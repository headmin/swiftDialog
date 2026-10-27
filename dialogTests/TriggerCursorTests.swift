//
//  TriggerCursorTests.swift
//  dialogTests
//
//  `TriggerCursor` reads the trigger file incrementally. It trusts its offset only while the bytes
//  already consumed are unchanged; a rewritten or replaced file is read from the start.
//

import XCTest
@testable import Dialog

final class TriggerCursorTests: XCTestCase {

    private func data(_ string: String) -> Data { Data(string.utf8) }

    // MARK: - Append

    func testAFreshCursorConsumesEverything() {
        var cursor = TriggerCursor()
        XCTAssertEqual(cursor.advance(over: data("next\n")).flatMap { String(bytes: $0, encoding: .utf8) },
                       "next\n")
    }

    func testAnAppendYieldsOnlyTheAppendedBytes() {
        var cursor = TriggerCursor()
        _ = cursor.advance(over: data("next\n"))
        let slice = cursor.advance(over: data("next\nnext\n"))
        XCTAssertEqual(slice.flatMap { String(bytes: $0, encoding: .utf8) }, "next\n",
                       "an append must not replay what was already processed")
    }

    func testAnUnchangedFileYieldsNothing() {
        var cursor = TriggerCursor()
        _ = cursor.advance(over: data("next\n"))
        XCTAssertNil(cursor.advance(over: data("next\n")),
                     "the 200ms fallback timer re-reads constantly; unchanged must mean nothing")
    }

    // MARK: - Replacement

    /// A same-length rewrite ("navigate: 2" then "navigate: 1") is still delivered.
    func testASameLengthRewriteIsNotSilentlyDropped() {
        var cursor = TriggerCursor()
        XCTAssertEqual(data("navigate: 2\n").count, data("navigate: 1\n").count,
                       "precondition: these are the same length, which is what hides the bug")

        _ = cursor.advance(over: data("navigate: 2\n"))
        let slice = cursor.advance(over: data("navigate: 1\n"))
        XCTAssertEqual(slice.flatMap { String(bytes: $0, encoding: .utf8) }, "navigate: 1\n",
                       "a same-length rewrite is a NEW command, not a re-read of the old one")
    }

    func testAShorterRewriteIsReadFromTheStart() {
        var cursor = TriggerCursor()
        _ = cursor.advance(over: data("navigate: 12\n"))
        let slice = cursor.advance(over: data("next\n"))
        XCTAssertEqual(slice.flatMap { String(bytes: $0, encoding: .utf8) }, "next\n")
    }

    /// A rewrite that also grew is read from the start, not sliced at the stale offset.
    func testALongerRewriteIsNotMistakenForAnAppend() {
        var cursor = TriggerCursor()
        _ = cursor.advance(over: data("next\n"))
        let slice = cursor.advance(over: data("navigate: 3\n"))
        XCTAssertEqual(slice.flatMap { String(bytes: $0, encoding: .utf8) }, "navigate: 3\n",
                       "the consumed prefix changed, so the file is new — read all of it")
    }

    func testAnEmptiedFileResetsTheCursor() {
        var cursor = TriggerCursor()
        _ = cursor.advance(over: data("next\n"))
        XCTAssertNil(cursor.advance(over: Data()), "nothing to process yet")
        let slice = cursor.advance(over: data("next\n"))
        XCTAssertEqual(slice.flatMap { String(bytes: $0, encoding: .utf8) }, "next\n",
                       "after truncation the same command must be deliverable again")
    }

    /// Seeking to end adopts the current length without processing it, so leftovers do not replay at launch.
    func testSeekingToEndSkipsExistingContentButStillTracksIt() {
        var cursor = TriggerCursor()
        cursor.seekToEnd(of: data("stale\nstale\n"))
        XCTAssertNil(cursor.advance(over: data("stale\nstale\n")),
                     "pre-existing content must not replay on launch")
        let slice = cursor.advance(over: data("stale\nstale\nnext\n"))
        XCTAssertEqual(slice.flatMap { String(bytes: $0, encoding: .utf8) }, "next\n")
    }

    /// Seeking to end still detects a later replacement.
    func testSeekingToEndStillDetectsAReplacement() {
        var cursor = TriggerCursor()
        cursor.seekToEnd(of: data("navigate: 2\n"))
        let slice = cursor.advance(over: data("navigate: 1\n"))
        XCTAssertEqual(slice.flatMap { String(bytes: $0, encoding: .utf8) }, "navigate: 1\n")
    }

    // MARK: - Repeats

    /// Appending the same command twice yields it twice (`echo "next" >> trigger` runs every time).
    func testAppendingTheSameCommandTwiceYieldsItTwice() {
        var cursor = TriggerCursor()
        _ = cursor.advance(over: data("next\n"))
        let slice = cursor.advance(over: data("next\nnext\n"))
        XCTAssertEqual(slice.flatMap { String(bytes: $0, encoding: .utf8) }, "next\n")
    }

    // MARK: - Unfinished lines

    /// A line caught mid-write is not dispatched in halves: it waits for its newline.
    func testALineStillBeingWrittenWaitsForItsNewline() {
        var cursor = TriggerCursor()
        let first = cursor.advance(over: data("next\nbatch_update:{\"a\""), now: 0)
        XCTAssertEqual(first.flatMap { String(bytes: $0, encoding: .utf8) }, "next\n")
        XCTAssertNil(cursor.advance(over: data("next\nbatch_update:{\"a\""), now: 0.1))
        let rest = cursor.advance(over: data("next\nbatch_update:{\"a\":1}\n"), now: 0.2)
        XCTAssertEqual(rest.flatMap { String(bytes: $0, encoding: .utf8) }, "batch_update:{\"a\":1}\n")
    }

    /// A last command written without a newline still runs, once it has stood still.
    func testALastLineWithoutANewlineRunsOnceItStandsStill() {
        var cursor = TriggerCursor()
        XCTAssertNil(cursor.advance(over: data("next"), now: 10))
        XCTAssertNil(cursor.advance(over: data("next"), now: 10 + TriggerCursor.tailGrace / 2))
        let slice = cursor.advance(over: data("next"), now: 10 + TriggerCursor.tailGrace)
        XCTAssertEqual(slice.flatMap { String(bytes: $0, encoding: .utf8) }, "next")
        XCTAssertNil(cursor.advance(over: data("next"), now: 20), "and only once")
    }

    /// Rewriting identical bytes reads as unchanged, so an idle file does not replay its last command each tick.
    func testAnIdenticalRewriteIsTreatedAsUnchanged() {
        var cursor = TriggerCursor()
        _ = cursor.advance(over: data("next\n"))
        XCTAssertNil(cursor.advance(over: data("next\n")),
                     "indistinguishable from an idle re-read; idle must win")
    }
}
