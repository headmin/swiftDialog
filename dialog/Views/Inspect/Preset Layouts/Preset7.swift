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

struct Preset7View: View, InspectLayoutProtocol {
    @ObservedObject var inspectState: InspectState
    @State private var completedSteps: Set<String> = []
    @State private var currentStep: Int = 0
    @State private var loadedImages: [String: NSImage] = [:]
    @State private var showSuccess: Bool = false
    @State private var currentPage: Int = 0  // Track which page of cards we're viewing
    @State private var externalMonitoringTimer: Timer?  // Store timer for proper cleanup
    private let persistenceService = Preset7Persistence.shared

    // Dynamic cards per page based on size mode
    private var cardsPerPage: Int {
        switch sizeMode {
        case "compact": return 2
        case "large": return 4
        default: return 3  // standard
        }
    }
    private let imageResolver = ImageResolver.shared

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

    var body: some View {
        VStack(spacing: 0) {
            // Top status indicator (optional)
            if !inspectState.uiConfiguration.statusMessage.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(inspectState.uiConfiguration.statusMessage)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 30)
            }

            // Main title
            Text(inspectState.uiConfiguration.windowTitle)
                .font(.system(size: 32 * scaleFactor, weight: .semibold))
                .padding(.top, inspectState.uiConfiguration.statusMessage.isEmpty ? 40 * scaleFactor : 20 * scaleFactor)
                .padding(.bottom, 40 * scaleFactor)

            // Horizontal step cards with navigation
            HStack(spacing: 20 * scaleFactor) {
                // Left chevron for navigation
                if currentPage > 0 {
                    Button(action: { navigateLeft() }) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 36 * scaleFactor))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Previous steps")
                } else {
                    // Spacer to maintain layout when chevron is hidden
                    Color.clear
                        .frame(width: 36 * scaleFactor, height: 36 * scaleFactor)
                }

                // Cards container with animation
                HStack(spacing: 25 * scaleFactor) {
                    ForEach(Array(currentPageItems.enumerated()), id: \.element.id) { index, item in
                        let globalIndex = currentPage * cardsPerPage + index
                        StepCard(
                            step: globalIndex + 1,
                            item: item,
                            isCompleted: completedSteps.contains(item.id) || inspectState.completedItems.contains(item.id),
                            isActive: globalIndex == currentStep,
                            image: loadedImages[item.id],
                            iconBasePath: inspectState.uiConfiguration.iconBasePath,
                            scaleFactor: scaleFactor
                        )
                        .onAppear {
                            if globalIndex == currentStep {
                                writeLog("Preset7: Card \(globalIndex) (\(item.id)) is ACTIVE (currentStep=\(currentStep))", logLevel: .info)
                            } else if completedSteps.contains(item.id) {
                                writeLog("Preset7: Card \(globalIndex) (\(item.id)) is COMPLETED", logLevel: .debug)
                            }
                        }
                        .onTapGesture {
                            handleStepClick(item: item, index: globalIndex)
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }
                }
                .frame(width: 750 * scaleFactor) // Fixed width for card container
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentPage)

                // Right chevron for navigation
                if currentPage < totalPages - 1 {
                    Button(action: { navigateRight() }) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 36 * scaleFactor))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("More steps")
                } else {
                    // Spacer to maintain layout when chevron is hidden
                    Color.clear
                        .frame(width: 36 * scaleFactor, height: 36 * scaleFactor)
                }
            }
            .padding(.horizontal, 40)

            // Dynamic indicator: dots when navigating, completion message when done
            ZStack {
                // Page dots - visible when not complete
                if !inspectState.items.allSatisfy({ completedSteps.contains($0.id) }) && totalPages > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { page in
                            Circle()
                                .fill(page == currentPage ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 8 * scaleFactor, height: 8 * scaleFactor)
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        currentPage = page
                                    }
                                }
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }

                // Completion indicator - appears when all done
                if inspectState.items.allSatisfy({ completedSteps.contains($0.id) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14 * scaleFactor))
                            .foregroundColor(.blue)

                        Text("Setup Complete")
                            .font(.system(size: 13 * scaleFactor, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .scaleEffect(inspectState.items.allSatisfy({ completedSteps.contains($0.id) }) ? 1.0 : 0.9)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .frame(height: 20)  // Fixed height to prevent layout shift
            .padding(.top, 35)  // Consistent spacing
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: inspectState.items.allSatisfy({ completedSteps.contains($0.id) }))

            Spacer()

            // Custom buttons with dynamic state based on completion
            customButtonArea()
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            writeLog("Preset7: View appearing, loading state...", logLevel: .info)
            loadStepImages()
            loadPersistedState()  // Load previous progress (will log launched/resumed)
            setupExternalMonitoring()

            // Debug button configuration
            writeLog("Preset7: Button1 text: '\(inspectState.buttonConfiguration.button1Text)'", logLevel: .debug)
            writeLog("Preset7: Button2 text: '\(inspectState.buttonConfiguration.button2Text)'", logLevel: .debug)
            writeLog("Preset7: Button2 visible: \(inspectState.buttonConfiguration.button2Visible)", logLevel: .debug)
        }
        .onChange(of: inspectState.items.count) {
            // When items change (initial load), update currentStep if needed
            if !completedSteps.isEmpty && !inspectState.items.isEmpty {
                if let firstIncompleteIndex = inspectState.items.firstIndex(where: { !completedSteps.contains($0.id) }) {
                    if currentStep != firstIncompleteIndex {
                        currentStep = firstIncompleteIndex
                        let targetPage = firstIncompleteIndex / 3
                        currentPage = targetPage
                        writeLog("Preset7: Items loaded, updated currentStep to \(currentStep), page \(currentPage)", logLevel: .info)
                    }
                }
            }
        }
        .onChange(of: inspectState.completedItems) { _, newCompletedItems in
            // Sync with external completions (e.g., from inspect state)
            withAnimation(.spring()) {
                // Update our local completed steps
                for item in inspectState.items {
                    if newCompletedItems.contains(item.id) && !completedSteps.contains(item.id) {
                        completedSteps.insert(item.id)
                        writeLog("Preset7: External completion detected for \(item.id)", logLevel: .debug)
                    }
                }

                // Check if current page is complete and auto-advance
                checkForPageCompletion()

                // Check if all steps are complete
                checkForCompletion()
            }
        }
        .onDisappear {
            savePersistedState()  // Save progress when closing
            externalMonitoringTimer?.invalidate()  // Clean up timer
            externalMonitoringTimer = nil
        }
    }

    private func navigateLeft() {
        withAnimation(.spring()) {
            currentPage = max(0, currentPage - 1)
        }
        writeInteractionLog("navigate", step: "page_\(currentPage)")
    }

    private func navigateRight() {
        withAnimation(.spring()) {
            currentPage = min(totalPages - 1, currentPage + 1)
        }
        writeInteractionLog("navigate", step: "page_\(currentPage)")
    }

    private func handleStepClick(item: InspectConfig.ItemConfig, index: Int) {
        guard !completedSteps.contains(item.id) else { return }

        withAnimation(.spring()) {
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring()) {
                            self.currentPage = nextPage
                            self.writeInteractionLog("auto_navigate", step: "page_\(nextPage)")
                        }
                    }
                    break
                }
            }
        }
    }

    @ViewBuilder
    private func customButtonArea() -> some View {
        let allStepsComplete = inspectState.items.allSatisfy { completedSteps.contains($0.id) }

        HStack(spacing: 12) {
            // Button 2: "Cancel" - always enabled to break/stop
            if inspectState.buttonConfiguration.button2Visible && !inspectState.buttonConfiguration.button2Text.isEmpty {
                Button(inspectState.buttonConfiguration.button2Text) {
                    writeLog("InspectView: User clicked button2 (\(inspectState.buttonConfiguration.button2Text)) - exiting with code 2", logLevel: .info)
                    exit(2)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                // Note: button2 is always enabled when visible
            }

            // Button 1: Dynamic text based on completion state
            Button(allStepsComplete ? "Continue" : inspectState.buttonConfiguration.button1Text) {
                writeLog("InspectView: User clicked button1 (\(allStepsComplete ? "Continue" : inspectState.buttonConfiguration.button1Text)) - exiting with code 0", logLevel: .info)
                exit(0)
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!allStepsComplete) // Only enabled when all complete
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
                if let fileHandle = FileHandle(forWritingAtPath: logPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
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
            withAnimation(.easeInOut(duration: 0.5).delay(0.3)) {
                showSuccess = true
            }
            writeInteractionLog("completed", step: "all_steps")
        }
    }

    private func resetSteps() {
        withAnimation(.spring()) {
            completedSteps.removeAll()
            currentStep = 0
            currentPage = 0  // Reset to first page
            inspectState.completedItems.removeAll()
            showSuccess = false
        }

        // Clear the persisted state using the safe service
        persistenceService.clearState()

        writeInteractionLog("reset", step: "all")
    }


    private func setupExternalMonitoring() {
        // Check for external triggers periodically
        externalMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            DispatchQueue.main.async {
                checkForExternalTrigger()
            }
        }
    }

    private func checkForExternalTrigger() {
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
                        withAnimation(.spring()) {
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

    private func loadStepImages() {
        // Images are now loaded on-demand via IconView, similar to other presets
        // This ensures consistent image loading behavior across all presets
        writeLog("Preset7: Image loading delegated to IconView for consistency", logLevel: .debug)
    }

    // MARK: - State Persistence

    private func savePersistedState() {
        persistenceService.saveState(
            completedSteps: completedSteps,
            currentPage: currentPage,
            currentStep: currentStep,
            itemCount: inspectState.items.count,
            totalPages: totalPages
        )
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

        // Calculate which page contains this task
        let cardsPerPage = 3
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
        let persistPath = ProcessInfo.processInfo.environment["DIALOG_PERSIST_PATH"] ?? "default"
        writeLog("Preset7: DIALOG_PERSIST_PATH=\(persistPath)", logLevel: .info)

        guard var state = persistenceService.loadState() else {
            writeLog("Preset7: No previous state found", logLevel: .debug)
            // No saved state - this is a fresh launch
            // Set currentStep to first item (0)
            currentStep = 0
            writeInteractionLog("launched", step: "preset7")
            return
        }

        // Validate and fix the loaded state
        persistenceService.validateAndFixState(
            state: &state,
            itemCount: inspectState.items.count,
            totalPages: totalPages
        )

        writeLog("Preset7: Loaded state - completed: \(state.completedSteps), saved page: \(state.currentPage), saved step: \(state.currentStep)", logLevel: .info)

        // Apply the validated state
        completedSteps = state.completedSteps
        inspectState.completedItems = completedSteps

        // Don't use the saved currentStep - calculate it fresh based on completed items
        // But only if items are loaded
        if !inspectState.items.isEmpty {
            // Find the first incomplete task
            if let firstIncompleteIndex = inspectState.items.firstIndex(where: { !completedSteps.contains($0.id) }) {
                // Calculate the page for this step
                let targetPage = firstIncompleteIndex / 3

                // Update state immediately - SwiftUI will handle the UI updates
                currentStep = firstIncompleteIndex
                currentPage = targetPage

                writeLog("Preset7: Set currentStep=\(firstIncompleteIndex) (first incomplete: \(inspectState.items[firstIncompleteIndex].id)), page=\(targetPage)", logLevel: .info)
            } else {
                // All steps are completed - set to last item
                currentStep = inspectState.items.count - 1
                let lastPage = (inspectState.items.count - 1) / 3
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
                fileHandle.seekToEndOfFile()
                fileHandle.write(logData)
                fileHandle.closeFile()
            } else {
                try? logData.write(to: URL(fileURLWithPath: logPath))
            }
        }
    }
}

struct StepCard: View {
    let step: Int
    let item: InspectConfig.ItemConfig
    let isCompleted: Bool
    let isActive: Bool
    let image: NSImage?
    let iconBasePath: String?
    let scaleFactor: CGFloat

    private let imageResolver = ImageResolver.shared

    var body: some View {
        VStack(spacing: 0) {
            // Step number bubble
            ZStack {
                Circle()
                    .fill(bubbleColor)
                    .frame(width: 44 * scaleFactor, height: 44 * scaleFactor)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20 * scaleFactor, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(step)")
                        .font(.system(size: 20 * scaleFactor, weight: .medium))
                        .foregroundColor(isActive ? .blue : .secondary)
                }
            }
            .padding(.bottom, 20)

            // Image/Content card
            ZStack(alignment: .bottomTrailing) {
                // Main card with active border
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackgroundColor)
                    .frame(width: 220 * scaleFactor, height: 180 * scaleFactor)
                    .overlay(
                        Group {
                            if let iconPath = item.icon {
                                // Use IconView for consistent image loading with other presets
                                IconView(
                                    image: imageResolver.resolveImagePath(iconPath, basePath: iconBasePath) ?? "",
                                    defaultImage: getPlaceholderIcon(),
                                    defaultColour: isCompleted ? "green" : (isActive ? "blue" : "gray")
                                )
                                .frame(width: 180 * scaleFactor, height: 140 * scaleFactor)
                                .padding(10)
                            } else {
                                // Fallback placeholder
                                VStack {
                                    Image(systemName: getPlaceholderIcon())
                                        .font(.system(size: 50))
                                        .foregroundColor(placeholderColor)
                                    Text(String(step))
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(placeholderTextColor)
                                }
                            }
                        }
                    )
                    .overlay(
                        // Active indicator border - inside the card
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isActive && !isCompleted ? Color.blue : Color.clear, lineWidth: 3)
                    )

                // Optional app context icon bubble (bottom-right) - outside the card
                if let categoryIcon = item.categoryIcon {
                    AppIconBubble(iconName: categoryIcon, iconBasePath: iconBasePath, scaleFactor: scaleFactor)
                        .offset(x: 10, y: 10)
                        .zIndex(10) // High z-index to ensure it's above everything
                }
            }

            // Step instruction text with fixed height to prevent bumping
            VStack(spacing: 4) {
                Text(item.displayName)
                    .font(.system(size: 15 * scaleFactor, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(minHeight: 20)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 13 * scaleFactor))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(minHeight: 18)
                } else {
                    // Empty space to maintain consistent height
                    Color.clear
                        .frame(height: 18)
                }
            }
            .frame(width: 200 * scaleFactor, height: 60 * scaleFactor, alignment: .top)  // Fixed height for text area
            .padding(.top, 12 * scaleFactor)
        }
        .frame(width: 240 * scaleFactor)
    }

    private var bubbleColor: Color {
        if isCompleted {
            return .green
        } else if isActive {
            return Color.blue.opacity(0.2)
        } else {
            return Color.gray.opacity(0.1)
        }
    }

    private var cardBackgroundColor: Color {
        if isCompleted {
            return Color.green.opacity(0.1)
        } else if isActive {
            return Color.blue.opacity(0.05)
        } else {
            return Color.gray.opacity(0.05)
        }
    }

    private var placeholderColor: Color {
        isCompleted ? .green : (isActive ? .blue : .gray)
    }

    private var placeholderTextColor: Color {
        isCompleted ? .green : (isActive ? .blue : .secondary)
    }

    private func getPlaceholderIcon() -> String {
        // Return appropriate SF Symbol based on step
        switch step {
        case 1: return "bell.badge"
        case 2: return "checkmark.circle"
        case 3: return "lock.shield"
        case 4: return "desktopcomputer"
        case 5: return "arrow.right.square"
        default: return "questionmark.circle"
        }
    }
}

// Small app icon bubble for context (e.g., Finder, Safari, Word)
struct AppIconBubble: View {
    let iconName: String
    let iconBasePath: String?
    let scaleFactor: CGFloat

    private let imageResolver = ImageResolver.shared

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 36 * scaleFactor, height: 36 * scaleFactor)
                .shadow(color: Color.black.opacity(0.2), radius: 2 * scaleFactor, x: 0, y: 1 * scaleFactor)

            if let resolvedPath = imageResolver.resolveImagePath(iconName, basePath: iconBasePath),
               let image = NSImage(contentsOfFile: resolvedPath) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24 * scaleFactor, height: 24 * scaleFactor)
            } else {
                // Fallback to SF Symbol if image not found
                Image(systemName: getSFSymbolForApp(iconName))
                    .font(.system(size: 16 * scaleFactor))
                    .foregroundColor(.blue)
            }
        }
    }

    private func getSFSymbolForApp(_ name: String) -> String {
        let lowercased = name.lowercased()
        if lowercased.contains("finder") { return "folder" }
        if lowercased.contains("safari") { return "safari" }
        if lowercased.contains("word") || lowercased.contains("office") { return "doc.text" }
        if lowercased.contains("excel") { return "tablecells" }
        if lowercased.contains("powerpoint") { return "play.rectangle" }
        if lowercased.contains("terminal") { return "terminal" }
        if lowercased.contains("settings") || lowercased.contains("preferences") { return "gear" }
        return "app"
    }
}

struct LinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14))
            .foregroundColor(.blue)
            .underline()
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}
