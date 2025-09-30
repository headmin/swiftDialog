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
    @State private var lastDownloadingItem: String? = nil

    init(inspectState: InspectState) {
        self.inspectState = inspectState
    }

    var body: some View {
        let scale: CGFloat = scaleFactor

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
                    .padding(.top, 20 * scale)
                    .padding(.bottom, 20 * scale)
            } else {
                // Original icon display (when no banner is set)
                VStack(spacing: 20 * scale) {
                    // Main icon - larger for Setup Manager style
                    IconView(image: getMainIconPath(), defaultImage: "briefcase.fill", defaultColour: "accent")
                        .frame(maxHeight: 120 * scale)
                        .onAppear { iconCache.cacheMainIcon(for: inspectState) }

                    // Welcome title
                    Text(inspectState.uiConfiguration.windowTitle)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40 * scale)
                .padding(.bottom, 20 * scale)
            }

            // Rotating side messages - always visible
            if let currentMessage = inspectState.getCurrentSideMessage() {
                Text(currentMessage)
                    .font(.system(size: 14 * scale))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .padding(.horizontal, 60 * scale)
                    .frame(minHeight: 60 * scale)
                    .animation(.easeInOut(duration: InspectConstants.standardAnimationDuration), value: inspectState.uiConfiguration.currentSideMessageIndex)
            }

            // App cards with navigation arrows
            VStack(spacing: 8 * scale) {
                HStack(spacing: 20 * scale) {
                    // Left arrow
                    Button(action: {
                        scrollLeft()
                    }) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 32 * scale))
                            .foregroundColor(canScrollLeft() ? Color(hex: inspectState.uiConfiguration.highlightColor) : .gray.opacity(0.3))
                    }
                    .disabled(!canScrollLeft())
                    .buttonStyle(PlainButtonStyle())

                    // App cards - show 5 at a time
                    HStack(spacing: 12 * scale) {
                        ForEach(getVisibleItemsWithOffset(), id: \.id) { item in
                            Preset2ItemCardView(
                                item: item,
                                isCompleted: inspectState.completedItems.contains(item.id),
                                isDownloading: inspectState.downloadingItems.contains(item.id),
                                highlightColor: inspectState.uiConfiguration.highlightColor,
                                scale: scale,
                                resolvedIconPath: getIconPathForItem(item)
                            )
                        }

                        // Fill remaining slots with placeholder cards if needed
                        let visibleCount = sizeMode == "compact" ? 3 : (sizeMode == "large" ? 6 : 4)
                        ForEach(0..<max(0, visibleCount - getVisibleItemsWithOffset().count), id: \.self) { _ in
                            Preset2PlaceholderCardView(scale: scale)
                        }
                    }
                    .animation(.easeInOut(duration: InspectConstants.standardAnimationDuration), value: scrollOffset)
                    .animation(.easeInOut(duration: InspectConstants.longAnimationDuration), value: inspectState.completedItems.count)
                    .animation(.easeInOut(duration: InspectConstants.longAnimationDuration), value: inspectState.downloadingItems.count)
                    .onChange(of: inspectState.downloadingItems) { _, newValue in
                        centerDownloadingItem(newValue)
                    }

                    // Right arrow
                    Button(action: {
                        scrollRight()
                    }) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 32 * scale))
                            .foregroundColor(canScrollRight() ? Color(hex: inspectState.uiConfiguration.highlightColor) : .gray.opacity(0.3))
                    }
                    .disabled(!canScrollRight())
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 40 * scale)
            }

            Spacer()

            // Bottom progress section
            VStack(spacing: 12) {
                // Progress bar
                ProgressView(value: Double(inspectState.completedItems.count), total: Double(inspectState.items.count))
                    .progressViewStyle(.linear)
                    .frame(width: 600 * scale)
                    .tint(Color(hex: inspectState.uiConfiguration.highlightColor))

                // Progress text
                Text("\(inspectState.completedItems.count) of \(inspectState.items.count) apps installed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 20 * scale)

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
                HStack(spacing: 20 * scale) {
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
            .padding(.horizontal, 40 * scale)
            .padding(.bottom, 30 * scale)
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
        let visibleCount = sizeMode == "compact" ? 3 : (sizeMode == "large" ? 6 : 4)
        return scrollOffset + visibleCount < inspectState.items.count
    }

    private func scrollLeft() {
        if canScrollLeft() {
            scrollOffset = max(0, scrollOffset - 1)  // Shift by 1 for smoother navigation
        }
    }

    private func scrollRight() {
        if canScrollRight() {
            let visibleCount = sizeMode == "compact" ? 3 : (sizeMode == "large" ? 6 : 4)
            scrollOffset = min(inspectState.items.count - visibleCount, scrollOffset + 1)  // Shift by 1
        }
    }

    private func getVisibleItemsWithOffset() -> [InspectConfig.ItemConfig] {
        // Adjust visible cards based on size mode
        let visibleCount: Int
        switch sizeMode {
        case "compact": visibleCount = 3
        case "large": visibleCount = 6
        default: visibleCount = 4  // standard
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

    private func centerDownloadingItem(_ downloadingItems: Set<String>) {
        // Find first downloading item that's not already centered
        let visibleCount = sizeMode == "compact" ? 3 : (sizeMode == "large" ? 6 : 4)
        let centerPosition = visibleCount / 2  // Center position in the visible cards

        for (index, item) in inspectState.items.enumerated() {
            if downloadingItems.contains(item.id) {
                // Check if this is a new downloading item
                if lastDownloadingItem != item.id {
                    lastDownloadingItem = item.id
                    // Calculate offset to center this item
                    let targetOffset = max(0, min(index - centerPosition, inspectState.items.count - visibleCount))
                    if targetOffset != scrollOffset {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            scrollOffset = targetOffset
                        }
                    }
                }
                break // Only center the first downloading item
            }
        }

        // Clear last downloading item if nothing is downloading
        if downloadingItems.isEmpty {
            lastDownloadingItem = nil
        }
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

    var body: some View {
        VStack(spacing: 4 * scale) {
            // Icon with status overlay
            ZStack {
                // Item icon - larger size
                IconView(image: resolvedIconPath, defaultImage: "app.fill", defaultColour: "accent")
                    .frame(width: 90 * scale, height: 90 * scale)
                    .cornerRadius(16 * scale)

                // Status indicator overlay
                VStack {
                    HStack {
                        Spacer()
                        if isCompleted {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 26 * scale, height: 26 * scale)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12 * scale, weight: .bold))
                                        .foregroundColor(.white)
                                )
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
                Text(isCompleted ? "Installed" : (isDownloading ? "Installing..." : "Waiting"))
                    .font(.system(size: 9 * scale))
                    .foregroundColor(isCompleted ? .green : (isDownloading ? .blue : .gray))
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
