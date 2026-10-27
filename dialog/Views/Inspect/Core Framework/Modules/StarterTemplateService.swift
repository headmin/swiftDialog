//
//  StarterTemplateService.swift
//  dialog
//
//  Starter config templates for the 7 presets, written to ~/Desktop by `--inspect-starter`;
//  each is a self-contained JSON config plus a run.sh.
//

import Foundation

struct StarterTemplateService {

    // MARK: - Preset Name Lookup

    private static let presetNames: [Int: String] = [
        1: "deployment",
        2: "cards",
        3: "compact",
        4: "toast",
        5: "unified",
        6: "guidance",
        7: "guided-setup"
    ]

    // MARK: - Template Configs

    private static let templates: [Int: String] = [

        // ── Preset 1: Deployment ────────────────────────────────────────
        1: """
        {
            "preset": "1",
            "title": "App Deployment",
            "message": "Installing applications...(example)",
            "icon": "SF=arrow.down.app.fill",
            "highlightColor": "#007AFF",
            "items": [
                {
                    "id": "safari",
                    "displayName": "Safari",
                    "icon": "/Applications/Safari.app",
                    "paths": ["/Applications/Safari.app"],
                    "showBundleInfo": "all"
                },
                {
                    "id": "calculator",
                    "displayName": "Calculator",
                    "icon": "/System/Applications/Calculator.app",
                    "paths": ["/System/Applications/Calculator.app"],
                    "showBundleInfo": "all"
                },
                {
                    "id": "textedit",
                    "displayName": "TextEdit",
                    "icon": "/System/Applications/TextEdit.app",
                    "paths": ["/System/Applications/TextEdit.app"],
                    "showBundleInfo": "all"
                }
            ]
        }
        """,

        // ── Preset 2: Cards ─────────────────────────────────────────────
        2: """
        {
            "preset": "2",
            "title": "App Catalog",
            "message": "Installing applications...(example)",
            "icon": "SF=rectangle.split.3x1.fill",
            "highlightColor": "#34C759",
            "items": [
                {
                    "id": "safari",
                    "displayName": "Safari",
                    "icon": "/Applications/Safari.app",
                    "paths": ["/Applications/Safari.app"],
                    "showBundleInfo": "all"
                },
                {
                    "id": "calculator",
                    "displayName": "Calculator",
                    "icon": "/System/Applications/Calculator.app",
                    "paths": ["/System/Applications/Calculator.app"],
                    "showBundleInfo": "all"
                },
                {
                    "id": "textedit",
                    "displayName": "TextEdit",
                    "icon": "/System/Applications/TextEdit.app",
                    "paths": ["/System/Applications/TextEdit.app"],
                    "showBundleInfo": "all"
                }
            ]
        }
        """,

        // ── Preset 3: Compact ───────────────────────────────────────────
        3: """
        {
            "preset": "3",
            "title": "Quick Install",
            "message": "Installing essentials...(example)",
            "icon": "SF=list.bullet.rectangle.fill",
            "highlightColor": "#5856D6",
            "secondaryColor": "#AF52DE",
            "items": [
                {
                    "id": "safari",
                    "displayName": "Safari",
                    "icon": "/Applications/Safari.app",
                    "paths": ["/Applications/Safari.app"]
                },
                {
                    "id": "calculator",
                    "displayName": "Calculator",
                    "icon": "/System/Applications/Calculator.app",
                    "paths": ["/System/Applications/Calculator.app"]
                },
                {
                    "id": "textedit",
                    "displayName": "TextEdit",
                    "icon": "/System/Applications/TextEdit.app",
                    "paths": ["/System/Applications/TextEdit.app"]
                }
            ]
        }
        """,

        // ── Preset 4: Toast ─────────────────────────────────────────────
        4: """
        {
            "preset": "4",
            "title": "Background Install",
            "icon": "SF=bell.badge.fill",
            "highlightColor": "#FF9500",
            "introScreen": {
                "title": "Software Check",
                "subtitle": "Checking 3 applications...",
                "buttonText": "Begin"
            },
            "summaryScreen": {
                "title": "All Done",
                "subtitle": "All applications installed successfully.",
                "buttonText": "Close"
            },
            "items": [
                {
                    "id": "safari",
                    "displayName": "Safari",
                    "icon": "/Applications/Safari.app",
                    "paths": ["/Applications/Safari.app"]
                },
                {
                    "id": "calculator",
                    "displayName": "Calculator",
                    "icon": "/System/Applications/Calculator.app",
                    "paths": ["/System/Applications/Calculator.app"]
                },
                {
                    "id": "textedit",
                    "displayName": "TextEdit",
                    "icon": "/System/Applications/TextEdit.app",
                    "paths": ["/System/Applications/TextEdit.app"]
                }
            ]
        }
        """,

        // ── Preset 5: Unified Portal ────────────────────────────────────
        5: """
        {
            "preset": "5",
            "highlightColor": "#007AFF",
            "introSteps": [
                {
                    "id": "welcome",
                    "stepType": "intro",
                    "title": "Welcome",
                    "subtitle": "Your starter Preset 5 workflow (example)",
                    "heroImage": "computer",
                    "heroImageSize": 180,
                    "content": [
                        { "type": "text", "content": "This is a two-step starter. Edit config.json to add more steps, change layouts, or customise the content." },
                        { "type": "bullets", "items": ["Step types: intro, deployment, carousel, guide, showcase, bento, processing, portal, outro", "55+ content block types available", "Add branding, forms, compliance checks"] }
                    ],
                    "continueButtonText": "Next",
                    "showBackButton": false
                },
                {
                    "id": "apps",
                    "stepType": "deployment",
                    "title": "App Installation",
                    "subtitle": "Simulated deployment step",
                    "heroImage": "SF=arrow.down.app.fill",
                    "items": [
                        { "id": "safari", "displayName": "Safari", "guiIndex": 0, "icon": "/Applications/Safari.app", "paths": ["/Applications/Safari.app"] },
                        { "id": "calculator", "displayName": "Calculator", "guiIndex": 1, "icon": "/System/Applications/Calculator.app", "paths": ["/System/Applications/Calculator.app"] },
                        { "id": "textedit", "displayName": "TextEdit", "guiIndex": 2, "icon": "/System/Applications/TextEdit.app", "paths": ["/System/Applications/TextEdit.app"] }
                    ],
                    "continueButtonText": "Finish",
                    "showBackButton": true
                }
            ]
        }
        """,

        // ── Preset 6: Guidance / Modern Sidebar ─────────────────────────
        6: """
        {
            "preset": "6",
            "title": "Service Portal",
            "highlightColor": "#007AFF",
            "items": [
                {
                    "id": "overview",
                    "displayName": "Overview",
                    "icon": "SF=house.fill",
                    "guidanceTitle": "Welcome",
                    "guidanceContent": [
                        { "type": "text", "content": "Welcome to the sidebar navigation layout. Users can navigate between sections." },
                        { "type": "info", "content": "Edit config.json to add more sections, change icons, or customise the content blocks." }
                    ]
                },
                {
                    "id": "apps",
                    "displayName": "Applications",
                    "icon": "SF=app.badge.fill",
                    "guidanceTitle": "Applications",
                    "guidanceContent": [
                        { "type": "text", "content": "This section could list available applications or provide self-service options." },
                        { "type": "bullets", "items": ["Safari — Web browser", "Calculator — Quick math", "TextEdit — Text editor"] }
                    ]
                },
                {
                    "id": "help",
                    "displayName": "Help & Support",
                    "icon": "SF=questionmark.circle.fill",
                    "guidanceTitle": "Help & Support",
                    "guidanceContent": [
                        { "type": "text", "content": "Add links, contact info, or troubleshooting guides here." },
                        { "type": "button", "content": "Open Apple Support", "icon": "safari.fill", "action": "url", "url": "https://support.apple.com" }
                    ]
                }
            ]
        }
        """,

        // ── Preset 7: Guided Setup ──────────────────────────────────────
        // Presents the choices and emits them over IPC (select:/dock:); an orchestrator applies
        // them. Built-in apps are the defaults so it runs on any Mac.
        7: """
        {
            "preset": "7",
            "size": "setup",
            "highlightColor": "#007AFF",
            "footerText": "Guided Setup — example",
            "brandSelectionKey": "selectedBrand",
            "appConfigSource": {
                "domain": "com.example.branding",
                "highlightColorKey": "HighlightColor",
                "logoPathKey": "LogoPath",
                "footerTextKey": "FooterText",
                "allowedBrandsKey": "AllowedBrands"
            },
            "localization": {
                "languages": { "de": "lang/de.json", "fr": "lang/fr.json" },
                "selectionKey": "preferredLanguage",
                "defaultLanguage": "auto"
            },
            "brands": [
                { "id": "acme", "displayName": "Acme Corp", "sfSymbol": "building.2.fill", "highlightColor": "#0A84FF", "footerText": "Acme Corp — IT" },
                { "id": "globex", "displayName": "Globex", "sfSymbol": "globe.americas.fill", "highlightColor": "#30D158", "footerText": "Globex — Onboarding" },
                { "id": "initech", "displayName": "Initech", "sfSymbol": "printer.fill", "highlightColor": "#FF9F0A", "footerText": "Initech — Setup" }
            ],
            "summaryScreen": {
                "title": "You're all set",
                "subtitle": "Your Mac is ready to go.",
                "buttonText": "Done",
                "autoTransition": false
            },
            "introSteps": [
                {
                    "id": "language",
                    "stepType": "options",
                    "title": "Choose your language",
                    "subtitle": "Sprache · Langue",
                    "heroImage": "SF=globe",
                    "heroImageSize": 80,
                    "optionKey": "preferredLanguage",
                    "optionCards": [
                        { "id": "en", "label": "English", "sfSymbol": "a.circle", "value": "en" },
                        { "id": "de", "label": "Deutsch", "sfSymbol": "a.circle.fill", "value": "de" },
                        { "id": "fr", "label": "Français", "sfSymbol": "a.square", "value": "fr" }
                    ],
                    "continueButtonText": "Continue",
                    "showBackButton": false
                },
                {
                    "id": "welcome",
                    "stepType": "intro",
                    "title": "Welcome to your new Mac",
                    "subtitle": "Let's get you set up in a few quick steps.",
                    "heroImage": "SF=sparkles",
                    "heroImageSize": 90,
                    "content": [
                        { "type": "text", "content": "This guided setup lets you choose your Dock, default apps, and appearance. Edit config.json to rebrand, add or remove steps." }
                    ],
                    "continueButtonText": "Get Started",
                    "showBackButton": true
                },
                {
                    "id": "brand",
                    "stepType": "brandPicker",
                    "title": "Choose your brand",
                    "subtitle": "Colors and logo adapt to your selection.",
                    "continueButtonText": "Continue",
                    "showBackButton": true
                },
                {
                    "id": "dock",
                    "stepType": "dock",
                    "title": "Choose your Dock",
                    "subtitle": "Pick a starting layout — you can change it anytime.",
                    "heroImage": "SF=dock.rectangle",
                    "heroImageSize": 70,
                    "dockMode": "flavors",
                    "dockSelectionKey": "dock",
                    "dockFlavors": [
                        {
                            "id": "essentials",
                            "name": "Essentials",
                            "summary": "The everyday basics",
                            "sfSymbol": "star.fill",
                            "items": [
                                { "label": "Safari", "path": "/Applications/Safari.app", "sfSymbol": "safari" },
                                { "label": "Mail", "path": "/System/Applications/Mail.app", "sfSymbol": "envelope" },
                                { "label": "Notes", "path": "/System/Applications/Notes.app", "sfSymbol": "note.text" },
                                { "label": "Calendar", "path": "/System/Applications/Calendar.app", "sfSymbol": "calendar" },
                                { "label": "System Settings", "path": "/System/Applications/System Settings.app", "sfSymbol": "gearshape" }
                            ]
                        },
                        {
                            "id": "creative",
                            "name": "Creative",
                            "summary": "Media & photos",
                            "sfSymbol": "paintbrush.fill",
                            "items": [
                                { "label": "Safari", "path": "/Applications/Safari.app", "sfSymbol": "safari" },
                                { "label": "Photos", "path": "/System/Applications/Photos.app", "sfSymbol": "photo" },
                                { "label": "Music", "path": "/System/Applications/Music.app", "sfSymbol": "music.note" },
                                { "label": "Preview", "path": "/System/Applications/Preview.app", "sfSymbol": "doc.richtext" },
                                { "label": "Notes", "path": "/System/Applications/Notes.app", "sfSymbol": "note.text" }
                            ]
                        },
                        {
                            "id": "focused",
                            "name": "Focused",
                            "summary": "Minimal & distraction-free",
                            "sfSymbol": "circle.dashed",
                            "items": [
                                { "label": "Safari", "path": "/Applications/Safari.app", "sfSymbol": "safari" },
                                { "label": "Mail", "path": "/System/Applications/Mail.app", "sfSymbol": "envelope" },
                                { "label": "System Settings", "path": "/System/Applications/System Settings.app", "sfSymbol": "gearshape" }
                            ]
                        }
                    ],
                    "continueButtonText": "Continue",
                    "showBackButton": true
                },
                {
                    "id": "browser",
                    "stepType": "options",
                    "title": "Choose your browser",
                    "subtitle": "Which browser should open links by default?",
                    "heroImage": "SF=globe",
                    "heroImageSize": 70,
                    "optionKey": "browser",
                    "optionCards": [
                        { "id": "safari", "label": "Safari", "subtitle": "Built in", "iconPath": "/Applications/Safari.app", "value": "com.apple.safari" },
                        { "id": "chrome", "label": "Google Chrome", "subtitle": "If installed", "iconPath": "/Applications/Google Chrome.app", "sfSymbol": "globe", "value": "com.google.chrome" },
                        { "id": "edge", "label": "Microsoft Edge", "subtitle": "If installed", "iconPath": "/Applications/Microsoft Edge.app", "sfSymbol": "globe", "value": "com.microsoft.edgemac" }
                    ],
                    "continueButtonText": "Continue",
                    "showBackButton": true
                },
                {
                    "id": "email",
                    "stepType": "options",
                    "title": "Choose your email app",
                    "subtitle": "Which app should handle mailto: links?",
                    "heroImage": "SF=envelope",
                    "heroImageSize": 70,
                    "optionKey": "email",
                    "optionCards": [
                        { "id": "mail", "label": "Mail", "subtitle": "Built in", "iconPath": "/System/Applications/Mail.app", "value": "com.apple.mail" },
                        { "id": "outlook", "label": "Microsoft Outlook", "subtitle": "If installed", "iconPath": "/Applications/Microsoft Outlook.app", "sfSymbol": "envelope.fill", "value": "com.microsoft.outlook" }
                    ],
                    "continueButtonText": "Continue",
                    "showBackButton": true
                },
                {
                    "id": "pdf",
                    "stepType": "options",
                    "title": "Choose your PDF viewer",
                    "subtitle": "Which app should open PDF files?",
                    "heroImage": "SF=doc.richtext",
                    "heroImageSize": 70,
                    "optionKey": "pdf",
                    "optionCards": [
                        { "id": "preview", "label": "Preview", "subtitle": "Built in", "iconPath": "/System/Applications/Preview.app", "value": "com.apple.preview" },
                        { "id": "acrobat", "label": "Adobe Acrobat", "subtitle": "If installed", "iconPath": "/Applications/Adobe Acrobat Reader.app", "sfSymbol": "doc.fill", "value": "com.adobe.reader" }
                    ],
                    "continueButtonText": "Continue",
                    "showBackButton": true
                },
                {
                    "id": "appearance",
                    "stepType": "options",
                    "title": "Light or Dark?",
                    "subtitle": "Choose how macOS looks.",
                    "heroImage": "SF=circle.lefthalf.filled",
                    "heroImageSize": 70,
                    "optionKey": "appearance",
                    "optionCards": [
                        { "id": "light", "label": "Light", "sfSymbol": "sun.max.fill", "value": "light" },
                        { "id": "dark", "label": "Dark", "sfSymbol": "moon.fill", "value": "dark" },
                        { "id": "auto", "label": "Auto", "subtitle": "Follow the time of day", "sfSymbol": "clock.fill", "value": "auto" }
                    ],
                    "continueButtonText": "Continue",
                    "showBackButton": true
                },
                {
                    "id": "finish",
                    "stepType": "outro",
                    "title": "Setup complete",
                    "subtitle": "Your choices are ready to apply.",
                    "heroImage": "SF=checkmark.seal.fill",
                    "heroImageSize": 90,
                    "content": [
                        { "type": "text", "content": "Selections are emitted over IPC for your management tool to apply. Open a support link if you need help getting started." },
                        { "type": "button", "content": "Open Apple Support", "icon": "safari.fill", "action": "url", "url": "https://support.apple.com" }
                    ],
                    "continueButtonText": "Finish",
                    "showBackButton": true
                }
            ]
        }
        """
    ]

    // MARK: - Sample Localization Files (Preset 7)

    /// Translation sidecars for the preset 7 starter. Flat keys: `<stepId>.<property>` and
    /// `<stepId>.options.<cardId>.{label,subtitle}`, as the localization lookup expects.
    private static let guidedSetupLangFiles: [String: String] = [
        "de": """
        {
            "language.title": "Sprache wählen",
            "language.subtitle": "Choose your language · Langue",
            "welcome.title": "Willkommen auf Ihrem neuen Mac",
            "welcome.subtitle": "Wir richten alles in wenigen Schritten ein.",
            "welcome.content.0.content": "Dieses Setup hilft Ihnen, Dock, Standard-Apps und Erscheinungsbild zu wählen.",
            "brand.title": "Wählen Sie Ihre Marke",
            "brand.subtitle": "Farben und Logo passen sich an.",
            "dock.title": "Wählen Sie Ihr Dock",
            "dock.subtitle": "Wählen Sie ein Startlayout — jederzeit änderbar.",
            "browser.title": "Wählen Sie Ihren Browser",
            "browser.subtitle": "Welcher Browser soll Links standardmäßig öffnen?",
            "browser.options.chrome.subtitle": "Falls installiert",
            "browser.options.edge.subtitle": "Falls installiert",
            "browser.options.safari.subtitle": "Vorinstalliert",
            "email.title": "Wählen Sie Ihre E-Mail-App",
            "email.subtitle": "Welche App soll mailto:-Links öffnen?",
            "pdf.title": "Wählen Sie Ihren PDF-Viewer",
            "pdf.subtitle": "Welche App soll PDF-Dateien öffnen?",
            "appearance.title": "Hell oder Dunkel?",
            "appearance.subtitle": "Wählen Sie das Erscheinungsbild von macOS.",
            "appearance.options.light.label": "Hell",
            "appearance.options.dark.label": "Dunkel",
            "appearance.options.auto.label": "Automatisch",
            "finish.title": "Einrichtung abgeschlossen",
            "finish.subtitle": "Ihre Auswahl ist bereit."
        }
        """,
        "fr": """
        {
            "language.title": "Choisissez votre langue",
            "language.subtitle": "Sprache · Choose your language",
            "welcome.title": "Bienvenue sur votre nouveau Mac",
            "welcome.subtitle": "Configurons tout en quelques étapes.",
            "welcome.content.0.content": "Cette configuration vous aide à choisir le Dock, les apps par défaut et l'apparence.",
            "brand.title": "Choisissez votre marque",
            "brand.subtitle": "Les couleurs et le logo s'adaptent.",
            "dock.title": "Choisissez votre Dock",
            "dock.subtitle": "Choisissez une disposition de départ — modifiable à tout moment.",
            "browser.title": "Choisissez votre navigateur",
            "browser.subtitle": "Quel navigateur doit ouvrir les liens par défaut ?",
            "browser.options.chrome.subtitle": "Si installé",
            "browser.options.edge.subtitle": "Si installé",
            "browser.options.safari.subtitle": "Préinstallé",
            "email.title": "Choisissez votre app e-mail",
            "email.subtitle": "Quelle app doit gérer les liens mailto: ?",
            "pdf.title": "Choisissez votre lecteur PDF",
            "pdf.subtitle": "Quelle app doit ouvrir les fichiers PDF ?",
            "appearance.title": "Clair ou sombre ?",
            "appearance.subtitle": "Choisissez l'apparence de macOS.",
            "appearance.options.light.label": "Clair",
            "appearance.options.dark.label": "Sombre",
            "appearance.options.auto.label": "Automatique",
            "finish.title": "Configuration terminée",
            "finish.subtitle": "Vos choix sont prêts."
        }
        """
    ]

    // MARK: - Run Script Template

    private static func generateRunScript() -> String {
        return """
        #!/bin/bash
        # swiftDialog Starter — Launch Script
        # Run: bash run.sh

        SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

        # Clean previous state
        defaults delete com.swiftdialog.preset5 2>/dev/null || true
        rm -f /var/tmp/dialog.log /var/tmp/dialog-inspect-trigger.txt

        # Launch
        dialog --inspect-config "$SCRIPT_DIR/config.json" --inspect-mode
        """
    }

    // MARK: - Generate Starter Project

    static func generateStarter(forPreset presetId: String) {
        guard let presetNum = Int(presetId),
              let template = templates[presetNum] else {
            writeLog("StarterTemplate: No template for preset '\(presetId)'", logLevel: .error)
            return
        }

        let presetName = presetNames[presetNum] ?? "unknown"
        let dirName = "swiftdialog-preset\(presetNum)"
        let desktopURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
            .appendingPathComponent(dirName)

        do {
            try FileManager.default.createDirectory(at: desktopURL, withIntermediateDirectories: true)

            let configURL = desktopURL.appendingPathComponent("config.json")
            if let jsonData = template.data(using: .utf8),
               var jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                // The relative "lang/*.json" paths resolve against iconBasePath.
                if presetNum == 7 {
                    jsonObject["iconBasePath"] = desktopURL.path
                }
                if let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) {
                    try prettyData.write(to: configURL)
                } else {
                    try template.write(to: configURL, atomically: true, encoding: .utf8)
                }
            } else {
                try template.write(to: configURL, atomically: true, encoding: .utf8)
            }

            if presetNum == 7 {
                let langDir = desktopURL.appendingPathComponent("lang")
                try FileManager.default.createDirectory(at: langDir, withIntermediateDirectories: true)
                for (code, contents) in guidedSetupLangFiles {
                    try contents.write(to: langDir.appendingPathComponent("\(code).json"),
                                       atomically: true, encoding: .utf8)
                }
            }

            let runURL = desktopURL.appendingPathComponent("run.sh")
            try generateRunScript().write(to: runURL, atomically: true, encoding: .utf8)

            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: runURL.path
            )

            let divider = String(repeating: "━", count: 66)
            let path = "~/Desktop/\(dirName)/"
            print("""

            \(divider)
              Starter Project Generated
            \(divider)

              ✓ Preset:  \(presetNum) (\(presetName))
              ✓ Path:    \(path)
              ✓ Files:   config.json, run.sh

              Launch it:
              → cd \(path) && bash run.sh

            \(divider)
            """)

            writeLog("StarterTemplate: Generated preset \(presetNum) at \(desktopURL.path)", logLevel: .info)

        } catch {
            writeLog("StarterTemplate: Failed to generate — \(error.localizedDescription)", logLevel: .error)
            writeLog("  ✗ Failed to generate starter: \(error.localizedDescription)", logLevel: .debug)
        }
    }
}
