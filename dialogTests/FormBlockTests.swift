//
//  FormBlockTests.swift
//  dialogTests
//
//  Form blocks: drop zones, dropped apps and the colour picker.
//

import XCTest
import SwiftUI
import AppKit
@testable import Dialog


// The drop zone: what it accepts, and dropped apps joining a flow.
@MainActor
final class DropZoneTests: XCTestCase {

    func testItAcceptsWhatFileTypeSays() {
        let app = URL(fileURLWithPath: "/Applications/Safari.app")
        let png = URL(fileURLWithPath: "/tmp/logo.png")
        let txt = URL(fileURLWithPath: "/tmp/notes.txt")
        XCTAssertTrue(GuidanceDropZoneBlock<InspectState>.accepts(app, accepted: ["app"]))
        XCTAssertFalse(GuidanceDropZoneBlock<InspectState>.accepts(png, accepted: ["app"]))
        XCTAssertTrue(GuidanceDropZoneBlock<InspectState>.accepts(png, accepted: ["app", "image"]))
        XCTAssertFalse(GuidanceDropZoneBlock<InspectState>.accepts(txt, accepted: ["app", "image"]))
        XCTAssertEqual(GuidanceDropZoneBlock<InspectState>.hint(for: ["app"]), "Drop apps here, or click to choose")
    }

    func testDroppedAppsJoinAnItemFlowAndAChooser() throws {
        let itemRecipe = InspectRecipe(name: "deployment", title: "D", summary: "", chooserStep: nil, titleStep: nil,
                                       defaultGradient: nil, screens: [:], folder: URL(fileURLWithPath: "/"),
                                       itemsChooser: true, addApps: true)
        let items = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(#"""
        {"preset":"1","items":[{"id":"safari","displayName":"Safari","paths":["/a"]}]}
        """#.utf8)) as? [String: Any])
        var answers = InspectRecipeComposer.Answers()
        answers.extraApps = ["/Applications/Visual Studio Code.app", "/Applications/Safari.app"]
        let out = InspectRecipeComposer.composeConfig(items, recipe: itemRecipe, answers: answers)
        let ids = (out["items"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }
        XCTAssertEqual(ids, ["safari", "visual-studio-code"], "a dropped app already offered is not added twice")

        let chooserRecipe = InspectRecipe(name: "picks", title: "P", summary: "", chooserStep: "choose", titleStep: nil,
                                          defaultGradient: nil, screens: [:], folder: URL(fileURLWithPath: "/"), addApps: true)
        let steps = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(#"""
        {"preset":"5","introSteps":[{"id":"choose","stepType":"options","optionMultiSelect":true,"optionCards":[]}]}
        """#.utf8)) as? [String: Any])
        let picked = InspectRecipeComposer.composeConfig(steps, recipe: chooserRecipe, answers: answers)
        let card = try XCTUnwrap(((picked["introSteps"] as? [[String: Any]])?.first?["optionCards"] as? [[String: Any]])?.first)
        XCTAssertEqual(card["category"] as? String, "Added")
        XCTAssertEqual(card["iconPath"] as? String, "/Applications/Visual Studio Code.app")

        var notApps = InspectRecipeComposer.Answers()
        notApps.extraApps = ["/tmp/logo.png", "/tmp/readme.txt"]
        let unchanged = InspectRecipeComposer.composeConfig(items, recipe: itemRecipe, answers: notApps)
        XCTAssertEqual((unchanged["items"] as? [[String: Any]])?.count, 1, "only .app bundles join a flow as apps")
    }
}



// Dropped apps: several at once, what they say about themselves, and the trail.
@MainActor
final class DroppedAppsTests: XCTestCase {

    func testMultipleZonesCollectAndSingleZonesReplace() {
        XCTAssertEqual(GuidanceDropZoneBlock<InspectState>.merged(existing: ["/a.app"], dropped: ["/b.app", "/a.app", "/c.app"], multiple: true),
                       ["/a.app", "/b.app", "/c.app"], "several drops collect, no duplicates, drop order kept")
        XCTAssertEqual(GuidanceDropZoneBlock<InspectState>.merged(existing: ["/a.app"], dropped: ["/b.app", "/c.app"], multiple: false),
                       ["/c.app"], "a single zone holds the last one")
        XCTAssertEqual(GuidanceDropZoneBlock<InspectState>.merged(existing: ["/a.app"], dropped: [], multiple: false), ["/a.app"])
        XCTAssertEqual(GuidanceDropZoneBlock<InspectState>.merged(existing: ["/light.png"], dropped: ["/dark.png", "/extra.png"],
                                                                 multiple: true, limit: 2),
                       ["/light.png", "/dark.png"], "a limit keeps the first ones dropped")
    }

    func testAnAppSaysWhatItIs() throws {
        let info = try XCTUnwrap(AppBundleInfo.read("/System/Library/CoreServices/Finder.app"))
        XCTAssertEqual(info.bundleId, "com.apple.finder")
        XCTAssertEqual(info.name, "Finder")
        XCTAssertNotNil(info.version)
        XCTAssertNil(AppBundleInfo.read("/tmp/not-a-bundle-\(UUID().uuidString)"))
    }

    func testASignedThirdPartyAppNamesItsTeam() throws {
        // Apple's own apps carry no Team ID; a Developer ID app does. Skipped where none is installed.
        let candidates = ["/Applications/Microsoft Teams.app", "/Applications/Microsoft Outlook.app",
                          "/Applications/Slack.app", "/Applications/Google Chrome.app"]
        guard let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            throw XCTSkip("no signed third-party app installed")
        }
        let info = try XCTUnwrap(AppBundleInfo.read(path))
        XCTAssertNotNil(info.teamId, "\(path) is Developer-ID signed")
        XCTAssertEqual(info.teamId?.count, 10, "a Team ID is ten characters")
    }

    func testADroppedAppIsDetectedByBundleIdAndRecordedInTheTrail() throws {
        let recipe = InspectRecipe(name: "deployment", title: "D", summary: "", chooserStep: nil, titleStep: nil,
                                   defaultGradient: nil, screens: [:], folder: URL(fileURLWithPath: "/"),
                                   itemsChooser: true, addApps: true)
        var answers = InspectRecipeComposer.Answers(title: "Apps")
        answers.extraApps = ["/System/Library/CoreServices/Finder.app"]
        let template: [String: Any] = ["preset": "1", "items": [[String: Any]]()]
        let out = InspectRecipeComposer.composeConfig(template, recipe: recipe, answers: answers)
        let item = try XCTUnwrap((out["items"] as? [[String: Any]])?.first)
        XCTAssertEqual(((item["requirements"] as? [[String: Any]])?.first)?["bundleId"] as? String, "com.apple.finder")
        XCTAssertNotNil(item["version"])

        let trail = try JSONSerialization.jsonObject(with: InspectRecipeComposer.trail(recipe: recipe, answers: answers)) as? [String: Any]
        XCTAssertEqual(trail?["recipe"] as? String, "deployment")
        XCTAssertEqual(((trail?["apps"] as? [[String: Any]])?.first)?["bundleId"] as? String, "com.apple.finder")
        XCTAssertEqual((trail?["answers"] as? [String: Any])?["title"] as? String, "Apps")
    }
}


// The colour picker: any colour, stored as hex; the builder's "your own colour" wins over a gradient.
@MainActor
final class ColorPickerTests: XCTestCase {

    func testAColourIsStoredAsHex() {
        XCTAssertEqual(GuidanceColorPickerBlock<InspectState>.hexString(Color(hex: "#6A67FE")), "#6A67FE")
    }

    func testYourOwnColourWinsOverAGradient() throws {
        let values = ["builder.recipe": "deployment", "builder.look": "custom"]
        let read = InspectRecipeComposer.builderAnswers(userValues: values, text: { $0 == "accent" ? "#6A67FE" : nil })
        XCTAssertNil(read.answers.gradient)
        XCTAssertEqual(read.answers.accentColor, "#6A67FE")

        let step = InspectRecipe(name: "s", title: "S", summary: "", chooserStep: nil, titleStep: nil, defaultGradient: "g09",
                                 screens: [:], folder: URL(fileURLWithPath: "/"))
        let flow = InspectRecipeComposer.composeConfig(["preset": "5", "introSteps": [[String: Any]]()], recipe: step, answers: read.answers)
        XCTAssertEqual(flow["highlightColor"] as? String, "#6A67FE")
        XCTAssertEqual(flow["phaseBackgroundPalette"] as? [String], ["#6A67FE"])

        let items = InspectRecipe(name: "i", title: "I", summary: "", chooserStep: nil, titleStep: nil, defaultGradient: "g09",
                                  screens: [:], folder: URL(fileURLWithPath: "/"), itemsChooser: true)
        let itemFlow = InspectRecipeComposer.composeConfig(["preset": "1", "items": [[String: Any]]()], recipe: items, answers: read.answers)
        XCTAssertEqual(itemFlow["highlightColor"] as? String, "#6A67FE")
        XCTAssertNil(itemFlow["phaseBackgroundPalette"])
    }

    func testTheBuilderOffersAColourScreenOnlyForYourOwnColour() {
        let steps = InspectRecipeComposer.builderConfig()["introSteps"] as? [[String: Any]] ?? []
        let ids = steps.compactMap { $0["id"] as? String }
        XCTAssertEqual(ids.firstIndex(of: "colour"), (ids.firstIndex(of: "look") ?? -2) + 1, "right after the look")
        let colour = steps.first { $0["id"] as? String == "colour" }
        XCTAssertEqual((colour?["showWhen"] as? [String: Any])?["anyOf"] as? [String], ["custom"])
    }
}
