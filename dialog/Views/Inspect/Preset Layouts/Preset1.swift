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

                Text(getItemStatusWithValidation(for: item))
                    .font(.system(size: 13 * scaleFactor))  // 12pt → 13pt
                    .foregroundColor(getItemStatusColor(for: item))
            }

            Spacer()

            // Status indicator with validation support
            statusIndicatorWithValidation(for: item)
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
        case .completed:
            // Use section header if provided, otherwise fall back to status text
            return inspectState.config?.uiLabels?.sectionHeaderCompleted
                ?? inspectState.config?.uiLabels?.completedStatus
                ?? "Completed"
        case .downloading:
            // Use section header if provided, otherwise construct from status text
            if let header = inspectState.config?.uiLabels?.sectionHeaderPending {
                return header
            }
            let downloadingText = inspectState.config?.uiLabels?.downloadingStatus ?? "Installing..."
            let cleanText = downloadingText.replacingOccurrences(of: "...", with: "")
            return "Currently \(cleanText)"
        case .pending:
            // Use section header if provided, otherwise fall back to constructed text
            return inspectState.config?.uiLabels?.sectionHeaderPending ?? "Pending Installation"
        case .failed:
            // Use section header if provided, otherwise fall back to hardcoded
            return inspectState.config?.uiLabels?.sectionHeaderFailed ?? "Installation Failed"
        }
    }

    // MARK: - Validation Support

    private func hasValidationWarning(for item: InspectConfig.ItemConfig) -> Bool {
        // Only check validation for completed items  
        guard inspectState.completedItems.contains(item.id) else { return false }
        
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

    private func getItemStatusWithValidation(for item: InspectConfig.ItemConfig) -> String {
        if inspectState.completedItems.contains(item.id) {
            if hasValidationWarning(for: item) {
                // Use custom validation warning text if available, otherwise default
                return inspectState.config?.uiLabels?.failedStatus ?? "Failed"
            } else {
                return getItemStatus(for: item)
            }
        } else {
            return getItemStatus(for: item)
        }
    }

    private func getItemStatusColor(for item: InspectConfig.ItemConfig) -> Color {
        if inspectState.completedItems.contains(item.id) {
            return hasValidationWarning(for: item) ? .yellow : .green
        } else if inspectState.downloadingItems.contains(item.id) {
            return .blue
        } else {
            return .secondary
        }
    }

    @ViewBuilder
    private func statusIndicatorWithValidation(for item: InspectConfig.ItemConfig) -> some View {
        let size: CGFloat = 20 * scaleFactor
        
        if inspectState.completedItems.contains(item.id) {
            // Completed - check for validation warnings
            Circle()
                .fill(hasValidationWarning(for: item) ? Color.yellow : Color.green)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: hasValidationWarning(for: item) ? "exclamationmark" : "checkmark")
                        .font(.system(size: size * 0.6, weight: .bold))
                        .foregroundColor(.white)
                )
                .help(hasValidationWarning(for: item) ?
                      "Configuration validation failed - check plist settings" :
                      "Installed and validated")
        } else if inspectState.downloadingItems.contains(item.id) {
            // Downloading
            Circle()
                .fill(Color.blue)
                .frame(width: size, height: size)
                .overlay(
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(Color.white)
                        .colorScheme(.dark)
                )
        } else {
            // Pending
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: size, height: size)
        }
    }
}