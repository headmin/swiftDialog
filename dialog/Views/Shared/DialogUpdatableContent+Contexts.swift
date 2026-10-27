//
//  DialogUpdatableContent+Contexts.swift
//  dialog
//
//  Conforms the classic dialog observable to ContentContext / ProgressContext / UserInputContext so
//  shared components render in classic dialogs; input stores classic lacks live in a side table here.
//

import SwiftUI

// MARK: - Input-sink side table

/// Storage for the UserInputContext sink members. Extensions cannot add stored properties,
/// hence the per-instance side table; entries live for the process lifetime.
private final class ContextBridgeStore {
    var userValues: [String: String] = [:]
    var wallpaperSelection: [String: String] = [:]
    var dockSelection: [String: String] = [:]
    var guidanceFormInputs: [String: GuidanceFormInputState] = [:]
}

private var contextBridgeStores: [ObjectIdentifier: ContextBridgeStore] = [:]

private func bridgeStore(for object: DialogUpdatableContent) -> ContextBridgeStore {
    let key = ObjectIdentifier(object)
    if let store = contextBridgeStores[key] { return store }
    let store = ContextBridgeStore()
    contextBridgeStores[key] = store
    return store
}

// MARK: - ContentContext (read-only config surface)

extension DialogUpdatableContent: ContentContext {

    /// Classic dialogs have no InspectConfig; components fall back to their inputs and defaults.
    var config: InspectConfig? { nil }

    /// Classic list rows mapped to the shared item model, derived on access from
    /// userInputState.listItems. id = title, matching how listitem: commands address rows.
    var items: [InspectConfig.ItemConfig] {
        userInputState.listItems.enumerated().map { index, row in
            InspectConfig.ItemConfig(
                id: row.title,
                displayName: row.title,
                icon: row.icon.isEmpty ? nil : row.icon,
                guiIndex: index
            )
        }
    }

    /// Only fields with a classic counterpart are mapped. preset = "classic" marks bridged rendering.
    var uiConfiguration: UIConfiguration {
        var configuration = UIConfiguration()
        configuration.preset = "classic"
        configuration.windowTitle = args.titleOption.value
        if args.iconOption.present {
            configuration.iconPath = args.iconOption.value
        }
        configuration.iconSize = Int(iconSize)
        configuration.width = Int(appProperties.windowWidth)
        configuration.height = Int(appProperties.windowHeight)
        return configuration
    }

    var colorThresholds: InspectConfig.ColorThresholds { .default }
}

// MARK: - ProgressContext (live progress sets)

extension DialogUpdatableContent: ProgressContext {

    // Classic's listitem status vocabulary mapped onto the three sets; "pending" is membership in none.

    var completedItems: Set<String> {
        Set(userInputState.listItems.filter { $0.statusIcon == "success" }.map(\.title))
    }

    var downloadingItems: Set<String> {
        Set(userInputState.listItems.filter { ["wait", "progress"].contains($0.statusIcon) }.map(\.title))
    }

    var failedItems: Set<String> {
        Set(userInputState.listItems.filter { ["fail", "error"].contains($0.statusIcon) }.map(\.title))
    }
}

// MARK: - UserInputContext (input sink + interaction log)

extension DialogUpdatableContent: @MainActor UserInputContext {

    var userValues: [String: String] {
        get { bridgeStore(for: self).userValues }
        set {
            objectWillChange.send()
            bridgeStore(for: self).userValues = newValue
        }
    }

    var wallpaperSelection: [String: String] {
        get { bridgeStore(for: self).wallpaperSelection }
        set {
            objectWillChange.send()
            bridgeStore(for: self).wallpaperSelection = newValue
        }
    }

    var dockSelection: [String: String] {
        get { bridgeStore(for: self).dockSelection }
        set {
            objectWillChange.send()
            bridgeStore(for: self).dockSelection = newValue
        }
    }

    var guidanceFormInputs: [String: GuidanceFormInputState] {
        get { bridgeStore(for: self).guidanceFormInputs }
        set {
            objectWillChange.send()
            bridgeStore(for: self).guidanceFormInputs = newValue
        }
    }

    /// Bridged events go to the same interaction-log file inspect writes, so listeners see
    /// classic and inspect emissions identically.
    func writeToInteractionLog(_ message: String) {
        appendToInteractionLog(message)
        writeLog("INTERACTION: \(message)", logLevel: .info)
    }

    /// Seed empty form state so the guidance blocks' optional-chained writes land. Goes through
    /// the computed setter so objectWillChange fires.
    func initializeGuidanceFormState(for itemId: String) {
        if guidanceFormInputs[itemId] == nil {
            guidanceFormInputs[itemId] = GuidanceFormInputState()
        }
    }

    /// The same resolution core InspectState uses (FormInheritance.swift).
    @MainActor
    func resolveInheritValue(_ inheritSpec: String, basePath: String?) -> String? {
        resolveFormInheritValue(inheritSpec, basePath: basePath) { itemId, fieldId in
            guidanceFormInputs[itemId]?.textfields[fieldId]
        }
    }
}
