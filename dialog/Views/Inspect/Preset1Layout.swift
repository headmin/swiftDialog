//
//  Preset1Layout.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 19/07/2025
//  Traditional dialog presentation layout with icon and progress bar on left, app list on right

import SwiftUI


struct Preset1Layout: View, InspectLayoutProtocol {
    @ObservedObject var inspectState: InspectState
    let isMini: Bool
    @State private var showingAboutPopover = false
    let systemImage: String = isLaptop ? "laptopcomputer.and.arrow.down" : "desktopcomputer.and.arrow.down"

    init(inspectState: InspectState, isMini: Bool = false) {
        self.inspectState = inspectState
        self.isMini = isMini
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left sidebar with icon/image
            VStack {
                IconView(image: inspectState.uiConfiguration.iconPath ?? "", defaultImage: "apps.iphone.badge.plus", defaultColour: "accent")
                    .frame(width: 250 * scaleFactor, height: 250 * scaleFactor)

                // Progress bar
                if !inspectState.items.isEmpty {
                    let progress = Double(inspectState.completedItems.count) / Double(inspectState.items.count)
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(width: 200 * scaleFactor)
                        .padding(.top, 20 * scaleFactor)
                    
                    Text("\(inspectState.completedItems.count) of \(inspectState.items.count) installed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 5 * scaleFactor)
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
                    
                    buttonArea()
                }
                .padding()
                
                if let currentMessage = inspectState.getCurrentSideMessage() {
                    Text(currentMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .animation(.easeInOut(duration: InspectConstants.standardAnimationDuration), value: inspectState.uiConfiguration.currentSideMessageIndex)
                }
                
                Divider()
                
                // Item list
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        let sortedItems = getSortedItemsByStatus()
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
                                .padding(.vertical, 8)
                                .padding(.horizontal)
                                .background(Color(NSColor.windowBackgroundColor))
                            }
                            HStack {
                                // Item icon
                                IconView(image: item.icon ?? "", defaultImage: systemImage, defaultColour: "accent")
                                    .frame(width: 48, height: 48)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.displayName)
                                        .font(.system(size: 14, weight: .medium))
                                    if !inspectState.completedItems.contains(item.id) {
                                        Text(getItemStatus(for: item))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                // Status indicator
                                statusIndicator(for: item)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            
                            if item.id != sortedItems.last?.id {
                                Divider()
                                    .padding(.leading, 76)
                            }
                        }
                    }
                    .padding(.vertical)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Helper Methods
    
    private func shouldShowGroupSeparator(for item: InspectConfig.ItemConfig, in sortedItems: [InspectConfig.ItemConfig]) -> Bool {
        guard let currentIndex = sortedItems.firstIndex(where: { $0.id == item.id }) else { return false }
        
        if currentIndex == 0 { return true }
        
        let previousItem = sortedItems[currentIndex - 1]
        let currentStatus = getItemStatusType(for: item)
        let previousStatus = getItemStatusType(for: previousItem)
        
        return currentStatus != previousStatus
    }
    
    private func getStatusHeaderText(for statusType: ItemStatusType) -> String {
        switch statusType {
        case .completed:
            return "Completed"
        case .downloading:
            return "Installing"
        case .pending:
            return "Waiting"
        }
    }
}
