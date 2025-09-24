//
//  InspectState.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 19/07/2025
//

import Foundation
import SwiftUI

enum LoadingState: Equatable {
    case loading
    case loaded
    case failed(String)
}

enum ConfigurationSource {
    case file(path: String)
    case testData
    case fallback
}

// MARK: - Configuration Structs for Grouped State

struct UIConfiguration {
    var windowTitle: String = "System Inspection"
    var statusMessage: String = "Inspection active - Items will appear as they are detected"
    var iconPath: String?
    var iconBasePath: String?  // Base path for relative icon paths
    var sideMessages: [String] = []
    var currentSideMessageIndex: Int = 0
    var popupButtonText: String = "Install details..."
    var preset: String = "preset1"
    var highlightColor: String = "#808080"
    var iconSize: Int = 120
    var subtitleMessage: String?

    // Window sizing configuration
    var width: Int?                // Custom width override
    var height: Int?               // Custom height override
    var size: String?              // Size mode: "compact", "standard", or "large"

    // Banner configuration (optional - preserves logo display when not set)
    var bannerImage: String?        // Path to banner image
    var bannerHeight: Int = 100     // Default banner height
    var bannerTitle: String?        // Optional title overlay on banner

    // Preset6 specific properties
    var rotatingImages: [String] = []
    var imageRotationInterval: Double = 4.0
    var imageFormat: String = "square"     // "square" | "rectangle" | "round"
    var imageSyncMode: String = "manual"   // "manual" | "sync" | "auto"
    var stepStyle: String = "plain"        // "plain" | "colored" | "cards"
}

struct BackgroundConfiguration {
    var backgroundColor: String?
    var backgroundImage: String?
    var backgroundOpacity: Double = 1.0
    var textOverlayColor: String?
    var gradientColors: [String] = []
}

struct ButtonConfiguration {
    var button1Text: String = "OK"           // Text during progress/installation
    var button1Disabled: Bool = false
    var button2Text: String = "Cancel"       // Optional second button text
    var button2Visible: Bool = true          // Show second button when complete
    var autoEnableButton: Bool = true
    // Note: button2Disabled removed - button2 is always enabled when shown
    // Note: buttonStyle removed - not used in Inspect mode
}

class InspectState: ObservableObject, FileMonitorDelegate {
    // MARK: - Core State (Keep as @Published)
    @Published var loadingState: LoadingState = .loading
    @Published var items: [InspectConfig.ItemConfig] = []
    @Published var config: InspectConfig?
    
    // MARK: - Grouped Configuration State
    @Published var uiConfiguration = UIConfiguration()
    @Published var backgroundConfiguration = BackgroundConfiguration()
    @Published var buttonConfiguration = ButtonConfiguration()
    
    // MARK: - Preset-specific State
    @Published var plistSources: [InspectConfig.PlistSourceConfig]?
    @Published var colorThresholds: InspectConfig.ColorThresholds = InspectConfig.ColorThresholds.default
    @Published var plistValidationResults: [String: Bool] = [:] // Track plist validation results
    
    // MARK: - View-specific State (Should be @State in views, but keeping for now)
    @Published var scrollOffset: Int = 0 // Manual scroll offset, currently needed in preset3
    @Published var lastManualScrollTime: Date? // Track manual scrolling
    
    // MARK: - Dynamic State (Needs @Published for UI updates)
    @Published var completedItems: Set<String> = []
    @Published var downloadingItems: Set<String> = []
    
    private var appInspector: AppInspector?
    private var configPath: String?
    private var lastCommandFileSize: Int = 0
    private var lastProcessedLineCount: Int = 0
    private var commandFileMonitor: DispatchSourceFileSystemObject?
    private var updateTimer: Timer?
    private var fileSystemCheckTimer: Timer?
    private var sideMessageTimer: Timer?
    private var debouncedUpdater = DebouncedUpdater()
    private let fileSystemCache = FileSystemCache()

    // FSEvents priority tracking - prevent timer interference
    private var fsEventsTimestamps: [String: Date] = [:]
    private let fsEventsPriorityWindow: TimeInterval = 10.0 // 10 seconds

    private let fsEventsMonitor = FileMonitor()
    private var lastFSEventTime: Date?
    private var lastLogTime: Date = Date()
    
    // MARK: - Base Business Logic Services initialize
    private let validationService = Validation()
    private let configurationService = Config()
    
    func initialize() {
        writeLog("InspectState.initialize() - Starting initialization", logLevel: .info)
        
        loadConfiguration()
        startMonitoring()
        
        writeLog("InspectState: Memory-safe initialization complete", logLevel: .info)
    }
    
    private func loadConfiguration() {
        // Use configuration service to load config
        let result = configurationService.loadConfiguration()
        
        switch result {
        case .success(let configResult):
            // Log warnings from configuration validation 
            // TODO: Learn how best type-chcek in swift
            for warning in configResult.warnings {
                writeLog("InspectState: Configuration warning - \(warning)", logLevel: .info)
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let loadedConfig = configResult.config
                
                // Set core configuration
                self.config = loadedConfig
                self.items = loadedConfig.items.sorted { $0.guiIndex < $1.guiIndex }
                
                // Set plist sources from config - required inpreset5
                self.plistSources = loadedConfig.plistSources
                
                // Set color thresholds from config or use defaults
                if let colorThresholds = loadedConfig.colorThresholds {
                    self.colorThresholds = colorThresholds
                    writeLog("InspectState: Using custom color thresholds - Excellent: \(colorThresholds.excellent), Good: \(colorThresholds.good), Warning: \(colorThresholds.warning)", logLevel: .info)
                } else {
                    self.colorThresholds = InspectConfig.ColorThresholds.default
                    writeLog("InspectState: Using default color thresholds", logLevel: .info)
                }
                
                // Use configuration service to extract grouped configurations
                print("InspectState: About to extract configurations")
                print("InspectState: loadedConfig.banner = \(loadedConfig.banner ?? "nil")")
                self.uiConfiguration = self.configurationService.extractUIConfiguration(from: loadedConfig)
                print("InspectState: After extraction - uiConfiguration.bannerImage = \(self.uiConfiguration.bannerImage ?? "nil")")
                print("InspectState: After extraction - uiConfiguration.iconBasePath = \(self.uiConfiguration.iconBasePath ?? "nil")")
                self.backgroundConfiguration = self.configurationService.extractBackgroundConfiguration(from: loadedConfig)
                self.buttonConfiguration = self.configurationService.extractButtonConfiguration(from: loadedConfig)
                
                // Set side message rotation if multiple messages exist
                if self.uiConfiguration.sideMessages.count > 1, let interval = loadedConfig.sideInterval {
                    self.startSideMessageRotation(interval: TimeInterval(interval))
                }
                
                // Debug logging for preset detection
                if appvars.debugMode { print("DEBUG: loadedConfig.preset = \(loadedConfig.preset ?? "nil")") }
                if appvars.debugMode { print("DEBUG: Setting preset to: \(self.uiConfiguration.preset)") }
                
                writeLog("InspectState: Loaded \(loadedConfig.items.count) items from config", logLevel: .info)
                writeLog("InspectState: Title: \(self.uiConfiguration.windowTitle)", logLevel: .debug)
                writeLog("InspectState: Using preset: \(self.uiConfiguration.preset)", logLevel: .info)
                if !self.uiConfiguration.sideMessages.isEmpty {
                    writeLog("InspectState: Side messages: \(self.uiConfiguration.sideMessages.count)", logLevel: .debug)
                }
                
                // Log configuration source
                switch configResult.source {
                case .file(let path):
                    writeLog("InspectState: Configuration loaded from file: \(path)", logLevel: .info)
                    self.configPath = path
                case .testData:
                    writeLog("InspectState: Using fallback test data configuration", logLevel: .info)
                case .fallback:
                    writeLog("InspectState: Using fallback configuration", logLevel: .info)
                }
                
                // Here, configuration loaded successfully
                self.loadingState = .loaded
                
                // Validate items to populate results dict
                self.validateAllItems()

                // Once config is loaded, start FSEvents monitoring for UI updates
                self.setupOptimizedFileMonitoring()

                // Initialize progress tracker
                self.initializeProgressTracker()
            }
            
        case .failure(let error):
            writeLog("InspectState: Configuration loading failed - \(error.localizedDescription)", logLevel: .error)
            DispatchQueue.main.async { [weak self] in
                self?.loadingState = .failed(error.localizedDescription)
            }
        }
    }
    
    
    func retryConfiguration() {
        DispatchQueue.main.async { [weak self] in
            self?.loadingState = .loading
        }
        loadConfiguration()
    }
    
    
    private func startMonitoring() {
        writeLog("InspectState.startMonitoring() - Starting all monitoring components", logLevel: .info)
        
        // Create AppInspector for filesystem monitoring
        appInspector = AppInspector()
        
        // Next, configure AppInspector if we have config data
        if let config = config {
            loadAppInspectConfig(config: config, originalPath: configPath ?? "")
        }
        
        // Setup command file monitoring for continued status updates
        setupCommandFileMonitoring()
        
        // Setup periodic updates as backup detection method
        setupOptimizedPeriodicUpdates()

        // Note: FSEvents monitoring is setup in loadConfiguration() after config is loaded
        // Don't call setupOptimizedFileMonitoring() here as config isn't loaded yet

        writeLog("InspectState: All monitoring components started successfully", logLevel: .info)
    }
    
    private func setupCommandFileMonitoring() {
        // Look into this for memory-safety checks - our command file monitoring setup is sensitive, we want avoid leaks
        let commandFilePath = InspectConstants.commandFilePath
        
        guard FileManager.default.fileExists(atPath: commandFilePath) else {
            writeLog("InspectState: Command file doesn't exist yet: \(commandFilePath)", logLevel: .debug)
            return
        }
        
        // Prevent multiple monitoring setups
        guard commandFileMonitor == nil else {
            writeLog("InspectState: Command file monitoring already set up", logLevel: .debug)
            return
        }
        
        // Create command file monitor with weak self to prevent retain cycles
        let fileHandle = open(commandFilePath, O_EVTONLY)
        guard fileHandle >= 0 else {
            writeLog("InspectState: Unable to open command file for monitoring: \(commandFilePath)", logLevel: .error)
            return
        }
        
        commandFileMonitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileHandle,
            eventMask: .write,
            queue: DispatchQueue.global(qos: .utility)
        )
        
        commandFileMonitor?.setEventHandler { [weak self] in
            // Use weak self to prevent memory leaks in nested closures
            guard let self = self else { return }
            self.debouncedUpdater.debounce(key: "command-file-update") { [weak self] in
                self?.updateAppStatus()
            }
        }
        
        commandFileMonitor?.setCancelHandler {
            close(fileHandle)
        }
        
        commandFileMonitor?.resume()
        writeLog("DispatchSource file monitoring active", logLevel: .info)
    }
    
    private func setupOptimizedPeriodicUpdates() {
        // Periodic updates with weak self references
        updateTimer?.invalidate()
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: InspectConstants.robustUpdateInterval, repeats: true) { [weak self] _ in
            // Again, use weak self to prevent memory leaks
            self?.performRobustAppCheck()
        }
        
        writeLog("Timer-based monitoring active", logLevel: .info)
    }
    
    private func setupOptimizedFileMonitoring() {
        // Instantiate FSEvents monitoring setup
        let cachePaths = config?.cachePaths ?? []
        
        guard !cachePaths.isEmpty else {
            writeLog("InspectState: No cache paths configured for FSEvents monitoring", logLevel: .debug)
            return
        }
        
        // Set up FSEvents monitor with our delegate pattern
        fsEventsMonitor.delegate = self
        fsEventsMonitor.startMonitoring(items: items, cachePaths: cachePaths)
        
        writeLog("FSEvents monitoring active", logLevel: .info)
    }
    
    private func performRobustAppCheck() {
        // Simple, timer-based monitoring - checks all app states every 2 seconds
        // This ensures 100% reliability for detecting app installations
        
        // Only log every 30 seconds to avoid memory accumulation
        if Date().timeIntervalSince(lastLogTime) > 30.0 {
            writeLog("InspectState: App status monitoring active", logLevel: .debug)
            lastLogTime = Date()
        }
        
        // Always check command file for updates (external status changes)
        checkCommandFileForUpdates()
        
        // Check all app installation statuses directly
        checkDirectInstallationStatus()
    }
    
    // MARK: - FileMonitorDelegate Implementation (Cache-only)
    
    func appInstalled(_ appId: String, at path: String) {
        // App installations are handled by robust timer polling
        // FSEvents only used for pre-loaded cachePaths monitoring
        writeLog("InspectState: FSEvents app install ignored - handled by timer polling", logLevel: .debug)
    }
    
    func appUninstalled(_ appId: String, at path: String) {
        // App uninstalls are handled by robust timer polling
        // FSEvents only used for pre-loaded cachePaths  monitoring 
        writeLog("InspectState: FSEvents app uninstall ignored - handled by timer polling", logLevel: .debug)
    }
    
    func cacheFileCreated(_ path: String) {
        lastFSEventTime = Date()

        // Extract just the filename from the full path for logging
        let filename = (path as NSString).lastPathComponent
        writeLog("InspectState: FSEvents detected new cache file: '\(filename)' at path: \(path)", logLevel: .info)

        // Simply invalidate cache - let timer polling handle state updates
        // This prevents race conditions between FSEvents and timer
        let parentPath = (path as NSString).deletingLastPathComponent
        fileSystemCache.invalidateCache(for: parentPath)
        writeLog("InspectState: Invalidated cache for directory: \(parentPath) - timer will update status", logLevel: .debug)

        // Optionally trigger immediate timer check for responsiveness
        DispatchQueue.main.async { [weak self] in
            self?.performRobustAppCheck()
        }
    }
    
    func cacheFileRemoved(_ path: String) {
        lastFSEventTime = Date()

        // Extract just the filename from the full path for logging
        let filename = (path as NSString).lastPathComponent
        writeLog("InspectState: FSEvents detected cache file removal: '\(filename)' at path: \(path)", logLevel: .info)

        // Simply invalidate cache - let timer polling handle state updates
        // This prevents race conditions between FSEvents and timer
        let parentPath = (path as NSString).deletingLastPathComponent
        fileSystemCache.invalidateCache(for: parentPath)
        writeLog("InspectState: Invalidated cache for directory: \(parentPath) - timer will update status", logLevel: .debug)

        // Optionally trigger immediate timer check for responsiveness
        DispatchQueue.main.async { [weak self] in
            self?.performRobustAppCheck()
        }
    }
    
    private func cacheFileMatchesItem(_ filePath: String, item: InspectConfig.ItemConfig) -> Bool {
        let filename = (filePath as NSString).lastPathComponent
        let lowercaseFile = filename.lowercased()
        _ = item.id.lowercased()
        _ = item.displayName.lowercased().replacingOccurrences(of: " ", with: "")

        let isDownloadFile = lowercaseFile.hasSuffix(".download") ||
                            lowercaseFile.hasSuffix(".pkg") ||
                            lowercaseFile.hasSuffix(".dmg")

        guard isDownloadFile else { return false }

        // Use smart matching for better detection
        return smartFilenameMatch(itemId: item.id, displayName: item.displayName, filename: filename)
    }
    
    private func updateAppStatus() {
        // Check for command file updates and direct filesystem status
        checkCommandFileForUpdates()
        checkDirectInstallationStatus()
    }
    
    private func checkCommandFileForUpdates() {
        let commandFilePath = InspectConstants.commandFilePath
        
        guard FileManager.default.fileExists(atPath: commandFilePath) else {
            return
        }
        
        do {
            let content = try String(contentsOfFile: commandFilePath, encoding: .utf8)
            let currentSize = content.count
            let lines = content.components(separatedBy: .newlines)
            let currentLineCount = lines.count
            
            // Only process if file has actually changed
            if currentSize != lastCommandFileSize || currentLineCount != lastProcessedLineCount {
                
                // Process only new lines since last check (more efficient)
                let newLines = Array(lines.dropFirst(max(0, lastProcessedLineCount)))
                
                if !newLines.isEmpty {
                    writeLog("InspectState: Processing \(newLines.count) new command lines", logLevel: .debug)
                    
                    for line in newLines where !line.isEmpty {
                            parseCommandLine(line)
                    }
                }
                
                lastCommandFileSize = currentSize
                lastProcessedLineCount = currentLineCount
                writeLog("InspectState: Command file updated (size: \(currentSize), lines: \(currentLineCount))", logLevel: .debug)
            }
        } catch {
            writeLog("InspectState: Error reading command file: \(error)", logLevel: .error)
        }
    }
    
    private func checkDirectInstallationStatus() {
        // Direct filesystem check - this is our backup detection method
        guard !items.isEmpty else { return }
        
        var changesDetected = false
        
        for item in items {
            let wasCompleted = completedItems.contains(item.id)
            let wasDownloading = downloadingItems.contains(item.id)
            
            // Path checking - stop at first found path
            let isInstalled = item.paths.first { path in
                FileManager.default.fileExists(atPath: path)
            } != nil
            
            // Only check cache if not already installed (for performance optimization)
            let isDownloading = !isInstalled && checkCacheForItem(item)
            
            // Apply changes only if status actually changed
            if isInstalled && !wasCompleted {
                self.debouncedUpdater.debounce(key: "item-install-\(item.id)") { [weak self] in
                    guard let self = self else { return }
                    self.completedItems.insert(item.id)
                    self.downloadingItems.remove(item.id)

                    // Check if this was the last item to complete
                    if self.completedItems.count == self.items.count {
                        writeLog("InspectState: All items completed - triggering button state update", logLevel: .info)
                        // Introduce a small delay to ensure UI state is updated
                        DispatchQueue.main.asyncAfter(deadline: .now() + InspectConstants.debounceDelay) { [weak self] in
                            self?.checkAndUpdateButtonState()
                        }
                    }
                }
                writeLog("InspectState: FILESYSTEM - \(item.displayName) detection completed", logLevel: .info)
                changesDetected = true

            } else if !isInstalled && wasCompleted {
                // App was installed but now deleted - check if still downloading
                if isDownloading {
                    self.debouncedUpdater.debounce(key: "item-download-\(item.id)") { [weak self] in
                        guard let self = self else { return }
                        self.completedItems.remove(item.id)
                        self.downloadingItems.insert(item.id)
                    }
                    writeLog("InspectState: FILESYSTEM - \(item.displayName) deleted but still downloading", logLevel: .info)
                } else {
                    self.debouncedUpdater.debounce(key: "item-remove-\(item.id)") { [weak self] in
                        guard let self = self else { return }
                        self.completedItems.remove(item.id)
                        self.downloadingItems.remove(item.id)
                    }
                    writeLog("InspectState: FILESYSTEM - \(item.displayName) deleted, reset to pending", logLevel: .info)
                }
                changesDetected = true

            } else if isDownloading && !wasDownloading {
                self.debouncedUpdater.debounce(key: "item-downloading-\(item.id)") { [weak self] in
                    guard let self = self else { return }
                    self.downloadingItems.insert(item.id)
                    writeLog("InspectState: Added \(item.id) to downloadingItems (cache detected)", logLevel: .info)
                }
                writeLog("InspectState: FILESYSTEM - \(item.displayName) downloading", logLevel: .info)
                changesDetected = true
                
            } else if !isDownloading && !isInstalled && (wasDownloading || wasCompleted) {
                // Simplified state management - single source of truth
                // Only reset to pending if cache file doesn't exist
                if !checkCacheForItem(item) {
                    self.debouncedUpdater.debounce(key: "item-pending-\(item.id)") { [weak self] in
                        guard let self = self else { return }
                        self.downloadingItems.remove(item.id)
                        self.completedItems.remove(item.id)
                        // Clear any tracking timestamps
                        self.fsEventsTimestamps.removeValue(forKey: item.id)
                        writeLog("InspectState: \(item.displayName) reset to pending (no cache file)", logLevel: .info)
                    }
                }
                changesDetected = true
            }
        }
        
        if changesDetected {
            writeLog("InspectState: Filesystem check detected status changes", logLevel: .debug)
        }
    }
    
    private func loadAppInspectConfig(config: InspectConfig, originalPath: String) {
        // Convert InspectConfig to AppInspector.AppConfig format
        // TODO: Consolidate this with AppInspector/AppInspectorConfig structures
        do {
            // Create AppInspector compatible structure
            let appInspectorApps = config.items.map { item in
                return [
                    "id": item.id,
                    "displayName": item.displayName,
                    "guiIndex": item.guiIndex,
                    "paths": item.paths
                ] as [String: Any]
            }
            
            var appInspectConfig: [String: Any] = [
                "apps": appInspectorApps
            ]
            
            if let cachePaths = config.cachePaths {
                appInspectConfig["cachePaths"] = cachePaths
            }
            
            // Convert to JSON data and write to a temporary file for AppInspector to load
            let jsonData = try JSONSerialization.data(withJSONObject: appInspectConfig, options: [])
            let tempConfigPath = InspectConstants.tempConfigPath
            try jsonData.write(to: URL(fileURLWithPath: tempConfigPath))
            
            // Load the converted config into AppInspector
            appInspector?.loadConfig(from: tempConfigPath)
            
            // Start AppInspector filesystem monitoring
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.appInspector?.start()
                writeLog("InspectState: AppInspector filesystem monitoring started", logLevel: .info)
            }
            
            writeLog("InspectState: Successfully converted and loaded config for AppInspector", logLevel: .info)
            
        } catch {
            writeLog("InspectState: Failed to convert config for AppInspector: \(error)", logLevel: .error)
        }
    }
    
    private func checkCacheForItem(_ item: InspectConfig.ItemConfig) -> Bool {
        guard let config = config, let cachePaths = config.cachePaths else { return false }

        writeLog("InspectState: Checking cache for item '\(item.id)' (display: '\(item.displayName)')", logLevel: .debug)

        // Use the optimized containsMatchingFile method to avoid unnecessary memory allocations
        for cachePath in cachePaths {
            // ALWAYS invalidate and re-read the cache to ensure we have fresh data
            fileSystemCache.invalidateCache(for: cachePath)
            let cacheContents = fileSystemCache.cacheDirectoryContents(cachePath)

            // Log what's actually in the cache for debugging
            if cacheContents.isEmpty {
                writeLog("InspectState:   Cache directory '\(cachePath)' is empty", logLevel: .debug)
            } else {
                writeLog("InspectState:   Files in cache (\(cacheContents.count) total): \(cacheContents.prefix(3).joined(separator: ", "))\(cacheContents.count > 3 ? "..." : "")", logLevel: .debug)
            }

            // Filter for download files
            let downloadFiles = cacheContents.filter { file in
                // Skip hidden files like .DS_Store
                guard !file.hasPrefix(".") else { return false }

                return file.lowercased().hasSuffix(".download") ||
                       file.lowercased().hasSuffix(".pkg") ||
                       file.lowercased().hasSuffix(".dmg")
            }

            if downloadFiles.isEmpty {
                writeLog("InspectState:   No package files found (looked for .pkg, .dmg, .download)", logLevel: .debug)
            } else {
                for file in downloadFiles {
                    writeLog("InspectState:   Found package: '\(file)'", logLevel: .debug)
                }
            }

            // Now check if any match this item
            let hasMatchingFile = downloadFiles.contains { file in
                let matches = smartFilenameMatch(itemId: item.id, displayName: item.displayName, filename: file)

                if matches {
                    writeLog("InspectState:   ✓ SMART MATCH: '\(file)' matches item '\(item.id)'", logLevel: .info)
                } else {
                    writeLog("InspectState:   ✗ No match: '\(file)' vs item '\(item.id)'", logLevel: .debug)
                }

                return matches
            }

            if hasMatchingFile {
                writeLog("InspectState: ✓ Cache match found for '\(item.id)' in \(cachePath)", logLevel: .info)
                return true
            }
        }
        writeLog("InspectState: No cache match for '\(item.id)'", logLevel: .debug)
        return false
    }

    /// Smart filename matching algorithm for package cache detection
    /// Handles cases like: microsoft_outlook → Microsoft_Outlook_16.101.25091314_Installer.pkg
    private func smartFilenameMatch(itemId: String, displayName: String, filename: String) -> Bool {
        let cleanFilename = filename.lowercased()
        let cleanItemId = itemId.lowercased()
        let cleanDisplayName = displayName.lowercased().replacingOccurrences(of: " ", with: "")

        // Additional normalization: also remove underscores from display name for better matching
        let cleanDisplayNameNoUnderscore = displayName.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")

        // Strategy 1: Direct substring match (current approach - fast path)
        let strategy1Match = cleanFilename.contains(cleanItemId) ||
                           cleanFilename.contains(cleanDisplayName) ||
                           cleanFilename.contains(cleanDisplayNameNoUnderscore)
        if strategy1Match {
            writeLog("InspectState:     ✓ Strategy 1 match: '\(filename)' matched", logLevel: .info)
            return true
        }

        // Strategy 2: Split and match components (handle underscores/spaces)
        // microsoft_outlook → ["microsoft", "outlook"]
        let itemComponents = cleanItemId.components(separatedBy: CharacterSet(charactersIn: "_- "))
            .filter { !$0.isEmpty && $0.count > 2 }  // Filter out small words

        let displayComponents = cleanDisplayName.components(separatedBy: CharacterSet(charactersIn: "_- "))
            .filter { !$0.isEmpty && $0.count > 2 }

        // Check if all significant components from item ID are present in filename
        let allItemComponentsMatch = !itemComponents.isEmpty && itemComponents.allSatisfy { component in
            cleanFilename.contains(component)
        }

        let allDisplayComponentsMatch = !displayComponents.isEmpty && displayComponents.allSatisfy { component in
            cleanFilename.contains(component)
        }

        let strategy2Match = allItemComponentsMatch || allDisplayComponentsMatch
        if strategy2Match {
            writeLog("InspectState:     ✓ Strategy 2 match: '\(filename)' component match", logLevel: .info)
            return true
        }

        // Strategy 3: Handle common patterns
        // microsoft_outlook → microsoftoutlook, microsoft.outlook, Microsoft_Outlook, etc.
        let condensedItemId = cleanItemId.replacingOccurrences(of: "_", with: "")
        let condensedDisplayName = cleanDisplayName.replacingOccurrences(of: "_", with: "")

        let strategy3Match = cleanFilename.contains(condensedItemId) || cleanFilename.contains(condensedDisplayName)
        if strategy3Match {
            writeLog("InspectState:     ✓ Strategy 3 match: '\(filename)' contains condensed form", logLevel: .debug)
            return true
        }

        // Strategy 4: Fuzzy matching for brand names
        // Handle cases where "microsoft_office" should match "Office_365" packages
        if let primaryComponent = itemComponents.first, primaryComponent.count >= 4 {
            // For microsoft_*, look for the main app name (second component)
            if primaryComponent == "microsoft" && itemComponents.count > 1 {
                let appName = itemComponents[1]
                let strategy4Match = cleanFilename.contains(appName)
                if strategy4Match {
                    writeLog("InspectState:     ✓ Strategy 4 match: '\(filename)' contains app name '\(appName)'", logLevel: .debug)
                    return true
                }
            }
        }

        // No match found - only log this at debug level
        return false
    }

    private func fsEventsRecentlyDetected(_ itemId: String) -> Bool {
        guard let timestamp = fsEventsTimestamps[itemId] else { return false }
        return Date().timeIntervalSince(timestamp) < fsEventsPriorityWindow
    }
    
    /// This works but might be a bit solved too complex - 
    private func parseCommandLine(_ line: String) {
        // Enhanced parsing to handle multiple command formats from AppInspector
        writeLog("InspectState: Parsing command line: \(line)", logLevel: .debug)
        
        // Try to extract index from various command formats
        var appIndex: Int?
        var status: String?
        var statusText: String?
        
        // Format 1: "listitem: index: X, status: Y, statustext: Z"
        if let indexRange = line.range(of: "index: "),
           let commaRange = line.range(of: ",", range: indexRange.upperBound..<line.endIndex) {
            let indexStr = String(line[indexRange.upperBound..<commaRange.lowerBound])
            appIndex = Int(indexStr)
        }
        
        // Extract status
        if let statusRange = line.range(of: "status: "),
           let nextCommaRange = line.range(of: ",", range: statusRange.upperBound..<line.endIndex) {
            status = String(line[statusRange.upperBound..<nextCommaRange.lowerBound])
        } else if let statusRange = line.range(of: "status: ") {
            status = String(line[statusRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Extract status text
        if let statusTextRange = line.range(of: "statustext: ") {
            statusText = String(line[statusTextRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Apply updates based on parsed information
        guard let index = appIndex, index < items.count else {
            writeLog("InspectState: Invalid or missing index in command: \(line)", logLevel: .debug)
            return
        }
        
        let app = items[index]
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let status = status {
                switch status.lowercased() {
                case "success":
                    self.completedItems.insert(app.id)
                    self.downloadingItems.remove(app.id)
                    writeLog("InspectState: \(app.displayName) installation completed (from command)", logLevel: .info)
                case "wait":
                    self.downloadingItems.insert(app.id)
                    writeLog("InspectState: \(app.displayName) downloading (from command)", logLevel: .info)
                case "pending":
                    self.downloadingItems.remove(app.id)
                    self.completedItems.remove(app.id)
                    writeLog("InspectState: \(app.displayName) pending (from command)", logLevel: .info)
                default:
                    writeLog("InspectState: Unknown status '\(status)' for \(app.displayName)", logLevel: .debug)
                }
            }
            
            // Also check for German status texts in case status field is missing
            if let statusText = statusText {
                if statusText.contains("Installed") || statusText.contains("Complete") || statusText.contains("erfolgreich") {
                    self.completedItems.insert(app.id)
                    self.downloadingItems.remove(app.id)
                    writeLog("InspectState: \(app.displayName) installation completed (from status text)", logLevel: .info)
                } else if statusText.contains("Downloading") || statusText.contains("Installing") || statusText.contains("heruntergeladen") {
                    self.downloadingItems.insert(app.id)
                    writeLog("InspectState: \(app.displayName) downloading (from status text)", logLevel: .info)
                }
            }
        }
    }
    
    private func startSideMessageRotation(interval: TimeInterval) {
        // Stop existing timer if any
        sideMessageTimer?.invalidate()

        writeLog("InspectState: Starting side message rotation with \(uiConfiguration.sideMessages.count) messages, interval: \(interval)s", logLevel: .info)

        // Start new timer - ensure it runs on the main run loop
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.sideMessageTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                guard let self = self, self.uiConfiguration.sideMessages.count > 1 else {
                    writeLog("InspectState: Timer fired but no messages to rotate (count: \(self?.uiConfiguration.sideMessages.count ?? 0))", logLevel: .debug)
                    return
                }

                self.uiConfiguration.currentSideMessageIndex = (self.uiConfiguration.currentSideMessageIndex + 1) % self.uiConfiguration.sideMessages.count
                writeLog("InspectState: Rotated to side message index \(self.uiConfiguration.currentSideMessageIndex) of \(self.uiConfiguration.sideMessages.count)", logLevel: .info)
            }

            // Also fire immediately to start rotation
            if self.uiConfiguration.sideMessages.count > 1 {
                Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
                    writeLog("InspectState: Initial rotation trigger", logLevel: .info)
                }
            }
        }

        writeLog("InspectState: Side message rotation timer configured", logLevel: .info)
    }
    
    func getCurrentSideMessage() -> String? {
        guard !uiConfiguration.sideMessages.isEmpty else { return nil }
        let index = min(uiConfiguration.currentSideMessageIndex, uiConfiguration.sideMessages.count - 1)
        return uiConfiguration.sideMessages[index]
    }
    
    /// For best UX, especially in Enrollment scenarios - check if all apps are completed and update button state accordingly
    func checkAndUpdateButtonState() {
        let totalApps = items.count
        let completedCount = completedItems.count
        
        writeLog("InspectState: Button state check - Total: \(totalApps), Completed: \(completedCount), AutoEnable: \(buttonConfiguration.autoEnableButton)", logLevel: .info)
        
        // If all apps are completed
        if totalApps > 0 && completedCount == totalApps {
            writeLog("InspectState: All apps completed (\(completedCount)/\(totalApps))", logLevel: .info)
            
            // Update button state directly since InspectView uses independent state management
            DispatchQueue.main.asyncAfter(deadline: .now() + InspectConstants.debounceDelay) { [weak self] in
                guard let self = self else { return }
                if self.buttonConfiguration.autoEnableButton {
                    self.buttonConfiguration.button1Text = self.config?.autoEnableButtonText ?? "OK"
                    self.buttonConfiguration.button1Disabled = false
                    writeLog("InspectState: Auto-enabling button with text: \(self.buttonConfiguration.button1Text)", logLevel: .info)
                }
            }
        }
    }
    
    // MARK: - Unified Plist Validation

    /// TODO: this can be build better, however plist are oftentime pretty complex, our actual at least works for the current use cases tested
    
    func validatePlistItem(_ item: InspectConfig.ItemConfig) -> Bool {
        writeLog("InspectState: validatePlistItem called for '\(item.id)'", logLevel: .debug)
        
        // Use validation service for all validation logic
        let request = ValidationRequest(
            item: item,
            plistSources: plistSources
        )
        
        let result = validationService.validateItem(request)
        
        // Cache the result for UI consistency
        plistValidationResults[item.id] = result.isValid
        
        // Log validation details for debugging
        if let details = result.details {
            writeLog("InspectState: Validation for '\(item.id)' - Path: \(details.path), Key: \(details.key ?? "N/A"), Expected: \(details.expectedValue ?? "N/A"), Actual: \(details.actualValue ?? "N/A"), Result: \(result.isValid)", logLevel: .debug)
        } else {
            writeLog("InspectState: Validation for '\(item.id)' - Type: \(result.validationType), Result: \(result.isValid)", logLevel: .debug)
        }
        
        return result.isValid
    }
    
    // MARK: - Validation Initialization
    
    /// Validate all items to populate the validation results dictionary
    func validateAllItems() {
        writeLog("InspectState: Starting async validation of \(items.count) items", logLevel: .debug)

        // Use optimized async validation
        Validation.shared.validateItemsBatch(items, plistSources: plistSources) { [weak self] results in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.plistValidationResults = results
                writeLog("InspectState: Async validation complete. \(results.filter { $0.value }.count) valid items", logLevel: .info)

                // Update UI if needed
                self.objectWillChange.send()
            }
        }
    }
    
    
    // NEW: Get actual plist value for display purposes
    func getPlistValueForDisplay(item: InspectConfig.ItemConfig) -> String? {
        guard let plistKey = item.plistKey else { return nil }
        
        // Use validation service to get the actual plist value
        for path in item.paths {
            if let value = validationService.getPlistValue(at: path, key: plistKey) {
                return value
            }
        }
        return nil
    }
    
    
    deinit {
        writeLog("InspectState.deinit() - Starting resource cleanup", logLevel: .info)

        // Stop progress tracking
        // Progress tracking removed - no longer needed

        // Stop all timers
        updateTimer?.invalidate()
        updateTimer = nil
        fileSystemCheckTimer?.invalidate() 
        fileSystemCheckTimer = nil
        sideMessageTimer?.invalidate()
        sideMessageTimer = nil
        
        // Stop DispatchSource monitoring
        commandFileMonitor?.cancel()
        commandFileMonitor = nil
        
        // Stop FSEvents monitoring and clear delegate to prevent any potential retain cycles
        fsEventsMonitor.stopMonitoring()
        fsEventsMonitor.delegate = nil
        
        // Cancel all debounced operations
        debouncedUpdater.cancelAll()
        
        // Clear AppInspector reference
        appInspector = nil
        
        // Note: Services (validationService, configurationService) are value types with no explicit cleanup needed
        // They will be automatically deallocated when InspectState is deallocated
        
        writeLog("InspectState.deinit() - Resource cleanup completed", logLevel: .info)
    }
    
    // MARK: - Progress Tracking

    private func initializeProgressTracker() {
        let preset = uiConfiguration.preset.lowercased()
        let totalItems = items.count

        // Progress tracking removed - no longer needed

        // Set initial state for all items
        for item in items {
            _ = getItemStatus(item)
            // Progress tracking removed - no longer needed
        }

        // Update preset-specific data
        updatePresetSpecificProgress()

        writeLog("InspectState: Progress tracker initialized for \(preset) with \(totalItems) items", logLevel: .info)
    }

    private func updateProgressForItem(_ itemId: String, status: String) {
        // Progress tracking removed - no longer needed
        updatePresetSpecificProgress()
    }

    private func updatePresetSpecificProgress() {
        // Progress tracking removed - no longer needed

        switch uiConfiguration.preset.lowercased() {
        case "preset1":
            // Progress tracking removed - no longer needed
            break

        case "preset6":
            // Progress tracking removed - no longer needed
            break

        default:
            break
        }
    }

    private func getItemStatus(_ item: InspectConfig.ItemConfig) -> String {
        if completedItems.contains(item.id) {
            return "complete"
        } else if downloadingItems.contains(item.id) {
            return "downloading"
        } else {
            return "pending"
        }
    }

    private func getCurrentImageIndex() -> Int {
        // This would need to be tracked if implementing image rotation
        return 0
    }

    // MARK: - Helper Functions

    // MARK: - FileMonitorDelegate

    func fileMonitor(_ monitor: FileMonitor, didDetectInstallation itemId: String, at path: String) {
        // Handle installation detection if needed
        writeLog("InspectState: Installation detected for \(itemId)", logLevel: .debug)
    }

    func fileMonitor(_ monitor: FileMonitor, didDetectRemoval itemId: String, at path: String) {
        // Handle removal detection if needed
        writeLog("InspectState: Removal detected for \(itemId)", logLevel: .debug)
    }

    func fileMonitor(_ monitor: FileMonitor, didDetectDownload itemId: String, at path: String) {
        // Handle download detection if needed
        writeLog("InspectState: Download detected for \(itemId)", logLevel: .debug)
    }

    func fileMonitorDidDetectChanges(_ monitor: FileMonitor) {
        // Handle general changes if needed
        writeLog("InspectState: File monitor detected changes", logLevel: .debug)
    }
}
