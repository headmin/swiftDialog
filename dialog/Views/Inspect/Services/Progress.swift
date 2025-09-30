//
//  Progress.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 21/09/2025
//
//  Progress tracking service for Inspect mode
//  Handles progress calculation, status management, and preset-specific progress data
//

import Foundation

// MARK: - Progress Models

struct ItemProgress {
    let itemId: String
    let status: InspectItemStatus
    let timestamp: Date
}

struct OverallProgress {
    let totalItems: Int
    let completedItems: Int
    let downloadingItems: Int
    let pendingItems: Int
    let progressPercentage: Double

    var isComplete: Bool {
        return completedItems == totalItems && totalItems > 0
    }
}

// MARK: - Progress Service

class Progress: ObservableObject {

    // MARK: Published Properties

    @Published var overallProgress = OverallProgress(
        totalItems: 0,
        completedItems: 0,
        downloadingItems: 0,
        pendingItems: 0,
        progressPercentage: 0.0
    )

    @Published var itemStatuses: [String: InspectItemStatus] = [:]

    // MARK: Private Properties

    private var items: [InspectConfig.ItemConfig] = []
    private var statusHistory: [ItemProgress] = []

    // Preset-specific data
    private var presetData: [String: Any] = [:]

    // MARK: - Initialization

    init(preset: String? = nil, items: [InspectConfig.ItemConfig] = []) {
        self.items = items

        // Initialize item statuses
        for item in items {
            itemStatuses[item.id] = .pending
        }

        updateOverallProgress()
        writeLog("ProgressService: Initialized with \(items.count) items", logLevel: .debug)
    }

    // MARK: - Public API

    func configureItems(_ items: [InspectConfig.ItemConfig]) {
        self.items = items
        itemStatuses.removeAll()

        // Initialize all items as pending
        for item in items {
            itemStatuses[item.id] = .pending
        }

        updateOverallProgress()
        writeLog("ProgressService: Configured with \(items.count) items", logLevel: .info)
    }

    func updateItemStatus(_ itemId: String, status: InspectItemStatus) {
        // Auto-add item if not known (for backwards compatibility)
        if itemStatuses[itemId] == nil {
            itemStatuses[itemId] = status
            writeLog("ProgressService: Auto-added item ID: \(itemId)", logLevel: .debug)
        }

        // Record status change
        let progress = ItemProgress(
            itemId: itemId,
            status: status,
            timestamp: Date()
        )
        statusHistory.append(progress)

        // Update current status
        itemStatuses[itemId] = status

        // Progress tracking removed - no longer needed

        // Update overall progress
        updateOverallProgress()

        // Log significant changes
        switch status {
        case .completed:
            writeLog("ProgressService: Item '\(itemId)' completed", logLevel: .info)
        case .failed(let error):
            writeLog("ProgressService: Item '\(itemId)' failed: \(error)", logLevel: .error)
        default:
            break
        }
    }

    func setItemCompleted(_ itemId: String) {
        updateItemStatus(itemId, status: .completed)
    }

    func setItemDownloading(_ itemId: String) {
        updateItemStatus(itemId, status: .downloading)
    }

    func setItemPending(_ itemId: String) {
        updateItemStatus(itemId, status: .pending)
    }

    func setItemFailed(_ itemId: String, error: String) {
        updateItemStatus(itemId, status: .failed(error))
    }

    func resetAllItems() {
        for itemId in itemStatuses.keys {
            itemStatuses[itemId] = .pending
        }
        statusHistory.removeAll()
        updateOverallProgress()
        writeLog("ProgressService: Reset all items to pending", logLevel: .info)
    }

    // MARK: - Progress Calculation

    private func updateOverallProgress() {
        let completed = itemStatuses.values.filter { status in
            if case .completed = status { return true }
            return false
        }.count

        let downloading = itemStatuses.values.filter { status in
            if case .downloading = status { return true }
            return false
        }.count

        let pending = itemStatuses.values.filter { status in
            if case .pending = status { return true }
            return false
        }.count

        let total = itemStatuses.count
        let percentage = total > 0 ? Double(completed) / Double(total) : 0.0

        overallProgress = OverallProgress(
            totalItems: total,
            completedItems: completed,
            downloadingItems: downloading,
            pendingItems: pending,
            progressPercentage: percentage
        )

        // Progress tracker doesn't have updateOverallProgress method
        // It tracks individual items instead
    }

    // MARK: - Status Queries

    func isItemCompleted(_ itemId: String) -> Bool {
        if case .completed = itemStatuses[itemId] {
            return true
        }
        return false
    }

    func isItemDownloading(_ itemId: String) -> Bool {
        if case .downloading = itemStatuses[itemId] {
            return true
        }
        return false
    }

    func isItemPending(_ itemId: String) -> Bool {
        if case .pending = itemStatuses[itemId] {
            return true
        }
        return false
    }

    func getItemStatus(_ itemId: String) -> InspectItemStatus? {
        return itemStatuses[itemId]
    }

    func getCompletedItems() -> Set<String> {
        return Set(itemStatuses.compactMap { key, value in
            if case .completed = value { return key }
            return nil
        })
    }

    func getDownloadingItems() -> Set<String> {
        return Set(itemStatuses.compactMap { key, value in
            if case .downloading = value { return key }
            return nil
        })
    }

    // MARK: - Preset-Specific Data

    func updatePresetData(_ key: String, value: Any) {
        presetData[key] = value
        writeLog("ProgressService: Updated preset data '\(key)'", logLevel: .debug)
    }

    func getPresetData(_ key: String) -> Any? {
        return presetData[key]
    }

    // For Preset6 image rotation
    func updatePreset6Images(images: [String], currentIndex: Int, rotationEnabled: Bool) {
        // Progress tracking removed - no longer needed
    }

    // For Preset1 spinner
    func updatePreset1Spinner(active: Bool) {
        _ = Array(getDownloadingItems())
        // Progress tracking removed - no longer needed
    }

    // MARK: - History & Analytics

    func getStatusHistory(for itemId: String? = nil) -> [ItemProgress] {
        if let itemId = itemId {
            return statusHistory.filter { $0.itemId == itemId }
        }
        return statusHistory
    }

    func getAverageCompletionTime() -> TimeInterval? {
        var completionTimes: [TimeInterval] = []

        for itemId in itemStatuses.keys {
            let history = getStatusHistory(for: itemId)

            // Find download start time
            let downloadStart = history.first { progress in
                if case .downloading = progress.status { return true }
                return false
            }

            // Find completion time
            let completion = history.first { progress in
                if case .completed = progress.status { return true }
                return false
            }

            if let start = downloadStart?.timestamp,
               let end = completion?.timestamp {
                completionTimes.append(end.timeIntervalSince(start))
            }
        }

        guard !completionTimes.isEmpty else { return nil }
        return completionTimes.reduce(0, +) / Double(completionTimes.count)
    }

    // MARK: - Helper Methods

    private func statusString(for status: InspectItemStatus) -> String {
        switch status {
        case .pending:
            return "pending"
        case .downloading:
            return "downloading"
        case .completed:
            return "complete"
        case .failed:
            return "failed"
        }
    }

    deinit {
        // Progress tracking removed - no longer needed
        writeLog("ProgressService: Deinitialized", logLevel: .debug)
    }
}
