//
//  InspectLintTests.swift
//  dialogTests
//
//  The config lint: its findings and the script keys it knows.
//

import XCTest
import SwiftUI
import AppKit
@testable import Dialog

// Lint: the whole-flow checks an author needs before running anything.
@MainActor
final class InspectLintTests: XCTestCase {

    private func findings(_ json: String) -> [InspectLintFinding] {
        InspectLint.lint(data: Data(json.utf8))
    }

    private let clean = #"""
    {"preset":"5","chrome":"provisioning","introSteps":[
      {"id":"pick","stepType":"options","optionMultiSelect":true,"optionKey":"tasks",
       "optionCards":[{"id":"a","label":"A","category":"One","cancels":["category:Two"]},
                      {"id":"b","label":"B","category":"Two"}]},
      {"id":"check","stepType":"review"},
      {"id":"run","stepType":"cadence"},
      {"id":"done","stepType":"outro","receipt":[{"stepId":"pick","label":"Tasks","selectionKey":"tasks"}]}]}
    """#

    func testACleanStepFlowHasNoFindings() {
        let all = findings(clean)
        XCTAssertEqual(all, [], "\(all)")
        XCTAssertEqual(InspectLint.exitCode(for: all), 0)
    }

    func testEachWholeFlowCheckFires() {
        let broken = clean
            .replacingOccurrences(of: #""cancels":["category:Two"]"#, with: #""cancels":["category:Nope","ghost"]"#)
            .replacingOccurrences(of: #""stepId":"pick""#, with: #""stepId":"gone""#)
            .replacingOccurrences(of: #""preset":"5","#, with: #""preset":"5","phaseBackgroundPalette":["preset:g99"],"#)
        let messages = findings(broken).map(\.message).joined(separator: "\n")
        XCTAssertTrue(messages.contains("'category:Nope' names no category"), messages)
        XCTAssertTrue(messages.contains("'ghost' is not an option"), messages)
        XCTAssertTrue(messages.contains("points at step 'gone'"), messages)
        XCTAssertTrue(messages.contains("'preset:g99' is not a gradient preset"), messages)
        XCTAssertEqual(InspectLint.exitCode(for: findings(broken)), 1)
    }

    func testAFollowerWithNothingToFollowIsAnError() {
        let noChooser = #"{"preset":"5","introSteps":[{"id":"check","stepType":"review"},{"id":"run","stepType":"cadence"}]}"#
        let messages = findings(noChooser).map(\.message)
        XCTAssertTrue(messages.contains { $0.contains("no multi-select chooser to follow") }, "\(messages)")
        XCTAssertTrue(messages.contains { $0.contains("no entries and no chooser") }, "\(messages)")
    }

    func testAShowWhenNobodyRecordsIsAWarning() {
        let json = clean.replacingOccurrences(of: #"{"id":"check","stepType":"review"}"#,
                                              with: #"{"id":"check","stepType":"review","showWhen":{"key":"nobody","anyOf":["x"]}}"#)
        let found = findings(json).first { $0.path == "introSteps[check].showWhen" }
        XCTAssertEqual(found?.severity, .warning)
    }
}

// Lint counts a key a sibling script records (`select:<key>:`) as recorded.
final class LintScriptKeysTests: XCTestCase {
    func testSelectLinesInAScriptAreRecordedKeys() {
        let script = #"send "select:installed:${(j:,:)INSTALLED}"; echo "select:team.pick:eng""#
        XCTAssertEqual(InspectLint.scriptKeys(inScript: script), ["installed", "team.pick"])
        XCTAssertTrue(InspectLint.scriptKeys(inScript: "cadence:satisfy:zoom").isEmpty)
    }
}
