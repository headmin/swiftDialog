//
//  Preset7View.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 21/09/2025
//
//  Preset7: Interactive Step-by-Step Guide
//  Horizontal layout with images loaded from JSON and optional app icon bubbles
//

import SwiftUI

// MARK: - Preset7 State Definition

/// State structure for Preset7 persistence
struct Preset7State: InspectPersistableState {
    let completedSteps: Set<String>
    let currentPage: Int
    let currentStep: Int
    let timestamp: Date
}

// MARK: - Preset7 View

struct Preset7View: View, InspectLayoutProtocol {
    @ObservedObject var inspectState: InspectState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var completedSteps: Set<String> = []
    @State private var failedSteps: Set<String> = []  // Track failed items
    @State private var currentStep: Int = 0
    @StateObject private var iconCache = PresetIconCache()
    @State private var showSuccess: Bool = false
    @State private var currentPage: Int = 0  // Track which page of cards we're viewing
    @State private var externalMonitoringTimer: Timer?  // Store timer for proper cleanup
    @State private var showResetFeedback: Bool = false  // Visual feedback for option-click reset on step indicator
    @FocusState private var focusedCardIndex: Int?  // Track focused card for keyboard navigation
    @State private var autoPageNavigationWorkItem: DispatchWorkItem?  // Auto-page navigation timer (for cancellation on manual/external navigation)
    private let persistence = InspectPersistence<Preset7State>(presetName: "preset7")

    // Dynamic cards per page based on size mode
    private var cardsPerPage: Int {
        switch sizeMode {
        case "compact": return 2
        case "large": return 4
        default: return 3  // standaed - horizontal carusel
        }
    }

    // Card size - make smaller when banner present
    private var cardWidth: CGFloat {
        inspectState.uiConfiguration.bannerImage != nil ? 240 : 280
    }

    private var cardHeight: CGFloat {
        inspectState.uiConfiguration.bannerImage != nil ? 220 : 260
    }

    // MARK: - Color Helpers

    /// Gets configurable highlight color for primary UI elements (buttons, active states, progress)
    /// Falls back to system accent color if no custom color is configured
    private func getConfigurableHighlightColor() -> Color {
        if let highlightColor = inspectState.config?.highlightColor {
            return Color(hex: highlightColor)
        }
        // Check if default color is still set (gray), if so use system accent
        let defaultColor = inspectState.uiConfiguration.highlightColor
        if defaultColor == "#808080" {
            return Color.accentColor
        }
        return Color(hex: defaultColor)
    }

    /// Gets configurable secondary color for secondary UI elements (text, borders, accents)
    /// Falls back to system secondary color if no custom color is configured
    private func getConfigurableSecondaryColor() -> Color {
        if let secondaryColor = inspectState.config?.secondaryColor {
            return Color(hex: secondaryColor)
        }
        // Check if default color is still set (gray), if so use system secondary
        let defaultColor = inspectState.uiConfiguration.secondaryColor
        if defaultColor == "#A0A0A0" {
            return Color.secondary
        }
        return Color(hex: defaultColor)
    }

    // Dynamic colors for light/dark mode
    private var backgroundColor: Color {
        // Softer backgrounds for better visual comfort
        // Dark: ~#0D0D0D (very dark gray instead of pure black)
        // Light: ~#F2F2F2 (soft white)
        return colorScheme == .dark ? Color(white: 0.05) : Color(white: 0.95)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.15, green: 0.17, blue: 0.19) : .white
    }

    private var cardShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.15)
    }

    private var progressBarBackgroundColor: Color {
        colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.3)
    }

    private var dotInactiveColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.3)
    }

    // Calculate contrasting text color for button based on accent color luminance
    private func contrastingTextColor(for backgroundColor: Color) -> Color {
        // Extract RGB components from the background color
        let nsColor = NSColor(backgroundColor)

        // Convert to RGB color space (returns nil if conversion fails)
        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else {
            // Cannot convert to RGB, return white as safe default
            return .white
        }

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        // getRed modifies the values via inout parameters
        rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Calculate relative luminance using WCAG formula
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue

        // Return white for dark colors, black for light colors
        // Threshold at 0.5 provides good contrast
        return luminance > 0.5 ? .black : .white
    }

    init(inspectState: InspectState) {
        self.inspectState = inspectState
    }

    // Calculate total pages based on number of items
    private var totalPages: Int {
        guard !inspectState.items.isEmpty else { return 1 } // Minimum 1 page even with no items
        return (inspectState.items.count + cardsPerPage - 1) / cardsPerPage
    }

    // Get items for current page
    private var currentPageItems: [InspectConfig.ItemConfig] {
        // Handle empty items case
        guard !inspectState.items.isEmpty else {
            return []
        }

        // Ensure currentPage is valid
        let validPage = min(max(0, currentPage), max(0, totalPages - 1))
        let startIndex = validPage * cardsPerPage
        let endIndex = min(startIndex + cardsPerPage, inspectState.items.count)

        // Safety check to prevent range errors
        guard startIndex < inspectState.items.count else {
            return []
        }

        return Array(inspectState.items[startIndex..<endIndex])
    }

    // MARK: - Card Data Model

    fileprivate struct CardData: Identifiable {
        let id: String
        let item: InspectConfig.ItemConfig
        let globalIndex: Int
        let isCompleted: Bool
        let isFailed: Bool
        let isClickable: Bool
        var isActive: Bool {
            !isCompleted && !isFailed
        }
    }

    // Pre-compute card data to simplify ForEach and avoid type inference issues
    private var visibleCardData: [CardData] {
        currentPageItems.enumerated().map { index, item in
            let globalIndex = currentPage * cardsPerPage + index
            let isCompleted = completedSteps.contains(item.id) || inspectState.completedItems.contains(item.id)
            let isFailed = failedSteps.contains(item.id)
            let isObserveOnly = isItemObserveOnly(item)
            return CardData(
                id: item.id,
                item: item,
                globalIndex: globalIndex,
                isCompleted: isCompleted,
                isFailed: isFailed,
                isClickable: !isCompleted && !isFailed && !isObserveOnly
            )
        }
    }

    // MARK: - View Builders

    @ViewBuilder
    private var headerSection: some View {
        if inspectState.uiConfiguration.bannerImage != nil {
            ZStack {
                if let bannerNSImage = iconCache.bannerImage {
                    // Banner image spanning to absolute window top, ignoring safe area
                    Image(nsImage: bannerNSImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: windowSize.width, height: CGFloat(inspectState.uiConfiguration.bannerHeight))
                        .clipped()
                        .ignoresSafeArea(.all, edges: .top)  // Extend to absolute top

                    // Overlay content with better positioning
                    ZStack {
                        // Step indicator positioned absolutely in top-right
                        VStack {
                            HStack {
                                Spacer()
                                if inspectState.items.count > 1 {
                                    Text(getStepCounterText())
                                        .font(.system(size: 12 * scaleFactor, weight: .medium))
                                        .foregroundColor(primaryTextColor.opacity(0.9))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(.thinMaterial.opacity(0.6))
                                                .overlay(
                                                    Capsule()
                                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                                )
                                        )
                                        .scaleEffect(showResetFeedback ? 1.1 : 1.0)
                                        .opacity(showResetFeedback ? 0.7 : 1.0)
                                        .animation(.easeInOut(duration: 0.3), value: showResetFeedback)
                                        .onTapGesture {
                                            if NSEvent.modifierFlags.contains(.option) {
                                                handleManualReset()
                                            }
                                        }
                                        .help("Option-click to reset progress")
                                }
                            }
                            .padding(.top, 40)  // Account for window title bar
                            .padding(.trailing, 24)
                            
                            Spacer()
                        }
                        
                        // Banner title centered in the full banner height
                        if let bannerTitle = inspectState.uiConfiguration.bannerTitle {
                            Text(bannerTitle)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(primaryTextColor)
                                .shadow(color: cardShadowColor, radius: 3, x: 2, y: 2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)  // Add horizontal padding to prevent text from going under step indicator
                        }
                    }
                }
            }
            .frame(width: windowSize.width, height: CGFloat(inspectState.uiConfiguration.bannerHeight))
            .frame(maxWidth: .infinity)
            .ignoresSafeArea(.all, edges: .top)  // Ensure the container also ignores safe area
            .onAppear { iconCache.cacheBannerImage(for: inspectState) }
        } else {
            ZStack {
                // Step indicator in top-right when no banner
                VStack {
                    HStack {
                        Spacer()
                        if inspectState.items.count > 1 {
                            Text(getStepCounterText())
                                .font(.system(size: 12 * scaleFactor, weight: .medium))
                                .foregroundColor(primaryTextColor.opacity(0.9))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(.thinMaterial.opacity(0.6))
                                        .overlay(
                                            Capsule()
                                                .stroke(primaryTextColor.opacity(0.2), lineWidth: 1)
                                        )
                                )
                                .scaleEffect(showResetFeedback ? 1.1 : 1.0)
                                .opacity(showResetFeedback ? 0.7 : 1.0)
                                .animation(.easeInOut(duration: 0.3), value: showResetFeedback)
                                .onTapGesture {
                                    if NSEvent.modifierFlags.contains(.option) {
                                        handleManualReset()
                                    }
                                }
                                .help("Option-click to reset progress")
                        }
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 24)

                    Spacer()
                }

                // Icon/Logo centered at top (option-click to reset progress)
                // Smart sizing: respects iconSize config and adapts to aspect ratio
                GeometryReader { _ in
                    IconView(image: getMainIconPath(), defaultImage: "tray.fill", defaultColour: "accent")
                        .frame(maxWidth: getIconMaxWidth(), maxHeight: CGFloat(inspectState.uiConfiguration.iconSize) * scaleFactor)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16 * scaleFactor)
                        .padding(.bottom, 8 * scaleFactor)
                }
                .frame(height: CGFloat(inspectState.uiConfiguration.iconSize + 20) * scaleFactor)
            }
            .onAppear {
                iconCache.cacheMainIcon(for: inspectState)
                writeLog("Preset7: IconView appeared with path: '\(getMainIconPath())'", logLevel: .debug)
            }
        }
    }

    @ViewBuilder
    private var mainTitleSection: some View {
        VStack(spacing: 0) {
            // When banner has a title, show message here instead of repeating the title
            let hasBannerTitle = inspectState.uiConfiguration.bannerImage != nil &&
                                 inspectState.uiConfiguration.bannerTitle != nil

            if !hasBannerTitle {
                // No banner title - show main title
                Text(inspectState.uiConfiguration.windowTitle)
                    .font(.system(size: 32 * scaleFactor, weight: .bold))
                    .foregroundColor(primaryTextColor)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12 * scaleFactor)
                    .padding(.bottom, 4 * scaleFactor)
            }

            // Show message (when banner has title) or rotating side messages (when no banner title)
            if hasBannerTitle {
                // Banner has title - show the main message here
                if !inspectState.uiConfiguration.statusMessage.isEmpty {
                    Text(inspectState.uiConfiguration.statusMessage)
                        .font(.system(size: 17 * scaleFactor))
                        .foregroundColor(secondaryTextColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 40)
                        .padding(.top, 16 * scaleFactor)
                        .padding(.bottom, 12 * scaleFactor)
                }
            } else {
                // No banner title - show rotating side messages below title
                if let currentMessage = inspectState.getCurrentSideMessage() {
                    Text(currentMessage)
                        .font(.system(size: 15 * scaleFactor))
                        .foregroundColor(secondaryTextColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 40)
                        .padding(.top, 8 * scaleFactor)
                        .padding(.bottom, 12 * scaleFactor)
                        .transition(.opacity)
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func getMainIconPath() -> String {
        let path = iconCache.getMainIconPath(for: inspectState)
        writeLog("Preset7: Main icon path resolved to: '\(path)'", logLevel: .debug)
        return path
    }

    /// Calculate appropriate max width for icon/logo based on image aspect ratio
    /// Respects configured iconSize and scales appropriately for wide logos
    private func getIconMaxWidth() -> CGFloat {
        // Use configured iconSize as base (default 120, configurable via JSON)
        let baseSize = CGFloat(inspectState.uiConfiguration.iconSize) * scaleFactor
        let iconPath = getMainIconPath()

        // Skip aspect ratio check for SF Symbols or special keywords
        if iconPath.hasPrefix("sf=") || iconPath == "default" || iconPath == "none" {
            return baseSize
        }

        // Try to load the image to check its aspect ratio
        guard let image = NSImage(contentsOfFile: iconPath) else {
            // Can't load image, use configured size
            return baseSize
        }

        let imageSize = image.size
        guard imageSize.height > 0 else {
            return baseSize
        }

        let aspectRatio = imageSize.width / imageSize.height

        // Scale width based on aspect ratio, using baseSize as reference
        // This respects user's iconSize config while adapting to image shape
        if aspectRatio > 2.5 {
            // Very wide logo (e.g., 1000×300 = 3.33 ratio)
            return baseSize * 3.5
        } else if aspectRatio > 1.5 {
            // Wide logo (e.g., 16:9 = 1.78 ratio)
            return baseSize * 2.5
        } else if aspectRatio > 1.2 {
            // Slightly wide (e.g., 4:3 = 1.33 ratio)
            return baseSize * 1.5
        } else {
            // Square or portrait (1:1 or taller) - use configured size
            return baseSize
        }
    }

    private func handleManualReset() {
        writeLog("Preset7: Manual reset triggered via option-click", logLevel: .info)

        // Show visual feedback
        withAnimation {
            showResetFeedback = true
        }

        // Reset after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.resetSteps()

            // Clear feedback after reset
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation {
                    self.showResetFeedback = false
                }
            }
        }
    }

    // MARK: - Observe-Only Mode Helpers

    /// Check if global observe-only mode is enabled
    private var isGlobalObserveOnly: Bool {
        inspectState.config?.observeOnly ?? false
    }

    /// Check if a specific item has observe-only enabled (cascading logic)
    /// Priority: item.observeOnly → config.observeOnly → false (default interactive)
    private func isItemObserveOnly(_ item: InspectConfig.ItemConfig) -> Bool {
        item.observeOnly ?? inspectState.config?.observeOnly ?? false
    }

    /// Check if navigation should be disabled (observe-only mode)
    private var isNavigationDisabled: Bool {
        isGlobalObserveOnly
    }

    var body: some View {
        ZStack {
            // Dynamic background
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection
                mainTitleSection

                Spacer(minLength: 20)

                gridSection

                pageNavigationDots
                    .padding(.top, 16)

                // Fixed spacing region - prevents shifting when completion message appears
                VStack(spacing: 0) {
                    progressIndicatorSection
                        .frame(height: 58)  // Fixed height container for the message area
                }
                .padding(.top, 8)

                Spacer(minLength: 20)

                customButtonArea()
                    .padding(.horizontal, 40)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                globalProgressBar
            }
        }
        .frame(minHeight: windowSize.height)
        .onAppear(perform: handleViewAppear)
        .onChange(of: inspectState.items.count) { _, newCount in
            handleItemsCountChange(newCount)
        }
        .onChange(of: inspectState.completedItems) { oldValue, newValue in
            handleCompletedItemsChange(oldValue, newValue)
        }
        .onDisappear(perform: handleViewDisappear)
    }

    @ViewBuilder
    private var pageNavigationDots: some View {
        if totalPages > 1 {
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { pageIndex in
                    Circle()
                        .fill(pageIndex == currentPage ? getConfigurableHighlightColor() : dotInactiveColor)
                        .frame(width: 8, height: 8)
                        .onTapGesture {
                            if !isNavigationDisabled {
                                withAnimation(reduceMotion ? nil : .spring()) {
                                    currentPage = pageIndex
                                }
                            }
                        }
                        .onHover { hovering in
                            if hovering && !isNavigationDisabled {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                        .help(isNavigationDisabled ? "" : "Go to page \(pageIndex + 1)")
                        .accessibilityLabel("Page \(pageIndex + 1) of \(totalPages)")
                        .accessibilityAddTraits(pageIndex == currentPage ? [.isSelected] : [])
                        .accessibilityHint(isNavigationDisabled ? "Navigation disabled in observe-only mode" : (pageIndex != currentPage ? "Double tap to navigate to page \(pageIndex + 1)" : ""))
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    @ViewBuilder
    private var gridSection: some View {
        // Cards container - centered with generous spacing for better visual balance
        HStack(spacing: 32 * scaleFactor) {
            ForEach(visibleCardData) { cardData in
                cardView(for: cardData)
            }
        }
        .id("page_\(currentPage)")
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: currentPage)
        .padding(.horizontal, 40)
        // Keyboard navigation temporarily disabled
        // .onKeyPress(.leftArrow) {
        //     handleKeyboardNavigation(.left)
        //     return .handled
        // }
        // .onKeyPress(.rightArrow) {
        //     handleKeyboardNavigation(.right)
        //     return .handled
        // }
        // .onKeyPress(.tab) {
        //     handleKeyboardNavigation(.tab)
        //     return .handled
        // }
    }

    @ViewBuilder
    private func cardView(for cardData: CardData) -> some View {
        let baseCard = StepCard(
            step: cardData.globalIndex + 1,
            item: cardData.item,
            isCompleted: cardData.isCompleted,
            isFailed: cardData.isFailed,
            isActive: cardData.globalIndex == currentStep,
            isClickable: cardData.isClickable,
            iconCache: iconCache,
            iconBasePath: inspectState.uiConfiguration.iconBasePath,
            scaleFactor: scaleFactor,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            accentColor: getConfigurableHighlightColor(),
            colorScheme: colorScheme,
            inspectState: inspectState
        )

        cardInteractivity(baseCard, cardData: cardData)
    }

    @ViewBuilder
    private func cardInteractivity<V: View>(_ card: V, cardData: CardData) -> some View {
        card
            .onAppear {
                if cardData.globalIndex == currentStep {
                    writeLog("Preset7: Card \(cardData.globalIndex) (\(cardData.item.id)) is ACTIVE (currentStep=\(currentStep))", logLevel: .info)
                } else if completedSteps.contains(cardData.item.id) {
                    writeLog("Preset7: Card \(cardData.globalIndex) (\(cardData.item.id)) is COMPLETED", logLevel: .debug)
                }
            }
            .onTapGesture {
                if cardData.isClickable {
                    handleStepClick(item: cardData.item, index: cardData.globalIndex)
                }
            }
            .onHover { hovering in
                if hovering && cardData.isClickable {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .modifier(CardAccessibilityModifier(cardData: cardData))
            .modifier(CardFocusModifier(cardData: cardData, focusedCardIndex: $focusedCardIndex, accentColor: getConfigurableHighlightColor(), scaleFactor: scaleFactor, onAction: { handleStepClick(item: cardData.item, index: cardData.globalIndex) }))
    }

    @ViewBuilder
    private var globalProgressBar: some View {
        InspectBottomProgressBar(
            inspectState: inspectState,
            completedSteps: $completedSteps,
            currentStep: currentStep,
            scaleFactor: scaleFactor
        )
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var progressIndicatorSection: some View {
        let allComplete = inspectState.items.allSatisfy({ completedSteps.contains($0.id) })

        // Message area - container has fixed height to pervent shifting
        // Content centers should work within the available space
        ZStack {
            // Status message (shown when not complete)
            if !allComplete && !inspectState.uiConfiguration.statusMessage.isEmpty {
                Text(inspectState.uiConfiguration.statusMessage)
                    .font(.system(size: 14 * scaleFactor))
                    .foregroundColor(secondaryTextColor)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            // Completion celebration (shown when all complete)
            if allComplete {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 26 * scaleFactor, weight: .semibold))
                        .foregroundColor(.green)
                        .symbolEffect(.bounce, value: showSuccess)

                    Text(inspectState.config?.uiLabels?.completionMessage ?? "All Complete!")
                        .font(.system(size: 22 * scaleFactor, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .scaleEffect(showSuccess ? 1.0 : 0.9)
                .opacity(showSuccess ? 1.0 : 0.0)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // Fill container, center content
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7), value: allComplete)
    }

    // MARK: - Event Handlers

    private func handleViewAppear() {
        writeLog("Preset7: View appearing, loading state...", logLevel: .info)

        // Debug icon/banner configuration
        writeLog("Preset7: iconPath = '\(inspectState.uiConfiguration.iconPath ?? "nil")'", logLevel: .debug)
        writeLog("Preset7: iconBasePath = '\(inspectState.uiConfiguration.iconBasePath ?? "nil")'", logLevel: .debug)
        writeLog("Preset7: bannerImage = '\(inspectState.uiConfiguration.bannerImage ?? "nil")'", logLevel: .debug)

        iconCache.cacheItemIcons(for: inspectState)
        iconCache.cacheMainIcon(for: inspectState)
        iconCache.cacheBannerImage(for: inspectState)
        loadPersistedState()
        setupExternalMonitoring()

        // Debug button configuration
        writeLog("Preset7: Button1 text: '\(inspectState.buttonConfiguration.button1Text)'", logLevel: .debug)
        writeLog("Preset7: Button2 text: '\(inspectState.buttonConfiguration.button2Text)'", logLevel: .debug)
        writeLog("Preset7: Button2 visible: \(inspectState.buttonConfiguration.button2Visible)", logLevel: .debug)
    }

    private func handleItemsCountChange(_ count: Int) {
        if !completedSteps.isEmpty && !inspectState.items.isEmpty {
            if let firstIncompleteIndex = inspectState.items.firstIndex(where: { !completedSteps.contains($0.id) }) {
                if currentStep != firstIncompleteIndex {
                    let targetPage = firstIncompleteIndex / cardsPerPage

                    // Delay navigation to ensure view is fully ready
                    // IMPORTANT: Use cancellable work item to prevent race with external navigation
                    autoPageNavigationWorkItem?.cancel()
                    let workItem = DispatchWorkItem {
                        self.currentStep = firstIncompleteIndex
                        self.currentPage = targetPage
                        writeLog("Preset7: Items loaded, navigated to currentStep \(firstIncompleteIndex), page \(targetPage)", logLevel: .info)
                    }
                    autoPageNavigationWorkItem = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
                }
            }
        }
    }

    private func handleCompletedItemsChange(_ oldValue: Set<String>, _ newCompletedItems: Set<String>) {
        withAnimation(reduceMotion ? nil : .spring()) {
            for item in inspectState.items {
                if newCompletedItems.contains(item.id) && !completedSteps.contains(item.id) {
                    completedSteps.insert(item.id)
                    writeLog("Preset7: External completion detected for \(item.id)", logLevel: .debug)
                }
            }
            checkForPageCompletion()
            checkForCompletion()
        }
    }

    private func handleViewDisappear() {
        savePersistedState()
        externalMonitoringTimer?.invalidate()
        externalMonitoringTimer = nil
    }

    // MARK: - Navigation

    private func navigateLeft() {
        withAnimation(reduceMotion ? nil : .spring()) {
            currentPage = max(0, currentPage - 1)
        }
        writeInteractionLog("navigate", step: "page_\(currentPage)")
    }

    private func navigateRight() {
        withAnimation(reduceMotion ? nil : .spring()) {
            currentPage = min(totalPages - 1, currentPage + 1)
        }
        writeInteractionLog("navigate", step: "page_\(currentPage)")
    }

    private enum KeyboardNavDirection {
        case left, right, tab
    }

    private func handleKeyboardNavigation(_ direction: KeyboardNavDirection) {
        // Find all clickable (incomplete) cards
        let clickableCards = visibleCardData.filter { $0.isClickable }

        guard !clickableCards.isEmpty else { return }

        switch direction {
        case .left:
            if let focused = focusedCardIndex,
               let currentIndex = clickableCards.firstIndex(where: { $0.globalIndex == focused }),
               currentIndex > 0 {
                // Move focus to previous clickable card
                focusedCardIndex = clickableCards[currentIndex - 1].globalIndex
            } else if currentPage > 0 {
                // Navigate to previous page and focus last clickable card
                navigateLeft()
                // Focus will be set when page loads
            }

        case .right:
            if let focused = focusedCardIndex,
               let currentIndex = clickableCards.firstIndex(where: { $0.globalIndex == focused }),
               currentIndex < clickableCards.count - 1 {
                // Move focus to next clickable card
                focusedCardIndex = clickableCards[currentIndex + 1].globalIndex
            } else if currentPage < totalPages - 1 {
                // Navigate to next page and focus first clickable card
                navigateRight()
                // Focus will be set when page loads
            }

        case .tab:
            if let focused = focusedCardIndex,
               let currentIndex = clickableCards.firstIndex(where: { $0.globalIndex == focused }),
               currentIndex < clickableCards.count - 1 {
                // Tab to next clickable card
                focusedCardIndex = clickableCards[currentIndex + 1].globalIndex
            } else if !clickableCards.isEmpty {
                // Wrap to first clickable card
                focusedCardIndex = clickableCards[0].globalIndex
            }
        }
    }

    private func handleStepClick(item: InspectConfig.ItemConfig, index: Int) {
        guard !completedSteps.contains(item.id) else { return }

        withAnimation(reduceMotion ? nil : .spring()) {
            completedSteps.insert(item.id)
            inspectState.completedItems.insert(item.id)

            // Write interaction to stdout for script monitoring
            writeInteractionLog("clicked", step: item.id)

            // Advance current step pointer if this was the current step
            if index == currentStep && currentStep < inspectState.items.count - 1 {
                currentStep += 1
            }

            // Save state after each click
            savePersistedState()

            // Check if current page is complete and auto-advance
            checkForPageCompletion()

            // Check if all steps are complete
            checkForCompletion()
        }
    }

    private func checkForPageCompletion() {
        // Ensure currentPage is valid
        guard currentPage >= 0 && currentPage < totalPages else { return }

        // Get items on current page
        let startIndex = currentPage * cardsPerPage
        let endIndex = min(startIndex + cardsPerPage, inspectState.items.count)

        // Safety check
        guard startIndex < inspectState.items.count else { return }

        let currentPageItems = Array(inspectState.items[startIndex..<endIndex])

        // Check if all items on current page are completed
        let allPageItemsComplete = currentPageItems.allSatisfy { completedSteps.contains($0.id) }

        if allPageItemsComplete && currentPage < totalPages - 1 {
            // Find next page with incomplete items
            for nextPage in (currentPage + 1)..<totalPages {
                let nextStartIndex = nextPage * cardsPerPage
                let nextEndIndex = min(nextStartIndex + cardsPerPage, inspectState.items.count)
                let nextPageItems = Array(inspectState.items[nextStartIndex..<nextEndIndex])

                // Check if this page has any incomplete items
                if nextPageItems.contains(where: { !completedSteps.contains($0.id) }) {
                    // Auto-advance to this page with a slight delay
                    // IMPORTANT: Use cancellable work item to prevent race with external/manual navigation
                    autoPageNavigationWorkItem?.cancel()
                    let workItem = DispatchWorkItem {
                        withAnimation(self.reduceMotion ? nil : .spring()) {
                            self.currentPage = nextPage
                            self.writeInteractionLog("auto_navigate", step: "page_\(nextPage)")
                        }
                    }
                    autoPageNavigationWorkItem = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
                    break
                }
            }
        }
    }

    @ViewBuilder
    private func customButtonArea() -> some View {
        let allStepsComplete = inspectState.items.allSatisfy { completedSteps.contains($0.id) }
        let highlightColor = getConfigurableHighlightColor()

        HStack(spacing: 24) {
            // Left chevron navigation
            if totalPages > 1 {
                Button(action: {
                    if currentPage > 0 && !isNavigationDisabled {
                        navigateLeft()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20 * scaleFactor, weight: .bold))
                        .foregroundColor(currentPage > 0 && !isNavigationDisabled
                            ? highlightColor
                            : Color.gray.opacity(0.5))
                        .padding(12)
                        .background(
                            Circle()
                                .strokeBorder(currentPage > 0 && !isNavigationDisabled
                                    ? highlightColor
                                    : Color.gray.opacity(0.5), lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
                .disabled(currentPage == 0 || isNavigationDisabled)
                .help(isNavigationDisabled ? "Navigation disabled" : (currentPage > 0 ? "Previous page" : ""))
                .onHover { hovering in
                    if hovering && currentPage > 0 && !isNavigationDisabled {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }

            Spacer()

            // Button 2: Outlined style (matching mockup's "All features" button)
            if inspectState.buttonConfiguration.button2Visible && !inspectState.buttonConfiguration.button2Text.isEmpty {
                Button(action: {
                    writeLog("InspectView: User clicked button2 (\(inspectState.buttonConfiguration.button2Text)) - exiting with code 2", logLevel: .info)
                    exit(2)
                }) {
                    Text(inspectState.buttonConfiguration.button2Text)
                        .font(.system(size: 15 * scaleFactor, weight: .medium))
                        .foregroundColor(highlightColor)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(highlightColor, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
            }

            // Button 1: Filled green/teal style (matching mockup's "Get Started" button)
            Button(action: {
                let finalButtonText = inspectState.config?.finalButtonText ??
                                     inspectState.config?.button1Text ??
                                     (inspectState.buttonConfiguration.button1Text.isEmpty ? "Continue" : inspectState.buttonConfiguration.button1Text)
                handleFinalButtonPress(buttonText: finalButtonText)
            }) {
                let finalButtonText = inspectState.config?.finalButtonText ??
                                     inspectState.config?.button1Text ??
                                     (inspectState.buttonConfiguration.button1Text.isEmpty ? "Continue" : inspectState.buttonConfiguration.button1Text)
                HStack(spacing: 8) {
                    Text(finalButtonText)
                        .font(.system(size: 15 * scaleFactor, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13 * scaleFactor, weight: .semibold))
                }
                .foregroundColor(allStepsComplete ? contrastingTextColor(for: highlightColor) : primaryTextColor.opacity(0.5))
                .padding(.horizontal, 40)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(allStepsComplete ? highlightColor : Color.gray.opacity(0.3))
                        .shadow(color: allStepsComplete ? highlightColor.opacity(0.3) : Color.clear, radius: 8, y: 4)
                )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
            .disabled(!allStepsComplete)
            .opacity(allStepsComplete ? 1.0 : 0.6)
            .accessibilityHint(allStepsComplete ? "" : "Complete all steps to enable this button")

            Spacer()

            // Right chevron navigation
            if totalPages > 1 {
                Button(action: {
                    if currentPage < totalPages - 1 && !isNavigationDisabled {
                        navigateRight()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 20 * scaleFactor, weight: .bold))
                        .foregroundColor(currentPage < totalPages - 1 && !isNavigationDisabled
                            ? highlightColor
                            : Color.gray.opacity(0.5))
                        .padding(12)
                        .background(
                            Circle()
                                .strokeBorder(currentPage < totalPages - 1 && !isNavigationDisabled
                                    ? highlightColor
                                    : Color.gray.opacity(0.5), lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
                .disabled(currentPage >= totalPages - 1 || isNavigationDisabled)
                .help(isNavigationDisabled ? "Navigation disabled" : (currentPage < totalPages - 1 ? "Next page" : ""))
                .onHover { hovering in
                    if hovering && currentPage < totalPages - 1 && !isNavigationDisabled {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
    }

    private func writeInteractionLog(_ event: String, step: String) {
        // Write to stdout for external script monitoring
        print("[PRESET7_INTERACTION] event=\(event) step=\(step) current=\(currentStep) completed=\(completedSteps.count)")

        // Write to plist for reliable monitoring
        let plistPath = "/tmp/preset7_interaction.plist"
        let interaction: [String: Any] = [
            "timestamp": Date(),
            "event": event,
            "step": step,
            "currentStep": currentStep,
            "completedSteps": Array(completedSteps),
            "completedCount": completedSteps.count
        ]

        // Write plist atomically to avoid partial reads
        if let plistData = try? PropertyListSerialization.data(fromPropertyList: interaction,
                                                               format: .xml,
                                                               options: 0) {
            try? plistData.write(to: URL(fileURLWithPath: plistPath), options: .atomic)
        }

        // Also append to log file for history
        let logPath = "/tmp/preset7_interaction.log"
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = "\(timestamp) event=\(event) step=\(step) current=\(currentStep) completed=\(Array(completedSteps).joined(separator: ","))\n"

        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath) {
                if let fileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: logPath)) {
                    _ = try? fileHandle.seekToEnd()
                    _ = try? fileHandle.write(contentsOf: data)
                    try? fileHandle.close()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: logPath))
            }
        }
    }

    private func checkForCompletion() {
        // Check if ALL items are complete, not just visible ones
        let allComplete = inspectState.items.allSatisfy { completedSteps.contains($0.id) }

        if allComplete && !showSuccess {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.5).delay(0.3)) {
                showSuccess = true
            }
            writeInteractionLog("completed", step: "all_steps")
        }
    }

    private func resetSteps() {
        withAnimation(reduceMotion ? nil : .spring()) {
            completedSteps.removeAll()
            currentStep = 0
            currentPage = 0  // Reset to first page
            inspectState.completedItems.removeAll()
            showSuccess = false
        }

        // Clear the persisted state
        persistence.clearState()

        // Clear ALL interaction logs and status files
        let filesToClear = [
            "/tmp/preset7_interaction.plist",
            "/tmp/preset7_interaction.log",
            "/tmp/preset7_trigger.txt"
        ]

        for filePath in filesToClear {
            do {
                if FileManager.default.fileExists(atPath: filePath) {
                    try FileManager.default.removeItem(atPath: filePath)
                    writeLog("Preset7: Cleared file: \(filePath)", logLevel: .debug)
                }
            } catch {
                writeLog("Preset7: Failed to clear \(filePath): \(error)", logLevel: .error)
            }
        }

        // Write reset log AFTER clearing (so it's a fresh start)
        writeInteractionLog("reset", step: "all")
    }


    private func setupExternalMonitoring() {
        // Check for external triggers periodically
        externalMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.checkForExternalTrigger()
            }
        }
    }

    private func checkForExternalTrigger() {
        // Early exit if view state is invalid (prevents crashes during teardown)
        guard !inspectState.items.isEmpty else {
            return
        }

        let triggerPath = "/tmp/preset7_trigger.txt"

        guard FileManager.default.fileExists(atPath: triggerPath) else {
            return
        }

        // Read content before removing
        guard let content = try? String(contentsOfFile: triggerPath, encoding: .utf8) else {
            return
        }

        // Debug log
        if appvars.debugMode {
            writeLog("Preset7: Found trigger file with content: \(content)", logLevel: .debug)
        }
        print("[PRESET7_TRIGGER] Processing: \(content.replacingOccurrences(of: "\n", with: " "))")

        // Remove trigger file after successful read
        try? FileManager.default.removeItem(atPath: triggerPath)

        let lines = content.split(separator: "\n")
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedLine.hasPrefix("complete:") {
                let stepId = String(trimmedLine.dropFirst(9))
                print("[PRESET7_TRIGGER] Attempting to complete step: \(stepId)")

                // Try to match against actual step IDs
                if !completedSteps.contains(stepId) {
                    if inspectState.items.contains(where: { $0.id == stepId }) {
                        withAnimation(reduceMotion ? nil : .spring()) {
                            completedSteps.insert(stepId)
                            inspectState.completedItems.insert(stepId)
                            writeInteractionLog("auto_completed", step: stepId)
                            checkForCompletion()
                        }
                        print("[PRESET7_TRIGGER] Step \(stepId) marked complete")
                    } else {
                        print("[PRESET7_TRIGGER] Step \(stepId) not found in items")
                    }
                } else {
                    print("[PRESET7_TRIGGER] Step \(stepId) already completed")
                }
            } else if trimmedLine == "reset" {
                print("[PRESET7_TRIGGER] Resetting steps")
                resetSteps()
            } else if trimmedLine == "success" {
                print("[PRESET7_TRIGGER] Success command received (deprecated - checkmarks indicate completion)")
                writeInteractionLog("external_success", step: "triggered")
            }
        }
    }

    // MARK: - State Persistence

    private func savePersistedState() {
        let state = Preset7State(
            completedSteps: completedSteps,
            currentPage: currentPage,
            currentStep: currentStep,
            timestamp: Date()
        )
        persistence.saveState(state)
        writeLog("Preset7: State saved - \(completedSteps.count) steps completed", logLevel: .debug)
    }

    private func navigateToFirstOpenTask() {
        // Find first incomplete task
        let firstOpenTaskIndex = inspectState.items.firstIndex { !completedSteps.contains($0.id) }

        guard let taskIndex = firstOpenTaskIndex else {
            // All tasks completed, no navigation needed
            writeLog("Preset7: All tasks completed, no navigation needed", logLevel: .debug)
            return
        }

        // Calculate which page contains this task using actual cardsPerPage
        let targetPage = taskIndex / cardsPerPage

        // Update currentStep and page immediately
        writeLog("Preset7: Setting currentStep from \(currentStep) to \(taskIndex) (first incomplete task)", logLevel: .debug)

        // Set currentStep directly
        currentStep = taskIndex

        // Navigate if we're not already on the correct page
        if targetPage != currentPage {
            writeLog("Preset7: Navigating to first open task on page \(targetPage)", logLevel: .info)
            currentPage = targetPage
            writeInteractionLog("auto_navigate", step: "first_open_task_page_\(targetPage)")
        }

        writeLog("Preset7: currentStep is now \(currentStep), currentPage is \(currentPage)", logLevel: .debug)
    }

    private func loadPersistedState() {
        // Log where we're loading state from
        if let persistPath = persistence.persistenceFilePath {
            writeLog("Preset7: State file path: \(persistPath)", logLevel: .info)
        }

        guard let state = persistence.loadState() else {
            writeLog("Preset7: No previous state found", logLevel: .debug)
            // No saved state - this is a fresh launch
            // Set currentStep to first item (0)
            currentStep = 0
            writeInteractionLog("launched", step: "preset7")
            return
        }

        // Check if state is stale (older than 24 hours)
        if persistence.isStateStale(state, hours: 24) {
            writeLog("Preset7: State is stale, starting fresh", logLevel: .info)
            currentStep = 0
            writeInteractionLog("launched", step: "preset7")
            return
        }

        writeLog("Preset7: Loaded state - completed: \(state.completedSteps), saved page: \(state.currentPage), saved step: \(state.currentStep)", logLevel: .info)

        // Apply the validated state
        completedSteps = state.completedSteps
        inspectState.completedItems = completedSteps

        // Don't use the saved currentStep - calculate it fresh based on completed items
        // But only if items are loaded
        if !inspectState.items.isEmpty {
            // Find the first incomplete task
            if let firstIncompleteIndex = inspectState.items.firstIndex(where: { !completedSteps.contains($0.id) }),
               firstIncompleteIndex < inspectState.items.count {
                // Calculate the page for this step using actual cardsPerPage
                let targetPage = firstIncompleteIndex / cardsPerPage
                let firstIncompleteItem = inspectState.items[firstIncompleteIndex]

                writeLog("Preset7: Will navigate to currentStep=\(firstIncompleteIndex) (first incomplete: \(firstIncompleteItem.id)), page=\(targetPage)", logLevel: .info)

                // Delay the navigation to ensure view is fully ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.currentStep = firstIncompleteIndex
                    self.currentPage = targetPage
                    writeLog("Preset7: Navigated to page \(targetPage), step \(firstIncompleteIndex)", logLevel: .info)
                }
            } else {
                // All steps are completed - set to last item
                currentStep = inspectState.items.count - 1
                let lastPage = (inspectState.items.count - 1) / cardsPerPage
                currentPage = lastPage

                writeLog("Preset7: All steps completed, set to last item: \(currentStep), page: \(lastPage)", logLevel: .info)
            }
        } else {
            // Items haven't loaded yet, keep currentStep from saved state
            currentStep = state.currentStep
            writeLog("Preset7: Items not loaded yet, using saved currentStep: \(currentStep), page: \(currentPage)", logLevel: .info)
        }

        // Log the restoration
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        writeLog("Preset7: Resumed from \(formatter.string(from: state.timestamp)) - \(completedSteps.count) steps complete", logLevel: .info)

        // Calculate the actual current step before writing to plist
        writeLog("Preset7: Items count when calculating actualCurrentStep: \(inspectState.items.count)", logLevel: .info)
        let actualCurrentStep: Int
        if inspectState.items.isEmpty {
            // Items haven't been loaded yet, use the value we set earlier
            actualCurrentStep = currentStep
            writeLog("Preset7: Items empty, using currentStep: \(currentStep)", logLevel: .info)
        } else if let firstIncompleteIndex = inspectState.items.firstIndex(where: { !completedSteps.contains($0.id) }) {
            actualCurrentStep = firstIncompleteIndex
            writeLog("Preset7: Found first incomplete at index: \(actualCurrentStep)", logLevel: .info)
        } else {
            actualCurrentStep = inspectState.items.count - 1
            writeLog("Preset7: All complete, using last index: \(actualCurrentStep)", logLevel: .info)
        }

        // Write to interaction log that we resumed
        let completedList = completedSteps.joined(separator: ",")
        writeInteractionLog("resumed", step: "state_loaded")

        // Write additional debug info to plist with correct currentStep
        let interactionPath = "/tmp/preset7_interaction.plist"
        let interactionData: [String: Any] = [
            "event": "resumed",
            "step": "state_loaded",
            "currentStep": actualCurrentStep,
            "completedSteps": Array(completedSteps),
            "completedCount": completedSteps.count,
            "timestamp": Date()
        ]
        if let plistData = try? PropertyListSerialization.data(fromPropertyList: interactionData, format: .xml, options: 0) {
            try? plistData.write(to: URL(fileURLWithPath: interactionPath))
        }

        // Log the launched state with correct currentStep
        writeInteractionLog("launched", step: "preset7")

        // Also update the log file with correct currentStep
        let logEntry = "\(ISO8601DateFormatter().string(from: Date())) event=launched step=preset7 current=\(actualCurrentStep) completed=\(completedList)\n"
        if let logData = logEntry.data(using: .utf8) {
            let logPath = "/tmp/preset7_interaction.log"
            if let fileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: logPath)) {
                _ = try? fileHandle.seekToEnd()
                _ = try? fileHandle.write(contentsOf: logData)
                try? fileHandle.close()
            } else {
                try? logData.write(to: URL(fileURLWithPath: logPath))
            }
        }

        // Explicitly check for completion after state is loaded
        // This ensures showSuccess is set if all steps were already completed
        // IMPORTANT: Use cancellable work item for consistency (though less critical than navigation timers)
        autoPageNavigationWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            self.checkForCompletion()
            writeLog("Preset7: Checked for completion after state load", logLevel: .debug)
        }
        autoPageNavigationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func getStepCounterText() -> String {
        let format = inspectState.config?.uiLabels?.stepCounterFormat ?? "Step {current} of {total}"
        return format
            .replacingOccurrences(of: "{current}", with: "\(currentStep + 1)")
            .replacingOccurrences(of: "{total}", with: "\(inspectState.items.count)")
    }

    /// Handle final button press with safe callback mechanisms
    /// Writes trigger file, updates plist, logs event, then exits
    private func handleFinalButtonPress(buttonText: String) {
        writeLog("Preset7: User clicked final button (\(buttonText))", logLevel: .info)

        // 1. Write to interaction log for script monitoring
        let logPath = "/tmp/preset7_interaction.log"
        let logEntry = "final_button:clicked:\(buttonText)\n"
        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath) {
                if let fileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: logPath)) {
                    _ = try? fileHandle.seekToEnd()
                    _ = try? fileHandle.write(contentsOf: data)
                    try? fileHandle.close()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: logPath))
            }
        }

        // 2. Create trigger file (touch equivalent)
        let triggerPath = "/tmp/preset7_final_button.trigger"
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let triggerContent = "button_text=\(buttonText)\ntimestamp=\(timestamp)\nstatus=completed\n"
        if let data = triggerContent.data(using: .utf8) {
            try? data.write(to: URL(fileURLWithPath: triggerPath), options: .atomic)
            writeLog("Preset7: Created trigger file at \(triggerPath)", logLevel: .debug)
        }

        // 3. Write to plist for structured data access
        let plistPath = "/tmp/preset7_interaction.plist"
        let plistData: [String: Any] = [
            "finalButtonPressed": true,
            "buttonText": buttonText,
            "timestamp": timestamp,
            "completedSteps": Array(completedSteps),
            "failedSteps": Array(failedSteps),
            "currentStep": currentStep,
            "preset": "preset7"
        ]
        if let data = try? PropertyListSerialization.data(fromPropertyList: plistData, format: .xml, options: 0) {
            try? data.write(to: URL(fileURLWithPath: plistPath), options: .atomic)
            writeLog("Preset7: Updated interaction plist at \(plistPath)", logLevel: .debug)
        }

        // 4. Small delay to ensure file operations complete
        usleep(100000) // 100ms

        // 5. Exit with success code
        writeLog("Preset7: Exiting with code 0", logLevel: .info)
        exit(0)
    }
}

// MARK: - Card ViewModifiers

private struct CardAccessibilityModifier: ViewModifier {
    let cardData: Preset7View.CardData

    func body(content: Content) -> some View {
        content
            // Temporarily disable accessibility to avoid double outlines
            .accessibilityHidden(true)
    }
}

private struct CardFocusModifier: ViewModifier {
    let cardData: Preset7View.CardData
    let focusedCardIndex: FocusState<Int?>.Binding
    let accentColor: Color
    let scaleFactor: CGFloat
    let onAction: () -> Void

    func body(content: Content) -> some View {
        content
            // Disable focusable to avoid system focus ring
            // .focusable(cardData.isClickable)
            // .focused(focusedCardIndex, equals: cardData.globalIndex)
            .overlay(
                RoundedRectangle(cornerRadius: 16 * scaleFactor)
                    .strokeBorder(accentColor, lineWidth: 3)
                    .opacity(focusedCardIndex.wrappedValue == cardData.globalIndex ? 1.0 : 0.0)
            )
            .onKeyPress(.return) {
                if cardData.isClickable && focusedCardIndex.wrappedValue == cardData.globalIndex {
                    onAction()
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.space) {
                if cardData.isClickable && focusedCardIndex.wrappedValue == cardData.globalIndex {
                    onAction()
                    return .handled
                }
                return .ignored
            }
    }
}

struct StepCard: View {
    let step: Int
    let item: InspectConfig.ItemConfig
    let isCompleted: Bool
    let isFailed: Bool
    let isActive: Bool
    let isClickable: Bool
    let iconCache: PresetIconCache
    let iconBasePath: String?
    let scaleFactor: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let accentColor: Color
    let colorScheme: ColorScheme
    @ObservedObject var inspectState: InspectState

    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var showGuidancePopover = false
    @State private var isHovered = false

    // Dynamic colors based on color scheme
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.15, green: 0.17, blue: 0.19) : .white
    }

    private var cardShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.15)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }

    var body: some View {
        ZStack {
            // Main card background - dark gray with rounded corners
            RoundedRectangle(cornerRadius: 16 * scaleFactor)
                .fill(cardBackgroundColor)
                // Subtle shadow for depth - slightly more prominent on hover
                .shadow(
                    color: cardShadowColor,
                    radius: isHovered && isClickable ? 10 * scaleFactor : 8 * scaleFactor,
                    x: 0,
                    y: isHovered && isClickable ? 4 * scaleFactor : 3 * scaleFactor
                )
                // Very subtle accent glow on clickable cards (only on hover, minimal)
                .shadow(
                    color: isClickable && isHovered ? accentColor.opacity(0.08) : Color.clear,
                    radius: 12 * scaleFactor,
                    x: 0,
                    y: 2 * scaleFactor
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16 * scaleFactor)
                        .strokeBorder(borderColor, lineWidth: isHovered && isClickable ? 2 : 1.5)
                )

            // Content area directly (no progress bar on cards)
            VStack(spacing: 12 * scaleFactor) {
                // Icon at top
                ZStack {
                    if let categoryIcon = item.categoryIcon {
                        // Use categoryIcon as main icon (matching mockup style)
                        if let resolvedPath = iconCache.resolveImagePath(categoryIcon, basePath: iconBasePath) {
                            IconView(
                                image: resolvedPath,
                                defaultImage: getPlaceholderIcon(),
                                defaultColour: iconColor
                            )
                            .frame(width: 64 * scaleFactor, height: 64 * scaleFactor)
                        }
                    } else if let iconPath = item.icon {
                        // Fallback to item icon
                        if let resolvedPath = iconCache.resolveImagePath(iconPath, basePath: iconBasePath) {
                            IconView(
                                image: resolvedPath,
                                defaultImage: getPlaceholderIcon(),
                                defaultColour: iconColor
                            )
                            .frame(width: 64 * scaleFactor, height: 64 * scaleFactor)
                        }
                    } else {
                        // SF Symbol fallback
                        Image(systemName: getPlaceholderIcon())
                            .font(.system(size: 48 * scaleFactor))
                            .foregroundColor(iconTintColor)
                    }

                    // Completion indicator (top-right corner of icon)
                    if isCompleted {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20 * scaleFactor))
                                    .foregroundColor(.green)
                                    .background(Circle().fill(cardBackgroundColor).padding(-2))
                            }
                            Spacer()
                        }
                        .frame(width: 64 * scaleFactor, height: 64 * scaleFactor)
                    }
                }
                .padding(.top, 24 * scaleFactor)

                // Title
                Text(item.displayName)
                    .font(.system(size: 16 * scaleFactor, weight: .semibold))
                    .foregroundColor(primaryTextColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Description (subtitle)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 13 * scaleFactor))
                        .foregroundColor(secondaryTextColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                // More info link (minimal, always shown if guidance available)
                if hasGuidanceContent(item) {
                    Button(action: { showGuidancePopover.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12 * scaleFactor))
                            Text("More info")
                                .font(.system(size: 13 * scaleFactor))
                        }
                        .foregroundColor(accentColor.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8 * scaleFactor)
                }
            }
            .padding(.horizontal, 20 * scaleFactor)
            .padding(.top, 24 * scaleFactor)
            .padding(.bottom, 16 * scaleFactor)
        }
        .frame(width: cardWidth * scaleFactor, height: cardHeight * scaleFactor)
        .scaleEffect(isHovered && isClickable ? 1.05 : 1.0)
        .brightness(isHovered && isClickable ? 0.05 : 0)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .saturation(isCompleted ? 0.90 : 1.0)  // Subtle saturation reduction when completed
        .opacity(isCompleted ? 0.85 : 1.0)  // Keep completed cards mostly visible
        .onHover { hovering in
            isHovered = hovering
        }
        .popover(isPresented: $showGuidancePopover) {
            if hasGuidanceContent(item), let guidanceContent = item.guidanceContent {
                VStack(alignment: .leading, spacing: 12) {
                    if let title = item.guidanceTitle {
                        Text(title)
                            .font(.system(size: 16 * scaleFactor, weight: .semibold))
                            .padding(.bottom, 4)
                    }

                    ScrollView {
                        GuidanceContentView(
                            contentBlocks: guidanceContent,
                            scaleFactor: scaleFactor,
                            iconBasePath: iconBasePath,
                            inspectState: inspectState,
                            itemId: item.id
                        )
                    }
                }
                .padding()
                .frame(minWidth: 300, maxWidth: 500, maxHeight: 400)
            } else {
                Text("No guidance available")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }

    private var borderColor: Color {
        if isFailed {
            return .orange
        } else if isCompleted {
            // Light mode needs visible border for completed cards
            return colorScheme == .light ? getSecondaryColor().opacity(0.2) : .clear
        } else if isClickable {
            // Clickable cards get accent border (brighter if active)
            return isActive
                ? accentColor
                : accentColor.opacity(0.6)
        } else {
            // Light mode needs visible border for inactive cards
            return colorScheme == .light ? getSecondaryColor().opacity(0.2) : .clear
        }
    }

    /// Gets configurable secondary color - helper for StepCard
    private func getSecondaryColor() -> Color {
        if let secondaryColor = inspectState.config?.secondaryColor {
            return Color(hex: secondaryColor)
        }
        let defaultColor = inspectState.uiConfiguration.secondaryColor
        return defaultColor == "#A0A0A0" ? Color.secondary : Color(hex: defaultColor)
    }

    private var iconColor: String {
        if isCompleted {
            return "green"
        } else if isFailed {
            return "orange"
        } else if isActive {
            return "blue"
        } else {
            return "accent"
        }
    }

    private var iconTintColor: Color {
        // Dynamic accent tint for icons
        if isCompleted {
            return .green
        } else if isFailed {
            return .orange
        } else {
            return accentColor
        }
    }

    private func getPlaceholderIcon() -> String {
        // Return appropriate SF Symbol based on step
        switch step {
        case 1: return "app.badge"
        case 2: return "gearshape"
        case 3: return "arrow.clockwise"
        case 4: return "terminal"
        case 5: return "cart"
        case 6: return "accessibility"
        default: return "app.dashed"
        }
    }
}



struct LinkButtonStyle: ButtonStyle {
    let accentColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14))
            .foregroundColor(accentColor)
            .underline()
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}
