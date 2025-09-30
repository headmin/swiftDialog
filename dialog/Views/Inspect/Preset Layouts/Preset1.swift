//
//  Preset1.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 19/07/2025
//
//  Classic sidebar layout with FSevents based progress tracking
//  
//

import SwiftUI

struct Preset1View: View, InspectLayoutProtocol {
    @ObservedObject var inspectState: InspectState
    @State private var showingAboutPopover = false
    @StateObject private var iconCache = PresetIconCache()

    let systemImage: String = isLaptop ? "laptopcomputer.and.arrow.down" : "desktopcomputer.and.arrow.down"

    init(inspectState: InspectState) {
        self.inspectState = inspectState
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left sidebar with icon/image
            VStack {
                Spacer()
                    .frame(height: 80)  // Push icon down to center it better

                IconView(image: iconCache.getMainIconPath(for: inspectState), defaultImage: "apps.iphone.badge.plus", defaultColour: "accent")
                    .frame(width: 220 * scaleFactor, height: 220 * scaleFactor)
                    .onAppear { iconCache.cacheMainIcon(for: inspectState) }

                // Progress bar
                if !inspectState.items.isEmpty {
                    PresetCommonViews.progressBar(
                        state: inspectState,
                        width: 200 * scaleFactor,
                        labelSize: 13  // Improved from caption
                    )
                    .padding(.top, 20 * scaleFactor)
                }

                Spacer()

                // Install info button
                Button(inspectState.uiConfiguration.popupButtonText) {
                    showingAboutPopover.toggle()
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .font(.body)
                .padding(.bottom, 20 * scaleFactor)
                .popover(isPresented: $showingAboutPopover, arrowEdge: .top) {
                    InstallationInfoPopoverView(inspectState: inspectState)
                }
            }
            .frame(width: 320 * scaleFactor)
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            // Right content area
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text(inspectState.uiConfiguration.windowTitle)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()

                    PresetCommonViews.buttonArea(state: inspectState)
                }
                .padding()

                if let currentMessage = inspectState.getCurrentSideMessage() {
                    Text(currentMessage)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .frame(minHeight: 50)
                        .animation(.easeInOut(duration: 0.5), value: inspectState.uiConfiguration.currentSideMessageIndex)
                }

                Divider()

                // Item list
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Add top padding for better visual balance
                        Color.clear.frame(height: 60)
                        let sortedItems = PresetCommonViews.getSortedItemsByStatus(inspectState)
                        ForEach(sortedItems, id: \.id) { item in
                            // Add group separator if needed
                            if shouldShowGroupSeparator(for: item, in: sortedItems) {
                                HStack {
                                    Text(getStatusHeaderText(for: getItemStatusType(for: item)))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.top, 10 * scaleFactor)
                                .padding(.bottom, 5 * scaleFactor)
                            }

                            itemRow(for: item)
                        }
                    }
                    .padding(.vertical, 10 * scaleFactor)
                }

                Divider()

                // Status bar
                HStack {
                    Text(inspectState.uiConfiguration.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
        }
        .frame(width: windowSize.width, height: windowSize.height)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            writeLog("Preset1View: Using refactored InspectState", logLevel: .info)
        }
    }

    // MARK: - Helper Methods

    @ViewBuilder
    private func itemRow(for item: InspectConfig.ItemConfig) -> some View {
        HStack(spacing: 12 * scaleFactor) {
            // Icon
            IconView(image: iconCache.getItemIconPath(for: item, state: inspectState))
                .frame(width: 48 * scaleFactor, height: 48 * scaleFactor)
                .aspectRatio(1, contentMode: .fit)
                .clipped()

            // Item info
            VStack(alignment: .leading, spacing: 2 * scaleFactor) {
                Text(item.displayName)
                    .font(.system(size: 16 * scaleFactor, weight: .medium))  // 14pt → 16pt
                    .foregroundColor(.primary)

                Text(PresetCommonViews.getItemStatus(for: item, state: inspectState))
                    .font(.system(size: 13 * scaleFactor))  // 12pt → 13pt
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status indicator
            PresetCommonViews.statusIndicator(for: item, state: inspectState, size: 20 * scaleFactor)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)  // Consistent 8pt padding
    }

    // MARK: - Sorting & Status

    private func getItemStatusType(for item: InspectConfig.ItemConfig) -> InspectItemStatus {
        if inspectState.completedItems.contains(item.id) { return .completed }
        if inspectState.downloadingItems.contains(item.id) { return .downloading }
        return .pending
    }

    private func shouldShowGroupSeparator(for item: InspectConfig.ItemConfig, in sortedItems: [InspectConfig.ItemConfig]) -> Bool {
        guard let index = sortedItems.firstIndex(where: { $0.id == item.id }), index > 0 else { return false }

        let previousItem = sortedItems[index - 1]
        let currentStatus = getItemStatusType(for: item)
        let previousStatus = getItemStatusType(for: previousItem)

        return currentStatus != previousStatus
    }

    private func getStatusHeaderText(for statusType: InspectItemStatus) -> String {
        switch statusType {
        case .completed: return "Installed"
        case .downloading: return "Currently Installing"
        case .pending: return "Pending Installation"
        case .failed: return "Installation Failed"
        }
    }
}