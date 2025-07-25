//
//  Preset4Layout.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 22/07/2025
//  Simple, high-contrast inspection layout for any type of file/folder/setting checks
//  Use cases: Font installation, template files, compliance settings, app presence
//

import SwiftUI

struct Preset4Layout: View, InspectLayoutProtocol {
    @ObservedObject var inspectState: InspectState
    var isMini: Bool
    @State private var showingDetailPopover = false
    @State private var selectedItem: InspectConfig.ItemConfig?
    
    // Use centralized validation results from InspectState - no local caching needed
    
    private var scaleFactor: CGFloat {
        return isMini ? 0.75 : 1.0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Simple Header
            headerSection
            
            // Main Content Area
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 20 * scaleFactor) {
                        // Compact Status Summary
                        simpleStatusSummary
                            .padding(.top, 5 * scaleFactor)
                        
                        // Clean Grid with improved layout
                        simpleInspectionGrid(geometry: geometry)
                        
                        // Simple Buttons with proper spacing
                        buttonArea()
                            .padding(.top, 10 * scaleFactor)
                    }
                    .padding(.horizontal, 30 * scaleFactor)
                    .padding(.vertical, 20 * scaleFactor)
                }
            }
        }
        .background(customBackground())
        .onAppear {
            // Validation results are now managed centrally by InspectState
        }
        .onChange(of: inspectState.items.count) { _ in
            // Validation results are now managed centrally by InspectState
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 8 * scaleFactor) {
            HStack(spacing: 15 * scaleFactor) {
                // Compact logo
                if let iconPath = inspectState.uiConfiguration.iconPath,
                   FileManager.default.fileExists(atPath: iconPath) {
                    Image(nsImage: NSImage(contentsOfFile: iconPath) ?? NSImage())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40 * scaleFactor, height: 40 * scaleFactor)
                }
                
                // Compact title only
                Text(inspectState.uiConfiguration.windowTitle)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Message if available
            if let message = inspectState.uiConfiguration.subtitleMessage, !message.isEmpty {
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 40 * scaleFactor)
        .padding(.vertical, 15 * scaleFactor)
        .background(.regularMaterial)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.secondary.opacity(0.2)),
            alignment: .bottom
        )
    }
    
    // MARK: - Status Summary
    
    private var simpleStatusSummary: some View {
        let totalItems = inspectState.items.count
        let presentItems = inspectState.plistValidationResults.values.filter { $0 }.count
        let missingItems = totalItems - presentItems
        let progress = totalItems == 0 ? 0.0 : Double(presentItems) / Double(totalItems)
        
        return HStack(spacing: 20 * scaleFactor) {
            // Compact progress info
            HStack(spacing: 12 * scaleFactor) {
                Text("\(presentItems)/\(totalItems)")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.primary)
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: inspectState.colorThresholds.getColor(for: progress)))
                    .frame(width: 120 * scaleFactor, height: 6 * scaleFactor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3 * scaleFactor)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
            }
            
            // Compact status counts
            HStack(spacing: 15 * scaleFactor) {
                CompactStatusCount(count: presentItems, label: inspectState.colorThresholds.getLabel(for: 1.0), color: inspectState.colorThresholds.getColor(for: 1.0), scaleFactor: scaleFactor)
                CompactStatusCount(count: missingItems, label: inspectState.colorThresholds.getLabel(for: 0.0), color: inspectState.colorThresholds.getColor(for: 0.0), scaleFactor: scaleFactor)
            }
            
            Spacer()
            
            // Inspection Details button
            Button("Details...") {
                showingDetailPopover = true
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundColor(.accentColor)
            .popover(isPresented: $showingDetailPopover) {
                InspectionDetailPopover(
                    items: inspectState.items,
                    validationResults: inspectState.plistValidationResults,
                    downloadingItems: inspectState.downloadingItems,
                    scaleFactor: scaleFactor,
                    hideSystemDetails: inspectState.config?.hideSystemDetails ?? false,
                    inspectState: inspectState
                )
            }
        }
        .padding(.horizontal, 20 * scaleFactor)
        .padding(.vertical, 12 * scaleFactor)
        .background(.thickMaterial)
        .cornerRadius(8 * scaleFactor)
    }
    
    // MARK: - Simple Grid
    
    private func simpleInspectionGrid(geometry: GeometryProxy) -> some View {
        let columns = calculateColumns(for: geometry.size.width)
        
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18 * scaleFactor), count: columns), 
                         spacing: 18 * scaleFactor) {
            ForEach(inspectState.items, id: \.id) { item in
                SimpleInspectionTile(
                    title: item.displayName,
                    icon: item.icon,
                    isPresent: inspectState.plistValidationResults[item.id] ?? false,
                    isChecking: inspectState.downloadingItems.contains(item.id),
                    scaleFactor: scaleFactor,
                    colorThresholds: inspectState.colorThresholds,
                    item: item
                )
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func calculateColumns(for width: CGFloat) -> Int {
        let minTileWidth: CGFloat = 220 * scaleFactor
        let spacing: CGFloat = 18 * scaleFactor
        let padding: CGFloat = 80 * scaleFactor // Total horizontal padding
        
        let availableWidth = width - padding
        let maxColumns = Int((availableWidth + spacing) / (minTileWidth + spacing))
        
        return max(2, min(maxColumns, 5)) // 2-5 columns for better balance
    }
    
    // MARK: - Background Customization
    
    @ViewBuilder
    private func customBackground() -> some View {
        GeometryReader { geometry in
            ZStack {
                // Base background
                Color(NSColor.controlBackgroundColor)
                
                // Custom background from config
                if let config = inspectState.config {
                    // Gradient background
                    if let gradientColors = config.gradientColors, gradientColors.count >= 2 {
                        LinearGradient(
                            colors: gradientColors.compactMap { Color(hex: $0) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .opacity(config.backgroundOpacity ?? 1.0)
                    }
                    // Solid color background
                    else if let backgroundColor = config.backgroundColor {
                        Color(hex: backgroundColor)
                            .opacity(config.backgroundOpacity ?? 1.0)
                    }
                    // Background image
                    else if let backgroundImage = config.backgroundImage {
                        if FileManager.default.fileExists(atPath: backgroundImage) {
                            if let nsImage = NSImage(contentsOfFile: backgroundImage) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .clipped()
                                    .opacity(config.backgroundOpacity ?? 1.0)
                            }
                        }
                    }
                }
            }
        }
        .ignoresSafeArea(.all)
    }
    
    // MARK: - Button Area
    
    private func buttonArea() -> some View {
        HStack(spacing: 12 * scaleFactor) {
            Button("Continue") {
                writeLog("Preset4Layout: User clicked Continue button - exiting with code 0", logLevel: .info)
                exit(0)
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            
            Button("Show Details") {
                showingDetailPopover = true
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Validation Results Caching
    
    
    // MARK: - Plist Compliance Checking (Legacy - kept for reference)
    
    private func checkItemCompliance(item: InspectConfig.ItemConfig) -> Bool {
        // Use unified validation service for all items
        return inspectState.validatePlistItem(item)
    }
}

// MARK: - Compact Status Count Component

struct CompactStatusCount: View {
    let count: Int
    let label: String
    let color: Color
    let scaleFactor: CGFloat
    
    var body: some View {
        HStack(spacing: 4 * scaleFactor) {
            Circle()
                .fill(color)
                .frame(width: 6 * scaleFactor, height: 6 * scaleFactor)
            
            Text("\(count)")
                .font(.caption.weight(.bold))
                .foregroundColor(color)
        }
    }
}

// MARK: - Simple Inspection Tile (Horizontal Layout)

struct SimpleInspectionTile: View {
    let title: String
    let icon: String?
    let isPresent: Bool
    let isChecking: Bool
    let scaleFactor: CGFloat
    let colorThresholds: InspectConfig.ColorThresholds
    let item: InspectConfig.ItemConfig? // Add item context for plist validation
    
    var body: some View {
        HStack(spacing: 15 * scaleFactor) {
            // Item icon (from config)
            Group {
                if let iconPath = icon, FileManager.default.fileExists(atPath: iconPath) {
                    Image(nsImage: NSImage(contentsOfFile: iconPath) ?? NSImage())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    // Default system icons based on item type
                    Image(systemName: getSystemIcon(for: title))
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
            }
            .frame(width: 32 * scaleFactor, height: 32 * scaleFactor)
            
            // Content with status - fixed height container
            VStack(alignment: .leading, spacing: 4 * scaleFactor) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(minHeight: 20 * scaleFactor, alignment: .top)
                
                // Status text instead of icon overlay
                Text(getStatusText())
                    .font(.caption.weight(.medium))
                    .foregroundColor(getStatusColor())
                    .frame(minHeight: 14 * scaleFactor, alignment: .top)
            }
            .frame(minHeight: 40 * scaleFactor, alignment: .top)
            
            Spacer()
            
            // Status indicator (smaller, on the right)
            Group {
                if isChecking {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16 * scaleFactor, height: 16 * scaleFactor)
                } else if isPresent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundColor(colorThresholds.getColor(for: 1.0))
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundColor(colorThresholds.getColor(for: 0.0))
                }
            }
            .frame(width: 20 * scaleFactor, height: 20 * scaleFactor)
        }
        .frame(minHeight: 72 * scaleFactor) // Fixed minimum height for all cards
        .padding(.horizontal, 18 * scaleFactor)
        .padding(.vertical, 16 * scaleFactor)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 8 * scaleFactor)
                .stroke(isPresent ? colorThresholds.getColor(for: 1.0) : 
                       isChecking ? Color.blue : 
                       colorThresholds.getColor(for: 0.0), 
                       lineWidth: 2)
        )
        .cornerRadius(8 * scaleFactor)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func getSystemIcon(for title: String) -> String {
        let lowercaseTitle = title.lowercased()
        
        // Font-related
        if lowercaseTitle.contains("font") || lowercaseTitle.contains("arial") || lowercaseTitle.contains("helvetica") {
            return "textformat"
        }
        // Template-related  
        if lowercaseTitle.contains("template") || lowercaseTitle.contains("powerpoint") {
            return "doc.richtext"
        }
        // Security-related
        if lowercaseTitle.contains("security") || lowercaseTitle.contains("policy") {
            return "shield.checkered"
        }
        // VPN-related
        if lowercaseTitle.contains("vpn") || lowercaseTitle.contains("network") {
            return "network"
        }
        // Antivirus-related
        if lowercaseTitle.contains("antivirus") || lowercaseTitle.contains("virus") {
            return "checkmark.shield"
        }
        // Backup-related
        if lowercaseTitle.contains("backup") {
            return "externaldrive"
        }
        // Certificate-related
        if lowercaseTitle.contains("certificate") || lowercaseTitle.contains("keychain") {
            return "key"
        }
        // Printer-related
        if lowercaseTitle.contains("print") {
            return "printer"
        }
        // Default
        return "gear"
    }
    
    private func getStatusText() -> String {
        if isChecking {
            return "Checking..."
        } else if let item = item, item.plistKey != nil {
            // For plist validation, use compliance terminology
            return isPresent ? (colorThresholds.excellentLabel ?? "Compliant") : (colorThresholds.criticalLabel ?? "Non-Compliant")
        } else {
            // For file existence, use present/missing terminology
            return isPresent ? "Present" : "Missing"
        }
    }
    
    private func getStatusColor() -> Color {
        if isChecking {
            return .blue
        } else if isPresent {
            return colorThresholds.getColor(for: 1.0)
        } else {
            return colorThresholds.getColor(for: 0.0)
        }
    }
}

// MARK: - Inspection Detail Popover

struct InspectionDetailPopover: View {
    let items: [InspectConfig.ItemConfig]
    let validationResults: [String: Bool]
    let downloadingItems: Set<String>
    let scaleFactor: CGFloat
    let hideSystemDetails: Bool
    let inspectState: InspectState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text("Inspection Details")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(validationResults.values.filter { $0 }.count)/\(items.count) Present")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Scrollable list of items
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(items, id: \.id) { item in
                        InspectionDetailItem(
                            item: item,
                            isPresent: inspectState.plistValidationResults[item.id] ?? false,
                            isChecking: downloadingItems.contains(item.id),
                            scaleFactor: scaleFactor,
                            hideSystemDetails: hideSystemDetails,
                            inspectState: inspectState
                        )
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 400)
        }
        .padding(20)
        .frame(width: 500)
    }
}

// MARK: - Individual Detail Item

struct InspectionDetailItem: View {
    let item: InspectConfig.ItemConfig
    let isPresent: Bool
    let isChecking: Bool
    let scaleFactor: CGFloat
    let hideSystemDetails: Bool
    let inspectState: InspectState
    @State private var showFullPaths = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Item header with status
            HStack {
                // Status indicator
                Circle()
                    .fill(isPresent ? inspectState.colorThresholds.getColor(for: 1.0) : isChecking ? Color.blue : inspectState.colorThresholds.getColor(for: 0.0))
                    .frame(width: 8, height: 8)
                
                // Item name
                Text(item.displayName)
                    .font(.headline.weight(.medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Status text
                Text(getStatusText())
                    .font(.caption.weight(.medium))
                    .foregroundColor(getStatusColor())
            }
            
            // Paths section (conditionally shown)
            if !hideSystemDetails {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Checked Paths:")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if item.paths.count > 1 {
                            Button(showFullPaths ? "Show Less" : "Show All (\(item.paths.count))") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showFullPaths.toggle()
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        }
                    }
                    
                    let pathsToShow = showFullPaths ? item.paths : Array(item.paths.prefix(1))
                    
                    ForEach(Array(pathsToShow.enumerated()), id: \.offset) { index, path in
                        HStack(alignment: .top, spacing: 8) {
                            // Path indicator
                            Circle()
                                .fill(Color.secondary.opacity(0.5))
                                .frame(width: 4, height: 4)
                                .padding(.top, 6)
                            
                            // Path text with word wrapping
                            Text(path)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(showFullPaths ? nil : 2)
                        }
                    }
                    
                    if !showFullPaths && item.paths.count > 1 {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 4, height: 4)
                                .padding(.top, 6)
                            
                            Text("... and \(item.paths.count - 1) more path\(item.paths.count - 1 == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                }
                .padding(.leading, 12)
            } else {
                // Show generic info when paths are hidden
                VStack(alignment: .leading, spacing: 6) {
                    Text("Path Details Hidden")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    
                    Text("Checking \(item.paths.count) configured location\(item.paths.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding(.leading, 12)
            }
            
            // NEW: Plist Key and Value Information (shown when plist validation is configured)
            if let plistKey = item.plistKey {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Plist Validation:")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    
                    // Plist key
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Color.blue.opacity(0.5))
                            .frame(width: 4, height: 4)
                            .padding(.top, 6)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Key:")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                            Text(plistKey)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                        }
                    }
                    
                    // Expected value (if configured)
                    if let expectedValue = item.expectedValue {
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color.orange.opacity(0.5))
                                .frame(width: 4, height: 4)
                                .padding(.top, 6)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Expected:")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.secondary)
                                Text(expectedValue)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.orange)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    
                    // Actual value (from plist)
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(inspectState.colorThresholds.getValidationColor(isValid: isPresent))
                            .frame(width: 4, height: 4)
                            .padding(.top, 6)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Actual:")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                            
                            if let actualValue = inspectState.getPlistValueForDisplay(item: item) {
                                Text(actualValue)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(isPresent ? inspectState.colorThresholds.getColor(for: 1.0) : inspectState.colorThresholds.getColor(for: 0.0))
                                    .textSelection(.enabled)
                            } else {
                                Text("Key not found or file missing")
                                    .font(.caption)
                                    .foregroundColor(inspectState.colorThresholds.getColor(for: 0.0))
                                    .italic()
                            }
                        }
                    }
                }
                .padding(.leading, 12)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isPresent ? inspectState.colorThresholds.getColor(for: 1.0).opacity(0.3) : 
                       isChecking ? Color.blue.opacity(0.3) : 
                       inspectState.colorThresholds.getColor(for: 0.0).opacity(0.3), 
                       lineWidth: 1)
        )
    }
    
    private func getStatusText() -> String {
        if isChecking {
            return "Checking..."
        } else if isPresent {
            return "Present"
        } else {
            return "Missing"
        }
    }
    
    private func getStatusColor() -> Color {
        if isChecking {
            return .blue
        } else if isPresent {
            return inspectState.colorThresholds.getColor(for: 1.0)
        } else {
            return inspectState.colorThresholds.getColor(for: 0.0)
        }
    }
}