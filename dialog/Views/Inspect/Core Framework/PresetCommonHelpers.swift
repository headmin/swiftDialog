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
    @Published var mainIcon: String?
    @Published var itemIcons: [String: String] = [:]
    @Published var bannerImage: NSImage?

    private let resolver = ImageResolver.shared

    func cacheMainIcon(for state: InspectState) {
        guard mainIcon == nil,
              let iconPath = state.uiConfiguration.iconPath else {
            writeLog("PresetIconCache: cacheMainIcon called but mainIcon='\(mainIcon ?? "nil")' iconPath='\(state.uiConfiguration.iconPath ?? "nil")'", logLevel: .info)
            return
        }

        writeLog("PresetIconCache: Caching main icon - iconPath='\(iconPath)' iconBasePath='\(state.uiConfiguration.iconBasePath ?? "nil")'", logLevel: .info)

        // Don't resolve SF Symbols or special keywords - pass them through directly
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

    /// Resolve and cache a single icon path
    private func resolveAndCacheIcon(_ icon: String, for itemId: String, basePath: String?) {
        // Don't resolve SF Symbols or special keywords - pass them through directly
        if iconPathHasIgnoredPrefixKeywords(for: icon) {
            DispatchQueue.main.async { [weak self] in
                self?.itemIcons[itemId] = icon
            }
        } else if let resolved = resolver.resolveImagePath(icon, basePath: basePath, fallbackIcon: nil) {
            // Only cache if resolution succeeded
            DispatchQueue.main.async { [weak self] in
                self?.itemIcons[itemId] = resolved
            }
        }
        // If resolution fails, don't cache anything (leave itemIcons[itemId] as nil/uncached)
    }

    func cacheItemIcons(for state: InspectState, limit: Int = 20) {
        // Stick to smple synchronous caching !!! - remember to build on lazy loading - the swiftUI way to prevent blocking
        // Added batch limit to prevent hanging with large item counts
        let basePath = state.uiConfiguration.iconBasePath
        let itemsToCache = state.items.prefix(limit)

        for item in itemsToCache {
            if itemIcons[item.id] == nil, let icon = item.icon {
                resolveAndCacheIcon(icon, for: item.id, basePath: basePath)
            }
        }
    }

    // Backwards compatible overload without limit
    func cacheItemIcons(for state: InspectState) {
        cacheItemIcons(for: state, limit: 20)
    }

    // Progressive caching for visible items only
    func cacheVisibleItemIcons(for items: [InspectConfig.ItemConfig], state: InspectState) {
        let basePath = state.uiConfiguration.iconBasePath

        for item in items {
            if itemIcons[item.id] == nil, let icon = item.icon {
                resolveAndCacheIcon(icon, for: item.id, basePath: basePath)
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
            DispatchQueue.main.async { [weak self] in
                self?.bannerImage = nsImage
            }
        }
    }
    
    func iconPathHasIgnoredPrefixKeywords(for iconPath: String) -> Bool {
        return iconPath.lowercased().hasPrefix("sf=") ||
           iconPath.lowercased() == "default" ||
           iconPath.lowercased() == "computer" ||
            iconPath.lowercased().hasPrefix("http")
    }

    func getMainIconPath(for state: InspectState) -> String {
        if let cached = mainIcon { return cached }

        // Check if we have an icon path to cache
        if let iconPath = state.uiConfiguration.iconPath {
            // Don't resolve SF Symbols or special keywords - pass them through directly
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

    func getItemIconPath(for item: InspectConfig.ItemConfig, state: InspectState) -> String {
        if let cached = itemIcons[item.id] { return cached }

        guard let icon = item.icon else { return "" }

        // Use the common resolution logic
        resolveAndCacheIcon(icon, for: item.id, basePath: state.uiConfiguration.iconBasePath)
        return itemIcons[item.id] ?? ""
    }

    // Helper for resolving paths (e.g., for rotating images in Preset6)
    func resolveImagePath(_ path: String, basePath: String?) -> String? {
        return resolver.resolveImagePath(path, basePath: basePath, fallbackIcon: nil)
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
                Text(getProgressText(state: state))
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
            // Button 2 (Secondary) - show in demo mode or when all complete
            if (state.configurationSource == .testData || state.completedItems.count == state.items.count) &&
               state.buttonConfiguration.button2Visible &&
               !state.buttonConfiguration.button2Text.isEmpty {
                Button(state.buttonConfiguration.button2Text) {
                    // Check if we're in demo mode and button is for creating configuration
                    if state.configurationSource == .testData && (state.buttonConfiguration.button2Text.contains("Create") || state.buttonConfiguration.button2Text.contains("Config")) {
                        writeLog("Preset: Creating sample configuration", logLevel: .info)
                        state.createSampleConfiguration()
                    } else {
                        writeLog("Preset: User clicked button2 - exiting with code 2", logLevel: .info)
                        exit(2)
                    }
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
            // Priority: item-specific > global UILabels > default
            if let customStatus = item.completedStatus {
                return customStatus
            } else if let globalStatus = state.config?.uiLabels?.completedStatus {
                return globalStatus
            } else {
                return "Completed"
            }
        } else if state.downloadingItems.contains(item.id) {
            // Priority: item-specific > global UILabels > default
            if let customStatus = item.downloadingStatus {
                return customStatus
            } else if let globalStatus = state.config?.uiLabels?.downloadingStatus {
                return globalStatus
            } else {
                return "Installing..."
            }
        } else {
            // Priority: item-specific > global UILabels > default
            if let customStatus = item.pendingStatus {
                return customStatus
            } else if let globalStatus = state.config?.uiLabels?.pendingStatus {
                return globalStatus
            } else {
                return "Waiting"
            }
        }
    }

    // MARK: Progress Text
    /// Get progress bar text with template support
    /// Supports template variables: {completed}, {total}
    /// Example template: "{completed} of {total} apps installed"
    static func getProgressText(state: InspectState) -> String {
        let completed = state.completedItems.count
        let total = state.items.count

        if let template = state.config?.uiLabels?.progressFormat {
            return template
                .replacingOccurrences(of: "{completed}", with: "\(completed)")
                .replacingOccurrences(of: "{total}", with: "\(total)")
        }

        return "\(completed) of \(total) completed"
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

// MARK: - Category Icon Bubble Component (Shared between presets)

/// Small app icon bubble for context (e.g., Finder, Safari, Word)
struct CategoryIconBubble: View {
    let iconName: String
    let iconBasePath: String?
    let iconCache: PresetIconCache
    let scaleFactor: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 36 * scaleFactor, height: 36 * scaleFactor)
                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 1)
                )

            if let resolvedPath = iconCache.resolveImagePath(iconName, basePath: iconBasePath),
               let image = NSImage(contentsOfFile: resolvedPath) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24 * scaleFactor, height: 24 * scaleFactor)
                    .clipShape(Circle())
            } else {
                // Fallback to SF Symbol if image not found
                Image(systemName: getSFSymbolForApp(iconName))
                    .font(.system(size: 16 * scaleFactor, weight: .medium))
                    .foregroundColor(.blue)
            }
        }
    }

    private func getSFSymbolForApp(_ name: String) -> String {
        let lowercased = name.lowercased()
        if lowercased.contains("finder") { return "folder.fill" }
        if lowercased.contains("safari") { return "safari.fill" }
        if lowercased.contains("word") || lowercased.contains("office") { return "doc.text.fill" }
        if lowercased.contains("excel") { return "tablecells.fill" }
        if lowercased.contains("powerpoint") { return "play.rectangle.fill" }
        if lowercased.contains("terminal") { return "terminal.fill" }
        if lowercased.contains("settings") || lowercased.contains("preferences") { return "gearshape.fill" }
        if lowercased.contains("chrome") { return "globe" }
        if lowercased.contains("firefox") { return "flame.fill" }
        if lowercased.contains("mail") { return "envelope.fill" }
        if lowercased.contains("calendar") { return "calendar" }
        if lowercased.contains("notes") { return "note.text" }
        if lowercased.contains("photos") { return "photo.fill" }
        return "app.fill"
    }
}

// MARK: - Guidance Content View (Shared from Preset9)

/// Renders rich guidance content for Migration Assistant-style workflows
/// Originally from Preset9, now shared across all presets for consistent rich content display
struct GuidanceContentView: View {
    let contentBlocks: [InspectConfig.GuidanceContent]
    let scaleFactor: CGFloat
    let iconBasePath: String?  // Optional base path for resolving relative image paths
    @ObservedObject var inspectState: InspectState
    let itemId: String

    // Initialize with required parameters for interactive form support
    init(contentBlocks: [InspectConfig.GuidanceContent], scaleFactor: CGFloat, iconBasePath: String? = nil, inspectState: InspectState, itemId: String) {
        self.contentBlocks = contentBlocks
        self.scaleFactor = scaleFactor
        self.iconBasePath = iconBasePath
        self.inspectState = inspectState
        self.itemId = itemId

        // Initialize form state for this item asynchronously to avoid publishing during view updates
        DispatchQueue.main.async {
            inspectState.initializeGuidanceFormState(for: itemId)
        }
    }

    /// Group comparison-table blocks by category for collapsible rendering
    private var groupedBlocks: [(category: String?, items: [InspectConfig.GuidanceContent])] {
        var groups: [(String?, [InspectConfig.GuidanceContent])] = []
        var currentCategory: String?
        var currentItems: [InspectConfig.GuidanceContent] = []

        for block in contentBlocks {
            if block.type == "comparison-table" && block.category != nil {
                // Comparison table with category
                if block.category != currentCategory {
                    // Save previous group if exists
                    if !currentItems.isEmpty {
                        groups.append((currentCategory, currentItems))
                        currentItems = []
                    }
                    currentCategory = block.category
                }
                currentItems.append(block)
            } else {
                // Non-categorized block or different type
                // Save previous group if exists
                if !currentItems.isEmpty {
                    groups.append((currentCategory, currentItems))
                    currentItems = []
                    currentCategory = nil
                }
                // Add as single-item group
                groups.append((nil, [block]))
            }
        }

        // Save last group
        if !currentItems.isEmpty {
            groups.append((currentCategory, currentItems))
        }

        return groups
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8 * scaleFactor) {
            ForEach(Array(groupedBlocks.enumerated()), id: \.offset) { groupIndex, group in
                if let category = group.category, !group.items.isEmpty, group.items.allSatisfy({ $0.type == "comparison-table" }) {
                    // Render as collapsible category group
                    ComparisonGroupView(
                        category: category,
                        comparisons: group.items,
                        scaleFactor: scaleFactor
                    )
                    .id("comparison-group-\(category)-\(groupIndex)")
                } else {
                    // Render individual blocks normally
                    ForEach(Array(group.items.enumerated()), id: \.offset) { _, block in
                        contentBlockView(for: block)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func contentBlockView(for block: InspectConfig.GuidanceContent) -> some View {
        let isBold = block.bold ?? false
        let textColor = getTextColor(for: block)

        switch block.type {
        case "text":
            let resolvedContent = resolveTemplateVariables(block.content ?? "", inspectState: inspectState)
            Text(resolvedContent)
                .font(.system(size: 13 * scaleFactor, weight: isBold ? .semibold : .regular))
                .foregroundColor(textColor)
                .fixedSize(horizontal: false, vertical: true)

        case "highlight":
            let accentColor: Color = {
                if let customColor = inspectState.config?.secondaryColor {
                    return Color(hex: customColor)
                }
                // Use system accent color if default gray is still set
                let defaultColor = inspectState.uiConfiguration.secondaryColor
                return defaultColor == "#A0A0A0" ? Color.accentColor : Color(hex: defaultColor)
            }()

            Text(block.content ?? "")
                .font(.system(size: 14 * scaleFactor, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
                .modifier(HighlightChipStyle(accentColor: accentColor, scaleFactor: scaleFactor))

        case "arrow":
            HStack(spacing: 6 * scaleFactor) {
                Text(block.content ?? "")
                    .font(.system(size: 13 * scaleFactor, weight: .medium))
                    .foregroundColor(textColor)
            }

        case "warning":
            HStack(alignment: .top, spacing: 8 * scaleFactor) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundColor(.orange)
                Text(block.content ?? "")
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10 * scaleFactor)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.1))
            )

        case "info":
            HStack(alignment: .top, spacing: 8 * scaleFactor) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundColor(.blue)
                Text(block.content ?? "")
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10 * scaleFactor)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
            )

        case "success":
            HStack(alignment: .top, spacing: 8 * scaleFactor) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundColor(.green)
                Text(block.content ?? "")
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10 * scaleFactor)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.1))
            )

        case "explainer":
            // Explainer with inline markdown support and optional styled box
            // Supports: "plain" (no box), "info" (blue), "warning" (orange), "success" (green)
            let resolvedContent = resolveTemplateVariables(block.content ?? "", inspectState: inspectState)
            let explainerStyle = block.style ?? "plain"

            // Determine icon and colors based on style
            let (icon, iconColor, backgroundColor): (String?, Color, Color) = {
                switch explainerStyle {
                case "info":
                    return ("info.circle.fill", .blue, Color.blue.opacity(0.1))
                case "warning":
                    return ("exclamationmark.triangle.fill", .orange, Color.orange.opacity(0.1))
                case "success":
                    return ("checkmark.circle.fill", .green, Color.green.opacity(0.1))
                default: // "plain"
                    return (nil, .primary, .clear)
                }
            }()

            Group {
                if let iconName = icon {
                    // Box style with icon
                    HStack(alignment: .top, spacing: 8 * scaleFactor) {
                        Image(systemName: iconName)
                            .font(.system(size: 13 * scaleFactor))
                            .foregroundColor(iconColor)

                        // Native SwiftUI markdown support
                        Text(try! AttributedString(markdown: resolvedContent, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                            .font(.system(size: 13 * scaleFactor))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10 * scaleFactor)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(backgroundColor)
                    )
                } else {
                    // Plain style without box
                    Text(try! AttributedString(markdown: resolvedContent, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                        .font(.system(size: 13 * scaleFactor))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

        case "bullets":
            let resolvedContent = resolveTemplateVariables(block.content ?? "", inspectState: inspectState)
            HStack(alignment: .top, spacing: 8 * scaleFactor) {
                Text("•")
                    .font(.system(size: 13 * scaleFactor, weight: .bold))
                    .foregroundColor(.primary)
                Text(resolvedContent)
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case "label-value":
            // Format label-value pairs with visual distinction
            // Expects content in format "Label: Value" or uses separate label/value fields
            // Supports style variants: "default", "success" (green labels), "table" (no bullet, green labels)
            let resolvedContent = resolveTemplateVariables(block.content ?? "", inspectState: inspectState)
            let style = block.style ?? "default"  // default, success, table

            // Parse label and value
            let (label, value): (String, String) = {
                // Option 1: Use separate label/value fields if provided
                if let blockLabel = block.label, let blockValue = block.value {
                    return (blockLabel, blockValue)
                }

                // Option 2: Parse from content string (split on first colon)
                if let colonIndex = resolvedContent.firstIndex(of: ":") {
                    let labelPart = String(resolvedContent[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                    let valuePart = String(resolvedContent[resolvedContent.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    return (labelPart, valuePart)
                }

                // Fallback: treat entire content as value
                return ("", resolvedContent)
            }()

            // Determine styling based on style parameter
            let (labelColor, valueFontSize, showBullet): (Color, CGFloat, Bool) = {
                switch style {
                case "success":
                    return (Color(hex: "#34C759") ?? .green, 15, true)  // Green labels, larger values, with bullet
                case "table":
                    return (Color(hex: "#34C759") ?? .green, 15, false)  // Green labels, larger values, no bullet
                default:
                    return (.secondary, 13, true)  // Default: grey labels, normal size, with bullet
                }
            }()

            HStack(alignment: .top, spacing: 8 * scaleFactor) {
                // Bullet point (optional based on style)
                if showBullet {
                    Text("•")
                        .font(.system(size: 13 * scaleFactor, weight: .bold))
                        .foregroundColor(.primary)
                }

                // Label part (styled based on variant)
                if !label.isEmpty {
                    Text(label + ":")
                        .font(.system(size: 13 * scaleFactor, weight: .regular))
                        .foregroundColor(labelColor)
                }

                // Value part (bold, larger if table/success style)
                Text(value)
                    .font(.system(size: valueFontSize * scaleFactor, weight: .bold))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, showBullet ? 0 : 6 * scaleFactor)  // Add slight indent if no bullet

        case "image":
            // Only render if content path is provided and not empty
            if let contentPath = block.content, !contentPath.isEmpty {
                VStack(spacing: 4 * scaleFactor) {
                    if let image = loadInstructionalImage(path: contentPath) {
                        let imageWidth = CGFloat(block.imageWidth ?? 400) * scaleFactor
                        let shape = block.imageShape ?? "rectangle"
                        let showBorder = block.imageBorder ?? true

                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: imageWidth)
                            .clipShape(getImageClipShape(for: shape))
                            .overlay(
                                showBorder ? getImageClipShape(for: shape)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1) : nil
                            )
                            .shadow(color: showBorder ? Color.black.opacity(0.15) : Color.clear, radius: 4, x: 0, y: 2)
                            .padding(.vertical, 4 * scaleFactor)

                        if let caption = block.caption {
                            Text(caption)
                                .font(.system(size: 11 * scaleFactor))
                                .foregroundColor(.secondary)
                                .italic()
                                .multilineTextAlignment(.center)
                                .padding(.top, 2 * scaleFactor)
                        }
                    } else {
                        // Fallback if image not found - only show in debug mode
                        if appvars.debugMode {
                            HStack(spacing: 8 * scaleFactor) {
                                Image(systemName: "photo")
                                    .font(.system(size: 13 * scaleFactor))
                                    .foregroundColor(.secondary)
                                Text("Image not found: \(contentPath)")
                                    .font(.system(size: 11 * scaleFactor))
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                            .padding(10 * scaleFactor)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.secondary.opacity(0.1))
                            )
                        }
                    }
                }
            }

        case "checkbox":
            VStack(alignment: .leading, spacing: 6 * scaleFactor) {
                HStack {
                    if let fieldId = block.id {
                        Toggle(isOn: Binding(
                            get: {
                                // Check state first, then fall back to default value from config
                                if let checked = inspectState.guidanceFormInputs[itemId]?.checkboxes[fieldId] {
                                    return checked
                                }
                                // Parse default from block.value ("true", "yes", "1" → true)
                                if let value = block.value?.lowercased() {
                                    return value == "true" || value == "yes" || value == "1"
                                }
                                return false
                            },
                            set: { newValue in
                                // Ensure state exists before setting (fixes race condition with async init)
                                if inspectState.guidanceFormInputs[itemId] == nil {
                                    inspectState.initializeGuidanceFormState(for: itemId)
                                }
                                inspectState.guidanceFormInputs[itemId]?.checkboxes[fieldId] = newValue
                                writeLog("GuidanceContentView: Checkbox '\(fieldId)' set to \(newValue)", logLevel: .info)
                            }
                        )) {
                            Text(block.content ?? "")
                                .font(.system(size: 13 * scaleFactor))
                                .foregroundColor(.primary)
                        }
                        .toggleStyle(.checkbox)
                    } else {
                        // Fallback for checkbox without id (display-only)
                        Toggle(isOn: .constant(false)) {
                            Text(block.content ?? "")
                                .font(.system(size: 13 * scaleFactor))
                                .foregroundColor(.primary)
                        }
                        .toggleStyle(.checkbox)
                        .disabled(true)
                    }
                }

                if block.required == true {
                    Text("* Required")
                        .font(.system(size: 11 * scaleFactor))
                        .foregroundColor(.orange)
                        .italic()
                }
            }
            .padding(.vertical, 4 * scaleFactor)

        case "dropdown":
            VStack(alignment: .leading, spacing: 6 * scaleFactor) {
                HStack {
                    Text(block.content ?? "")
                        .font(.system(size: 13 * scaleFactor))
                        .foregroundColor(.primary)

                    Spacer()

                    if let options = block.options, !options.isEmpty, let fieldId = block.id {
                        Picker("", selection: Binding(
                            get: {
                                inspectState.guidanceFormInputs[itemId]?.dropdowns[fieldId] ?? block.value ?? options.first ?? ""
                            },
                            set: { newValue in
                                // Ensure state exists before setting (fixes race condition with async init)
                                if inspectState.guidanceFormInputs[itemId] == nil {
                                    inspectState.initializeGuidanceFormState(for: itemId)
                                }
                                inspectState.guidanceFormInputs[itemId]?.dropdowns[fieldId] = newValue
                                writeLog("GuidanceContentView: Dropdown '\(fieldId)' set to '\(newValue)'", logLevel: .info)
                            }
                        )) {
                            ForEach(options, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 200 * scaleFactor)
                    } else if let options = block.options, !options.isEmpty {
                        // Fallback for dropdown without id (display-only)
                        Menu {
                            ForEach(options, id: \.self) { option in
                                Button(option) { }
                            }
                        } label: {
                            HStack {
                                Text(block.value ?? "Select...")
                                    .font(.system(size: 12 * scaleFactor))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10 * scaleFactor))
                            }
                            .padding(.horizontal, 12 * scaleFactor)
                            .padding(.vertical, 6 * scaleFactor)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.secondary.opacity(0.1))
                            )
                        }
                        .frame(maxWidth: 200 * scaleFactor)
                        .disabled(true)
                    }
                }

                if block.required == true {
                    Text("* Required")
                        .font(.system(size: 11 * scaleFactor))
                        .foregroundColor(.orange)
                        .italic()
                }
            }
            .padding(.vertical, 4 * scaleFactor)

        case "radio":
            VStack(alignment: .leading, spacing: 8 * scaleFactor) {
                if let content = block.content, !content.isEmpty {
                    Text(content)
                        .font(.system(size: 13 * scaleFactor, weight: .medium))
                        .foregroundColor(.primary)
                }

                if let options = block.options, !options.isEmpty, let fieldId = block.id {
                    let selectedValue = Binding(
                        get: {
                            inspectState.guidanceFormInputs[itemId]?.radios[fieldId] ?? block.value ?? ""
                        },
                        set: { newValue in
                            // Ensure state exists before setting (fixes race condition with async init)
                            if inspectState.guidanceFormInputs[itemId] == nil {
                                inspectState.initializeGuidanceFormState(for: itemId)
                            }
                            inspectState.guidanceFormInputs[itemId]?.radios[fieldId] = newValue
                            writeLog("GuidanceContentView: Radio '\(fieldId)' set to '\(newValue)'", logLevel: .info)
                        }
                    )

                    VStack(alignment: .leading, spacing: 6 * scaleFactor) {
                        ForEach(options, id: \.self) { option in
                            HStack {
                                Image(systemName: option == selectedValue.wrappedValue ? "circle.inset.filled" : "circle")
                                    .font(.system(size: 14 * scaleFactor))
                                    .foregroundColor(option == selectedValue.wrappedValue ? .blue : .secondary)

                                Text(option)
                                    .font(.system(size: 13 * scaleFactor))
                                    .foregroundColor(.primary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedValue.wrappedValue = option
                            }
                        }
                    }
                    .padding(.leading, 4 * scaleFactor)
                } else if let options = block.options, !options.isEmpty {
                    // Fallback for radio without id (display-only)
                    VStack(alignment: .leading, spacing: 6 * scaleFactor) {
                        ForEach(options, id: \.self) { option in
                            HStack {
                                Image(systemName: option == block.value ? "circle.inset.filled" : "circle")
                                    .font(.system(size: 14 * scaleFactor))
                                    .foregroundColor(option == block.value ? .blue : .secondary)

                                Text(option)
                                    .font(.system(size: 13 * scaleFactor))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .padding(.leading, 4 * scaleFactor)
                }

                if block.required == true {
                    Text("* Required")
                        .font(.system(size: 11 * scaleFactor))
                        .foregroundColor(.orange)
                        .italic()
                }
            }
            .padding(.vertical, 4 * scaleFactor)

        case "toggle":
            HStack {
                if let content = block.content {
                    Text(content)
                        .font(.system(size: 13 * scaleFactor))
                        .foregroundColor(.primary)
                }

                if let helpText = block.helpText, !helpText.isEmpty {
                    InfoPopoverButton(helpText: helpText, scaleFactor: scaleFactor)
                }

                Spacer()

                if let fieldId = block.id {
                    let isOn = Binding(
                        get: {
                            inspectState.guidanceFormInputs[itemId]?.toggles[fieldId] ?? (block.value == "true")
                        },
                        set: { newValue in
                            if inspectState.guidanceFormInputs[itemId] == nil {
                                inspectState.initializeGuidanceFormState(for: itemId)
                            }
                            inspectState.guidanceFormInputs[itemId]?.toggles[fieldId] = newValue
                            writeLog("GuidanceContentView: Toggle '\(fieldId)' set to \(newValue)", logLevel: .info)

                            // Write to interaction log for script monitoring
                            inspectState.writeToInteractionLog("toggle:\(itemId):\(fieldId):\(newValue)")
                        }
                    )

                    Toggle("", isOn: isOn)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }
            .padding(.vertical, 4 * scaleFactor)

        case "slider":
            VStack(alignment: .leading, spacing: 8 * scaleFactor) {
                HStack {
                    if let label = block.label {
                        Text(label)
                            .font(.system(size: 13 * scaleFactor, weight: .medium))
                            .foregroundColor(.primary)
                    }

                    if let helpText = block.helpText, !helpText.isEmpty {
                        InfoPopoverButton(helpText: helpText, scaleFactor: scaleFactor)
                    }

                    Spacer()

                    if let fieldId = block.id {
                        let currentValue = inspectState.guidanceFormInputs[itemId]?.sliders[fieldId] ??
                                          Double(block.value ?? "0") ?? 0.0

                        HStack(spacing: 4 * scaleFactor) {
                            Text("\(Int(currentValue))")
                                .font(.system(size: 13 * scaleFactor, weight: .medium))
                                .foregroundColor(.secondary)

                            if let unit = block.unit {
                                Text(unit)
                                    .font(.system(size: 12 * scaleFactor))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if let fieldId = block.id {
                    let minValue = block.min ?? 0.0
                    let maxValue = block.max ?? 100.0
                    let stepValue = block.step ?? 1.0

                    let sliderBinding = Binding(
                        get: {
                            inspectState.guidanceFormInputs[itemId]?.sliders[fieldId] ??
                            Double(block.value ?? "\(minValue)") ?? minValue
                        },
                        set: { newValue in
                            if inspectState.guidanceFormInputs[itemId] == nil {
                                inspectState.initializeGuidanceFormState(for: itemId)
                            }
                            inspectState.guidanceFormInputs[itemId]?.sliders[fieldId] = newValue
                            writeLog("GuidanceContentView: Slider '\(fieldId)' set to \(newValue)", logLevel: .info)

                            // Write to interaction log for script monitoring
                            inspectState.writeToInteractionLog("slider:\(itemId):\(fieldId):\(newValue)")
                        }
                    )

                    Slider(value: sliderBinding, in: minValue...maxValue, step: stepValue)
                }
            }
            .padding(.vertical, 4 * scaleFactor)

        case "button":
            if let buttonLabel = block.content {
                applyButtonStyle(
                    Button(action: {
                        handleButtonAction(block: block, itemId: itemId, inspectState: inspectState)
                    }) {
                        if let icon = block.icon {
                            Label(buttonLabel, systemImage: icon)
                        } else {
                            Text(buttonLabel)
                        }
                    }
                    .controlSize(.regular),
                    styleString: block.buttonStyle
                )
            }

        case "status-badge":
            if let label = block.label, let state = block.state {
                let autoColor = block.autoColor ?? true
                let customColor: Color? = {
                    if let colorHex = block.color {
                        return Color(hex: colorHex)
                    }
                    return nil
                }()

                StatusBadgeView(
                    label: label,
                    state: state,
                    icon: block.icon,
                    autoColor: autoColor,
                    customColor: customColor,
                    scaleFactor: scaleFactor
                )
                .id("status-badge-\(label)-\(state)")
            } else if appvars.debugMode {
                Text("status-badge requires 'label' and 'state' properties")
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundColor(.red)
                    .italic()
            }

        case "comparison-table":
            // swiftlint:disable:next redundant_nil_coalescing
            if let label = block.label ?? block.content.map({ $0.isEmpty ? nil : $0 }) ?? nil,  // Flatten Optional<String?> to String?
               let expected = block.expected,
               let actual = block.actual {
                let autoColor = block.autoColor ?? true
                let customColor: Color? = {
                    if let colorHex = block.color {
                        return Color(hex: colorHex)
                    }
                    return nil
                }()

                ComparisonTableView(
                    label: label,
                    expected: expected,
                    actual: actual,
                    expectedLabel: block.expectedLabel ?? "Expected",
                    actualLabel: block.actualLabel ?? "Actual",
                    expectedIcon: block.expectedIcon,
                    actualIcon: block.actualIcon,
                    comparisonStyle: block.comparisonStyle,
                    highlightCells: block.highlightCells ?? false,
                    autoColor: autoColor,
                    customColor: customColor,
                    expectedColor: block.expectedColor.flatMap { Color(hex: $0) },
                    actualColor: block.actualColor.flatMap { Color(hex: $0) },
                    scaleFactor: scaleFactor
                )
                .id("comparison-\(label)-\(actual)-\(block.comparisonStyle ?? "stacked")")
            } else if appvars.debugMode {
                Text("comparison-table requires 'expected' and 'actual' properties")
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundColor(.red)
                    .italic()
            }

        case "phase-tracker":
            if let currentPhase = block.currentPhase,
               let phases = block.phases, !phases.isEmpty {
                let style = block.style ?? "stepper"

                PhaseTrackerView(
                    currentPhase: currentPhase,
                    phases: phases,
                    style: style,
                    scaleFactor: scaleFactor
                )
                .id("phase-tracker-\(currentPhase)")
            } else if appvars.debugMode {
                Text("phase-tracker requires 'currentPhase' and 'phases' properties")
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundColor(.red)
                    .italic()
            }

        case "progress-bar":
            let progressStyle = block.style ?? "indeterminate"
            let progressValue = block.progress ?? 0.0
            let progressLabel = block.label ?? block.content

            VStack(alignment: .leading, spacing: 6 * scaleFactor) {
                if let label = progressLabel, !label.isEmpty {
                    Text(label)
                        .font(.system(size: 12 * scaleFactor, weight: .medium))
                        .foregroundColor(.secondary)
                }

                if progressStyle == "determinate" {
                    // Determinate progress with value
                    ProgressView(value: progressValue)
                        .progressViewStyle(.linear)
                        .scaleEffect(y: 1.5 * scaleFactor, anchor: .center)
                        .frame(height: 12 * scaleFactor)
                } else {
                    // Indeterminate animated progress (brownian/spinner)
                    IndeterminateProgressView()
                        .frame(height: 8 * scaleFactor)
                }
            }

        case "image-carousel":
            if let images = block.images, !images.isEmpty {
                ImageCarouselView(
                    images: images,
                    iconBasePath: iconBasePath,
                    scaleFactor: scaleFactor,
                    imageWidth: CGFloat(block.imageWidth ?? 400),
                    imageHeight: CGFloat(block.imageHeight ?? 300),
                    imageShape: block.imageShape ?? "rectangle",
                    showDots: block.showDots ?? true,
                    showArrows: block.showArrows ?? true,
                    captions: block.captions,
                    autoAdvance: block.autoAdvance ?? false,
                    autoAdvanceDelay: block.autoAdvanceDelay ?? 3.0,
                    transitionStyle: block.transitionStyle ?? "slide",
                    currentIndex: block.currentIndex ?? 0
                )
                .id("carousel-\(images.joined(separator: ","))-\(block.currentIndex ?? 0)")
            } else if appvars.debugMode {
                Text("image-carousel requires 'images' array with at least one image path")
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundColor(.red)
                    .italic()
            }

        case "compliance-card":
            if let categoryName = block.categoryName,
               let passed = block.passed,
               let total = block.total {
                ComplianceCardView(
                    categoryName: categoryName,
                    passed: passed,
                    total: total,
                    icon: block.cardIcon,
                    checkDetails: block.checkDetails,
                    scaleFactor: scaleFactor,
                    colorThresholds: inspectState.colorThresholds
                )
            } else if appvars.debugMode {
                Text("compliance-card requires 'categoryName', 'passed', and 'total' fields")
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundColor(.red)
                    .italic()
            }

        case "compliance-header":
            if let passed = block.passed,
               let total = block.total {
                let failed = total - passed
                ComplianceDashboardHeader(
                    title: block.label ?? "Compliance Dashboard",
                    subtitle: block.content,
                    icon: block.icon,
                    passed: passed,
                    failed: failed,
                    scaleFactor: scaleFactor,
                    colorThresholds: inspectState.colorThresholds
                )
            } else if appvars.debugMode {
                Text("compliance-header requires 'passed' and 'total' fields")
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundColor(.red)
                    .italic()
            }

        default:
            Text(block.content ?? "")
                .font(.system(size: 13 * scaleFactor))
                .foregroundColor(textColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Image Loading Helper

    /// Load instructional image from absolute or relative path using ImageResolver
    private func loadInstructionalImage(path: String) -> NSImage? {
        writeLog("GuidanceContentView: Loading image from path='\(path)' with iconBasePath='\(iconBasePath ?? "nil")'", logLevel: .info)

        // Use ImageResolver for consistent path resolution across the app
        let resolver = ImageResolver.shared

        // Resolve the path using basePath (if provided) or standard search locations
        if let resolvedPath = resolver.resolveImagePath(path, basePath: iconBasePath, fallbackIcon: nil) {
            writeLog("GuidanceContentView: ImageResolver returned resolvedPath='\(resolvedPath)'", logLevel: .info)

            // Only try to load as a file if it looks like a file path (starts with /)
            // This excludes SF Symbols and other special formats that ImageResolver might return
            if resolvedPath.hasPrefix("/") && FileManager.default.fileExists(atPath: resolvedPath) {
                writeLog("GuidanceContentView: Loading image from resolved file path: \(resolvedPath)", logLevel: .info)
                return NSImage(contentsOfFile: resolvedPath)
            } else if !resolvedPath.hasPrefix("/") {
                // Not a file path - ImageResolver returned it as-is (like SF Symbol or URL)
                // These aren't supported for instructional images which must be actual image files
                writeLog("GuidanceContentView: Resolved path is not a file path (SF Symbol or URL?): \(resolvedPath)", logLevel: .info)
            } else {
                writeLog("GuidanceContentView: Resolved file path does not exist: \(resolvedPath)", logLevel: .info)
            }
        } else {
            writeLog("GuidanceContentView: ImageResolver returned nil for path: \(path)", logLevel: .info)
        }

        // If ImageResolver doesn't find it, try absolute path as last resort
        if path.hasPrefix("/") {
            if FileManager.default.fileExists(atPath: path) {
                writeLog("GuidanceContentView: Loading image from original absolute path: \(path)", logLevel: .info)
                return NSImage(contentsOfFile: path)
            } else {
                writeLog("GuidanceContentView: Original absolute path does not exist: \(path)", logLevel: .info)
            }
        }

        writeLog("GuidanceContentView: Failed to load image from path: \(path)", logLevel: .info)
        return nil
    }

    /// Get the appropriate clip shape for image display
    private func getImageClipShape(for shape: String) -> AnyShape {
        switch shape.lowercased() {
        case "square":
            return AnyShape(RoundedRectangle(cornerRadius: 8))
        case "circle":
            return AnyShape(Circle())
        default: // "rectangle"
            return AnyShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func getTextColor(for block: InspectConfig.GuidanceContent) -> Color {
        if let colorHex = block.color {
            return Color(hex: colorHex)
        }
        return .primary
    }

    // MARK: - Template Variable Resolution

    /// Resolve template variables in content string (e.g., {{fieldId}} or {{stepId.fieldId}})
    /// Looks up values from inspectState.guidanceFormInputs and replaces placeholders with actual values
    private func resolveTemplateVariables(_ content: String, inspectState: InspectState) -> String {
        var resolved = content

        // Find all {{variable}} patterns
        let pattern = "\\{\\{([^}]+)\\}\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return content
        }

        let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))

        // Process matches in reverse order to preserve string indices
        for match in matches.reversed() {
            guard let matchRange = Range(match.range, in: content),
                  let variableRange = Range(match.range(at: 1), in: content) else {
                continue
            }

            let variable = String(content[variableRange])
            let value = resolveVariable(variable, from: inspectState)

            resolved.replaceSubrange(matchRange, with: value)
        }

        return resolved
    }

    /// Resolve a single variable (fieldId or stepId.fieldId) to its actual value
    private func resolveVariable(_ variable: String, from inspectState: InspectState) -> String {
        let trimmed = variable.trimmingCharacters(in: .whitespaces)

        // Check if it's a stepId.fieldId pattern
        if trimmed.contains(".") {
            let components = trimmed.split(separator: ".", maxSplits: 1).map(String.init)
            guard components.count == 2 else {
                return "(invalid variable format)"
            }

            let stepId = components[0]
            let fieldId = components[1]

            // Look up value in specific step
            if let formState = inspectState.guidanceFormInputs[stepId] {
                // Check dropdowns first (most common)
                if let value = formState.dropdowns[fieldId], !value.isEmpty {
                    return value
                }
                // Then radios
                if let value = formState.radios[fieldId], !value.isEmpty {
                    return value
                }
                // Then checkboxes (return Yes/No)
                if let checked = formState.checkboxes[fieldId] {
                    return checked ? "Yes" : "No"
                }
            }

            return "(not set)"
        } else {
            // Simple fieldId - search all steps
            let fieldId = trimmed

            // Search through all form states
            for (_, formState) in inspectState.guidanceFormInputs {
                // Check dropdowns
                if let value = formState.dropdowns[fieldId], !value.isEmpty {
                    return value
                }
                // Check radios
                if let value = formState.radios[fieldId], !value.isEmpty {
                    return value
                }
                // Check checkboxes
                if let checked = formState.checkboxes[fieldId] {
                    return checked ? "Yes" : "No"
                }
            }

            return "(not set)"
        }
    }
}

// MARK: - Processing Countdown View

/// Displays a processing countdown with spinner and custom message
/// Used for steps with `stepType: "processing"` and `processingDuration`
struct ProcessingCountdownView: View {
    let countdown: Int
    let message: String?
    let scaleFactor: CGFloat

    var body: some View {
        VStack(spacing: 8 * scaleFactor) {
            ProgressView()
                .scaleEffect(0.8)

            if let message = message {
                Text(message.replacingOccurrences(of: "{countdown}", with: "\(countdown)"))
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16 * scaleFactor)
    }
}

// MARK: - Step Type Indicator Badge

/// Visual indicator showing the step type (info, confirmation, processing, completion)
/// Can be used as an overlay badge on cards or inline indicators
struct StepTypeIndicator: View {
    let stepType: String
    let scaleFactor: CGFloat
    let style: IndicatorStyle

    enum IndicatorStyle {
        case badge      // Small badge overlay
        case inline     // Inline with text
        case prominent  // Large, featured indicator
    }

    var body: some View {
        HStack(spacing: 4 * scaleFactor) {
            Image(systemName: iconName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(iconColor)

            if style == .inline || style == .prominent {
                Text(displayLabel)
                    .font(.system(size: textSize, weight: .medium))
                    .foregroundColor(iconColor)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(
            Capsule()
                .fill(backgroundColor)
                .overlay(
                    Capsule()
                        .stroke(iconColor.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var iconName: String {
        switch stepType {
        case "confirmation":
            return "checkmark.circle.fill"
        case "processing":
            return "hourglass"
        case "completion":
            return "checkmark.seal.fill"
        default: // "info"
            return "info.circle.fill"
        }
    }

    private var iconColor: Color {
        switch stepType {
        case "confirmation":
            return .orange
        case "processing":
            return .purple
        case "completion":
            return .green
        default: // "info"
            return .blue
        }
    }

    private var backgroundColor: Color {
        iconColor.opacity(0.1)
    }

    private var displayLabel: String {
        switch stepType {
        case "confirmation":
            return "Confirm"
        case "processing":
            return "Processing"
        case "completion":
            return "Complete"
        default:
            return "Info"
        }
    }

    private var iconSize: CGFloat {
        switch style {
        case .badge:
            return 10 * scaleFactor
        case .inline:
            return 12 * scaleFactor
        case .prominent:
            return 16 * scaleFactor
        }
    }

    private var textSize: CGFloat {
        switch style {
        case .inline:
            return 11 * scaleFactor
        case .prominent:
            return 13 * scaleFactor
        default:
            return 0
        }
    }

    private var horizontalPadding: CGFloat {
        switch style {
        case .badge:
            return 6 * scaleFactor
        case .inline:
            return 8 * scaleFactor
        case .prominent:
            return 12 * scaleFactor
        }
    }

    private var verticalPadding: CGFloat {
        switch style {
        case .badge:
            return 4 * scaleFactor
        case .inline:
            return 5 * scaleFactor
        case .prominent:
            return 6 * scaleFactor
        }
    }
}

// MARK: - Guidance Helper Functions

/// Get default button text for step type
func getDefaultButtonText(for stepType: String?) -> String {
    guard let stepType = stepType else { return "Continue" }

    switch stepType {
    case "confirmation":
        return "Confirm"
    case "processing":
        return "Start"
    case "completion":
        return "Continue"
    default:
        return "Continue"
    }
}

/// Check if step has guidance content
func hasGuidanceContent(_ item: InspectConfig.ItemConfig) -> Bool {
    return item.guidanceContent?.isEmpty == false
}

// MARK: - Highlight Chip Styles

/// ViewModifier for highlighting content with chip/badge style that works in both light and dark modes
/// Uses system accent color with high contrast for optimal readability
///
/// **Usage Example:**
/// ```swift
/// Text("5-10 Minutes")
///     .font(.system(size: 14, weight: .semibold, design: .monospaced))
///     .foregroundStyle(.primary)
///     .modifier(HighlightChipStyle(accentColor: .blue, scaleFactor: 1.0))
/// ```
///
/// **Features:**
/// - Automatically adapts to light/dark mode
/// - Uses `.primary` foregroundStyle for proper text contrast
/// - Configurable accent color (defaults to system accent)
/// - Scales proportionally with scaleFactor
/// - Provides depth with subtle shadow
struct HighlightChipStyle: ViewModifier {
    let accentColor: Color
    let scaleFactor: CGFloat

    init(accentColor: Color = .accentColor, scaleFactor: CGFloat = 1.0) {
        self.accentColor = accentColor
        self.scaleFactor = scaleFactor
    }

    func body(content: Content) -> some View {
        content
            .padding(.vertical, 6 * scaleFactor)
            .padding(.horizontal, 12 * scaleFactor)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(accentColor.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(accentColor.opacity(0.6), lineWidth: 1.5)
            )
            .shadow(color: accentColor.opacity(0.1), radius: 2, y: 1)
    }
}

/// ViewModifier for secondary/subtle highlighting with system secondary color
struct SecondaryChipStyle: ViewModifier {
    let secondaryColor: Color
    let scaleFactor: CGFloat

    init(secondaryColor: Color = .secondary, scaleFactor: CGFloat = 1.0) {
        self.secondaryColor = secondaryColor
        self.scaleFactor = scaleFactor
    }

    func body(content: Content) -> some View {
        content
            .padding(.vertical, 6 * scaleFactor)
            .padding(.horizontal, 12 * scaleFactor)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(secondaryColor.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(secondaryColor.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Instruction Banner Component

/// Reusable instruction banner for user guidance across all Inspect presets
/// Displays a semi-transparent banner with text and optional icon at the top of the view
struct InstructionBanner: View {
    let text: String
    let autoDismiss: Bool
    let dismissDelay: Double
    let backgroundColor: Color
    let icon: String?

    @State private var isVisible: Bool = true
    @State private var dismissTimer: Timer?

    init(
        text: String,
        autoDismiss: Bool = true,
        dismissDelay: Double = 5.0,
        backgroundColor: Color = Color.black.opacity(0.7),
        icon: String? = nil
    ) {
        self.text = text
        self.autoDismiss = autoDismiss
        self.dismissDelay = dismissDelay
        self.backgroundColor = backgroundColor
        self.icon = icon
    }

    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                if let iconName = icon {
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }

                Text(text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Spacer()

                // Manual dismiss button
                Button(action: dismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Dismiss instruction")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                backgroundColor
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: isVisible)
            .onAppear {
                if autoDismiss {
                    startDismissTimer()
                }
            }
            .onDisappear {
                dismissTimer?.invalidate()
            }
        }
    }

    /// Dismiss the banner with animation
    func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        dismissTimer?.invalidate()
    }

    /// Start auto-dismiss timer
    private func startDismissTimer() {
        dismissTimer = Timer.scheduledTimer(withTimeInterval: dismissDelay, repeats: false) { _ in
            dismiss()
        }
    }
}

// MARK: - Safe Array Access Extension

// MARK: - Status Monitoring Components

/// Status badge showing binary or multi-state status with icon and color
/// Used for compliance checks, service status, feature states
struct StatusBadgeView: View {
    let label: String
    let state: String
    let icon: String?
    let autoColor: Bool
    let customColor: Color?
    let scaleFactor: CGFloat

    private var stateColor: Color {
        if let customColor = customColor {
            return customColor
        }

        if !autoColor {
            return .secondary
        }

        // Auto-color based on semantic state
        let lowercaseState = state.lowercased()
        switch lowercaseState {
        case "enabled", "active", "pass", "success", "valid", "enrolled", "connected", "on", "true", "yes":
            return Color(hex: "#34C759") ?? .green
        case "disabled", "inactive", "fail", "failure", "invalid", "unenrolled", "disconnected", "off", "false", "no":
            return Color(hex: "#FF3B30") ?? .red
        case "pending", "in-progress", "waiting", "unknown", "partial":
            return Color(hex: "#FF9F0A") ?? .orange
        default:
            return .secondary
        }
    }

    private var defaultIcon: String {
        let lowercaseState = state.lowercased()
        switch lowercaseState {
        case "enabled", "active", "pass", "success", "valid", "enrolled", "connected", "on", "true", "yes":
            return "checkmark.circle.fill"
        case "disabled", "inactive", "fail", "failure", "invalid", "unenrolled", "disconnected", "off", "false", "no":
            return "xmark.circle.fill"
        case "pending", "in-progress", "waiting":
            return "clock.fill"
        case "unknown", "partial":
            return "questionmark.circle.fill"
        default:
            return "circle.fill"
        }
    }

    var body: some View {
        let _ = writeLog("🟡 VIEW: StatusBadgeView rendering label='\(label)' state='\(state)' color=\(stateColor)", logLevel: .debug)

        return HStack(spacing: 8 * scaleFactor) {
            Image(systemName: icon ?? defaultIcon)
                .font(.system(size: 16 * scaleFactor))
                .foregroundColor(stateColor)

            VStack(alignment: .leading, spacing: 2 * scaleFactor) {
                Text(label)
                    .font(.system(size: 13 * scaleFactor, weight: .medium))
                    .foregroundColor(.primary)

                Text(state)
                    .font(.system(size: 12 * scaleFactor))
                    .foregroundColor(stateColor)
                    .fontWeight(.semibold)
            }

            Spacer(minLength: 0)
        }
        .frame(minWidth: 60 * scaleFactor, alignment: .leading)
        .padding(.horizontal, 12 * scaleFactor)
        .padding(.vertical, 10 * scaleFactor)
        .background(
            RoundedRectangle(cornerRadius: 8 * scaleFactor)
                .fill(stateColor.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8 * scaleFactor)
                .stroke(stateColor.opacity(0.3), lineWidth: 1)
        )
    }
}

/// Comparison table showing expected vs actual values
/// Used for configuration validation, version checks, server comparisons
struct ComparisonTableView: View {
    let label: String
    let expected: String
    let actual: String
    let expectedLabel: String
    let actualLabel: String
    let expectedIcon: String?
    let actualIcon: String?
    let comparisonStyle: String?
    let highlightCells: Bool
    let autoColor: Bool
    let customColor: Color?
    let expectedColor: Color?
    let actualColor: Color?
    let scaleFactor: CGFloat

    /// Smart comparison that handles common edge cases
    private var isMatch: Bool {
        let expectedNorm = normalizeForComparison(expected)
        let actualNorm = normalizeForComparison(actual)
        return expectedNorm == actualNorm
    }

    /// Normalize strings for flexible comparison
    /// Handles: URL protocols, trailing slashes, case differences
    private func normalizeForComparison(_ value: String) -> String {
        var normalized = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove common URL protocols
        let protocols = ["https://", "http://", "ftp://", "ftps://"]
        for proto in protocols {
            if normalized.hasPrefix(proto) {
                normalized = String(normalized.dropFirst(proto.count))
                break
            }
        }

        // Remove trailing slashes
        while normalized.hasSuffix("/") {
            normalized = String(normalized.dropLast())
        }

        return normalized
    }

    private var comparisonColor: Color {
        if let customColor = customColor {
            return customColor
        }

        if !autoColor {
            return .secondary
        }

        return isMatch ? (Color(hex: "#34C759") ?? .green) : (Color(hex: "#FF3B30") ?? .red)
    }

    /// Effective color for expected column (with override support)
    private var effectiveExpectedColor: Color {
        if let expectedColor = expectedColor {
            return expectedColor
        }
        // Default to secondary (neutral) for expected column
        return .secondary
    }

    /// Effective color for actual column (with override support)
    private var effectiveActualColor: Color {
        if let actualColor = actualColor {
            return actualColor
        }
        // Default to match-based color
        return comparisonColor
    }

    /// Auto-assign SF Symbol icon based on match state or color semantics when not explicitly provided
    private func getIconForState(isExpected: Bool) -> String {
        if isExpected {
            // Expected value icon (always neutral)
            return "circle.fill"
        } else {
            // Actual value icon: Consider color override semantics first
            if let actualColor = actualColor {
                // When actualColor is specified, choose icon based on color semantics
                // This allows migration scenarios to show green/checkmark for "new" state
                // even when values don't match
                let nsColor = NSColor(actualColor)
                let red = nsColor.redComponent
                let green = nsColor.greenComponent
                let blue = nsColor.blueComponent

                // Check for standard swiftDialog colors by RGB components
                if abs(red - 0.204) < 0.01 && abs(green - 0.780) < 0.01 && abs(blue - 0.349) < 0.01 {
                    // Green #34C759 (0.204, 0.780, 0.349) → success/checkmark
                    return "checkmark.circle.fill"
                } else if abs(red - 1.0) < 0.01 && abs(green - 0.231) < 0.01 && abs(blue - 0.188) < 0.01 {
                    // Red #FF3B30 (1.0, 0.231, 0.188) → error/X
                    return "xmark.circle.fill"
                } else if abs(red - 1.0) < 0.01 && abs(green - 0.624) < 0.01 && abs(blue - 0.039) < 0.01 {
                    // Orange #FF9F0A (1.0, 0.624, 0.039) → warning
                    return "exclamationmark.triangle.fill"
                } else {
                    // Other colors → generic circle
                    return "circle.fill"
                }
            }

            // Default: icon based on match state
            return isMatch ? "checkmark.circle.fill" : "xmark.circle.fill"
        }
    }

    /// Render stacked layout (existing behavior)
    private var stackedLayout: some View {
        VStack(alignment: .leading, spacing: 8 * scaleFactor) {
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 13 * scaleFactor, weight: .semibold))
                    .foregroundColor(.primary)
            }

            VStack(spacing: 6 * scaleFactor) {
                // Expected row
                HStack {
                    Text(expectedLabel + ":")
                        .font(.system(size: 12 * scaleFactor, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 80 * scaleFactor, alignment: .leading)

                    Text(expected)
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8 * scaleFactor)
                        .padding(.vertical, 4 * scaleFactor)
                        .background(
                            RoundedRectangle(cornerRadius: 4 * scaleFactor)
                                .fill(Color.secondary.opacity(0.1))
                        )

                    Spacer()
                }

                // Actual row
                HStack {
                    Text(actualLabel + ":")
                        .font(.system(size: 12 * scaleFactor, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 80 * scaleFactor, alignment: .leading)

                    Text(actual)
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundColor(comparisonColor)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8 * scaleFactor)
                        .padding(.vertical, 4 * scaleFactor)
                        .background(
                            RoundedRectangle(cornerRadius: 4 * scaleFactor)
                                .fill(comparisonColor.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4 * scaleFactor)
                                .stroke(comparisonColor.opacity(0.3), lineWidth: 1)
                        )

                    Image(systemName: isMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 14 * scaleFactor))
                        .foregroundColor(comparisonColor)

                    Spacer()
                }
            }
        }
        .padding(12 * scaleFactor)
        .background(
            RoundedRectangle(cornerRadius: 8 * scaleFactor)
                .fill(Color(.textBackgroundColor).opacity(0.5))
        )
    }

    /// Render columns layout (A | B side-by-side)
    private var columnsLayout: some View {
        VStack(alignment: .leading, spacing: 8 * scaleFactor) {
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 13 * scaleFactor, weight: .semibold))
                    .foregroundColor(.primary)
            }

            HStack(spacing: 12 * scaleFactor) {
                // Expected column
                VStack(spacing: 4 * scaleFactor) {
                    Text(expectedLabel)
                        .font(.system(size: 11 * scaleFactor, weight: .medium))
                        .foregroundColor(.secondary)

                    VStack(spacing: 6 * scaleFactor) {
                        if let icon = expectedIcon {
                            Image(systemName: icon)
                                .font(.system(size: 24 * scaleFactor))
                                .foregroundColor(expectedColor != nil ? effectiveExpectedColor : .secondary)
                                .frame(height: 24 * scaleFactor)
                        }

                        Text(expected)
                            .font(.system(size: highlightCells ? 14 * scaleFactor : 12 * scaleFactor, weight: highlightCells ? .bold : .regular))
                            .foregroundColor(expectedColor != nil ? effectiveExpectedColor : .primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, minHeight: 60 * scaleFactor, alignment: .center)
                    .padding(10 * scaleFactor)
                    .background(
                        RoundedRectangle(cornerRadius: 6 * scaleFactor)
                            .fill(expectedColor != nil ? effectiveExpectedColor.opacity(highlightCells ? 0.2 : 0.1) : Color.secondary.opacity(highlightCells ? 0.15 : 0.1))
                    )
                }
                .frame(maxWidth: .infinity)

                // Divider
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 1)

                // Actual column
                VStack(spacing: 4 * scaleFactor) {
                    Text(actualLabel)
                        .font(.system(size: 11 * scaleFactor, weight: .medium))
                        .foregroundColor(.secondary)

                    VStack(spacing: 6 * scaleFactor) {
                        if let icon = actualIcon {
                            Image(systemName: icon)
                                .font(.system(size: 24 * scaleFactor))
                                .foregroundColor(effectiveActualColor)
                                .frame(height: 24 * scaleFactor)
                        } else {
                            // Auto-assign icon based on match
                            Image(systemName: getIconForState(isExpected: false))
                                .font(.system(size: 24 * scaleFactor))
                                .foregroundColor(effectiveActualColor)
                                .frame(height: 24 * scaleFactor)
                        }

                        Text(actual)
                            .font(.system(size: highlightCells ? 14 * scaleFactor : 12 * scaleFactor, weight: highlightCells ? .bold : .semibold))
                            .foregroundColor(effectiveActualColor)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, minHeight: 60 * scaleFactor, alignment: .center)
                    .padding(10 * scaleFactor)
                    .background(
                        RoundedRectangle(cornerRadius: 6 * scaleFactor)
                            .fill(effectiveActualColor.opacity(highlightCells ? 0.2 : 0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6 * scaleFactor)
                            .stroke(effectiveActualColor.opacity(highlightCells ? 0.4 : 0.3), lineWidth: highlightCells ? 2 : 1.5)
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12 * scaleFactor)
        .background(
            RoundedRectangle(cornerRadius: 8 * scaleFactor)
                .fill(Color(.textBackgroundColor).opacity(0.5))
        )
    }

    var body: some View {
        let _ = writeLog("🟡 VIEW: ComparisonTableView rendering label='\(label)' actual='\(actual)' match=\(isMatch) color=\(comparisonColor) style=\(comparisonStyle ?? "stacked")", logLevel: .debug)

        return Group {
            if comparisonStyle == "columns" {
                columnsLayout
            } else {
                stackedLayout
            }
        }
    }
}

/// Comparison group for organizing related comparisons under collapsible categories
/// Used for CIS compliance, security baselines, multi-section configurations
struct ComparisonGroupView: View {
    let category: String
    let comparisons: [InspectConfig.GuidanceContent]
    let scaleFactor: CGFloat
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8 * scaleFactor) {
            // Category header (collapsible)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 8 * scaleFactor) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12 * scaleFactor, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 12 * scaleFactor)

                    Text(category)
                        .font(.system(size: 14 * scaleFactor, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    // Summary badge (count of items)
                    Text("\(comparisons.count)")
                        .font(.system(size: 11 * scaleFactor, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6 * scaleFactor)
                        .padding(.vertical, 2 * scaleFactor)
                        .background(
                            RoundedRectangle(cornerRadius: 4 * scaleFactor)
                                .fill(Color.secondary.opacity(0.15))
                        )
                }
                .padding(.horizontal, 12 * scaleFactor)
                .padding(.vertical, 10 * scaleFactor)
                .background(
                    RoundedRectangle(cornerRadius: 8 * scaleFactor)
                        .fill(Color(.textBackgroundColor).opacity(0.3))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // Expandable comparison items
            if isExpanded {
                VStack(spacing: 8 * scaleFactor) {
                    ForEach(Array(comparisons.enumerated()), id: \.offset) { index, comparison in
                        if comparison.type == "comparison-table",
                           let label = comparison.label ?? comparison.content,
                           let expected = comparison.expected,
                           let actual = comparison.actual {

                            let autoColor = comparison.autoColor ?? true
                            let customColor: Color? = {
                                if let colorHex = comparison.color {
                                    return Color(hex: colorHex)
                                }
                                return nil
                            }()

                            ComparisonTableView(
                                label: label,
                                expected: expected,
                                actual: actual,
                                expectedLabel: comparison.expectedLabel ?? "Expected",
                                actualLabel: comparison.actualLabel ?? "Actual",
                                expectedIcon: comparison.expectedIcon,
                                actualIcon: comparison.actualIcon,
                                comparisonStyle: comparison.comparisonStyle,
                                highlightCells: comparison.highlightCells ?? false,
                                autoColor: autoColor,
                                customColor: customColor,
                                expectedColor: comparison.expectedColor.flatMap { Color(hex: $0) },
                                actualColor: comparison.actualColor.flatMap { Color(hex: $0) },
                                scaleFactor: scaleFactor
                            )
                            .id("comparison-group-\(category)-\(index)-\(actual)")
                        }
                    }
                }
                .padding(.leading, 20 * scaleFactor)
                .transition(.opacity)
            }
        }
    }
}

/// Phase tracker showing multi-step progress
/// Used for workflows like MDM migration, software installation, onboarding
struct PhaseTrackerView: View {
    let currentPhase: Int
    let phases: [String]
    let style: String
    let scaleFactor: CGFloat

    private var defaultPhaseLabels: [String] {
        ["Prepare", "Execute", "Verify", "Complete"]
    }

    private var phaseLabels: [String] {
        phases.isEmpty ? defaultPhaseLabels : phases
    }

    var body: some View {
        if style == "progress" {
            progressBarStyle
        } else if style == "checklist" {
            checklistStyle
        } else {
            stepperStyle // default
        }
    }

    // Stepper style - horizontal numbered steps
    private var stepperStyle: some View {
        HStack(spacing: 0) {
            ForEach(0..<phaseLabels.count, id: \.self) { index in
                let phaseNum = index + 1
                let isActive = phaseNum == currentPhase
                let isCompleted = phaseNum < currentPhase

                HStack(spacing: 8 * scaleFactor) {
                    // Phase circle
                    ZStack {
                        Circle()
                            .fill(isCompleted ? Color(hex: "#34C759") ?? .green :
                                  isActive ? Color(hex: "#FF9F0A") ?? .orange :
                                  Color.secondary.opacity(0.3))
                            .frame(width: 28 * scaleFactor, height: 28 * scaleFactor)

                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12 * scaleFactor, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(phaseNum)")
                                .font(.system(size: 12 * scaleFactor, weight: .bold))
                                .foregroundColor(isActive ? .white : .secondary)
                        }
                    }

                    // Phase label
                    Text(phaseLabels[index])
                        .font(.system(size: 11 * scaleFactor, weight: isActive ? .semibold : .regular))
                        .foregroundColor(isActive ? .primary : .secondary)

                    // Connector line (except for last item)
                    if index < phaseLabels.count - 1 {
                        Rectangle()
                            .fill(phaseNum < currentPhase ? (Color(hex: "#34C759") ?? .green) : Color.secondary.opacity(0.3))
                            .frame(width: 20 * scaleFactor, height: 2 * scaleFactor)
                    }
                }
            }
        }
        .padding(12 * scaleFactor)
    }

    // Progress bar style
    private var progressBarStyle: some View {
        VStack(alignment: .leading, spacing: 8 * scaleFactor) {
            HStack {
                Text("Phase \(currentPhase) of \(phaseLabels.count)")
                    .font(.system(size: 12 * scaleFactor, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                Text(phaseLabels[safe: currentPhase - 1] ?? "")
                    .font(.system(size: 12 * scaleFactor, weight: .semibold))
                    .foregroundColor(.primary)
            }

            ProgressView(value: Double(currentPhase), total: Double(phaseLabels.count))
                .progressViewStyle(LinearProgressViewStyle())
                .tint(Color(hex: "#FF9F0A") ?? .orange)
        }
        .padding(12 * scaleFactor)
    }

    // Checklist style - vertical checkboxes
    private var checklistStyle: some View {
        VStack(alignment: .leading, spacing: 8 * scaleFactor) {
            ForEach(0..<phaseLabels.count, id: \.self) { index in
                let phaseNum = index + 1
                let isActive = phaseNum == currentPhase
                let isCompleted = phaseNum < currentPhase

                HStack(spacing: 8 * scaleFactor) {
                    Image(systemName: isCompleted ? "checkmark.square.fill" :
                          isActive ? "square.fill" :
                          "square")
                        .font(.system(size: 16 * scaleFactor))
                        .foregroundColor(isCompleted ? (Color(hex: "#34C759") ?? .green) :
                                       isActive ? (Color(hex: "#FF9F0A") ?? .orange) :
                                       .secondary)

                    Text(phaseLabels[index])
                        .font(.system(size: 12 * scaleFactor, weight: isActive ? .semibold : .regular))
                        .foregroundColor(isActive ? .primary : .secondary)

                    Spacer()
                }
            }
        }
        .padding(12 * scaleFactor)
    }
}

// MARK: - AsyncImageView (Shared Component)

/// Asynchronous image loader with loading states and fallback support
/// Extracted from Preset8 for reuse across all presets
struct AsyncImageView<Fallback: View>: View {
    let iconPath: String
    let basePath: String?
    let maxWidth: CGFloat
    let maxHeight: CGFloat
    let fallback: () -> Fallback

    @State private var imageState: ImageLoadState = .loading
    @State private var loadedImage: NSImage?

    enum ImageLoadState: Equatable {
        case loading
        case loaded(NSImage)
        case failed

        static func == (lhs: ImageLoadState, rhs: ImageLoadState) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading), (.failed, .failed):
                return true
            case (.loaded(let lhsImage), .loaded(let rhsImage)):
                return lhsImage == rhsImage
            default:
                return false
            }
        }
    }

    init(iconPath: String, basePath: String?, maxWidth: CGFloat, maxHeight: CGFloat, @ViewBuilder fallback: @escaping () -> Fallback) {
        self.iconPath = iconPath
        self.basePath = basePath
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.fallback = fallback
    }

    var body: some View {
        Group {
            switch imageState {
            case .loading:
                // Loading state - gradient background with spinner
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.gray.opacity(0.3),
                            Color.gray.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)

                        Text("Loading...")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .frame(width: maxWidth, height: maxHeight)
                .clipped()

            case .loaded(let nsImage):
                // Successfully loaded image
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: maxWidth, height: maxHeight)
                    .clipped()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))

            case .failed:
                // Failed to load, show fallback
                fallback()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: imageState)
        .onAppear {
            loadImageAsync()
        }
        .onChange(of: iconPath) { _, _ in
            imageState = .loading
            loadImageAsync()
        }
    }

    private func loadImageAsync() {
        Task {
            await loadImage()
        }
    }

    @MainActor
    private func loadImage() async {
        // Resolve the full path
        let fullPath: String
        if iconPath.hasPrefix("/") {
            // Absolute path
            fullPath = iconPath
        } else if let basePath = basePath {
            // Relative path with base
            fullPath = (basePath as NSString).appendingPathComponent(iconPath)
        } else {
            // Relative path without base
            fullPath = iconPath
        }

        // Add small delay to show loading state
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Try to load the image
        if let nsImage = NSImage(contentsOfFile: fullPath) {
            withAnimation(.easeInOut(duration: 0.3)) {
                imageState = .loaded(nsImage)
            }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                imageState = .failed
            }
        }
    }
}

// MARK: - ImageCarouselView (Shared Component)

/// Interactive image carousel component with navigation controls
/// Supports arrow buttons, dot indicators, captions, and auto-advance
struct ImageCarouselView: View {
    // Required properties
    let images: [String]
    let iconBasePath: String?
    let scaleFactor: CGFloat

    // Layout properties
    let imageWidth: CGFloat
    let imageHeight: CGFloat
    let imageShape: String

    // Navigation properties
    let showDots: Bool
    let showArrows: Bool
    let captions: [String]?

    // Behavior properties
    let autoAdvance: Bool
    let autoAdvanceDelay: Double
    let transitionStyle: String

    // State
    @State private var currentIndex: Int
    @State private var autoAdvanceTimer: Timer?
    @StateObject private var iconCache = PresetIconCache()

    init(
        images: [String],
        iconBasePath: String?,
        scaleFactor: CGFloat,
        imageWidth: CGFloat = 400,
        imageHeight: CGFloat = 300,
        imageShape: String = "rectangle",
        showDots: Bool = true,
        showArrows: Bool = true,
        captions: [String]? = nil,
        autoAdvance: Bool = false,
        autoAdvanceDelay: Double = 3.0,
        transitionStyle: String = "slide",
        currentIndex: Int = 0
    ) {
        self.images = images
        self.iconBasePath = iconBasePath
        self.scaleFactor = scaleFactor
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.imageShape = imageShape
        self.showDots = showDots
        self.showArrows = showArrows
        self.captions = captions
        self.autoAdvance = autoAdvance
        self.autoAdvanceDelay = autoAdvanceDelay
        self.transitionStyle = transitionStyle
        self._currentIndex = State(initialValue: min(max(0, currentIndex), images.count - 1))
    }

    var body: some View {
        VStack(spacing: 12 * scaleFactor) {
            // Main carousel container
            ZStack {
                // Background with rounded corners
                RoundedRectangle(cornerRadius: 12 * scaleFactor)
                    .fill(Color.gray.opacity(0.1))

                // Current image
                carouselImageView()

                // Navigation arrows (overlays)
                if showArrows && images.count > 1 {
                    HStack {
                        // Previous button
                        Button(action: previousImage) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 32 * scaleFactor))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(currentIndex == 0)
                        .opacity(currentIndex == 0 ? 0.3 : 1.0)
                        .padding(.leading, 16 * scaleFactor)

                        Spacer()

                        // Next button
                        Button(action: nextImage) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 32 * scaleFactor))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(currentIndex == images.count - 1)
                        .opacity(currentIndex == images.count - 1 ? 0.3 : 1.0)
                        .padding(.trailing, 16 * scaleFactor)
                    }
                }
            }
            .frame(width: imageWidth * scaleFactor, height: imageHeight * scaleFactor)
            .clipShape(applyImageShape())

            // Dot indicators
            if showDots && images.count > 1 {
                dotIndicators()
            }

            // Caption
            if let captions = captions,
               let caption = captions[safe: currentIndex],
               !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 13 * scaleFactor, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16 * scaleFactor)
                    .transition(.opacity)
            }
        }
        .onAppear {
            if autoAdvance && images.count > 1 {
                startAutoAdvance()
            }
        }
        .onDisappear {
            stopAutoAdvance()
        }
    }

    // MARK: - Image View

    @ViewBuilder
    private func carouselImageView() -> some View {
        if images.indices.contains(currentIndex) {
            let imagePath = images[currentIndex]

            AsyncImageView(
                iconPath: imagePath,
                basePath: iconBasePath,
                maxWidth: imageWidth * scaleFactor,
                maxHeight: imageHeight * scaleFactor,
                fallback: {
                    // Fallback view for failed image load
                    ZStack {
                        Color.gray.opacity(0.2)

                        VStack(spacing: 8 * scaleFactor) {
                            Image(systemName: "photo")
                                .font(.system(size: 40 * scaleFactor))
                                .foregroundColor(.secondary)

                            Text("Image not found")
                                .font(.system(size: 12 * scaleFactor))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            )
            .transition(getTransition())
            .id("carousel-image-\(currentIndex)-\(imagePath)")
        }
    }

    // MARK: - Dot Indicators

    private func dotIndicators() -> some View {
        HStack(spacing: 8 * scaleFactor) {
            ForEach(0..<images.count, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(
                        width: (index == currentIndex ? 8 : 6) * scaleFactor,
                        height: (index == currentIndex ? 8 : 6) * scaleFactor
                    )
                    .scaleEffect(index == currentIndex ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentIndex)
                    .onTapGesture {
                        navigateToIndex(index)
                    }
            }
        }
        .padding(.vertical, 8 * scaleFactor)
    }

    // MARK: - Navigation

    private func previousImage() {
        guard currentIndex > 0 else { return }
        withAnimation(getAnimationType()) {
            currentIndex -= 1
        }
        resetAutoAdvanceTimer()
    }

    private func nextImage() {
        guard currentIndex < images.count - 1 else { return }
        withAnimation(getAnimationType()) {
            currentIndex += 1
        }
        resetAutoAdvanceTimer()
    }

    private func navigateToIndex(_ index: Int) {
        guard index != currentIndex && images.indices.contains(index) else { return }
        withAnimation(getAnimationType()) {
            currentIndex = index
        }
        resetAutoAdvanceTimer()
    }

    // MARK: - Auto-Advance

    private func startAutoAdvance() {
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: autoAdvanceDelay, repeats: true) { _ in
            if currentIndex < images.count - 1 {
                withAnimation(getAnimationType()) {
                    currentIndex += 1
                }
            } else {
                // Loop back to start
                withAnimation(getAnimationType()) {
                    currentIndex = 0
                }
            }
        }
    }

    private func stopAutoAdvance() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
    }

    private func resetAutoAdvanceTimer() {
        if autoAdvance {
            stopAutoAdvance()
            startAutoAdvance()
        }
    }

    // MARK: - Helpers

    private func getTransition() -> AnyTransition {
        switch transitionStyle.lowercased() {
        case "fade":
            return .opacity
        case "slide":
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        default:
            return .opacity
        }
    }

    private func getAnimationType() -> Animation {
        switch transitionStyle.lowercased() {
        case "slide":
            return .spring(response: 0.4, dampingFraction: 0.8)
        case "fade":
            return .easeInOut(duration: 0.3)
        default:
            return .easeInOut(duration: 0.3)
        }
    }

    private func applyImageShape() -> some Shape {
        switch imageShape.lowercased() {
        case "circle":
            return AnyShape(Circle())
        case "square":
            return AnyShape(RoundedRectangle(cornerRadius: 8 * scaleFactor))
        default: // "rectangle"
            return AnyShape(RoundedRectangle(cornerRadius: 12 * scaleFactor))
        }
    }
}

// Helper for type-erased shapes
private struct AnyShape: Shape {
    private let _path: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

/// Extension to provide safe array subscripting that returns nil instead of crashing on out-of-bounds access
extension Array {
    /// Safe subscript that returns nil instead of crashing on out-of-bounds access
    /// Usage: if let item = array[safe: index] { ... }
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - List Item Status Icon

/// List item status icon view - renders SF Symbol with optional color
/// Shared component for dynamic status icons in list items (Inspect presets & future Dialog --listitem)
///
/// Supports formats:
/// - Simple icon: "shield"
/// - Icon with color: "shield.fill-green"
/// - Full SF syntax: "sf=shield.fill,colour=green"
///
/// Reuses IconView for rendering (inherits all SF Symbol + color capabilities)
struct ListItemStatusIconView: View {
    let status: String?           // Status string (e.g., "shield.fill-green" or "sf=shield,colour=blue")
    let size: CGFloat             // Icon size
    let defaultIcon: String?      // Fallback icon if status is nil

    var body: some View {
        Group {
            if let statusIcon = resolvedIconString {
                IconView(image: statusIcon, sfPaddingEnabled: false, corners: false)
                    .frame(width: size, height: size)
            } else if let fallback = defaultIcon {
                IconView(image: fallback, sfPaddingEnabled: false, corners: false)
                    .frame(width: size, height: size)
            } else {
                // No icon to display
                EmptyView()
            }
        }
    }

    /// Resolves status string into IconView-compatible format
    /// Converts "icon-color" syntax to "sf=icon,colour=color"
    private var resolvedIconString: String? {
        guard let status = status, !status.isEmpty else { return nil }

        // Already in SF syntax format
        if status.hasPrefix("sf=") {
            return status
        }

        // Check for "icon-color" format (e.g., "shield.fill-green")
        if let dashIndex = status.lastIndex(of: "-") {
            let icon = String(status[..<dashIndex])
            let color = String(status[status.index(after: dashIndex)...])

            // Convert to SF syntax that IconView understands
            return "sf=\(icon),colour=\(color)"
        }

        // Plain icon name without color
        return "sf=\(status)"
    }
}

// MARK: - Info Popover Helper

/// Helper view that displays an info icon button that shows a popover with help text
struct InfoPopoverButton: View {
    let helpText: String
    let scaleFactor: Double
    @State private var showingPopover = false

    var body: some View {
        Button(action: {
            showingPopover.toggle()
        }) {
            Image(systemName: "info.circle")
                .font(.system(size: 14 * scaleFactor))
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPopover, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("Help")
                        .font(.headline)
                }

                Text(helpText)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Close") {
                    showingPopover = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: 300)
        }
        .help(helpText)
    }
}

// MARK: - Button Helpers

/// Handle button action for inline buttons in guidance content
private func handleButtonAction(block: InspectConfig.GuidanceContent, itemId: String, inspectState: InspectState) {
    guard let action = block.action else {
        writeLog("Button clicked but no action defined", logLevel: .error)
        return
    }

    switch action {
    case "url":
        if let urlString = block.url, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
            writeLog("Button: Opened URL \(urlString)", logLevel: .info)
            inspectState.writeToInteractionLog("button:\(itemId):\(block.content ?? "button"):url:\(urlString)")
        } else {
            writeLog("Button: Invalid URL for action='url'", logLevel: .error)
        }

    case "shell":
        if let shellCommand = block.shell {
            // Execute shell command in background
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                task.launchPath = "/bin/bash"
                task.arguments = ["-c", shellCommand]

                do {
                    try task.run()
                    writeLog("Button: Executed shell command: \(shellCommand)", logLevel: .info)
                    DispatchQueue.main.async {
                        inspectState.writeToInteractionLog("button:\(itemId):\(block.content ?? "button"):shell:\(shellCommand)")
                    }
                } catch {
                    writeLog("Button: Failed to execute shell command: \(error)", logLevel: .error)
                }
            }
        } else {
            writeLog("Button: No shell command specified for action='shell'", logLevel: .error)
        }

    case "custom":
        // Write to interaction log for script monitoring
        inspectState.writeToInteractionLog("button:\(itemId):\(block.content ?? "button"):custom")
        writeLog("Button: Custom action triggered for '\(block.content ?? "button")'", logLevel: .info)

    default:
        writeLog("Button: Unknown action '\(action)'", logLevel: .error)
    }
}

// MARK: - Compliance Dashboard Components (Migrated from Preset5)

/// Compliance dashboard header with overall statistics
/// Migrated from Preset5 header for use in Preset6 guidance content
struct ComplianceDashboardHeader: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let passed: Int
    let failed: Int
    let scaleFactor: CGFloat
    let colorThresholds: InspectConfig.ColorThresholds

    private var total: Int {
        passed + failed
    }

    private var score: Double {
        guard total > 0 else { return 0.0 }
        return Double(passed) / Double(total)
    }

    private var statusText: String {
        colorThresholds.getLabel(for: score)
    }

    private var statusColor: Color {
        colorThresholds.getColor(for: score)
    }

    var body: some View {
        VStack(spacing: 20 * scaleFactor) {
            // Icon and Title
            HStack(spacing: 20 * scaleFactor) {
                // Icon
                if let iconName = icon {
                    if iconName.hasPrefix("sf=") {
                        let sfSymbol = String(iconName.dropFirst(3))
                        Image(systemName: sfSymbol)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64 * scaleFactor, height: 64 * scaleFactor)
                            .foregroundColor(.accentColor)
                    } else {
                        Image(systemName: iconName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64 * scaleFactor, height: 64 * scaleFactor)
                            .foregroundColor(.accentColor)
                    }
                }

                VStack(alignment: .leading, spacing: 4 * scaleFactor) {
                    Text(title)
                        .font(.system(size: 22 * scaleFactor, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14 * scaleFactor))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                // Status badge
                Text(statusText)
                    .font(.system(size: 12 * scaleFactor, weight: .semibold))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 16 * scaleFactor)
                    .padding(.vertical, 8 * scaleFactor)
                    .background(
                        Capsule()
                            .fill(statusColor.opacity(0.15))
                    )
            }

            // Progress Bar Section
            VStack(spacing: 12 * scaleFactor) {
                // Stats row
                HStack(spacing: 32 * scaleFactor) {
                    // Passed
                    HStack(spacing: 8 * scaleFactor) {
                        Circle()
                            .fill(colorThresholds.getPositiveColor())
                            .frame(width: 8 * scaleFactor, height: 8 * scaleFactor)
                        Text("Passed")
                            .font(.system(size: 11 * scaleFactor, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("\(passed)")
                            .font(.system(size: 16 * scaleFactor, weight: .bold, design: .monospaced))
                            .foregroundColor(colorThresholds.getPositiveColor())
                    }

                    Spacer()

                    // Overall percentage
                    Text("\(Int(score * 100))%")
                        .font(.system(size: 20 * scaleFactor, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Spacer()

                    // Failed
                    HStack(spacing: 8 * scaleFactor) {
                        Text("\(failed)")
                            .font(.system(size: 16 * scaleFactor, weight: .bold, design: .monospaced))
                            .foregroundColor(colorThresholds.getNegativeColor())
                        Text("Failed")
                            .font(.system(size: 11 * scaleFactor, weight: .medium))
                            .foregroundColor(.secondary)
                        Circle()
                            .fill(colorThresholds.getNegativeColor())
                            .frame(width: 8 * scaleFactor, height: 8 * scaleFactor)
                    }
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background bar
                        RoundedRectangle(cornerRadius: 6 * scaleFactor)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 12 * scaleFactor)

                        // Progress bar
                        RoundedRectangle(cornerRadius: 6 * scaleFactor)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        statusColor,
                                        statusColor.opacity(0.8)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, geometry.size.width * score), height: 12 * scaleFactor)
                            .animation(.spring(response: 0.8, dampingFraction: 0.6), value: score)
                    }
                }
                .frame(height: 12 * scaleFactor)

                // Total count
                Text("Total: \(total) items")
                    .font(.system(size: 10 * scaleFactor, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 32 * scaleFactor)
        .padding(.vertical, 20 * scaleFactor)
        .background(
            RoundedRectangle(cornerRadius: 12 * scaleFactor)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12 * scaleFactor)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
        )
        .id("compliance-header-\(passed)-\(failed)")  // Force re-render on data change
    }
}

/// Circular progress indicator with percentage display
/// Used in compliance cards to show category completion percentage
struct CircularProgressView: View {
    let progress: Double  // 0.0 to 1.0
    let color: Color
    let scaleFactor: CGFloat
    @State private var animateProgress = false

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: 4 * scaleFactor)
                .frame(width: 60 * scaleFactor, height: 60 * scaleFactor)

            // Progress circle
            Circle()
                .trim(from: 0, to: animateProgress ? progress : 0)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 4 * scaleFactor, lineCap: .round)
                )
                .frame(width: 60 * scaleFactor, height: 60 * scaleFactor)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.6), value: animateProgress)

            // Percentage text
            Text("\(Int(progress * 100))%")
                .font(.system(size: 12 * scaleFactor, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.1)) {
                animateProgress = true
            }
        }
        .id("circular-progress-\(progress)")  // Force re-render on progress change
    }
}

/// Compliance card displaying category metrics with circular progress
/// Migrated from Preset5 CategoryCardView for use in Preset6 guidance content
struct ComplianceCardView: View {
    let categoryName: String
    let passed: Int
    let total: Int
    let icon: String?
    let checkDetails: String?  // Optional: newline-separated check items to display inside card
    let scaleFactor: CGFloat
    let colorThresholds: InspectConfig.ColorThresholds

    private var score: Double {
        guard total > 0 else { return 0.0 }
        return Double(passed) / Double(total)
    }

    private var statusText: String {
        colorThresholds.getLabel(for: score)
    }

    private var statusColor: Color {
        colorThresholds.getColor(for: score)
    }

    /// Parse a check item to extract symbol, text, and status
    /// Format: "pass:Description" or "fail:Description"
    /// Returns: (symbol: String, text: String, isPassed: Bool, isFailed: Bool)
    private func parseCheckItem(_ item: String) -> (symbol: String, text: String, isPassed: Bool, isFailed: Bool) {
        let trimmed = item.trimmingCharacters(in: .whitespaces)

        // Check for keyword prefixes (ASCII-safe, shell-independent)
        if trimmed.lowercased().hasPrefix("pass:") {
            let text = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            return ("✓", text, true, false)
        }

        if trimmed.lowercased().hasPrefix("fail:") {
            let text = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            return ("✗", text, false, true)
        }

        // No status keyword - use neutral bullet point
        return ("•", trimmed, false, false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with category title and status badge
            HStack {
                HStack(spacing: 10 * scaleFactor) {
                    // Category icon (LARGER, more prominent)
                    if let iconName = icon {
                        Image(systemName: iconName)
                            .font(.system(size: 20 * scaleFactor, weight: .semibold))
                            .foregroundColor(statusColor)
                    }

                    Text(categoryName)
                        .font(.system(size: 15 * scaleFactor, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }

                Spacer()

                // Status badge
                Text(statusText)
                    .font(.system(size: 10 * scaleFactor, weight: .semibold))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 10 * scaleFactor)
                    .padding(.vertical, 4 * scaleFactor)
                    .background(
                        Capsule()
                            .fill(statusColor.opacity(0.12))
                    )
            }
            .padding(.horizontal, 16 * scaleFactor)
            .padding(.top, 14 * scaleFactor)
            .padding(.bottom, 12 * scaleFactor)

            Divider()
                .padding(.horizontal, 16 * scaleFactor)

            // Main content: Two-column layout like Preset 5 (CLEAN design)
            HStack(alignment: .top, spacing: 20 * scaleFactor) {
                // Left: Check details list (scrollable)
                if let details = checkDetails, !details.isEmpty {
                    // Split on | separator (pipe-delimited format for external scripts)
                    // Falls back to \n for backward compatibility with JSON-defined cards
                    let separator = details.contains("|") ? "|" : "\n"
                    let items = details.components(separatedBy: separator)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8 * scaleFactor) {
                            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                                // Parse the check item to extract symbol, text, and status
                                let parsed = parseCheckItem(item)
                                let symbol = parsed.symbol
                                let text = parsed.text
                                let isPassed = parsed.isPassed
                                let isFailed = parsed.isFailed

                                HStack(alignment: .top, spacing: 8 * scaleFactor) {
                                    // Color-coded symbol
                                    Text(symbol)
                                        .font(.system(size: 10 * scaleFactor, weight: .semibold))
                                        .foregroundColor(isPassed ? colorThresholds.getPositiveColor() :
                                                       isFailed ? colorThresholds.getNegativeColor() :
                                                       Color.secondary)
                                        .frame(width: 10 * scaleFactor, alignment: .leading)

                                    Text(text)
                                        .font(.system(size: 10 * scaleFactor, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 2 * scaleFactor)

                                if index < items.count - 1 {
                                    Divider()
                                        .padding(.leading, 16 * scaleFactor)
                                        .padding(.vertical, 2 * scaleFactor)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 180 * scaleFactor)
                }

                // Right: Progress indicator and metrics
                VStack(spacing: 10 * scaleFactor) {
                    // Spacer to push content down (like Preset 5)
                    Spacer()
                        .frame(height: 20 * scaleFactor)

                    // Circular progress with percentage inside
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.15), lineWidth: 3 * scaleFactor)
                            .frame(width: 50 * scaleFactor, height: 50 * scaleFactor)

                        Circle()
                            .trim(from: 0, to: score)
                            .stroke(
                                statusColor,
                                style: StrokeStyle(lineWidth: 3 * scaleFactor, lineCap: .round)
                            )
                            .frame(width: 50 * scaleFactor, height: 50 * scaleFactor)
                            .rotationEffect(.degrees(-90))

                        // Percentage inside ring
                        Text("\(Int(score * 100))%")
                            .font(.system(size: 11 * scaleFactor, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }

                    // Compact metrics (just numbers with dots)
                    VStack(spacing: 5 * scaleFactor) {
                        HStack(spacing: 5 * scaleFactor) {
                            Circle()
                                .fill(colorThresholds.getPositiveColor())
                                .frame(width: 4 * scaleFactor, height: 4 * scaleFactor)
                            Text("\(passed)")
                                .font(.system(size: 9 * scaleFactor, weight: .medium, design: .monospaced))
                                .foregroundColor(colorThresholds.getPositiveColor())
                        }

                        HStack(spacing: 5 * scaleFactor) {
                            Circle()
                                .fill(colorThresholds.getNegativeColor())
                                .frame(width: 4 * scaleFactor, height: 4 * scaleFactor)
                            Text("\(total - passed)")
                                .font(.system(size: 9 * scaleFactor, weight: .medium, design: .monospaced))
                                .foregroundColor(colorThresholds.getNegativeColor())
                        }
                    }

                    Spacer()
                }
                .frame(width: 80 * scaleFactor)
            }
            .padding(.horizontal, 16 * scaleFactor)
            .padding(.vertical, 12 * scaleFactor)
        }
        .background(
            ZStack(alignment: .leading) {
                // Main card background
                RoundedRectangle(cornerRadius: 16 * scaleFactor)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(
                        color: Color.black.opacity(0.06),
                        radius: 8 * scaleFactor,
                        x: 0,
                        y: 2 * scaleFactor
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16 * scaleFactor)
                            .stroke(
                                Color.gray.opacity(0.08),
                                lineWidth: 1
                            )
                    )
            }
        )
        .id("compliance-card-\(categoryName)-\(passed)-\(total)-\(checkDetails ?? "")")  // Force re-render on data change
    }
}

// MARK: - Button Helper Functions

/// Get SwiftUI button style from string
@ViewBuilder
private func applyButtonStyle(_ button: some View, styleString: String?) -> some View {
    switch styleString {
    case "borderedProminent":
        button.buttonStyle(.borderedProminent)
    case "plain":
        button.buttonStyle(.plain)
    default: // "bordered" or nil
        button.buttonStyle(.bordered)
    }
}
