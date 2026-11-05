//
//  UpstreamIssueFixTests.swift
//  dialogTests
//
//  Upstream issues the toast preset pins.
//

import XCTest
import SwiftUI
import AppKit
@testable import Dialog

// GitHub #699 / #712 / #713 / #565: a string sideMessage, the item-list order, the toast's item
// strip, and the card pager that must not stall on a failed item.
final class UpstreamIssueFixTests: XCTestCase {
    private func decode(_ json: String) throws -> InspectConfig {
        try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
    }

    func testASingleSideMessageStringLoads() throws {
        XCTAssertEqual(try decode(#"{"preset":"1","items":[],"sideMessage":"Hang tight"}"#).sideMessage, ["Hang tight"])
        XCTAssertEqual(try decode(#"{"preset":"1","items":[],"sideMessage":["a","b"]}"#).sideMessage, ["a", "b"])
    }

    func testItemSortOrderKey() throws {
        XCTAssertEqual(try decode(#"{"preset":"1","items":[],"itemSortOrder":"activeFirst"}"#).itemSortOrder, "activeFirst")
        XCTAssertEqual(PresetCommonViews.ItemOrder(itemSortOrder: nil), .completedFirst)
        XCTAssertEqual(PresetCommonViews.ItemOrder(itemSortOrder: "activeFirst"), .upNext)
        XCTAssertEqual(PresetCommonViews.ItemOrder(itemSortOrder: "guiIndex"), .guiIndex)
        XCTAssertEqual(PresetCommonViews.ItemOrder(itemSortOrder: "bogus"), .completedFirst)
        XCTAssertFalse(PresetCommonViews.ItemOrder.completedFirst.followsActive, "the default order does not start scrolling")
        XCTAssertTrue(PresetCommonViews.ItemOrder.upNext.followsActive)
    }

    func testToastItemStripModes() {
        XCTAssertEqual(ToastSummaryBar.itemStripMode(nil), .always)
        XCTAssertEqual(ToastSummaryBar.itemStripMode("never"), .never)
        XCTAssertEqual(ToastSummaryBar.itemStripMode("auto"), .auto)
    }

    func testARootWindowOptionSaysWhereItGoes() {
        XCTAssertTrue(InspectConfig.unknownRootKeyWarning("moveable").contains(#""options": {"moveable": true}"#))
        XCTAssertEqual(InspectConfig.unknownRootKeyWarning("tittle"), "Unknown key 'tittle' in root config")
    }

    func testThePagerMovesPastAFailedCard() {
        let ids = ["a", "b", "c", "d"]
        XCTAssertEqual(Preset2CardPager.followAnchor(ids: ids, downloading: [], completed: ["a"], failed: ["b"]), 2)
        XCTAssertEqual(Preset2CardPager.followAnchor(ids: ids, downloading: ["d"], completed: ["a"], failed: []), 3)
        XCTAssertEqual(Preset2CardPager.followAnchor(ids: ids, downloading: [], completed: ["a", "c", "d"], failed: ["b"]), 3)
    }

    /// All three token spellings 3.1.1 accepted fill in, on every preset's progress label (Preset 2
    /// used to replace only the `{…}` form).
    func testProgressFormatAcceptsEveryTokenSpelling() {
        for format in ["{completed} of {total}", "$completed of $total", "%completed% of %total%"] {
            XCTAssertEqual(PresetCommonViews.fillProgressTokens(format, completed: 2, total: 5), "2 of 5", format)
        }
    }
}

/// The 3.1.1 guide picker: decoded keys, selection rules and the plist shape scripts read.
final class GuidePickerTests: XCTestCase {

    private func config(mode: String, allowEmpty: Bool = false) throws -> InspectConfig {
        let json = """
        {"preset": "5", "pickerConfig": {"selectionMode": "\(mode)", "returnSelections": true,
                                         "allowContinueWithoutSelection": \(allowEmpty)},
         "introSteps": [{"id": "a", "stepType": "guide", "title": "Alpha", "selectable": true},
                        {"id": "b", "stepType": "guide", "title": "Beta", "selectable": true},
                        {"id": "c", "stepType": "guide"}]}
        """
        return try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
    }

    func testTheKeysDecode() throws {
        let c = try config(mode: "multi")
        XCTAssertTrue(GuidePicker.isActive(c.pickerConfig))
        XCTAssertEqual(c.pickerConfig?.returnSelections, true)
        XCTAssertEqual(c.introSteps?.map { $0.selectable }, [true, true, nil])
    }

    func testSingleIsExclusiveAndMultiToggles() {
        XCTAssertEqual(GuidePicker.toggled(["a"], id: "b", mode: "single"), ["b"])
        XCTAssertEqual(GuidePicker.toggled(["a"], id: "a", mode: "single"), [])
        XCTAssertEqual(GuidePicker.toggled(["a"], id: "b", mode: "multi"), ["a", "b"])
        XCTAssertEqual(GuidePicker.toggled(["a", "b"], id: "a", mode: "multi"), ["b"])
    }

    func testFinishWaitsForASelectionUnlessAllowed() throws {
        XCTAssertFalse(GuidePicker.canFinish(try config(mode: "single").pickerConfig, selections: []))
        XCTAssertTrue(GuidePicker.canFinish(try config(mode: "single").pickerConfig, selections: ["a"]))
        XCTAssertTrue(GuidePicker.canFinish(try config(mode: "multi", allowEmpty: true).pickerConfig, selections: []))
        XCTAssertTrue(GuidePicker.canFinish(nil, selections: []), "no pickerConfig never holds Finish")
    }

    func testThePlistHasThe311Shape() throws {
        let steps = try XCTUnwrap(try config(mode: "multi").introSteps)
        let multi = GuidePicker.output(mode: "multi", selections: ["b", "a"], steps: steps)
        XCTAssertEqual(multi["selectedItems"] as? [[String: String]],
                       [["id": "a", "title": "Alpha"], ["id": "b", "title": "Beta"]], "step order, {id, title}")
        XCTAssertEqual(multi["selectionCount"] as? Int, 2)
        XCTAssertEqual(multi["selectionMode"] as? String, "multi")
        XCTAssertNotNil(multi["timestamp"] as? Date)

        let single = GuidePicker.output(mode: "single", selections: ["b"], steps: steps)
        XCTAssertEqual(single["selectedItem"] as? [String: String], ["id": "b", "title": "Beta"])
        XCTAssertNil(single["selectedItems"])
    }
}
