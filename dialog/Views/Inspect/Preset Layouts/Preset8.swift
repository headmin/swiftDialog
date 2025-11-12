//
//  Preset8Fixed.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 10/10/2025
//
//  Preset8: Minimal Onboarding Flow
//  Clean layout with large images, progress dots, and simple navigation
//

import SwiftUI

struct Preset8State: Codable {
    let currentPage: Int
    let completedPages: Set<Int>
    let timestamp: Date
}

// Validation result for caching to prevent flickering
private struct Preset8ValidationResult {
    let isValid: Bool
    let isInstalled: Bool
    let timestamp: Date
    let source: Preset8ValidationSource
}

private enum Preset8ValidationSource {
    case fileSystem
    case plist
    case emptyPaths
}

struct Preset8View: View, InspectLayoutProtocol {
    @ObservedObject var inspectState: InspectState
    @State private var currentPage: Int = 0
    @State private var completedPages: Set<Int> = []
    @StateObject private var iconCache = PresetIconCache()
    @State private var showSuccess: Bool = false
    @State private var showResetFeedback: Bool = false
    @State private var monitoringTimer: Timer?
    @State private var validationCache: [String: Preset8ValidationResult] = [:]
    @State private var lastValidationTime: [String: Date] = [:]
    
    // Add persistence manager
    private var persistence: Preset8StatePersistence {
        Preset8StatePersistence()
    }

    init(inspectState: InspectState) {
        self.inspectState = inspectState
        writeLog("Initializing - Items count: \(inspectState.items.count)")
    }

    // Calculate total pages based on number of items
    private var totalPages: Int {
        return max(1, inspectState.items.count)
    }

    // Get current page item
    private var currentPageItem: InspectConfig.ItemConfig? {
        guard currentPage < inspectState.items.count else { return nil }
        return inspectState.items[currentPage]
    }

    // Check if we're on the last page
    private var isLastPage: Bool {
        return currentPage >= totalPages - 1
    }

    // Check if all pages are complete
    private var allPagesComplete: Bool {
        return completedPages.count == totalPages
    }

    // MARK: - Picker Mode Helpers

    /// Check if picker mode is enabled
    private var isPickerMode: Bool {
        guard let selectionMode = inspectState.config?.pickerConfig?.selectionMode else {
            return false
        }
        return selectionMode == "single" || selectionMode == "multi"
    }

    /// Check if an item is currently selected
    private func isItemSelected(_ item: InspectConfig.ItemConfig) -> Bool {
        guard isPickerMode,
              let formState = inspectState.guidanceFormInputs["preset8_selections"] else {
            return false
        }

        let selectionMode = inspectState.config?.pickerConfig?.selectionMode ?? "none"

        if selectionMode == "single" {
            return formState.radios["selected_item"] == item.id
        } else if selectionMode == "multi" {
            return formState.checkboxes[item.id] == true
        }

        return false
    }

    /// Get count of selected items (for multi-select)
    private var selectedCount: Int {
        guard let formState = inspectState.guidanceFormInputs["preset8_selections"] else {
            return 0
        }

        let selectionMode = inspectState.config?.pickerConfig?.selectionMode ?? "none"

        if selectionMode == "multi" {
            return formState.checkboxes.values.filter { $0 }.count
        } else if selectionMode == "single" {
            return formState.radios["selected_item"] != nil ? 1 : 0
        }

        return 0
    }

    var body: some View {
        let _ = print("Rendering Preset8Fixed - currentPage: \(currentPage), totalPages: \(totalPages)")
        let _ = print("   - Button1 disabled: \(inspectState.buttonConfiguration.button1Disabled)")
        
        return ZStack {
            // Configurable background
            getConfigurableBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Full-width image section with overlay controls
                ZStack(alignment: .topLeading) {
                    // Main content image - spans full width
                    fullSpanImageArea()
                    
                    // Overlay navigation controls
                    VStack {
                        // Instruction banner (top overlay)
                        if let bannerConfig = inspectState.config?.instructionBanner,
                           let bannerText = bannerConfig.text {
                            InstructionBanner(
                                text: bannerText,
                                autoDismiss: bannerConfig.autoDismiss ?? true,
                                dismissDelay: bannerConfig.dismissDelay ?? 5.0,
                                icon: bannerConfig.icon
                            )
                        }

                        HStack {
                            // Back button overlay
                            if currentPage > 0 {
                                Button(action: navigateBack) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.black.opacity(0.3))
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Spacer()
                            
                            // Page counter overlay
                            let pageCounterText: String = {
                                if let format = inspectState.config?.pickerLabels?.pageCounterFormat {
                                    return format
                                        .replacingOccurrences(of: "{current}", with: "\(currentPage + 1)")
                                        .replacingOccurrences(of: "{total}", with: "\(totalPages)")
                                } else {
                                    return "\(currentPage + 1) of \(totalPages)"
                                }
                            }()

                            Text(pageCounterText)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .monospacedDigit()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.3))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
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
                        .padding(.horizontal, 30)
                        .padding(.top, 30)
                        
                        Spacer()
                        
                        // Overlay controls at the bottom of the image
                        HStack {
                            // Category bubble overlay (bottom-left of image)
                            if let item = currentPageItem, let categoryIcon = item.categoryIcon {
                                CategoryIconBubble(
                                    iconName: categoryIcon,
                                    iconBasePath: inspectState.uiConfiguration.iconBasePath,
                                    iconCache: iconCache,
                                    scaleFactor: 1.0
                                )
                                .padding(.leading, 30)
                                .padding(.bottom, 40) // Lower on the crossing line
                            } else {
                                // Placeholder space to maintain layout
                                Color.clear
                                    .frame(width: 36, height: 36)
                                    .padding(.leading, 30)
                                    .padding(.bottom, 40)
                            }

                            Spacer()

                            // Status indicator overlay (bottom-right of image)
                            // Hidden when hideSystemDetails is true
                            if inspectState.config?.hideSystemDetails != true {
                                overlayStatusIndicator()
                                    .padding(.trailing, 30)
                                    .padding(.bottom, 40) // Lower on the crossing line
                            }
                        }
                    }
                }
                .frame(height: windowSize.height * 0.6) // Take up 60% of the screen height

                // Bottom content section
                VStack(spacing: 28) {
                    // Simple progress dots
                    minimalProgressDots()
                        .padding(.top, 28)
                    
                    // Clean description text
                    minimalDescriptionText()
                    
                    Spacer()
                    
                    // Bottom continue button
                    minimalBottomButton()
                        .padding(.horizontal, 48)
                        .padding(.bottom, 48)
                }
            }
        }
        .frame(minWidth: windowSize.width, minHeight: windowSize.height)
        .onAppear(perform: handleViewAppear)
        .onDisappear(perform: handleViewDisappear)
    }

    // MARK: - Minimal View Components

    @ViewBuilder
    private func fullSpanImageArea() -> some View {
        GeometryReader { geometry in
            ZStack {
                // Base content layer
                if let item = currentPageItem {
                    // Display the full-span image
                    if let iconPath = item.icon {
                        // Handle SF Symbol icons
                        if iconPath.lowercased().hasPrefix("sf=") {
                            // For SF Symbols, create a nice background with the symbol
                            ZStack {
                                // Gradient background for SF Symbols - use config colors if available
                                createConfigurableGradient()

                                // Large SF Symbol
                                sfSymbolView(from: iconPath)
                                    .scaleEffect(0.8)
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                        } else {
                            // Handle image files - full span
                            AsyncImageView(
                                iconPath: iconPath,
                                basePath: inspectState.uiConfiguration.iconBasePath,
                                maxWidth: geometry.size.width,
                                maxHeight: geometry.size.height,
                                fallback: {
                                    fullSpanPlaceholderContent(
                                        for: item,
                                        width: geometry.size.width,
                                        height: geometry.size.height
                                    )
                                }
                            )
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                        }
                    } else {
                        // Enhanced placeholder for full span
                        fullSpanPlaceholderContent(
                            for: item,
                            width: geometry.size.width,
                            height: geometry.size.height
                        )
                    }
                } else {
                    // Default welcome content - full span with configurable gradient
                    ZStack {
                        createConfigurableGradient()

                        VStack(spacing: 30) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 120, weight: .thin))
                                .foregroundColor(getConfigurableTextColor())

                            Text("Welcome")
                                .font(.system(size: 48, weight: .thin))
                                .foregroundColor(getConfigurableTextColor())
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }

                // Selection button overlay (picker mode only)
                if let item = currentPageItem, isPickerMode {
                    let isSelected = isItemSelected(item)
                    let labels = inspectState.config?.pickerLabels
                    let selectionMode = inspectState.config?.pickerConfig?.selectionMode ?? "none"

                    VStack {
                        Spacer()

                        // Floating selection button at bottom-center
                        Button(action: {
                            handleItemSelection(item)
                        }) {
                            HStack(spacing: 8) {
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                }

                                // Button text: in single-select mode, show deselect option when selected
                                let buttonText: String = {
                                    if isSelected {
                                        if selectionMode == "single" {
                                            return labels?.deselectButtonText ?? "Tap to Deselect"
                                        } else {
                                            return labels?.selectedButtonText ?? "✓ Selected"
                                        }
                                    } else {
                                        return labels?.selectButtonText ?? "Select This"
                                    }
                                }()

                                Text(buttonText)
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.green : Color.blue)
                                    .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 6)
                            )
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(isSelected ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func fullSpanPlaceholderContent(for item: InspectConfig.ItemConfig, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Configurable gradient background
            createConfigurableGradient()
            
            // Subtle pattern overlay
            ZStack {
                // Large background icon
                Image(systemName: getMinimalIcon(for: currentPage))
                    .font(.system(size: min(width, height) * 0.3, weight: .ultraLight))
                    .foregroundColor(getConfigurableTextColor().opacity(0.1))
                    .offset(x: width * 0.2, y: -height * 0.1)
                
                // Content
                VStack(spacing: 24) {
                    Image(systemName: getMinimalIcon(for: currentPage))
                        .font(.system(size: 80, weight: .light))
                        .foregroundColor(getConfigurableTextColor())
                    
                    Text("Step \(currentPage + 1)")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(getConfigurableTextColor())
                }
            }
        }
        .frame(width: width, height: height)
    }

    @ViewBuilder
    private func overlayStatusIndicator() -> some View {
        HStack(spacing: 10) {
            // Status icon
            Image(systemName: getStatusIcon())
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            // Status text
            Text(getStatusText())
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)

            // Subtle step type badge (if specified)
            if let item = currentPageItem, let stepType = item.stepType {
                StepTypeIndicator(
                    stepType: stepType,
                    scaleFactor: 0.8,
                    style: .badge
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(getStatusColor().opacity(0.95))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 4)
        .scaleEffect(0.9)
        .animation(.easeInOut(duration: 0.3), value: completedPages)
        .animation(.easeInOut(duration: 0.3), value: currentPage)
    }



    @ViewBuilder
    private func minimalPlaceholderContent(for item: InspectConfig.ItemConfig) -> some View {
        VStack(spacing: 24) {
            // Simple, elegant placeholder
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 400, height: 280)
                .overlay(
                    VStack(spacing: 20) {
                        Image(systemName: getMinimalIcon(for: currentPage))
                            .font(.system(size: 60, weight: .ultraLight))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("Step \(currentPage + 1)")
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(.white.opacity(0.8))
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
    }


    
    // Helper functions for status overlay
    private func getStatusIcon() -> String {
        guard let item = currentPageItem else {
            return "circle.dotted"
        }
        
        // Check validation results and completion status
        if inspectState.completedItems.contains(item.id) {
            return "checkmark.circle.fill"
        } else if let isValid = inspectState.plistValidationResults[item.id] {
            if isValid {
                return "checkmark.circle.fill"
            } else {
                return "exclamationmark.triangle.fill" // Warning for failed validation
            }
        } else if currentPage == 0 && completedPages.isEmpty {
            return "play.circle"
        } else {
            return "circle.dotted"
        }
    }
    
    private func getStatusColor() -> Color {
        guard let item = currentPageItem else {
            return getConfigurableAccentColor()
        }
        
        // Check validation results and completion status
        if inspectState.completedItems.contains(item.id) {
            // Use configured color thresholds for completion
            return inspectState.colorThresholds.getColor(for: 1.0)
        } else if let isValid = inspectState.plistValidationResults[item.id] {
            if isValid {
                return inspectState.colorThresholds.getColor(for: 1.0) // Green for valid
            } else {
                return inspectState.colorThresholds.getColor(for: 0.6) // Warning color for invalid
            }
        } else {
            return getConfigurableAccentColor()
        }
    }
    
    private func getStatusText() -> String {
        // Helper to get label with config override
        let labels = inspectState.config?.uiLabels

        guard let item = currentPageItem else {
            if currentPage == 0 && completedPages.isEmpty {
                return labels?.statusReadyToStart ?? "Ready to Start"
            }
            return labels?.statusInProgress ?? "In Progress"
        }

        // Check validation results and completion status
        if inspectState.completedItems.contains(item.id) {
            return labels?.completedStatus ?? "Completed"
        } else if let isValid = inspectState.plistValidationResults[item.id] {
            if isValid {
                return labels?.statusConditionMet ?? "Condition Met"
            } else {
                return labels?.statusConditionNotMet ?? "Condition Not Met"
            }
        } else if inspectState.downloadingItems.contains(item.id) {
            return labels?.statusChecking ?? "Checking..."
        } else if currentPage == 0 && completedPages.isEmpty {
            return labels?.statusReadyToStart ?? "Ready to Start"
        } else {
            return labels?.pendingStatus ?? "Pending"
        }
    }

    @ViewBuilder
    private func minimalProgressDots() -> some View {
        HStack(spacing: 12) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? getConfigurableTextColor() : getConfigurableTextColor().opacity(0.3))
                    .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
                    .scaleEffect(index == currentPage ? 1.0 : 0.8)
                    .animation(.easeInOut(duration: 0.3), value: currentPage)
                    .onTapGesture {
                        navigateToPage(index)
                    }
            }
        }
    }

    @ViewBuilder
    private func minimalDescriptionText() -> some View {
        VStack(spacing: 12) {
            if let item = currentPageItem {
                Text(item.displayName)
                    .font(.system(size: 28, weight: .regular))
                    .foregroundColor(getConfigurableTextColor())
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.3), value: currentPage)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(getConfigurableTextColor().opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                }
            } else {
                Text("Get Started")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundColor(getConfigurableTextColor())
                    .multilineTextAlignment(.center)

                Text("Follow the steps to complete setup")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(getConfigurableTextColor().opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 80)
    }

    @ViewBuilder
    private func minimalBottomButton() -> some View {
        HStack(spacing: 16) {
            // Secondary button (Go/Skip) - left side
            if inspectState.buttonConfiguration.button2Visible && 
               !inspectState.buttonConfiguration.button2Text.isEmpty {
                Button(inspectState.buttonConfiguration.button2Text) {
                    print("Secondary button clicked!")
                    handleButton2Action()
                }
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .frame(height: 50)
                .padding(.horizontal, 24)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .buttonStyle(.plain)
            } else {
                // Placeholder secondary button for layout consistency
                Button("Go") {
                    print("Go button clicked!")
                    // Could be used for alternative action or skip
                    navigateForward()
                }
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .frame(height: 50)
                .padding(.horizontal, 24)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            // Primary Continue button - blue and prominent
            Button(action: {
                print("CONTINUE CLICKED! Page: \(currentPage)")

                // Check for Option+Click shortcut in single-select picker mode
                let isOptionPressed = NSEvent.modifierFlags.contains(.option)
                let selectionMode = inspectState.config?.pickerConfig?.selectionMode ?? "none"
                let shouldFinishImmediately = isOptionPressed &&
                                              selectionMode == "single" &&
                                              validateSelections()

                if shouldFinishImmediately {
                    // Option+Click shortcut - finish immediately
                    writeLog("Preset8: Option+Click shortcut triggered - finishing immediately", logLevel: .info)

                    if isPickerMode {
                        writeSelectionsToOutput()
                    }

                    exit(0)
                } else if isLastPage {
                    // Validate selections in picker mode
                    if isPickerMode && !validateSelections() {
                        writeLog("Preset8: Finish blocked - no selection made", logLevel: .info)
                        // TODO: Show error feedback to user
                        return
                    }

                    // Write selections to output if in picker mode
                    if isPickerMode {
                        writeSelectionsToOutput()
                    }

                    writeLog("Preset8: Final step completed - exiting", logLevel: .info)
                    exit(0)
                } else {
                    navigateForward()
                }
            }) {
                let labels = inspectState.config?.pickerLabels
                let baseButtonText = isLastPage
                    ? (labels?.finishButton ?? inspectState.config?.button1Text ?? "Finish")
                    : (labels?.continueButton ?? inspectState.config?.button1Text ?? "Continue")

                // Compute final button text with selection count
                let buttonText: String = {
                    var text = baseButtonText
                    if isPickerMode && selectedCount > 0 {
                        let selectionMode = inspectState.config?.pickerConfig?.selectionMode ?? "none"
                        if selectionMode == "single" {
                            text += " ✓"
                        } else if selectionMode == "multi" {
                            text += " (\(selectedCount) selected)"
                        }
                    }
                    return text
                }()

                HStack(spacing: 8) {
                    Text(buttonText)
                        .font(.system(size: 17, weight: .semibold))

                    if !isLastPage {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .medium))
                    }
                }
                .foregroundColor(.white)
                .frame(height: 50)
                .padding(.horizontal, 32)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [getConfigurableAccentColor(), getConfigurableAccentColor().opacity(0.8)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .help({
                let selectionMode = inspectState.config?.pickerConfig?.selectionMode ?? "none"
                if selectionMode == "single" && !isLastPage {
                    return "Continue to next step (Option-click to finish immediately)"
                } else if isLastPage {
                    return "Complete setup"
                } else {
                    return "Continue to next step"
                }
            }())
        }
    }

    // Helper function for minimal icons
    private func getMinimalIcon(for pageIndex: Int) -> String {
        let minimalIcons = [
            "hand.wave",
            "gearshape",
            "arrow.down.circle",
            "checkmark.circle",
            "star",
            "shield",
            "bell",
            "checkmark.seal"
        ]
        return minimalIcons[pageIndex % minimalIcons.count]
    }

    // MARK: - Legacy View Builders (kept for compatibility)

    private func sfSymbolView(from iconPath: String) -> some View {
        // Parse SF Symbol configuration for minimal design
        let components = iconPath.components(separatedBy: ",")
        var symbolName = "questionmark.circle"
        var weight = Font.Weight.ultraLight
        var color1 = Color.white.opacity(0.8)
        var color2: Color?

        for component in components {
            let parts = component.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                
                switch key {
                case "sf":
                    symbolName = value
                case "weight":
                    weight = parseWeight(value)
                case "colour1", "color1":
                    color1 = Color(hex: value)
                case "colour2", "color2":
                    color2 = Color(hex: value)
                default:
                    break
                }
            }
        }

        // Create minimal symbol view
        return Group {
            if let color2 = color2 {
                // Gradient symbol
                Image(systemName: symbolName)
                    .font(.system(size: 100, weight: weight))
                    .foregroundStyle(LinearGradient(colors: [color1, color2], startPoint: .topLeading, endPoint: .bottomTrailing))
            } else {
                // Single color symbol
                Image(systemName: symbolName)
                    .font(.system(size: 100, weight: weight))
                    .foregroundColor(color1)
            }
        }
    }

    private func parseWeight(_ weightString: String) -> Font.Weight {
        switch weightString.lowercased() {
        case "ultralight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default: return .regular
        }
    }

    @ViewBuilder
    private func placeholderContent(for item: InspectConfig.ItemConfig) -> some View {
        VStack(spacing: 20) {
            // Large placeholder rectangle mimicking a screenshot
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: windowSize.width * 0.6, height: windowSize.height * 0.4)
                    .overlay(
                        VStack {
                            Image(systemName: getPlaceholderIcon(for: currentPage))
                                .font(.system(size: 60))
                                .foregroundColor(.blue.opacity(0.6))
                            
                            Text("Step \(currentPage + 1)")
                                .font(.title2)
                                .fontWeight(.medium)
                                .multilineTextAlignment(.center)
                                .padding(.top, 10)
                        }
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
        }
    }

    @ViewBuilder
    private func enhancedPlaceholderContent(for item: InspectConfig.ItemConfig) -> some View {
        VStack(spacing: 24) {
            // Enhanced placeholder with more detail
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.08),
                                Color.indigo.opacity(0.12),
                                Color.purple.opacity(0.08)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: windowSize.width * 0.6, height: windowSize.height * 0.4)
                    .overlay(
                        VStack(spacing: 16) {
                            // Dynamic icon based on step
                            Image(systemName: getEnhancedPlaceholderIcon(for: currentPage))
                                .font(.system(size: 64, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue, Color.indigo]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            VStack(spacing: 4) {
                                Text("Step \(currentPage + 1)")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text(getStepDescription(for: currentPage, itemName: item.displayName))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding()
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.blue.opacity(0.3),
                                        Color.purple.opacity(0.2)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
            }
        }
    }

    // MARK: - Configuration-based Color & Gradient Helpers
    
    /// Creates a configurable gradient based on JSON config or fallback to defaults
    private func createConfigurableGradient() -> LinearGradient {
        // Check if custom gradient colors are provided in config
        if let gradientColors = inspectState.config?.gradientColors, !gradientColors.isEmpty {
            let colors = gradientColors.compactMap { Color(hex: $0) }
            if !colors.isEmpty {
                return LinearGradient(
                    gradient: Gradient(colors: colors),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        
        // Check if single highlight color is provided
        if let highlightColor = inspectState.config?.highlightColor {
            let baseColor = Color(hex: highlightColor)
            return LinearGradient(
                gradient: Gradient(colors: [
                    baseColor.opacity(0.8),
                    baseColor.opacity(0.6),
                    baseColor.opacity(0.8)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        // Fallback to default gradient
        return LinearGradient(
            gradient: Gradient(colors: [
                Color.blue.opacity(0.8),
                Color.purple.opacity(0.6),
                Color.indigo.opacity(0.8)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Gets configurable background color or image
    @ViewBuilder
    private func getConfigurableBackground() -> some View {
        if let backgroundImage = inspectState.config?.backgroundImage {
            // Try to load background image
            if let resolvedPath = iconCache.resolveImagePath(backgroundImage, basePath: inspectState.uiConfiguration.iconBasePath),
               let nsImage = NSImage(contentsOfFile: resolvedPath) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(inspectState.config?.backgroundOpacity ?? 1.0)
            } else {
                // Fallback to color if image fails to load
                getConfigurableBackgroundColor()
            }
        } else {
            getConfigurableBackgroundColor()
        }
    }
    
    /// Gets configurable background color
    private func getConfigurableBackgroundColor() -> Color {
        if let backgroundColor = inspectState.config?.backgroundColor {
            return Color(hex: backgroundColor)
        }
        return Color.black // Default background
    }
    
    /// Gets configurable text color for overlays
    private func getConfigurableTextColor() -> Color {
        if let textOverlayColor = inspectState.config?.textOverlayColor {
            return Color(hex: textOverlayColor)
        }
        return Color.white.opacity(0.9) // Default text color
    }
    
    /// Gets configurable accent color for status indicators and buttons
    private func getConfigurableAccentColor() -> Color {
        if let highlightColor = inspectState.config?.highlightColor {
            return Color(hex: highlightColor)
        }
        return Color.blue // Default accent color
    }

    // MARK: - Background Evaluation & Monitoring
    
    /// Triggers evaluation for a specific item (file/plist checks) with caching to prevent flickering
    private func triggerItemEvaluation(_ item: InspectConfig.ItemConfig) {
        writeLog("Preset8: Triggering evaluation for item: \(item.id)", logLevel: .info)
        
        // Log interaction for external scripts
        writeInteractionLog("evaluate_item", page: currentPage, itemId: item.id)
        
        // Check validation cache to prevent rapid re-evaluation
        let now = Date()
        if let lastValidation = lastValidationTime[item.id],
           let cachedResult = validationCache[item.id],
           now.timeIntervalSince(lastValidation) < 2.0 { // Cache for 2 seconds
            
            writeLog("Preset8: Using cached validation result for item: \(item.id)", logLevel: .debug)
            applyCachedValidationResult(item: item, result: cachedResult)
            return
        }
        
        // Skip validation for items with empty paths - treat as always valid/completed
        guard !item.paths.isEmpty else {
            writeLog("Preset8: Item \(item.id) has empty paths array - skipping validation and marking as completed", logLevel: .info)
            
            let result = Preset8ValidationResult(
                isValid: true,
                isInstalled: true,
                timestamp: now,
                source: .emptyPaths
            )
            
            cacheAndApplyValidationResult(item: item, result: result)
            return
        }
        
        // Validate the item using InspectState's validation system
        DispatchQueue.global(qos: .userInitiated).async { [inspectState] in
            // Check file system paths for completion first
            let isInstalled = item.paths.first { path in
                FileManager.default.fileExists(atPath: path)
            } != nil
            
            // For plist validation, we need to access the InspectState on the main queue
            // because it's an @ObservedObject and needs to be accessed from the main thread
            DispatchQueue.main.async {
                let isValid: Bool
                let validationSource: Preset8ValidationSource
                
                // Determine validation method and result - prioritize file existence
                if isInstalled {
                    // If file exists, it's always valid and completed
                    isValid = true
                    validationSource = .fileSystem
                } else if item.plistKey != nil || item.paths.contains(where: { $0.hasSuffix(".plist") }) {
                    // Only check plist if file doesn't exist
                    isValid = inspectState.validatePlistItem(item)
                    validationSource = .plist
                } else {
                    // For non-plist items, file existence is the only validation
                    isValid = false
                    validationSource = .fileSystem
                }
                
                writeLog("Preset8: Item \(item.id) evaluation result: isValid=\(isValid), isInstalled=\(isInstalled), source=\(validationSource)", logLevel: .info)
                
                // Create validation result
                let result = Preset8ValidationResult(
                    isValid: isValid,
                    isInstalled: isInstalled,
                    timestamp: now,
                    source: validationSource
                )
                
                // Cache and apply the result
                self.cacheAndApplyValidationResult(item: item, result: result)
            }
        }
    }
    
    /// Caches validation result and applies the outcome
    private func cacheAndApplyValidationResult(item: InspectConfig.ItemConfig, result: Preset8ValidationResult) {
        // Cache the result
        validationCache[item.id] = result
        lastValidationTime[item.id] = result.timestamp
        
        // Apply the result
        applyCachedValidationResult(item: item, result: result)
    }
    
    /// Applies a cached validation result with stable state management
    private func applyCachedValidationResult(item: InspectConfig.ItemConfig, result: Preset8ValidationResult) {
        let wasCompleted = inspectState.completedItems.contains(item.id)
        let shouldBeCompleted = result.isInstalled
        
        // Special handling for items with empty paths - once marked as completed, never remove them
        if item.paths.isEmpty && wasCompleted {
            writeLog("Preset8: Item \(item.id) has empty paths and is already completed - preserving state", logLevel: .debug)
            return
        }
        
        // Only update completion state if there's a real change
        if shouldBeCompleted && !wasCompleted {
            inspectState.completedItems.insert(item.id)
            writeLog("Preset8: Item \(item.id) marked as completed (\(result.source))", logLevel: .info)
        } else if !shouldBeCompleted && wasCompleted {
            // Only remove if we're certain from file system check
            if result.source == .fileSystem {
                inspectState.completedItems.remove(item.id)
                writeLog("Preset8: Item \(item.id) removed from completed (\(result.source))", logLevel: .info)
            }
        }
        
        // Log status change for external monitoring
        let status = result.isInstalled ? "completed" : (result.isValid ? "condition_met" : "condition_not_met")
        print("[PRESET8_STATUS_CHANGE] item=\(item.id) status=\(status) source=\(result.source) cached=\(lastValidationTime[item.id] != result.timestamp)")
        
        // Write detailed status to plist for reliable monitoring
        writeStatusPlist(item: item, result: result, status: status)
    }
    
    /// Writes status to plist with error handling
    private func writeStatusPlist(item: InspectConfig.ItemConfig, result: Preset8ValidationResult, status: String) {
        let statusPath = "/tmp/preset8_status.plist"
        let statusData: [String: Any] = [
            "timestamp": result.timestamp,
            "item_id": item.id,
            "item_name": item.displayName,
            "status": status,
            "is_valid": result.isValid,
            "is_installed": result.isInstalled,
            "validation_source": "\(result.source)",
            "cached": lastValidationTime[item.id] != result.timestamp
        ]
        
        do {
            let plistData = try PropertyListSerialization.data(fromPropertyList: statusData,
                                                               format: .xml,
                                                               options: 0)
            try plistData.write(to: URL(fileURLWithPath: statusPath), options: .atomic)
        } catch {
            writeLog("Preset8: Failed to write status plist: \(error.localizedDescription)", logLevel: .error)
        }
    }
    
    /// Starts monitoring an item when we navigate to its page
    private func startItemMonitoring(_ item: InspectConfig.ItemConfig) {
        writeLog("Preset8: Starting monitoring for item: \(item.id)", logLevel: .debug)
        
        // Immediate evaluation
        triggerItemEvaluation(item)
        
        // Log page entry for external scripts
        writeInteractionLog("page_entered", page: currentPage, itemId: item.id)
    }

    // MARK: - Navigation Methods

    private func handleButton2Action() {
        writeLog("Preset8: User clicked secondary action - exiting with code 2", logLevel: .info)
        exit(2)
    }

    private func navigateBack() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage = max(0, currentPage - 1)
        }
        writeInteractionLog("navigate_back", page: currentPage)
        
        // Start monitoring the new current item
        if let currentItem = currentPageItem {
            startItemMonitoring(currentItem)
        }
        
        savePersistedState()
    }

    private func navigateForward() {
        print("navigateForward called - currentPage: \(currentPage), totalPages: \(totalPages)")
        
        // Mark current page as completed
        completedPages.insert(currentPage)
        print("   - Marked page \(currentPage) as completed")
        
        // Trigger background evaluation for current item
        if let currentItem = currentPageItem {
            triggerItemEvaluation(currentItem)
        }
        
        // Always just move to next page
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage = min(totalPages - 1, currentPage + 1)
        }
        print("   - New currentPage: \(currentPage)")
        
        writeInteractionLog("navigate_forward", page: currentPage)
        
        // Start monitoring the new current item
        if let newCurrentItem = currentPageItem {
            startItemMonitoring(newCurrentItem)
        }
        
        // Check for completion after navigation
        checkForCompletion()
        
        savePersistedState()
    }

    private func navigateToPage(_ pageIndex: Int) {
        guard pageIndex != currentPage && pageIndex >= 0 && pageIndex < totalPages else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage = pageIndex
        }
        writeInteractionLog("navigate_to_page", page: currentPage)
        
        // Start monitoring the new current item
        if let currentItem = currentPageItem {
            startItemMonitoring(currentItem)
        }
        
        savePersistedState()
    }

    // MARK: - Helper Methods

    private func handleManualReset() {
        writeLog("Preset8: Manual reset triggered via option-click", logLevel: .info)

        // Show visual feedback
        withAnimation {
            showResetFeedback = true
        }

        // Reset after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.resetProgress()

            // Clear feedback after reset
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation {
                    self.showResetFeedback = false
                }
            }
        }
    }

    private func resetProgress() {
        withAnimation(.spring()) {
            completedPages.removeAll()
            currentPage = 0
            inspectState.completedItems.removeAll()
            showSuccess = false
        }

        // Clear the persisted state
        persistence.clearState()

        writeInteractionLog("reset", page: 0)
        writeLog("Preset8: Progress reset to beginning", logLevel: .info)
        
        // Trigger evaluation/completion check after reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.checkForCompletion()
        }
    }

    private func checkForCompletion() {
        // Check if ALL items are complete, not just visible ones
        let allComplete = inspectState.items.allSatisfy { inspectState.completedItems.contains($0.id) }

        if allComplete && !showSuccess {
            withAnimation(.easeInOut(duration: 0.5).delay(0.3)) {
                showSuccess = true
            }
            writeInteractionLog("completed", page: currentPage)
        }
    }

    // MARK: - Picker Mode Selection Handler

    /// Handle item selection in picker mode
    private func handleItemSelection(_ item: InspectConfig.ItemConfig) {
        guard isPickerMode else { return }

        // Initialize form state if needed
        if inspectState.guidanceFormInputs["preset8_selections"] == nil {
            inspectState.guidanceFormInputs["preset8_selections"] = GuidanceFormInputState()
        }

        let selectionMode = inspectState.config?.pickerConfig?.selectionMode ?? "none"

        switch selectionMode {
        case "single":
            // Single-select: toggle - if already selected, deselect it
            let currentSelection = inspectState.guidanceFormInputs["preset8_selections"]?.radios["selected_item"]

            if currentSelection == item.id {
                // Clicking the same item again - deselect it
                inspectState.guidanceFormInputs["preset8_selections"]?.radios.removeAll()
                writeLog("Preset8: Deselected item: \(item.id) (\(item.displayName))", logLevel: .info)
            } else {
                // Selecting a different item - clear all and select this one
                inspectState.guidanceFormInputs["preset8_selections"]?.radios.removeAll()
                inspectState.guidanceFormInputs["preset8_selections"]?.radios["selected_item"] = item.id
                writeLog("Preset8: Single-selected item: \(item.id) (\(item.displayName))", logLevel: .info)
            }

        case "multi":
            // Multi-select: toggle checkbox
            let currentState = inspectState.guidanceFormInputs["preset8_selections"]?.checkboxes[item.id] ?? false
            inspectState.guidanceFormInputs["preset8_selections"]?.checkboxes[item.id] = !currentState
            writeLog("Preset8: Multi-select toggled \(item.id) (\(item.displayName)): \(!currentState)", logLevel: .info)

        default:
            break
        }

        writeInteractionLog("item_selected", page: currentPage, itemId: item.id)
    }

    /// Validate selections before allowing completion
    private func validateSelections() -> Bool {
        guard isPickerMode else { return true } // Always valid in onboarding mode

        let allowContinue = inspectState.config?.pickerConfig?.allowContinueWithoutSelection ?? false

        // If continuation without selection is allowed, always valid
        if allowContinue {
            return true
        }

        // Check if any selection was made
        return selectedCount > 0
    }

    /// Write selections to output plist
    private func writeSelectionsToOutput() {
        guard let config = inspectState.config?.pickerConfig,
              config.returnSelections == true else {
            writeLog("Preset8: returnSelections not enabled, skipping output", logLevel: .debug)
            return
        }

        let outputPath = config.outputPath ?? "/tmp/preset8_selections.plist"
        let selectionMode = config.selectionMode ?? "none"

        // Build output data
        var outputData: [String: Any] = [
            "timestamp": Date(),
            "selectionMode": selectionMode,
            "totalItems": inspectState.items.count
        ]

        // Get selections from guidanceFormInputs
        if let formState = inspectState.guidanceFormInputs["preset8_selections"] {
            if selectionMode == "single" {
                // Single selection - return the selected item details
                if let selectedId = formState.radios["selected_item"],
                   let item = inspectState.items.first(where: { $0.id == selectedId }) {
                    outputData["selectedItem"] = [
                        "id": item.id,
                        "displayName": item.displayName,
                        "subtitle": item.subtitle ?? "",
                        "icon": item.icon ?? "",
                        "guiIndex": item.guiIndex
                    ]
                }
            } else if selectionMode == "multi" {
                // Multi selection - return array of selected items
                var selectedItems: [[String: Any]] = []
                for (itemId, isSelected) in formState.checkboxes where isSelected {
                    if let item = inspectState.items.first(where: { $0.id == itemId }) {
                        selectedItems.append([
                            "id": item.id,
                            "displayName": item.displayName,
                            "subtitle": item.subtitle ?? "",
                            "icon": item.icon ?? "",
                            "guiIndex": item.guiIndex
                        ])
                    }
                }
                outputData["selectedItems"] = selectedItems
                outputData["selectionCount"] = selectedItems.count
            }
        }

        // Write plist atomically
        do {
            let plistData = try PropertyListSerialization.data(
                fromPropertyList: outputData,
                format: .xml,
                options: 0
            )
            try plistData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
            writeLog("Preset8: Wrote selections to \(outputPath)", logLevel: .info)
        } catch {
            writeLog("Preset8: Failed to write selections plist: \(error.localizedDescription)", logLevel: .error)
        }
    }

    private func getPlaceholderIcon(for pageIndex: Int) -> String {
        let icons = ["bell.badge", "lock.shield", "arrow.down.circle", "app.badge", "square.stack.3d.up", "externaldrive.badge.timemachine", "hand.raised", "checkmark.seal"]
        return icons[pageIndex % icons.count]
    }

    private func getEnhancedPlaceholderIcon(for pageIndex: Int) -> String {
        let enhancedIcons = [
            "bell.badge.fill",           // Welcome/Introduction
            "lock.shield.fill",          // Security/Privacy
            "arrow.down.circle.fill",    // Download/Install
            "app.badge.fill",            // App Configuration
            "square.stack.3d.up.fill",   // Organization
            "externaldrive.badge.timemachine.fill", // Backup
            "hand.raised.fill",          // Permissions
            "checkmark.seal.fill"        // Completion
        ]
        return enhancedIcons[pageIndex % enhancedIcons.count]
    }

    private func getStepDescription(for pageIndex: Int, itemName: String) -> String {
        let descriptions = [
            "Getting started with \(itemName)",
            "Configuring security settings",
            "Installing required components",
            "Setting up your preferences",
            "Organizing your workspace",
            "Creating backup configuration",
            "Granting necessary permissions",
            "Finalizing setup"
        ]
        return descriptions[pageIndex % descriptions.count]
    }

    /// Handle final button press with safe callback mechanisms
    /// Writes trigger file, updates plist, logs event, then exits
    private func handleFinalButtonPress(buttonText: String) {
        writeLog("Preset8: User clicked final button (\(buttonText))", logLevel: .info)

        // 1. Write to interaction log for script monitoring
        let logPath = "/tmp/preset8_interaction.log"
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
        let triggerPath = "/tmp/preset8_final_button.trigger"
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let triggerContent = "button_text=\(buttonText)\ntimestamp=\(timestamp)\nstatus=completed\n"
        if let data = triggerContent.data(using: .utf8) {
            try? data.write(to: URL(fileURLWithPath: triggerPath), options: .atomic)
            writeLog("Preset8: Created trigger file at \(triggerPath)", logLevel: .debug)
        }

        // 3. Write to plist for structured data access
        let plistPath = "/tmp/preset8_interaction.plist"
        let plistData: [String: Any] = [
            "finalButtonPressed": true,
            "buttonText": buttonText,
            "timestamp": timestamp,
            "preset": "preset8"
        ]
        if let data = try? PropertyListSerialization.data(fromPropertyList: plistData, format: .xml, options: 0) {
            try? data.write(to: URL(fileURLWithPath: plistPath), options: .atomic)
            writeLog("Preset8: Updated interaction plist at \(plistPath)", logLevel: .debug)
        }

        // 4. Small delay to ensure file operations complete
        usleep(100000) // 100ms

        // 5. Exit with success code
        writeLog("Preset8: Exiting with code 0", logLevel: .info)
        exit(0)
    }

    // MARK: - Event Handlers

    private func handleViewAppear() {
        writeLog("Preset8: View appearing, loading state...", logLevel: .info)
        iconCache.cacheItemIcons(for: inspectState)
        iconCache.cacheBannerImage(for: inspectState)
        loadPersistedState()
        
        // Start monitoring current item
        if let currentItem = currentPageItem {
            startItemMonitoring(currentItem)
        }
        
        // Start continuous monitoring timer
        startContinuousMonitoring()
        
        // Check for completion on appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.checkForCompletion()
        }
    }

    private func handleViewDisappear() {
        savePersistedState()
        stopContinuousMonitoring()
    }
    
    /// Starts continuous monitoring of current item every few seconds
    private func startContinuousMonitoring() {
        stopContinuousMonitoring() // Stop any existing timer
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            // Re-evaluate current item periodically (reduced frequency to prevent flickering)
            if let currentItem = self.currentPageItem {
                self.triggerItemEvaluation(currentItem)
            }
        }
        
        writeLog("Preset8: Started continuous monitoring timer", logLevel: .debug)
    }
    
    /// Stops continuous monitoring
    private func stopContinuousMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        writeLog("Preset8: Stopped continuous monitoring timer", logLevel: .debug)
    }

    // MARK: - Interaction Logging

    private func writeInteractionLog(_ event: String, page: Int, itemId: String? = nil) {
        let itemInfo = itemId != nil ? " item=\(itemId!)" : ""
        print("[PRESET8_INTERACTION] event=\(event) page=\(page) total=\(totalPages)\(itemInfo)")
        
        // Write to plist for reliable monitoring
        let plistPath = "/tmp/preset8_interaction.plist"
        var interaction: [String: Any] = [
            "timestamp": Date(),
            "event": event,
            "page": page,
            "totalPages": totalPages,
            "completedPages": Array(completedPages)
        ]
        
        if let itemId = itemId {
            interaction["item_id"] = itemId
            
            // Include current status information
            if let item = inspectState.items.first(where: { $0.id == itemId }) {
                interaction["item_name"] = item.displayName
                interaction["is_completed"] = inspectState.completedItems.contains(itemId)
                interaction["is_downloading"] = inspectState.downloadingItems.contains(itemId)
                if let isValid = inspectState.plistValidationResults[itemId] {
                    interaction["validation_result"] = isValid
                }
            }
        }
        
        if let plistData = try? PropertyListSerialization.data(fromPropertyList: interaction,
                                                               format: .xml,
                                                               options: 0) {
            try? plistData.write(to: URL(fileURLWithPath: plistPath), options: .atomic)
        }
    }

    // MARK: - State Persistence

    private func savePersistedState() {
        let state = Preset8State(
            currentPage: currentPage,
            completedPages: completedPages,
            timestamp: Date()
        )
        persistence.saveState(state)
        writeLog("Preset8: State saved - page \(currentPage), completed: \(completedPages.count)", logLevel: .debug)
    }

    private func loadPersistedState() {
        guard let state = persistence.loadState() else {
            writeLog("Preset8: No previous state found", logLevel: .debug)
            writeInteractionLog("launched", page: 0)
            return
        }

        // Check if state is stale (older than 24 hours)
        if persistence.isStateStale(state, hours: 24) {
            writeLog("Preset8: State is stale, starting fresh", logLevel: .info)
            writeInteractionLog("launched", page: 0)
            return
        }

        writeLog("Preset8: Loaded state - page: \(state.currentPage), completed: \(state.completedPages)", logLevel: .info)

        // Apply the validated state
        currentPage = min(state.currentPage, max(0, totalPages - 1))
        completedPages = state.completedPages

        // Log the restoration
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        writeLog("Preset8: Resumed from \(formatter.string(from: state.timestamp)) - page \(currentPage)", logLevel: .info)

        writeInteractionLog("resumed", page: currentPage)
    }
}

// MARK: - State Persistence Manager
// Note: AsyncImageView is now imported from PresetCommonHelpers.swift

class Preset8StatePersistence {
    private let stateKey = "Preset8State"
    private let userDefaults = UserDefaults.standard
    
    func saveState(_ state: Preset8State) {
        if let data = try? JSONEncoder().encode(state) {
            userDefaults.set(data, forKey: stateKey)
        }
    }
    
    func loadState() -> Preset8State? {
        guard let data = userDefaults.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(Preset8State.self, from: data) else {
            return nil
        }
        return state
    }
    
    func clearState() {
        userDefaults.removeObject(forKey: stateKey)
    }
    
    func isStateStale(_ state: Preset8State, hours: Int) -> Bool {
        let cutoffTime = Date().addingTimeInterval(-TimeInterval(hours * 3600))
        return state.timestamp < cutoffTime
    }
}
