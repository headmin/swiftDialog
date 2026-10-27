//
//  InspectRecipeComposer.swift
//  dialog
//
//  Turns a recipe from `Recipes/` plus a few answers into a flow folder (`config.json`, `run.sh`,
//  `README.md`). Used by the builder flow (`"compose"` button action) and `--inspect-new`.
//

import AppKit

struct InspectRecipe: Equatable {
    let name: String
    let title: String
    let summary: String
    let chooserStep: String?
    let titleStep: String?
    let defaultGradient: String?
    /// Screen step id → its human name, for the screens a person may leave out.
    let screens: [String: String]
    let folder: URL
    /// An item flow (Presets 1–3): the options are the root `items` rather than a chooser step's cards.
    var itemsChooser: Bool = false
    /// The builder offers a drop zone for the author's own apps (`Answers.extraApps`).
    var addApps: Bool = false
}

enum InspectRecipeComposer {

    struct Answers: Equatable, Codable {
        var title: String?
        var subtitle: String?
        /// A gradient preset id, "g01"…"g14".
        var gradient: String?
        /// The author's own colour ("#RRGGBB"); wins over `gradient`.
        var accentColor: String?
        var logoPath: String?
        /// The logo for the dark appearance (`logoConfig.imagePathDark`).
        var logoDarkPath: String?
        /// The chooser's options to offer, by id; nil offers them all.
        var options: [String]?
        /// The optional screens to keep, by step id; nil keeps them all.
        var screens: Set<String>?
        /// Apps the author dropped in (paths to .app bundles), added to what the flow offers.
        var extraApps: [String]?
    }

    /// A dropped app as an id and name: "/Applications/Example App.app" → ("example-app", "Example App").
    /// The name is the bundle's file name as Finder shows it.
    static func appIdentity(_ path: String) -> (id: String, name: String) {
        let name = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        return (slug(name), name)
    }

    // MARK: - The recipes

    static var recipesFolder: URL? {
        Bundle.main.url(forResource: "Recipes", withExtension: nil)
    }

    static func recipes(in folder: URL? = recipesFolder) -> [InspectRecipe] {
        guard let folder,
              let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return [] }
        return names.sorted().compactMap { recipe(at: folder.appendingPathComponent($0)) }
    }

    static func recipe(at folder: URL) -> InspectRecipe? {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("recipe.json")),
              let meta = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = meta["name"] as? String else { return nil }
        return InspectRecipe(name: name, title: meta["title"] as? String ?? name,
                             summary: meta["summary"] as? String ?? "",
                             chooserStep: meta["chooserStep"] as? String,
                             titleStep: meta["titleStep"] as? String,
                             defaultGradient: meta["defaultGradient"] as? String,
                             screens: meta["screens"] as? [String: String] ?? [:],
                             folder: folder,
                             itemsChooser: meta["itemsChooser"] as? Bool ?? false,
                             addApps: meta["addApps"] as? Bool ?? false)
    }

    // MARK: - Composing

    /// A file-system-safe name for the flow: its IPC paths and default folder.
    static func slug(_ title: String) -> String {
        let lowered = title.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" }
        let collapsed = String(lowered).split(separator: "-").joined(separator: "-")
        return collapsed.isEmpty ? "flow" : collapsed
    }

    /// The recipe's config with the answers applied. Pure, so tests drive it directly.
    static func composeConfig(_ template: [String: Any], recipe: InspectRecipe, answers: Answers) -> [String: Any] {
        var config = template
        let title = answers.title?.trimmingCharacters(in: .whitespaces).nilIfEmpty
        let slug = slug(title ?? recipe.name)
        config["triggerFile"] = "/tmp/\(slug).trigger"
        config["readinessFile"] = "/tmp/\(slug).ready"
        config["eventFile"] = "/tmp/\(slug).events.jsonl"
        config["resultFile"] = "/tmp/\(slug).result.json"
        if let title { config["title"] = title }
        let isStepFlow = config["introSteps"] != nil
        // Only app bundles are added; answers may also come from a script or a hand-written trail.
        let extraApps = (answers.extraApps ?? []).filter { $0.lowercased().hasSuffix(".app") }

        // The author's colour, else a gradient preset, tints the backdrop and sets the accent. Item flows
        // (Presets 1–3) have no phase backdrop and take the colours only.
        if let hex = answers.accentColor?.trimmingCharacters(in: .whitespaces).nilIfEmpty, hex.hasPrefix("#") {
            if isStepFlow {
                if (config["phaseBackground"] as? String) != "splash" { config["phaseBackground"] = "gradient" }
                config["phaseBackgroundPalette"] = [hex]
            } else {
                config["secondaryColor"] = hex
            }
            config["highlightColor"] = hex
        } else if let id = answers.gradient ?? recipe.defaultGradient,
           let stops = GradientPresets.stops(GradientPresets.prefix + id, dark: false) {
            if isStepFlow {
                if (config["phaseBackground"] as? String) != "splash" { config["phaseBackground"] = "gradient" }
                config["phaseBackgroundPalette"] = [GradientPresets.prefix + id]
            } else if stops.count > 1 {
                config["secondaryColor"] = stops[1]
            }
            config["highlightColor"] = stops.first
        }
        // An item flow's subtitle is its root message.
        if !isStepFlow, let subtitle = answers.subtitle?.trimmingCharacters(in: .whitespaces).nilIfEmpty {
            config["message"] = subtitle
        }
        // Offered apps in recipe order, renumbered so `guiIndex` stays sequential.
        if recipe.itemsChooser, var items = config["items"] as? [[String: Any]] {
            if let offered = answers.options {
                let keep = Set(offered)
                items = items.filter { keep.contains($0["id"] as? String ?? "") }
            }
            let present = Set(items.compactMap { $0["id"] as? String })
            for path in extraApps {
                let app = appIdentity(path)
                guard !present.contains(app.id) else { continue }
                var item: [String: Any] = ["id": app.id, "displayName": app.name, "icon": path, "paths": [path],
                                           "showBundleInfo": "all"]
                // The bundle id finds the app wherever it is installed.
                if let info = AppBundleInfo.read(path) {
                    if let bundleId = info.bundleId { item["requirements"] = [["type": "app", "bundleId": bundleId]] }
                    if let version = info.version { item["version"] = version }
                }
                items.append(item)
            }
            config["items"] = items.enumerated().map { index, item in
                var item = item; item["guiIndex"] = index; return item
            }
        }
        // A lone dark logo serves both appearances.
        if let logo = (answers.logoPath ?? answers.logoDarkPath)?.trimmingCharacters(in: .whitespaces).nilIfEmpty {
            var logoConfig: [String: Any] = ["imagePath": logo, "maxHeight": 20, "position": "footer"]
            if let dark = answers.logoDarkPath?.trimmingCharacters(in: .whitespaces).nilIfEmpty {
                logoConfig["imagePathDark"] = dark
            }
            config["logoConfig"] = logoConfig
        }

        var steps = config["introSteps"] as? [[String: Any]] ?? []
        // Remove left-out screens and any receipt rows pointing at them.
        if let keep = answers.screens {
            let dropped = Set(recipe.screens.keys).subtracting(keep)
            steps.removeAll { dropped.contains($0["id"] as? String ?? "") }
            steps = steps.map { step in
                guard var rows = step["receipt"] as? [[String: Any]] else { return step }
                rows.removeAll { dropped.contains($0["stepId"] as? String ?? "") }
                var out = step; out["receipt"] = rows; return out
            }
        }
        steps = steps.map { step in
            var step = step
            let id = step["id"] as? String
            if id == recipe.titleStep {
                if let title { step["title"] = title }
                if let subtitle = answers.subtitle?.trimmingCharacters(in: .whitespaces).nilIfEmpty {
                    step["subtitle"] = subtitle
                }
            }
            // Offered options in recipe order; rules keep only what is still offered (category selectors stay).
            if id == recipe.chooserStep, let offered = answers.options,
               let cards = step["optionCards"] as? [[String: Any]] {
                let keep = Set(offered)
                step["optionCards"] = cards.filter { keep.contains($0["id"] as? String ?? "") }.map { card in
                    var card = card
                    for field in ["includes", "cancels"] {
                        guard let refs = card[field] as? [String] else { continue }
                        let pruned = refs.filter { $0.hasPrefix(OptionPlan.categoryPrefix) || keep.contains($0) }
                        card[field] = pruned.isEmpty ? nil : pruned
                    }
                    return card
                }
            }
            // Dropped apps join a chooser as their own section, switched on.
            if id == recipe.chooserStep, !extraApps.isEmpty,
               var cards = step["optionCards"] as? [[String: Any]] {
                let present = Set(cards.compactMap { $0["id"] as? String })
                for path in extraApps {
                    let app = appIdentity(path)
                    guard !present.contains(app.id) else { continue }
                    let summary = AppBundleInfo.read(path)?.summary ?? ""
                    cards.append(["id": app.id, "label": app.name,
                                  "subtitle": summary.isEmpty ? "Added by IT" : summary,
                                  "category": "Added", "iconPath": path, "sfSymbol": "app", "recommended": true])
                }
                step["optionCards"] = cards
            }
            return step
        }
        // Only step flows get `introSteps`: alongside `items` the loader rejects it.
        if isStepFlow { config["introSteps"] = steps }
        return config
    }

    /// The three files of a composed flow.
    static func compose(recipe: InspectRecipe, answers: Answers) throws -> [String: Data] {
        let templateData = try Data(contentsOf: recipe.folder.appendingPathComponent("config.json"))
        guard let template = try JSONSerialization.jsonObject(with: templateData) as? [String: Any] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let config = composeConfig(template, recipe: recipe, answers: answers)
        let json = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        // run.sh uses the Dialog binary that built the folder unless SD_DIALOG_BIN points elsewhere.
        let scriptText = try String(contentsOf: recipe.folder.appendingPathComponent("run.sh"), encoding: .utf8)
            .replacingOccurrences(of: "__BUILT_WITH__", with: Bundle.main.executablePath ?? "")
        let script = Data(scriptText.utf8)
        var files = ["config.json": json, "run.sh": script,
                     "README.md": Data(readme(recipe: recipe, config: config).utf8),
                     "trail.json": try trail(recipe: recipe, answers: answers)]
        let apps = (answers.extraApps ?? []).compactMap(AppBundleInfo.read)
        if !apps.isEmpty {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            files["apps.json"] = try encoder.encode(apps)
        }
        return files
    }

    /// How the folder was made: recipe, answers, dropped app details, time and Dialog version.
    static func trail(recipe: InspectRecipe, answers: Answers, at date: Date = Date()) throws -> Data {
        struct Trail: Encodable {
            let createdAt: String
            let dialogVersion: String
            let recipe: String
            let answers: Answers
            let apps: [AppBundleInfo]
        }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let record = Trail(createdAt: ISO8601DateFormatter().string(from: date), dialogVersion: version,
                           recipe: recipe.name, answers: answers,
                           apps: (answers.extraApps ?? []).compactMap(AppBundleInfo.read))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(record)
    }

    /// Writes the composed flow into `folder` (created if needed) and makes `run.sh` executable.
    @discardableResult
    static func write(recipe: InspectRecipe, answers: Answers, to folder: URL) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (name, data) in try compose(recipe: recipe, answers: answers) {
            let url = folder.appendingPathComponent(name)
            try data.write(to: url)
            if name.hasSuffix(".sh") {
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            }
        }
        return folder
    }

    /// `--inspect-new <recipe> [folder]` writes a flow and lints it; `--inspect-new list` lists the recipes.
    @MainActor
    static func runCommandLine(arguments: [String]) -> Int32 {
        guard let flag = arguments.firstIndex(of: "--inspect-new"), arguments.indices.contains(flag + 1) else {
            print("usage: dialog --inspect-new <recipe> [folder]   |   dialog --inspect-new list")
            return 2
        }
        let name = arguments[flag + 1]
        let all = recipes()
        if name == "builder" { return launchBuilder() }
        if name == "list" {
            for recipe in all { print("\(recipe.name.padding(toLength: 20, withPad: " ", startingAt: 0)) \(recipe.summary)") }
            return 0
        }
        guard let recipe = all.first(where: { $0.name == name }) else {
            print("no recipe '\(name)'; the recipes are \(all.map(\.name).joined(separator: ", "))")
            return 2
        }
        let answers = Answers()
        let folder = arguments.indices.contains(flag + 2) && !arguments[flag + 2].hasPrefix("--")
            ? URL(fileURLWithPath: (arguments[flag + 2] as NSString).expandingTildeInPath)
            : defaultFolder(for: answers, recipe: recipe)
        do {
            try write(recipe: recipe, answers: answers, to: folder)
        } catch {
            print("could not write \(folder.path): \(error.localizedDescription)")
            return 1
        }
        print("wrote \(folder.path)  —  run it with \(folder.path)/run.sh")
        let configData = (try? Data(contentsOf: folder.appendingPathComponent("config.json"))) ?? Data()
        let errors = InspectLint.lint(data: configData).filter { $0.severity == .error }
        for finding in errors { print("error: \(finding.path) \(finding.message)") }
        return errors.isEmpty ? 0 : 1
    }

    // MARK: - The builder: an inspect flow that builds inspect flows

    /// The builder's config, generated from the recipes so its options match the recipes' own cards and items.
    /// Order: what to build, options/apps, own apps, screens, name and logo, look, save, done.
    static func builderConfig(recipes: [InspectRecipe] = recipes()) -> [String: Any] {
        var steps: [[String: Any]] = []
        steps.append(["id": "recipe", "stepType": "options", "optionKey": "builder.recipe", "optionLayout": "rows",
                      "title": "What are you building?", "subtitle": "Start from a recipe; everything can be changed later.",
                      "optionCards": recipes.map { ["id": $0.name, "label": $0.title, "subtitle": $0.summary] },
                      "continueButtonText": "Continue"])

        // Per recipe: what it offers, the author's own apps, the screens it shows.
        for recipe in recipes {
            let only: [String: Any] = ["key": "builder.recipe", "anyOf": [recipe.name]]
            if recipe.itemsChooser, let items = templateItems(of: recipe) {
                steps.append(["id": "options-\(recipe.name)", "stepType": "options", "optionMultiSelect": true,
                              "optionKey": "builder.options.\(recipe.name)", "optionLayout": "rows", "optionControl": "switch",
                              "showWhen": only, "title": "Which apps should it watch?",
                              "subtitle": "Each one ticks off when it lands on the Mac. You can add your own next.",
                              "optionCards": items.map { item -> [String: Any] in
                                var card: [String: Any] = ["id": item["id"] as? String ?? "",
                                                           "label": item["displayName"] as? String ?? "",
                                                           "sfSymbol": "app", "recommended": true]
                                if let icon = item["icon"] as? String { card["iconPath"] = icon }
                                if let path = (item["paths"] as? [String])?.first { card["subtitle"] = path }
                                return card
                              },
                              "continueButtonText": "Continue"])
            }
            if let chooser = recipe.chooserStep, let cards = chooserCards(of: recipe, step: chooser) {
                steps.append(["id": "options-\(recipe.name)", "stepType": "options", "optionMultiSelect": true,
                              "optionKey": "builder.options.\(recipe.name)", "optionLayout": "rows", "optionControl": "switch",
                              "showWhen": only, "title": "Which options should it offer?",
                              "subtitle": "Switch off what your Macs don't need. Rules between options come with them.",
                              "optionCards": cards.map { var c = $0; c["recommended"] = true; return c },
                              "continueButtonText": "Continue"])
            }
            if recipe.addApps {
                steps.append(["id": "add-apps-\(recipe.name)", "stepType": "guide", "showWhen": only,
                              "title": "Add your own apps",
                              "subtitle": "Drop as many apps as you like — together or one by one. Each joins the flow with its icon and bundle id. Optional.",
                              "content": [["type": "drop-zone", "id": "extraApps", "content": "Apps",
                                           "fileType": "app", "multiple": true]],
                              "continueButtonText": "Continue"])
            }
            if !recipe.screens.isEmpty {
                steps.append(["id": "screens-\(recipe.name)", "stepType": "options", "optionMultiSelect": true,
                              "optionKey": "builder.screens.\(recipe.name)", "optionLayout": "rows", "optionControl": "switch",
                              "showWhen": only, "title": "Which screens should it show?",
                              "subtitle": "The recipe's core screens always stay.",
                              "optionCards": recipe.screens.sorted { $0.key < $1.key }.map {
                                ["id": $0.key, "label": $0.value, "sfSymbol": "rectangle.on.rectangle", "recommended": true]
                              },
                              "continueButtonText": "Continue"])
            }
        }

        // Identity: name, logo, look.
        steps.append(["id": "words", "stepType": "guide", "title": "Name it and add your logo",
                      "subtitle": "The title opens the flow. Leave a field empty to keep the recipe's words.",
                      "content": [
                        ["type": "textfield", "id": "title", "content": "Title", "placeholder": "e.g. Repair & Reset"],
                        ["type": "textfield", "id": "subtitle", "content": "One line under the title", "placeholder": "Optional"],
                        ["type": "drop-zone", "id": "logo", "style": "logo", "content": "Logo (optional)",
                         "fileType": "app image", "multiple": true, "limit": 2]],
                      "continueButtonText": "Continue"])
        steps.append(["id": "look", "stepType": "options", "optionKey": "builder.look", "optionLayout": "rows",
                      "title": "Pick a look", "subtitle": "The backdrop and the accent come from one gradient.",
                      "optionCards": GradientPresets.all.enumerated().map { index, preset in
                        ["id": preset.id, "label": "Gradient \(index + 1)", "subtitle": preset.colors.joined(separator: " → "),
                         "preview": GradientSwatch.prefix + preset.id, "recommended": preset.id == "g09"] as [String: Any]
                      } + [["id": "custom", "label": "Your own colour", "subtitle": "Pick any colour on the next screen",
                            "preview": GradientSwatch.prefix + "custom"]],
                      "continueButtonText": "Continue"])
        steps.append(["id": "colour", "stepType": "guide", "showWhen": ["key": "builder.look", "anyOf": ["custom"]],
                      "title": "Pick your colour",
                      "subtitle": "It colours the buttons, the progress and the backdrop wash.",
                      "content": [["type": "color-picker", "id": "accent", "content": "Accent colour", "value": "#0A84FF"]],
                      "continueButtonText": "Continue"])

        steps.append(["id": "save", "stepType": "guide", "title": "Save it",
                      "subtitle": "Create my flow writes it to a folder, opens it in Finder and starts a preview.",
                      "content": [
                        ["type": "textfield", "id": "folder", "content": "Folder", "placeholder": "~/Desktop/<title>"]],
                      // Continue creates the folder; there is no way past this screen without it.
                      "continueAction": "compose", "continueButtonText": "Create my flow"])
        steps.append(["id": "done", "stepType": "outro", "title": "Your flow is ready",
                      "subtitle": "Edit config.json in the folder, check it with dialog --inspect-lint config.json, and run it with run.sh.",
                      "heroImage": "SF=checkmark.seal.fill", "heroImageSize": 44, "continueButtonText": "Done", "phase": "outro"])
        return ["preset": "5", "chrome": "provisioning", "width": 820, "height": 640,
                "title": "Flow builder", "highlightColor": "#0A84FF",
                "triggerFile": "/tmp/inspect-builder.trigger", "readinessFile": "/tmp/inspect-builder.ready",
                "eventFile": "/tmp/inspect-builder.events.jsonl", "resultFile": "/tmp/inspect-builder.result.json",
                "introSteps": steps]
    }

    private static func templateItems(of recipe: InspectRecipe) -> [[String: Any]]? {
        guard let data = try? Data(contentsOf: recipe.folder.appendingPathComponent("config.json")),
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return config["items"] as? [[String: Any]]
    }

    private static func chooserCards(of recipe: InspectRecipe, step: String) -> [[String: Any]]? {
        guard let data = try? Data(contentsOf: recipe.folder.appendingPathComponent("config.json")),
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let steps = config["introSteps"] as? [[String: Any]],
              let chooser = steps.first(where: { $0["id"] as? String == step }) else { return nil }
        return chooser["optionCards"] as? [[String: Any]]
    }

    /// The builder's answers: picks from `userValues`, words from the text fields.
    static func builderAnswers(userValues: [String: String], text: (String) -> String?) -> (recipe: String?, answers: Answers, folder: String?) {
        let recipe = userValues["builder.recipe"]
        let split = { (key: String) in userValues[key].map { $0.split(separator: ",").map(String.init) } }
        // The logo zone stores two slots by position: "light\ndark" (either may be empty).
        let logos = text("logo")?.components(separatedBy: "\n") ?? []
        var answers = Answers(title: text("title"), subtitle: text("subtitle"), gradient: userValues["builder.look"],
                              logoPath: logos.first.flatMap { $0.isEmpty ? nil : $0 })
        answers.logoDarkPath = logos.dropFirst().first.flatMap { $0.isEmpty ? nil : $0 }
        if userValues["builder.look"] == "custom" {
            answers.gradient = nil
            answers.accentColor = text("accent") ?? "#0A84FF"
        }
        answers.extraApps = text("extraApps")?.split(separator: "\n").map(String.init)
        if let recipe {
            answers.options = split("builder.options.\(recipe)")
            answers.screens = split("builder.screens.\(recipe)").map(Set.init)
        }
        return (recipe, answers, text("folder"))
    }

    /// The builder's Create button (`"compose"`): writes the folder, opens it and starts a preview.
    static func composeFromBuilder(userValues: [String: String], formInputs: [String: GuidanceFormInputState]) {
        let text = { (field: String) -> String? in
            formInputs.values.lazy.compactMap { $0.textfields[field] }
                .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        }
        let read = builderAnswers(userValues: userValues, text: text)
        guard let name = read.recipe, let recipe = recipes().first(where: { $0.name == name }) else {
            writeLog("Builder: no recipe picked", logLevel: .error)
            return
        }
        let folder = read.folder.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
            ?? defaultFolder(for: read.answers, recipe: recipe)
        do {
            try write(recipe: recipe, answers: read.answers, to: folder)
            writeLog("Builder: wrote \(folder.path)", logLevel: .info)
        } catch {
            writeLog("Builder: could not write \(folder.path): \(error)", logLevel: .error)
            return
        }
        NSWorkspace.shared.open(folder)
        let preview = Process()
        preview.executableURL = URL(fileURLWithPath: "/bin/zsh")
        preview.arguments = [folder.appendingPathComponent("run.sh").path]
        var env = ProcessInfo.processInfo.environment
        env["SD_DIALOG_BIN"] = Bundle.main.executablePath
        preview.environment = env
        try? preview.run()
    }

    /// Starts the builder in its own window with a freshly generated config.
    static func launchBuilder() -> Int32 {
        let path = NSTemporaryDirectory() + "inspect-builder.json"
        guard let data = try? JSONSerialization.data(withJSONObject: builderConfig(), options: [.prettyPrinted]),
              (try? data.write(to: URL(fileURLWithPath: path))) != nil,
              let executable = Bundle.main.executableURL else { return 1 }
        let builder = Process()
        builder.executableURL = executable
        builder.arguments = ["--inspect-mode", "--inspect-config", path]
        do { try builder.run() } catch { return 1 }
        print("builder: started (config \(path))")
        return 0
    }

    /// The default folder for a flow: `~/Desktop/<slug>`.
    static func defaultFolder(for answers: Answers, recipe: InspectRecipe) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
            .appendingPathComponent(slug(answers.title ?? recipe.name))
    }

    private static func readme(recipe: InspectRecipe, config: [String: Any]) -> String {
        let title = config["title"] as? String ?? recipe.title
        return """
        # \(title)

        Made from the **\(recipe.title)** recipe: \(recipe.summary)

        ## Run it

            ./run.sh

        ## Change it

        Everything is in `config.json`. Check it after every edit:

            dialog --inspect-lint config.json

        Each finding names the place and what is wrong. Put `"watch": true` at the top of the
        config to see edits in the open window as you save.

        ## Do the real work

        `run.sh` marks the one place your own script goes (`do_work`, where there is one). The
        dialog shows the progress; your script reports each piece done with one line:

            cadence:satisfy:<id>
        """
    }
}
