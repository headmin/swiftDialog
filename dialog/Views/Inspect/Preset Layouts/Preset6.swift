//
//  Preset6View.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 16/09/2025
//
//  Image carousel uin a ssplit layout with steps on right
//

import SwiftUI

struct Preset6View: View, InspectLayoutProtocol {
    @ObservedObject var inspectState: InspectState
    @State private var showingAboutPopover = false
    @State private var currentImageIndex = 0
    @State private var imageRotationTimer: Timer?
    @State private var validationResults: [String: Bool] = [:]
    @State private var pathCheckTimer: Timer?
    @State private var imageUpdateTimer: Timer?
    @State private var pendingImageIndex: Int?
    @State private var cachedImagePaths: [String] = []
    @StateObject private var iconCache = PresetIconCache()
    @State private var lastDownloadingCount = 0
    @State private var isInitialized = false
    @State private var lastDownloadingItemId: String? = nil
    @State private var autoAdvanceTimer: Timer?
    @State private var cachedBannerImage: NSImage? = nil
    @State private var bannerImageLoaded = false

    init(inspectState: InspectState) {
        self.inspectState = inspectState
    }

    var body: some View {
        let scale: CGFloat = scaleFactor
        // Dynamic dimensions based on window size from protocol
        let windowSize = self.windowSize
        let leftPanelWidth: CGFloat = windowSize.width * 0.45  // Left panel 45% of window width
        let totalWidth: CGFloat = windowSize.width

        GeometryReader { geometry in
            ZStack {
                // Main content structure
                VStack(spacing: 0) {
                    // Full-width banner at the top (if available and loaded)
                    if cachedBannerImage != nil {
                        fullWidthBanner(scale: scale)
                    } else {
                        // Unified header when no banner
                        unifiedHeader(scale: scale)
                    }

                    // Main content area
                    HStack(spacing: 0) {
                        // Left panel - Image and message
                        leftPanel(scale: scale)
                            .frame(width: leftPanelWidth)

                        // Right panel - Checklist
                        rightPanel(scale: scale)
                            .frame(width: totalWidth - leftPanelWidth)
                    }
                    .frame(maxHeight: .infinity)

                    // Button bar with clear separation - always at bottom
                    if hasButtons() {
                        Divider()
                        buttonBar(scale: scale)
                    }
                }

                // Vertical divider that spans from below header to above buttons
                VStack {
                    Rectangle()
                        .fill(Color(NSColor.separatorColor))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
                .frame(width: 1)
                .position(x: leftPanelWidth, y: {
                    let headerHeight: CGFloat
                    if cachedBannerImage != nil {
                        // Below banner (when banner is loaded)
                        headerHeight = CGFloat(inspectState.uiConfiguration.bannerHeight)
                        return geometry.size.height / 2 + headerHeight / 2
                    } else {
                        // Below unified header
                        headerHeight = 54 * scale // Match the unified header fixed height
                        return geometry.size.height / 2
                    }
                }())
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .ignoresSafeArea()
        .onAppear {
            if !isInitialized {
                cacheImagePaths()
                cacheItemIcons()
                cacheBannerImage()
                isInitialized = true
                // Initialize plist with images
                // Progress tracking now handled differently through the service architecture
            }
            startImageRotation()
            performInitialValidation()
            startPathMonitoring()
        }
        .onDisappear {
            stopImageRotation()
            stopPathMonitoring()
            imageUpdateTimer?.invalidate()
            imageUpdateTimer = nil
            autoAdvanceTimer?.invalidate()
            autoAdvanceTimer = nil
        }
        .onAppear {
            // Set up keyboard monitoring
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                handleKeyEvent(event)
            }
        }
        .onChange(of: inspectState.completedItems) {
            updateSyncedImage()

            // Auto-advance on item completion in manual mode
            if inspectState.uiConfiguration.imageSyncMode == "manual" {
                autoAdvanceOnCompletion()
            }
        }
        .onChange(of: inspectState.downloadingItems) {
            updateSyncedImage()
        }
        .onChange(of: validationResults) {
            // Also handle sync mode when validation results change
            if inspectState.uiConfiguration.imageSyncMode == "sync" {
                let completedCount = inspectState.completedItems.count +
                                   validationResults.values.filter { $0 }.count
                let imagePaths = getImagePaths()
                if !imagePaths.isEmpty && completedCount > 0 {
                    let targetIndex = min(completedCount - 1, imagePaths.count - 1)
                    if targetIndex != currentImageIndex && targetIndex >= 0 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentImageIndex = targetIndex
                        }
                    }
                }
            }
        }
    }

    // MARK: - Full Width Banner
    private func fullWidthBanner(scale: CGFloat) -> some View {
        let windowSize = self.windowSize
        let leftPanelWidth: CGFloat = windowSize.width * 0.45
        let bannerHeight = CGFloat(inspectState.uiConfiguration.bannerHeight)

        return Group {
            if let bannerImage = cachedBannerImage {
                ZStack(alignment: .topLeading) {
                    Image(nsImage: bannerImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: bannerHeight)
                        .frame(maxWidth: .infinity)
                        .clipped()

                    HStack(spacing: 0) {
                        // Left side - banner title
                        if let bannerTitle = inspectState.uiConfiguration.bannerTitle {
                            Text(bannerTitle)
                                .font(.system(size: 28 * scale, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(radius: 3)
                                .padding()
                                .frame(width: leftPanelWidth, alignment: .leading)
                        } else {
                            Spacer()
                                .frame(width: leftPanelWidth)
                        }

                        // Right side - static message overlay (from "message" field)
                        VStack {
                            Spacer()
                            Text(inspectState.uiConfiguration.statusMessage)
                                .font(.system(size: 16 * scale, weight: .medium))
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.horizontal, 30 * scale)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: bannerHeight)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Unified Header (Simplified)
    private func unifiedHeader(scale: CGFloat) -> some View {
        HStack(spacing: 0) {
            // Left: Title only
            Text(inspectState.uiConfiguration.windowTitle)
                .font(.system(size: 16 * scale, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)

            // Center divider (minimal)
            Rectangle()
                .fill(Color(NSColor.separatorColor).opacity(0.2))
                .frame(width: 1)
                .frame(height: 30 * scale)

            // Right: Message only
            Text(inspectState.uiConfiguration.statusMessage)
                .font(.system(size: 13 * scale))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12 * scale)
        .frame(height: 54 * scale) // Fixed height to ensure visibility
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.05))
        .overlay(
            Rectangle()
                .fill(Color(NSColor.separatorColor).opacity(0.15))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Left Panel
    private func leftPanel(scale: CGFloat) -> some View {
        VStack(spacing: 0) {

            // Main content area - image centered
            VStack(spacing: 0) {
                Spacer()

                // Image section (slightly smaller to accommodate sideMessage)
                if !getImagePaths().isEmpty {
                    imageDisplay(scale: scale * 0.75)
                } else {
                    defaultIcon(scale: scale * 0.75)
                }

                // Always show sideMessage below image (rotating messages array)
                // Fixed-height message section to prevent bumping
                VStack(spacing: 0) {
                    Spacer(minLength: 20 * scale)

                    // Rotating side messages
                    Group {
                        if let currentMessage = inspectState.getCurrentSideMessage() {
                            Text(currentMessage)
                                .font(.system(size: 14 * scale))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)  // Limit to prevent excessive growth
                                .animation(.easeInOut(duration: 0.5), value: inspectState.uiConfiguration.currentSideMessageIndex)
                        } else if let subtitle = inspectState.uiConfiguration.subtitleMessage, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.system(size: 14 * scale))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                        } else {
                            // Empty text to maintain space
                            Text(" ")
                                .font(.system(size: 14 * scale))
                        }
                    }
                    .padding(.horizontal, 20 * scale)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50 * scale)  // Fixed minimum height for text area

                    Spacer(minLength: 10 * scale)
                }
                .frame(height: 90 * scale)  // Fixed total height for message section

                // Integrated Navigation Card for manual mode
                if inspectState.uiConfiguration.imageSyncMode == "manual" && getImagePaths().count > 1 {
                    navigationCard(scale: scale)
                        .padding(.bottom, 15 * scale)
                } else if !getImagePaths().isEmpty && getImagePaths().count > 1 {
                    // Show simple counter for other modes
                    VStack(spacing: 6 * scale) {
                        Text("\(getCurrentImageIndex() + 1) / \(getImagePaths().count)")
                            .font(.system(size: 13 * scale, weight: .medium))
                            .foregroundColor(.secondary)

                        // Progress dots
                        progressDots(scale: scale)
                    }
                    .padding(.bottom, 15 * scale)
                } else {
                    // Add spacer to maintain layout
                    Spacer()
                        .frame(height: 50 * scale)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Removed divider for cleaner look

            // Bottom section - exactly 60pt to match right side
            ZStack {
                // Progress indicator centered
                HStack {
                    Spacer()
                    if !inspectState.items.isEmpty {
                        progressIndicator(scale: scale)
                    }
                    Spacer()
                }

                // Info button overlaid on the left
                HStack {
                    infoButton(scale: scale)
                        .padding(.leading, 10 * scale)
                    Spacer()
                }
            }
            .frame(height: 60 * scale)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Right Panel
    private func rightPanel(scale: CGFloat) -> some View {
        VStack(spacing: 0) {

            // Removed divider for cleaner look

            // Main content area - checklist items
            ScrollView {
                VStack(alignment: .leading, spacing: 8 * scale) {
                    ForEach(Array(inspectState.items.enumerated()), id: \.element.id) { index, item in
                        VStack(spacing: 0) {
                            checklistItem(
                                item: item,
                                index: index,
                                scale: scale
                            )
                            .id("checklist-\(item.id)") // Stable ID for each item
                            .background(
                                // Highlight the current item when its image is shown
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        isItemHighlighted(item: item, at: index)
                                        ? Color.accentColor.opacity(0.1)
                                        : Color.clear
                                    )
                                    .padding(.horizontal, -12 * scale)
                                    .animation(.easeInOut(duration: 0.3), value: getCurrentImageIndex())
                            )

                            if inspectState.uiConfiguration.stepStyle != "cards" && index < inspectState.items.count - 1 {
                                Divider()
                                    .padding(.leading, 50 * scale)
                            }
                        }
                    }
                }
                .padding(.vertical, 8 * scale)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Divider above the bottom section
            Divider()

            // Bottom section - 60pt status area
            HStack {
                Spacer()

                if allItemsCompleted() {
                    completionStatus(scale: scale)
                }

                Spacer()
            }
            .frame(height: 60 * scale)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Image Display
    private func imageDisplay(scale: CGFloat) -> some View {
        let imagePaths = cachedImagePaths.isEmpty ? getImagePaths() : cachedImagePaths
        let currentIndex = min(currentImageIndex, max(0, imagePaths.count - 1))
        let imageSize = getImageSize(scale: scale)

        return ZStack {
            if currentIndex < imagePaths.count {
                let imagePath = imagePaths[currentIndex]

                if let nsImage = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: imageSize.width, height: imageSize.height)
                        .clipShape(imageShape())
                        .id("image-\(currentIndex)") // Stable ID for SwiftUI
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 1.05))
                        ))
                } else {
                    // Fallback for failed image load
                    VStack {
                        Image(systemName: "photo")
                            .font(.system(size: 60 * scale))
                            .foregroundColor(.secondary)
                        Text("Failed: \(imagePath)")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                    }
                    .frame(width: imageSize.width, height: imageSize.height)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(imageShape())
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: currentImageIndex)
    }

    private func getImageSize(scale: CGFloat) -> CGSize {
        switch inspectState.uiConfiguration.imageFormat {
        case "round":
            // Circle - always square aspect ratio - larger for better visibility
            return CGSize(width: 320 * scale, height: 320 * scale)
        case "rectangle":
            // Rectangle - 4:3 aspect ratio - increased size for impact
            return CGSize(width: 360 * scale, height: 270 * scale)
        default:
            // Square - standard square with rounded corners - maximized size
            return CGSize(width: 320 * scale, height: 320 * scale)
        }
    }

    private func imageShape() -> some Shape {
        switch inspectState.uiConfiguration.imageFormat {
        case "round":
            return AnyShape(Circle())
        case "rectangle":
            return AnyShape(RoundedRectangle(cornerRadius: 8))
        case "square":
            return AnyShape(RoundedRectangle(cornerRadius: 12))
        default:
            return AnyShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Default Icon
    private func defaultIcon(scale: CGFloat) -> some View {
        Image(systemName: "checkmark.shield.fill")
            .font(.system(size: 100 * scale))
            .foregroundColor(.secondary)
            .frame(width: 240 * scale, height: 240 * scale)
    }

    // MARK: - Integrated Navigation Card
    private func navigationCard(scale: CGFloat) -> some View {
        HStack(spacing: 0) {
            // Previous button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    previousImage()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16 * scale, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 32 * scale, height: 32 * scale)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .help("Previous image (←)")

            // Counter and dots in the middle
            VStack(spacing: 6 * scale) {
                Text("\(getCurrentImageIndex() + 1) / \(getImagePaths().count)")
                    .font(.system(size: 14 * scale, weight: .semibold))
                    .foregroundColor(.primary)

                // Progress dots
                progressDots(scale: scale)
            }
            .frame(minWidth: 100 * scale)
            .padding(.horizontal, 16 * scale)

            // Next button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    nextImage()
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16 * scale, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 32 * scale, height: 32 * scale)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .help("Next image (→)")
        }
        .padding(.horizontal, 12 * scale)
        .padding(.vertical, 8 * scale)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Progress Dots Indicator
    private func progressDots(scale: CGFloat) -> some View {
        HStack(spacing: 6 * scale) {
            ForEach(0..<getImagePaths().count, id: \.self) { index in
                Circle()
                    .fill(
                        index == getCurrentImageIndex()
                        ? Color.accentColor
                        : Color.secondary.opacity(0.3)
                    )
                    .frame(width: 6 * scale, height: 6 * scale)
                    .animation(.easeInOut(duration: 0.2), value: getCurrentImageIndex())
            }
        }
    }

    // MARK: - Keyboard Navigation
    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard inspectState.uiConfiguration.imageSyncMode == "manual" else {
            return event
        }

        switch event.keyCode {
        case 123: // Left arrow
            withAnimation(.easeInOut(duration: 0.3)) {
                previousImage()
            }
            return nil
        case 124: // Right arrow
            withAnimation(.easeInOut(duration: 0.3)) {
                nextImage()
            }
            return nil
        default:
            return event
        }
    }

    // MARK: - Auto-advance on Completion
    private func autoAdvanceOnCompletion() {
        // Cancel any existing timer
        autoAdvanceTimer?.invalidate()

        // Set up a timer to auto-advance after 1.5 seconds
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            let imagePaths = getImagePaths()
            if !imagePaths.isEmpty && currentImageIndex < imagePaths.count - 1 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentImageIndex += 1
                }
            }
        }
    }

    // MARK: - Highlight Current Item
    private func isItemHighlighted(item: InspectConfig.ItemConfig, at index: Int) -> Bool {
        // Only highlight in manual mode when showing rotating images
        guard inspectState.uiConfiguration.imageSyncMode == "manual",
              !getImagePaths().isEmpty else {
            return false
        }

        // Match the index with the current image index
        // This assumes items correspond to images in order
        return index == getCurrentImageIndex()
    }

    // MARK: - Banner Image Caching
    private func cacheBannerImage() {
        print("Preset6: cacheBannerImage called")
        print("Preset6: Current cachedBannerImage: \(cachedBannerImage == nil ? "nil" : "exists")")
        print("Preset6: Banner path from config: \(inspectState.uiConfiguration.bannerImage ?? "nil")")
        print("Preset6: IconBasePath: \(inspectState.uiConfiguration.iconBasePath ?? "nil")")

        guard cachedBannerImage == nil,
              let bannerPath = inspectState.uiConfiguration.bannerImage else {
            print("Preset6: No banner path configured or already cached")
            return
        }

        print("Preset6: Attempting to load banner from: \(bannerPath)")

        // Cache banner using PresetIconCache
        iconCache.cacheBannerImage(for: inspectState)

        if let nsImage = iconCache.bannerImage {
            cachedBannerImage = nsImage
            bannerImageLoaded = true
            print("Preset6: Banner image loaded successfully, size: \(nsImage.size)")
        } else {
            print("Preset6: Failed to load banner image")
        }
    }

    private func getBannerImage() -> NSImage? {
        // Return cached image if available
        if let cachedImage = cachedBannerImage {
            return cachedImage
        }

        // Otherwise load and cache it
        cacheBannerImage()
        return cachedBannerImage
    }

    // MARK: - Progress Indicator
    private func progressIndicator(scale: CGFloat) -> some View {
        VStack(spacing: 8 * scale) {
            let progress = Double(inspectState.completedItems.count) / Double(inspectState.items.count)

            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: 250 * scale)

            Text("\(inspectState.completedItems.count) of \(inspectState.items.count) completed")
                .font(.system(size: 11 * scale))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Info Button
    private func infoButton(scale: CGFloat) -> some View {
        HStack {
            Button(action: { showingAboutPopover.toggle() }) {
                Image(systemName: "info.circle")
                    .font(.system(size: 18 * scale))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .popover(isPresented: $showingAboutPopover) {
                InstallationInfoPopoverView(inspectState: inspectState)
            }
            .padding(.leading, 20 * scale)

            Spacer()
        }
    }

    // MARK: - Checklist Item
    private func checklistItem(item: InspectConfig.ItemConfig, index: Int, scale: CGFloat) -> some View {
        let stepStyle = inspectState.uiConfiguration.stepStyle

        print("Preset6: stepStyle = '\(stepStyle)'")
        switch stepStyle {
        case "cards":
            // Card style with rounded rectangles (alpha-inspired)
            return AnyView(cardStyleItem(item: item, index: index, scale: scale))

        case "colored":
            // Colored round indicators
            return AnyView(
                HStack(spacing: 15 * scale) {
                    ZStack {
                        Circle()
                            .fill(
                                (validationResults[item.id] == true || inspectState.completedItems.contains(item.id)) ?
                                Color.green :
                                (inspectState.downloadingItems.contains(item.id) ?
                                 Color.blue :
                                 Color.gray.opacity(0.15))
                            )
                            .frame(width: 28 * scale, height: 28 * scale)

                        if validationResults[item.id] == true || inspectState.completedItems.contains(item.id) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14 * scale, weight: .bold))
                                .foregroundColor(.white)
                        } else if inspectState.downloadingItems.contains(item.id) {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 14 * scale, height: 14 * scale)
                                .tint(.white)
                                .frame(width: 14 * scale, height: 14 * scale)
                        } else {
                            Text(getListIndicator(for: index))
                                .font(.system(size: 12 * scale, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4 * scale) {
                        Text(item.displayName)
                            .font(.system(size: 14 * scale, weight: .medium))
                            .foregroundColor(.primary)

                        if let subtitle = item.subtitle {
                            Text(subtitle)
                                .font(.system(size: 11 * scale))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Display item icon if available (using cached path)
                    let resolvedPath = iconCache.getItemIconPath(for: item, state: inspectState)
                    if !resolvedPath.isEmpty {
                        IconView(
                            image: resolvedPath,
                            defaultImage: "folder",
                            defaultColour: "gray"
                        )
                        .frame(width: 20 * scale, height: 20 * scale)
                        .id("icon-\(item.id)") // Stable ID to prevent recreation
                    }
                }
                .padding(.horizontal, 20 * scale)
                .padding(.vertical, 12 * scale)
                .background(
                    getCurrentImageIndex() == index ?
                    Color.accentColor.opacity(0.1) : Color.clear
                )
            )

        default: // "plain"
            // Plain circle indicators
            return AnyView(
                HStack(spacing: 15 * scale) {
                    ZStack {
                        Circle()
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            .frame(width: 24 * scale, height: 24 * scale)

                        if validationResults[item.id] == true || inspectState.completedItems.contains(item.id) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12 * scale, weight: .semibold))
                                .foregroundColor(.green)
                        } else if inspectState.downloadingItems.contains(item.id) {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 14 * scale, height: 14 * scale)
                        } else {
                            Text(getListIndicator(for: index))
                                .font(.system(size: 11 * scale, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4 * scale) {
                        Text(item.displayName)
                            .font(.system(size: 14 * scale, weight: .medium))
                            .foregroundColor(.primary)

                        if let subtitle = item.subtitle {
                            Text(subtitle)
                                .font(.system(size: 11 * scale))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Display item icon if available (using cached path)
                    let resolvedPath = iconCache.getItemIconPath(for: item, state: inspectState)
                    if !resolvedPath.isEmpty {
                        IconView(
                            image: resolvedPath,
                            defaultImage: "folder",
                            defaultColour: "gray"
                        )
                        .frame(width: 20 * scale, height: 20 * scale)
                        .id("icon-\(item.id)") // Stable ID to prevent recreation
                    }
                }
                .padding(.horizontal, 20 * scale)
                .padding(.vertical, 12 * scale)
                .background(
                    getCurrentImageIndex() == index ?
                    Color.accentColor.opacity(0.1) : Color.clear
                )
            )
        }
    }

    // MARK: - Card Style Item
    private func cardStyleItem(item: InspectConfig.ItemConfig, index: Int, scale: CGFloat) -> some View {
        let isHighlighted = getCurrentImageIndex() == index
        let isCompleted = inspectState.completedItems.contains(item.id)
        let isInProgress = inspectState.downloadingItems.contains(item.id)

        let statusColor: Color = isCompleted ? .green : (isInProgress ? .blue : .gray.opacity(0.5))
        let statusText = isCompleted ? "Complete" : (isInProgress ? "Installing..." : "Pending")
        let statusTextColor: Color = isCompleted ? .green : (isInProgress ? .blue : .secondary)
        let bgColor = isHighlighted ? Color.orange.opacity(0.1) :
                      (isCompleted ? Color.green.opacity(0.05) : Color(NSColor.controlBackgroundColor))
        let borderColor = isHighlighted ? Color.orange.opacity(0.6) :
                         (isCompleted ? Color.green.opacity(0.3) : Color.clear)

        return HStack(spacing: 0) {
            // Status circle on left
            Circle()
                .fill(statusColor)
                .frame(width: 28 * scale, height: 28 * scale)
                .overlay(statusIndicatorContent(isCompleted: isCompleted, isInProgress: isInProgress, index: index, scale: scale))
                .padding(.leading, 20 * scale)
                .padding(.trailing, 15 * scale)

            // Content area
            VStack(alignment: .leading, spacing: 4 * scale) {
                Text(item.displayName)
                    .font(.system(size: 16 * scale, weight: .medium))
                    .foregroundColor(isCompleted ? .secondary : .primary)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 13 * scale))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 15 * scale)

            Spacer()

            // Status text on right
            Text(statusText)
                .font(.system(size: 12 * scale, weight: .medium))
                .foregroundColor(statusTextColor)
                .padding(.trailing, 20 * scale)
        }
        .background(
            RoundedRectangle(cornerRadius: 12 * scale)
                .fill(bgColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12 * scale)
                .stroke(borderColor, lineWidth: isHighlighted ? 2 : 1)
        )
        .padding(.horizontal, 16 * scale)
        .padding(.vertical, 6 * scale)
    }

    @ViewBuilder
    private func statusIndicatorContent(isCompleted: Bool, isInProgress: Bool, index: Int, scale: CGFloat) -> some View {
        if isCompleted {
            Image(systemName: "checkmark")
                .font(.system(size: 14 * scale, weight: .bold))
                .foregroundColor(.white)
        } else if isInProgress {
            ProgressView()
                .scaleEffect(0.6)
                .tint(.white)
                .frame(width: 16 * scale, height: 16 * scale)
        } else {
            Text(getListIndicator(for: index))
                .font(.system(size: 14 * scale, weight: .bold))
                .foregroundColor(.white)
        }
    }

    // MARK: - Completion Status
    private func completionStatus(scale: CGFloat) -> some View {
        HStack(spacing: 10 * scale) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20 * scale))
                .foregroundColor(.green)

            Text("Setup Complete")
                .font(.system(size: 14 * scale, weight: .semibold))
                .foregroundColor(.primary)
        }
    }

    // MARK: - Button Bar
    private func buttonBar(scale: CGFloat) -> some View {
        HStack(spacing: 12 * scale) {
            Spacer()

            if !inspectState.buttonConfiguration.button2Text.isEmpty {
                Button(action: {
                    writeLog("Preset6View: User clicked button2 (\(inspectState.buttonConfiguration.button2Text)) - exiting with code 2", logLevel: .info)
                    exit(2)
                }) {
                    Text(inspectState.buttonConfiguration.button2Text)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                // Note: button2 is always enabled when visible
            }

            if !inspectState.buttonConfiguration.button1Text.isEmpty {
                Button(action: {
                    writeLog("Preset6View: User clicked button1 (\(inspectState.buttonConfiguration.button1Text)) - exiting with code 0", logLevel: .info)
                    exit(0)
                }) {
                    Text(inspectState.buttonConfiguration.button1Text)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(inspectState.buttonConfiguration.button1Disabled)
            }
        }
        .padding(.horizontal, 20 * scale)
        .padding(.vertical, 12 * scale)  // Balanced vertical padding
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Validation Methods

    private func performInitialValidation() {
        // Perform initial validation for all items
        for item in inspectState.items {
            validateItem(item)
        }
    }

    private func validateItem(_ item: InspectConfig.ItemConfig) {
        // Check if item has plist validation
        if item.plistKey != nil {
            // Use plist validation
            let isValid = inspectState.validatePlistItem(item)
            validationResults[item.id] = isValid
        } else {
            // Check paths for file/folder existence
            let isValid = item.paths.first(where: { FileManager.default.fileExists(atPath: $0) }) != nil
            validationResults[item.id] = isValid
        }
    }

    private func startPathMonitoring() {
        // Start a timer to periodically check paths and plist values
        pathCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            for item in inspectState.items {
                validateItem(item)
            }
        }
    }

    private func stopPathMonitoring() {
        pathCheckTimer?.invalidate()
        pathCheckTimer = nil
    }

    // MARK: - Helper Functions

    private func hasButtons() -> Bool {
        !inspectState.buttonConfiguration.button1Text.isEmpty ||
        !inspectState.buttonConfiguration.button2Text.isEmpty
    }

    private func getListIndicator(for index: Int) -> String {
        // Check for listStyle configuration option
        // Default to numbers (1, 2, 3) for clearer ordering
        let listStyle = inspectState.uiConfiguration.listIndicatorStyle ?? "numbers"

        // Debug logging to verify config is loaded
        print("Preset6: listIndicatorStyle = '\(listStyle)' (from config: '\(inspectState.uiConfiguration.listIndicatorStyle)')")

        switch listStyle {
        case "numbers":
            return String(index + 1)
        case "letters":
            return String(Character(UnicodeScalar(65 + index) ?? "A"))
        case "roman":
            // Roman numerals for fancy lists
            let romanNumerals = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
                                "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX"]
            return index < romanNumerals.count ? romanNumerals[index] : String(index + 1)
        default:
            return String(Character(UnicodeScalar(65 + index) ?? "A"))
        }
    }

    private func cacheImagePaths() {
        let basePath = inspectState.uiConfiguration.iconBasePath

        // Debug logging
        writeLog("Preset6: cacheImagePaths - basePath: \(basePath ?? "nil")", logLevel: .debug)
        writeLog("Preset6: cacheImagePaths - rotatingImages: \(inspectState.uiConfiguration.rotatingImages)", logLevel: .debug)

        var resolvedPaths: [String] = []
        for imagePath in inspectState.uiConfiguration.rotatingImages {
            if let resolved = iconCache.resolveImagePath(imagePath, basePath: basePath) {
                writeLog("Preset6: Resolving '\(imagePath)' -> '\(resolved)'", logLevel: .debug)
                resolvedPaths.append(resolved)
            } else {
                writeLog("Preset6: Failed to resolve '\(imagePath)'", logLevel: .debug)
            }
        }

        cachedImagePaths = resolvedPaths
        writeLog("Preset6: cacheImagePaths - cached \(cachedImagePaths.count) images from \(inspectState.uiConfiguration.rotatingImages.count) input images", logLevel: .debug)
    }

    private func cacheItemIcons() {
        // Use PresetIconCache to cache item icons
        iconCache.cacheItemIcons(for: inspectState, limit: 30)
    }

    private func getImagePaths() -> [String] {
        // Directly compute paths instead of relying on cached values
        let basePath = inspectState.uiConfiguration.iconBasePath

        return inspectState.uiConfiguration.rotatingImages.compactMap { imagePath in
            iconCache.resolveImagePath(imagePath, basePath: basePath)
        }
    }

    private func getCurrentImageIndex() -> Int {
        min(currentImageIndex, max(0, getImagePaths().count - 1))
    }

    private func updateSyncedImage() {
        let syncMode = inspectState.uiConfiguration.imageSyncMode
        guard syncMode == "sync" || syncMode == "latestOnly" else { return }

        let imagePaths = getImagePaths()
        guard !imagePaths.isEmpty else { return }

        // Check if downloading count changed (new download started)
        let currentDownloadingCount = inspectState.downloadingItems.count
        let isNewDownload = currentDownloadingCount > lastDownloadingCount
        lastDownloadingCount = currentDownloadingCount

        // For latestOnly mode - simple logic: show downloading item, no rotation during downloads
        if syncMode == "latestOnly" {
            let hasDownloads = !inspectState.downloadingItems.isEmpty

            if hasDownloads {
                // Stop any rotation
                stopImageRotation()

                // Mark that we're in download mode
                if lastDownloadingItemId == nil {
                    lastDownloadingItemId = "downloading"
                }

                // Find latest downloading item (last one in the list)
                for (index, item) in inspectState.items.enumerated().reversed() {
                    if inspectState.downloadingItems.contains(item.id) {
                        let targetIndex = min(index, imagePaths.count - 1)

                        // Only update if actually changing index
                        if currentImageIndex != targetIndex {
                            currentImageIndex = targetIndex
                        }
                        break
                    }
                }
            } else if lastDownloadingItemId != nil {
                // Downloads just finished - resume rotation
                lastDownloadingItemId = nil
                startImageRotation()
            }
            return
        }

        // Original sync mode logic
        var targetIndex: Int? = nil

        // Priority 1: Show image for the LATEST downloading item (most recently started)
        if !inspectState.downloadingItems.isEmpty {
            for (index, item) in inspectState.items.enumerated().reversed() {
                if inspectState.downloadingItems.contains(item.id) {
                    targetIndex = min(index, imagePaths.count - 1)
                    break
                }
            }
        }

        // Priority 2: If nothing downloading, show last completed item
        if targetIndex == nil {
            let completedCount = inspectState.completedItems.count +
                               validationResults.values.filter { $0 }.count

            if completedCount > 0 {
                targetIndex = min(completedCount - 1, imagePaths.count - 1)
            }
        }

        // Apply image change with debouncing to prevent flicker
        if let newIndex = targetIndex, newIndex != currentImageIndex {
            // Cancel any pending image update
            imageUpdateTimer?.invalidate()
            pendingImageIndex = newIndex

            // Use shorter delay for new downloads, longer for other changes
            let delay = isNewDownload ? 0.1 : 0.8

            imageUpdateTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
                if let pending = pendingImageIndex, pending != currentImageIndex {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentImageIndex = pending
                    }
                }
                pendingImageIndex = nil
            }
        }
    }

    private func allItemsCompleted() -> Bool {
        !inspectState.items.isEmpty &&
        inspectState.completedItems.count == inspectState.items.count
    }

    private func previousImage() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentImageIndex > 0 {
                currentImageIndex -= 1
            } else {
                currentImageIndex = getImagePaths().count - 1
            }
        }
    }

    private func nextImage() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentImageIndex < getImagePaths().count - 1 {
                currentImageIndex += 1
            } else {
                currentImageIndex = 0
            }
        }
    }

    private func startImageRotation() {
        guard inspectState.uiConfiguration.imageSyncMode != "manual",
              inspectState.uiConfiguration.imageRotationInterval > 0,
              getImagePaths().count > 1 else { return }

        let interval = inspectState.uiConfiguration.imageRotationInterval

        imageRotationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            nextImage()
        }
    }

    private func stopImageRotation() {
        imageRotationTimer?.invalidate()
        imageRotationTimer = nil
    }

    private func customBackground() -> some View {
        Color(NSColor.windowBackgroundColor)
    }
}


// MARK: - Shape Helper
struct AnyShape: Shape {
    private let _path: @Sendable (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}
