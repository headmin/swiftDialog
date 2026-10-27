//
//  DoorTests.swift
//
//  Footer doors and the shared rules behind them: `BackDoor.label`'s precedence, host lines,
//  language keys, deferral, cadence windows, footer air, detection logging and the removal notice.
//

import XCTest
import SwiftUI
import Synchronization
@testable import Dialog

final class BackDoorLabelTests: XCTestCase {

    /// The first non-empty source wins: localized, step, branding, fallback.
    func testPrecedenceIsLocalizedThenStepThenBrandingThenFallback() {
        XCTAssertEqual(BackDoor.label(localized: "Zurück", step: "Go back", branding: "Previous"), "Zurück")
        XCTAssertEqual(BackDoor.label(localized: nil, step: "Go back", branding: "Previous"), "Go back")
        XCTAssertEqual(BackDoor.label(localized: nil, step: nil, branding: "Previous"), "Previous")
        XCTAssertEqual(BackDoor.label(localized: nil, step: nil, branding: nil), "Back")
    }

    /// A language pack beats a global button label.
    func testALanguagePackBeatsAGlobalButtonLabel() {
        XCTAssertEqual(BackDoor.label(localized: "Zurück", step: nil, branding: "Previous"), "Zurück")
    }

    /// `steps[].backButtonText` is honoured on every preset, Preset 6 included.
    func testTheAuthoredPerStepKeyIsHonoured() {
        XCTAssertEqual(BackDoor.label(localized: nil, step: "Do this later", branding: "Previous"), "Do this later")
    }

    /// The two values the in-repo configs author.
    func testTheTwoCorpusAuthoredValues() {
        XCTAssertEqual(BackDoor.label(localized: nil, step: "Do this later", branding: nil), "Do this later")
        XCTAssertEqual(BackDoor.label(localized: nil, step: "Back", branding: nil), "Back")
    }

    /// An empty string falls through to the next rung; a back door needs a word for VoiceOver.
    func testEmptyStringsFallThrough() {
        XCTAssertEqual(BackDoor.label(localized: "", step: "Go back", branding: nil), "Go back")
        XCTAssertEqual(BackDoor.label(localized: "", step: "", branding: ""), "Back")
    }

    /// The fallback word is overridable; the chain always returns a String.
    func testFallbackIsOverridable() {
        XCTAssertEqual(BackDoor.label(localized: nil, step: nil, branding: nil, fallback: "Cancel"), "Cancel")
    }
}

// MARK: - Removal on the provisioning design

/// A removed item arrives as `.pending`, so it needs its own word ("Removed") rather than "Queued".
final class ProvisioningRemovedWordTests: XCTestCase {

    private struct Item: MonitoredItem {
        let id: String
        let displayName: String
        var icon: String? { nil }
        var paths: [String] { [] }
        var plistKey: String? { nil }
        var expectedValue: String? { nil }
        var evaluation: String? { nil }
        var plistRecheckInterval: Int? { nil }
        var useUserDefaults: Bool? { nil }
        var jsonMonitors: [InspectConfig.JsonMonitor]? { nil }
        var requirements: [InspectConfig.ItemConfig.Requirement]? { nil }
        var satisfy: String? { nil }
        var showBundleInfo: String? { nil }
        var logAliases: [String]? { nil }
    }

    /// A removed row says so on the provisioning design.
    func testARemovedItemSaysRemovedNotQueued() {
        let rows = ProvisioningRowBuilder.itemRows(
            items: [Item(id: "obsidian", displayName: "Obsidian")],
            statuses: [.pending],
            removedIds: ["obsidian"],
            vocabulary: .packages)
        guard case .notice(let word) = rows[0].trailing else {
            return XCTFail("expected a notice trailing, got \(rows[0].trailing)")
        }
        XCTAssertEqual(word, "Removed")
    }

    /// A removed row gets the notice trailing (a chip), not an ordinary state trailing.
    func testARemovedItemGetsTheNoticeTrailingNotAnOrdinaryState() {
        let rows = ProvisioningRowBuilder.itemRows(
            items: [Item(id: "obsidian", displayName: "Obsidian")],
            statuses: [.pending], removedIds: ["obsidian"], vocabulary: .packages)
        XCTAssertEqual(rows[0].trailing, .notice("Removed"))
    }

    /// A queued row keeps its ordinary state trailing.
    func testAQueuedRowKeepsItsOrdinaryStateTrailing() {
        let rows = ProvisioningRowBuilder.itemRows(
            items: [Item(id: "figma", displayName: "Figma")],
            statuses: [.pending], removedIds: [], vocabulary: .packages)
        XCTAssertEqual(rows[0].trailing, .state("Queued", failed: false),
                       "the chip belongs to the removal alone — a queued row is not a notice")
    }

    /// An installed item with a stale removal id gets no chip.
    func testAnInstalledItemGetsNoChip() {
        let rows = ProvisioningRowBuilder.itemRows(
            items: [Item(id: "obsidian", displayName: "Obsidian")],
            statuses: [.completed], removedIds: ["obsidian"], vocabulary: .packages)
        XCTAssertEqual(rows[0].trailing, .state("Installed", failed: false))
    }

    /// A pending item nobody removed is still queued.
    func testAPendingItemIsStillQueued() {
        let rows = ProvisioningRowBuilder.itemRows(
            items: [Item(id: "figma", displayName: "Figma")],
            statuses: [.pending], removedIds: [], vocabulary: .packages)
        guard case .state(let word, _) = rows[0].trailing else {
            return XCTFail("expected a state trailing")
        }
        XCTAssertEqual(word, "Queued")
    }

    /// The mark stays `.queued`; only the word differs.
    func testTheMarkStaysQueued() {
        let rows = ProvisioningRowBuilder.itemRows(
            items: [Item(id: "obsidian", displayName: "Obsidian")],
            statuses: [.pending], removedIds: ["obsidian"], vocabulary: .packages)
        XCTAssertEqual(rows[0].mark, .queued)
    }

    /// An installed item ignores a stale removal.
    func testAnInstalledItemIgnoresAStaleRemoval() {
        let rows = ProvisioningRowBuilder.itemRows(
            items: [Item(id: "obsidian", displayName: "Obsidian")],
            statuses: [.completed], removedIds: ["obsidian"], vocabulary: .packages)
        guard case .state(let word, _) = rows[0].trailing else {
            return XCTFail("expected a state trailing")
        }
        XCTAssertEqual(word, "Installed")
    }

    /// Both vocabularies say "Removed".
    func testBothVocabulariesCarryTheWord() {
        XCTAssertEqual(ProvisioningVocabulary.packages.removed, "Removed")
        XCTAssertEqual(ProvisioningVocabulary.checks.removed, "Removed")
    }
}

// MARK: - Removal wire

/// Preset 5 rows read `monitoringService.removedItems` (InspectState's list is config-level and
/// empty for a step flow). Driven through the filesystem against the real service.
@MainActor
final class MonitoringServiceRemovalTests: XCTestCase {

    private var tempDir: URL!
    private var service: UnifiedMonitoringService!

    private struct Item: MonitoredItem {
        let id: String
        let displayName: String
        let itemPaths: [String]
        var icon: String? { nil }
        var paths: [String] { itemPaths }
        var plistKey: String? { nil }
        var expectedValue: String? { nil }
        var evaluation: String? { nil }
        var plistRecheckInterval: Int? { nil }
        var useUserDefaults: Bool? { nil }
        var jsonMonitors: [InspectConfig.JsonMonitor]? { nil }
        var requirements: [InspectConfig.ItemConfig.Requirement]? { nil }
        var satisfy: String? { nil }
        var showBundleInfo: String? { nil }
        var logAliases: [String]? { nil }
    }

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("monitoring-removal-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        service = UnifiedMonitoringService()
    }

    override func tearDownWithError() throws {
        service.stopMonitoring()
        // Reset the shared log monitor's manifest so later tests do not match against this fixture.
        LogMonitorService.shared.setItems([])
        try? FileManager.default.removeItem(at: tempDir)
    }

    /// Runs after the service's `DispatchQueue.main.async` publish on the same serial queue.
    private func drainMain() {
        let exp = expectation(description: "main queue drained")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 2)
    }

    private func install(_ name: String) throws -> String {
        let url = tempDir.appendingPathComponent(name)
        try Data("installed".utf8).write(to: url)
        return url.path
    }

    /// Install, then delete: the service records when. Only a file on disk changes between the checks.
    func testDeletingAnInstalledItemRecordsARemovalNotice() throws {
        let path = try install("Obsidian.app")
        let item = Item(id: "obsidian", displayName: "Obsidian", itemPaths: [path])

        service.startMonitoring(items: [item])
        drainMain()
        XCTAssertEqual(service.itemStatuses["obsidian"], .completed, "the fixture must start installed")
        XCTAssertTrue(service.removedItems.isEmpty, "nothing has been removed yet")

        try FileManager.default.removeItem(atPath: path)
        service.forceStatusCheck()
        drainMain()

        XCTAssertEqual(service.itemStatuses["obsidian"], .pending,
                       "the STATE is pending — a removed app genuinely is not installed")
        XCTAssertNotNil(service.removedItems["obsidian"],
                        "and the service records WHEN, which is the whole fix: without it the row " +
                        "can only ever say 'Queued'")
    }

    /// The recorded removal reaches the row as a notice, through the set `provisioningCarouselStepView` passes.
    func testTheRecordedRemovalReachesTheRowAsANotice() throws {
        let path = try install("Obsidian.app")
        let item = Item(id: "obsidian", displayName: "Obsidian", itemPaths: [path])

        service.startMonitoring(items: [item])
        drainMain()
        try FileManager.default.removeItem(atPath: path)
        service.forceStatusCheck()
        drainMain()

        let statuses = [service.itemStatuses["obsidian"] ?? .pending]
        let rows = ProvisioningRowBuilder.itemRows(
            items: [item], statuses: statuses,
            removedIds: Set(service.removedItems.keys),
            vocabulary: .packages)
        XCTAssertEqual(rows[0].trailing, .notice("Removed"))
        XCTAssertEqual(rows[0].mark, .queued, "a removed row keeps the queued glyph; the notice alone says what happened")
    }

    /// An app that stays installed is never recorded.
    func testAnItemThatStaysInstalledIsNeverRecorded() throws {
        let path = try install("Figma.app")
        service.startMonitoring(items: [Item(id: "figma", displayName: "Figma", itemPaths: [path])])
        drainMain()
        service.forceStatusCheck()
        drainMain()

        XCTAssertEqual(service.itemStatuses["figma"], .completed)
        XCTAssertTrue(service.removedItems.isEmpty)
    }

    /// Past the dwell the notice goes and the row reads queued again; the notice came from a real deletion.
    func testThePruneSettlesTheNoticePastTheDwell() throws {
        let path = try install("Obsidian.app")
        service.startMonitoring(items: [Item(id: "obsidian", displayName: "Obsidian", itemPaths: [path])])
        drainMain()
        try FileManager.default.removeItem(atPath: path)
        service.forceStatusCheck()
        drainMain()
        XCTAssertNotNil(service.removedItems["obsidian"])

        service.pruneRemovalNotices(now: Date().addingTimeInterval(AppInspector.removalNoticeDwell + 1))
        drainMain()

        XCTAssertTrue(service.removedItems.isEmpty,
                      "the notice expires on this service's own tick, at the ONE dwell constant")
    }

    /// A fresh notice survives a prune; the prune reads `AppInspector.removalNoticeDwell`.
    func testAFreshNoticeSurvivesAPrune() throws {
        let path = try install("Obsidian.app")
        service.startMonitoring(items: [Item(id: "obsidian", displayName: "Obsidian", itemPaths: [path])])
        drainMain()
        try FileManager.default.removeItem(atPath: path)
        service.forceStatusCheck()
        drainMain()

        service.pruneRemovalNotices(now: Date().addingTimeInterval(AppInspector.removalNoticeDwell - 5))
        drainMain()

        XCTAssertNotNil(service.removedItems["obsidian"], "a notice inside the dwell is still news")
    }

    /// A reinstall clears the notice at once.
    func testAnItemThatComesBackClearsItsNotice() throws {
        let path = try install("Obsidian.app")
        service.startMonitoring(items: [Item(id: "obsidian", displayName: "Obsidian", itemPaths: [path])])
        drainMain()
        try FileManager.default.removeItem(atPath: path)
        service.forceStatusCheck()
        drainMain()
        XCTAssertNotNil(service.removedItems["obsidian"])

        _ = try install("Obsidian.app")
        service.forceStatusCheck()
        drainMain()

        XCTAssertEqual(service.itemStatuses["obsidian"], .completed)
        XCTAssertTrue(service.removedItems.isEmpty, "a row that has come back must stop saying it went")
    }
}
