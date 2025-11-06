//
//  Preset3.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 19/07/2025
//
//  Compact and ultra-compact list style layout with gradient background and option for banner image
//

import SwiftUI

struct Preset3View: View, InspectLayoutProtocol {
    @ObservedObject var inspectState: InspectState
    @StateObject private var iconCache = PresetIconCache()

    init(inspectState: InspectState) {
        self.inspectState = inspectState
    }
    
    var body: some View {
        let textColor = getTextColor()
        
        ZStack {
            // Custom background (gradient, image, or color)
            customBackground()
            
            VStack(spacing: 0) {
                // Fixed header with title and button - always visible
                HStack {
                    Text(inspectState.uiConfiguration.windowTitle)
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(textColor)
                    Spacer()
                    
                    HStack(spacing: 12) {
                        // Button 2 (Secondary/Cancel) - Exit code 2
                        // Only show when all items are completed (like preset3)
                        if inspectState.completedItems.count == inspectState.items.count && 
                           inspectState.buttonConfiguration.button2Visible && !inspectState.buttonConfiguration.button2Text.isEmpty {
                            Button(inspectState.buttonConfiguration.button2Text) {
                                writeLog("Preset3LayoutServiceBased: User clicked button2 (\(inspectState.buttonConfiguration.button2Text)) - exiting with code 2", logLevel: .info)
                                exit(2)
                            }
                            .buttonStyle(.bordered)
                            // Note: button2 is always enabled when visible
                        }
                        
                        // Button 1 (Primary) - Exit code 0
                        Button(inspectState.buttonConfiguration.button1Text) {
                            writeLog("Preset3LayoutServiceBased: User clicked button1 (\(inspectState.buttonConfiguration.button1Text)) - exiting with code 0", logLevel: .info)
                            exit(0)
                        }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .disabled(inspectState.buttonConfiguration.button1Disabled)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color.primary.opacity(0.05))
                
                // Banner image at top if available
                if inspectState.uiConfiguration.bannerImage != nil {
                    if let bannerNSImage = iconCache.bannerImage {
                        ZStack(alignment: .bottomLeading) {
                            Image(nsImage: bannerNSImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxHeight: CGFloat(inspectState.uiConfiguration.bannerHeight))
                                .clipped()

                            // Optional title overlay on banner
                            if let bannerTitle = inspectState.uiConfiguration.bannerTitle {
                                Text(bannerTitle)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                                    .padding()
                            }
                        }
                        .frame(height: CGFloat(inspectState.uiConfiguration.bannerHeight))
                    }
                }

                // Company icon section - more compact
                HStack(spacing: 16) {
                    IconView(image: iconCache.getMainIconPath(for: inspectState), sfPaddingEnabled: false, corners: false, defaultImage: "building.2.fill", defaultColour: "accent")
                        .frame(width: 100 * scaleFactor, height: 100 * scaleFactor)
                        // Border removed
                        .onAppear {
                            iconCache.cacheMainIcon(for: inspectState)
                            iconCache.cacheBannerImage(for: inspectState)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        // Add subtitle message if available
                        if let subtitle = inspectState.uiConfiguration.subtitleMessage {
                            Text(subtitle)
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundColor(textColor)
                        }

                        if let currentMessage = inspectState.getCurrentSideMessage() {
                            Text(currentMessage)
                                .font(.subheadline)
                                .foregroundColor(textColor.opacity(0.9))
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                
                // Removed - message is now inline with logo
                
                // Scrollable app list with auto-scrolling
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        // Use two columns in compact mode, one column otherwise
                        let columns = sizeMode == "compact" ?
                            [GridItem(.flexible()), GridItem(.flexible())] :
                            [GridItem(.flexible())]

                        LazyVGrid(columns: columns, spacing: 6) {
                            let sortedItems = getSortedItemsByStatus() // Use simple order: Latest Completed → Installing → Waiting
                            ForEach(sortedItems, id: \.id) { item in
                                HStack {
                                    // Small item icon - use resolved path from cache
                                    IconView(image: iconCache.getItemIconPath(for: item, state: inspectState), sfPaddingEnabled: false, corners: false, defaultImage: "app.badge.fill", defaultColour: "accent")
                                        .frame(width: 24 * scaleFactor, height: 24 * scaleFactor)
                                        .id("icon-\(item.id)") // Stable ID to prevent recreation

                                    // Item name
                                    Text(item.displayName)
                                        .font(.body)
                                        .foregroundColor(textColor)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    // Status indicator with validation support
                                    statusIndicatorWithValidation(for: item, textColor: textColor)
                                }
                                .padding(.vertical, 3)
                                .padding(.horizontal, 8)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(6)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .onChange(of: inspectState.completedItems.count) {
                            // Auto-scroll to top when new item completes
                            let sortedItems = getSortedItemsByStatus()
                            if let firstItem = sortedItems.first {
                                withAnimation(.easeInOut(duration: InspectConstants.longAnimationDuration)) {
                                    proxy.scrollTo(firstItem.id, anchor: .top)
                                }
                            }
                            
                            // Auto-enable button when all items are completed
                            inspectState.checkAndUpdateButtonState()
                            
                            // Also trigger validation for completed items manually if needed
                            if inspectState.completedItems.count == inspectState.items.count {
                                // Ensure validation results are populated for UI display
                                Task { @MainActor in
                                    let completedItemsNeedingValidation = inspectState.items.filter { item in
                                        inspectState.completedItems.contains(item.id) &&
                                        (item.plistKey != nil || inspectState.plistSources?.contains(where: { source in
                                            item.paths.contains(source.path)
                                        }) == true)
                                    }
                                    
                                    for item in completedItemsNeedingValidation {
                                        if inspectState.plistValidationResults[item.id] == nil {
                                            writeLog("Preset3: Manual validation trigger for '\(item.id)' - missing from results dict", logLevel: .info)
                                            _ = inspectState.validatePlistItem(item)
                                        }
                                    }
                                }
                            }
                        }
                        .onChange(of: inspectState.downloadingItems.count) {
                            // Auto-scroll when installing status changes
                            let sortedItems = getSortedItemsByStatus()
                            if let firstInstalling = sortedItems.first(where: { inspectState.downloadingItems.contains($0.id) }) {
                                withAnimation(.easeInOut(duration: InspectConstants.longAnimationDuration)) {
                                    proxy.scrollTo(firstInstalling.id, anchor: .center)
                                }
                            }
                            
                            // Check button state when downloading status changes
                            inspectState.checkAndUpdateButtonState()
                        }
                        .onChange(of: inspectState.plistValidationResults) {
                            print("DEBUG Preset3: plistValidationResults changed: \(inspectState.plistValidationResults)")
                            // Force UI update when validation results change
                        }
                    }
                    .scrollIndicators(.visible, axes: .vertical)
                }
                
                // Progress bar section - moved to bottom as requested
                if !inspectState.items.isEmpty {
                    let progress = Double(inspectState.completedItems.count) / Double(inspectState.items.count)
                    let isComplete = inspectState.completedItems.count == inspectState.items.count
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(isComplete ? (inspectState.config?.uiLabels?.completionMessage ?? "Installation Complete!") : "Installation Progress")
                                .font(.headline)
                                .foregroundColor(textColor)
                            Spacer()
                            if isComplete {
                                Text(inspectState.config?.uiLabels?.completionSubtitle ?? "All installations completed successfully")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(textColor)
                            } else {
                                Text(PresetCommonViews.getProgressText(state: inspectState))
                                    .font(.subheadline)
                                    .foregroundColor(textColor.opacity(0.8))
                            }
                        }
                        
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .scaleEffect(y: 2.0)
                    }
                    .padding()
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 12) // Bottom spacing
                }
            }
        }
        .frame(width: windowSize.width, height: windowSize.height)
        .onAppear {
            // Main icon caching is already handled in the icon's .onAppear
            // LazyVGrid handles item icon loading as items become visible
        }
    }

    // MARK: - Icon Resolution Methods

    // Icon caching is now handled by PresetIconCache

    // MARK: - Private Helper Methods
    
    @ViewBuilder
    private func customBackground() -> some View {
        if !inspectState.backgroundConfiguration.gradientColors.isEmpty && inspectState.backgroundConfiguration.gradientColors.count >= 2 {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: inspectState.backgroundConfiguration.gradientColors.compactMap { Color(hex: $0) }),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if let backgroundImage = inspectState.backgroundConfiguration.backgroundImage,
                  FileManager.default.fileExists(atPath: backgroundImage),
                  let nsImage = NSImage(contentsOfFile: backgroundImage) {
            // Background image with proper frame constraints
            GeometryReader { geometry in
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .opacity(inspectState.backgroundConfiguration.backgroundOpacity)
            }
        } else if let backgroundColor = inspectState.backgroundConfiguration.backgroundColor {
            // Solid color background
            Color(hex: backgroundColor)
        } else {
            // Default background
            Color(NSColor.windowBackgroundColor)
        }
    }
    
    private func getTextColor() -> Color {
        if let textColor = inspectState.backgroundConfiguration.textOverlayColor {
            return Color(hex: textColor)
        }
        
        // Auto-contrast logic - if we have dark background, use light text
        if !inspectState.backgroundConfiguration.gradientColors.isEmpty || inspectState.backgroundConfiguration.backgroundImage != nil {
            return .white
        } else if let bgColor = inspectState.backgroundConfiguration.backgroundColor {
            // Simple heuristic: if color contains dark values, use white text
            if bgColor.lowercased().contains("dark") || bgColor == "#000000" {
                return .white
            }
        }
        
        return Color.primary // Default system color
    }
    
    private func getSortedItemsByStatus() -> [InspectConfig.ItemConfig] {
        return inspectState.items.sorted { item1, item2 in
            let status1 = getItemStatusPriority(item1)
            let status2 = getItemStatusPriority(item2)
            
            if status1 != status2 {
                return status1 < status2
            }
            
            // Same status - maintain original GUI order
            return item1.guiIndex < item2.guiIndex
        }
    }
    
    private func getItemStatusPriority(_ item: InspectConfig.ItemConfig) -> Int {
        if inspectState.downloadingItems.contains(item.id) {
            return 0 // Installing items first
        } else if inspectState.completedItems.contains(item.id) {
            return 1 // Completed items second
        } else {
            return 2 // Pending items last
        }
    }

    // MARK: - Validation Support

    private func hasValidationWarning(for item: InspectConfig.ItemConfig) -> Bool {
        print("DEBUG Preset3: hasValidationWarning called for item '\(item.id)'")
        
        // Only check validation for completed items  
        guard inspectState.completedItems.contains(item.id) else { 
            print("DEBUG Preset3: Item '\(item.id)' not completed - completedItems: \(inspectState.completedItems)")
            return false 
        }
        
        print("DEBUG Preset3: Item '\(item.id)' IS completed")
        
        // Check if item has any plist validation configuration
        let hasPlistValidation = item.plistKey != nil || 
                               inspectState.plistSources?.contains(where: { source in
                                   item.paths.contains(source.path)
                               }) == true
        
        print("DEBUG Preset3: Item '\(item.id)' - plistKey: '\(item.plistKey ?? "nil")', paths: \(item.paths), hasPlistValidation: \(hasPlistValidation)")
        
        // If item has plist validation, check the results
        if hasPlistValidation {
            // If validation result is missing, assume validation passed (true)
            // If validation result is false, that means validation failed, so we have a warning
            let validationResultFromDict = inspectState.plistValidationResults[item.id]
            let validationResult = validationResultFromDict ?? true
            let hasWarning = !validationResult  // Warning when validation result is false
            print("DEBUG Preset3: Item '\(item.id)' - raw value from dict: \(validationResultFromDict as Any), computed validationResult: \(validationResult), hasWarning: \(hasWarning)")
            print("DEBUG Preset3: Full validation results dict: \(inspectState.plistValidationResults)")
            print("DEBUG Preset3: Dictionary keys: \(Array(inspectState.plistValidationResults.keys))")
            
            // If validation result is missing but item has plist validation config, trigger validation manually
            if validationResultFromDict == nil {
                print("DEBUG Preset3: Item '\(item.id)' missing validation result - triggering manual validation")
                Task { @MainActor in
                    _ = inspectState.validatePlistItem(item)
                    print("DEBUG Preset3: Manual validation triggered for '\(item.id)'")
                }
                // For now, assume no warning until validation completes
                return false
            }
            
            return hasWarning
        }
        
        print("DEBUG Preset3: Item '\(item.id)' - no plist validation configured")
        return false
    }

    private func getStatusText(for item: InspectConfig.ItemConfig) -> String {
        if inspectState.completedItems.contains(item.id) {
            if hasValidationWarning(for: item) {
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
        } else if inspectState.downloadingItems.contains(item.id) {
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

    private func getStatusColor(for item: InspectConfig.ItemConfig) -> Color {
        if inspectState.completedItems.contains(item.id) {
            return hasValidationWarning(for: item) ? .yellow : .green
        } else if inspectState.downloadingItems.contains(item.id) {
            return .blue
        } else {
            return .secondary
        }
    }

    @ViewBuilder
    private func statusIndicatorWithValidation(for item: InspectConfig.ItemConfig, textColor: Color) -> some View {
        let isCompleted = inspectState.completedItems.contains(item.id)
        let hasWarning = hasValidationWarning(for: item)
        
        // Move print statements outside of ViewBuilder context
        let _ = print("DEBUG Preset3 UI: Item '\(item.id)' - isCompleted: \(isCompleted), hasWarning: \(hasWarning)")
        
        if isCompleted {
            // Completed - check for validation warnings (using same logic as Preset2)
            if hasWarning {
                let _ = print("DEBUG Preset3 UI: Showing 'Check Config' for '\(item.id)'")
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text("Check Config")
                        .font(.caption)
                        .foregroundColor(.yellow)
                        .fontWeight(.medium)
                }
                .help("Configuration validation failed - check plist settings")
            } else {
                let _ = print("DEBUG Preset3 UI: Showing '\(getStatusText(for: item))' for '\(item.id)'")
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text(getStatusText(for: item))
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
                .help("\(getStatusText(for: item)) and validated")
            }
        } else if inspectState.downloadingItems.contains(item.id) {
            let _ = print("DEBUG Preset3 UI: Showing '\(getStatusText(for: item))' for '\(item.id)'")
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
                Text(getStatusText(for: item))
                    .font(.caption)
                    .foregroundColor(textColor.opacity(0.7))
                    .fontWeight(.medium)
            }
        } else {
            let _ = print("DEBUG Preset3 UI: Showing '\(getStatusText(for: item))' for '\(item.id)'")
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .foregroundColor(textColor.opacity(0.5))
                    .font(.caption)
                Text(getStatusText(for: item))
                    .font(.caption)
                    .foregroundColor(textColor.opacity(0.7))
                    .fontWeight(.medium)
            }
        }
    }
}
