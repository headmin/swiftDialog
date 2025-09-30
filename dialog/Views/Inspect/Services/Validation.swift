//
//  Validation.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 25/07/2025
//  Centralized validation service for all file and plist validation logic
//  Integrates caching, batch processing, and async validation
//

import Foundation
import Combine

// MARK: - Validation Models

struct ValidationRequest {
    let item: InspectConfig.ItemConfig
    let plistSources: [InspectConfig.PlistSourceConfig]?
}

struct ValidationResult {
    let itemId: String
    let isValid: Bool
    let validationType: ValidationType
    let details: ValidationDetails?
}

enum ValidationType {
    case fileExistence
    case plistValidation
    case complexPlistValidation
}

struct ValidationDetails {
    let path: String
    let key: String?
    let expectedValue: String?
    let actualValue: String?
    let evaluationType: String?
}

// MARK: - Validation Service

class Validation: ObservableObject {

    // MARK: - Singleton
    static let shared = Validation()

    // MARK: - Caching
    private struct CachedPlist {
        let data: [String: Any]
        let lastModified: Date
        let fileSize: Int64
    }

    private var plistCache = [String: CachedPlist]()
    private let cacheQueue = DispatchQueue(label: "validation.cache", attributes: .concurrent)
    private let validationQueue = DispatchQueue(label: "validation.queue", qos: .userInitiated, attributes: .concurrent)

    // MARK: - Publishers
    @Published var validationProgress: Double = 0.0
    @Published var isValidating: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public API

    /// Batch validation with progress reporting
    func validateItemsBatch(_ items: [InspectConfig.ItemConfig],
                           plistSources: [InspectConfig.PlistSourceConfig]? = nil,
                           completion: @escaping ([String: Bool]) -> Void) {

        DispatchQueue.main.async {
            self.isValidating = true
            self.validationProgress = 0.0
        }

        validationQueue.async { [weak self] in
            guard let self = self else { return }

            var results = [String: Bool]()
            let totalItems = items.count
            var completed = 0

            // Pre-cache all unique plist files
            self.preCachePlists(from: items, and: plistSources)

            // Process items concurrently with limited width
            let semaphore = DispatchSemaphore(value: 4)
            let resultQueue = DispatchQueue(label: "results", attributes: .concurrent)
            let group = DispatchGroup()

            for item in items {
                group.enter()
                self.validationQueue.async {
                    semaphore.wait()
                    defer {
                        semaphore.signal()
                        group.leave()
                    }

                    let request = ValidationRequest(item: item, plistSources: plistSources)
                    let result = self.validateItemCached(request)

                    resultQueue.async(flags: .barrier) {
                        results[item.id] = result.isValid
                        completed += 1
                        let progress = Double(completed) / Double(totalItems)

                        DispatchQueue.main.async {
                            self.validationProgress = progress
                        }
                    }
                }
            }

            group.wait()

            DispatchQueue.main.async {
                self.isValidating = false
                self.validationProgress = 1.0
                completion(results)
            }
        }
    }

    /// Single item validation (cached)
    func validateItemCached(_ request: ValidationRequest) -> ValidationResult {
        let item = request.item

        // Check for simplified plist validation first
        if item.plistKey != nil {
            return validateSimplePlistItemCached(item)
        }

        // Check for complex plist sources validation
        if let plistSources = request.plistSources {
            for source in plistSources where item.paths.contains(source.path) {
                return validateComplexPlistItemCached(item, source: source)
            }
        }

        // Fallback to file existence validation
        return validateFileExistence(item)
    }

    /// Main validation entry point (synchronous for backward compatibility)
    func validateItem(_ request: ValidationRequest) -> ValidationResult {
        let item = request.item
        
        // Check for simplified plist validation first
        if item.plistKey != nil {
            return validateSimplePlistItem(item)
        }
        
        // Check for complex plist sources validation
        if let plistSources = request.plistSources {
            for source in plistSources where item.paths.contains(source.path) {
                return validateComplexPlistItem(item, source: source)
            }
        }
        
        // Fallback to file existence validation
        return validateFileExistence(item)
    }
    
    /// Get actual plist value for display purposes
    func getPlistValue(at path: String, key: String) -> String? {
        let expandedPath = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath),
              let data = FileManager.default.contents(atPath: expandedPath),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        
        // Support nested keys with dot notation
        let keyParts = key.components(separatedBy: ".")
        var current: Any = plist
        
        for keyPart in keyParts {
            if let dict = current as? [String: Any] {
                current = dict[keyPart] ?? NSNull()
            } else if let array = current as? [Any], let index = Int(keyPart), index < array.count {
                current = array[index]
            } else {
                return nil // Key doesn't exist
            }
            
            if current is NSNull {
                return nil // Key doesn't exist
            }
        }
        
        // Convert value to string for display
        return formatValueForDisplay(current)
    }
    
    // MARK: - Private Validation Methods
    
    private func validateFileExistence(_ item: InspectConfig.ItemConfig) -> ValidationResult {
        // Debug logging to understand what's happening
        writeLog("ValidationService: Checking file existence for '\(item.id)'", logLevel: .debug)
        
        var foundPath: String?
        let exists = item.paths.first { path in
            let expandedPath = (path as NSString).expandingTildeInPath
            let fileExists = FileManager.default.fileExists(atPath: expandedPath)
            writeLog("ValidationService: Path '\(path)' expanded to '\(expandedPath)' exists: \(fileExists)", logLevel: .debug)
            if fileExists {
                foundPath = expandedPath
            }
            return fileExists
        } != nil
        
        writeLog("ValidationService: File existence result for '\(item.id)': \(exists)", logLevel: .debug)
        
        return ValidationResult(
            itemId: item.id,
            isValid: exists,
            validationType: .fileExistence,
            details: foundPath != nil ? ValidationDetails(
                path: foundPath!,
                key: nil,
                expectedValue: "File exists",
                actualValue: exists ? "Found" : "Not found",
                evaluationType: "file_existence"
            ) : nil
        )
    }
    
    // MARK: - Cache Management

    private func preCachePlists(from items: [InspectConfig.ItemConfig],
                                and sources: [InspectConfig.PlistSourceConfig]?) {
        var uniquePaths = Set<String>()

        // Collect all unique plist paths
        for item in items {
            for path in item.paths {
                let expandedPath = (path as NSString).expandingTildeInPath
                if expandedPath.hasSuffix(".plist") {
                    uniquePaths.insert(expandedPath)
                }
            }
        }

        // Add paths from plist sources
        if let sources = sources {
            for source in sources {
                let expandedPath = (source.path as NSString).expandingTildeInPath
                uniquePaths.insert(expandedPath)
            }
        }

        // Load all plists into cache
        for path in uniquePaths {
            _ = loadPlistCached(at: path)
        }

        writeLog("ValidationService: Pre-cached \(uniquePaths.count) plist files", logLevel: .debug)
    }

    private func loadPlistCached(at path: String) -> [String: Any]? {
        let expandedPath = (path as NSString).expandingTildeInPath

        // Check cache first
        return cacheQueue.sync {
            if let cached = plistCache[expandedPath] {
                // Check if file has been modified
                if let attributes = try? FileManager.default.attributesOfItem(atPath: expandedPath),
                   let modifiedDate = attributes[.modificationDate] as? Date,
                   let fileSize = attributes[.size] as? NSNumber {

                    if cached.lastModified == modifiedDate && cached.fileSize == fileSize.int64Value {
                        return cached.data // Cache is still valid
                    }
                }
            }

            // Load from disk
            guard let data = FileManager.default.contents(atPath: expandedPath),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  let attributes = try? FileManager.default.attributesOfItem(atPath: expandedPath),
                  let modifiedDate = attributes[.modificationDate] as? Date,
                  let fileSize = attributes[.size] as? NSNumber else {
                return nil
            }

            // Update cache
            let cached = CachedPlist(data: plist, lastModified: modifiedDate, fileSize: fileSize.int64Value)

            cacheQueue.async(flags: .barrier) {
                self.plistCache[expandedPath] = cached
            }

            return plist
        }
    }

    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.plistCache.removeAll()
        }
        writeLog("ValidationService: Cache cleared", logLevel: .debug)
    }

    func invalidateCacheForPath(_ path: String) {
        let expandedPath = (path as NSString).expandingTildeInPath
        cacheQueue.async(flags: .barrier) {
            self.plistCache.removeValue(forKey: expandedPath)
        }
    }

    // MARK: - Cached Validation Methods

    private func validateSimplePlistItemCached(_ item: InspectConfig.ItemConfig) -> ValidationResult {
        guard let plistKey = item.plistKey else {
            return ValidationResult(itemId: item.id, isValid: false, validationType: .plistValidation, details: nil)
        }

        for path in item.paths {
            if let plist = loadPlistCached(at: path) {
                let result = validatePlistValue(plist: plist, key: plistKey,
                                               expectedValue: item.expectedValue,
                                               evaluation: item.evaluation)
                if result {
                    let actualValue = extractPlistValue(from: plist, key: plistKey)
                    return ValidationResult(
                        itemId: item.id,
                        isValid: true,
                        validationType: .plistValidation,
                        details: ValidationDetails(
                            path: path,
                            key: plistKey,
                            expectedValue: item.expectedValue,
                            actualValue: formatValueForDisplay(actualValue),
                            evaluationType: item.evaluation
                        )
                    )
                }
            }
        }

        return ValidationResult(
            itemId: item.id,
            isValid: false,
            validationType: .plistValidation,
            details: nil
        )
    }

    private func validateComplexPlistItemCached(_ item: InspectConfig.ItemConfig, source: InspectConfig.PlistSourceConfig) -> ValidationResult {
        guard let plist = loadPlistCached(at: source.path) else {
            return ValidationResult(itemId: item.id, isValid: false, validationType: .complexPlistValidation, details: nil)
        }

        // General validation using critical keys
        if let criticalKeys = source.criticalKeys {
            for key in criticalKeys where !checkNestedKey(key, in: plist, expectedValues: source.successValues) {
                return ValidationResult(itemId: item.id, isValid: false, validationType: .complexPlistValidation, details: nil)
            }
        }

        return ValidationResult(itemId: item.id, isValid: true, validationType: .complexPlistValidation, details: nil)
    }

    private func validatePlistValue(plist: [String: Any], key: String, expectedValue: String?, evaluation: String?) -> Bool {
        // Navigate nested keys
        let keyParts = key.components(separatedBy: ".")
        var current: Any = plist

        for keyPart in keyParts {
            if let dict = current as? [String: Any] {
                guard let next = dict[keyPart] else { return false }
                current = next
            } else if let array = current as? [Any], let index = Int(keyPart), index < array.count {
                current = array[index]
            } else {
                return false
            }
        }

        return performSmartEvaluation(
            value: current,
            evaluationType: evaluation ?? "equals",
            expectedValue: expectedValue,
            key: key
        )
    }

    private func extractPlistValue(from plist: [String: Any], key: String) -> Any {
        let keyParts = key.components(separatedBy: ".")
        var current: Any = plist

        for keyPart in keyParts {
            if let dict = current as? [String: Any] {
                current = dict[keyPart] ?? NSNull()
            } else if let array = current as? [Any], let index = Int(keyPart), index < array.count {
                current = array[index]
            } else {
                return NSNull()
            }
        }

        return current
    }

    private func validateSimplePlistItem(_ item: InspectConfig.ItemConfig) -> ValidationResult {
        guard let plistKey = item.plistKey else {
            return ValidationResult(itemId: item.id, isValid: false, validationType: .plistValidation, details: nil)
        }
        
        for path in item.paths {
            let expandedPath = (path as NSString).expandingTildeInPath
            if let result = checkSimplePlistKey(at: path, key: plistKey, expectedValue: item.expectedValue, evaluation: item.evaluation) {
                let actualValue = getPlistValue(at: path, key: plistKey)
                let details = ValidationDetails(
                    path: expandedPath,
                    key: plistKey,
                    expectedValue: item.expectedValue,
                    actualValue: actualValue,
                    evaluationType: item.evaluation
                )
                
                return ValidationResult(
                    itemId: item.id,
                    isValid: result,
                    validationType: .plistValidation,
                    details: details
                )
            }
        }
        
        // If we reach here, file doesn't exist or key not found - this is a failure
        return ValidationResult(
            itemId: item.id,
            isValid: false,
            validationType: .plistValidation,
            details: ValidationDetails(
                path: item.paths.first ?? "",
                key: plistKey,
                expectedValue: item.expectedValue,
                actualValue: nil,
                evaluationType: item.evaluation
            )
        )
    }
    
    private func validateComplexPlistItem(_ item: InspectConfig.ItemConfig, source: InspectConfig.PlistSourceConfig) -> ValidationResult {
        let expandedPath = (source.path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath),
              let data = FileManager.default.contents(atPath: expandedPath),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return ValidationResult(itemId: item.id, isValid: false, validationType: .complexPlistValidation, details: nil)
        }
        
        // General validation using critical keys
        if let criticalKeys = source.criticalKeys {
            for key in criticalKeys where !checkNestedKey(key, in: plist, expectedValues: source.successValues) {
                return ValidationResult(itemId: item.id, isValid: false, validationType: .complexPlistValidation, details: nil)
            }
        }
        
        return ValidationResult(itemId: item.id, isValid: true, validationType: .complexPlistValidation, details: nil)
    }
    
    // MARK: - Smart Evaluation System
    
    private func checkSimplePlistKey(at path: String, key: String, expectedValue: String?, evaluation: String? = nil) -> Bool? {
        let expandedPath = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath),
              let data = FileManager.default.contents(atPath: expandedPath),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil // File doesn't exist or can't be read
        }
        
        // Support nested keys with dot notation (e.g., "Sets.0.ProxyAutoConfigURLString")
        let keyParts = key.components(separatedBy: ".")
        var current: Any = plist
        
        for keyPart in keyParts {
            if let dict = current as? [String: Any] {
                current = dict[keyPart] ?? NSNull()
            } else if let array = current as? [Any], let index = Int(keyPart), index < array.count {
                current = array[index]
            } else {
                writeLog("ValidationService: Key part '\(keyPart)' not found in path '\(key)'", logLevel: .info)
                return false // Key doesn't exist
            }
            
            if current is NSNull {
                writeLog("ValidationService: Key '\(key)' is NSNull", logLevel: .info)
                return false // Key doesn't exist
            }
        }
        
        // Smart evaluation system
        let evaluationType = evaluation ?? "equals" // Default to equals for backward compatibility
        
        return performSmartEvaluation(
            value: current,
            evaluationType: evaluationType,
            expectedValue: expectedValue,
            key: key
        )
    }
    
    private func performSmartEvaluation(value: Any, evaluationType: String, expectedValue: String?, key: String) -> Bool {
        switch evaluationType.lowercased() {
        case "exists":
            // Just check if key exists (ignore expectedValue)
            let result = !(value is NSNull)
            writeLog("ValidationService: Key '\(key)', Evaluation 'exists', Result: \(result)", logLevel: .info)
            return result
            
        case "boolean":
            // Smart boolean evaluation: 1, true, YES = true; 0, false, NO = false
            guard let expectedValue = expectedValue else {
                writeLog("ValidationService: Key '\(key)', Evaluation 'boolean' requires expectedValue", logLevel: .error)
                return false
            }
            
            let expectedBool = parseSmartBoolean(expectedValue)
            let actualBool = parseSmartBoolean(value)
            let result = actualBool == expectedBool
            writeLog("ValidationService: Key '\(key)', Expected bool '\(expectedBool)', Actual bool '\(actualBool)', Result: \(result)", logLevel: .info)
            return result
            
        case "contains":
            // For arrays, check if contains the expectedValue
            guard let expectedValue = expectedValue else {
                writeLog("ValidationService: Key '\(key)', Evaluation 'contains' requires expectedValue", logLevel: .error)
                return false
            }
            
            if let arrayValue = value as? [Any] {
                let result = arrayValue.contains { item in
                    if let stringItem = item as? String {
                        return stringItem == expectedValue
                    }
                    return String(describing: item) == expectedValue
                }
                writeLog("ValidationService: Key '\(key)', Array contains '\(expectedValue)', Result: \(result)", logLevel: .info)
                return result
            } else {
                writeLog("ValidationService: Key '\(key)', Evaluation 'contains' requires array value", logLevel: .error)
                return false
            }
            
        case "range":
            // For numbers, expectedValue like "1-100" checks range
            guard let expectedValue = expectedValue, expectedValue.contains("-") else {
                writeLog("ValidationService: Key '\(key)', Evaluation 'range' requires format 'min-max'", logLevel: .error)
                return false
            }
            
            let rangeParts = expectedValue.components(separatedBy: "-")
            guard rangeParts.count == 2,
                  let minValue = Double(rangeParts[0]),
                  let maxValue = Double(rangeParts[1]) else {
                writeLog("ValidationService: Key '\(key)', Invalid range format '\(expectedValue)'", logLevel: .error)
                return false
            }
            
            let actualNumber: Double
            if let intVal = value as? Int {
                actualNumber = Double(intVal)
            } else if let doubleVal = value as? Double {
                actualNumber = doubleVal
            } else {
                writeLog("ValidationService: Key '\(key)', Evaluation 'range' requires numeric value", logLevel: .error)
                return false
            }
            
            let result = actualNumber >= minValue && actualNumber <= maxValue
            writeLog("ValidationService: Key '\(key)', Value \(actualNumber) in range \(minValue)-\(maxValue), Result: \(result)", logLevel: .info)
            return result
            
        default: // "equals" and any other unknown types
            // Default: exact string comparison (backward compatible)
            guard let expectedValue = expectedValue else {
                writeLog("ValidationService: Key '\(key)', Evaluation 'equals' requires expectedValue", logLevel: .error)
                return false
            }
            
            let result: Bool
            if let stringValue = value as? String {
                result = stringValue == expectedValue
            } else if let boolValue = value as? Bool {
                result = String(boolValue) == expectedValue
            } else if let intValue = value as? Int {
                result = String(intValue) == expectedValue
            } else if let doubleValue = value as? Double {
                result = String(doubleValue) == expectedValue
            } else {
                result = String(describing: value) == expectedValue
            }
            
            writeLog("ValidationService: Key '\(key)', Expected '\(expectedValue)', Actual '\(String(describing: value))', Result: \(result)", logLevel: .info)
            return result
        }
    }
    
    // MARK: - Helper Methods
    
    private func parseSmartBoolean(_ value: Any) -> Bool {
        if let boolValue = value as? Bool {
            return boolValue
        } else if let stringValue = value as? String {
            let lower = stringValue.lowercased()
            return lower == "true" || lower == "yes" || lower == "1"
        } else if let intValue = value as? Int {
            return intValue == 1
        } else if let doubleValue = value as? Double {
            return doubleValue == 1.0
        }
        return false
    }
    
    private func formatValueForDisplay(_ value: Any) -> String {
        if let stringValue = value as? String {
            return stringValue
        } else if let boolValue = value as? Bool {
            return String(boolValue)
        } else if let intValue = value as? Int {
            return String(intValue)
        } else if let doubleValue = value as? Double {
            return String(doubleValue)
        } else if let arrayValue = value as? [Any] {
            return "[\(arrayValue.count) items]"
        } else if let dictValue = value as? [String: Any] {
            return "{\(dictValue.keys.count) keys}"
        }
        
        return String(describing: value)
    }
    
    private func checkNestedKey(_ keyPath: String, in dict: [String: Any], expectedValues: [String]?) -> Bool {
        let components = keyPath.split(separator: ".")
        var current: Any = dict
        
        for component in components {
            if component == "*" {
                // Handle wildcard - would need more complex logic
                return true
            }
            
            guard let currentDict = current as? [String: Any],
                  let nextValue = currentDict[String(component)] else {
                return false
            }
            current = nextValue
        }
        
        // Check if value matches expected
        if let expectedValues = expectedValues {
            if let stringValue = current as? String {
                return expectedValues.contains(stringValue)
            } else if let intValue = current as? Int {
                return expectedValues.contains(String(intValue))
            }
        }
        
        return true
    }
}
