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
}
