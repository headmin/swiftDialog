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
    @State private var cachedMainIcon: String? = nil
    @State private var cachedItemIcons: [String: String] = [:]

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
                if let bannerImagePath = inspectState.uiConfiguration.bannerImage {
                    let resolver = ImageResolver.shared
                    let resolvedPath = resolver.resolveImagePath(bannerImagePath,
                                                                 basePath: inspectState.uiConfiguration.iconBasePath,
                                                                 fallbackIcon: nil)

                    if let resolvedPath = resolvedPath,
                       FileManager.default.fileExists(atPath: resolvedPath),
                       let nsImage = NSImage(contentsOfFile: resolvedPath) {
                        ZStack(alignment: .bottomLeading) {
                            Image(nsImage: nsImage)
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
                HStack(spacing: 12) {
                    IconView(image: getMainIconPath(), sfPaddingEnabled: false, corners: false, defaultImage: "building.2.fill", defaultColour: "accent")
                        .frame(width: 80 * scaleFactor, height: 80 * scaleFactor)
                        // Border removed
                        .onAppear { cacheMainIcon() }

                    VStack(alignment: .leading, spacing: 4) {
                        // Add subtitle message if available
                        if let subtitle = inspectState.uiConfiguration.subtitleMessage {
                            Text(subtitle)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(textColor)
                        }

                        if let currentMessage = inspectState.getCurrentSideMessage() {
                            Text(currentMessage)
                                .font(.body)
                                .foregroundColor(textColor.opacity(0.9))
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
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
                                    IconView(image: getItemIconPath(for: item), sfPaddingEnabled: false, corners: false, defaultImage: "app.badge.fill", defaultColour: "accent")
                                        .frame(width: 24 * scaleFactor, height: 24 * scaleFactor)
                                        .id("icon-\(item.id)") // Stable ID to prevent recreation

                                    // Item name
                                    Text(item.displayName)
                                        .font(.body)
                                        .foregroundColor(textColor)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    // Status indicator
                                    if inspectState.completedItems.contains(item.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.title3)
                                    } else if inspectState.downloadingItems.contains(item.id) {
                                        HStack(spacing: 8) { // More spacing between spinner and text
                                            ProgressView()
                                                .scaleEffect(0.6) // Much smaller spinner
                                                .frame(width: 12, height: 12) // Smaller fixed size
                                            Text("Installing...")
                                                .font(.caption)
                                                .foregroundColor(textColor.opacity(0.7))
                                        }
                                    } else {
                                        Text("Pending")
                                            .font(.caption)
                                            .foregroundColor(textColor.opacity(0.7))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Color.primary.opacity(0.1))
                                            .cornerRadius(4)
                                    }
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
                    }
                    .scrollIndicators(.visible, axes: .vertical)
                }
                
                // Progress bar section - moved to bottom as requested
                if !inspectState.items.isEmpty {
                    let progress = Double(inspectState.completedItems.count) / Double(inspectState.items.count)
                    let isComplete = inspectState.completedItems.count == inspectState.items.count
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(isComplete ? "Installation Complete!" : "Installation Progress")
                                .font(.headline)
                                .foregroundColor(textColor)
                            Spacer()
                            if isComplete {
                                Text("All installations completed successfully")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(textColor)
                            } else {
                                Text("\(inspectState.completedItems.count) of \(inspectState.items.count) completed")
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
        .onAppear {
            cacheMainIcon()
            cacheItemIcons()
        }
    }

    // MARK: - Icon Resolution Methods

    private func cacheMainIcon() {
        let basePath = inspectState.uiConfiguration.iconBasePath
        let resolver = ImageResolver.shared

        if let iconPath = inspectState.uiConfiguration.iconPath {
            cachedMainIcon = resolver.resolveImagePath(iconPath, basePath: basePath, fallbackIcon: nil)
        }
    }

    private func cacheItemIcons() {
        let basePath = inspectState.uiConfiguration.iconBasePath
        let resolver = ImageResolver.shared

        for item in inspectState.items {
            if let icon = item.icon {
                if let resolvedPath = resolver.resolveImagePath(icon, basePath: basePath, fallbackIcon: nil) {
                    cachedItemIcons[item.id] = resolvedPath
                }
            }
        }
    }

    private func getMainIconPath() -> String {
        if let cached = cachedMainIcon {
            return cached
        }

        let basePath = inspectState.uiConfiguration.iconBasePath
        let resolver = ImageResolver.shared

        if let iconPath = inspectState.uiConfiguration.iconPath {
            let resolved = resolver.resolveImagePath(iconPath, basePath: basePath, fallbackIcon: nil) ?? ""
            cachedMainIcon = resolved
            return resolved
        }

        return ""
    }

    private func getItemIconPath(for item: InspectConfig.ItemConfig) -> String {
        // Return cached path if available
        if let cached = cachedItemIcons[item.id] {
            return cached
        }

        // Resolve and cache
        let basePath = inspectState.uiConfiguration.iconBasePath
        let resolver = ImageResolver.shared

        if let icon = item.icon {
            if let resolved = resolver.resolveImagePath(icon, basePath: basePath, fallbackIcon: nil) {
                cachedItemIcons[item.id] = resolved
                return resolved
            }
        }

        return ""
    }

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
}
