//
//  Preset2Layout.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 19/07/2025
//  Card-based display and navigation
//

import SwiftUI

struct Preset2Layout: View, InspectLayoutProtocol {
    @ObservedObject var inspectState: InspectState
    let isMini: Bool
    @State private var showingAboutPopover = false
    
    init(inspectState: InspectState, isMini: Bool = false) {
        self.inspectState = inspectState
        self.isMini = isMini
    }
    
    var body: some View {
        let scale: CGFloat = isMini ? 0.75 : 1.0
        
        VStack(spacing: 0) {
            // Top section with welcome and large icon
            VStack(spacing: 20 * scale) {
                // Main icon - larger for Setup Manager style
                if let iconPath = inspectState.uiConfiguration.iconPath,
                   FileManager.default.fileExists(atPath: iconPath) {
                    Image(nsImage: NSImage(contentsOfFile: iconPath) ?? NSImage())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 100 * scale)
                        .cornerRadius(15)
                } else {
                    // Default Setup Manager style icon
                    RoundedRectangle(cornerRadius: 15)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.blue]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120 * scale, height: 120 * scale)
                        .overlay(
                            Image(systemName: "briefcase.fill")
                                .font(.system(size: 40 * scale))
                                .foregroundColor(.white)
                        )
                }
                
                // Welcome title
                Text(inspectState.uiConfiguration.windowTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                if let currentMessage = inspectState.getCurrentSideMessage() {
                    Text(currentMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40 * scale)
                        .animation(.easeInOut(duration: InspectConstants.standardAnimationDuration), value: inspectState.uiConfiguration.currentSideMessageIndex)
                }
            }
            .padding(.top, 40 * scale)
            .padding(.bottom, 30 * scale)
            
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
                    HStack(spacing: 16 * scale) {
                        ForEach(getVisibleItemsWithOffset(), id: \.id) { app in
                            ItemCardView(item: app, 
                                      isCompleted: inspectState.completedItems.contains(app.id),
                                      isDownloading: inspectState.downloadingItems.contains(app.id),
                                      highlightColor: inspectState.uiConfiguration.highlightColor,
                                      scale: scale)
                        }
                        
                        // Fill remaining slots with placeholder cards if needed
                        ForEach(0..<max(0, 5 - getVisibleItemsWithOffset().count), id: \.self) { _ in
                            PlaceholderCardView(scale: scale)
                        }
                    }
                    .animation(.easeInOut(duration: InspectConstants.standardAnimationDuration), value: inspectState.scrollOffset)
                    .animation(.easeInOut(duration: InspectConstants.longAnimationDuration), value: inspectState.completedItems.count)
                    .animation(.easeInOut(duration: InspectConstants.longAnimationDuration), value: inspectState.downloadingItems.count)
                    .onChange(of: inspectState.completedItems.count) { _ in
                        smartAutoScroll()
                    }
                    .onChange(of: inspectState.downloadingItems.count) { _ in
                        smartAutoScroll()
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
                if !inspectState.items.isEmpty {
                    let progress = Double(inspectState.completedItems.count) / Double(inspectState.items.count)
                    
                    // Current item being processed
                    if let currentItem = inspectState.items.first(where: { inspectState.downloadingItems.contains($0.id) }) {
                        Text(currentItem.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Step \(inspectState.completedItems.count + 1) of \(inspectState.items.count)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else if inspectState.completedItems.count == inspectState.items.count && !inspectState.items.isEmpty {
                        Text("Installation Complete")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("All applications installed successfully")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Progress bar
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 6)
                        .padding(.horizontal, 80 * scale)
                }
                
                // Action buttons - Reserve space to prevent progress bar jumping
                HStack(spacing: 20 * scale) {
                    Button(inspectState.uiConfiguration.popupButtonText) {
                        showingAboutPopover.toggle()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                    .font(.body)
                    .popover(isPresented: $showingAboutPopover, arrowEdge: .top) {
                        InstallationInfoPopoverView(inspectState: inspectState)
                    }
                    
                    Spacer()
                    
                    // Always reserve space for buttons to prevent layout jumping
                    HStack(spacing: 12) {
                        // Button 2 (Secondary/Cancel) - Exit code 2
                        if inspectState.buttonConfiguration.button2Visible && !inspectState.buttonConfiguration.button2Text.isEmpty {
                            Button(inspectState.buttonConfiguration.button2Text) {
                                writeLog("Preset2Layout: User clicked button2 (\(inspectState.buttonConfiguration.button2Text)) - exiting with code 2", logLevel: .info)
                                exit(2)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .disabled(inspectState.buttonConfiguration.button2Disabled)
                            .opacity(inspectState.completedItems.count == inspectState.items.count ? 1.0 : 0.0)
                        }
                        
                        // Button 1 (Primary) - Exit code 0 - Always present to reserve space
                        Button(inspectState.buttonConfiguration.button1Text) {
                            writeLog("Preset2Layout: User clicked button1 (\(inspectState.buttonConfiguration.button1Text)) - exiting with code 0", logLevel: .info)
                            exit(0)
                        }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(inspectState.buttonConfiguration.button1Disabled)
                        .opacity(inspectState.completedItems.count == inspectState.items.count ? 1.0 : 0.0)
                    }
                }
                .padding(.horizontal, 40 * scale)
            }
            .padding(.bottom, 30 * scale)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Private Helper Methods
    
    /// Get visible items with manual scroll offset for preset2 (Setup Manager style after swap)
    /// Ordered: Installed → Installing → Pending
    private func getVisibleItemsWithOffset() -> [InspectConfig.ItemConfig] {
        let totalItems = inspectState.items.count
        guard totalItems > 0 else { return [] }
        
        // Separate into three categories: installed, installing, pending
        let completedItems = inspectState.items.filter { inspectState.completedItems.contains($0.id) }
        let downloadingItems = inspectState.items.filter { inspectState.downloadingItems.contains($0.id) }
        let pendingItems = inspectState.items.filter { 
            !inspectState.completedItems.contains($0.id) && !inspectState.downloadingItems.contains($0.id)
        }
        
        // Combine: completed first, then downloading, then pending
        let sortedItems = completedItems + downloadingItems + pendingItems
        
        if sortedItems.count <= 5 {
            // If 5 or fewer items total, show them all
            return sortedItems
        }
        
        // Use manual scroll offset on the sorted list
        let startIndex = max(0, min(inspectState.scrollOffset, sortedItems.count - 5))
        let endIndex = min(sortedItems.count, startIndex + 5)
        return Array(sortedItems[startIndex..<endIndex])
    }
    
    /// Check if we can scroll left (show earlier apps)
    private func canScrollLeft() -> Bool {
        return inspectState.scrollOffset > 0
    }
    
    /// Check if we can scroll right (show later items)
    private func canScrollRight() -> Bool {
        let totalItems = inspectState.items.count
        return inspectState.scrollOffset < max(0, totalItems - 5)
    }
    
    /// Get total items in sorted order (completed + pending)
    private func getSortedItemsCount() -> Int {
        return inspectState.items.count
    }
    
    /// Scroll left by one item
    private func scrollLeft() {
        if canScrollLeft() {
            inspectState.scrollOffset = max(0, inspectState.scrollOffset - 1)
            // Disable auto-scroll for 5 seconds after manual scroll
            inspectState.lastManualScrollTime = Date()
        }
    }
    
    /// Scroll right by one item
    private func scrollRight() {
        if canScrollRight() {
            let totalItems = getSortedItemsCount()
            inspectState.scrollOffset = min(max(0, totalItems - 5), inspectState.scrollOffset + 1)
            // Disable auto-scroll for 5 seconds after manual scroll
            inspectState.lastManualScrollTime = Date()
        }
    }
    
    /// Smart auto-scrolling to keep active installations in view
    private func smartAutoScroll() {
        // Only auto-scroll if we're in preset2 (Setup Manager style after swap)
        guard inspectState.uiConfiguration.preset == "preset2" else { return }
        
        // Don't auto-scroll if user manually scrolled in the last 5 seconds
        if let lastManualScroll = inspectState.lastManualScrollTime,
           Date().timeIntervalSince(lastManualScroll) < InspectConstants.manualScrollTimeoutInterval {
            return
        }
        
        let totalItems = inspectState.items.count
        guard totalItems > 5 else { return } // No scrolling needed if 5 or fewer items
        
        // Get sorted items in order: Installed → Installing → Pending
        let completedItems = inspectState.items.filter { inspectState.completedItems.contains($0.id) }
        let downloadingItems = inspectState.items.filter { inspectState.downloadingItems.contains($0.id) }
        let pendingItems = inspectState.items.filter { 
            !inspectState.completedItems.contains($0.id) && !inspectState.downloadingItems.contains($0.id)
        }
        
        let sortedItems = completedItems + downloadingItems + pendingItems
        
        // Find the optimal view window
        if !downloadingItems.isEmpty {
            // Priority 1: If items are installing, center them in view
            let firstDownloadingIndex = sortedItems.firstIndex(where: { inspectState.downloadingItems.contains($0.id) }) ?? 0
            let lastDownloadingIndex = sortedItems.lastIndex(where: { inspectState.downloadingItems.contains($0.id) }) ?? 0
            
            // Calculate the center position for downloading items
            let downloadingCenter = (firstDownloadingIndex + lastDownloadingIndex) / 2
            
            // Try to center the downloading items in the 5-card view
            var targetOffset = downloadingCenter - 2 // Center in a 5-card view
            
            // Adjust if multiple downloads span more than 5 cards
            if lastDownloadingIndex - firstDownloadingIndex >= 5 {
                // Show the first 5 downloading items
                targetOffset = firstDownloadingIndex
            }
            
            // Ensure we don't scroll past bounds
            targetOffset = max(0, min(targetOffset, totalItems - 5))
            inspectState.scrollOffset = targetOffset
            
        } else if completedItems.count > 0 && pendingItems.count > 0 {
            // Priority 2: Show boundary between completed and pending
            // Show the last 2 completed and first 3 pending
            let targetOffset = max(0, completedItems.count - 2)
            inspectState.scrollOffset = min(targetOffset, totalItems - 5)
            
        } else if pendingItems.count > 0 {
            // Priority 3: If only pending items remain, show the first ones
            inspectState.scrollOffset = completedItems.count
        }
        // If all items are completed, stay at current position
    }
}
