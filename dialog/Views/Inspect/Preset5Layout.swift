//
//  Preset5Layout.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 22/07/2025
//  Security Compliance Dashboard - Corporate style layout
//

import SwiftUI

struct Preset5Layout: View, InspectLayoutProtocol {
    @ObservedObject var inspectState: InspectState
    let isMini: Bool
    @State private var showingAboutPopover = false
    @State private var complianceData: [ComplianceCategory] = []
    @State private var lastCheck: String = ""
    @State private var overallScore: Double = 0.0
    @State private var criticalIssues: [ComplianceItem] = []
    @State private var allFailingItems: [ComplianceItem] = []
    
    init(inspectState: InspectState, isMini: Bool = false) {
        self.inspectState = inspectState
        self.isMini = isMini
    }
    
    var body: some View {
        let scale: CGFloat = isMini ? 0.75 : 1.0
        
        VStack(spacing: 0) {
            // Header Section - Corporate Style
            VStack(spacing: 16 * scale) {
                // Security Icon and Title
                HStack(spacing: 12 * scale) {
                    // Icon from configuration
                    IconView(image: inspectState.uiConfiguration.iconPath ?? "", defaultImage: "shield.checkered", defaultColour: "accent")
                            .frame(width: 52 * scale, height: 52 * scale)
                    
                    VStack(alignment: .leading, spacing: 2 * scale) {
                        Text(inspectState.uiConfiguration.windowTitle)
                            .font(.system(size: 20 * scale, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if let message = inspectState.uiConfiguration.subtitleMessage, !message.isEmpty {
                            Text(message)
                                .font(.system(size: 14 * scale))
                                .foregroundColor(.secondary)
                        } else {
                            Text("Last Check: \(lastCheck)")
                                .font(.system(size: 12 * scale))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 32 * scale)
                .padding(.top, 24 * scale)
                
                // Overall Progress Bar - Cleaner design
                VStack(spacing: 8 * scale) {
                    HStack {
                        // Progress fraction - smaller text
                        Text("\(Int(overallScore * Double(getTotalChecks())))/\(getTotalChecks())")
                            .font(.system(size: 16 * scale, weight: .semibold, design: .monospaced))
                            .foregroundColor(.primary)
                        
                        // Progress bar - thinner and more refined
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                Rectangle()
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(height: 4 * scale)
                                    .cornerRadius(2 * scale)
                                
                                // Progress fill
                                Rectangle()
                                    .fill(inspectState.colorThresholds.getColor(for: overallScore))
                                    .frame(width: geometry.size.width * overallScore, height: 4 * scale)
                                    .cornerRadius(2 * scale)
                            }
                        }
                        .frame(height: 4 * scale)
                        
                        Spacer()
                        
                        // Status indicators - cleaner design
                        HStack(spacing: 12 * scale) {
                            HStack(spacing: 3 * scale) {
                                Circle()
                                    .fill(inspectState.colorThresholds.getPositiveColor())
                                    .frame(width: 8 * scale, height: 8 * scale)
                                Text("\(getPassedCount())")
                                    .font(.system(size: 12 * scale, weight: .medium))
                                    .foregroundColor(inspectState.colorThresholds.getPositiveColor())
                            }
                            
                            HStack(spacing: 3 * scale) {
                                Circle()
                                    .fill(inspectState.colorThresholds.getNegativeColor())
                                    .frame(width: 8 * scale, height: 8 * scale)
                                Text("\(getFailedCount())")
                                    .font(.system(size: 12 * scale, weight: .medium))
                                    .foregroundColor(inspectState.colorThresholds.getNegativeColor())
                            }
                        }
                    }
                }
                .padding(.horizontal, 32 * scale)
                .padding(.bottom, 20 * scale)
            }
            
            Spacer()
            
            // Category Breakdown Section - Enhanced layout with more space
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16 * scale),
                    GridItem(.flexible(), spacing: 16 * scale)
                ], spacing: 12 * scale) {
                    ForEach(complianceData, id: \.name) { category in
                        CategoryCardView(category: category, scale: scale, colorThresholds: inspectState.colorThresholds, inspectState: inspectState)
                    }
                }
                .padding(.horizontal, 32 * scale)
            }
            
            Spacer()
            
            // Bottom Action Area
            HStack(spacing: 20 * scale) {
                Button(inspectState.uiConfiguration.popupButtonText) {
                    showingAboutPopover.toggle()
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .font(.body)
                .popover(isPresented: $showingAboutPopover, arrowEdge: .top) {
                    ComplianceDetailsPopoverView(
                        complianceData: complianceData,
                        criticalIssues: criticalIssues,
                        allFailingItems: allFailingItems,
                        lastCheck: lastCheck,
                        inspectState: inspectState
                    )
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    if inspectState.buttonConfiguration.button2Visible && !inspectState.buttonConfiguration.button2Text.isEmpty {
                        Button(inspectState.buttonConfiguration.button2Text) {
                            writeLog("Preset5Layout: User clicked button2 (\(inspectState.buttonConfiguration.button2Text)) - exiting with code 2", logLevel: .info)
                            exit(2)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(inspectState.buttonConfiguration.button2Disabled)
                    }
                    
                    Button(inspectState.buttonConfiguration.button1Text) {
                        writeLog("Preset5Layout: User clicked button1 (\(inspectState.buttonConfiguration.button1Text)) - exiting with code 0", logLevel: .info)
                        exit(0)
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(inspectState.buttonConfiguration.button1Disabled)
                }
            }
            .padding(.horizontal, 32 * scale)
            .padding(.bottom, 30 * scale)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadComplianceData()
        }
        .onChange(of: inspectState.items.count) { _ in
            loadComplianceData()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadComplianceData() {
        // Check if we have complex plist sources (for mSCP audit) OR simple item validation
        let hasComplexPlist = inspectState.plistSources != nil
        let hasSimpleValidation = inspectState.items.contains { $0.plistKey != nil }
        let hasRegularItems = !inspectState.items.isEmpty
        
        guard hasComplexPlist || hasSimpleValidation || hasRegularItems else {
            writeLog("Preset5Layout: No configuration found", logLevel: .info)
            return
        }
        
        // Handle complex plist sources (existing mSCP audit functionality)
        if let plistSources = inspectState.plistSources {
            loadComplexPlistData(from: plistSources)
            return
        }
        
        // Handle simple validation (plist + file existence checks)
        if hasSimpleValidation || hasRegularItems {
            loadSimpleItemValidation()
        }
    }
    
    private func loadComplexPlistData(from plistSources: [InspectConfig.PlistSourceConfig]) {
        
        // Memory-safe loading with autorelease pool
        autoreleasepool {
            var allItems: [ComplianceItem] = []
            var latestCheck = ""
            
            // Limit concurrent processing to prevent memory spikes
            let maxSources = 10
            let sourcesToProcess = Array(plistSources.prefix(maxSources))
            
            if plistSources.count > maxSources {
                writeLog("Preset5Layout: Limiting plist processing to \(maxSources) sources", logLevel: .info)
            }
            
            for source in sourcesToProcess {
                autoreleasepool {
                    if let result = loadPlistSource(source: source) {
                        allItems.append(contentsOf: result.items)
                        if result.lastCheck > latestCheck {
                            latestCheck = result.lastCheck
                        }
                    }
                }
            }
            
            // Process data with memory cleanup
            let processedData = autoreleasepool { () -> ([ComplianceCategory], [ComplianceItem], [ComplianceItem]) in
                let categories = categorizeItems(allItems)
                let critical = allItems.filter { !$0.finding && $0.isCritical }
                let allFailing = allItems.filter { !$0.finding }
                return (categories, critical, allFailing)
            }
            
            // Update UI state
            complianceData = processedData.0
            lastCheck = latestCheck.isEmpty ? getCurrentTimestamp() : latestCheck
            overallScore = calculateOverallScore(allItems)
            criticalIssues = processedData.1
            allFailingItems = processedData.2
            
            writeLog("Preset5Layout: Loaded \(allItems.count) items from \(sourcesToProcess.count) plist sources", logLevel: .info)
        }
    }
    
    private func loadPlistSource(source: InspectConfig.PlistSourceConfig) -> (items: [ComplianceItem], lastCheck: String)? {
        // Memory safety: Check file size first to avoid loading huge plists
        let _ = URL(fileURLWithPath: source.path)
        guard let fileAttributes = try? FileManager.default.attributesOfItem(atPath: source.path),
              let fileSize = fileAttributes[.size] as? Int64 else {
            writeLog("Preset5Layout: Unable to get file attributes for \(source.path)", logLevel: .error)
            return nil
        }
        
        // Prevent loading files larger than 10MB
        let maxFileSize: Int64 = 10 * 1024 * 1024 // 10MB
        if fileSize > maxFileSize {
            writeLog("Preset5Layout: Plist file too large (\(fileSize) bytes) at \(source.path)", logLevel: .error)
            return nil
        }
        
        // Use autorelease pool for memory management
        return autoreleasepool { () -> (items: [ComplianceItem], lastCheck: String)? in
            guard let fileData = FileManager.default.contents(atPath: source.path) else {
                writeLog("Preset5Layout: Unable to read plist at \(source.path)", logLevel: .error)
                return nil
            }
            
            do {
                // Use PropertyListSerialization with explicit cleanup
                let plistObject = try PropertyListSerialization.propertyList(from: fileData, format: nil)
                
                guard let plistContents = plistObject as? [String: Any] else {
                    writeLog("Preset5Layout: Invalid plist format at \(source.path)", logLevel: .error)
                    return nil
                }
                
                var items: [ComplianceItem] = []
                let lastCheck = plistContents["lastComplianceCheck"] as? String ?? 
                               plistContents["LastUpdateCheck"] as? String ?? 
                               getCurrentTimestamp()
                
                // Process items with memory-conscious approach
                let maxItems = 1000 // Prevent processing too many items
                var processedCount = 0
                
                for (key, value) in plistContents {
                    if processedCount >= maxItems {
                        writeLog("Preset5Layout: Limiting plist processing to \(maxItems) items for \(source.path)", logLevel: .info)
                        break
                    }
                    
                    if shouldProcessKey(key, source: source) {
                        if let finding = evaluateValue(value, source: source) {
                            let item = ComplianceItem(
                                id: String(key), // Ensure string copy, not reference
                                category: getCategoryForKey(key, source: source),
                                finding: finding,
                                isCritical: isCriticalKey(key, source: source)
                            )
                            items.append(item)
                            processedCount += 1
                        }
                    }
                }
                
                writeLog("Preset5Layout: Successfully processed \(items.count) items from \(source.path) (\(fileSize) bytes)", logLevel: .info)
                return (items, lastCheck)
                
            } catch {
                writeLog("Preset5Layout: Error parsing plist at \(source.path): \(error)", logLevel: .error)
                return nil
            }
        }
    }
    
    private func shouldProcessKey(_ key: String, source: InspectConfig.PlistSourceConfig) -> Bool {
        // Skip timestamp and metadata keys
        let skipKeys = ["lastComplianceCheck", "LastUpdateCheck", "CFBundleVersion", "_"]
        if skipKeys.contains(key) || key.hasPrefix("_") { return false }
        
        // If key mappings exist, only process mapped keys
        if let keyMappings = source.keyMappings {
            return keyMappings.contains { $0.key == key }
        }
        
        // For compliance type, process all non-metadata keys
        if source.type == "compliance" {
            return true
        }
        
        // For other types, be more selective
        return true
    }
    
    private func evaluateValue(_ value: Any, source: InspectConfig.PlistSourceConfig) -> Bool? {
        let successValues = source.successValues ?? ["true", "1", "YES"]
        
        if let boolValue = value as? Bool {
            // Check if the boolean value (as string) is in successValues
            return successValues.contains(String(boolValue))
        }
        
        if let stringValue = value as? String {
            return successValues.contains(stringValue)
        }
        
        if let numberValue = value as? NSNumber {
            return successValues.contains(numberValue.stringValue)
        }
        
        if let dictValue = value as? [String: Any] {
            // For compliance plists with nested structure
            if let finding = dictValue["finding"] as? Bool {
                // Check if the boolean finding value is in successValues
                return successValues.contains(String(finding))
            }
        }
        
        return nil
    }
    
    private func getCategoryForKey(_ key: String, source: InspectConfig.PlistSourceConfig) -> String {
        // Check key mappings first
        if let keyMappings = source.keyMappings {
            if let mapping = keyMappings.first(where: { $0.key == key }),
               let category = mapping.category {
                return category
            }
        }
        
        // Check category prefixes
        if let categoryPrefix = source.categoryPrefix {
            for (prefix, category) in categoryPrefix {
                if key.hasPrefix(prefix) {
                    return category
                }
            }
        }
        
        // Fallback to source display name or generic categorization
        return source.displayName
    }
    
    private func isCriticalKey(_ key: String, source: InspectConfig.PlistSourceConfig) -> Bool {
        // Check key mappings first
        if let keyMappings = source.keyMappings {
            if let mapping = keyMappings.first(where: { $0.key == key }),
               let isCritical = mapping.isCritical {
                return isCritical
            }
        }
        
        // Check critical keys list
        if let criticalKeys = source.criticalKeys {
            return criticalKeys.contains(key)
        }
        
        return false
    }
    
    // NEW: Simple item validation for non-audit use cases
    private func loadSimpleItemValidation() {
        var items: [ComplianceItem] = []
        
        for item in inspectState.items {
            let isValid: Bool
            
            // Check if this item needs plist validation
            if item.plistKey != nil {
                // Use plist validation
                isValid = inspectState.validatePlistItem(item)
            } else {
                // Simple file existence check
                isValid = item.paths.first(where: { FileManager.default.fileExists(atPath: $0) }) != nil ||
                         inspectState.completedItems.contains(item.id)
            }
            
            // Create ComplianceItem from validation result
            // Use intelligent categorization with multiple fallback options
            let category: String
            let isCritical: Bool
            
            // Priority 1: Direct category specification
            if let itemCategory = item.category {
                category = itemCategory
                isCritical = false // Can be enhanced later
            }
            // Priority 2: plistSources configuration
            else if let plistKey = item.plistKey,
                    let firstSource = inspectState.plistSources?.first {
                category = getCategoryForKey(plistKey, source: firstSource)
                isCritical = isCriticalKey(plistKey, source: firstSource)
            }
            // Priority 3: Fallback for non-plist items
            else {
                category = "Applications"
                isCritical = false
            }
            
            let complianceItem = ComplianceItem(
                id: item.id,
                category: category,
                finding: isValid,
                isCritical: isCritical
            )
            
            items.append(complianceItem)
        }
        
        // Update UI state with validation results
        complianceData = categorizeItems(items)
        lastCheck = getCurrentTimestamp()
        overallScore = calculateOverallScore(items)
        criticalIssues = items.filter { !$0.finding && $0.isCritical }
        allFailingItems = items.filter { !$0.finding }
        
        writeLog("Preset5Layout: Loaded \(items.count) items from validation (plist + file checks)", logLevel: .info)
    }
    
    private func getCurrentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
    
    private func categorizeItems(_ items: [ComplianceItem]) -> [ComplianceCategory] {
        let grouped = Dictionary(grouping: items) { $0.category }
        
        return grouped.map { category, items in
            let passed = items.filter { $0.finding }.count
            let total = items.count
            let score = total > 0 ? Double(passed) / Double(total) : 0.0
            
            return ComplianceCategory(
                name: category,
                passed: passed,
                total: total,
                score: score,
                icon: getCategoryIcon(category)
            )
        }.sorted { $0.name < $1.name }
    }
    
    private func categorizeItemID(_ id: String) -> String {
        if id.hasPrefix("audit_") { return "Audit Controls" }
        if id.hasPrefix("auth_") { return "Authentication" }
        if id.hasPrefix("icloud_") { return "iCloud Security" }
        if id.hasPrefix("os_") { return "OS Security" }
        if id.hasPrefix("pwpolicy_") { return "Password Policy" }
        if id.hasPrefix("system_settings_") { return "System Settings" }
        return "Other"
    }
    
    private func getCategoryIcon(_ category: String) -> String {
        // Priority 1: Check if any item has specified a custom categoryIcon for this category
        for item in inspectState.items {
            if let itemCategory = item.category,
               itemCategory == category,
               let categoryIcon = item.categoryIcon {
                return categoryIcon
            }
        }
        
        // Priority 2: Check if we have plistSources with an icon configuration
        if let plistSources = inspectState.plistSources {
            for source in plistSources {
                // Check if this category matches any categoryPrefix from this source
                if let categoryPrefix = source.categoryPrefix {
                    for (_, prefixCategory) in categoryPrefix {
                        if prefixCategory == category {
                            // Use the icon from plistSources configuration
                            return source.icon ?? "shield"
                        }
                    }
                }
                // If category matches the source displayName, use source icon
                if source.displayName == category {
                    return source.icon ?? "shield"
                }
            }
        }
        
        // Priority 3: Simple fallback for common categories - use info icon to indicate help is available
        return "info.circle"
    }
    
    private func isCriticalItem(_ id: String) -> Bool {
        let criticalItems = [
            "os_anti_virus_installed",
            "os_firmware_password_require",
            "system_settings_critical_update_install_enforce",
            "os_sip_enable",
            "system_settings_firewall_enable"
        ]
        return criticalItems.contains(id)
    }
    
    private func calculateOverallScore(_ items: [ComplianceItem]) -> Double {
        guard !items.isEmpty else { return 0.0 }
        let passed = items.filter { $0.finding }.count
        return Double(passed) / Double(items.count)
    }
    
    private func getTotalChecks() -> Int {
        return complianceData.reduce(0) { $0 + $1.total }
    }
    
    private func getPassedCount() -> Int {
        return complianceData.reduce(0) { $0 + $1.passed }
    }
    
    private func getFailedCount() -> Int {
        return getTotalChecks() - getPassedCount()
    }
    
    private func formatIssueTitle(_ id: String) -> String {
        return id.replacingOccurrences(of: "_", with: " ")
            .capitalized
            .trimmingCharacters(in: .whitespaces)
    }
    
}

// MARK: - Supporting Views

struct CategoryRowView: View {
    let category: ComplianceCategory
    let scale: CGFloat
    let colorThresholds: InspectConfig.ColorThresholds
    
    var body: some View {
        HStack(spacing: 16 * scale) {
            // Category icon
            Image(systemName: category.icon)
                .font(.system(size: 20 * scale))
                .foregroundColor(.blue)
                .frame(width: 24 * scale)
            
            // Category name
            Text(category.name)
                .font(.system(size: 16 * scale, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            // Progress indicator
            HStack(spacing: 8 * scale) {
                // Status icon
                Image(systemName: colorThresholds.getStatusIcon(for: category.score))
                    .font(.system(size: 14 * scale))
                    .foregroundColor(colorThresholds.getColor(for: category.score))
                
                // Score text
                Text("\(category.passed)/\(category.total)")
                    .font(.system(size: 14 * scale, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
                
                // Percentage
                Text("(\(Int(category.score * 100))%)")
                    .font(.system(size: 14 * scale))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8 * scale)
        .padding(.horizontal, 16 * scale)
        .background(
            RoundedRectangle(cornerRadius: 8 * scale)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

struct CategoryCardView: View {
    let category: ComplianceCategory
    let scale: CGFloat
    let colorThresholds: InspectConfig.ColorThresholds
    let inspectState: InspectState
    @State private var showingCategoryHelp = false
    
    var body: some View {
        VStack(spacing: 8 * scale) {
            // Header with icon and status
            HStack {
                // Make the category icon clickable for help
                Button(action: {
                    showingCategoryHelp = true
                }) {
                    Image(systemName: category.icon)
                        .font(.system(size: 16 * scale, weight: .medium))
                        .foregroundColor(.blue)
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 24 * scale, height: 24 * scale)
                        )
                }
                .buttonStyle(.plain)
                .help("Click for category information and recommendations")
                .popover(isPresented: $showingCategoryHelp) {
                    CategoryHelpPopover(category: category, scale: scale, inspectState: inspectState)
                }
                
                Spacer()
                
                // Status icon
                Image(systemName: colorThresholds.getStatusIcon(for: category.score))
                    .font(.system(size: 14 * scale))
                    .foregroundColor(colorThresholds.getColor(for: category.score))
            }
            
            // Category name
            Text(category.name)
                .font(.system(size: 14 * scale, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(minHeight: 28 * scale)
            
            // Progress bar - higher contrast
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(height: 4 * scale)
                        .cornerRadius(2 * scale)
                    
                    Rectangle()
                        .fill(colorThresholds.getColor(for: category.score))
                        .frame(width: geometry.size.width * category.score, height: 4 * scale)
                        .cornerRadius(2 * scale)
                }
            }
            .frame(height: 4 * scale)
            .overlay(
                RoundedRectangle(cornerRadius: 2 * scale)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
            )
            
            // Score text
            Text("\(category.passed)/\(category.total) (\(Int(category.score * 100))%)")
                .font(.system(size: 12 * scale, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
        }
        .padding(12 * scale)
        .background(
            RoundedRectangle(cornerRadius: 8 * scale)
                .fill(Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8 * scale)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct ComplianceDetailsPopoverView: View {
    let complianceData: [ComplianceCategory]
    let criticalIssues: [ComplianceItem]
    let allFailingItems: [ComplianceItem]
    let lastCheck: String
    let inspectState: InspectState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Security Details")
                    .font(.headline)
                
                Text("Last Check: \(lastCheck)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Show all items evaluation details (both plist and file checks)
                if !inspectState.items.isEmpty {
                    Divider()
                    
                    Text("Item Evaluation Details")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    // Group items by category for better organization
                    let groupedItems = Dictionary(grouping: inspectState.items) { item in
                        item.category ?? "Other"
                    }
                    
                    ForEach(groupedItems.keys.sorted(), id: \.self) { category in
                        if let categoryItems = groupedItems[category] {
                            VStack(alignment: .leading, spacing: 12) {
                                // Category header
                                HStack {
                                    Image(systemName: categoryItems.first?.categoryIcon ?? "folder")
                                        .font(.system(size: 14))
                                        .foregroundColor(.blue)
                                    Text(category)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    
                                    // Category summary
                                    let validCount = categoryItems.filter { item in
                                        isItemValid(item)
                                    }.count
                                    
                                    Text("\(validCount)/\(categoryItems.count)")
                                        .font(.caption)
                                        .foregroundColor(validCount == categoryItems.count ? inspectState.colorThresholds.getPositiveColor() : .orange)
                                }
                                .padding(.top, 8)
                    
                    ForEach(categoryItems.sorted(by: { $0.guiIndex < $1.guiIndex }), id: \.id) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            // Item header
                            HStack {
                                let isValid = isItemValid(item)
                                
                                Circle()
                                    .fill(inspectState.colorThresholds.getValidationColor(isValid: isValid))
                                    .frame(width: 8, height: 8)
                                
                                Text(item.displayName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            
                            // Plist details
                            if let plistKey = item.plistKey {
                                VStack(alignment: .leading, spacing: 4) {
                                    // Key
                                    HStack {
                                        Text("Key:")
                                            .font(.caption.weight(.medium))
                                            .foregroundColor(.secondary)
                                            .frame(width: 60, alignment: .leading)
                                        Text(plistKey)
                                            .font(.system(.caption, design: .monospaced))
                                            .textSelection(.enabled)
                                    }
                                    
                                    // Expected value
                                    if let expectedValue = item.expectedValue {
                                        HStack {
                                            Text("Expected:")
                                                .font(.caption.weight(.medium))
                                                .foregroundColor(.secondary)
                                                .frame(width: 60, alignment: .leading)
                                            Text(expectedValue)
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundColor(.orange)
                                                .textSelection(.enabled)
                                        }
                                    }
                                    
                                    // Actual value
                                    HStack {
                                        Text("Actual:")
                                            .font(.caption.weight(.medium))
                                            .foregroundColor(.secondary)
                                            .frame(width: 60, alignment: .leading)
                                        
                                        if let actualValue = inspectState.getPlistValueForDisplay(item: item) {
                                            Text(actualValue)
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundColor(inspectState.colorThresholds.getValidationColor(isValid: inspectState.validatePlistItem(item)))
                                                .textSelection(.enabled)
                                        } else {
                                            Text("Key not found")
                                                .font(.caption)
                                                .foregroundColor(inspectState.colorThresholds.getNegativeColor())
                                                .italic()
                                        }
                                    }
                                    
                                    // Path
                                    if let path = item.paths.first {
                                        HStack {
                                            Text("Path:")
                                                .font(.caption.weight(.medium))
                                                .foregroundColor(.secondary)
                                                .frame(width: 60, alignment: .leading)
                                            Text(path)
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                                .textSelection(.enabled)
                                        }
                                    }
                                }
                                .padding(.leading, 12)
                            } else {
                                // File existence check details
                                VStack(alignment: .leading, spacing: 4) {
                                    // Evaluation type
                                    HStack {
                                        Text("Type:")
                                            .font(.caption.weight(.medium))
                                            .foregroundColor(.secondary)
                                            .frame(width: 60, alignment: .leading)
                                        Text("File Existence Check")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    // Check all paths
                                    ForEach(item.paths, id: \.self) { path in
                                        let fileExists = FileManager.default.fileExists(atPath: path)
                                        HStack {
                                            Text("Path:")
                                                .font(.caption.weight(.medium))
                                                .foregroundColor(.secondary)
                                                .frame(width: 60, alignment: .leading)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(path)
                                                    .font(.system(.caption, design: .monospaced))
                                                    .foregroundColor(inspectState.colorThresholds.getValidationColor(isValid: fileExists))
                                                    .lineLimit(2)
                                                    .textSelection(.enabled)
                                                
                                                Text(fileExists ? "✓ File exists" : "✗ File not found")
                                                    .font(.caption)
                                                    .foregroundColor(inspectState.colorThresholds.getValidationColor(isValid: fileExists))
                                            }
                                        }
                                    }
                                    
                                    // File info if exists
                                    if let existingPath = item.paths.first(where: { FileManager.default.fileExists(atPath: $0) }) {
                                        if let attributes = try? FileManager.default.attributesOfItem(atPath: existingPath) {
                                            // File size
                                            if let fileSize = attributes[.size] as? Int64 {
                                                HStack {
                                                    Text("Size:")
                                                        .font(.caption.weight(.medium))
                                                        .foregroundColor(.secondary)
                                                        .frame(width: 60, alignment: .leading)
                                                    Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            
                                            // Modification date
                                            if let modDate = attributes[.modificationDate] as? Date {
                                                HStack {
                                                    Text("Modified:")
                                                        .font(.caption.weight(.medium))
                                                        .foregroundColor(.secondary)
                                                        .frame(width: 60, alignment: .leading)
                                                    Text(modDate, style: .date)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.leading, 12)
                            }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        )
                    }
                            } // End VStack for category
                        } // End if let categoryItems
                    } // End ForEach categories
                } // End if !inspectState.items.isEmpty
                
                if inspectState.items.isEmpty && !allFailingItems.isEmpty {
                    // Show enhanced audit issues for complex validation
                    Divider()
                    
                    // Enhanced header with context
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.shield.fill")
                                .foregroundColor(inspectState.colorThresholds.getNegativeColor())
                                .font(.subheadline)
                            Text("Security Compliance Issues")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        // Show audit source context
                        if let plistSources = inspectState.plistSources,
                           let firstSource = plistSources.first {
                            Text("Source: \(firstSource.displayName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("The following controls require attention:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 8)
                    
                    // Show all failing compliance items, with critical ones first
                    let sortedFailingItems = getAllFailingComplianceItems()
                    ForEach(sortedFailingItems, id: \.id) { issue in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(inspectState.colorThresholds.getNegativeColor())
                                    .font(.caption)
                                
                                Text(formatAuditControlTitle(issue.id))
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                // Show category badge
                                Text(issue.category)
                                    .font(.system(.caption2))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(4)
                            }
                            
                            // Show control description/context from config
                            if let context = getContextFromPlistSources(for: issue.id) {
                                Text(context)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 16)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    
                    // Summary footer with correct counts
                    let totalFailingCount = sortedFailingItems.count
                    let criticalFailingCount = sortedFailingItems.filter { $0.isCritical }.count
                    
                    if totalFailingCount > 0 {
                        Divider()
                            .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                
                                Text("\(totalFailingCount) control(s) need remediation")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if criticalFailingCount > 0 {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(inspectState.colorThresholds.getNegativeColor())
                                        .font(.caption)
                                    
                                    Text("\(criticalFailingCount) are critical priority")
                                        .font(.caption)
                                        .foregroundColor(inspectState.colorThresholds.getNegativeColor())
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .frame(maxWidth: 500, maxHeight: 400)
    }
    
    // Helper function to validate items
    private func isItemValid(_ item: InspectConfig.ItemConfig) -> Bool {
        if item.plistKey != nil {
            return inspectState.validatePlistItem(item)
        } else {
            return item.paths.first(where: { FileManager.default.fileExists(atPath: $0) }) != nil
        }
    }
    
    // Enhanced formatting for audit control titles using config data
    private func formatAuditControlTitle(_ id: String) -> String {
        // Use keyMappings from plistSources if available for custom titles
        if let plistSources = inspectState.plistSources {
            for source in plistSources {
                if let keyMappings = source.keyMappings {
                    if let mapping = keyMappings.first(where: { $0.key == id }),
                       let displayName = mapping.displayName {
                        return displayName
                    }
                }
            }
        }
        
        // Fallback: smart prefix removal and formatting
        var cleanedId = id
        if let plistSources = inspectState.plistSources,
           let firstSource = plistSources.first,
           let categoryPrefix = firstSource.categoryPrefix {
            // Remove category prefixes dynamically
            for (prefix, _) in categoryPrefix {
                if id.hasPrefix(prefix) {
                    cleanedId = String(id.dropFirst(prefix.count))
                    break
                }
            }
        }
        
        // Convert underscores to spaces and capitalize
        return cleanedId
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
            .trimmingCharacters(in: .whitespaces)
    }
    
    // Get context/description from plistSources configuration
    private func getContextFromPlistSources(for id: String) -> String? {
        guard let plistSources = inspectState.plistSources else { return nil }
        
        for source in plistSources {
            // Check if source has a general description for critical keys
            if let criticalKeys = source.criticalKeys,
               criticalKeys.contains(id) {
                return "Critical security control - requires immediate attention"
            }
        }
        
        return nil
    }
    
    // Check if there are any failing compliance items (beyond just critical ones)
    private func hasFailingComplianceItems() -> Bool {
        return !allFailingItems.isEmpty
    }
    
    // Get all failing compliance items, with critical ones first
    private func getAllFailingComplianceItems() -> [ComplianceItem] {
        // Sort so critical items appear first
        return allFailingItems.sorted { item1, item2 in
            if item1.isCritical && !item2.isCritical {
                return true // Critical items first
            } else if !item1.isCritical && item2.isCritical {
                return false
            } else {
                return item1.category < item2.category // Then by category
            }
        }
    }
    
    // Helper to determine if an item is critical based on plistSources
    private func isCriticalItem(_ id: String) -> Bool {
        guard let plistSources = inspectState.plistSources,
              let firstSource = plistSources.first,
              let criticalKeys = firstSource.criticalKeys else {
            return false
        }
        return criticalKeys.contains(id)
    }
}

// MARK: - Data Models

struct ComplianceItem {
    let id: String
    let category: String
    let finding: Bool
    let isCritical: Bool
}

struct ComplianceCategory {
    let name: String
    let passed: Int
    let total: Int
    let score: Double
    let icon: String
}

// MARK: - Category Help Popover
struct CategoryHelpPopover: View {
    let category: ComplianceCategory
    let scale: CGFloat
    let inspectState: InspectState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text(category.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Divider()
            
            // Description based on category
            Text(getCategoryDescription())
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Compliance status
            VStack(alignment: .leading, spacing: 8) {
                Text(getStatusLabel())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack {
                    ProgressView(value: category.score)
                        .progressViewStyle(LinearProgressViewStyle(tint: getScoreColor()))
                    
                    Text("\(Int(category.score * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(getScoreColor())
                }
                
                Text(getChecksPassedText())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Recommendations
            if category.score < 1.0 {
                Divider()
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(getRecommendationsLabel())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(getRecommendations())
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .frame(width: 320 * scale)
    }
    
    private func getCategoryDescription() -> String {
        // First check if there's custom help content in the configuration
        if let categoryHelp = inspectState.config?.categoryHelp {
            if let help = categoryHelp.first(where: { $0.category == category.name }) {
                return help.description
            }
        }
        
        // Fallback to generic description
        return "Security controls and configurations for \(category.name.lowercased()) to ensure compliance with organizational policies and industry standards."
    }
    
    private func getRecommendations() -> String {
        let failedCount = category.total - category.passed
        
        // First check if there's custom help content in the configuration
        if let categoryHelp = inspectState.config?.categoryHelp {
            if let help = categoryHelp.first(where: { $0.category == category.name }) {
                if let recommendations = help.recommendations {
                    return recommendations
                }
            }
        }
        
        // Fallback to generic recommendations
        return "Review and remediate the \(failedCount) failing check\(failedCount == 1 ? "" : "s") in this category to improve security posture."
    }
    
    private func getScoreColor() -> Color {
        if category.score >= 0.9 {
            return .green
        } else if category.score >= 0.75 {
            return .blue
        } else if category.score >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func getStatusLabel() -> String {
        // First check category-specific label
        if let categoryHelp = inspectState.config?.categoryHelp {
            if let help = categoryHelp.first(where: { $0.category == category.name }) {
                if let statusLabel = help.statusLabel {
                    return statusLabel
                }
            }
        }
        
        // Then check global UI labels
        if let uiLabels = inspectState.config?.uiLabels {
            if let complianceStatus = uiLabels.complianceStatus {
                return complianceStatus
            }
        }
        
        // Default fallback
        return "Compliance Status"
    }
    
    private func getRecommendationsLabel() -> String {
        // First check category-specific label
        if let categoryHelp = inspectState.config?.categoryHelp {
            if let help = categoryHelp.first(where: { $0.category == category.name }) {
                if let recommendationsLabel = help.recommendationsLabel {
                    return recommendationsLabel
                }
            }
        }
        
        // Then check global UI labels
        if let uiLabels = inspectState.config?.uiLabels {
            if let recommendedActions = uiLabels.recommendedActions {
                return recommendedActions
            }
        }
        
        // Default fallback
        return "Recommended Actions"
    }
    
    private func getChecksPassedText() -> String {
        // Check for custom format in UI labels
        if let uiLabels = inspectState.config?.uiLabels {
            if let checksPassed = uiLabels.checksPassed {
                // Replace placeholders with actual values
                return checksPassed
                    .replacingOccurrences(of: "{passed}", with: "\(category.passed)")
                    .replacingOccurrences(of: "{total}", with: "\(category.total)")
            }
        }
        
        // Default format
        return "\(category.passed) of \(category.total) checks passed"
    }
}
