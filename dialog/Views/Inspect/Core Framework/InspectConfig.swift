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

/// Download status emum
enum SimpleItemStatus {
    case pending
    case downloading
    case completed
    case failed
}

// MARK: - Configuration

/// Configuration structure, this is matching the JSON format 
/// Usage note: Due to the dynamic nature of the config, JSON must be used pre-loaded `export DIALOG_INSPECT_CONFIG=/path/to/config.json`
"$DIALOG_PATH" --inspect-mode
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
    let hideSystemDetails: Bool?
    let colorThresholds: ColorThresholds?   // WIP: Configurable color thresholds for visualizations
    let plistSources: [PlistSourceConfig]?  // Array of plist configurations to monitor - used in compliance dashboards like preset5 
    let categoryHelp: [CategoryHelp]?       // Optional help popovers for categories - used in compliance dashboards like preset5
    let uiLabels: UILabels?                 // Optional UI text customization

    let iconBasePath: String?                // Icon base path for relative loading icon paths
    let rotatingImages: [String]?            // Array of image paths for image rotation 
    let imageRotationInterval: Double?      // set interval for auto-rotation
    let imageShape: String?                  // rectangle, square, circle - used in preset6
    let imageSyncMode: String?              // "manual" | "sync" | "auto"
    let stepStyle: String?                  // "plain" | "colored" | "cards"

    let items: [ItemConfig]
    
    struct ItemConfig: Codable {
        let id: String
        let displayName: String
        let subtitle: String?           // TODO: We need to simplify this - atm used as subtitle for preset6 checklist
        let guiIndex: Int
        let paths: [String]
        let icon: String?
        let plistKey: String?           // Optional: plist key to check - used in compliance dashboards like preset5
        let expectedValue: String?      // Optional: expected value for the key - used in compliance dashboards like preset5
        let evaluation: String?         // Optional: evaluation type (equals, boolean, exists, contains, range) - used in compliance dashboards like preset5
        let category: String?           // Optional: custom category name - used in compliance dashboards like preset5
        let categoryIcon: String?       // Optional: custom category icon - used in compliance dashboards like preset5
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
    
    struct UILabels: Codable {
        let complianceStatus: String?       // Label for "Compliance Status"
        let recommendedActions: String?     // Label for "Recommended Actions"
        let securityDetails: String?        // Label for "Security Details"
        let lastCheck: String?              // Label for "Last Check"
        let passed: String?                 // Label for "passed"
        let failed: String?                 // Label for "failed"
        let checksPassed: String?           // Format for "X of Y checks passed"
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
    
    // TODO: Revisit this: - odd this seems required since refactoring - for Codable conformance (though we only read configs WTF !) - see: https://www.hackingwithswift.com/books/ios-swiftui/adding-codable-conformance-for-published-properties

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
        try container.encodeIfPresent(banner, forKey: .banner)
        try container.encodeIfPresent(bannerHeight, forKey: .bannerHeight)
        try container.encodeIfPresent(bannerTitle, forKey: .bannerTitle)
        try container.encodeIfPresent(iconBasePath, forKey: .iconBasePath)
        try container.encodeIfPresent(rotatingImages, forKey: .rotatingImages)
        try container.encodeIfPresent(imageRotationInterval, forKey: .imageRotationInterval)
        try container.encodeIfPresent(imageShape, forKey: .imageShape)
        try container.encodeIfPresent(imageSyncMode, forKey: .imageSyncMode)
        try container.encodeIfPresent(stepStyle, forKey: .stepStyle)
        try container.encode(items, forKey: .items)
    }

    // Custom decoder to handle missing items field
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
        backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor)
        backgroundImage = try container.decodeIfPresent(String.self, forKey: .backgroundImage)
        backgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .backgroundOpacity)
        textOverlayColor = try container.decodeIfPresent(String.self, forKey: .textOverlayColor)
        gradientColors = try container.decodeIfPresent([String].self, forKey: .gradientColors)
        button1Text = try container.decodeIfPresent(String.self, forKey: .button1Text)
        button1Disabled = try container.decodeIfPresent(Bool.self, forKey: .button1Disabled)
        button2Text = try container.decodeIfPresent(String.self, forKey: .button2Text)
        // Deprecated: button2Disabled - buttons are always enabled when shown
        _ = try container.decodeIfPresent(Bool.self, forKey: .button2Disabled)
        button2Visible = try container.decodeIfPresent(Bool.self, forKey: .button2Visible)
        // Deprecated: buttonStyle - not used in Inspect mode
        _ = try container.decodeIfPresent(String.self, forKey: .buttonStyle)
        autoEnableButton = try container.decodeIfPresent(Bool.self, forKey: .autoEnableButton)
        autoEnableButtonText = try container.decodeIfPresent(String.self, forKey: .autoEnableButtonText)
        hideSystemDetails = try container.decodeIfPresent(Bool.self, forKey: .hideSystemDetails)
        colorThresholds = try container.decodeIfPresent(ColorThresholds.self, forKey: .colorThresholds)
        plistSources = try container.decodeIfPresent([PlistSourceConfig].self, forKey: .plistSources)
        categoryHelp = try container.decodeIfPresent([CategoryHelp].self, forKey: .categoryHelp)
        uiLabels = try container.decodeIfPresent(UILabels.self, forKey: .uiLabels)

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

        // Default to empty array if items not provided
        items = try container.decodeIfPresent([ItemConfig].self, forKey: .items) ?? []
    }
    
    private enum CodingKeys: String, CodingKey {
        case title, message, infobox, icon, iconsize, banner, bannerHeight, bannerTitle
        case width, height, size, scanInterval, cachePaths
        case sideMessage, sideInterval, style, liststyle, preset, popupButton
        case highlightColor, backgroundColor, backgroundImage, backgroundOpacity
        case textOverlayColor, gradientColors
        case button1Text = "button1text"  
        case button1Disabled = "button1disabled"
        case button2Text = "button2text"
        case button2Disabled = "button2disabled"  // Deprecated - TODO: Remove
        case button2Visible = "button2visible"
        case buttonStyle  // Deprecated - TODO: Remove
        case autoEnableButton, autoEnableButtonText, hideSystemDetails, colorThresholds, plistSources, categoryHelp, uiLabels, items
        // Preset6 specific properties
        case iconBasePath, rotatingImages, imageRotationInterval, imageShape, imageSyncMode, stepStyle
    }
}
