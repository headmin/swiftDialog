//
//  Preset2.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 19/07/2025
//
//  Card-based display with carousel navigation, option for banner image
//

import SwiftUI

struct Preset2View: View, InspectLayoutProtocol {
    @ObservedObject var inspectState: InspectState
    @State private var showingAboutPopover = false
    @StateObject private var iconCache = PresetIconCache()
    @State private var scrollOffset: Int = 0
    @State private var lastDownloadingItem: String?

    init(inspectState: InspectState) {
        self.inspectState = inspectState
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top section - either banner or icon
            if inspectState.uiConfiguration.bannerImage != nil {
                // Banner display
                ZStack {
                    if let bannerNSImage = iconCache.bannerImage {
                        Image(nsImage: bannerNSImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: windowSize.width, height: CGFloat(inspectState.uiConfiguration.bannerHeight))
                            .clipped()

                        // Optional title overlay on banner
                        if let bannerTitle = inspectState.uiConfiguration.bannerTitle {
                            Text(bannerTitle)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 3, x: 2, y: 2)
                        }
                    }
                }
                .frame(width: windowSize.width, height: CGFloat(inspectState.uiConfiguration.bannerHeight))
                .onAppear { iconCache.cacheBannerImage(for: inspectState) }

                // Title below banner
                Text(inspectState.uiConfiguration.windowTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20 * scaleFactor)
                    .padding(.bottom, 20 * scaleFactor)
            } else {
                // Original icon display (when no banner is set)
                VStack(spacing: 20 * scaleFactor) {
                    // Main icon - larger for Setup Manager style
                    IconView(image: getMainIconPath(), defaultImage: "briefcase.fill", defaultColour: "accent")
                        .frame(maxHeight: 120 * scaleFactor)
                        .onAppear { iconCache.cacheMainIcon(for: inspectState) }

                    // Welcome title
                    Text(inspectState.uiConfiguration.windowTitle)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40 * scaleFactor)
                .padding(.bottom, 20 * scaleFactor)
            }

            // Rotating side messages - always visible
            if let currentMessage = inspectState.getCurrentSideMessage() {
                Text(currentMessage)
                    .font(.system(size: 14 * scaleFactor))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .padding(.horizontal, 60 * scaleFactor)
                    .frame(minHeight: 60 * scaleFactor)
                    .animation(.easeInOut(duration: InspectConstants.standardAnimationDuration), value: inspectState.uiConfiguration.currentSideMessageIndex)
            }

            // App cards with navigation arrows
            VStack(spacing: 8 * scaleFactor) {
                HStack(spacing: 20 * scaleFactor) {
                    // Left arrow
                    Button(action: {
                        scrollLeft()
                    }) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 32 * scaleFactor))
                            .foregroundColor(canScrollLeft() ? Color(hex: inspectState.uiConfiguration.highlightColor) : .gray.opacity(0.3))
                    }
                    .disabled(!canScrollLeft())
                    .buttonStyle(PlainButtonStyle())

                    // App cards - show 5 at a time
                    HStack(spacing: 12 * scaleFactor) {
                        ForEach(getVisibleItemsWithOffset(), id: \.id) { item in
                            Preset2ItemCardView(
                                item: item,
                                isCompleted: inspectState.completedItems.contains(item.id),
                                isDownloading: inspectState.downloadingItems.contains(item.id),
                                highlightColor: inspectState.uiConfiguration.highlightColor,
                                scale: scaleFactor,
                                resolvedIconPath: getIconPathForItem(item),
                                inspectState: inspectState
                            )
                        }

                        // Fill remaining slots with placeholder cards if needed
                        let visibleCount = sizeMode == "compact" ? 4 : (sizeMode == "large" ? 6 : 5)
                        ForEach(0..<max(0, visibleCount - getVisibleItemsWithOffset().count), id: \.self) { _ in
                            Preset2PlaceholderCardView(scale: scaleFactor)
                        }
                    }
                    .animation(.easeInOut(duration: InspectConstants.standardAnimationDuration), value: scrollOffset)
                    .animation(.easeInOut(duration: InspectConstants.longAnimationDuration), value: inspectState.completedItems.count)
                    .animation(.easeInOut(duration: InspectConstants.longAnimationDuration), value: inspectState.downloadingItems.count)
                    .onChange(of: inspectState.downloadingItems) { _, _ in
                        updateScrollForProgress()
                    }
                    .onChange(of: inspectState.completedItems) { _, _ in
                        updateScrollForProgress()
                    }

                    // Right arrow
                    Button(action: {
                        scrollRight()
                    }) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 32 * scaleFactor))
                            .foregroundColor(canScrollRight() ? Color(hex: inspectState.uiConfiguration.highlightColor) : .gray.opacity(0.3))
                    }
                    .disabled(!canScrollRight())
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 40 * scaleFactor)
            }

            Spacer()

            // Bottom progress section
            VStack(spacing: 12) {
                // Progress bar
                ProgressView(value: Double(inspectState.completedItems.count), total: Double(inspectState.items.count))
                    .progressViewStyle(.linear)
                    .frame(width: 600 * scaleFactor)
                    .tint(Color(hex: inspectState.uiConfiguration.highlightColor))

                // Progress text (customizable via uiLabels.progressFormat)
                Text(getProgressText())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 20 * scaleFactor)

            // Bottom buttons
            HStack {
                // Install details button (always visible)
                Button(inspectState.uiConfiguration.popupButtonText) {
                    showingAboutPopover.toggle()
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .font(.body)
                .popover(isPresented: $showingAboutPopover) {
                    InstallationInfoPopoverView(inspectState: inspectState)
                }

                Spacer()

                // Action buttons (appear when complete)
                HStack(spacing: 20 * scaleFactor) {
                    // About button or Button2 if configured
                    if inspectState.buttonConfiguration.button2Visible {
                        Button(action: {
                            // Check if we're in demo mode and button says "Create Config"
                            if inspectState.configurationSource == .testData && inspectState.buttonConfiguration.button2Text == "Create Config" {
                                writeLog("Preset2LayoutServiceBased: Creating sample configuration", logLevel: .info)
                                inspectState.createSampleConfiguration()
                            } else {
                                // Normal button2 action - typically quits with code 2
                                writeLog("Preset2LayoutServiceBased: User clicked button2", logLevel: .info)
                                exit(2)
                            }
                        }) {
                            Text(inspectState.buttonConfiguration.button2Text)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        // Show immediately in demo mode, otherwise show when complete
                        .opacity((inspectState.configurationSource == .testData || inspectState.completedItems.count == inspectState.items.count) ? 1.0 : 0.0)
                    }

                    // Main action button
                    Button(action: {
                        writeLog("Preset2LayoutServiceBased: User clicked button1", logLevel: .info)
                        exit(0)
                    }) {
                        Text(inspectState.buttonConfiguration.button1Text)
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(inspectState.buttonConfiguration.button1Disabled)
                    .opacity(inspectState.completedItems.count == inspectState.items.count ? 1.0 : 0.0)
                }
            }
            .padding(.horizontal, 40 * scaleFactor)
            .padding(.bottom, 30 * scaleFactor)
        }
        .frame(width: windowSize.width, height: windowSize.height)
        .background(Color(NSColor.windowBackgroundColor))
        .ignoresSafeArea()
        .onAppear {
            writeLog("Preset2LayoutServiceBased: Using InspectState", logLevel: .info)
        }
    }

    // MARK: - Navigation Methods

    private func canScrollLeft() -> Bool {
        scrollOffset > 0
    }

    private func canScrollRight() -> Bool {
        let visibleCount = sizeMode == "compact" ? 4 : (sizeMode == "large" ? 6 : 5)
        return scrollOffset + visibleCount < inspectState.items.count
    }

    private func scrollLeft() {
        if canScrollLeft() {
            scrollOffset = max(0, scrollOffset - 1)  // Shift by 1 for smoother navigation
        }
    }

    private func scrollRight() {
        if canScrollRight() {
            let visibleCount = sizeMode == "compact" ? 4 : (sizeMode == "large" ? 6 : 5)
            scrollOffset = min(inspectState.items.count - visibleCount, scrollOffset + 1)  // Shift by 1
        }
    }

    private func getVisibleItemsWithOffset() -> [InspectConfig.ItemConfig] {
        // Adjust visible cards based on size mode
        let visibleCount: Int
        switch sizeMode {
        case "compact": visibleCount = 4  // increased from 3 to 4
        case "large": visibleCount = 6
        default: visibleCount = 5  // standard - increased from 4 to 5
        }

        let startIndex = scrollOffset
        let endIndex = min(startIndex + visibleCount, inspectState.items.count)

        if startIndex >= inspectState.items.count {
            return []
        }

        return Array(inspectState.items[startIndex..<endIndex])
    }

    // MARK: - Icon Management

    private func getMainIconPath() -> String {
        return iconCache.getMainIconPath(for: inspectState)
    }




    private func getIconPathForItem(_ item: InspectConfig.ItemConfig) -> String {
        return iconCache.getItemIconPath(for: item, state: inspectState)
    }

    // MARK: - Auto-centering for downloading items

    private func updateScrollForProgress() {
        // Switch here to find the currently downloading item
        guard let downloadingItem = inspectState.downloadingItems.first,
              let downloadingIndex = inspectState.items.firstIndex(where: { $0.id == downloadingItem }) else {
            return
        }

        let visibleCount = sizeMode == "compact" ? 4 : (sizeMode == "large" ? 6 : 5)

        // Optimized try to keep downloading item in view position (index 1) when possible
        // Ther ordewr should be: [1 completed] [downloading] [penidng] [pending]...
        let preferredPositionFromLeft = 1

        // Calc offset to place downloading item at preferred position
        var targetOffset = downloadingIndex - preferredPositionFromLeft

        // Set up valid range
        targetOffset = max(0, targetOffset)  // We try to don't scroll before start
        targetOffset = min(targetOffset, max(0, inspectState.items.count - visibleCount))  // Don't scroll past end - needs observation if this works better

        // Scroll to target position if different
        if targetOffset != scrollOffset {
            withAnimation(.easeInOut(duration: 0.6)) {
                scrollOffset = targetOffset
            }

            // Update here for next change
            lastDownloadingItem = downloadingItem
        }
    }

    /// Get progress bar text with template support
    private func getProgressText() -> String {
        let completed = inspectState.completedItems.count
        let total = inspectState.items.count

        if let template = inspectState.config?.uiLabels?.progressFormat {
            return template
                .replacingOccurrences(of: "{completed}", with: "\(completed)")
                .replacingOccurrences(of: "{total}", with: "\(total)")
        }

        return "\(completed) of \(total) completed"
    }
}

// MARK: - Enhanced Card Views for Preset2

private struct Preset2ItemCardView: View {
    let item: InspectConfig.ItemConfig
    let isCompleted: Bool
    let isDownloading: Bool
    let highlightColor: String
    let scale: CGFloat
    let resolvedIconPath: String
    let inspectState: InspectState

    // TODO: Uncomment when info popover is ready
    // @State private var showingInfoPopover = false

    private var hasValidationWarning: Bool {
        // Only check validation for completed items
        guard isCompleted else { return false }
        
        // Check if item has any plist validation configuration
        let hasPlistValidation = item.plistKey != nil || 
                               inspectState.plistSources?.contains(where: { source in
                                   item.paths.contains(source.path)
                               }) == true
        
        // If item has plist validation, check the results
        if hasPlistValidation {
            return !(inspectState.plistValidationResults[item.id] ?? true)
        }
        
        return false
    }

    private func getStatusText() -> String {
        if isCompleted {
            if hasValidationWarning {
                // Use custom validation warning text if available, otherwise default
                return inspectState.config?.uiLabels?.failedStatus ?? "Failed"
            } else {
                // Use the new customization system for completed status
                if let customStatus = item.completedStatus {
                    return customStatus
                } else if let globalStatus = inspectState.config?.uiLabels?.completedStatus {
                    return globalStatus
                } else {
                    return "Completed"
                }
            }
        } else if isDownloading {
            // Use the new customization system for downloading status
            if let customStatus = item.downloadingStatus {
                return customStatus
            } else if let globalStatus = inspectState.config?.uiLabels?.downloadingStatus {
                return globalStatus
            } else {
                return "Installing..."
            }
        } else {
            // Use the new customization system for pending status
            if let customStatus = item.pendingStatus {
                return customStatus
            } else if let globalStatus = inspectState.config?.uiLabels?.pendingStatus {
                return globalStatus
            } else {
                return "Waiting"
            }
        }
    }

    private func getStatusColor() -> Color {
        if isCompleted {
            return hasValidationWarning ? .yellow : .green
        } else if isDownloading {
            return .blue
        } else {
            return .gray
        }
    }

    var body: some View {
        VStack(spacing: 4 * scale) {
            // Icon with status overlay
            ZStack {
                // Item icon - larger size
                IconView(image: resolvedIconPath, defaultImage: "app.fill", defaultColour: "accent")
                    .frame(width: 90 * scale, height: 90 * scale)
                    .cornerRadius(16 * scale)

                // TODO: Info button overlay (top-left) - Commented out - not ready yet
                // VStack {
                //     HStack {
                //         Button(action: {
                //             showingInfoPopover.toggle()
                //         }) {
                //             ZStack {
                //                 Circle()
                //                     .foregroundColor(.white.opacity(0.3))
                //                 Image(systemName: "info")
                //                     .font(.system(size: 8 * scale, weight: .medium))
                //                     .foregroundColor(.blue)
                //             }
                //             .frame(width: 16 * scale, height: 16 * scale)
                //         }
                //         .buttonStyle(PlainButtonStyle())
                //         .help("Show step information")
                //         .popover(isPresented: $showingInfoPopover, arrowEdge: .top) {
                //             ItemInfoPopoverView(item: item)
                //         }
                //
                //         Spacer()
                //     }
                //     Spacer()
                // }
                // .padding(4 * scale)

                // Status indicator overlay (top-right)
                VStack {
                    HStack {
                        Spacer()
                        if isCompleted {
                            Circle()
                                .fill(hasValidationWarning ? Color.yellow : Color.green)
                                .frame(width: 26 * scale, height: 26 * scale)
                                .overlay(
                                    Image(systemName: hasValidationWarning ? "exclamationmark" : "checkmark")
                                        .font(.system(size: 12 * scale, weight: .bold))
                                        .foregroundColor(.white)
                                )
                                .help(hasValidationWarning ?
                                      "Configuration validation failed - check plist settings" :
                                      "\(getStatusText()) and validated")
                        } else if isDownloading {
                            // Blue circle with white spinner - matches checkmark style
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 26 * scale, height: 26 * scale)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .tint(Color.white)
                                        .colorScheme(.dark)  // Makes spinner white
                                )
                        }
                    }
                    Spacer()
                }
                .padding(2 * scale)
            }

            // App name and status
            VStack(spacing: 2 * scale) {
                Text(item.displayName)
                    .font(.system(size: 12 * scale, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isDownloading ? Color(hex: highlightColor) : .primary)

                // Status text
                Text(getStatusText())
                    .font(.system(size: 9 * scale))
                    .foregroundColor(getStatusColor())
            }
            .frame(width: 110 * scale, height: 35 * scale)
        }
        .frame(width: 130 * scale, height: 160 * scale)
        .padding(6 * scale)
        .background(
            RoundedRectangle(cornerRadius: 10 * scale)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10 * scale)
                        .stroke(isDownloading ? Color(hex: highlightColor).opacity(0.5) : Color.gray.opacity(0.15),
                               lineWidth: isDownloading ? 1.5 : 1)
                )
        )
        .opacity(isCompleted ? 1.0 : (isDownloading ? 1.0 : 0.75))
        .animation(.easeInOut(duration: 0.3), value: isCompleted)
        .animation(.easeInOut(duration: 0.3), value: isDownloading)
    }
}

private struct Preset2PlaceholderCardView: View {
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 4 * scale) {
            RoundedRectangle(cornerRadius: 14 * scale)
                .fill(Color.gray.opacity(0.05))
                .frame(width: 72 * scale, height: 72 * scale)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.05))
                .frame(width: 70 * scale, height: 10 * scale)
        }
        .frame(width: 110 * scale, height: 120 * scale)
        .padding(6 * scale)
    }
}

// MARK: - Item Info Popover

private struct ItemInfoPopoverView: View {
    let item: InspectConfig.ItemConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with item name
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)

                    if let subtitle = item.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            Divider()

            // Installation paths info
            if !item.paths.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Installation Paths")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }

                    ForEach(item.paths, id: \.self) { path in
                        HStack(alignment: .top, spacing: 6) {
                            Text("→")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 12, alignment: .leading)

                            Text(path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            } else {
                Text("No additional installation details available.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}
