//
//  InspectConfigurationService.swift
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

class InspectConfigurationService {
    
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
            "title": "Test Configuration",
            "message": "Testing inspect mode",
            "preset": "preset1",
            "cachePaths": ["/tmp"],
            "items": [
                {
                    "id": "test1",
                    "displayName": "Test Item 1", 
                    "guiIndex": 0,
                    "paths": ["/Applications/Test1.app"]
                },
                {
                    "id": "test2",
                    "displayName": "Test Item 2",
                    "guiIndex": 1, 
                    "paths": ["/Applications/Test2.app"]
                },
                {
                    "id": "test3",
                    "displayName": "Test Item 3",
                    "guiIndex": 2,
                    "paths": ["/Applications/Test3.app"]
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
        
        if let preset = config.preset, !["preset1", "preset2", "preset3", "preset4", "preset5"].contains(preset) {
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
        
        if let iconsize = config.iconsize {
            uiConfig.iconSize = iconsize
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
        
        if let button2Disabled = config.button2Disabled {
            buttonConfig.button2Disabled = button2Disabled
        }
        
        if let button2Visible = config.button2Visible {
            buttonConfig.button2Visible = button2Visible
        }
        
        if let buttonStyle = config.buttonStyle {
            buttonConfig.buttonStyle = buttonStyle
        }
        
        if let autoEnableButton = config.autoEnableButton {
            buttonConfig.autoEnableButton = autoEnableButton
        }
        
        return buttonConfig
    }
}