//
//  ReadinessProgressService.swift
//  dialog
//
//  Scan progress as reported over IPC; while it says "running" the flow's Continue button is
//  disabled. Wire format: `readiness:{json}` on the trigger file, the JSON a `ReadinessProgress`
//  where every field beyond `state` is optional. Last report wins; nothing is estimated here.
//
import Foundation
import SwiftUI

/// What the scan is doing, as it reports it.
enum ReadinessState: String, Codable {
    /// Checks are running; `index`/`total`/`check` may name the one in flight.
    case running
    /// The scan finished; pass/fail per check comes from the aggregator, not this feed.
    case complete
    /// The scan failed to run (not the same as checks failing).
    case failed
}

/// One progress report from a scan.
struct ReadinessProgress: Codable, Equatable {
    var state: ReadinessState
    /// 1-based index of the check in flight.
    var index: Int?
    /// Total checks in the run.
    var total: Int?
    /// Identifier of the check in flight, e.g. `audit_flags_lo_configure`.
    var check: String?
    /// Its category, e.g. "Auditing".
    var category: String?
    /// Seconds left, as the scan estimates them.
    var secondsRemaining: Int?
    /// Why the run failed, when `state == .failed`.
    var message: String?

    static let idle = ReadinessProgress(state: .complete)
}

/// Observable holder for the latest report. Fed by IPC only.
@MainActor
@Observable
final class ReadinessProgressService {

    /// Nil until a scan reports; nil is not "running".
    private(set) var progress: ReadinessProgress?

    /// Apply a report delivered over IPC (`readiness:{json}`).
    func applyIPC(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(ReadinessProgress.self, from: data) else {
            writeLog("ReadinessProgress: malformed IPC payload", logLevel: .error)
            return
        }
        guard decoded != progress else { return }
        progress = decoded
        writeLog("ReadinessProgress: \(decoded.state.rawValue) \(decoded.index.map { "\($0)" } ?? "-")/\(decoded.total.map { "\($0)" } ?? "-")",
                 logLevel: .debug)
    }

    /// True only while the last report says running; no report, complete and failed all re-enable Continue.
    var isRunning: Bool {
        progress?.state == .running
    }
}
