//
//  Config.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 25/07/2025
//  Business logic service used for configuration loading and processing
//

import Foundation

// MARK: - Configuration Models

struct ConfigurationRequest {
    let environmentVariable: String
    let fallbackToTestData: Bool
    
    static let `default` = ConfigurationRequest(
        environmentVariable: "DIALOG_INSPECT_CONFIG",
        fallbackToTestData: true
    )
}

struct ConfigurationResult {
    let config: InspectConfig
    let source: ConfigurationSource
    let warnings: [String]
}


enum ConfigurationError: Error, LocalizedError {
    case fileNotFound(path: String)
    case invalidJSON(path: String, error: Error)
    case missingEnvironmentVariable(name: String)
    case testDataCreationFailed(error: Error)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Configuration file not found at: \(path)"
        case .invalidJSON(let path, let error):
            return "Invalid JSON in configuration file \(path): \(error.localizedDescription)"
        case .missingEnvironmentVariable(let name):
            return "Environment variable '\(name)' not set and no fallback available"
        case .testDataCreationFailed(let error):
            return "Failed to create test configuration: \(error.localizedDescription)"
        }
    }
}

// MARK: - Configuration Service

class Config {
    
    // MARK: - Isnpect API
    
    /// Load configuration from environment variable or fallback to test data
    func loadConfiguration(_ request: ConfigurationRequest = .default) -> Result<ConfigurationResult, ConfigurationError> {
        // Required: get config path from environment
        if let configPath = getConfigPath(from: request.environmentVariable) {
            writeLog("ConfigurationService: Using config from environment: \(configPath)", logLevel: .info)
            return loadConfigurationFromFile(at: configPath)
        }
        
        // Check if fallback is allowed
        guard request.fallbackToTestData else {
            return .failure(.missingEnvironmentVariable(name: request.environmentVariable))
        }
        
        writeLog("ConfigurationService: No config path provided, using test data", logLevel: .info)
        return createTestConfiguration()
    }
    
    /// Fallback: Load configuration from specific file path 
    /// TODO: Reevaluate as this has been brittle - loading from file system to late to initialize UI accordingly
    func loadConfigurationFromFile(at path: String) -> Result<ConfigurationResult, ConfigurationError> {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: path) else {
            return .failure(.fileNotFound(path: path))
        }
        
        do {
            // Load and parse JSON
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let decoder = JSONDecoder()
            let config = try decoder.decode(InspectConfig.self, from: data)
            
            // Validate and apply defaults
            let processedConfig = applyConfigurationDefaults(to: config)
            let warnings = validateConfiguration(processedConfig)
            
            writeLog("ConfigurationService: Successfully loaded configuration from \(path)", logLevel: .info)
            writeLog("ConfigurationService: Loaded \(config.items.count) items", logLevel: .debug)
            
            return .success(ConfigurationResult(
                config: processedConfig,
                source: .file(path: path),
                warnings: warnings
            ))
            
        } catch let error {
            writeLog("ConfigurationService: Configuration loading failed for \(path): \(error)", logLevel: .error)
            return .failure(.invalidJSON(path: path, error: error))
        }
    }
    
    /// Fallback for Demo: Create test configuration for development/fallback
    func createTestConfiguration() -> Result<ConfigurationResult, ConfigurationError> {
        let testConfigJSON = """
        {
            "title": "Software Installation Progress",
            "message": "Your IT department is installing essential applications. This process may take several minutes.",
            "preset": "preset1",
            "icon": "default",
            "button1text": "Continue",
            "button2text": "Create Sample Config",
            "button2visible": true,
            "popupButton": "Installation Details",
            "highlightColor": "#007AFF",
            "cachePaths": ["/tmp"],
            "items": [
                {
                    "id": "word",
                    "displayName": "Microsoft Word",
                    "guiIndex": 0,
                    "icon": "sf=doc.fill",
                    "paths": ["/Applications/Microsoft Word.app"]
                },
                {
                    "id": "excel",
                    "displayName": "Microsoft Excel",
                    "guiIndex": 1,
                    "icon": "sf=tablecells.fill",
                    "paths": ["/Applications/Microsoft Excel.app"]
                },
                {
                    "id": "teams",
                    "displayName": "Microsoft Teams",
                    "guiIndex": 2,
                    "icon": "sf=person.2.fill",
                    "paths": ["/Applications/Microsoft Teams.app"]
                },
                {
                    "id": "outlook",
                    "displayName": "Microsoft Outlook",
                    "guiIndex": 4,
                    "icon": "sf=envelope.fill",
                    "paths": ["/Applications/Microsoft Outlook.app"]
                }
            ]
        }
        """
        
        do {
            guard let jsonData = testConfigJSON.data(using: .utf8) else {
                throw NSError(domain: "TestDataError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create JSON data"])
            }
            
            let config = try JSONDecoder().decode(InspectConfig.self, from: jsonData)
            let processedConfig = applyConfigurationDefaults(to: config)
            
            writeLog("ConfigurationService: Created test configuration with \(config.items.count) items", logLevel: .debug)
            
            return .success(ConfigurationResult(
                config: processedConfig,
                source: .testData,
                warnings: []
            ))
            
        } catch let error {
            return .failure(.testDataCreationFailed(error: error))
        }
    }
    
    // MARK: - Internal Helper Methods
    
    private func getConfigPath(from environmentVariable: String) -> String? {
        guard let path = ProcessInfo.processInfo.environment[environmentVariable] else {
            return nil
        }
        return path.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func applyConfigurationDefaults(to config: InspectConfig) -> InspectConfig {
        // Apply configuration defaults and process the config
        // TODO: This is where we would add more advanced post-processing logic
        
        // Sort items by guiIndex for consistent display
        let processedConfig = config
        // Note: InspectConfig is a struct, we can't modify it directly
        
        return processedConfig
    }
    
    /// TODO: better validate configuration and return warnings - 
    private func validateConfiguration(_ config: InspectConfig) -> [String] {
        var warnings: [String] = []
        
        // Check for common configuration issues
        if config.items.isEmpty && config.plistSources?.isEmpty != false {
            warnings.append("Configuration has no items or plist sources")
        }
        
        if let preset = config.preset, !["preset1", "preset2", "preset3", "preset4", "preset5", "preset6"].contains(preset) {
            warnings.append("Unknown preset '\(preset)' - will default to preset1")
        }
        
        // Check for missing icon files
        if let iconPath = config.icon, !FileManager.default.fileExists(atPath: iconPath) {
            warnings.append("Icon file not found: \(iconPath)")
        }
        
        // Check for missing background images
        if let backgroundImage = config.backgroundImage, !FileManager.default.fileExists(atPath: backgroundImage) {
            warnings.append("Background image not found: \(backgroundImage)")
        }
        
        // Validate color thresholds
        if let thresholds = config.colorThresholds {
            if thresholds.excellent <= thresholds.good || thresholds.good <= thresholds.warning {
                warnings.append("Color thresholds should be in descending order (excellent > good > warning)")
            }
        }
        
        // Log warnings
        for warning in warnings {
            writeLog("ConfigurationService: Warning - \(warning)", logLevel: .info)
        }
        
        return warnings
    }
    
    // MARK: - Configuration Transformation Helpers
    
    func extractUIConfiguration(from config: InspectConfig) -> UIConfiguration {
        var uiConfig = UIConfiguration()

        print("Config.swift: extractUIConfiguration called")
        print("Config.swift: config.banner = \(config.banner ?? "nil")")
        print("Config.swift: config.bannerHeight = \(config.bannerHeight ?? 0)")
        print("Config.swift: config.bannerTitle = \(config.bannerTitle ?? "nil")")

        if let title = config.title {
            uiConfig.windowTitle = title
        }

        if let message = config.message {
            uiConfig.subtitleMessage = message
            uiConfig.statusMessage = message
        }

        if let icon = config.icon {
            uiConfig.iconPath = icon
        }

        if let sideMessage = config.sideMessage {
            uiConfig.sideMessages = sideMessage
        }

        if let popupButton = config.popupButton {
            uiConfig.popupButtonText = popupButton
        }

        if let preset = config.preset {
            uiConfig.preset = preset
        }

        if let highlightColor = config.highlightColor {
            uiConfig.highlightColor = highlightColor
        }

        // Banner configuration
        if let banner = config.banner {
            print("Config.swift: Setting uiConfig.bannerImage = \(banner)")
            uiConfig.bannerImage = banner
        }

        if let bannerHeight = config.bannerHeight {
            print("Config.swift: Setting uiConfig.bannerHeight = \(bannerHeight)")
            uiConfig.bannerHeight = bannerHeight
        }

        if let bannerTitle = config.bannerTitle {
            print("Config.swift: Setting uiConfig.bannerTitle = \(bannerTitle)")
            uiConfig.bannerTitle = bannerTitle
        }

        print("Config.swift: After extraction - uiConfig.bannerImage = \(uiConfig.bannerImage ?? "nil")")

        if let iconsize = config.iconsize {
            uiConfig.iconSize = iconsize
        }

        // Window sizing configuration
        if let width = config.width {
            uiConfig.width = width
        }

        if let height = config.height {
            uiConfig.height = height
        }

        if let size = config.size {
            uiConfig.size = size
        }

        // Preset6 specific properties
        if let iconBasePath = config.iconBasePath {
            uiConfig.iconBasePath = iconBasePath
        }

        if let rotatingImages = config.rotatingImages {
            uiConfig.rotatingImages = rotatingImages
        }

        if let imageRotationInterval = config.imageRotationInterval {
            uiConfig.imageRotationInterval = imageRotationInterval
        }

        if let imageShape = config.imageShape {
            uiConfig.imageFormat = imageShape  // Map to existing imageFormat property
        }

        if let imageSyncMode = config.imageSyncMode {
            uiConfig.imageSyncMode = imageSyncMode
        }

        if let stepStyle = config.stepStyle {
            uiConfig.stepStyle = stepStyle
        }

        if let listIndicatorStyle = config.listIndicatorStyle {
            uiConfig.listIndicatorStyle = listIndicatorStyle
            print("Config: Setting listIndicatorStyle to '\(listIndicatorStyle)' from JSON")
        } else {
            print("Config: No listIndicatorStyle in JSON, using default: '\(uiConfig.listIndicatorStyle)'")
        }

        return uiConfig
    }
    
    func extractBackgroundConfiguration(from config: InspectConfig) -> BackgroundConfiguration {
        var bgConfig = BackgroundConfiguration()
        
        if let backgroundColor = config.backgroundColor {
            bgConfig.backgroundColor = backgroundColor
        }
        
        if let backgroundImage = config.backgroundImage {
            bgConfig.backgroundImage = backgroundImage
        }
        
        if let backgroundOpacity = config.backgroundOpacity {
            bgConfig.backgroundOpacity = backgroundOpacity
        }
        
        if let textOverlayColor = config.textOverlayColor {
            bgConfig.textOverlayColor = textOverlayColor
        }
        
        if let gradientColors = config.gradientColors {
            bgConfig.gradientColors = gradientColors
        }
        
        return bgConfig
    }
    
    func extractButtonConfiguration(from config: InspectConfig) -> ButtonConfiguration {
        var buttonConfig = ButtonConfiguration()
        
        if let button1Text = config.button1Text {
            buttonConfig.button1Text = button1Text
        }
        
        if let button1Disabled = config.button1Disabled {
            buttonConfig.button1Disabled = button1Disabled
        }
        
        if let button2Text = config.button2Text {
            buttonConfig.button2Text = button2Text
        }

        // Deprecated: button2Disabled - button2 is always enabled when shown
        // if let button2Disabled = config.button2Disabled {
        //     buttonConfig.button2Disabled = button2Disabled
        // }

        if let button2Visible = config.button2Visible {
            buttonConfig.button2Visible = button2Visible
        }

        // Deprecated: buttonStyle - not used in Inspect mode
        // if let buttonStyle = config.buttonStyle {
        //     buttonConfig.buttonStyle = buttonStyle
        // }
        
        if let autoEnableButton = config.autoEnableButton {
            buttonConfig.autoEnableButton = autoEnableButton
        }
        
        return buttonConfig
    }
}
