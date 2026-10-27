//
//  RecipeComposerTests.swift
//  dialogTests
//
//  The recipe composer and the builder behind --inspect-new.
//

import XCTest
import SwiftUI
import AppKit
@testable import Dialog

// Recipes: a recipe plus a few answers is a working flow.
@MainActor
final class InspectRecipeComposerTests: XCTestCase {

    private let recipe = InspectRecipe(name: "toolkit", title: "Toolkit", summary: "", chooserStep: "pick",
                                       titleStep: "hello", defaultGradient: "g01",
                                       screens: ["check": "Review", "done": "Receipt"], folder: URL(fileURLWithPath: "/"))

    private var template: [String: Any] { get throws {
        try JSONSerialization.jsonObject(with: Data(#"""
        {"preset":"5","title":"Template","introSteps":[
          {"id":"hello","stepType":"intro","title":"Hi"},
          {"id":"pick","stepType":"options","optionMultiSelect":true,"optionKey":"tasks","optionCards":[
            {"id":"a","label":"A","category":"One","includes":["b","c"]},
            {"id":"b","label":"B","category":"One"},
            {"id":"c","label":"C","category":"Two","cancels":["category:One"]}]},
          {"id":"check","stepType":"review"},
          {"id":"run","stepType":"cadence"},
          {"id":"done","stepType":"outro","receipt":[{"stepId":"check","label":"x","selectionKey":"tasks"}]}]}
        """#.utf8)) as! [String: Any]
    } }

    func testAnswersShapeTheFlow() throws {
        let answers = InspectRecipeComposer.Answers(title: "Fix My Mac!", subtitle: "Pick fixes", gradient: "g09",
                                                    logoPath: "/tmp/logo.png", options: ["a", "b"], screens: ["done"])
        let out = InspectRecipeComposer.composeConfig(try template, recipe: recipe, answers: answers)
        XCTAssertEqual(out["title"] as? String, "Fix My Mac!")
        XCTAssertEqual(out["triggerFile"] as? String, "/tmp/fix-my-mac.trigger")
        XCTAssertEqual(out["phaseBackgroundPalette"] as? [String], ["preset:g09"])
        XCTAssertEqual(out["highlightColor"] as? String, GradientPresets.stops("preset:g09", dark: false)?.first)
        XCTAssertEqual((out["logoConfig"] as? [String: Any])?["imagePath"] as? String, "/tmp/logo.png")
        let steps = try XCTUnwrap(out["introSteps"] as? [[String: Any]])
        XCTAssertEqual(steps.map { $0["id"] as? String }, ["hello", "pick", "run", "done"], "the review was left out")
        XCTAssertEqual(steps[0]["title"] as? String, "Fix My Mac!")
        XCTAssertEqual(steps[0]["subtitle"] as? String, "Pick fixes")
        let cards = try XCTUnwrap(steps[1]["optionCards"] as? [[String: Any]])
        XCTAssertEqual(cards.map { $0["id"] as? String }, ["a", "b"])
        XCTAssertEqual(cards[0]["includes"] as? [String], ["b"], "a rule naming a dropped option loses it")
        XCTAssertEqual((steps[3]["receipt"] as? [[String: Any]])?.count, 0, "a receipt row for a dropped screen goes too")
    }

    func testEveryBundledRecipeComposesAndLintsWithoutErrors() throws {
        let all = InspectRecipeComposer.recipes()
        XCTAssertEqual(Set(all.map(\.name)), ["onboarding", "repair-toolkit", "self-service-picks",
                                              "deployment", "app-catalog", "quick-install"])
        for recipe in all {
            let files = try InspectRecipeComposer.compose(recipe: recipe, answers: .init(title: "Sample \(recipe.name)"))
            XCTAssertEqual(Set(files.keys), ["config.json", "run.sh", "README.md", "trail.json"])
            let script = try XCTUnwrap(String(bytes: XCTUnwrap(files["run.sh"]), encoding: .utf8))
            XCTAssertFalse(script.contains("__BUILT_WITH__"), "\(recipe.name): run.sh names the Dialog that built it")
            XCTAssertFalse(script.contains("python"), "\(recipe.name): run.sh needs only what every Mac ships")
            XCTAssertTrue(script.contains(Bundle.main.executablePath ?? "~"), recipe.name)
            let errors = InspectLint.lint(data: try XCTUnwrap(files["config.json"])).filter { $0.severity == .error }
            XCTAssertEqual(errors, [], "\(recipe.name): \(errors)")
        }
    }

    func testSlugsAreSafeNames() {
        XCTAssertEqual(InspectRecipeComposer.slug("Fix My Mac!"), "fix-my-mac")
        XCTAssertEqual(InspectRecipeComposer.slug("   "), "flow")
    }
}

// The builder is an inspect flow, generated from the recipes; its answers drive the composer.
@MainActor
final class InspectBuilderTests: XCTestCase {

    func testTheGeneratedBuilderIsACleanFlow() throws {
        let config = InspectRecipeComposer.builderConfig()
        let data = try JSONSerialization.data(withJSONObject: config)
        let errors = InspectLint.lint(data: data).filter { $0.severity == .error }
        XCTAssertEqual(errors, [], "\(errors)")
        let ids = (config["introSteps"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }
        XCTAssertEqual(ids.first, "recipe")
        XCTAssertTrue(ids.contains("options-repair-toolkit"), "a chooser recipe offers its own options")
        XCTAssertTrue(ids.contains("screens-onboarding"))
        XCTAssertFalse(ids.contains("options-onboarding"), "a recipe without a chooser has no options step")
        XCTAssertEqual(Array(ids.suffix(2)), ["save", "done"])
        // Content first: options → own apps → screens, then name & logo → look → save.
        let at = { (id: String) in ids.firstIndex(of: id) ?? -1 }
        XCTAssertLessThan(at("options-deployment"), at("add-apps-deployment"))
        XCTAssertLessThan(at("add-apps-deployment"), at("words"))
        XCTAssertLessThan(at("screens-repair-toolkit"), at("words"))
        XCTAssertLessThan(at("words"), at("look"))
        XCTAssertLessThan(at("look"), at("save"))
    }

    func testTheBuildersAnswersMapOntoTheComposer() {
        let values = ["builder.recipe": "repair-toolkit", "builder.look": "g05",
                      "builder.options.repair-toolkit": "clear_caches,reset_dock",
                      "builder.screens.repair-toolkit": "review,finish"]
        let fields = ["title": "Fix It", "folder": "~/Desktop/fix-it"]
        let read = InspectRecipeComposer.builderAnswers(userValues: values, text: { fields[$0] })
        XCTAssertEqual(read.recipe, "repair-toolkit")
        XCTAssertEqual(read.answers.title, "Fix It")
        XCTAssertEqual(read.answers.gradient, "g05")
        XCTAssertEqual(read.answers.options, ["clear_caches", "reset_dock"])
        XCTAssertEqual(read.answers.screens, ["review", "finish"])
        XCTAssertEqual(read.folder, "~/Desktop/fix-it")
        let darkOnly = InspectRecipeComposer.builderAnswers(userValues: values, text: { $0 == "logo" ? "\n/tmp/dark.png" : nil })
        XCTAssertNil(darkOnly.answers.logoPath, "the logo slots are positional")
        XCTAssertEqual(darkOnly.answers.logoDarkPath, "/tmp/dark.png")
    }
}


// Presets 1–3 as recipes: the options are the root items; the look is the preset's two colours.
@MainActor
final class ItemFlowRecipeTests: XCTestCase {

    func testAnItemFlowKeepsTheOfferedAppsInOrder() throws {
        let recipe = InspectRecipe(name: "deployment", title: "D", summary: "", chooserStep: nil, titleStep: nil,
                                   defaultGradient: "g01", screens: [:], folder: URL(fileURLWithPath: "/"),
                                   itemsChooser: true)
        let template = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(#"""
        {"preset":"1","title":"T","message":"M","items":[
          {"id":"a","displayName":"A","paths":["/a"],"guiIndex":0},
          {"id":"b","displayName":"B","paths":["/b"],"guiIndex":1},
          {"id":"c","displayName":"C","paths":["/c"],"guiIndex":2}]}
        """#.utf8)) as? [String: Any])
        let out = InspectRecipeComposer.composeConfig(template, recipe: recipe,
            answers: .init(title: "Apps", subtitle: "Installing your apps", gradient: "g09", options: ["c", "a"]))
        let items = try XCTUnwrap(out["items"] as? [[String: Any]])
        XCTAssertEqual(items.map { $0["id"] as? String }, ["a", "c"], "the recipe's order, not the tap order")
        XCTAssertEqual(items.map { $0["guiIndex"] as? Int }, [0, 1], "renumbered without gaps")
        XCTAssertEqual(out["message"] as? String, "Installing your apps")
        let stops = try XCTUnwrap(GradientPresets.stops("preset:g09", dark: false))
        XCTAssertEqual(out["highlightColor"] as? String, stops[0])
        XCTAssertEqual(out["secondaryColor"] as? String, stops[1])
        XCTAssertNil(out["phaseBackgroundPalette"], "an item flow has no phase backdrop")
    }

    func testTheBuilderOffersAnItemFlowsApps() {
        let ids = (InspectRecipeComposer.builderConfig()["introSteps"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }
        for name in ["deployment", "app-catalog", "quick-install"] {
            XCTAssertTrue(ids.contains("options-\(name)"), name)
        }
    }
}
