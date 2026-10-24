//
//  LocalizationService.swift
//  dialog
//
//  Loads language sidecar JSON files and answers localized string lookups. Each preset holds one in
//  @State; it is not an ObservableObject.
//

import Foundation

class LocalizationService {
    private var dictionaries: [String: [String: Any]] = [:]

    /// Loads every language file; relative paths resolve against `basePath`.
    func loadLanguages(from config: InspectConfig.LocalizationConfig, basePath: String) {
        for (langCode, relativePath) in config.languages {
            let fullPath: String
            if relativePath.hasPrefix("/") {
                fullPath = relativePath
            } else {
                let base = basePath.hasSuffix("/") ? basePath : basePath + "/"
                fullPath = base + relativePath
            }

            guard FileManager.default.fileExists(atPath: fullPath),
                  let data = try? Data(contentsOf: URL(fileURLWithPath: fullPath)),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                writeLog("LocalizationService: Failed to load \(langCode) from \(fullPath)", logLevel: .error)
                continue
            }

            dictionaries[langCode] = json
            writeLog("LocalizationService: Loaded \(langCode) (\(json.count) keys) from \(fullPath)", logLevel: .info)
        }
    }

    func string(forLanguage lang: String, key: String) -> String? {
        dictionaries[lang]?[key] as? String
    }

    func stringArray(forLanguage lang: String, key: String) -> [String]? {
        dictionaries[lang]?[key] as? [String]
    }

    func hasLanguage(_ lang: String) -> Bool {
        dictionaries[lang] != nil
    }

    /// The loaded language `defaultLanguage` names, or nil. "auto" picks the system language.
    func resolveDefaultLanguage(from config: InspectConfig.LocalizationConfig) -> String? {
        guard let defaultLang = config.defaultLanguage else { return nil }
        if defaultLang == "auto" {
            let systemLang = Locale.current.language.languageCode?.identifier ?? "en"
            if hasLanguage(systemLang) { return systemLang }
            // Configs may key `languages` by display name ("Deutsch"), so map the code to that key.
            if let key = Self.languageKey(forCode: systemLang, in: config.languages),
               hasLanguage(key) { return key }
            return nil
        }
        return hasLanguage(defaultLang) ? defaultLang : nil
    }

    /// The `languages` key for a language code: the code itself, a key whose file is named by the code
    /// (`"Deutsch": ".../de.json"`), or the language's display name. Nil rather than a guess.
    static func languageKey(forCode code: String, in languages: [String: String]) -> String? {
        let code = code.lowercased()
        if let exact = languages.keys.first(where: { $0.lowercased() == code }) { return exact }
        if let byFile = languages.first(where: { _, path in
            let stem = (path as NSString).lastPathComponent.lowercased()
            return stem == code || stem.hasPrefix(code + ".")
        })?.key { return byFile }
        let native = Locale(identifier: code).localizedString(forLanguageCode: code)
        let local = Locale.current.localizedString(forLanguageCode: code)
        return languages.keys.first { key in
            key.caseInsensitiveCompare(native ?? "\u{0}") == .orderedSame
                || key.caseInsensitiveCompare(local ?? "\u{0}") == .orderedSame
        }
    }

    /// A global `ui.*` string (e.g. "ui.helpTitle") from the language file, else `fallback`.
    func uiString(_ key: String, language: String?, fallback: String) -> String {
        guard let lang = language, hasLanguage(lang) else { return fallback }
        return string(forLanguage: lang, key: key) ?? fallback
    }

    /// A content block with its text replaced from the language pack. `prefix` is
    /// `<stepId>.content.<blockIndex>`; keys without an entry keep the block's own value.
    func localizedBlock(_ block: InspectConfig.GuidanceContent, language lang: String,
                        prefix: String) -> InspectConfig.GuidanceContent {
        var localized = block
        if let val = string(forLanguage: lang, key: "\(prefix).content") { localized.content = val }
        if let val = stringArray(forLanguage: lang, key: "\(prefix).items") { localized.items = val }
        if let val = string(forLanguage: lang, key: "\(prefix).caption") { localized.caption = val }
        if let val = string(forLanguage: lang, key: "\(prefix).helpText") { localized.helpText = val }
        if let val = string(forLanguage: lang, key: "\(prefix).placeholder") { localized.placeholder = val }
        if let val = string(forLanguage: lang, key: "\(prefix).label") { localized.label = val }
        if let val = string(forLanguage: lang, key: "\(prefix).specimenNote") { localized.specimenNote = val }
        if let stats = localized.stats {
            localized.stats = stats.enumerated().map { idx, cell in
                var cell = cell
                cell.value = string(forLanguage: lang, key: "\(prefix).stats.\(idx).value") ?? cell.value
                cell.label = string(forLanguage: lang, key: "\(prefix).stats.\(idx).label") ?? cell.label
                return cell
            }
        }
        if let lines = localized.checklist {
            localized.checklist = lines.enumerated().map { idx, line in
                var line = line
                line.text = string(forLanguage: lang, key: "\(prefix).checklist.\(idx)") ?? line.text
                return line
            }
        }
        return localized
    }
}
