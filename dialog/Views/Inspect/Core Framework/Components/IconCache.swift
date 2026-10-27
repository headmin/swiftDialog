//
// IconCache.swift
//  dialog
//
//  Icon caching and resolution for preset layouts: the main, overlay and banner images, and
//  the per-item icon ladder (authored icon, installed app by bundle id, first existing path).
//

import SwiftUI
import Synchronization

// MARK: - Icon Cache Manager

@MainActor
class PresetIconCache: ObservableObject {
    @Published var mainIcon: String?
    @Published var itemIcons: [String: String] = [:]
    @Published var bannerImage: NSImage?

    private let resolver = ImageResolver.shared

    func cacheMainIcon(for state: some ContentContext) {
        guard mainIcon == nil,
              let iconPath = state.uiConfiguration.iconPath else {
            writeLog("PresetIconCache: cacheMainIcon called but mainIcon='\(mainIcon ?? "nil")' iconPath='\(state.uiConfiguration.iconPath ?? "nil")'", logLevel: .info)
            return
        }

        writeLog("PresetIconCache: Caching main icon - iconPath='\(iconPath)' iconBasePath='\(state.uiConfiguration.iconBasePath ?? "nil")'", logLevel: .info)

        if iconPathHasIgnoredPrefixKeywords(for: iconPath) {
            DispatchQueue.main.async { [weak self] in
                self?.mainIcon = iconPath
                writeLog("PresetIconCache: Main icon has ignored prefix, using directly: '\(iconPath)'", logLevel: .info)
            }
        } else {
            let resolvedIcon = resolver.resolveImagePath(
                iconPath,
                basePath: state.uiConfiguration.iconBasePath,
                fallbackIcon: nil
            )
            DispatchQueue.main.async { [weak self] in
                self?.mainIcon = resolvedIcon
                writeLog("PresetIconCache: Main icon cached as: '\(resolvedIcon ?? "nil")'", logLevel: .info)
            }
        }
    }

    /// A failed resolution caches nothing, so the row asks again.
    private func resolveAndCacheIcon(_ icon: String, for itemId: String, basePath: String?) {
        if iconPathHasIgnoredPrefixKeywords(for: icon) {
            DispatchQueue.main.async { [weak self] in
                self?.itemIcons[itemId] = icon
            }
        } else if let resolved = resolver.resolveImagePath(icon, basePath: basePath, fallbackIcon: nil) {
            DispatchQueue.main.async { [weak self] in
                self?.itemIcons[itemId] = resolved
            }
        }
    }

    /// `limit` bounds the synchronous work for large item counts.
    func cacheItemIcons(for state: some ContentContext, limit: Int = 20) {
        let basePath = state.uiConfiguration.iconBasePath
        let itemsToCache = state.items.prefix(limit)

        for item in itemsToCache {
            if itemIcons[item.id] == nil, let icon = item.icon {
                resolveAndCacheIcon(icon, for: item.id, basePath: basePath)
            }
        }
    }

    func cacheItemIcons(for state: some ContentContext) {
        cacheItemIcons(for: state, limit: 20)
    }

    func cacheBannerImage(for state: some ContentContext) {
        guard bannerImage == nil,
              let bannerPath = state.uiConfiguration.bannerImage else { return }

        let resolvedPath = resolver.resolveImagePath(
            bannerPath,
            basePath: state.uiConfiguration.iconBasePath,
            fallbackIcon: nil
        )

        if let resolvedPath = resolvedPath,
           FileManager.default.fileExists(atPath: resolvedPath),
           let nsImage = NSImage(contentsOfFile: resolvedPath) {
            DispatchQueue.main.async { [weak self] in
                self?.bannerImage = nsImage
            }
        }
    }

    func iconPathHasIgnoredPrefixKeywords(for iconPath: String) -> Bool {
        return IconRef.isSymbolReference(iconPath) ||
           iconPath.lowercased() == "default" ||
           iconPath.lowercased() == "computer" ||
            iconPath.lowercased().hasPrefix("http")
    }

    func getMainIconPath(for state: some ContentContext) -> String {
        if let cached = mainIcon { return cached }

        if let iconPath = state.uiConfiguration.iconPath {
            if iconPathHasIgnoredPrefixKeywords(for: iconPath) {
                DispatchQueue.main.async { [weak self] in
                    self?.mainIcon = iconPath
                }
                return iconPath
            }
        }

        cacheMainIcon(for: state)
        return mainIcon ?? ""
    }

    func getOverlayIconPath(for state: some ContentContext) -> String {
        guard let overlayIcon = state.uiConfiguration.overlayIcon, !overlayIcon.isEmpty else {
            return ""
        }

        if iconPathHasIgnoredPrefixKeywords(for: overlayIcon) {
            return overlayIcon
        }

        let resolvedPath = resolver.resolveImagePath(
            overlayIcon,
            basePath: state.uiConfiguration.iconBasePath,
            fallbackIcon: nil
        )

        return resolvedPath ?? ""
    }

    /// The icon a row draws: a runtime `itemicon:` override, then `item.icon`, then the installed
    /// app by bundle id, then the first existing path, else "" and the view's default. Rungs 2
    /// and 3 return the `.app` path itself; `DisplayImage` extracts the icon.
    func getItemIconPath(for item: InspectConfig.ItemConfig, state: some ContentContext) -> String {
        if let override = state.itemIconOverrides[item.id], !override.isEmpty { return override }
        if let cached = itemIcons[item.id] { return cached }

        if let icon = item.icon {
            resolveAndCacheIcon(icon, for: item.id, basePath: state.uiConfiguration.iconBasePath)
            return itemIcons[item.id] ?? ""
        }

        if let installed = installedAppPath(for: item) {
            itemIcons[item.id] = installed
            return installed
        }

        // A miss is not cached: the row picks up its icon when the app lands.
        // `ItemIconLadder` rate-limits the probe.
        return ""
    }

    private func installedAppPath(for item: InspectConfig.ItemConfig) -> String? {
        ItemIconLadder.shared.installedAppPath(for: item)
    }

    func resolveImagePath(_ path: String, basePath: String?) -> String? {
        return resolver.resolveImagePath(path, basePath: basePath, fallbackIcon: nil)
    }
}

// MARK: - The ladder's middle rungs

/// Rungs 2 and 3 of the item-icon ladder: bundle id before path, first match wins. Callers are
/// synchronous view-body builders on and off the main actor, hence a `Mutex` rather than an actor.
/// Instance state so a test owns its own ladder and clock.
final class ItemIconLadder: Sendable {

    /// Shared by every seat so one miss floor covers all presets.
    static let shared = ItemIconLadder()

    /// How long a row that resolved to nothing waits before probing again; callers run once per
    /// row per redraw.
    let missRetryInterval: TimeInterval
    private let now: @Sendable () -> Date
    private let lastMiss = Mutex<[String: Date]>([:])

    // `{ Date() }`, not `Date.init`: the initializer reference is not inferred `@Sendable`.
    init(missRetryInterval: TimeInterval = 2, now: @escaping @Sendable () -> Date = { Date() }) {
        self.missRetryInterval = missRetryInterval
        self.now = now
    }

    /// The ladder for a watched row, rate-limited by the row's id.
    func installedAppPath(for item: any MonitoredItem) -> String? {
        installedAppPath(
            itemId: item.id,
            bundleIds: (item.requirements ?? [])
                .filter { $0.type.lowercased() == "app" }
                .compactMap(\.bundleId),
            paths: item.paths + (item.requirements ?? []).flatMap { $0.paths ?? [] })
    }

    /// The ladder with the miss floor. A hit clears the row's miss; a miss stamps it.
    func installedAppPath(itemId: String, bundleIds: [String], paths: [String]) -> String? {
        let current = now()
        let recentMiss = lastMiss.withLock { misses in
            misses[itemId].map { current.timeIntervalSince($0) < missRetryInterval } ?? false
        }
        if recentMiss { return nil }

        let resolved = Self.installedAppPath(bundleIds: bundleIds, paths: paths)
        lastMiss.withLock { $0[itemId] = resolved == nil ? current : nil }
        return resolved
    }

    /// The installed app's `.app` path, by bundle id first (finds it wherever it landed), then by
    /// the first existing path.
    static func installedAppPath(bundleIds: [String], paths: [String]) -> String? {
        for bundleId in bundleIds where !bundleId.isEmpty {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                return url.path
            }
        }
        for path in paths where !path.isEmpty {
            let expanded = (path as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expanded) {
                return expanded
            }
        }
        return nil
    }
}

/// Loads a row's art from a path. A `.app` path is a directory, so it goes through
/// `NSWorkspace` rather than `NSImage(contentsOfFile:)`; seats that use `IconView` need not call
/// this.
enum ItemArt {
    static func image(at path: String?) -> NSImage? {
        guard let path, path.hasPrefix("/") else { return nil }
        if path.hasSuffix(".app") {
            return FileManager.default.fileExists(atPath: path)
                ? NSWorkspace.shared.icon(forFile: path) : nil
        }
        return NSImage(contentsOfFile: path)
    }
}

extension MonitoredItem {
    /// The art this row draws: the authored `icon`, else the installed app. One seam for every
    /// seat that turns a row into artwork without `PresetIconCache`.
    var resolvedArt: String? {
        icon ?? ItemIconLadder.shared.installedAppPath(for: self)
    }
}
