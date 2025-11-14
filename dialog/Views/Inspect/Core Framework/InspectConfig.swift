//
//  InspectConfig.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 20/09/2025
//
//  Configuration structures for Inspect mode
//

import Foundation
import SwiftUI

// MARK: - Unified Status Enum

/// Unified status enum for all Inspect mode items
enum InspectItemStatus: Equatable {
    case pending
    case downloading
    case completed
    case failed(String)

    /// Handler for simple status without associated values for basic comparisons
    var simpleStatus: SimpleItemStatus {
        switch self {
        case .pending: return .pending
        case .downloading: return .downloading
        case .completed: return .completed
        case .failed: return .failed
        }
    }
}

/// Simple download status enum
///
/// **EXTERNAL API**: This enum is maintained for backward compatibility with external scripts
/// that may rely on parsing Dialog's state output.
///
/// **Internal Usage**: Prefer `InspectItemStatus` with Swift pattern matching:
/// ```swift
/// // Preferred internal approach:
/// if case .failed = itemStatus {
///     // Handle failure
/// }
///
/// // Avoid in internal code:
/// if itemStatus.simpleStatus == .failed {
///     // Less type-safe
/// }
/// ```
///
/// **Note**: `InspectItemStatus` provides richer information via associated values
/// (e.g., `.failed(String)` includes error message), while `SimpleItemStatus` only
/// indicates state without context.
enum SimpleItemStatus {
    case pending
    case downloading
    case completed
    case failed
}

// MARK: - Configuration

/// Configuration structure, this is matching the JSON format 
/// Usage note: Due to the dynamic nature of the config, JSON must be used pre-loaded `export
/// DIALOG_INSPECT_CONFIG=/path/to/config.json`"$DIALOG_PATH" --inspect-mode
struct InspectConfig: Codable {
    let title: String?
    let message: String?
    let infobox: String?
    let icon: String?
    let iconsize: Int?
    let banner: String?        // Sets the Banner image used in some presets, ovrides icon
    let bannerHeight: Int?     // Banner height in pixels, default: 100 - the dialog width/height may need to be adjusted
    let bannerTitle: String?   // Banner "Title overlay" 
    let width: Int?
    let height: Int?
    let size: String?  // Refactored into preset-specific sizing- we use "compact", "standard", or "large" -> see InspectSizes.swift
    let scanInterval: Int?
    let cachePaths: [String]?
    let sideMessage: [String]?
    let sideInterval: Int?
    let style: String?
    let liststyle: String?
    let preset: String?
    let popupButton: String?
    let highlightColor: String?
    let secondaryColor: String?
    let backgroundColor: String?
    let backgroundImage: String?
    let backgroundOpacity: Double?
    let textOverlayColor: String?
    let gradientColors: [String]?
    let button1Text: String?
    let button1Disabled: Bool?
    let button2Text: String?
    let button2Visible: Bool?
    let autoEnableButton: Bool?
    let autoEnableButtonText: String?   // TODO: we may want to rename this, idea is this Text is used when a dialog run has finished and the button is enabled
    let finalButtonText: String?        // Optional text for final button when all items complete (overrides button1Text)
    let hideSystemDetails: Bool?
    let observeOnly: Bool?                  // Global observe-only mode - disables all user interactions (default: false/interactive)
    let colorThresholds: ColorThresholds?   // WIP: Configurable color thresholds for visualizations
    let plistSources: [PlistSourceConfig]?  // Array of plist configurations to monitor - used in compliance dashboards like preset5
    let categoryHelp: [CategoryHelp]?       // Optional help popovers for categories - used in compliance dashboards like preset5
    let uiLabels: UILabels?                 // Optional UI text customization (cross-preset status/progress/completion text)
    let complianceLabels: ComplianceLabels? // Optional compliance-specific text customization (Preset5)
    let pickerConfig: PickerConfig?         // Optional picker mode configuration (Preset8, Preset9, etc.)
    let instructionBanner: InstructionBannerConfig? // Optional instruction banner (all presets)
    let pickerLabels: PickerLabels?         // Optional picker mode text customization (Preset8, Preset9, etc.)

    let iconBasePath: String?                // Icon base path for relative loading icon paths
    let rotatingImages: [String]?            // Array of image paths for image rotation
    let imageRotationInterval: Double?      // set interval for auto-rotation
    let imageShape: String?                  // rectangle, square, circle - used in preset6
    let imageSyncMode: String?              // "manual" | "sync" | "auto"
    let stepStyle: String?                  // "plain" | "colored" | "cards"
    let listIndicatorStyle: String?         // "letters" | "numbers" | "roman" - list indicator format
    let extraButton: ExtraButtonConfig?     // Optional extra button (e.g., Reset, Help, Info)
    let progressBarConfig: ProgressBarConfig? // Optional progress bar visual configuration
    let logoConfig: LogoConfig?             // Optional logo overlay configuration (Preset9, etc.)

    let items: [ItemConfig]

    // Extra button configuration for optional actions in presets
    struct ExtraButtonConfig: Codable {
        let text: String                    // Button text (e.g., "Reset", "Help", "Info")
        let action: String                  // Action type: "reset", "url", "custom"
        let url: String?                    // URL to open (for action: "url")
        let visible: Bool?                  // Show/hide button (default: true)
        let position: String?               // "sidebar" | "bottom" (default: "sidebar")
        let icon: String?                   // SF Symbol icon name (e.g., "star.fill")
    }

    // Progress bar configuration for status visualization
    struct ProgressBarConfig: Codable {
        let enableStatusColors: Bool?        // Enable status-based colors (default: false)
        let showCompletionState: Bool?       // Show green when all steps complete
        let showBlockingState: Bool?         // Show orange for blocking/required items
        let colors: ProgressBarColors?

        struct ProgressBarColors: Codable {
            let normal: String?      // Default: "#007AFF" (blue)
            let complete: String?    // Default: "#34C759" (green)
            let blocking: String?    // Default: "#FF9500" (orange)
            let error: String?       // Default: "#FF3B30" (red)
        }

        // Computed properties using existing Color(hex:) from Colour+Additions.swift
        var normalColor: Color {
            Color(hex: colors?.normal ?? "#007AFF")
        }

        var completeColor: Color {
            Color(hex: colors?.complete ?? "#34C759")
        }

        var blockingColor: Color {
            Color(hex: colors?.blocking ?? "#FF9500")
        }

        var errorColor: Color {
            Color(hex: colors?.error ?? "#FF3B30")
        }
    }

    // Logo overlay configuration for preset layouts
    struct LogoConfig: Codable {
        let imagePath: String                   // Path to logo image file
        let position: String?                   // "topleft" | "topright" | "bottomleft" | "bottomright" (default: "topleft")
        let padding: Double?                    // Padding from edges in points (default: 20)
        let maxWidth: Double?                   // Maximum width in points (default: 80)
        let maxHeight: Double?                  // Maximum height in points (default: 80)
        let backgroundColor: String?            // Background tint color in hex (default: nil/transparent)
        let backgroundOpacity: Double?          // Background opacity 0.0-1.0 (default: 0.2)
        let cornerRadius: Double?               // Corner radius for background (default: 8)
    }

    struct ItemConfig: Codable {
        let id: String
        let displayName: String
        let subtitle: String?           // TODO: We need to simplify this - atm used as subtitle for preset6 checklist
        let guiIndex: Int
        let paths: [String]
        let icon: String?
        let status: String?             // Optional: status icon for list items (e.g., "shield", "checkmark.circle.fill") - supports dynamic updates via listitem: commands
        let banner: String?             // Optional: banner image path for preset10 cards
        let plistKey: String?           // Optional: plist key to check - used in compliance dashboards like preset5
        let expectedValue: String?      // Optional: expected value for the key - used in compliance dashboards like preset5
        let evaluation: String?         // Optional: evaluation type (equals, boolean, exists, contains, range) - used in compliance dashboards like preset5
        let plistRecheckInterval: Int?  // Optional: interval in seconds to recheck plist (0 = disabled, 1-3600, default: 0) - for real-time monitoring
        let useUserDefaults: Bool?      // Optional: use UserDefaults for instant notification-based monitoring instead of file polling (default: false) - 2025-11-08
        let category: String?           // Optional: custom category name - used in compliance dashboards like preset5
        let categoryIcon: String?       // Optional: custom category icon - used in compliance dashboards like preset5

        //  Guidance Support - Migration Assistant style step-by-step workflow
        let guidanceTitle: String?      // Main title for the step by step workflow
        let guidanceContent: [GuidanceContent]? // Rich content blocks for the step
        let stepType: String?           // "info" | "confirmation" | "processing" | "completion"
        let actionButtonText: String?   // Custom button text for this step for "confirmation" steps
        let processingDuration: Int?    // For processing steps: duration in seconds
        let processingMessage: String?  // Message shown during processing

        // Progress bar state flags
        let blocking: Bool?             // Mark item as blocking further progress
        let required: Bool?             // Mark item as required for completion
        let observeOnly: Bool?          // Per-item observe-only override (overrides global observeOnly)

        // Custom status text labels for this specific item (overrides global UILabels)
        let completedStatus: String?    // Custom text for completed state (overrides "Installed")
        let downloadingStatus: String?  // Custom text for downloading state (overrides "Installing...")
        let pendingStatus: String?      // Custom text for pending state (overrides "Waiting")

        // Bento box (Preset10) simple content
        let info: [String]?             // Simple bullet-point list for cards
        let bentoSize: String?          // Card size: "small", "medium", "large", "wide", "tall" (default: "medium")
        let cardLayout: String?         // Card layout: "vertical-image-below", "horizontal-image-left", "horizontal-image-right", "pattern", "gradient" (default: "vertical-image-below")
        let gradientColors: [String]?   // Custom gradient colors for this card (hex strings like ["#9AA5A4", "#66bb6a"])
        let verticalSpacing: String?    // Vertical spacing mode for Preset7: "compact" (150pt text, 32pt gap), "balanced" (200pt text, 60pt gap - default), "generous" (250pt text, 80pt gap)

        // Preset9 custom content
        let keyPointsText: String?      // Custom paragraph text for "Key Points" section in Preset9 (appears above bullet points)

        // Preset6 success/failure handling (Option 3 - Hybrid approach)
        let successMessage: String?     // Message shown when step completes successfully
        let failureMessage: String?     // Message shown when step fails

        // Preset6 progressive override mechanism (for stuck workflows)
        let waitWarningTime: Int?       // Show warning after X seconds waiting (default: 120)
        let waitSmallOverrideTime: Int? // Show small override link after X seconds (default: 30)
        let waitLargeOverrideTime: Int? // Show large override button after X seconds (default: 60)
        let overrideButtonText: String? // Custom text for override button (default: "Override")
        let allowOverride: Bool?        // Enable override capability (default: true)
        let allowNavigationDuringProcessing: Bool? // Allow Continue/Back buttons while processing (default: true)

        // Preset6 processing modes
        let processingMode: String?     // "simple" (default - auto-complete) | "progressive" (wait for triggers)
        let autoAdvance: Bool?          // Auto-navigate after simple mode completes (default: false)
        let autoResult: String?         // Force result in simple mode: "success" (default) | "failure" - for banner demos
        let waitForExternalTrigger: Bool? // If true, NEVER auto-complete - always wait for success:/failure: command (default: false)

        // Multiple plist monitors for automatic status component updates
        let plistMonitors: [PlistMonitor]? // Array of plist monitors that auto-update guidance components

        // Multiple JSON monitors for automatic status component updates
        let jsonMonitors: [JsonMonitor]? // Array of JSON monitors that auto-update guidance components
    }

    // Completion trigger - defines automatic step completion when plist condition met
    struct CompletionTrigger: Codable {
        let condition: String           // "equals" | "notEquals" | "exists" | "match" | "greaterThan" | "lessThan"
        let value: String?              // Expected value for comparison (optional for "exists")
        let result: String              // "success" | "failure" - completion result type
        let message: String?            // Optional custom completion message
        let delay: Double?              // Optional delay before triggering (in seconds, default: 0)
    }

    // Plist monitor configuration - binds plist keys to guidance components
    struct PlistMonitor: Codable {
        let path: String                // Plist file path (supports glob patterns like "*.installinfo.plist")
        let key: String                 // Plist key to monitor (supports dot notation like "Settings.Network")
        let guidanceBlockIndex: Int     // Index of guidance component to update (0-based)
        let targetProperty: String      // Property to update: "state", "actual", "currentPhase", "progress", "label"
        let valueMap: [String: String]? // Optional value transformation (e.g., {"1": "enabled", "0": "disabled"})
        let recheckInterval: Int        // Polling interval in seconds (1-3600)
        let useUserDefaults: Bool?      // Use UserDefaults for faster reads (default: false)
        let evaluation: String?         // Optional evaluation: "equals", "boolean", "exists", "contains", "range"
        let completionTrigger: CompletionTrigger? // Optional auto-completion when condition met (Phase 1 MVP)
    }

    // JSON monitor configuration - binds JSON keys to guidance components
    struct JsonMonitor: Codable {
        let path: String                // JSON file path (supports glob patterns like "*.config.json")
        let key: String                 // JSON key path to monitor (supports dot notation like "deployment.status")
        let guidanceBlockIndex: Int     // Index of guidance component to update (0-based)
        let targetProperty: String      // Property to update: "state", "actual", "currentPhase", "progress", "label"
        let valueMap: [String: String]? // Optional value transformation (e.g., {"running": "enabled", "stopped": "disabled"})
        let recheckInterval: Int        // Polling interval in seconds (1-3600)
        let evaluation: String?         // Optional evaluation: "equals", "boolean", "exists", "contains", "range"
        let completionTrigger: CompletionTrigger? // Optional auto-completion when condition met
    }

    // Guidance content blocks for rich text display eg. used in Preset6
    struct GuidanceContent: Codable {
        let type: String                // "text" | "highlight" | "warning" | "info" | "success" | "bullets" | "arrow" | "image" | "image-carousel" | "checkbox" | "dropdown" | "radio" | "toggle" | "slider" | "button" | "status-badge" | "comparison-table" | "phase-tracker" | "progress-bar" | "compliance-card" | "compliance-header"
        let content: String?            // The actual text content (or button label for type="button") - optional for status monitoring types
        let color: String?              // Optional color override (hex format)
        let bold: Bool?                 // Whether to display in bold

        // Image-specific fields (for type="image")
        let imageShape: String?         // "rectangle" | "square" | "circle" - shape/clipping for the image
        let imageWidth: Double?         // Custom width in points (default: 400)
        let imageBorder: Bool?          // Show border/shadow around image (default: true)
        let caption: String?            // Caption text displayed below the image

        // Interactive element fields (for type="checkbox" | "dropdown" | "radio" | "toggle" | "slider")
        let id: String?                 // Unique identifier for storing user input
        let required: Bool?             // Whether this input is required for step completion
        let options: [String]?          // Options for dropdown/radio selections
        let value: String?              // Default/current value (for checkbox, toggle, dropdown, radio) or numeric value as string for slider
        let helpText: String?           // Optional help text displayed in info popover (i icon)

        // Slider-specific fields (for type="slider")
        let min: Double?                // Minimum value for slider (default: 0)
        let max: Double?                // Maximum value for slider (default: 100)
        let step: Double?               // Step increment for slider (default: 1)
        let unit: String?               // Unit label to display (e.g., "%", "GB", "minutes")

        // Button-specific fields (for type="button")
        let action: String?             // Button action: "url", "shell", "custom" (triggers callback)
        let url: String?                // URL to open (for action="url")
        let shell: String?              // Shell command to execute (for action="shell")
        let buttonStyle: String?        // Button style: "bordered" (default), "borderedProminent", "plain"

        // Status monitoring fields (for type="status-badge" | "comparison-table" | "phase-tracker" | "progress-bar")
        let label: String?              // Display label for status components
        let state: String?              // Current state (e.g., "enabled", "disabled", "active", "enrolled")
        let icon: String?               // SF Symbol icon name for status-badge
        let autoColor: Bool?            // Auto-assign colors based on state (default: true)
        let expected: String?           // Expected value for comparison-table
        let actual: String?             // Actual value for comparison-table
        let expectedLabel: String?      // Custom label for expected column (default: "Expected")
        let actualLabel: String?        // Custom label for actual column (default: "Actual")
        let expectedIcon: String?       // SF Symbol icon for expected value (comparison-table columns mode)
        let actualIcon: String?         // SF Symbol icon for actual value (comparison-table columns mode)
        let comparisonStyle: String?    // Comparison layout: "stacked" (default) or "columns"
        let highlightCells: Bool?       // Enable bold/larger text and stronger tinted backgrounds for columns mode (default: false)
        let expectedColor: String?      // Custom color for expected column (hex: "#FF3B30"), overrides match-based coloring
        let actualColor: String?        // Custom color for actual column (hex: "#34C759"), overrides match-based coloring
        let category: String?           // Category name for grouping comparison-tables
        let currentPhase: Int?          // Current phase number (1-based) for phase-tracker
        let phases: [String]?           // Phase labels for phase-tracker
        let style: String?              // Display style: "stepper" (default), "progress", "checklist" for phase-tracker; "indeterminate" (default) or "determinate" for progress-bar
        let progress: Double?           // Progress value (0.0 to 1.0) for determinate progress-bar

        // Image carousel fields (for type="image-carousel")
        let images: [String]?           // Array of image paths for carousel
        let captions: [String]?         // Optional captions for each image (array must match images length)
        let imageHeight: Double?        // Custom height in points (default: 300)
        let showDots: Bool?             // Show dot page indicators (default: true)
        let showArrows: Bool?           // Show left/right arrow navigation buttons (default: true)
        let autoAdvance: Bool?          // Enable automatic slide advancement (default: false)
        let autoAdvanceDelay: Double?   // Seconds between auto-advances (default: 3.0)
        let transitionStyle: String?    // Transition animation: "slide" (default) | "fade"
        let currentIndex: Int?          // Current image index (0-based) for dynamic updates

        // Compliance card fields (for type="compliance-card", migrated from Preset5)
        let categoryName: String?       // Category name displayed in card header
        let passed: Int?                // Number of passed items in category
        let total: Int?                 // Total number of items in category
        let cardIcon: String?           // SF Symbol icon for category (displayed in header)
        let checkDetails: String?       // Optional compact bullet-point details to display inside card (newline-separated, supports Unicode symbols)
    }
    
    struct PlistSourceConfig: Codable {
        let path: String                    // Path to plist file
        let type: String                    // "compliance", "health", "licenses", "preferences", "custom"
        let displayName: String             // Human-readable name
        let icon: String?                   // SF Symbol icon name
        let keyMappings: [KeyMapping]?      // How to interpret plist keys
        let successValues: [String]?        // Values that indicate "success" (for booleans: ["true"])
        let criticalKeys: [String]?         // Keys that are considered critical
        let categoryPrefix: [String: String]? // Map prefixes to category names
        let maxCheckDetails: Int?           // Max check items to display per category (default: 15)
    }
    
    struct KeyMapping: Codable {
        let key: String                     // Original plist key
        let displayName: String?            // Human-readable name (optional)
        let category: String?               // Override category (optional)
        let isCritical: Bool?              // Override critical status (optional)
    }
    
    struct CategoryHelp: Codable {
        let category: String                // Category name to match
        let description: String             // Description of the category
        let recommendations: String?        // Recommendations if not compliant
        let icon: String?                   // Optional custom icon for the category
        let statusLabel: String?            // Optional custom label for "Compliance Status"
        let recommendationsLabel: String?   // Optional custom label for "Recommended Actions"
    }
    
    /// We try here a cross-preset approach fro UI text customization labels (currently > Presets 1-9)
    /// Use this for overriding default status text, progress formats, and completion messages
    /// Note: Primary UI config (title, message, button text) remains at top level
    struct UILabels: Codable {
        // Status text overrides for items
        let completedStatus: String?        // Label for completed items (default: "Completed")
        let downloadingStatus: String?      // Label for downloading items (default: "Installing...")
        let pendingStatus: String?          // Label for pending items (default: "Pending")
        let failedStatus: String?           // Label for validation failure (default: "Failed")

        // Progress bar text templates (use {completed}, {total}, {current} as placeholders)
        let progressFormat: String?         // Progress bar text (default: "{completed} of {total} completed")
        let stepCounterFormat: String?      // Step counter text (default: "Step {current} of {total}")

        // Completion celebration messages
        let completionMessage: String?      // Main completion message (default: "All Complete!")
        let completionSubtitle: String?     // Subtitle completion message (default: "Setup complete!")

        // Section headers (used in Preset1 and others)
        let sectionHeaderCompleted: String?  // Completed section header (default: "Completed")
        let sectionHeaderPending: String?    // Pending section header (default: "Pending Installation")
        let sectionHeaderFailed: String?     // Failed section header (default: "Installation Failed")

        // Step/Item workflow status labels (used in Preset8 onboarding and multi-step flows)
        let statusConditionMet: String?     // Status when validation passes (default: "Condition Met")
        let statusConditionNotMet: String?  // Status when validation fails (default: "Condition Not Met")
        let statusChecking: String?         // Status during validation/download (default: "Checking...")
        let statusReadyToStart: String?     // Initial state status (default: "Ready to Start")
        let statusInProgress: String?       // Active step status (default: "In Progress")

        // MARK: - Preset9 Guide Layout Labels
        // Welcome screen customization
        let welcomeTitle: String?           // Welcome page title (default: "Welcome")
        let welcomeBadge: String?           // Welcome badge text (default: "GETTING STARTED")
        let welcomeParagraph1: String?      // Main welcome paragraph
        let welcomeParagraph2: String?      // Secondary welcome paragraph

        // Sidebar and section labels
        let guideInformationLabel: String?  // Sidebar section header (default: "Guide Information")
        let sectionsLabel: String?          // Page counter label (default: "SECTIONS")
        let keyPointsLabel: String?         // Content card header (default: "Key Points")

        // Minimal layout (alternative welcome screen)
        let getStartedTitle: String?        // Minimal welcome title (default: "Get Started")
        let getStartedSubtitle: String?     // Minimal welcome subtitle (default: "Follow the steps to complete setup")

        // Fallback messages
        let imageNotAvailable: String?      // Image error message (default: "Image not available")

        // MARK: - DEPRECATED: Compliance Labels
        // These fields are maintained for backward compatibility with Presets 1-4 configurations.
        // Use the dedicated `complianceLabels` struct instead.

        @available(*, deprecated, message: "Use complianceLabels.complianceStatus instead. Will be removed in v3.0.0")
        let complianceStatus: String?

        @available(*, deprecated, message: "Use complianceLabels.recommendedActions instead. Will be removed in v3.0.0")
        let recommendedActions: String?

        @available(*, deprecated, message: "Use complianceLabels.securityDetails instead. Will be removed in v3.0.0")
        let securityDetails: String?

        @available(*, deprecated, message: "Use complianceLabels.lastCheck instead. Will be removed in v3.0.0")
        let lastCheck: String?

        @available(*, deprecated, message: "Use complianceLabels.passed instead. Will be removed in v3.0.0")
        let passed: String?

        @available(*, deprecated, message: "Use complianceLabels.failed instead. Will be removed in v3.0.0")
        let failed: String?

        @available(*, deprecated, message: "Use complianceLabels.checksPassed instead. Will be removed in v3.0.0")
        let checksPassed: String?
    }

    /// Compliance dashboard labels (Preset5 specific)
    /// These are specialized labels for security compliance and validation workflows
    struct ComplianceLabels: Codable {
        let complianceStatus: String?       // Label for "Compliance Status"
        let recommendedActions: String?     // Label for "Recommended Actions"
        let securityDetails: String?        // Label for "Security Details"
        let lastCheck: String?              // Label for "Last Check"
        let passed: String?                 // Label for "passed"
        let failed: String?                 // Label for "failed"
        let checksPassed: String?           // Format for "X of Y checks passed" (use {passed}, {total})
    }

    /// Picker configuration (Global - all presets with picker support)
    /// Enables presets to function as single or multi-select pickers
    /// Used by Preset8, Preset9, and future presets that support picker mode
    struct PickerConfig: Codable {
        let selectionMode: String?          // "single" | "multi" | "none" (default: "none" = standard mode)
        let returnSelections: Bool?         // Write selections to output plist (default: false)
        let outputPath: String?             // Custom output plist path (default: "/tmp/picker_selections.plist")
        let allowContinueWithoutSelection: Bool? // Allow finishing without selection (default: false for single/multi)
    }

    /// Instruction banner configuration (Global - all presets)
    /// Displays a dismissible instruction banner at the top of the view
    struct InstructionBannerConfig: Codable {
        let text: String?                   // Banner message text (required if config present)
        let icon: String?                   // Optional SF Symbol icon name
        let autoDismiss: Bool?              // Auto-hide after delay (default: true)
        let dismissDelay: Double?           // Seconds before auto-hide (default: 5.0)
        let showOnce: Bool?                 // Show only on first page/step (default: false)
    }

    /// Picker mode labels (Global - all presets with picker support)
    /// Used when a preset operates in single-select or multi-select picker mode
    /// This provides consistent picker UI text across Preset8, Preset9, and future presets
    struct PickerLabels: Codable {
        // Selection action buttons
        let selectButtonText: String?       // Selection button text (default: "Select This")
        let selectedButtonText: String?     // Selected state button text (default: "✓ Selected")
        let deselectButtonText: String?     // Deselect button text for multi-mode (default: "Deselect")

        // Navigation (picker-specific overrides for multi-page pickers)
        let continueButton: String?         // Continue to next page (default: "Continue")
        let finishButton: String?           // Complete picker action (default: "Finish")
        let backButton: String?             // Go to previous page (default: "Previous")
        let pageCounterFormat: String?      // Page indicator format (default: "{current} / {total}")

        // User feedback and guidance
        let selectionPrompt: String?        // Top-level prompt text (e.g., "Select your desktop background")
        let selectionRequired: String?      // Error message when selection required but not made
        let multiSelectHint: String?        // Hint for multi-select mode (default: "You can select multiple items")
    }

    // Generic color threshold system for all presets
    struct ColorThresholds: Codable {
        let excellent: Double              // Default: 90%+ = Green
        let good: Double                   // Default: 70%+ = Blue  
        let warning: Double                // Default: 50%+ = Orange
        // Below warning = Red
        
        // Configurable labels for different use cases
        let excellentLabel: String?        // e.g., "Excellent", "Secure", "Complete"
        let goodLabel: String?             // e.g., "Good", "Safe", "In Progress"
        let warningLabel: String?          // e.g., "Warning", "At Risk", "Needs Attention"
        let criticalLabel: String?         // e.g., "Critical", "Unsafe", "Failed"
        
        // Configurable colors (hex strings)
        let excellentColor: String?        // Custom color for excellent range
        let goodColor: String?             // Custom color for good range
        let warningColor: String?          // Custom color for warning range
        let criticalColor: String?         // Custom color for critical range
        
        static let `default` = ColorThresholds(
            excellent: 0.9, good: 0.7, warning: 0.5,
            excellentLabel: nil, goodLabel: nil, warningLabel: nil, criticalLabel: nil,
            excellentColor: nil, goodColor: nil, warningColor: nil, criticalColor: nil
        )
        
        func getColor(for score: Double) -> Color {
            if score >= excellent {
                return excellentColor != nil ? Color(hex: excellentColor!) : .green
            } else if score >= good {
                return goodColor != nil ? Color(hex: goodColor!) : .blue
            } else if score >= warning {
                return warningColor != nil ? Color(hex: warningColor!) : .orange
            } else {
                return criticalColor != nil ? Color(hex: criticalColor!) : .red
            }
        }
        
        func getLabel(for score: Double) -> String {
            if score >= excellent {
                return excellentLabel ?? "Excellent"
            } else if score >= good {
                return goodLabel ?? "Good"
            } else if score >= warning {
                return warningLabel ?? "Warning"
            } else {
                return criticalLabel ?? "Critical"
            }
        }
        
        func getStatusIcon(for score: Double) -> String {
            if score >= excellent {
                return "checkmark.circle.fill"
            } else if score >= good {
                return "checkmark.circle"
            } else if score >= warning {
                return "exclamationmark.triangle.fill"
            } else {
                return "x.circle.fill"
            }
        }
        
        // Utility method for progress text
        func getProgressText(passed: Int, total: Int) -> String {
            let score = total > 0 ? Double(passed) / Double(total) : 0.0
            let percentage = Int(score * 100)
            return "\(passed)/\(total) (\(percentage)%)"
        }
        
        // Utility method for status badges
        func getStatusBadge(for score: Double) -> (color: Color, label: String, icon: String) {
            return (
                color: getColor(for: score),
                label: getLabel(for: score),
                icon: getStatusIcon(for: score)
            )
        }
        
        // Helper methods for flexible positive/negative color theming
        func getPositiveColor() -> Color {
            return excellentColor != nil ? Color(hex: excellentColor!) : .green
        }
        
        func getNegativeColor() -> Color {
            return criticalColor != nil ? Color(hex: criticalColor!) : .red
        }
        
        func getValidationColor(isValid: Bool) -> Color {
            return isValid ? getPositiveColor() : getNegativeColor()
        }
    }

    /// Custom encoder required because:
    /// 1. **Swift Limitation**: When implementing custom `init(from:)`, Swift requires matching `encode(to:)`
    /// 2. **Deprecated Field Exclusion**: Omits deprecated fields (button2Disabled, buttonStyle) from encoding
    ///
    /// Note: While InspectConfig is primarily used for *reading* JSON configs (not writing), Swift's
    /// Codable protocol requires both decoder and encoder when either is customized.
    ///
    /// Reference: https://www.hackingwithswift.com/books/ios-swiftui/adding-codable-conformance-for-published-properties
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(infobox, forKey: .infobox)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encodeIfPresent(iconsize, forKey: .iconsize)
        try container.encodeIfPresent(width, forKey: .width)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(size, forKey: .size)
        try container.encodeIfPresent(scanInterval, forKey: .scanInterval)
        try container.encodeIfPresent(cachePaths, forKey: .cachePaths)
        try container.encodeIfPresent(sideMessage, forKey: .sideMessage)
        try container.encodeIfPresent(sideInterval, forKey: .sideInterval)
        try container.encodeIfPresent(style, forKey: .style)
        try container.encodeIfPresent(liststyle, forKey: .liststyle)
        try container.encodeIfPresent(preset, forKey: .preset)
        try container.encodeIfPresent(popupButton, forKey: .popupButton)
        try container.encodeIfPresent(highlightColor, forKey: .highlightColor)
        try container.encodeIfPresent(secondaryColor, forKey: .secondaryColor)
        try container.encodeIfPresent(backgroundColor, forKey: .backgroundColor)
        try container.encodeIfPresent(backgroundImage, forKey: .backgroundImage)
        try container.encodeIfPresent(backgroundOpacity, forKey: .backgroundOpacity)
        try container.encodeIfPresent(textOverlayColor, forKey: .textOverlayColor)
        try container.encodeIfPresent(gradientColors, forKey: .gradientColors)
        try container.encodeIfPresent(button1Text, forKey: .button1Text)
        try container.encodeIfPresent(button1Disabled, forKey: .button1Disabled)
        try container.encodeIfPresent(button2Text, forKey: .button2Text)
        try container.encodeIfPresent(button2Visible, forKey: .button2Visible)
        try container.encodeIfPresent(autoEnableButton, forKey: .autoEnableButton)
        try container.encodeIfPresent(autoEnableButtonText, forKey: .autoEnableButtonText)
        try container.encodeIfPresent(hideSystemDetails, forKey: .hideSystemDetails)
        try container.encodeIfPresent(colorThresholds, forKey: .colorThresholds)
        try container.encodeIfPresent(plistSources, forKey: .plistSources)
        try container.encodeIfPresent(categoryHelp, forKey: .categoryHelp)
        try container.encodeIfPresent(uiLabels, forKey: .uiLabels)
        try container.encodeIfPresent(complianceLabels, forKey: .complianceLabels)
        try container.encodeIfPresent(pickerConfig, forKey: .pickerConfig)
        try container.encodeIfPresent(instructionBanner, forKey: .instructionBanner)
        try container.encodeIfPresent(pickerLabels, forKey: .pickerLabels)
        try container.encodeIfPresent(banner, forKey: .banner)
        try container.encodeIfPresent(bannerHeight, forKey: .bannerHeight)
        try container.encodeIfPresent(bannerTitle, forKey: .bannerTitle)
        try container.encodeIfPresent(iconBasePath, forKey: .iconBasePath)
        try container.encodeIfPresent(rotatingImages, forKey: .rotatingImages)
        try container.encodeIfPresent(imageRotationInterval, forKey: .imageRotationInterval)
        try container.encodeIfPresent(imageShape, forKey: .imageShape)
        try container.encodeIfPresent(imageSyncMode, forKey: .imageSyncMode)
        try container.encodeIfPresent(stepStyle, forKey: .stepStyle)
        try container.encodeIfPresent(listIndicatorStyle, forKey: .listIndicatorStyle)
        try container.encodeIfPresent(extraButton, forKey: .extraButton)
        try container.encodeIfPresent(progressBarConfig, forKey: .progressBarConfig)
        try container.encodeIfPresent(logoConfig, forKey: .logoConfig)
        try container.encode(items, forKey: .items)
    }

    // MARK: - Custom Codable Implementation

    /// Custom decoder required for:
    /// 1. **Backward Compatibility**: Decode deprecated fields (button2Disabled, buttonStyle) but discard values
    /// 2. **Default Values**: Provide fallback for missing optional arrays (e.g., items defaults to [])
    ///
    /// Without this custom implementation, the synthesized decoder would:
    /// - Fail to decode configs with deprecated fields if those fields were removed from the struct
    /// - Require explicit handling of nil optionals throughout the codebase
    ///
    /// This enables safe JSON parsing of both legacy and modern config files.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        title = try container.decodeIfPresent(String.self, forKey: .title)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        infobox = try container.decodeIfPresent(String.self, forKey: .infobox)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        iconsize = try container.decodeIfPresent(Int.self, forKey: .iconsize)
        width = try container.decodeIfPresent(Int.self, forKey: .width)
        height = try container.decodeIfPresent(Int.self, forKey: .height)
        size = try container.decodeIfPresent(String.self, forKey: .size)
        scanInterval = try container.decodeIfPresent(Int.self, forKey: .scanInterval)
        cachePaths = try container.decodeIfPresent([String].self, forKey: .cachePaths)
        sideMessage = try container.decodeIfPresent([String].self, forKey: .sideMessage)
        sideInterval = try container.decodeIfPresent(Int.self, forKey: .sideInterval)
        style = try container.decodeIfPresent(String.self, forKey: .style)
        liststyle = try container.decodeIfPresent(String.self, forKey: .liststyle)
        preset = try container.decodeIfPresent(String.self, forKey: .preset)
        popupButton = try container.decodeIfPresent(String.self, forKey: .popupButton)
        highlightColor = try container.decodeIfPresent(String.self, forKey: .highlightColor)
        secondaryColor = try container.decodeIfPresent(String.self, forKey: .secondaryColor)
        backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor)
        backgroundImage = try container.decodeIfPresent(String.self, forKey: .backgroundImage)
        backgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .backgroundOpacity)
        textOverlayColor = try container.decodeIfPresent(String.self, forKey: .textOverlayColor)
        gradientColors = try container.decodeIfPresent([String].self, forKey: .gradientColors)
        button1Text = try container.decodeIfPresent(String.self, forKey: .button1Text)
        button1Disabled = try container.decodeIfPresent(Bool.self, forKey: .button1Disabled)
        finalButtonText = try container.decodeIfPresent(String.self, forKey: .finalButtonText)
        button2Text = try container.decodeIfPresent(String.self, forKey: .button2Text)

        // DEPRECATED: button2Disabled - Decode but ignore for backward compatibility
        // Buttons are always enabled when shown. Use button2Visible to control visibility.
        _ = try container.decodeIfPresent(Bool.self, forKey: .button2Disabled)

        button2Visible = try container.decodeIfPresent(Bool.self, forKey: .button2Visible)

        // DEPRECATED: buttonStyle - Decode but ignore for backward compatibility
        // Not used in Inspect mode. Each preset has its own fixed button styling.
        _ = try container.decodeIfPresent(String.self, forKey: .buttonStyle)
        autoEnableButton = try container.decodeIfPresent(Bool.self, forKey: .autoEnableButton)
        autoEnableButtonText = try container.decodeIfPresent(String.self, forKey: .autoEnableButtonText)
        hideSystemDetails = try container.decodeIfPresent(Bool.self, forKey: .hideSystemDetails)
        observeOnly = try container.decodeIfPresent(Bool.self, forKey: .observeOnly)
        colorThresholds = try container.decodeIfPresent(ColorThresholds.self, forKey: .colorThresholds)
        plistSources = try container.decodeIfPresent([PlistSourceConfig].self, forKey: .plistSources)
        categoryHelp = try container.decodeIfPresent([CategoryHelp].self, forKey: .categoryHelp)
        uiLabels = try container.decodeIfPresent(UILabels.self, forKey: .uiLabels)
        complianceLabels = try container.decodeIfPresent(ComplianceLabels.self, forKey: .complianceLabels)
        pickerConfig = try container.decodeIfPresent(PickerConfig.self, forKey: .pickerConfig)
        instructionBanner = try container.decodeIfPresent(InstructionBannerConfig.self, forKey: .instructionBanner)
        pickerLabels = try container.decodeIfPresent(PickerLabels.self, forKey: .pickerLabels)

        // Banner configuration
        banner = try container.decodeIfPresent(String.self, forKey: .banner)
        bannerHeight = try container.decodeIfPresent(Int.self, forKey: .bannerHeight)
        bannerTitle = try container.decodeIfPresent(String.self, forKey: .bannerTitle)

        // Preset6 specific properties
        iconBasePath = try container.decodeIfPresent(String.self, forKey: .iconBasePath)
        rotatingImages = try container.decodeIfPresent([String].self, forKey: .rotatingImages)
        imageRotationInterval = try container.decodeIfPresent(Double.self, forKey: .imageRotationInterval)
        imageShape = try container.decodeIfPresent(String.self, forKey: .imageShape)
        imageSyncMode = try container.decodeIfPresent(String.self, forKey: .imageSyncMode)
        stepStyle = try container.decodeIfPresent(String.self, forKey: .stepStyle)
        listIndicatorStyle = try container.decodeIfPresent(String.self, forKey: .listIndicatorStyle)
        extraButton = try container.decodeIfPresent(ExtraButtonConfig.self, forKey: .extraButton)
        progressBarConfig = try container.decodeIfPresent(ProgressBarConfig.self, forKey: .progressBarConfig)
        logoConfig = try container.decodeIfPresent(LogoConfig.self, forKey: .logoConfig)

        // Default to empty array if items not provided
        items = try container.decodeIfPresent([ItemConfig].self, forKey: .items) ?? []
    }
    
    private enum CodingKeys: String, CodingKey {
        case title, message, infobox, icon, iconsize, banner, bannerHeight, bannerTitle
        case width, height, size, scanInterval, cachePaths
        case sideMessage, sideInterval, style, liststyle, preset, popupButton
        case highlightColor, secondaryColor, backgroundColor, backgroundImage, backgroundOpacity
        case textOverlayColor, gradientColors
        case button1Text = "button1text"
        case button1Disabled = "button1disabled"
        case finalButtonText = "finalButtonText"
        case button2Text = "button2text"

        // DEPRECATED: button2Disabled - Buttons are always enabled when shown
        // Backward compatibility: Field is decoded but ignored
        // Removal timeline: v3.0.0 (post Presets 5-9 public release)
        case button2Disabled = "button2disabled"

        case button2Visible = "button2visible"

        // DEPRECATED: buttonStyle - Not used in Inspect mode
        // Backward compatibility: Field is decoded but ignored
        // Removal timeline: v3.0.0 (post Presets 5-9 public release)
        case buttonStyle
        case autoEnableButton, autoEnableButtonText, hideSystemDetails, observeOnly, colorThresholds, plistSources, categoryHelp, uiLabels, complianceLabels, pickerConfig, instructionBanner, pickerLabels, items
        // Preset6 specific properties
        case iconBasePath, rotatingImages, imageRotationInterval, imageShape, imageSyncMode, stepStyle, listIndicatorStyle
        // Extra button configuration
        case extraButton
        // Progress bar configuration
        case progressBarConfig
        // Logo overlay configuration
        case logoConfig
    }
}
