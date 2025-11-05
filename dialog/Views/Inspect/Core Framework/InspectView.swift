//
//  InspectView.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 19/07/2025
//
//  Service-based implementation of InspectView
//  Uses InspectState with clean separation of concerns
//

import SwiftUI

struct InspectView: View {
    @StateObject private var inspectState = InspectState()
    @State private var showingAboutPopover = false

    var body: some View {
        Group {
            switch inspectState.loadingState {
            case .loading:
                CoordinatedLoadingView()
                    .onAppear {
                        if appvars.debugMode {
                            print("DEBUG: InspectViewServiceBased: Loading state - using new coordinator")
                        }
                    }

            case .failed(let errorMessage):
                CoordinatedConfigErrorView(
                    errorMessage: errorMessage,
                    onRetry: {
                        inspectState.retryConfiguration()
                    },
                    onUseDefault: {
                        inspectState.retryConfiguration()
                    }
                )
                .onAppear {
                    print("ERROR: InspectViewServiceBased: Failed state - \(errorMessage)")
                }

            case .loaded:
                presetView(for: inspectState.uiConfiguration.preset)
                    .onAppear {
                        if appvars.debugMode {
                            print("DEBUG: InspectViewServiceBased: Loading preset '\(inspectState.uiConfiguration.preset)' with new coordinator")
                        }
                    }
            }
        }
        .onAppear {
            if appvars.debugMode {
                print("DEBUG: InspectViewServiceBased: Starting with service-based architecture")
            }
            writeLog("InspectViewServiceBased: Initializing with InspectState", logLevel: .info)
            inspectState.initialize()
        }
    }

    // MARK: - Helper Methods

    /// Factory method for preset creation
    @ViewBuilder
    private func presetView(for presetName: String) -> some View {
        let preset = presetName.lowercased()
        // Size mode is now handled by InspectSizes
        let basePreset = preset

        switch basePreset {
        case "preset1":
            // Test with Preset1 first
            Preset1View(inspectState: inspectState)
        case "preset2":
            // Using service-based version to fix state flipping
            Preset2View(inspectState: inspectState)
        case "preset3":
            // Using wrapper to fix state recreation
            Preset3Wrapper(coordinator: inspectState)
        case "preset4":
            // Using wrapper to fix state recreation
            Preset4Wrapper(coordinator: inspectState)
        case "preset5":
            // Using wrapper to fix state recreation
            Preset5Wrapper(coordinator: inspectState)
        case "preset6", "6":
            // Progress Stepper with Side Panel (formerly Preset9)
            Preset6Wrapper(coordinator: inspectState)
        case "preset7", "7":
            // Using wrapper to fix state recreation
            Preset7Wrapper(coordinator: inspectState)
        case "preset8", "8":
            // Using wrapper to fix state recreation
            Preset8Wrapper(coordinator: inspectState)
        case "preset9", "9":
            // Modern two-panel onboarding flow
            Preset9Wrapper(coordinator: inspectState)
        default:
            // Default fallback
            Preset1View(inspectState: inspectState)
                .onAppear {
                    print("WARNING: InspectViewServiceBased: Unknown preset '\(presetName)', using default")
                }
        }
    }
}

// MARK: - Loading View

private struct CoordinatedLoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading configuration...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Error View

private struct CoordinatedConfigErrorView: View {
    let errorMessage: String
    let onRetry: () -> Void
    let onUseDefault: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Configuration Error")
                .font(.title2)
                .fontWeight(.semibold)

            Text(errorMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 12) {
                Button("Retry") {
                    onRetry()
                }
                .buttonStyle(.bordered)

                Button("Use Default") {
                    onUseDefault()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Wrapper for Preset3 to use InspectState

private struct Preset3Wrapper: View {
    @ObservedObject var coordinator: InspectState
    @StateObject private var inspectState = InspectState()

    var body: some View {
        Preset3View(inspectState: inspectState)
            .onAppear {
                // Sync initial state from coordinator
                inspectState.items = coordinator.items
                inspectState.config = coordinator.config
                inspectState.uiConfiguration = coordinator.uiConfiguration
                inspectState.backgroundConfiguration = coordinator.backgroundConfiguration
                inspectState.buttonConfiguration = coordinator.buttonConfiguration
                inspectState.completedItems = coordinator.completedItems
                inspectState.downloadingItems = coordinator.downloadingItems
            }
            .onReceive(coordinator.$completedItems) { items in
                inspectState.completedItems = items
            }
            .onReceive(coordinator.$downloadingItems) { items in
                inspectState.downloadingItems = items
            }
    }
}

// MARK: - Wrapper for Preset4 to use InspectState

private struct Preset4Wrapper: View {
    @ObservedObject var coordinator: InspectState
    @StateObject private var inspectState = InspectState()
    @State private var hasInitialized = false

    var body: some View {
        Preset4View(inspectState: inspectState)
            .onAppear {
                guard !hasInitialized else { return }
                hasInitialized = true

                // Initialize the InspectState properly
                inspectState.initialize()

                // Then sync state from coordinator
                inspectState.items = coordinator.items
                inspectState.config = coordinator.config
                inspectState.uiConfiguration = coordinator.uiConfiguration
                inspectState.backgroundConfiguration = coordinator.backgroundConfiguration
                inspectState.buttonConfiguration = coordinator.buttonConfiguration
                inspectState.completedItems = coordinator.completedItems
                inspectState.downloadingItems = coordinator.downloadingItems
                inspectState.plistSources = coordinator.plistSources
                inspectState.colorThresholds = coordinator.colorThresholds

                // Sync validation results
                inspectState.plistValidationResults = coordinator.plistValidationResults
            }
            .onReceive(coordinator.$completedItems) { items in
                inspectState.completedItems = items
            }
            .onReceive(coordinator.$downloadingItems) { items in
                inspectState.downloadingItems = items
            }
            .onReceive(coordinator.$plistValidationResults) { results in
                inspectState.plistValidationResults = results
            }
    }
}

// MARK: - Wrapper for Preset5 to use InspectState

private struct Preset5Wrapper: View {
    @ObservedObject var coordinator: InspectState
    @StateObject private var inspectState = InspectState()
    @State private var hasInitialized = false

    var body: some View {
        Preset5View(inspectState: inspectState)
            .onAppear {
                guard !hasInitialized else { return }
                hasInitialized = true

                // Initialize the InspectState properly
                inspectState.initialize()

                // Then sync state from coordinator
                inspectState.items = coordinator.items
                inspectState.config = coordinator.config
                inspectState.uiConfiguration = coordinator.uiConfiguration
                inspectState.backgroundConfiguration = coordinator.backgroundConfiguration
                inspectState.buttonConfiguration = coordinator.buttonConfiguration
                inspectState.completedItems = coordinator.completedItems
                inspectState.downloadingItems = coordinator.downloadingItems
            }
            .onReceive(coordinator.$completedItems) { items in
                inspectState.completedItems = items
            }
            .onReceive(coordinator.$downloadingItems) { items in
                inspectState.downloadingItems = items
            }
    }
}

// MARK: - Wrapper for Preset6 to use InspectState

private struct Preset6Wrapper: View {
    @ObservedObject var coordinator: InspectState

    var body: some View {
        Preset6View(inspectState: coordinator)
    }
}

// MARK: - Wrapper for Preset7 to use InspectState

private struct Preset7Wrapper: View {
    @ObservedObject var coordinator: InspectState
    @StateObject private var inspectState = InspectState()
    @State private var hasInitialized = false

    var body: some View {
        Preset7View(inspectState: inspectState)
            .onAppear {
                guard !hasInitialized else { return }
                hasInitialized = true

                // Initialize the InspectState properly
                inspectState.initialize()

                // Then sync state from coordinator
                inspectState.items = coordinator.items
                inspectState.config = coordinator.config
                inspectState.uiConfiguration = coordinator.uiConfiguration
                inspectState.backgroundConfiguration = coordinator.backgroundConfiguration
                inspectState.buttonConfiguration = coordinator.buttonConfiguration
                inspectState.completedItems = coordinator.completedItems
                inspectState.downloadingItems = coordinator.downloadingItems
            }
            .onReceive(coordinator.$completedItems) { items in
                inspectState.completedItems = items
            }
            .onReceive(coordinator.$downloadingItems) { items in
                inspectState.downloadingItems = items
            }
    }
}

// MARK: - Wrapper for Preset8 to use InspectState

private struct Preset8Wrapper: View {
    @ObservedObject var coordinator: InspectState
    @StateObject private var inspectState = InspectState()
    @State private var hasInitialized = false

    var body: some View {
        Preset8View(inspectState: inspectState)
            .onAppear {
                guard !hasInitialized else { return }
                hasInitialized = true

                // Initialize the InspectState properly
                inspectState.initialize()

                // Then sync state from coordinator
                inspectState.items = coordinator.items
                inspectState.config = coordinator.config
                inspectState.uiConfiguration = coordinator.uiConfiguration
                inspectState.backgroundConfiguration = coordinator.backgroundConfiguration
                inspectState.buttonConfiguration = coordinator.buttonConfiguration
                inspectState.completedItems = coordinator.completedItems
                inspectState.downloadingItems = coordinator.downloadingItems
            }
            .onReceive(coordinator.$completedItems) { items in
                inspectState.completedItems = items
            }
            .onReceive(coordinator.$downloadingItems) { items in
                inspectState.downloadingItems = items
            }
    }
}

// MARK: - Wrapper for Preset9 to use InspectState

private struct Preset9Wrapper: View {
    @ObservedObject var coordinator: InspectState

    var body: some View {
        Preset9View(inspectState: coordinator)
    }
}
