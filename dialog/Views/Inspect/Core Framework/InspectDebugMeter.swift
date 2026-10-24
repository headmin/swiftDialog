//
//  InspectDebugMeter.swift
//
//  Live metering for the opt-in debug panel: which row-moving source is alive on this host, a
//  running tail, and read-only probes of managed plists and the device API.
//

import Foundation
import Synchronization

/// One line of the running tail, tagged with its source so the panel can show one source at a time.
struct RecentLine: Equatable, Sendable {
    let at: Date
    let source: String?      // nil for lines that are not attributable to one source
    let text: String
}

/// One source's live account.
struct InspectSourceMeter: Equatable, Sendable {
    /// Rows actually moved.
    var count: Int = 0
    /// Lines that arrived for this source, matched or not; a source whose lines all miss is not silent.
    var attempts: Int = 0
    var lastItem: String = ""
    var lastDetail: String = ""
    var lastAt: Date?
}

/// A `Mutex`-guarded store the panel reads on a timer. Events arrive from the FSEvents queue,
/// the debouncer queue and main, and a debug instrument must not impose actor plumbing on the
/// code it measures.
final class InspectDebugMeter: Sendable {
    static let shared = InspectDebugMeter()

    /// The environment variable that shows the panel. The meter records regardless, so a panel
    /// opened mid-run shows history.
    static let variable = "DIALOG_INSPECT_DEBUG"

    static func panelEnabled(in environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        guard let value = environment[variable]?.lowercased() else { return false }
        return !["", "0", "false", "no"].contains(value)
    }

    /// Everything this store holds, in one value behind one lock.
    private struct State: Sendable {
        var sources: [String: InspectSourceMeter] = [:]
        var facts: [(key: String, value: String)] = []
        var recent: [RecentLine] = []
        /// The last device API sweep, carried in full by the dump.
        var fleetSweep: InspectFleetProbe.Result?

        /// Caller is inside the lock.
        mutating func append(source: String?, _ text: String) {
            recent.append(RecentLine(at: Date(), source: source, text: text))
            if recent.count > 400 { recent.removeFirst(recent.count - 400) }
        }
    }

    private let state = Mutex(State())

    /// Every source that can move a row, listed whether or not it has: a zero is the finding.
    static let knownSources = ["fsevents", "poller", "logmonitor", "requirements", "census", "listitem", "cadence:message"]

    private init() {
        state.withLock { state in
            for name in Self.knownSources { state.sources[name] = InspectSourceMeter() }
        }
    }

    // MARK: - Recording

    func record(source: String, itemId: String, detail: String) {
        state.withLock { state in
            var meter = state.sources[source] ?? InspectSourceMeter()
            meter.count += 1
            meter.attempts += 1
            meter.lastItem = itemId
            meter.lastDetail = detail
            meter.lastAt = Date()
            state.sources[source] = meter
            state.append(source: source, "\(itemId)  \(detail)")
        }
    }

    /// A standing fact about this session (config path, chrome, step, row count). Last write per
    /// key wins.
    func note(fact key: String, _ value: String) {
        state.withLock { state in
            if let index = state.facts.firstIndex(where: { $0.key == key }) {
                state.facts[index].value = value
            } else {
                state.facts.append((key, value))
            }
        }
    }

    /// A tail line for something that is not a row transition: a command, a subject that matched
    /// nothing.
    func trace(_ text: String, source: String? = nil) {
        state.withLock { state in
            if let source {
                var meter = state.sources[source] ?? InspectSourceMeter()
                meter.attempts += 1
                meter.lastAt = Date()
                state.sources[source] = meter
            }
            state.append(source: source, text)
        }
    }

    // MARK: - Reading

    struct Snapshot: Equatable {
        var sources: [(name: String, meter: InspectSourceMeter)]
        var facts: [(String, String)]
        var recent: [RecentLine]

        static func == (lhs: Snapshot, rhs: Snapshot) -> Bool {
            lhs.recent == rhs.recent
                && lhs.facts.map(\.0) == rhs.facts.map(\.0)
                && lhs.facts.map(\.1) == rhs.facts.map(\.1)
                && lhs.sources.map(\.name) == rhs.sources.map(\.name)
                && lhs.sources.map(\.meter) == rhs.sources.map(\.meter)
        }
    }

    /// Writes everything collected so far to a file in `directory` and returns the path.
    func dump(to directory: String = "/private/tmp") -> String? {
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let path = "\(directory)/dialog-debug-\(stamp).txt"
        let snap = snapshot()
        var out = ["swiftDialog inspect — debug dump \(stamp)", ""]
        out.append("SOURCES")
        for entry in snap.sources {
            let seen = entry.meter.lastAt.map { ISO8601DateFormatter().string(from: $0) } ?? "never"
            out.append("  \(entry.name.padding(toLength: 16, withPad: " ", startingAt: 0)) "
                       + "matched=\(entry.meter.count) arrived=\(entry.meter.attempts) last=\(seen) "
                       + "item=\(entry.meter.lastItem) \(entry.meter.lastDetail)")
        }
        out.append("")
        out.append("FACTS")
        for (key, value) in snap.facts { out.append("  \(key): \(value)") }
        out.append("")
        // Every title per endpoint; the panel shows only the first eight.
        if let fleet = lastFleetSweep {
            out.append("FLEET (\(fleet.url) via \(fleet.urlSource), token \(fleet.tokenChars) chars)")
            if let error = fleet.error { out.append("  error: \(error)") }
            for answer in fleet.answers {
                out.append("  \(answer.safe ? " " : "!") \(answer.name)")
                out.append("      \(answer.summary)")
                out.append("      expected: \(answer.expectation)")
                for line in answer.titles { out.append("        \(line)") }
            }
            out.append("")
        }
        out.append("RECENT (oldest first, \(snap.recent.count) lines)")
        let formatter = ISO8601DateFormatter()
        for line in snap.recent {
            out.append("  \(formatter.string(from: line.at)) [\(line.source ?? "-")] \(line.text)")
        }
        let text = out.joined(separator: "\n") + "\n"
        guard let data = text.data(using: .utf8),
              (try? data.write(to: URL(fileURLWithPath: path))) != nil else { return nil }
        return path
    }

    func recordFleetSweep(_ result: InspectFleetProbe.Result) {
        state.withLock { $0.fleetSweep = result }
    }

    private var lastFleetSweep: InspectFleetProbe.Result? {
        state.withLock { $0.fleetSweep }
    }

    func snapshot() -> Snapshot {
        state.withLock { state in
            // Known sources first in a fixed order so the panel does not reshuffle; extras follow, sorted.
            let extra = state.sources.keys.filter { !Self.knownSources.contains($0) }.sorted()
            let names = Self.knownSources + extra
            return Snapshot(sources: names.map { ($0, state.sources[$0] ?? InspectSourceMeter()) },
                            facts: state.facts.map { ($0.key, $0.value) },
                            recent: state.recent)
        }
    }
}

/// Reads out the keys of the preference domains the flow depends on, to answer whether a profile
/// has arrived. Reads the plist directly, not CFPreferences, whose cache can lag.
enum InspectPlistInspector {

    struct Domain: Identifiable {
        var id: String { name }
        let name: String
        let path: String
        let note: String
    }

    /// The known domains plus `extra`, each read from `/Library/Managed Preferences` when present,
    /// else `/Library/Preferences`.
    static func domains(extra: [String] = []) -> [Domain] {
        let known: [(String, String)] = [
            ("com.ignitecli", "the flow's own managed policy — the one that has gone missing"),
            ("com.fleetdm.fleetd.config", "Fleet's URL and enroll secret, read by orbit itself"),
            ("au.csiro.dialog", "swiftDialog's own defaults"),
            ("com.example.branding", "brand palette and logos from MDM")
        ]
        let names = known.map(\.0) + extra.filter { candidate in !known.contains { $0.0 == candidate } }
        return names.map { name in
            let managed = "/Library/Managed Preferences/\(name).plist"
            let local = "/Library/Preferences/\(name).plist"
            let path = FileManager.default.fileExists(atPath: managed) ? managed : local
            let note = known.first { $0.0 == name }?.1 ?? "requested for this run"
            return Domain(name: name, path: path, note: note)
        }
    }

    /// Every key in a domain, sorted, with values flattened to one line. nil when the file is
    /// absent, which differs from "arrived but empty".
    static func read(_ domain: Domain) -> [(String, String)]? {
        guard let data = FileManager.default.contents(atPath: domain.path),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any] else { return nil }
        return plist.keys.sorted().map { key in
            (key, flatten(plist[key]))
        }
    }

    private static func flatten(_ value: Any?) -> String {
        switch value {
        case let string as String: return string
        case let number as NSNumber: return number.stringValue
        case let array as [Any]: return "[" + array.map { flatten($0) }.joined(separator: ", ") + "]"
        case let dict as [String: Any]:
            return "{" + dict.keys.sorted().map { "\($0): \(flatten(dict[$0]))" }.joined(separator: ", ") + "}"
        case let date as Date: return ISO8601DateFormatter().string(from: date)
        case let data as Data: return "<\(data.count) bytes>"
        default: return value.map { "\($0)" } ?? "—"
        }
    }
}

/// Queries the device API with the token already on the Mac and dumps what the server knows
/// about this host. Read-only: `setup_experience/status` advances the server's install queue on
/// every call, so it runs only when explicitly asked for.
enum InspectFleetProbe {

    /// One endpoint and whether asking it is side-effect free.
    struct Endpoint: Identifiable {
        var id: String { name }
        let name: String
        let query: String
        let method: String
        /// False for an endpoint that changes server state when asked.
        let safe: Bool
        let expectation: String
    }

    /// The read-only device-token endpoints. Endpoints that change something (install, uninstall,
    /// refetch, …) must stay out: a debug sweep has to be safe to press.
    static let endpoints: [Endpoint] = [
        .init(name: "software (default)", query: "software?per_page=400",
              method: "GET", safe: true, expectation: "inventory only"),
        .init(name: "software +available", query: "software?per_page=400&include_available_for_install=true",
              method: "GET", safe: true,
              expectation: "ignored on this route — the default decoder never sets the flag"),
        .init(name: "software +self_service", query: "software?per_page=400&self_service=true",
              method: "GET", safe: true,
              expectation: "forces the flag — 6 scoped in the field where the default gave 0"),
        .init(name: "self_service_categories", query: "software/self_service_categories",
              method: "GET", safe: true, expectation: "how self-service software is grouped"),
        .init(name: "desktop", query: "desktop",
              method: "GET", safe: true, expectation: "the Fleet Desktop summary — counts and flags"),
        .init(name: "ping", query: "ping",
              method: "GET", safe: true, expectation: "reachability and token validity, cheapest check"),
        .init(name: "host", query: "",
              method: "GET", safe: true, expectation: "the whole host record as the device sees it"),
        .init(name: "policies", query: "policies",
              method: "GET", safe: true, expectation: "policy pass/fail for this host"),
        .init(name: "certificates", query: "certificates",
              method: "GET", safe: true, expectation: "certificates Fleet knows about"),
        .init(name: "device_mapping", query: "device_mapping",
              method: "GET", safe: true, expectation: "the identities mapped to this host"),
        .init(name: "macadmins", query: "macadmins",
              method: "GET", safe: true, expectation: "munki and MDM enrolment as Fleet sees them"),
        .init(name: "setup_experience/status", query: "setup_experience/status",
              method: "POST", safe: false,
              expectation: "the ONLY one that knows the SE set — and it ADVANCES ORBIT'S QUEUE")
    ]

    struct Answer: Identifiable, Sendable {
        var id: String { name }
        let name: String
        let summary: String
        let titles: [String]
        let safe: Bool
        let expectation: String
    }

    struct Result: Sendable {
        var url: String = ""
        var urlSource: String = ""
        var tokenChars: Int = 0
        var answers: [Answer] = []
        var error: String?
    }

    /// The server URL: `--tls_hostname` on the live osqueryd command line, else `FleetURL` in the
    /// agent's configuration profile.
    static func resolveURL() -> (String, String)? {
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-Ao", "args="]
        let pipe = Pipe()
        ps.standardOutput = pipe
        if (try? ps.run()) != nil {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            ps.waitUntilExit()
            if let text = String(data: data, encoding: .utf8) {
                for token in text.split(whereSeparator: { $0 == " " || $0 == "\n" })
                where token.hasPrefix("--tls_hostname=") {
                    return (normalise(String(token.dropFirst(15))), "live osqueryd command line")
                }
            }
        }
        let profile = "/Library/Managed Preferences/com.fleetdm.fleetd.config.plist"
        if let data = FileManager.default.contents(atPath: profile),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let url = plist["FleetURL"] as? String, !url.isEmpty {
            return (normalise(url), "the fleetd configuration profile")
        }
        return nil
    }

    private static func normalise(_ host: String) -> String {
        host.hasPrefix("http") ? host : "https://\(host)"
    }

    /// Asks every safe endpoint in turn, and the unsafe one only when `includeUnsafe`.
    static func run(includeUnsafe: Bool = false) async -> Result {
        var result = Result()
        guard let (url, source) = resolveURL() else {
            result.error = "no Fleet URL — orbit not enrolled yet?"
            return result
        }
        result.url = url
        result.urlSource = source
        guard let token = try? String(contentsOfFile: "/opt/orbit/identifier", encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            result.error = "no device token at /opt/orbit/identifier"
            return result
        }
        result.tokenChars = token.count

        for endpoint in endpoints where endpoint.safe || includeUnsafe {
            let (summary, titles) = await ask("\(url)/api/v1/fleet/device/\(token)/\(endpoint.query)",
                                              method: endpoint.method)
            result.answers.append(Answer(name: endpoint.name, summary: summary, titles: titles,
                                         safe: endpoint.safe, expectation: endpoint.expectation))
            InspectDebugMeter.shared.note(fact: "fleet · \(endpoint.name)", summary)
        }
        return result
    }

    /// One request with a 15 s timeout; returns a summary line and the titles it lists. An error
    /// returns the URLSession error text as the summary.
    private static func ask(_ urlString: String, method: String = "GET") async -> (String, [String]) {
        guard let url = URL(string: urlString) else { return ("bad URL", []) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            return ("error: \(error.localizedDescription)", [])
        }

        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ("HTTP \(code), unreadable body", [])
        }
        // setup_experience/status answers in a different shape.
        if let results = json["setup_experience_results"] as? [String: Any] {
            let se = (results["software"] as? [[String: Any]]) ?? []
            let script = results["script"] != nil ? 1 : 0
            return ("HTTP \(code) · \(se.count) software · \(script) script",
                    se.map { item in
                        let name = (item["name"] as? String) ?? "?"
                        return "\(item["status"] as? String ?? "-")  \(name)"
                    })
        }
        guard let software = json["software"] as? [[String: Any]] else {
            // Most endpoints have no software list; summarise the shape of the answer instead.
            let keys = json.keys.sorted()
            return ("HTTP \(code) · keys: \(keys.prefix(8).joined(separator: ", "))",
                    keys.map { key in
                        let value = json[key]
                        if let array = value as? [Any] { return "\(key): [\(array.count)]" }
                        if let dict = value as? [String: Any] {
                            return "\(key): {\(dict.keys.sorted().prefix(10).joined(separator: ", "))}"
                        }
                        return "\(key): \(value.map { "\($0)" } ?? "null")"
                    })
        }
        let scoped = software.filter { $0["status"] is String }
        return ("HTTP \(code) · \(software.count) titles · \(scoped.count) with a status",
                scoped.compactMap { item in
                    let name = (item["display_name"] as? String) ?? (item["name"] as? String) ?? "?"
                    return "\(item["status"] as? String ?? "-")  \(name)"
                })
    }
}
