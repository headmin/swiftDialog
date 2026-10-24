//
//  InspectConstants.swift
//  dialog
//

import SwiftUI

/// Central configuration constants for inspect functionality
struct InspectConstants {
    // MARK: - File Paths
    static let commandFilePath = "/var/tmp/dialog.log"
    static let tempConfigPath = "/tmp/appmonitor_config.json"
    static let applicationsPath = "/Applications"
    static let libraryApplicationSupportPath = "/Library/Application Support"
    
    // MARK: - Timing Configuration
    static let fallbackTimerInterval: TimeInterval = 30.0
    static let fsEventsLatency: TimeInterval = 0.1
    static let cacheTimeout: TimeInterval = 60.0
    static let debounceDelay: TimeInterval = 0.1
    static let updateTimerInterval: TimeInterval = 5.0
    static let fileSystemCheckInterval: TimeInterval = 3.0
    static let robustUpdateInterval: TimeInterval = 2.0
    /// How often a preset re-reads plist-backed item statuses (Presets 3 and 4). Slow on purpose:
    /// a faster poll competes with the software being installed. `IntroStepMonitorService` has
    /// its own clocks.
    static let plistPollInterval: TimeInterval = 3.0
    
    // MARK: - UI Animation
    static let standardAnimationDuration: TimeInterval = 0.3
    static let longAnimationDuration: TimeInterval = 0.5
    static let scaleAnimationDuration: TimeInterval = 0.2
    static let stepTransition: Animation = .interpolatingSpring(mass: 2, stiffness: 300, damping: 50)
    /// Preset5 step cross-fade; short so the two steps are not double-exposed for long.
    static let stepCrossfade: Animation = .easeInOut(duration: 0.3)
    static let snappyExit: Animation = .interpolatingSpring(mass: 0.75, stiffness: 350, damping: 20)
    
    // MARK: - Performance Limits
    static let maxRetryAttempts = 3
    static let maxCacheEntries = 100
    static let maxMemoryUsage = 10_000_000 // 10MB
    
    // MARK: - UI Layout
    static let sideMessageInterval: TimeInterval = 10.0
    static let progressCompletionDelay: TimeInterval = 2.0

    // MARK: - Spacing Scale (12pt base grid)
    // Content within a group sits `spacingInner` apart, sibling groups `spacingOuter` apart.
    // Multiply by scaleFactor at the call site where a view already scales.
    static let spacingGridUnit: CGFloat = 12         // base unit
    static let spacingIntra: CGFloat = 6             // 0.5u — inside one element (icon → caption)
    static let spacingInner: CGFloat = 12            // 1u   — within a group (label → its content)
    static let spacingSection: CGFloat = 24          // 2u   — header → first section
    static let spacingOuter: CGFloat = 36            // 3u   — between sibling groups

    // MARK: - Footer Insets
    // Live in InspectMetrics.phaseFooterHorizontal / .phaseFooterBottom; never restate them at a button site.

    // MARK: - UI Scale Factors
    static let miniScaleFactor: CGFloat = 0.75
    static let defaultScaleFactor: CGFloat = 1.0
    
    // MARK: - Additional Delays
    static let manualScrollTimeoutInterval: TimeInterval = 5.0
    static let buttonStateUpdateDelay: TimeInterval = 1.0
    static let retryMonitoringDelay: TimeInterval = 0.5
    static let startupDelay: TimeInterval = 1.0
    
    // MARK: - Monitoring Configuration
    static let inspectQueueQoS = DispatchQoS.background
    static let inspectQueueLabel = "app.inspect"
}
