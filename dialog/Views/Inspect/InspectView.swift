//
//  InspectView.swift
//  Dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 19/07/2025
//

import SwiftUI
import IOKit

struct InspectView: View {
    @StateObject private var inspectState = InspectState()
    @State private var showingAboutPopover = false
    
    var body: some View {
        Group {
            switch inspectState.loadingState {
            case .loading:
                LoadingView()
                    .onAppear { if appvars.debugMode { print("DEBUG: InspectView: Loading state - showing LoadingView") } }
                
            case .failed(let errorMessage):
                ConfigErrorView(
                    errorMessage: errorMessage,
                    onRetry: {
                        inspectState.retryConfiguration()
                    },
                    onUseDefault: {
                        inspectState.retryConfiguration()
                    }
                )
                .onAppear { print("ERROR: InspectView: Failed state - showing ConfigErrorView: \(errorMessage)") }
                
            case .loaded:
                switch inspectState.uiConfiguration.preset {
                case "preset1":
                    Preset1Layout(inspectState: inspectState, isMini: false)
                        .onAppear { if appvars.debugMode { print("DEBUG: InspectView: Loading Preset1Layout") } }
                case "preset2":
                    Preset2Layout(inspectState: inspectState, isMini: false)
                        .onAppear { if appvars.debugMode { print("DEBUG: InspectView: Loading Preset2Layout") } }
                case "preset3":
                    Preset3Layout(inspectState: inspectState, isMini: false)
                        .onAppear { if appvars.debugMode { print("DEBUG: InspectView: Loading Preset3Layout") } }
                case "preset4":
                    Preset4Layout(inspectState: inspectState, isMini: false)
                        .onAppear { if appvars.debugMode { print("DEBUG: InspectView: Loading Preset4Layout") } }
                case "preset5":
                    Preset5Layout(inspectState: inspectState, isMini: false)
                        .onAppear { if appvars.debugMode { print("DEBUG: InspectView: Loading Preset5Layout") } }
                case "preset1-mini":
                    Preset1Layout(inspectState: inspectState, isMini: true)
                        .onAppear { if appvars.debugMode { print("DEBUG: InspectView: Loading Preset1Layout (mini)") } }
                case "preset2-mini":
                    Preset2Layout(inspectState: inspectState, isMini: true)
                        .onAppear { if appvars.debugMode { print("DEBUG: InspectView: Loading Preset2Layout (mini)") } }
                case "preset3-mini":
                    Preset3Layout(inspectState: inspectState, isMini: true)
                        .onAppear { if appvars.debugMode { print("DEBUG: InspectView: Loading Preset3Layout (mini)") } }
                case "preset4-mini":
                    Preset4Layout(inspectState: inspectState, isMini: true)
                        .onAppear { if appvars.debugMode { print("DEBUG: InspectView: Loading Preset4Layout (mini)") } }
                case "preset5-mini":
                    Preset5Layout(inspectState: inspectState, isMini: true)
                        .onAppear { if appvars.debugMode { print("DEBUG: InspectView: Loading Preset5Layout (mini)") } }
                default:
                    Preset1Layout(inspectState: inspectState, isMini: false)
                        .onAppear { print("ERROR: InspectView: Unknown preset '\(inspectState.uiConfiguration.preset)', loading default Preset1Layout") }
                }
            }
        }
        .onAppear {
            if appvars.debugMode { print("DEBUG: InspectView: onAppear called, preset=\(inspectState.uiConfiguration.preset)") }
            writeLog("InspectView: Starting memory-safe initialization", logLevel: .info)
            inspectState.initialize()
        }
    }
    
    // MARK: - Helper Methods
    
    private func getVisibleItems() -> [InspectConfig.ItemConfig] {
        let totalItems = inspectState.items.count
        guard totalItems > 0 else { return [] }
        
        if totalItems <= 5 {
            return inspectState.items
        }
        
        let completedCount = inspectState.completedItems.count
        
        if completedCount == 0 {
            return Array(inspectState.items.prefix(5))
        } else if completedCount >= totalItems - 5 {
            return Array(inspectState.items.suffix(5))
        } else {
            let startIndex = max(0, completedCount - 2)
            let endIndex = min(totalItems, startIndex + 5)
            return Array(inspectState.items[startIndex..<endIndex])
        }
    }
    
    private func getSortedItemsByStatus() -> [InspectConfig.ItemConfig] {
        let completed = inspectState.items.filter { inspectState.completedItems.contains($0.id) }
        let installing = inspectState.items.filter { inspectState.downloadingItems.contains($0.id) }
        let waiting = inspectState.items.filter { 
            !inspectState.completedItems.contains($0.id) && !inspectState.downloadingItems.contains($0.id)
        }
        
        if inspectState.uiConfiguration.preset == "preset3" && installing.isEmpty && !waiting.isEmpty {
            let recentCompleted = Array(completed.reversed().prefix(2))
            return recentCompleted + waiting
        }
        
        let recentCompleted = completed.reversed()
        return Array(recentCompleted) + installing + waiting
    }
    
 
    private func shouldShowGroupSeparator(for item: InspectConfig.ItemConfig, in sortedItems: [InspectConfig.ItemConfig]) -> Bool {
        guard let index = sortedItems.firstIndex(where: { $0.id == item.id }), index > 0 else { return false }
        
        let previousItem = sortedItems[index - 1]
        let currentStatus = getItemStatusType(for: item)
        let previousStatus = getItemStatusType(for: previousItem)
        
        return currentStatus != previousStatus
    }
    
    /// Get item status type for grouping
    private func getItemStatusType(for item: InspectConfig.ItemConfig) -> Int {
        if inspectState.completedItems.contains(item.id) { return 0 }
        if inspectState.downloadingItems.contains(item.id) { return 1 }
        return 2
    }
    
    /// Get status header text for preset2
    private func getStatusHeaderText(for statusType: Int) -> String {
        switch statusType {
        case 0: return "Installed"
        case 1: return "Currently Installing"
        case 2: return "Pending Installation"
        default: return ""
        }
    }
    
    /// Get item status text
    private func getItemStatus(for item: InspectConfig.ItemConfig) -> String {
        if inspectState.completedItems.contains(item.id) {
            return "Installation Complete"
        } else if inspectState.downloadingItems.contains(item.id) {
            return "Downloading"
        } else {
            return "Pending"
        }
    }
}

/// Enhanced Installation Information popover using swiftDialog's built-in variables
struct InstallationInfoPopoverView: View {
    @ObservedObject var inspectState: InspectState

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            // Computer Model Header with Icon
            VStack(spacing: 8) {
                // Computer Icon (using actual device-specific icon like dialog --icon computer)
                Image(nsImage: NSImage(named: NSImage.computerName) ?? NSImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)

                if inspectState.config?.hideSystemDetails != true {
                    // Computer Model
                    Text(getSystemInfo("computermodel"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    // Serial Number
                    Text(getSystemInfo("serialnumber"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                } else {
                    // Generic system info when details are hidden
                    Text("System Information Hidden")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }

                // OS Name + Version (always shown as it's less sensitive)
                Text("\(getSystemInfo("osname")) \(getSystemInfo("osversion"))")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            .padding(.bottom, 8)

            Divider()

            // User Information
            VStack(alignment: .center, spacing: 4) {
                if inspectState.config?.hideSystemDetails != true {
                    // Full Name
                    Text(getSystemInfo("userfullname"))
                        .font(.headline)
                        .fontWeight(.semibold)

                    // Username
                    Text(getSystemInfo("username"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    // Generic user info when details are hidden
                    Text("User Details Hidden")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 8)

            Divider()

            // Progress Overview
            VStack(alignment: .leading, spacing: 8) {
                Text("Progress Overview")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 6) {
                    EnhancedInfoRow(label: "Total Items", value: "\(inspectState.items.count)")
                    EnhancedInfoRow(label: "Completed", value: "\(inspectState.completedItems.count)",
                                  valueColor: inspectState.completedItems.count > 0 ? .green : .primary)
                    EnhancedInfoRow(label: "Installing", value: "\(inspectState.downloadingItems.count)",
                                  valueColor: inspectState.downloadingItems.count > 0 ? .blue : .primary)
                    EnhancedInfoRow(label: "Pending", value: "\(inspectState.items.count - inspectState.completedItems.count - inspectState.downloadingItems.count)",
                                  valueColor: .secondary)

                    let progress = inspectState.items.isEmpty ? 0.0 : Double(inspectState.completedItems.count) / Double(inspectState.items.count)
                    EnhancedInfoRow(label: "Progress", value: "\(Int(progress * 100))%",
                                  valueColor: progress == 1.0 ? .green : .blue)
                }
            }

            // Current Activity (if any items are installing)
            if !inspectState.downloadingItems.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Currently Installing")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(inspectState.items.filter { inspectState.downloadingItems.contains($0.id) }, id: \.id) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                            Text(item.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 340)
        .frame(maxHeight: 500)
    }

    /// Get system information using swiftDialog's built-in variables
    private func getSystemInfo(_ key: String) -> String {
        let systemInfo = getEnvironmentVars()
        return systemInfo[key] ?? "Unknown"
    }
}

/// Enhanced info row component with better styling and color support
struct EnhancedInfoRow: View {
    let label: String
    let value: String
    let valueColor: Color

    init(label: String, value: String, valueColor: Color = .primary) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
    }

    var body: some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)

            Spacer()

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(valueColor)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }
}

/// Legacy info row component for backward compatibility
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        EnhancedInfoRow(label: label, value: value)
    }
}

/// Placeholder card for empty slots in the 5-card display
struct PlaceholderCardView: View {
    let scale: CGFloat
    
    var body: some View {
        VStack(spacing: 8 * scale) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
                .frame(width: 64 * scale, height: 64 * scale)
            
            Text("")
                .font(.caption)
                .frame(height: 32 * scale)
            
            Text("")
                .font(.caption2)
        }
        .frame(width: 100 * scale, height: 120 * scale)
        .padding(12 * scale)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
        )
    }
}

/// Individual item card component for preset3 Setup Manager style
struct ItemCardView: View {
    let item: InspectConfig.ItemConfig
    let isCompleted: Bool
    let isDownloading: Bool
    let highlightColor: String
    let scale: CGFloat
    
    var body: some View {
        VStack(spacing: 8 * scale) {
            // Item icon with status overlay
            ZStack {
                // Item icon
                if let iconPath = item.icon,
                   FileManager.default.fileExists(atPath: iconPath) {
                    Image(nsImage: NSImage(contentsOfFile: iconPath) ?? NSImage())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64 * scale, height: 64 * scale)
                        .cornerRadius(12)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 64 * scale, height: 64 * scale)
                        .overlay(
                            Image(systemName: "app.fill")
                                .font(.system(size: 32 * scale))
                                .foregroundColor(.blue)
                        )
                }
                
                // Status indicator overlay
                VStack {
                    HStack {
                        Spacer()
                        if isCompleted {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 20 * scale, height: 20 * scale)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        } else if isDownloading {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 20 * scale, height: 20 * scale)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.6)
                                )
                        }
                    }
                    Spacer()
                }
                .frame(width: 64 * scale, height: 64 * scale)
            }
            
            // Item name
            Text(item.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 32 * scale)
            
            // Status text
            if isDownloading {
                Text("Installing...")
                    .font(.caption2)
                    .foregroundColor(.blue)
            } else if isCompleted {
                Text("Installed")
                    .font(.caption2)
                    .foregroundColor(.green)
            } else {
                Text("Waiting...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 100 * scale, height: 120 * scale)
        .padding(12 * scale)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .opacity(isDownloading ? 1.0 : 0.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isDownloading ? Color(hex: highlightColor) : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isDownloading ? 1.05 : 1.0)
        .animation(.easeInOut(duration: InspectConstants.scaleAnimationDuration), value: isDownloading)
    }
}

/// Configuration structure matching the JSON format
struct InspectConfig: Codable {
    let title: String?
    let message: String?
    let infobox: String?
    let icon: String?
    let iconsize: Int?
    let width: Int?
    let height: Int?
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
    let button2Disabled: Bool?
    let button2Visible: Bool?
    let buttonStyle: String?
    let autoEnableButton: Bool?
    let hideSystemDetails: Bool?
    let colorThresholds: ColorThresholds?   // Configurable color thresholds for visualizations
    let plistSources: [PlistSourceConfig]?  // Array of plist configurations to monitor for preset5
    let items: [ItemConfig]
    
    struct ItemConfig: Codable {
        let id: String
        let displayName: String
        let guiIndex: Int
        let paths: [String]
        let icon: String?
        let plistKey: String?           // Optional plist key to check
        let expectedValue: String?      // Optional expected value for the key
        let evaluation: String?         // NEW: Optional evaluation type (equals, boolean, exists, contains, range)
        let category: String?           // NEW: Optional custom category name
        let categoryIcon: String?       // NEW: Optional custom category icon
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
        
        // NEW: Helper methods for flexible positive/negative color theming
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
        button2Disabled = try container.decodeIfPresent(Bool.self, forKey: .button2Disabled)
        button2Visible = try container.decodeIfPresent(Bool.self, forKey: .button2Visible)
        buttonStyle = try container.decodeIfPresent(String.self, forKey: .buttonStyle)
        autoEnableButton = try container.decodeIfPresent(Bool.self, forKey: .autoEnableButton)
        hideSystemDetails = try container.decodeIfPresent(Bool.self, forKey: .hideSystemDetails)
        colorThresholds = try container.decodeIfPresent(ColorThresholds.self, forKey: .colorThresholds)
        plistSources = try container.decodeIfPresent([PlistSourceConfig].self, forKey: .plistSources)
        
        // Default to empty array if items not provided
        items = try container.decodeIfPresent([ItemConfig].self, forKey: .items) ?? []
    }
    
    private enum CodingKeys: String, CodingKey {
        case title, message, infobox, icon, iconsize, width, height, scanInterval, cachePaths
        case sideMessage, sideInterval, style, liststyle, preset, popupButton
        case highlightColor, backgroundColor, backgroundImage, backgroundOpacity
        case textOverlayColor, gradientColors, button1Text, button1Disabled
        case button2Text, button2Disabled, button2Visible, buttonStyle
        case autoEnableButton, hideSystemDetails, colorThresholds, plistSources, items
    }
}

// Color extension to support hex color parsing
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 128, 128, 128) // Default gray fallback
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Loading and Error State Views

struct LoadingView: View {
    let scale: CGFloat
    
    init(scale: CGFloat = 1.0) {
        self.scale = scale
    }
    
    var body: some View {
        VStack(spacing: 24 * scale) {
            Spacer()
            
            // SwiftDialog Icon/Logo Area
            VStack(spacing: 16 * scale) {
                Image(systemName: "gear.circle.fill")
                    .font(.system(size: 64 * scale))
                    .foregroundColor(.blue)
                
                Text("swiftDialog")
                    .font(.system(size: 24 * scale, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            // Loading Content
            VStack(spacing: 16 * scale) {
                ProgressView()
                    .scaleEffect(1.2 * scale)
                    .foregroundColor(.blue)
                
                Text("Loading Configuration...")
                    .font(.system(size: 18 * scale, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("Please wait while the configuration is loaded")
                    .font(.system(size: 14 * scale))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct ConfigErrorView: View {
    let errorMessage: String
    let onRetry: () -> Void
    let onUseDefault: () -> Void
    let scale: CGFloat
    
    init(errorMessage: String, onRetry: @escaping () -> Void, onUseDefault: @escaping () -> Void, scale: CGFloat = 1.0) {
        self.errorMessage = errorMessage
        self.onRetry = onRetry
        self.onUseDefault = onUseDefault
        self.scale = scale
    }
    
    var body: some View {
        VStack(spacing: 24 * scale) {
            Spacer()
            
            // Error Icon and Title
            VStack(spacing: 16 * scale) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64 * scale))
                    .foregroundColor(.orange)
                
                Text("Configuration Load Failed")
                    .font(.system(size: 24 * scale, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            // Error Details
            VStack(spacing: 12 * scale) {
                Text("Unable to load the inspect configuration:")
                    .font(.system(size: 16 * scale))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(errorMessage)
                    .font(.system(size: 14 * scale, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20 * scale)
                    .padding(.vertical, 8 * scale)
                    .background(
                        RoundedRectangle(cornerRadius: 8 * scale)
                            .fill(Color.gray.opacity(0.1))
                    )
                    .multilineTextAlignment(.center)
            }
            
            // Action Buttons
            VStack(spacing: 12 * scale) {
                Button("Retry Loading") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("Use Test Configuration") {
                    onUseDefault()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.top, 8 * scale)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
