//
//  DetectionMechanics.swift
//
//  Filesystem facts for each delivery mechanic (log path, cache, receipts), the counterpart of
//  `LogPatternPreset.presets`. Unverified values stay `nil` with a caveat rather than a guess.
//

import Foundation

struct MechanicPaths {
    /// Where this mechanic writes its progress.
    let logPath: String
    /// The key into `LogPatternPreset.presets`.
    let logPreset: String
    /// Where an in-progress download lands, or nil when nothing evidences one.
    let cachePath: String?
    /// Proof-of-install on disk; a glob because the receipt name carries a version.
    let receiptGlob: String?
    /// What this mechanic cannot tell you; shown verbatim by the wizard.
    let caveat: String?
}

enum DetectionMechanic: String, CaseIterable {
    case munki, jamf, installomator, orbit

    var paths: MechanicPaths {
        switch self {
        case .munki:
            return MechanicPaths(
                logPath: "/Library/Managed Installs/Logs/ManagedSoftwareUpdate.log",
                logPreset: "munki",
                cachePath: "/Library/Managed Installs/Cache",
                receiptGlob: nil,
                caveat: "munki's success line does not name the item, so a finished install is matched to "
                      + "the item munki was working on, not to the line's text.")
        case .jamf:
            return MechanicPaths(
                logPath: "/var/log/jamf.log",
                logPreset: "jamf",
                cachePath: "/Library/Application Support/JAMF/Downloads",
                // Directory-wide; an item narrows it to its title, keeping the trailing `*`.
                receiptGlob: "/Library/Application Support/JAMF/Receipts/*",
                caveat: "the jamf preset reads policy lines only; jamf may not log each install step, so "
                      + "per-item progress may not appear.")
        case .installomator:
            return MechanicPaths(
                logPath: "/var/log/Installomator.log",
                logPreset: "installomator",
                cachePath: nil,
                receiptGlob: nil,
                caveat: "no download cache is known for it, so progress comes from its log, not from files "
                      + "on disk.")
        case .orbit:
            return MechanicPaths(
                logPath: "/var/log/orbit/orbit.stderr.log",
                logPreset: "orbit",
                cachePath: nil,
                receiptGlob: nil,
                caveat: "no download cache is known for it, so progress comes from its log, not from files "
                      + "on disk.")
        }
    }

    /// Where the finished app lands; the same for every mechanic.
    func installedPath(appName: String) -> String { "/Applications/\(appName).app" }
}
