//
//  Preset6View.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 07/10/2025
//
//  Preset6: Progress Stepper with Side Panel
//  Vertical progress stepper on left, configurable content panel on right
//  Based on design concept with logo, message, progress indicator and dialog capabilities
//

import SwiftUI

// MARK: - Preset6 State Definition

struct Preset6State: InspectPersistableState {
    let completedSteps: Set<String>
    let currentStep: Int
    let scrollOffset: CGFloat
    let guidanceFormInputs: [String: GuidanceFormInputState]  // Persist form inputs (checkboxes, dropdowns, radios)
    let timestamp: Date
}

struct Preset6View: View, InspectLayoutProtocol {
    @ObservedObject var inspectState: InspectState
    @State private var completedSteps: Set<String> = []
    @State private var downloadingItems: Set<String> = []
    @State private var currentStep: Int = 0
    @State private var scrollOffset: CGFloat = 0
    @StateObject private var iconCache = PresetIconCache()
    @State private var externalMonitoringTimer: Timer?  // Legacy - will be replaced by fileMonitorSource
    @State private var fileMonitorSource: DispatchSourceFileSystemObject?  // Phase 2: Zero-latency file monitoring
    @State private var cachedBannerImage: NSImage?
    @State private var bannerImageLoaded = false

    // MARK: - State Machine Enums (Shared Framework)

    /// Type aliases to shared state machine enums in InspectStateMachines.swift
    ///
    /// These provide convenient short names while using the shared framework enums.
    /// Presets can either use these typealiases or the full `Inspect*` names directly.
    ///
    /// - Note: Originally defined in Preset6, now extracted to InspectStateMachines.swift
    /// - SeeAlso: `InspectStateMachines.swift` for full documentation
    typealias ProcessingState = InspectProcessingState
    typealias CompletionResult = InspectCompletionResult
    typealias OverrideLevel = InspectOverrideLevel

    // MARK: - Core State Variables (Simplified Architecture)

    @State private var processingState: ProcessingState = .idle
    @State private var stateTimer: Timer?

    // NOTE: Plist monitoring moved to InspectState  -> see InspectState.startPlistMonitoring()

    // MARK: - Legacy State Variables (Being phased out)

    // isProcessing is now a computed property derived from processingState
    @State private var processingCountdown: Int = 0  // Temporary: synced for backward compatibility
    @State private var processingTimer: Timer?       // Temporary: synced for backward compatibility
    @State private var countdownCancelled = false          // Option 3: Track if countdown was cancelled
    @State private var failedSteps: [String: String] = [:] // Option 3: stepId -> failure reason
    @State private var showResetFeedbackLeft = false
    @State private var showResetFeedbackBanner = false

    // Phase 2: Dynamic content update capabilities
    // Started to use MVVM state management (refactored)
    // Replaced @State nested dictionaries with ObservableObject for reliable SwiftUI updates
    @StateObject private var dynamicState = InspectDynamicState()

    // Native plist aggregation
    // Stores categories loaded from plistSources for auto-populating compliance cards
    @State private var plistCategories: [PlistAggregator.ComplianceCategory]?

    // Progressive override mechanism (for reuse migrated to ProcessingState)
    @State private var showOverrideDialog: Bool = false

    // Auto-navigation timer tracking (for cancellation on manual/external navigation)
    @State private var autoNavigationWorkItem: DispatchWorkItem?

    private let persistenceService = InspectPersistence<Preset6State>(presetName: "preset6")

    // Scrollable progress list parameters based on size mode
    private var maxVisibleSteps: Int {
        switch sizeMode {
        case "compact": return 4
        case "large": return 8
        default: return 6  // standard
        }
    }

    // MARK: - Computed Properties

    /// Current override level based on wait elapsed time
    private var currentOverrideLevel: OverrideLevel {
        OverrideLevel.level(for: processingState.waitElapsed)
    }

    /// Whether override UI should be shown
    private var shouldShowOverride: Bool {
        processingState.isActive && currentOverrideLevel != .none
    }

    /// Whether processing is currently active (derived from processingState)
    private var isProcessing: Bool {
        processingState.isActive
    }

    /// Whether navigation should be blocked during processing
    /// - Returns: true if processing and current step has allowNavigationDuringProcessing=false
    private var shouldBlockNavigation: Bool {
        guard isProcessing, let currentItem = inspectState.items[safe: currentStep] else {
            return false
        }
        // Default to true (allow navigation) for better UX
        let allowNav = currentItem.allowNavigationDuringProcessing ?? true
        return !allowNav
    }

    /// Message for warning state
    private var overrideWarningMessage: String? {
        guard currentOverrideLevel == .warning else { return nil }
        return "Still waiting for external process..."
    }

    /// Determines if banner is present for floating help button positioning
    private var hasBanner: Bool {
        cachedBannerImage != nil || (inspectState.uiConfiguration.bannerTitle?.isEmpty == false)
    }

    init(inspectState: InspectState) {
        self.inspectState = inspectState
    }

    var body: some View {
        ZStack {
            // Modern background with subtle gradient
            LinearGradient(
                colors: [
                    Color(NSColor.windowBackgroundColor),
                    Color(NSColor.controlBackgroundColor).opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    // Left side: Compact progress stepper
                    minimalProgressStepper()
                        .frame(width: 240 * scaleFactor)
                        .background(
                            .ultraThinMaterial,
                            in: .rect(
                                topLeadingRadius: 12,
                                bottomLeadingRadius: 12,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 12
                            )
                        )
                        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 1)

                    // Right side: Clean content panel
                    minimalContentPanel()
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 12)
                .padding(.top, 0)

                // Bottom progress bar (Migration Assistant style) - reusable component
                InspectBottomProgressBar(
                    inspectState: inspectState,
                    completedSteps: $completedSteps,
                    currentStep: currentStep,
                    scaleFactor: scaleFactor
                )
            }

            // Instruction banner (top overlay)
            if let bannerConfig = inspectState.config?.instructionBanner,
               let bannerText = bannerConfig.text {
                VStack {
                    InstructionBanner(
                        text: bannerText,
                        autoDismiss: bannerConfig.autoDismiss ?? true,
                        dismissDelay: bannerConfig.dismissDelay ?? 5.0,
                        icon: bannerConfig.icon
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    Spacer()
                }
            }
        }
        .onAppear {
            writeLog("Preset6: View appearing, loading state...", logLevel: .info)
            iconCache.cacheMainIcon(for: inspectState)
            iconCache.cacheItemIcons(for: inspectState)
            cacheBannerImage()
            loadPersistedState()
            // Phase 2: Use zero-latency file monitoring instead of timer polling
            setupFileMonitoring()
            // Start plist monitors for automatic status component updates
            setupPlistMonitors()
            // Load plist sources for native compliance card aggregation
            loadPlistSourcesIfNeeded()
        }
        .onChange(of: inspectState.items.count) { oldCount, newCount in
            // When items change (initial load), update currentStep if needed
            if !completedSteps.isEmpty && !inspectState.items.isEmpty {
                if let firstIncompleteIndex = inspectState.items.firstIndex(where: { !completedSteps.contains($0.id) }) {
                    if currentStep != firstIncompleteIndex {
                        currentStep = firstIncompleteIndex
                        writeLog("Preset6: Items loaded, updated currentStep to \(currentStep)", logLevel: .info)
                    }
                }
            }

            // Start plist monitors when config first loads (items go from 0 to N)
            if oldCount == 0 && newCount > 0 {
                writeLog("Preset6: Config loaded with \(newCount) items, starting plist monitors...", logLevel: .info)
                setupPlistMonitors()
            }
        }
        .onChange(of: inspectState.completedItems) { _, newCompletedItems in
            // Sync with external completions
            withAnimation(.spring()) {
                var shouldAutoNavigate = false
                var completedCurrentStep = false

                for item in inspectState.items {
                    if newCompletedItems.contains(item.id) && !completedSteps.contains(item.id) {
                        completedSteps.insert(item.id)
                        writeLog("Preset6: External completion detected for \(item.id)", logLevel: .debug)

                        // Check if the completed item is the current step
                        if let currentItem = inspectState.items[safe: currentStep],
                           currentItem.id == item.id {
                            completedCurrentStep = true
                            writeLog("Preset6: Current step (\(item.id)) completed externally", logLevel: .info)
                        }
                    }
                }

                // Auto-navigate if current step was completed and we're not at the last step
                // IMPORTANT: Do NOT auto-navigate in these cases:
                // 1. Current step is "processing" type - they handle navigation via success/failure triggers
                // 2. NEXT step has waitForExternalTrigger: true - external script controls navigation
                if completedCurrentStep && currentStep < inspectState.items.count - 1 {
                    if let currentItem = inspectState.items[safe: currentStep] {
                        let stepType = currentItem.stepType ?? "info"

                        // Check if NEXT step has waitForExternalTrigger (external script control)
                        let nextStepIndex = currentStep + 1
                        let nextStepWaitsForTrigger = inspectState.items[safe: nextStepIndex]?.waitForExternalTrigger ?? false

                        if stepType == "processing" {
                            writeLog("Preset6: Skipping auto-navigation for processing step (uses success/failure triggers)", logLevel: .debug)
                        } else if nextStepWaitsForTrigger {
                            writeLog("Preset6: Skipping auto-navigation - next step has waitForExternalTrigger: true (external script controls navigation)", logLevel: .info)
                        } else {
                            // Safe to auto-navigate
                            shouldAutoNavigate = true
                        }
                    }
                }

                checkForCompletion()

                // Auto-navigate after brief delay for user to see success state
                if shouldAutoNavigate {
                    writeLog("Preset6: Auto-navigating to next step in 0.8s", logLevel: .info)

                    // Cancel any pending auto-navigation before scheduling new one
                    autoNavigationWorkItem?.cancel()

                    // Create cancellable work item for delayed navigation
                    let workItem = DispatchWorkItem {
                        navigateToNextStep()
                    }
                    autoNavigationWorkItem = workItem

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
                }
            }
        }
        .onChange(of: inspectState.downloadingItems) { oldDownloadingItems, newDownloadingItems in
            // Sync with external downloading status
            withAnimation(.spring()) {
                downloadingItems = newDownloadingItems

                // Auto-navigate to newly downloading items (external installations)
                let newlyDownloading = newDownloadingItems.subtracting(oldDownloadingItems)
                if let firstNewDownload = newlyDownloading.first,
                   let itemIndex = inspectState.items.firstIndex(where: { $0.id == firstNewDownload }) {
                    // Only jump if not already completed and not the current step
                    if !completedSteps.contains(firstNewDownload) && currentStep != itemIndex {
                        currentStep = itemIndex
                        writeLog("Preset6: Auto-navigated to downloading item: \(firstNewDownload) at index \(itemIndex)", logLevel: .info)
                    }
                }

                writeLog("Preset6: Downloading items updated: \(downloadingItems)", logLevel: .debug)
            }
        }
        .onChange(of: currentStep) { oldStep, newStep in
            // Cancel pending auto-navigation when step changes (manual or external navigate)
            if oldStep != newStep {
                autoNavigationWorkItem?.cancel()
                autoNavigationWorkItem = nil
                writeLog("Preset6: Cancelled pending auto-navigation due to step change (\(oldStep) → \(newStep))", logLevel: .debug)
            }
        }
        .sheet(isPresented: $showOverrideDialog) {
            // Progressive override dialog
            if let stepId = processingState.stepId {
                OverrideDialogView(
                    isPresented: $showOverrideDialog,
                    stepId: stepId,
                    cancelButtonText: inspectState.config?.button2Text ??
                                     (inspectState.buttonConfiguration.button2Text.isEmpty ?
                                      "Cancel" : inspectState.buttonConfiguration.button2Text),
                    onAction: { action in
                        handleOverrideAction(action: action, stepId: stepId)
                    }
                )
            }
        }
        .onDisappear {
            savePersistedState()
            externalMonitoringTimer?.invalidate()
            externalMonitoringTimer = nil
            processingTimer?.invalidate()
            processingTimer = nil
            stateTimer?.invalidate()
            stateTimer = nil
        }
    }


    @ViewBuilder
    private func minimalProgressStepper() -> some View {
        VStack(spacing: 0) {
            // Enhanced header - larger branding for professional appearance
            VStack(spacing: 12 * scaleFactor) {
                // Larger logo section for better brand visibility
                let iconPath = iconCache.getMainIconPath(for: inspectState)

                // Debug: Check what we're getting
                let _ = writeLog("Preset6: Icon path from cache: '\(iconPath)'", logLevel: .debug)
                let _ = writeLog("Preset6: Config iconPath: '\(inspectState.uiConfiguration.iconPath ?? "nil")'", logLevel: .debug)
                let _ = writeLog("Preset6: Config iconBasePath: '\(inspectState.uiConfiguration.iconBasePath ?? "nil")'", logLevel: .debug)

                IconView(
                    image: !iconPath.isEmpty ? iconPath : (inspectState.uiConfiguration.iconPath ?? ""),
                    defaultImage: "gearshape.2.fill",
                    defaultColour: "blue"
                )
                .frame(width: 80 * scaleFactor, height: 80 * scaleFactor)
                .background(
                    Circle()
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
                )

                // Title - enhanced size for better readability
                if !inspectState.uiConfiguration.windowTitle.isEmpty {
                    Text(inspectState.uiConfiguration.windowTitle)
                        .font(.system(size: 16 * scaleFactor, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .padding(.horizontal, 12)
                }

                // Progress indicator repositioned with more spacing
                VStack(spacing: 6 * scaleFactor) {
                    // Progress bar
                    ProgressView(value: Double(currentStep + 1), total: Double(inspectState.items.count))
                        .progressViewStyle(LinearProgressViewStyle())
                        .tint(getConfigurableHighlightColor())
                        .scaleEffect(y: 0.8)
                        .frame(width: 80 * scaleFactor)

                    // Step text - with enhanced spacing before step dots
                    Text(getStepCounterText())
                        .font(.system(size: 12 * scaleFactor, weight: .medium))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                        .padding(.bottom, 12 * scaleFactor)
                        .scaleEffect(showResetFeedbackLeft ? 1.1 : 1.0)
                        .opacity(showResetFeedbackLeft ? 0.7 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: showResetFeedbackLeft)
                        .onTapGesture {
                            if NSEvent.modifierFlags.contains(.option) {
                                handleManualReset(source: "left_stepper")
                            }
                        }
                        .help("Option-click to reset progress")
                }
                .padding(.top, 8 * scaleFactor)
            }
            .frame(height: 160 * scaleFactor)
            .frame(maxWidth: .infinity)

            // Compact progress dots
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 12 * scaleFactor) {
                        ForEach(Array(inspectState.items.enumerated()), id: \.element.id) { index, item in
                            MinimalProgressDot(
                                index: index,
                                item: item,
                                isCompleted: completedSteps.contains(item.id) || inspectState.completedItems.contains(item.id),
                                isDownloading: downloadingItems.contains(item.id),
                                isActive: index == currentStep,
                                scaleFactor: scaleFactor,
                                highlightColor: inspectState.config?.highlightColor ?? inspectState.uiConfiguration.highlightColor,
                                statusIcon: dynamicState.itemStatusIcons[index] ?? item.status  // Dynamic update > static config
                            )
                            .id("dot_\(index)")
                            .onTapGesture {
                                if !isItemObserveOnly(item) {
                                    handleStepClick(item: item, index: index)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .onChange(of: currentStep) { _, newStep in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("dot_\(newStep)", anchor: .center)
                    }

                    // Auto-start processing for steps without action button
                    autoStartProcessingIfNeeded(for: newStep)
                }
            }

            // Compact bottom section - no longer shows extra button (moved to main button area)
            Spacer()
                .frame(height: 20 * scaleFactor)
        }
    }

    @ViewBuilder
    private func minimalContentPanel() -> some View {
        VStack(spacing: 0) {
            // Banner area (if available)
            if cachedBannerImage != nil || (inspectState.uiConfiguration.bannerTitle?.isEmpty == false) {
                bannerContentArea()
                    .frame(height: CGFloat(inspectState.uiConfiguration.bannerHeight) * scaleFactor)
            }
            
            // Main content area with better proportions
            VStack(spacing: 0) {
                // Large hero area for the main content
                heroContentArea()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Clean bottom section with button - balanced spacing
                minimalBottomSection()
                    .frame(height: 90 * scaleFactor)
            }
            .background(
                RoundedRectangle(cornerRadius: cachedBannerImage != nil ? 0 : 16)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
            )
        }
    }
    
    @ViewBuilder
    private func bannerContentArea() -> some View {
        ZStack(alignment: .topTrailing) {
            // Banner image with proper aspect ratio
            if let bannerImage = cachedBannerImage {
                Image(nsImage: bannerImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: CGFloat(inspectState.uiConfiguration.bannerHeight) * scaleFactor)
                    .clipped()
                    .background(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else {
                // Fallback gradient background
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(maxWidth: .infinity, maxHeight: CGFloat(inspectState.uiConfiguration.bannerHeight) * scaleFactor)
            }

            // Improved banner content overlay with better positioning
            VStack(spacing: 0) {
                // Top section with title
                VStack(spacing: 8 * scaleFactor) {
                    if let bannerTitle = inspectState.uiConfiguration.bannerTitle, !bannerTitle.isEmpty {
                        Text(bannerTitle)
                            .font(.system(size: 24 * scaleFactor, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    
                    // Step indicator - more compact with option-click to reset
                    if !inspectState.items.isEmpty && currentStep < inspectState.items.count {
                        HStack {
                            Spacer()
                            Text(getStepCounterText())
                                .font(.system(size: 12 * scaleFactor, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
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
                                .scaleEffect(showResetFeedbackBanner ? 1.1 : 1.0)
                                .opacity(showResetFeedbackBanner ? 0.7 : 1.0)
                                .animation(.easeInOut(duration: 0.3), value: showResetFeedbackBanner)
                                .onTapGesture {
                                    if NSEvent.modifierFlags.contains(.option) {
                                        handleManualReset(source: "banner_stepper")
                                    }
                                }
                                .help("Option-click to reset progress")
                            Spacer()
                        }
                    }
                }
                .padding(.top, 16 * scaleFactor)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 32)

            // Help button integrated into banner (top-right)
            if let extraButton = inspectState.config?.extraButton,
               extraButton.visible ?? true {
                let iconName = (extraButton.icon ?? "questionmark.circle.fill")
                    .replacingOccurrences(of: "sf=", with: "")

                Button(action: {
                    handleExtraButtonAction(extraButton)
                }) {
                    ZStack {
                        // Semi-transparent white background with better contrast
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 36 * scaleFactor, height: 36 * scaleFactor)

                        // Text fallback with highlight color (works where SF Symbols don't)
                        Text("?")
                            .font(.system(size: 22 * scaleFactor, weight: .bold))
                            .foregroundColor(Color(hex: inspectState.config?.highlightColor ?? inspectState.uiConfiguration.highlightColor) ?? .blue)
                    }
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .help(extraButton.text)
                .padding(.top, 12 * scaleFactor)
                .padding(.trailing, 16 * scaleFactor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: CGFloat(inspectState.uiConfiguration.bannerHeight) * scaleFactor)
        .clipShape(
            .rect(
                topLeadingRadius: 16,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 16
            )
        )
    }
    
    @ViewBuilder
    private func heroContentArea() -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                if let currentItem = inspectState.items[safe: currentStep] {
                    let hasGuidance = currentItem.guidanceContent?.isEmpty == false

                    if hasGuidance {
                        // Migration Assistant style guidance view
                        // SwiftUI Fix: Add .id() to force re-render when @State changes
                        guidanceContentView(for: currentItem)
                    } else {
                        // Original compact step view
                        originalStepView(for: currentItem)
                    }
                } else {
                    // Compact completion state
                    completionView()
                }
            }

            // Category icon bubble in top-right corner (if specified)
            if let currentItem = inspectState.items[safe: currentStep],
               let categoryIcon = currentItem.categoryIcon {
                CategoryIconBubble(
                    iconName: categoryIcon,
                    iconBasePath: inspectState.uiConfiguration.iconBasePath,
                    iconCache: iconCache,
                    scaleFactor: scaleFactor
                )
                .padding([.top, .trailing], 16 * scaleFactor)
            }

            // Help button (only show when no banner present)
            if !hasBanner,
               let extraButton = inspectState.config?.extraButton,
               extraButton.visible ?? true {
                let iconName = (extraButton.icon ?? "questionmark.circle.fill")
                    .replacingOccurrences(of: "sf=", with: "")

                Button(action: {
                    handleExtraButtonAction(extraButton)
                }) {
                    ZStack {
                        // Semi-transparent white background with better contrast
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 36 * scaleFactor, height: 36 * scaleFactor)

                        // Text fallback with highlight color (works where SF Symbols don't)
                        Text("?")
                            .font(.system(size: 22 * scaleFactor, weight: .bold))
                            .foregroundColor(Color(hex: inspectState.config?.highlightColor ?? inspectState.uiConfiguration.highlightColor) ?? .blue)
                    }
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .help(extraButton.text)
                .padding(.top, 12 * scaleFactor)
                .padding(.trailing, 16 * scaleFactor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func guidanceContentView(for item: InspectConfig.ItemConfig) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16 * scaleFactor) {
                // Step heading
                VStack(alignment: .leading, spacing: 4 * scaleFactor) {
                    if let guidanceTitle = item.guidanceTitle {
                        Text(guidanceTitle)
                            .font(.system(size: 20 * scaleFactor, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.bottom, 8 * scaleFactor)

                // Guidance content blocks with dynamic updates
                if let guidanceContent = item.guidanceContent {
                    // Apply dynamic content updates to guidance blocks
                    let updatedContent = guidanceContent.enumerated().map { index, block in
                        applyDynamicUpdates(to: block, index: index, itemId: item.id)
                    }

                    GuidanceContentView(
                        contentBlocks: updatedContent,
                        scaleFactor: scaleFactor,
                        iconBasePath: inspectState.uiConfiguration.iconBasePath,
                        inspectState: inspectState,
                        itemId: item.id
                    )
                    // No longer need .id() modifier - @Published guarantees updates
                }

                // Custom data display (Phase 2)
                if let customData = dynamicState.customDataDisplay[item.id], !customData.isEmpty {
                    VStack(alignment: .leading, spacing: 8 * scaleFactor) {
                        ForEach(Array(customData.enumerated()), id: \.offset) { _, triple in
                            let key = triple.0
                            let value = triple.1
                            let colorHex = triple.2

                            HStack(spacing: 8 * scaleFactor) {
                                Text(key + ":")
                                    .font(.system(size: 13 * scaleFactor, weight: .medium))
                                    .foregroundColor(colorHex != nil ? Color(hex: colorHex!).opacity(0.7) : .secondary)

                                Text(value)
                                    .font(.system(size: 13 * scaleFactor, weight: .semibold))
                                    .foregroundColor(colorHex != nil ? Color(hex: colorHex!) : .primary)

                                Spacer()
                            }
                            .padding(.horizontal, 12 * scaleFactor)
                            .padding(.vertical, 8 * scaleFactor)
                            .background((colorHex != nil ? Color(hex: colorHex!) : Color.secondary).opacity(0.1))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke((colorHex != nil ? Color(hex: colorHex!) : Color.clear).opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.top, 8 * scaleFactor)
                }

                // Warning message after long wait (progressive override mechanism)
                // Only show during .waiting state (progressive mode), not during countdown or when showing progress
                // Only show if allowOverride is enabled (defaults to true if not specified)
                if case .warning = currentOverrideLevel,
                   case .waiting = processingState,
                   dynamicState.progressPercentages[item.id] == nil,
                   (item.allowOverride ?? true) == true {
                    HStack(spacing: 8 * scaleFactor) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14 * scaleFactor))
                            .foregroundColor(.orange)

                        Text("This step has been waiting for over \(processingState.waitElapsed) seconds. If you're experiencing issues, you can use the override option below.")
                            .font(.system(size: 13 * scaleFactor))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12 * scaleFactor)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.top, 8 * scaleFactor)
                }

                // Processing countdown if active (Option 3 - Hybrid approach with large visual countdown)
                if isProcessing, let processingMessage = item.processingMessage {
                    VStack(spacing: 16 * scaleFactor) {
                        // Large countdown number (3...2...1) OR percentage progress OR waiting state
                        if let percentage = dynamicState.progressPercentages[item.id] {
                            // Phase 2: Show percentage progress (external script sending updates)
                            ZStack {
                                Circle()
                                    .stroke(getConfigurableHighlightColor().opacity(0.3), lineWidth: 4)
                                    .frame(width: 100 * scaleFactor, height: 100 * scaleFactor)

                                Circle()
                                    .trim(from: 0, to: CGFloat(percentage) / 100.0)
                                    .stroke(getConfigurableHighlightColor(), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                    .frame(width: 100 * scaleFactor, height: 100 * scaleFactor)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.linear(duration: 0.3), value: percentage)

                                Text("\(percentage)%")
                                    .font(.system(size: 36 * scaleFactor, weight: .bold, design: .rounded))
                                    .foregroundColor(getConfigurableHighlightColor())
                            }
                            .padding(.vertical, 8 * scaleFactor)
                        } else if case .countdown(_, let remaining, _) = processingState {
                            // Countdown display (3...2...1...0) - using state machine
                            // Show countdown even at 0 to avoid flash before state transition
                            ZStack {
                                Circle()
                                    .stroke(getConfigurableHighlightColor().opacity(0.3), lineWidth: 4)
                                    .frame(width: 100 * scaleFactor, height: 100 * scaleFactor)

                                Circle()
                                    .trim(from: 0, to: CGFloat(remaining) / CGFloat(item.processingDuration ?? 5))
                                    .stroke(getConfigurableHighlightColor(), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                    .frame(width: 100 * scaleFactor, height: 100 * scaleFactor)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.linear(duration: 1.0), value: remaining)

                                Text("\(max(0, remaining))")
                                    .font(.system(size: 48 * scaleFactor, weight: .bold, design: .rounded))
                                    .foregroundColor(getConfigurableHighlightColor())
                            }
                            .padding(.vertical, 8 * scaleFactor)
                        } else if case .waiting = processingState {
                            // Waiting state - show animated spinner (not static)
                            // Clear visual feedback that we're waiting for external trigger
                            ProgressView()
                                .controlSize(.large)
                                .tint(getConfigurableHighlightColor())
                                .scaleEffect(1.5 * scaleFactor)
                                .frame(height: 100 * scaleFactor)
                        } else if processingCountdown > 0 {
                            // Fallback: Legacy countdown display (should not reach here anymore)
                            ZStack {
                                Circle()
                                    .stroke(getConfigurableHighlightColor().opacity(0.3), lineWidth: 4)
                                    .frame(width: 100 * scaleFactor, height: 100 * scaleFactor)

                                Circle()
                                    .trim(from: 0, to: CGFloat(processingCountdown) / CGFloat(item.processingDuration ?? 5))
                                    .stroke(getConfigurableHighlightColor(), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                    .frame(width: 100 * scaleFactor, height: 100 * scaleFactor)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.linear(duration: 1.0), value: processingCountdown)

                                Text("\(processingCountdown)")
                                    .font(.system(size: 48 * scaleFactor, weight: .bold, design: .rounded))
                                    .foregroundColor(getConfigurableHighlightColor())
                            }
                            .padding(.vertical, 8 * scaleFactor)
                        } else {
                            // Fallback: Static ellipsis (should not reach here anymore)
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 48 * scaleFactor, weight: .medium))
                                .foregroundColor(getConfigurableHighlightColor())
                                .padding(.vertical, 24 * scaleFactor)
                        }

                        // Phase 2: Use dynamic message if available, otherwise compute based on state
                        let displayMessage: String = {
                            if let dynamicMsg = dynamicState.dynamicMessages[item.id] {
                                return dynamicMsg
                            } else if case .countdown(_, let remaining, _) = processingState, remaining > 0 {
                                return processingMessage.replacingOccurrences(of: "{countdown}", with: "\(remaining)")
                            } else if case .waiting = processingState {
                                return "Waiting for result..."
                            } else if processingCountdown > 0 {
                                // Fallback: legacy countdown
                                return processingMessage.replacingOccurrences(of: "{countdown}", with: "\(processingCountdown)")
                            } else {
                                return "Processing..."
                            }
                        }()

                        Text(displayMessage)
                            .font(.system(size: 14 * scaleFactor, weight: .medium))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16 * scaleFactor)
                }

                // Success/Failure result banner (Option 3 - Hybrid approach)
                if completedSteps.contains(item.id) {
                    if let failureReason = failedSteps[item.id] {
                        // Failure banner
                        HStack(spacing: 12 * scaleFactor) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20 * scaleFactor))
                                .foregroundColor(.red)

                            VStack(alignment: .leading, spacing: 4 * scaleFactor) {
                                Text(item.failureMessage ?? "Step Failed")
                                    .font(.system(size: 14 * scaleFactor, weight: .semibold))
                                    .foregroundColor(.primary)

                                if !failureReason.isEmpty {
                                    Text(failureReason)
                                        .font(.system(size: 12 * scaleFactor))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()
                        }
                        .padding(12 * scaleFactor)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.top, 8 * scaleFactor)
                    } else if let successMessage = item.successMessage {
                        // Success banner
                        HStack(spacing: 12 * scaleFactor) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20 * scaleFactor))
                                .foregroundColor(.green)

                            Text(successMessage)
                                .font(.system(size: 14 * scaleFactor, weight: .semibold))
                                .foregroundColor(.primary)

                            Spacer()
                        }
                        .padding(12 * scaleFactor)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.top, 8 * scaleFactor)
                    }
                }
            }
            .padding(.horizontal, 24 * scaleFactor)
            .padding(.top, 16 * scaleFactor)
            .padding(.bottom, 12 * scaleFactor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Helper function to apply dynamic updates to guidance content blocks
    /// Separated from guidanceContentView to avoid Swift type checker timeout
    private func applyDynamicUpdates(to block: InspectConfig.GuidanceContent, index: Int, itemId: String) -> InspectConfig.GuidanceContent {
        // Check for plist-populated compliance cards
        // Use content field as category identifier to auto-populate from plistSources
        if block.type == "compliance-card",
           let categoryName = block.content,
           !categoryName.isEmpty,
           let plistCategories = self.plistCategories,
           let category = plistCategories.first(where: { $0.name == categoryName }) {

            // Auto-populate compliance card from plist data
            writeLog("Preset6: Auto-populating compliance card for category '\(categoryName)' (\(category.passed)/\(category.total))", logLevel: .debug)

            return InspectConfig.GuidanceContent(
                type: block.type,
                content: block.content,
                color: block.color,
                bold: block.bold,
                imageShape: block.imageShape,
                imageWidth: block.imageWidth,
                imageBorder: block.imageBorder,
                caption: block.caption,
                id: block.id,
                required: block.required,
                options: block.options,
                value: block.value,
                helpText: block.helpText,
                min: block.min,
                max: block.max,
                step: block.step,
                unit: block.unit,
                action: block.action,
                url: block.url,
                shell: block.shell,
                buttonStyle: block.buttonStyle,
                label: block.label,
                state: block.state,
                icon: block.icon,
                autoColor: block.autoColor,
                expected: block.expected,
                actual: block.actual,
                expectedLabel: block.expectedLabel,
                actualLabel: block.actualLabel,
                expectedIcon: block.expectedIcon,
                actualIcon: block.actualIcon,
                comparisonStyle: block.comparisonStyle,
                highlightCells: block.highlightCells,
                expectedColor: block.expectedColor,
                actualColor: block.actualColor,
                category: block.category,
                currentPhase: block.currentPhase,
                phases: block.phases,
                style: block.style,
                progress: block.progress,
                images: block.images,
                captions: block.captions,
                imageHeight: block.imageHeight,
                showDots: block.showDots,
                showArrows: block.showArrows,
                autoAdvance: block.autoAdvance,
                autoAdvanceDelay: block.autoAdvanceDelay,
                transitionStyle: block.transitionStyle,
                currentIndex: block.currentIndex,
                // Auto-populated from plist data
                categoryName: category.name,
                passed: category.passed,
                total: category.total,
                cardIcon: block.cardIcon ?? category.icon,  // Use plist icon if card icon not specified
                checkDetails: PlistAggregator.generateCheckDetails(
                    items: category.items,
                    maxItems: 15,  // TODO: Make configurable via plistSources.maxCheckDetails
                    sortFailedFirst: true
                )
            )
        }

        // Check if there are dynamic updates for this block
        let hasDynamicContent = dynamicState.dynamicGuidanceContent[itemId]?[index] != nil
        let hasDynamicProps = dynamicState.dynamicGuidanceProperties[itemId]?[index] != nil

        guard hasDynamicContent || hasDynamicProps else {
            return block
        }

        let props = dynamicState.dynamicGuidanceProperties[itemId]?[index] ?? [:]

        // Create new block with updated properties (properties are immutable)
        return InspectConfig.GuidanceContent(
            type: block.type,
            content: dynamicState.dynamicGuidanceContent[itemId]?[index] ?? block.content,
            color: block.color,
            bold: block.bold,
            imageShape: block.imageShape,
            imageWidth: block.imageWidth,
            imageBorder: block.imageBorder,
            caption: block.caption,
            id: block.id,
            required: block.required,
            options: block.options,
            value: block.value,
            helpText: block.helpText,
            min: block.min,
            max: block.max,
            step: block.step,
            unit: block.unit,
            action: block.action,
            url: block.url,
            shell: block.shell,
            buttonStyle: block.buttonStyle,
            label: props["label"] ?? block.label,
            state: props["state"] ?? block.state,
            icon: props["icon"] ?? block.icon,
            autoColor: props["autoColor"].flatMap { Bool($0) } ?? block.autoColor,
            expected: props["expected"] ?? block.expected,
            actual: props["actual"] ?? block.actual,
            expectedLabel: props["expectedLabel"] ?? block.expectedLabel,
            actualLabel: props["actualLabel"] ?? block.actualLabel,
            expectedIcon: props["expectedIcon"] ?? block.expectedIcon,
            actualIcon: props["actualIcon"] ?? block.actualIcon,
            comparisonStyle: props["comparisonStyle"] ?? block.comparisonStyle,
            highlightCells: props["highlightCells"].flatMap { Bool($0) } ?? block.highlightCells,
            expectedColor: props["expectedColor"] ?? block.expectedColor,
            actualColor: props["actualColor"] ?? block.actualColor,
            category: block.category,
            currentPhase: props["currentPhase"].flatMap { Int($0) } ?? block.currentPhase,
            phases: block.phases,
            style: props["style"] ?? block.style,
            progress: props["progress"].flatMap { Double($0) } ?? block.progress,
            images: block.images,
            captions: block.captions,
            imageHeight: block.imageHeight,
            showDots: block.showDots,
            showArrows: block.showArrows,
            autoAdvance: block.autoAdvance,
            autoAdvanceDelay: block.autoAdvanceDelay,
            transitionStyle: block.transitionStyle,
            currentIndex: props["currentIndex"].flatMap { Int($0) } ?? block.currentIndex,
            categoryName: props["categoryName"] ?? block.categoryName,
            passed: props["passed"].flatMap { Int($0) } ?? block.passed,
            total: props["total"].flatMap { Int($0) } ?? block.total,
            cardIcon: props["cardIcon"] ?? block.cardIcon,
            checkDetails: props["checkDetails"] ?? block.checkDetails
        )
    }

    @ViewBuilder
    private func originalStepView(for item: InspectConfig.ItemConfig) -> some View {
        VStack(spacing: 12 * scaleFactor) {
            Spacer(minLength: 4)

            // Smaller step icon
            if item.icon != nil {
                IconView(
                    image: iconCache.getItemIconPath(for: item, state: inspectState),
                    defaultImage: "circle.dashed",
                    defaultColour: "blue"
                )
                .frame(width: 96 * scaleFactor, height: 96 * scaleFactor)
                .background(
                    Circle()
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
                )
            }

            // More compact content
            VStack(spacing: 6 * scaleFactor) {
                Text(item.displayName)
                    .font(.system(size: 16 * scaleFactor, weight: .medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)

                if let description = item.paths.first, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 11 * scaleFactor))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                }
            }

            // Status indicator with larger icons - 45px
            HStack(spacing: 6) {
                Image(systemName: completedSteps.contains(item.id) ?
                      "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(completedSteps.contains(item.id) ?
                                   .green : getConfigurableHighlightColor())

                Text(completedSteps.contains(item.id) ? "Completed" : "Pending")
                    .font(.system(size: 12 * scaleFactor, weight: .medium))
                    .foregroundColor(completedSteps.contains(item.id) ?
                                   .green : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.thinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(completedSteps.contains(item.id) ?
                                  Color.green.opacity(0.3) : getConfigurableHighlightColor().opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
            )

            Spacer(minLength: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func completionView() -> some View {
        VStack(spacing: 12 * scaleFactor) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48 * scaleFactor, weight: .medium))
                .foregroundColor(.green)
                .background(
                    Circle()
                        .fill(.thinMaterial)
                        .shadow(color: .green.opacity(0.12), radius: 6, x: 0, y: 1)
                )

            VStack(spacing: 6) {
                Text(inspectState.config?.uiLabels?.completionMessage ?? "All Steps Complete")
                    .font(.system(size: 16 * scaleFactor, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text(inspectState.config?.uiLabels?.completionSubtitle ?? "Your setup is now complete!")
                    .font(.system(size: 12 * scaleFactor))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func minimalBottomSection() -> some View {
        VStack(spacing: 0) {
            // Message area with better spacing
            if let currentMessage = inspectState.getCurrentSideMessage() {
                Text(currentMessage)
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 12 * scaleFactor)
                    .italic()
                    .lineLimit(2)
            } else {
                Spacer()
                    .frame(height: 12 * scaleFactor)
            }

            Spacer()

            // Button area with better padding
            minimalButtonArea()
                .padding(.horizontal, 24)
                .padding(.bottom, 20 * scaleFactor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func minimalButtonArea() -> some View {
        let allStepsComplete = inspectState.items.allSatisfy { completedSteps.contains($0.id) }

        HStack(spacing: 16) {
            // Reset button - show when all steps complete
            if allStepsComplete {
                Button("Reset") {
                    resetSteps()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            // Back button - minimal style with extra padding
            if currentStep > 0 && !allStepsComplete && !isProcessing {
                Button(inspectState.config?.button2Text ??
                       (inspectState.buttonConfiguration.button2Text.isEmpty ? "Back" : inspectState.buttonConfiguration.button2Text)) {
                    navigateToPreviousStep()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            // Cancel button during countdown (Option 3 - Hybrid approach)
            if isProcessing {
                Button(inspectState.config?.button2Text ??
                       (inspectState.buttonConfiguration.button2Text.isEmpty ? "Cancel" : inspectState.buttonConfiguration.button2Text)) {
                    processingTimer?.invalidate()
                    processingTimer = nil
                    stateTimer?.invalidate()
                    stateTimer = nil
                    countdownCancelled = true

                    if let currentItem = inspectState.items[safe: currentStep] {
                        // Transition to completed state with cancelled result
                        processingState = .completed(stepId: currentItem.id, result: .cancelled)

                        // Mark as failed (for failure banner)
                        failedSteps[currentItem.id] = currentItem.failureMessage ?? "Processing cancelled by user"
                        completedSteps.insert(currentItem.id)

                        logPreset6Event("countdown_cancelled", details: ["stepId": currentItem.id])
                        writeInteractionLog("cancelled", step: currentItem.id)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Spacer()

            // Progressive override buttons (appears during long waits)
            // Only show if allowOverride is enabled (defaults to true if not specified)
            if let currentItem = inspectState.items[safe: currentStep],
               isProcessing,
               (currentItem.allowOverride ?? true) == true {
                let overrideText = currentItem.overrideButtonText ?? "Override"

                // Small override link (20 seconds)
                if case .small = currentOverrideLevel {
                    Button(action: {
                        showOverrideDialog = true
                    }) {
                        Text("Skip this step")
                            .font(.system(size: 12 * scaleFactor))
                            .foregroundColor(.secondary)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 4)
                }

                // Large override button (60 seconds - replaces small link)
                if case .large = currentOverrideLevel {
                    Button(overrideText) {
                        showOverrideDialog = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.large)
                    .padding(.vertical, 4)
                }
            }

            // Action button based on current step with improved styling and padding
            if let currentItem = inspectState.items[safe: currentStep] {
                let stepType = currentItem.stepType ?? "info"

                // Check if form inputs are valid for this step
                let hasRequiredFields = currentItem.guidanceContent?.isEmpty == false
                let isFormValid = hasRequiredFields ? inspectState.validateGuidanceInputs(for: currentItem) : true
                let isObserveOnly = isItemObserveOnly(currentItem)

                if !completedSteps.contains(currentItem.id) {
                    // Step not completed - show action button (disabled during processing)
                    let buttonText = currentItem.actionButtonText ?? inspectState.config?.button1Text ?? getDefaultButtonText(for: stepType)

                    Button(buttonText) {
                        handleStepAction(item: currentItem, stepType: stepType)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(getConfigurableHighlightColor())
                    .controlSize(.large)
                    .disabled(!isFormValid || isObserveOnly || shouldBlockNavigation || isProcessing)
                } else if !allStepsComplete {
                    // Step completed - show Continue to next step (blocked if any step is processing)
                    Button(inspectState.config?.button1Text ??
                           (inspectState.buttonConfiguration.button1Text.isEmpty ? "Continue" : inspectState.buttonConfiguration.button1Text)) {
                        navigateToNextStep()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(getConfigurableHighlightColor())
                    .controlSize(.large)
                    .disabled(isObserveOnly || isProcessing)
                }
            }

            // Final continue button when all complete
            if allStepsComplete {
                let finalButtonText = inspectState.config?.finalButtonText ??
                                     inspectState.config?.button1Text ??
                                     (inspectState.buttonConfiguration.button1Text.isEmpty ? "Continue" : inspectState.buttonConfiguration.button1Text)

                Button(finalButtonText) {
                    handleFinalButtonPress(buttonText: finalButtonText)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(getConfigurableHighlightColor())
                .controlSize(.large)
                .disabled(isGlobalObserveOnly || isProcessing)
            }
        }
    }

    private func getDefaultButtonText(for stepType: String) -> String {
        switch stepType {
        case "confirmation":
            return "Confirm"
        case "processing":
            return "Start"
        case "completion":
            return "Continue"
        default:
            return "Continue"
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

    private func handleStepAction(item: InspectConfig.ItemConfig, stepType: String) {
        // Validate form inputs if this step has guidance content with interactive elements
        if item.guidanceContent?.isEmpty == false {
            let isValid = inspectState.validateGuidanceInputs(for: item)
            if !isValid {
                writeLog("Preset6: Cannot proceed - required form fields not completed", logLevel: .info)
                // Could show an alert here, but for now just log and return
                return
            }
        }

        switch stepType {
        case "processing":
            startProcessing(for: item)
        case "confirmation":
            handleStepCompletion(item: item)
            // Auto-advance after a brief delay for confirmation steps
            // IMPORTANT: Use cancellable work item to prevent race with external navigation
            autoNavigationWorkItem?.cancel()
            let workItem = DispatchWorkItem {
                if self.currentStep < self.inspectState.items.count - 1 {
                    self.navigateToNextStep()
                }
            }
            autoNavigationWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        default:
            handleStepCompletion(item: item)
        }
    }

    /// Auto-start processing when navigating to a step without an action button
    private func autoStartProcessingIfNeeded(for stepIndex: Int) {
        guard stepIndex < inspectState.items.count else { return }
        let item = inspectState.items[stepIndex]

        // Only auto-start if:
        // 1. Step is a processing step
        // 2. Step has no actionButtonText (meaning it should auto-start)
        // 3. Step is not already completed
        // 4. Not currently processing
        // 5. Form inputs are valid (if step has required fields)
        guard (item.stepType ?? "info") == "processing",
              item.actionButtonText == nil,
              !completedSteps.contains(item.id),
              !processingState.isActive else {
            return
        }

        // Validate form inputs before auto-starting (if step has guidance content with fields)
        if item.guidanceContent?.isEmpty == false {
            let isFormValid = inspectState.validateGuidanceInputs(for: item)
            if !isFormValid {
                writeLog("Preset6: Cannot auto-start '\(item.id)' - required form fields not completed", logLevel: .info)
                return
            }
        }

        // Check for ambiguous configuration and log warning
        let hasWaitForTrigger = item.waitForExternalTrigger == true
        let isProgressiveMode = (item.processingMode ?? "simple") == "progressive"

        if isProgressiveMode && !hasWaitForTrigger {
            writeLog("⚠️  WARNING: Step '\(item.id)' has processingMode='progressive' but no actionButtonText and waitForExternalTrigger is not set.", logLevel: .error)
            writeLog("    This step may auto-complete instead of waiting for external triggers.", logLevel: .error)
            writeLog("    Recommended: Add \"waitForExternalTrigger\": true to config.", logLevel: .error)
        }

        writeLog("Preset6: Auto-starting processing for step '\(item.id)' (no action button, waitForTrigger: \(hasWaitForTrigger))", logLevel: .info)
        startProcessing(for: item)
    }

    private func startProcessing(for item: InspectConfig.ItemConfig) {
        guard let duration = item.processingDuration, duration > 0 else {
            // No duration specified, just complete immediately
            handleStepCompletion(item: item)
            return
        }

        // Initialize state machine with countdown
        processingCountdown = duration  // Keep for now (legacy sync)
        processingState = .countdown(stepId: item.id, remaining: duration, waitElapsed: 0)
        // isProcessing is now derived from processingState.isActive

        // Start plist monitoring immediately when processing begin
        startPlistMonitoring(for: item)

        processingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            DispatchQueue.main.async {
                // Update state machine countdown
                if case .countdown(let stepId, let remaining, let elapsed) = self.processingState, remaining > 0 {
                    // Determine processing mode - Check waitForExternalTrigger FIRST
                    let waitForTrigger = item.waitForExternalTrigger == true
                    let mode = item.processingMode ?? "simple"

                    // If waitForExternalTrigger is true, force progressive mode behavior
                    let shouldWaitForTrigger = waitForTrigger || (mode == "progressive")

                    // Check if we should transition early (simple mode at 1 second)
                    if !shouldWaitForTrigger && remaining == 1 {
                        // SIMPLE MODE: Transition at "1" to avoid showing "0" with spinner
                        timer.invalidate()
                        self.processingTimer = nil
                        self.processingCountdown = 0

                        // Check if autoResult is set to force success or failure (for banner demos)
                        let autoResult = item.autoResult ?? "success"

                        if autoResult == "failure" {
                            // Auto-fail for failure banner demos
                            let failureMsg = item.failureMessage ?? "Operation failed"
                            self.processingState = .completed(stepId: item.id, result: .failure(message: failureMsg))
                            self.failedSteps[item.id] = failureMsg
                            self.completedSteps.insert(item.id)
                            writeLog("Preset6: Simple mode - auto-failed \(item.id)", logLevel: .info)
                        } else {
                            // Auto-succeed (default behavior)
                            self.processingState = .idle
                            self.handleStepCompletion(item: item)
                            writeLog("Preset6: Simple mode - auto-completed \(item.id)", logLevel: .info)
                        }

                        // Auto-advance if enabled (default: false to not overcomplicate)
                        if item.autoAdvance ?? false {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if self.currentStep < self.inspectState.items.count - 1 {
                                    self.navigateToNextStep()
                                }
                            }
                        }
                    } else {
                        // Continue countdown
                        self.processingCountdown = remaining - 1  // Keep for now (legacy sync)
                        self.processingState = .countdown(stepId: stepId, remaining: remaining - 1, waitElapsed: elapsed + 1)
                    }
                } else {
                    // Countdown hit 0 - happens in progressive mode OR when waitForExternalTrigger=true
                    timer.invalidate()
                    self.processingTimer = nil
                    self.processingCountdown = 0

                    // PROGRESSIVE MODE / WAIT MODE: Wait for external trigger with progressive override
                    self.processingState = .waiting(stepId: item.id, waitElapsed: 0)

                    let modeDesc = item.waitForExternalTrigger == true ? "waitForExternalTrigger" : "progressive mode"
                    writeLog("Preset6: \(modeDesc) - waiting for external trigger for \(item.id)", logLevel: .info)
                    print("[PRESET6_PROCESSING] Countdown complete, waiting for external success/failure trigger")

                    // Write countdown_complete event to interaction log (for script synchronization)
                    self.writeInteractionLog("countdown_complete", step: item.id)

                    // Start state timer for wait elapsed tracking and progressive override
                    self.startStateTimer()
                    // Note: plist monitoring already started at beginning of processing (line 1112)
                }
            }
        }

        logPreset6Event("processing_started", details: [
            "stepId": item.id,
            "duration": duration,
            "mode": item.processingMode ?? "simple"
        ])
    }

    // MARK: - State Machine Timer (Unified)

    /// Start unified timer that increments processingState.waitElapsed
    /// Override level is automatically computed from waitElapsed via currentOverrideLevel
    private func startStateTimer() {
        stateTimer?.invalidate()

        stateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                // Increment wait elapsed time in current state
                self.processingState = self.processingState.incrementingWait()

                // Log override level transitions (updated timing: 2025-11-07)
                let level = self.currentOverrideLevel
                if case .warning = level, self.processingState.waitElapsed == 10 {
                    writeLog("Preset6: Warning level reached (10s)", logLevel: .info)
                } else if case .small = level, self.processingState.waitElapsed == 15 {
                    writeLog("Preset6: Small override available (15s) - NEW TIMING", logLevel: .info)
                } else if case .large = level, self.processingState.waitElapsed == 60 {
                    writeLog("Preset6: Large override available (60s)", logLevel: .info)
                }
            }
        }

        writeLog("Preset6: State timer started for \(processingState.stepId ?? "unknown")", logLevel: .info)
    }

    private func stopStateTimer() {
        stateTimer?.invalidate()
        stateTimer = nil
        writeLog("Preset6: State timer stopped", logLevel: .info)
    }

    /// Stops all active timers and resets associated state
    /// This is the centralized method for timer cleanup
    private func stopAllTimers() {
        // Stop state timer (unified timer for state machine)
        stateTimer?.invalidate()
        stateTimer = nil

        // Stop legacy processing timer
        processingTimer?.invalidate()
        processingTimer = nil

        // Stop legacy external monitoring timer
        externalMonitoringTimer?.invalidate()
        externalMonitoringTimer = nil

        // Stop file monitor dispatch source (Phase 2)
        fileMonitorSource?.cancel()
        fileMonitorSource = nil

        // Stop all plist monitoring -> now handled by InspectState)
        inspectState.stopAllPlistMonitors()

        writeLog("Preset6: All timers and monitors stopped", logLevel: .info)
    }

    // MARK: - Plist Monitoring

    /// Start plist monitoring for an item if configured
    /// Start plist monitoring using InspectState's generalized monitoring
    private func startPlistMonitoring(for item: InspectConfig.ItemConfig) {
        guard let recheckInterval = item.plistRecheckInterval, recheckInterval > 0 else {
            return
        }

        // Use InspectState's generalized monitoring with preset6-specific callback
        inspectState.startPlistMonitoring(
            itemId: item.id,
            item: item,
            recheckInterval: recheckInterval
        ) { initialValue, currentValue in
            // Preset6-specific auto-trigger behavior
            self.handlePlistValueChanged(for: item, from: initialValue, to: currentValue)
        }
    }

    /// Handle plist value change with preset6-specific auto-trigger logic 
    private func handlePlistValueChanged(for item: InspectConfig.ItemConfig, from initialValue: String, to currentValue: String) {
        writeLog("Preset6: Plist value changed for \(item.id): \(initialValue) → \(currentValue)", logLevel: .info)
        logPreset6Event("plist_changed", details: ["stepId": item.id, "oldValue": initialValue, "newValue": currentValue])

        // Write event to interaction log
        writeInteractionLog("plist_change_detected", step: item.id)

        // Auto-trigger success (Preset6-specific behavior)
        let successMsg = item.successMessage ?? "✓ Value changed to \(currentValue)"
        processingState = .completed(stepId: item.id, result: .success(message: successMsg))

        // Mark step as completed
        withAnimation(.spring()) {
            completedSteps.insert(item.id)
            inspectState.completedItems.insert(item.id)
            failedSteps.removeValue(forKey: item.id)
        }

        // Show Continue button after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + (item.processingDuration.map(Double.init) ?? 1.0)) {
            self.dynamicState.setContinueButtonVisible(stepId: item.id, visible: true)
        }
    }

    private func handleOverrideAction(action: OverrideDialogView.OverrideAction, stepId: String) {
        writeLog("Preset6: Override action \(action) for step \(stepId)", logLevel: .info)

        // Stop wait timer
        stopStateTimer()

        // Stop processing state (transition to idle)
        processingState = .idle
        processingTimer?.invalidate()
        processingTimer = nil

        switch action {
        case .success:
            // Mark step as successful
            withAnimation(.spring()) {
                completedSteps.insert(stepId)
                inspectState.completedItems.insert(stepId)
                failedSteps.removeValue(forKey: stepId)
            }
            writeInteractionLog("override_success", step: stepId)
            logPreset6Event("override_action", details: ["stepId": stepId, "action": "success"])
            checkForCompletion()

        case .failure:
            // Mark step as failed but completed so workflow can continue
            withAnimation(.spring()) {
                completedSteps.insert(stepId)
                inspectState.completedItems.insert(stepId)
                failedSteps[stepId] = "Manually marked as failed via override"
            }
            writeInteractionLog("override_failure", step: stepId)
            logPreset6Event("override_action", details: ["stepId": stepId, "action": "failure"])
            checkForCompletion()

        case .skip:
            // Skip to next step - mark as completed so workflow can finish
            withAnimation(.spring()) {
                completedSteps.insert(stepId)
                inspectState.completedItems.insert(stepId)
                // Don't add to failedSteps - it was skipped, not failed
            }
            writeInteractionLog("override_skip", step: stepId)
            logPreset6Event("override_action", details: ["stepId": stepId, "action": "skip"])
            navigateToNextStep()
            checkForCompletion()

        case .cancel:
            // User cancelled - restart wait timer
            writeInteractionLog("override_cancel", step: stepId)
            logPreset6Event("override_action", details: ["stepId": stepId, "action": "cancel"])
            // Restart processing state and timer (reset waitElapsed to 0)
            processingState = .waiting(stepId: stepId, waitElapsed: 0)  // isProcessing derived from this
            startStateTimer()
        }
    }

    private func buttonTitle(allComplete: Bool, currentComplete: Bool) -> String {
        if allComplete {
            return "Continue"
        } else if currentComplete && currentStep < inspectState.items.count - 1 {
            return "Next"
        } else {
            return inspectState.buttonConfiguration.button1Text
        }
    }

    private func handleStepClick(item: InspectConfig.ItemConfig, index: Int) {
        // Only allow clicking on completed steps or current step
        if completedSteps.contains(item.id) || index == currentStep {
            logUserInteraction("step_clicked", stepId: item.id, details: [
                "clickedIndex": index,
                "currentIndex": currentStep,
                "wasCompleted": completedSteps.contains(item.id)
            ])
            
            let oldStep = currentStep
            withAnimation(.spring()) {
                currentStep = index
            }
            logStepTransition(from: oldStep, to: index, reason: "user_clicked")
            writeInteractionLog("navigate", step: item.id)
        } else {
            logUserInteraction("step_click_blocked", stepId: item.id, details: [
                "clickedIndex": index,
                "currentIndex": currentStep,
                "reason": "step_not_accessible"
            ])
        }
    }

    private func handleStepCompletion(item: InspectConfig.ItemConfig) {
        // Mark current step as completed
        logUserInteraction("complete_step", stepId: item.id, details: [
            "stepIndex": currentStep,
            "previouslyCompleted": completedSteps.contains(item.id)
        ])

        // Write form selections to log if this step had guidance content
        if item.guidanceContent?.isEmpty == false {
            inspectState.writeGuidanceSelectionsToLog()
        }

        withAnimation(.spring()) {
            completedSteps.insert(item.id)
            inspectState.completedItems.insert(item.id)
            writeInteractionLog("completed_step", step: item.id)
            savePersistedState()
            checkForCompletion()
        }

        logPreset6Event("step_completed", details: [
            "stepId": item.id,
            "stepIndex": currentStep,
            "totalCompleted": completedSteps.count,
            "progressPercentage": Double(completedSteps.count) / Double(inspectState.items.count) * 100.0
        ])
    }

    private func navigateToNextStep() {
        guard currentStep < inspectState.items.count - 1 else { 
            logUserInteraction("navigate_next_blocked", details: ["reason": "already_at_last_step"])
            return 
        }

        let oldStep = currentStep
        withAnimation(.spring()) {
            currentStep += 1
        }
        
        logStepTransition(from: oldStep, to: currentStep, reason: "navigation_next")
        logUserInteraction("navigate_next", details: ["newStepIndex": currentStep])
        writeInteractionLog("navigate_next", step: "step_\(currentStep)")
    }

    private func navigateToPreviousStep() {
        guard currentStep > 0 else { 
            logUserInteraction("navigate_back_blocked", details: ["reason": "already_at_first_step"])
            return 
        }

        let oldStep = currentStep
        withAnimation(.spring()) {
            currentStep -= 1
        }
        
        logStepTransition(from: oldStep, to: currentStep, reason: "navigation_back")
        logUserInteraction("navigate_back", details: ["newStepIndex": currentStep])
        writeInteractionLog("navigate_previous", step: "step_\(currentStep)")
    }

    private func checkForCompletion() {
        let allComplete = inspectState.items.allSatisfy { completedSteps.contains($0.id) }

        if allComplete {
            logPreset6Event("all_steps_completed", details: [
                "totalSteps": inspectState.items.count,
                "completionTime": Date().timeIntervalSince1970
            ])
            writeInteractionLog("completed", step: "all_steps")
        }
    }

    private func resetSteps() {
        logUserInteraction("reset_all_steps", details: [
            "previousCompletedCount": completedSteps.count,
            "previousCurrentStep": currentStep
        ])

        // Stop all timers and monitors FIRST to prevent interference during reload
        stopAllTimers()

        withAnimation(.spring()) {
            completedSteps.removeAll()
            currentStep = 0
            scrollOffset = 0
            inspectState.completedItems.removeAll()
        }

        // Clear all dynamic state from MVVM state manager
        dynamicState.clearAllState()

        persistenceService.clearState()

        // Clear ALL interaction logs and status files
        let filesToClear = [
            "/tmp/preset6_interaction.plist",
            "/tmp/preset6_interaction.log",
            "/tmp/preset6_trigger.txt"
        ]

        for filePath in filesToClear {
            do {
                if FileManager.default.fileExists(atPath: filePath) {
                    try FileManager.default.removeItem(atPath: filePath)
                    writeLog("Preset6: Cleared file: \(filePath)", logLevel: .debug)
                }
            } catch {
                writeLog("Preset6: Failed to clear \(filePath): \(error)", logLevel: .error)
            }
        }

        // Write reset log AFTER clearing (so it's a fresh start)
        writeInteractionLog("reset", step: "all")

        logPreset6Event("steps_reset", details: [
            "reason": "user_requested",
            "resetTime": Date().timeIntervalSince1970
        ])

        // Reload all plist/defaults data for fresh state
        reloadAllData()
    }

    /// Reload all plist and UserDefaults data after reset
    /// This ensures UI components display current values from disk
    private func reloadAllData() {
        writeLog("Preset6: Reloading all plist/defaults data after reset...", logLevel: .info)

        // Stop existing monitors to prevent stale data
        inspectState.stopAllPlistMonitors()

        // Restart plist monitors with fresh data
        setupPlistMonitors()

        // Force immediate recheck of all monitors to populate UI
        inspectState.recheckAllPlistMonitors { itemId, blockIndex, property, newValue in
            // Update guidance components with fresh values
            self.dynamicState.updateGuidanceProperty(
                stepId: itemId,
                blockIndex: blockIndex,
                property: property,
                value: newValue
            )
        }

        // Restart file monitoring for external triggers
        setupFileMonitoring()

        writeLog("Preset6: Data reload complete - monitors restarted and values refreshed", logLevel: .info)
        logPreset6Event("data_reloaded", details: [
            "itemsCount": inspectState.items.count
        ])
    }

    private func handleManualReset(source: String) {
        // Show visual feedback based on source
        if source == "left_stepper" {
            showResetFeedbackLeft = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showResetFeedbackLeft = false
            }
        } else if source == "banner_stepper" {
            showResetFeedbackBanner = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showResetFeedbackBanner = false
            }
        }

        // Log the reset source
        logUserInteraction("manual_reset", details: [
            "source": source,
            "method": "option_click"
        ])

        // Perform the reset after a brief delay to show visual feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.resetSteps()
        }
    }

    private func handleExtraButtonAction(_ buttonConfig: InspectConfig.ExtraButtonConfig) {
        switch buttonConfig.action {
        case "reset":
            resetSteps()
        case "url":
            if let urlString = buttonConfig.url, let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
                logUserInteraction("extra_button_url", details: ["url": urlString])
            }
        case "custom":
            // Write to interaction log for external script monitoring
            writeToInteractionLog("extra_button:\(buttonConfig.text)")
            logUserInteraction("extra_button_custom", details: ["text": buttonConfig.text])
            writeLog("Preset6: Custom extra button action triggered: \(buttonConfig.text)", logLevel: .info)
        default:
            writeLog("Preset6: Unknown extra button action: \(buttonConfig.action)", logLevel: .error)
        }
    }

    /// Handle final button press with safe callback mechanisms
    /// Writes trigger file, updates plist, logs event, then exits
    private func handleFinalButtonPress(buttonText: String) {
        writeLog("Preset6: User clicked final button (\(buttonText)) - all steps complete", logLevel: .info)

        // 1. Write to interaction log for script monitoring
        writeToInteractionLog("final_button:clicked:\(buttonText)")

        // 2. Create trigger file (touch equivalent)
        let triggerPath = "/tmp/preset6_final_button.trigger"
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let triggerContent = "button_text=\(buttonText)\ntimestamp=\(timestamp)\nstatus=completed\n"

        if let data = triggerContent.data(using: .utf8) {
            try? data.write(to: URL(fileURLWithPath: triggerPath), options: .atomic)
            writeLog("Preset6: Created trigger file at \(triggerPath)", logLevel: .debug)
        }

        // 3. Write to plist for structured data access
        let plistPath = "/tmp/preset6_interaction.plist"
        let plistData: [String: Any] = [
            "finalButtonPressed": true,
            "buttonText": buttonText,
            "timestamp": timestamp,
            "completedSteps": Array(completedSteps),
            "failedSteps": failedSteps.keys.map { $0 }
        ]

        if let data = try? PropertyListSerialization.data(fromPropertyList: plistData, format: .xml, options: 0) {
            try? data.write(to: URL(fileURLWithPath: plistPath), options: .atomic)
            writeLog("Preset6: Updated interaction plist at \(plistPath)", logLevel: .debug)
        }

        // 4. Log user interaction for analytics
        logUserInteraction("final_button", details: [
            "buttonText": buttonText,
            "completedCount": "\(completedSteps.count)",
            "failedCount": "\(failedSteps.count)"
        ])

        // 5. Small delay to ensure file operations complete
        usleep(100000) // 100ms

        // 6. Exit with success code
        writeLog("Preset6: Exiting with code 0", logLevel: .info)
        exit(0)
    }

    // MARK: - Banner Support

    private func cacheBannerImage() {
        guard let bannerImagePath = inspectState.uiConfiguration.bannerImage,
              !bannerImagePath.isEmpty else {
            writeLog("Preset6: No banner image configured", logLevel: .debug)
            return
        }
        
        writeLog("Preset6: Caching banner image from path: \(bannerImagePath)", logLevel: .info)
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Check if it's a color specification
            if bannerImagePath.range(of: "colo[u]?r=", options: .regularExpression) != nil {
                writeLog("Preset6: Banner is a color specification", logLevel: .debug)
                return
            }
            
            // Handle different path types
            let fullPath: String
            if bannerImagePath.hasPrefix("/") {
                // Absolute path
                fullPath = bannerImagePath
            } else if let basePath = self.inspectState.uiConfiguration.iconBasePath {
                // Relative to base path
                fullPath = "\(basePath)/\(bannerImagePath)"
            } else {
                // Try relative to current directory
                fullPath = bannerImagePath
            }
            
            if let image = NSImage(contentsOfFile: fullPath) {
                DispatchQueue.main.async {
                    self.cachedBannerImage = image
                    self.bannerImageLoaded = true
                    writeLog("Preset6: Banner image cached successfully from: \(fullPath)", logLevel: .info)
                }
            } else {
                writeLog("Preset6: Failed to load banner image from: \(fullPath)", logLevel: .error)
            }
        }
    }

    // MARK: - Enhanced Logging

    private func logPreset6Event(_ event: String, details: [String: Any] = [:]) {
        var logDetails = details
        logDetails["preset"] = "6"
        logDetails["currentStep"] = currentStep
        logDetails["totalSteps"] = inspectState.items.count
        logDetails["completedSteps"] = completedSteps.count
        
        let detailsString = logDetails.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        writeLog("Preset6: \(event) - \(detailsString)", logLevel: .info)
        
        // Also write to console for external monitoring
        print("[PRESET6_EVENT] \(event) \(detailsString)")
    }

    private func logStepTransition(from oldStep: Int, to newStep: Int, reason: String) {
        logPreset6Event("step_transition", details: [
            "from": oldStep,
            "to": newStep,
            "reason": reason,
            "stepId": inspectState.items.indices.contains(newStep) ? inspectState.items[newStep].id : "unknown"
        ])
    }

    private func logUserInteraction(_ action: String, stepId: String? = nil, details: [String: Any] = [:]) {
        var logDetails = details
        logDetails["action"] = action
        if let stepId = stepId {
            logDetails["stepId"] = stepId
        }

        logPreset6Event("user_interaction", details: logDetails)
    }

    /// Write a simple interaction log entry to /tmp/preset6_interaction.log
    /// Used for real-time form element callbacks (sliders, toggles, extra button)
    private func writeToInteractionLog(_ message: String) {
        let logPath = "/tmp/preset6_interaction.log"
        let logEntry = "\(message)\n"

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

    // MARK: - External Monitoring

    private func setupExternalMonitoring() {
        externalMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            DispatchQueue.main.async {
                checkForExternalTrigger()
            }
        }
    }

    /// Process a single preset command from /tmp/preset6_trigger.txt
    /// Command format examples:
    /// - "update_guidance:step1:0:New text"
    /// - "success:install_app"
    /// - "progress:deploy:75"
    private func processPresetCommand(_ trimmedLine: String) {
        // This is the unified command processing logic extracted from checkForExternalTrigger()

        if trimmedLine.hasPrefix("complete:") {
            let stepId = String(trimmedLine.dropFirst(9))
            if !completedSteps.contains(stepId) {
                if inspectState.items.contains(where: { $0.id == stepId }) {
                    withAnimation(.spring()) {
                        completedSteps.insert(stepId)
                        inspectState.completedItems.insert(stepId)
                        writeInteractionLog("auto_completed", step: stepId)
                        checkForCompletion()
                    }
                }
            }
        } else if trimmedLine.hasPrefix("success:") {
            // Option 3 - Hybrid: Mark step as successfully completed
            // Extract message (format: "success:stepId:optional_message")
            let parts = trimmedLine.dropFirst(8).split(separator: ":", maxSplits: 1)
            let stepId = String(parts[0])
            let message = parts.count > 1 ? String(parts[1]) : nil
            handleCompletionTrigger(stepId: stepId, result: .success(message: message))
        } else if trimmedLine.hasPrefix("failure:") {
            // Option 3 - Hybrid: Mark step as failed with optional reason
            // Extract reason (format: "failure:stepId:optional_reason")
            let parts = trimmedLine.dropFirst(8).split(separator: ":", maxSplits: 1)
            let stepId = String(parts[0])
            let reason = parts.count > 1 ? String(parts[1]) : "Step failed"
            handleCompletionTrigger(stepId: stepId, result: .failure(message: reason))
        } else if trimmedLine == "reset" {
            resetSteps()
        } else if trimmedLine.hasPrefix("navigate:") {
            let stepIndexString = String(trimmedLine.dropFirst(9)).trimmingCharacters(in: .whitespaces)
            let stepIndex = Int(stepIndexString) ?? 0
            if stepIndex >= 0 && stepIndex < inspectState.items.count {
                // CRITICAL: Cancel any pending auto-navigation BEFORE changing step
                // This prevents race condition where external navigate happens while auto-nav timer is pending
                autoNavigationWorkItem?.cancel()
                autoNavigationWorkItem = nil
                writeLog("Preset6: Cancelled pending auto-navigation due to external navigate command", logLevel: .debug)

                withAnimation(.spring()) {
                    currentStep = stepIndex
                }
                writeInteractionLog("external_navigate", step: "step_\(stepIndex)")
            }
        } else if trimmedLine.hasPrefix("listitem:") {
            // NEW: Update list item status icon
            // Format: listitem: index: X, status: Y
            // Examples:
            //   listitem: index: 0, status: shield.fill-green
            //   listitem: index: 1, status: checkmark.circle.fill-blue
            //   listitem: index: 2, status: xmark.circle.fill-red
            let remainder = String(trimmedLine.dropFirst(9))  // Remove "listitem:"
            let components = remainder.components(separatedBy: ",")

            var itemIndex: Int?
            var statusIcon: String?

            for component in components {
                let trimmed = component.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("index:") {
                    let indexStr = trimmed.dropFirst(6).trimmingCharacters(in: .whitespaces)
                    itemIndex = Int(indexStr)
                } else if trimmed.hasPrefix("status:") {
                    statusIcon = String(trimmed.dropFirst(7).trimmingCharacters(in: .whitespaces))
                }
            }

            if let index = itemIndex, index >= 0, index < inspectState.items.count {
                if let status = statusIcon, !status.isEmpty {
                    dynamicState.updateItemStatusIcon(index: index, icon: status)
                    logPreset6Event("listitem_status_update", details: ["index": index, "status": status])
                } else {
                    // Empty status clears the icon
                    dynamicState.updateItemStatusIcon(index: index, icon: nil)
                    logPreset6Event("listitem_status_clear", details: ["index": index])
                }
            }
        } else if trimmedLine.hasPrefix("update_message:") {
            // Phase 2: Update processing message dynamically
            // Format: update_message:stepId:new_message
            let parts = trimmedLine.dropFirst(15).split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let stepId = String(parts[0])
                let message = String(parts[1])
                dynamicState.updateMessage(stepId: stepId, message: message)
                logPreset6Event("dynamic_message_update", details: ["stepId": stepId, "message": message])
            }
        } else if trimmedLine.hasPrefix("progress:") {
            // Phase 2: Update progress percentage
            // Format: progress:stepId:percentage (0-100)
            let parts = trimmedLine.dropFirst(9).split(separator: ":")
            if parts.count == 2 {
                let stepId = String(parts[0])
                if let percentage = Int(String(parts[1])) {
                    dynamicState.updateProgress(stepId: stepId, percentage: percentage)
                    logPreset6Event("progress_update", details: ["stepId": stepId, "percentage": percentage])
                }
            }
        } else if trimmedLine.hasPrefix("display_data:") {
            // Phase 2: Add/update custom data display
            // Format: display_data:stepId:key:value[:color]
            // Split only on first 2 colons to get stepId and key, leaving value+color intact
            let parts = trimmedLine.dropFirst(13).split(separator: ":", maxSplits: 2)
            if parts.count >= 3 {
                let stepId = String(parts[0])
                let key = String(parts[1])
                let valueAndColor = String(parts[2])

                // Check if the last segment (after last ":") is a color (starts with #)
                var value = valueAndColor
                var color: String? = nil

                if let lastColonIndex = valueAndColor.lastIndex(of: ":") {
                    let potentialColor = String(valueAndColor[valueAndColor.index(after: lastColonIndex)...])
                    if potentialColor.hasPrefix("#") {
                        color = potentialColor
                        value = String(valueAndColor[..<lastColonIndex])
                    }
                }

                dynamicState.updateDisplayData(stepId: stepId, key: key, value: value, color: color)
                logPreset6Event("display_data_update", details: ["stepId": stepId, "key": key, "value": value, "color": color ?? "none"])
            }
        } else if trimmedLine.hasPrefix("update_guidance:") {
            // Phase 2/4: Update guidance content block dynamically
            // Format: update_guidance:stepId:blockIndex:new_content
            // Format: update_guidance:stepId:blockIndex:property=value
            let parts = trimmedLine.dropFirst(16).split(separator: ":", maxSplits: 2)
            if parts.count == 3 {
                let stepId = String(parts[0])
                if let blockIndex = Int(String(parts[1])) {
                    let valueString = String(parts[2])

                    // Validate stepId exists
                    let stepExists = inspectState.items.contains { $0.id == stepId }
                    if !stepExists {
                        writeLog("Preset6: Invalid stepId '\(stepId)' in update_guidance command", logLevel: .error)
                        writeAcknowledgment("update_guidance", stepId: stepId, index: blockIndex, status: "error", message: "Invalid stepId")
                        return
                    }

                    // Check if this is a property update (contains '=')
                    if valueString.contains("=") {
                        let propParts = valueString.split(separator: "=", maxSplits: 1)
                        if propParts.count == 2 {
                            let property = String(propParts[0])
                            let value = String(propParts[1])

                            dynamicState.updateGuidanceProperty(stepId: stepId, blockIndex: blockIndex, property: property, value: value)
                            logPreset6Event("guidance_property_update", details: ["stepId": stepId, "index": blockIndex, "property": property, "value": value])

                            // Bidirectional feedback
                            writeAcknowledgment("property_update", stepId: stepId, index: blockIndex, status: "success", property: property, value: value)
                        }
                    } else {
                        // Legacy content update
                        dynamicState.updateGuidanceContent(stepId: stepId, blockIndex: blockIndex, content: valueString)
                        logPreset6Event("guidance_content_update", details: ["stepId": stepId, "index": blockIndex, "content": valueString])

                        // Bidirectional feedback
                        writeAcknowledgment("content_update", stepId: stepId, index: blockIndex, status: "success")
                    }
                } else {
                    writeLog("Preset6: Invalid blockIndex in update_guidance command", logLevel: .error)
                }
            } else {
                writeLog("Preset6: Malformed update_guidance command: \(trimmedLine)", logLevel: .error)
            }
        } else if trimmedLine == "recheck:" || trimmedLine.hasPrefix("recheck:") {
            // Manual trigger for plist monitor recheck
            // Format: recheck: (recheck all) OR recheck:itemId (recheck specific item)

            let targetItemId = trimmedLine == "recheck:" ? nil : String(trimmedLine.dropFirst(8))

            if let itemId = targetItemId {
                // Recheck monitors for specific item
                inspectState.recheckPlistMonitorsForItem(itemId) { itemId, blockIndex, property, newValue in
                    // Update guidance property with the changed value
                    dynamicState.updateGuidanceProperty(
                        stepId: itemId,
                        blockIndex: blockIndex,
                        property: property,
                        value: newValue
                    )
                }
                writeLog("Preset6: Manual recheck triggered for item '\(itemId)'", logLevel: .info)
                logPreset6Event("manual_recheck", details: ["itemId": itemId])
            } else {
                // Recheck ALL monitors
                inspectState.recheckAllPlistMonitors { itemId, blockIndex, property, newValue in
                    // Update guidance property with the changed value
                    dynamicState.updateGuidanceProperty(
                        stepId: itemId,
                        blockIndex: blockIndex,
                        property: property,
                        value: newValue
                    )
                }
                writeLog("Preset6: Manual recheck triggered for ALL items", logLevel: .info)
                logPreset6Event("manual_recheck", details: ["scope": "all"])
            }
        }
    }

    /// Phase 2: Zero-latency file monitoring using DispatchSource
    /// Replaces timer-based polling (500ms latency) with instant file change detection
    private func setupFileMonitoring() {
        let triggerPath = "/tmp/preset6_trigger.txt"

        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: triggerPath) {
            FileManager.default.createFile(atPath: triggerPath, contents: nil, attributes: nil)
        }

        // Open file descriptor
        let fileDescriptor = open(triggerPath, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            writeLog("Preset6: Failed to open trigger file for monitoring", logLevel: .error)
            return
        }

        // Create dispatch source to monitor file changes
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.main
        )

        // Set event handler
        source.setEventHandler { [self] in
            checkForExternalTrigger()
        }

        // Set cancellation handler to close file descriptor
        source.setCancelHandler {
            close(fileDescriptor)
        }

        // Activate the source
        source.resume()

        // Store reference
        fileMonitorSource = source

        writeLog("Preset6: File monitoring started with DispatchSource (zero-latency)", logLevel: .info)
    }

    /// Setup automatic plist monitors for all items
    /// Monitors plist files/UserDefaults and auto-updates guidance components when values change
    private func setupPlistMonitors() {
        writeLog("Preset6: setupPlistMonitors() called with \(inspectState.items.count) items", logLevel: .info)

        for item in inspectState.items {
            if let monitors = item.plistMonitors {
                writeLog("Preset6: Item '\(item.id)' has \(monitors.count) plist monitor(s)", logLevel: .info)
            }
            guard item.plistMonitors != nil else { continue }

            // Start monitoring with callback to update guidance components
            inspectState.startMultiplePlistMonitors(
                for: item,
                onUpdate: { itemId, blockIndex, property, newValue in
                    // Update the appropriate guidance property
                    Task { @MainActor in
                        self.updateGuidanceProperty(
                            itemId: itemId,
                            blockIndex: blockIndex,
                            property: property,
                            value: newValue
                        )

                        writeLog("Preset6: Auto-updated guidance[\(itemId)][\(blockIndex)].\(property) = \(newValue)", logLevel: .info)
                    }
                },
                onComplete: { itemId, result, _ in
                    // Auto-trigger completion when plist condition met
                    Task { @MainActor in
                        writeLog("Preset6: Auto-completion triggered for '\(itemId)' via plistMonitor completionTrigger", logLevel: .info)
                        self.handleCompletionTrigger(stepId: itemId, result: result)
                    }
                }
            )
        }
    }

    /// Load plist sources to populate our compliance categories
    /// Reads plist files defined in plistSources config and aggregates into categories
    /// Used to auto-populate compliance cards with live data
    private func loadPlistSourcesIfNeeded() {
        writeLog("Preset6: loadPlistSourcesIfNeeded() called", logLevel: .info)
        writeLog("Preset6: inspectState.plistSources count: \(inspectState.plistSources?.count ?? 0)", logLevel: .info)

        guard let plistSources = inspectState.plistSources, !plistSources.isEmpty else {
            writeLog("Preset6: No plistSources configured, skipping native aggregation", logLevel: .info)
            return
        }

        writeLog("Preset6: Loading \(plistSources.count) plist source(s) for compliance cards", logLevel: .info)

        var allItems: [PlistAggregator.ComplianceItem] = []

        // Load all plist sources
        for source in plistSources {
            if let result = PlistAggregator.loadPlistSource(source: source) {
                allItems.append(contentsOf: result.items)
                writeLog("Preset6: Loaded \(result.items.count) items from \(source.displayName) (\(source.path))", logLevel: .info)
            } else {
                writeLog("Preset6: Failed to load plist source: \(source.displayName) at \(source.path)", logLevel: .error)
            }
        }

        guard !allItems.isEmpty else {
            writeLog("Preset6: No items loaded from plist sources", logLevel: .error)
            return
        }

        // Categorize items
        let categories = PlistAggregator.categorizeItems(allItems)
        self.plistCategories = categories

        writeLog("Preset6: Categorized \(allItems.count) items into \(categories.count) categories", logLevel: .info)

        // Log category summary
        for category in categories {
            writeLog("Preset6: Category '\(category.name)': \(category.passed)/\(category.total) passed (\(Int(category.score * 100))%)", logLevel: .info)
        }
    }

    /// Update a specific property on a guidance component
    /// Called by plist monitors to auto-update status badges, comparison tables, etc.
    private func updateGuidanceProperty(itemId: String, blockIndex: Int, property: String, value: String) {
        // Use withAnimation to ensure SwiftUI detects the change
        withAnimation(.easeInOut(duration: 0.3)) {
            dynamicState.updateGuidanceProperty(stepId: itemId, blockIndex: blockIndex, property: property, value: value)
        }

        // Log the update
        logPreset6Event("plist_monitor_update", details: [
            "itemId": itemId,
            "blockIndex": blockIndex,
            "property": property,
            "value": value
        ])
    }

    /// Unified handler for step completion triggers (success/failure)
    /// Eliminates duplicate code and ensures consistent state management
    private func handleCompletionTrigger(stepId: String, result: CompletionResult) {
        guard inspectState.items.contains(where: { $0.id == stepId }) else {
            writeLog("Preset6: Cannot handle completion for unknown step: \(stepId)", logLevel: .error)
            return
        }

        withAnimation(.spring()) {
            // ALWAYS stop ALL timers (even if already completed)
            // This ensures UI transitions properly regardless of timing and prevents race conditions
            stopAllTimers()
            processingState = .idle  // Transition to idle (isProcessing derived from this)

            let wasAlreadyCompleted = completedSteps.contains(stepId)

            // Mark as completed if not already done
            if !wasAlreadyCompleted {
                completedSteps.insert(stepId)
                inspectState.completedItems.insert(stepId)
            }

            // Handle result-specific logic
            switch result {
            case .success(let message):
                // Remove from failed steps if it was there
                failedSteps.removeValue(forKey: stepId)

                // Log the event
                if wasAlreadyCompleted {
                    writeInteractionLog("override_success", step: stepId)
                } else {
                    writeInteractionLog("auto_success", step: stepId)
                }

                logPreset6Event("external_trigger_success", details: [
                    "stepId": stepId,
                    "message": message ?? "No message",
                    "wasOverride": wasAlreadyCompleted
                ])

            case .failure(let message):
                // Mark with failure state
                failedSteps[stepId] = message ?? "Step failed"

                // Log the event
                if wasAlreadyCompleted {
                    writeInteractionLog("override_failure", step: stepId)
                } else {
                    writeInteractionLog("auto_failure", step: stepId)
                }

                logPreset6Event("external_trigger_failure", details: [
                    "stepId": stepId,
                    "reason": message ?? "No reason",
                    "wasOverride": wasAlreadyCompleted
                ])

            case .cancelled:
                // Handle cancellation (not currently used in triggers, but available for future)
                writeInteractionLog("cancelled", step: stepId)
                logPreset6Event("external_trigger_cancelled", details: ["stepId": stepId])
            }

            checkForCompletion()
        }
    }

    /// Phase 2: Legacy file monitoring for backward compatibility
    /// Now refactored to use unified command processing via processPresetCommand()
    private func checkForExternalTrigger() {
        // Early exit if view state is invalid (prevents crashes during teardown)
        guard !inspectState.items.isEmpty else {
            return
        }

        let triggerPath = "/tmp/preset6_trigger.txt"

        guard FileManager.default.fileExists(atPath: triggerPath) else {
            return
        }

        guard let content = try? String(contentsOfFile: triggerPath, encoding: .utf8) else {
            return
        }

        if appvars.debugMode {
            writeLog("Preset6: Found legacy trigger file with content: \(content)", logLevel: .debug)
        }
        print("[PRESET6_TRIGGER] Processing: \(content.replacingOccurrences(of: "\n", with: " "))")

        // Truncate instead of delete so DispatchSource file descriptor stays valid
        try? "".write(toFile: triggerPath, atomically: false, encoding: .utf8)

        // Process each line using unified command processor
        let lines = content.split(separator: "\n")
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedLine.isEmpty {
                processPresetCommand(trimmedLine)
            }
        }
    }

    private func writeInteractionLog(_ event: String, step: String) {
        writeInteractionLog(event, step: step, data: [:])
    }

    // Overload with additional data parameter - this might be too hacky
    private func writeInteractionLog(_ event: String, step: String, data: [String: Any]) {
        print("[PRESET6_INTERACTION] event=\(event) step=\(step) current=\(currentStep) completed=\(completedSteps.count)")

        let plistPath = "/tmp/preset6_interaction.plist"
        var interaction: [String: Any] = [
            "timestamp": Date(),
            "event": event,
            "step": step,
            "currentStep": currentStep,
            "completedSteps": Array(completedSteps),
            "completedCount": completedSteps.count
        ]

        // Merge additional data
        interaction.merge(data) { (_, new) in new }

        if let plistData = try? PropertyListSerialization.data(fromPropertyList: interaction,
                                                               format: .xml,
                                                               options: 0) {
            try? plistData.write(to: URL(fileURLWithPath: plistPath), options: .atomic)
        }

        let logPath = "/tmp/preset6_interaction.log"
        let timestamp = ISO8601DateFormatter().string(from: Date())

        // Include additional data in log entry
        var extraFields = ""
        for (key, value) in data {
            extraFields += " \(key)=\(value)"
        }

        let logEntry = "\(timestamp) event=\(event) step=\(step) current=\(currentStep) completed=\(Array(completedSteps).joined(separator: ","))\(extraFields)\n"

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

    // MARK: - Bidirectional Feedback

    private func writeAcknowledgment(_ command: String, stepId: String, index: Int, status: String, property: String? = nil, value: String? = nil, message: String? = nil) {
        let ackPath = "/var/tmp/dialog-ack.log"
        let timestamp = ISO8601DateFormatter().string(from: Date())

        var ackEntry = "\(timestamp) command=\(command) stepId=\(stepId) index=\(index) status=\(status)"
        if let property = property {
            ackEntry += " property=\(property)"
        }
        if let value = value {
            ackEntry += " value=\(value)"
        }
        if let message = message {
            ackEntry += " message=\(message)"
        }
        ackEntry += "\n"

        if let data = ackEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: ackPath) {
                if let fileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: ackPath)) {
                    _ = try? fileHandle.seekToEnd()
                    _ = try? fileHandle.write(contentsOf: data)
                    try? fileHandle.close()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: ackPath))
            }
        }
    }

    // MARK: - State Persistence

    private func savePersistedState() {
        let state = Preset6State(
            completedSteps: completedSteps,
            currentStep: currentStep,
            scrollOffset: scrollOffset,
            guidanceFormInputs: inspectState.guidanceFormInputs,  // Save form inputs
            timestamp: Date()
        )
        persistenceService.saveState(state)
        writeLog("Preset6: State saved - \(completedSteps.count) steps completed, \(inspectState.guidanceFormInputs.count) form states", logLevel: .debug)
    }

    private func loadPersistedState() {
        let persistPath = ProcessInfo.processInfo.environment["DIALOG_PERSIST_PATH"] ?? "default"
        writeLog("Preset6: DIALOG_PERSIST_PATH=\(persistPath)", logLevel: .info)

        guard let state = persistenceService.loadState() else {
            writeLog("Preset6: No previous state found", logLevel: .debug)
            currentStep = 0
            writeInteractionLog("launched", step: "preset6")
            return
        }

        // Check if state is stale (>24 hours old)
        if persistenceService.isStateStale(state, hours: 24) {
            writeLog("Preset6: State is stale, starting fresh", logLevel: .info)
            currentStep = 0
            writeInteractionLog("launched", step: "preset6")
            return
        }

        writeLog("Preset6: Loaded state - completed: \(state.completedSteps), saved step: \(state.currentStep)", logLevel: .info)

        completedSteps = state.completedSteps
        inspectState.completedItems = completedSteps
        scrollOffset = state.scrollOffset

        // Restore form inputs (checkboxes, dropdowns, radios)
        inspectState.guidanceFormInputs = state.guidanceFormInputs
        writeLog("Preset6: Restored \(state.guidanceFormInputs.count) form states", logLevel: .info)

        if !inspectState.items.isEmpty {
            if let firstIncompleteIndex = inspectState.items.firstIndex(where: { !completedSteps.contains($0.id) }) {
                currentStep = firstIncompleteIndex
                writeLog("Preset6: Set currentStep=\(firstIncompleteIndex) (first incomplete)", logLevel: .info)
            } else {
                currentStep = inspectState.items.count - 1
                writeLog("Preset6: All steps completed, set to last item: \(currentStep)", logLevel: .info)
            }
        } else {
            currentStep = 0
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        writeLog("Preset6: Resumed from \(formatter.string(from: state.timestamp)) - \(completedSteps.count) steps complete", logLevel: .info)

        writeInteractionLog("resumed", step: "state_loaded")
        writeInteractionLog("launched", step: "preset6")
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

    private func getStepCounterText() -> String {
        let format = inspectState.config?.uiLabels?.stepCounterFormat ?? "Step {current} of {total}"
        return format
            .replacingOccurrences(of: "{current}", with: "\(currentStep + 1)")
            .replacingOccurrences(of: "{total}", with: "\(inspectState.items.count)")
    }
}

// MARK: - Guidance Content View
// NOTE: GuidanceContentView is now defined in PresetCommonHelpers.swift
// and is shared across all presets for consistency

// MARK: - Minimal Progress Dot Component

struct MinimalProgressDot: View {
    let index: Int
    let item: InspectConfig.ItemConfig
    let isCompleted: Bool
    let isDownloading: Bool
    let isActive: Bool
    let scaleFactor: CGFloat
    let highlightColor: String
    let statusIcon: String?  // NEW: Optional dynamic status icon (overrides default indicators)

    var body: some View {
        HStack(spacing: 12 * scaleFactor) {
            // Optimized dot indicator - 28px for better density
            ZStack {
                // Background circle (only show if not using custom status icon)
                if statusIcon == nil {
                    Circle()
                        .fill(dotBackgroundColor)
                        .frame(width: 28 * scaleFactor, height: 28 * scaleFactor)
                        .shadow(color: dotBackgroundColor.opacity(0.2), radius: 2, x: 0, y: 1)
                }

                // Priority: status icon > completed > downloading > number
                if let status = statusIcon {
                    // NEW: Custom status icon (supports dynamic updates)
                    ListItemStatusIconView(
                        status: status,
                        size: 28 * scaleFactor,
                        defaultIcon: nil
                    )
                } else if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16 * scaleFactor, weight: .bold))
                        .foregroundColor(.white)
                } else if isDownloading {
                    // Show spinner for downloading/in-progress items
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16 * scaleFactor, height: 16 * scaleFactor)
                } else {
                    // Clear step numbering
                    Text("\(index + 1)")
                        .font(.system(size: 14 * scaleFactor, weight: .bold, design: .rounded))
                        .foregroundColor(isActive ? .white : .primary)
                        .monospacedDigit()
                }
            }
            .animation(.easeInOut(duration: 0.2), value: statusIcon)
            .animation(.easeInOut(duration: 0.2), value: isCompleted)
            .animation(.easeInOut(duration: 0.2), value: isDownloading)
            .animation(.easeInOut(duration: 0.2), value: isActive)
            
            // Readable text
            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                    .font(.system(size: 13 * scaleFactor, weight: isActive ? .medium : .regular))
                    .foregroundColor(isActive ? .primary : .secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11 * scaleFactor))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6 * scaleFactor)
        .padding(.horizontal, 8 * scaleFactor)
        .background(
            RoundedRectangle(cornerRadius: 8 * scaleFactor)
                .fill(isActive ? Color(hex: highlightColor).opacity(0.08) : Color.clear)
        )
        .scaleEffect(isActive ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
    }

    private var dotBackgroundColor: Color {
        if isCompleted {
            return .green
        } else if isDownloading {
            return .orange
        } else if isActive {
            return Color(hex: highlightColor)
        } else {
            return Color.secondary.opacity(0.3)
        }
    }
}

// MARK: - Override Dialog View

struct OverrideDialogView: View {
    @Binding var isPresented: Bool
    let stepId: String
    let cancelButtonText: String
    let onAction: (OverrideAction) -> Void

    enum OverrideAction {
        case success
        case failure
        case skip
        case cancel
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)

                Text("Override Step")
                    .font(.system(size: 24, weight: .bold))

                Text("This step has been waiting for an extended period. How would you like to proceed?")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 20)

            // Action buttons
            VStack(spacing: 12) {
                Button(action: {
                    onAction(.success)
                    isPresented = false
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Mark as Success")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Button(action: {
                    onAction(.failure)
                    isPresented = false
                }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Mark as Failed")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Button(action: {
                    onAction(.skip)
                    isPresented = false
                }) {
                    HStack {
                        Image(systemName: "forward.circle.fill")
                        Text("Skip This Step")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            // Cancel button
            Button(cancelButtonText) {
                onAction(.cancel)
                isPresented = false
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .padding(.bottom, 20)
        }
        .frame(width: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(16)
        .shadow(radius: 20)
    }
}
