//
//  PresetCommonHelpers.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 23/09/2025
//
//  Sets up common helpers for all preset layouts to reduce code duplication
//

import SwiftUI

// MARK: - Icon Cache Manager
class PresetIconCache: ObservableObject {
    @Published var mainIcon: String? = nil
    @Published var itemIcons: [String: String] = [:]
    @Published var bannerImage: NSImage? = nil

    private let resolver = ImageResolver.shared

    func cacheMainIcon(for state: InspectState) {
        guard mainIcon == nil,
              let iconPath = state.uiConfiguration.iconPath else { return }

        mainIcon = resolver.resolveImagePath(
            iconPath,
            basePath: state.uiConfiguration.iconBasePath,
            fallbackIcon: nil
        )
    }

    func cacheItemIcons(for state: InspectState) {
        let basePath = state.uiConfiguration.iconBasePath

        for item in state.items {
            if itemIcons[item.id] == nil,
               let icon = item.icon {
                itemIcons[item.id] = resolver.resolveImagePath(
                    icon,
                    basePath: basePath,
                    fallbackIcon: nil
                )
            }
        }
    }

    func cacheBannerImage(for state: InspectState) {
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
            bannerImage = nsImage
        }
    }

    func getMainIconPath(for state: InspectState) -> String {
        if let cached = mainIcon { return cached }
        cacheMainIcon(for: state)
        return mainIcon ?? ""
    }

    func getItemIconPath(for item: InspectConfig.ItemConfig, state: InspectState) -> String {
        if let cached = itemIcons[item.id] { return cached }

        let basePath = state.uiConfiguration.iconBasePath
        if let icon = item.icon,
           let resolved = resolver.resolveImagePath(icon, basePath: basePath, fallbackIcon: nil) {
            itemIcons[item.id] = resolved
            return resolved
        }

        return ""
    }
}

// MARK: - Common View Components
struct PresetCommonViews {

    // MARK: Progress Bar
    @ViewBuilder
    static func progressBar(
        state: InspectState,
        width: CGFloat = 250,
        height: CGFloat = 4,
        showLabel: Bool = true,
        labelSize: CGFloat = 11
    ) -> some View {
        let progress = state.items.isEmpty ? 0.0 :
            Double(state.completedItems.count) / Double(state.items.count)

        VStack(spacing: 8) {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: width)
                .frame(height: height)

            if showLabel {
                Text("\(state.completedItems.count) of \(state.items.count) completed")
                    .font(.system(size: labelSize))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: Status Indicator
    @ViewBuilder
    static func statusIndicator(
        for item: InspectConfig.ItemConfig,
        state: InspectState,
        size: CGFloat = 20
    ) -> some View {
        if state.completedItems.contains(item.id) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: size))
        } else if state.downloadingItems.contains(item.id) {
            ProgressView()
                .scaleEffect(size / 25)
                .frame(width: size, height: size)
        } else {
            Circle()
                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: size, height: size)
        }
    }

    // MARK: Button Area
    @ViewBuilder
    static func buttonArea(
        state: InspectState,
        spacing: CGFloat = 12,
        controlSize: ControlSize = .large
    ) -> some View {
        HStack(spacing: spacing) {
            // Button 2 (Secondary) - only when all complete
            if state.completedItems.count == state.items.count &&
               state.buttonConfiguration.button2Visible &&
               !state.buttonConfiguration.button2Text.isEmpty {
                Button(state.buttonConfiguration.button2Text) {
                    writeLog("Preset: User clicked button2 - exiting with code 2", logLevel: .info)
                    exit(2)
                }
                .buttonStyle(.bordered)
                .controlSize(controlSize)
            }

            // Button 1 (Primary)
            Button(state.buttonConfiguration.button1Text) {
                writeLog("Preset: User clicked button1 - exiting with code 0", logLevel: .info)
                exit(0)
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .controlSize(controlSize)
            .disabled(state.buttonConfiguration.button1Disabled)
        }
    }

    // MARK: Item Status Text
    static func getItemStatus(for item: InspectConfig.ItemConfig, state: InspectState) -> String {
        if state.completedItems.contains(item.id) {
            return "Installed"
        } else if state.downloadingItems.contains(item.id) {
            return "Installing..."
        } else {
            return "Waiting"
        }
    }

    // MARK: Sorted Items
    static func getSortedItemsByStatus(_ state: InspectState) -> [InspectConfig.ItemConfig] {
        let completed = state.items.filter { state.completedItems.contains($0.id) }
        let downloading = state.items.filter { state.downloadingItems.contains($0.id) }
        let pending = state.items.filter { item in
            !state.completedItems.contains(item.id) &&
            !state.downloadingItems.contains(item.id)
        }

        return completed + downloading + pending
    }
}

// MARK: - Layout Sizing Helper
struct PresetSizing {
    static func getScaleFactor(for sizeMode: String) -> CGFloat {
        switch sizeMode {
        case "compact": return 0.85
        case "large": return 1.15
        default: return 1.0  // standard
        }
    }

    static func getWindowSize(for state: InspectState) -> CGSize {
        // Check for explicit overrides first
        if let width = state.uiConfiguration.width,
           let height = state.uiConfiguration.height {
            return CGSize(width: CGFloat(width), height: CGFloat(height))
        }

        // Use InspectSizes
        let sizeMode = state.uiConfiguration.size ?? "standard"
        let preset = state.uiConfiguration.preset
        let (width, height) = InspectSizes.getSize(preset: preset, mode: sizeMode)

        return CGSize(width: width, height: height)
    }
}