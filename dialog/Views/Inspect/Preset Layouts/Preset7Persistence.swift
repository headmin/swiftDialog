//
//  Preset7PersistenceService.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 21/09/2025
//
//  Safe persistence service for Preset7 state
//

import Foundation

struct Preset7StateData: Codable {
    let completedSteps: Set<String>
    let currentPage: Int
    let currentStep: Int
    let timestamp: Date
}

class Preset7Persistence {
    static let shared = Preset7Persistence()

    private let stateFileName = "preset7_state.plist"
    private let queue = DispatchQueue(label: "preset7.persistence", qos: .background)

    private var stateFileURL: URL? {
        // Strategy for persistence location:
        // 1. Check if DIALOG_PERSIST_PATH environment variable is set (for enterprise deployments)
        // 2. Try to create a .dialog subdirectory next to where dialog was called from
        // 3. Use ~/Library/Application Support/Dialog/ as fallback
        // 4. Last resort - use temp directory

        // Option 1: Environment variable override
        if let customPath = ProcessInfo.processInfo.environment["DIALOG_PERSIST_PATH"] {
            let url = URL(fileURLWithPath: customPath).appendingPathComponent(stateFileName)
            writeLog("Preset7Persistence: Using custom path from env: \(url.path)", logLevel: .debug)
            return url
        }

        // Option 2: Next to calling location (get from command line args or working directory)
        if let workingDir = ProcessInfo.processInfo.environment["PWD"] {
            let workingURL = URL(fileURLWithPath: workingDir)
            let dialogDir = workingURL.appendingPathComponent(".dialog", isDirectory: true)

            if ensureDirectoryExists(at: dialogDir) {
                let url = dialogDir.appendingPathComponent(stateFileName)
                writeLog("Preset7Persistence: Using working directory location: \(url.path)", logLevel: .debug)
                return url
            }
        }

        // Option 3: User's Application Support directory
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dialogDir = appSupport.appendingPathComponent("Dialog", isDirectory: true)

            if ensureDirectoryExists(at: dialogDir) {
                let url = dialogDir.appendingPathComponent(stateFileName)
                writeLog("Preset7Persistence: Using Application Support: \(url.path)", logLevel: .debug)
                return url
            }
        }

        // Option 4: Temp directory as last resort
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Dialog", isDirectory: true)
            .appendingPathComponent(stateFileName)
        writeLog("Preset7Persistence: Using temp directory: \(tempURL.path)", logLevel: .debug)
        return tempURL
    }

    private func ensureDirectoryExists(at url: URL) -> Bool {
        // Check if directory exists
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            return isDirectory.boolValue
        }

        // Try to create directory
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)

            // Verify we can write to it
            let testFile = url.appendingPathComponent(".write_test")
            if FileManager.default.createFile(atPath: testFile.path, contents: nil, attributes: nil) {
                try? FileManager.default.removeItem(at: testFile)
                return true
            }
        } catch {
            writeLog("Preset7Persistence: Cannot create directory at \(url.path): \(error)", logLevel: .info)
        }

        return false
    }

    // MARK: - Save State

    func saveState(completedSteps: Set<String>, currentPage: Int, currentStep: Int, itemCount: Int, totalPages: Int) {
        queue.async { [weak self] in
            guard let self = self,
                  let url = self.stateFileURL else {
                writeLog("Preset7PersistenceService: Cannot determine save location", logLevel: .error)
                return
            }

            // Validate data before saving
            let validPage = totalPages > 0 ? min(max(0, currentPage), totalPages - 1) : 0
            let validStep = itemCount > 0 ? min(max(0, currentStep), itemCount - 1) : 0

            let stateData = Preset7StateData(
                completedSteps: completedSteps,
                currentPage: validPage,
                currentStep: validStep,
                timestamp: Date()
            )

            do {
                let encoder = PropertyListEncoder()
                let data = try encoder.encode(stateData)
                try data.write(to: url, options: .atomic)
                writeLog("Preset7PersistenceService: State saved successfully to \(url.path)", logLevel: .debug)
            } catch {
                writeLog("Preset7PersistenceService: Failed to save state - \(error.localizedDescription)", logLevel: .error)
            }
        }
    }

    // MARK: - Load State

    func loadState() -> (completedSteps: Set<String>, currentPage: Int, currentStep: Int, timestamp: Date)? {
        guard let url = stateFileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            writeLog("Preset7PersistenceService: No persisted state found", logLevel: .debug)
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = PropertyListDecoder()
            let stateData = try decoder.decode(Preset7StateData.self, from: data)

            writeLog("Preset7PersistenceService: State loaded from \(stateData.timestamp)", logLevel: .info)

            return (
                completedSteps: stateData.completedSteps,
                currentPage: stateData.currentPage,
                currentStep: stateData.currentStep,
                timestamp: stateData.timestamp
            )
        } catch {
            writeLog("Preset7PersistenceService: Failed to load state - \(error.localizedDescription)", logLevel: .error)
            // Try to remove corrupt file
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    // MARK: - Clear State

    func clearState() {
        queue.async { [weak self] in
            guard let self = self,
                  let url = self.stateFileURL else { return }

            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                    writeLog("Preset7PersistenceService: State cleared", logLevel: .info)
                }
            } catch {
                writeLog("Preset7PersistenceService: Failed to clear state - \(error.localizedDescription)", logLevel: .error)
            }
        }
    }

    // MARK: - Validation

    func validateAndFixState(state: inout (completedSteps: Set<String>, currentPage: Int, currentStep: Int, timestamp: Date),
                            itemCount: Int, totalPages: Int) {
        // Ensure currentPage is within bounds
        if totalPages <= 0 {
            state.currentPage = 0
        } else if state.currentPage < 0 || state.currentPage >= totalPages {
            writeLog("Preset7PersistenceService: Fixing invalid currentPage \(state.currentPage) to 0", logLevel: .info)
            state.currentPage = 0
        }

        // Ensure currentStep is within bounds
        if itemCount <= 0 {
            state.currentStep = 0
        } else if state.currentStep < 0 || state.currentStep >= itemCount {
            writeLog("Preset7PersistenceService: Fixing invalid currentStep \(state.currentStep) to 0", logLevel: .info)
            state.currentStep = 0
        }

        // Check if state is too old (>24 hours) and consider clearing it
        let hoursSinceLastSave = Date().timeIntervalSince(state.timestamp) / 3600
        if hoursSinceLastSave > 24 {
            writeLog("Preset7PersistenceService: State is \(Int(hoursSinceLastSave)) hours old, considering it stale", logLevel: .info)
        }
    }
}
