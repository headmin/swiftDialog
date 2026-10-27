//
//  GuidanceBridgeView.swift
//  dialog
//
//  Renders inspect guidance blocks inside a classic dialog through the context-protocol bridge.
//  Active only when DIALOG_BRIDGE_GUIDANCE is set to inline JSON (a [GuidanceContent] array) or
//  the path of a JSON file; otherwise an EmptyView.
//

import SwiftUI

struct GuidanceBridgeView: View {

    @ObservedObject var observedData: DialogUpdatableContent

    /// Decoded once per process — the environment cannot change after launch.
    private static let contentBlocks: [InspectConfig.GuidanceContent] = loadBlocks()

    private static func loadBlocks() -> [InspectConfig.GuidanceContent] {
        guard let flagValue = ProcessInfo.processInfo.environment["DIALOG_BRIDGE_GUIDANCE"],
              !flagValue.isEmpty else {
            return []
        }

        let json: Data
        if flagValue.trimmingCharacters(in: .whitespaces).hasPrefix("[") {
            json = Data(flagValue.utf8)
        } else if let fileData = FileManager.default.contents(atPath: flagValue) {
            json = fileData
        } else {
            writeLog("GuidanceBridge: no readable JSON at \(flagValue)", logLevel: .error)
            return []
        }

        do {
            let blocks = try JSONDecoder().decode([InspectConfig.GuidanceContent].self, from: json)
            writeLog("GuidanceBridge: rendering \(blocks.count) guidance block(s) in classic dialog", logLevel: .info)
            return blocks
        } catch {
            writeLog("GuidanceBridge: failed to decode guidance JSON: \(error)", logLevel: .error)
            return []
        }
    }

    var body: some View {
        if !Self.contentBlocks.isEmpty {
            GuidanceContentView(
                contentBlocks: Self.contentBlocks,
                scaleFactor: 1.0,
                inspectState: observedData,
                itemId: "classic-bridge"
            )
            .padding(.bottom, appDefaults.contentPadding)
        }
    }
}
