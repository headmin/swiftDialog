//
//  InspectAdvisory.swift
//  dialog
//
//  A file-backed advisory channel beside `writeLog`, for harnesses that cannot read stderr.
//  Off unless `DIALOG_INSPECT_ADVISORY_LOG` names a path.
//

import Foundation

enum InspectAdvisory {

    /// The environment variable that turns the channel on; scripts export the same name.
    static let variable = "DIALOG_INSPECT_ADVISORY_LOG"

    /// Where advisories go, or nil when the channel is off.
    static func destination(in environment: [String: String]) -> String? {
        guard let path = environment[variable], !path.isEmpty else { return nil }
        return path
    }

    /// Appends one line; a no-op when the channel is off and silent on write failure.
    static func note(_ message: String) {
        guard let path = destination(in: ProcessInfo.processInfo.environment) else { return }
        let line = message + "\n"
        guard let data = line.data(using: .utf8) else { return }
        let url = URL(fileURLWithPath: path)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }
}
