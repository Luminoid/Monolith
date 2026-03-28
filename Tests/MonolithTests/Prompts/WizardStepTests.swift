import Foundation
import Testing
@testable import MonolithLib

struct WizardStateTests {
    @Test
    func `string accessor returns stored string`() {
        var state = WizardState()
        state.values["name"] = "MyApp"
        #expect(state.string("name") == "MyApp")
    }

    @Test
    func `string accessor returns nil for missing key`() {
        let state = WizardState()
        #expect(state.string("name") == nil)
    }

    @Test
    func `string accessor returns nil for wrong type`() {
        var state = WizardState()
        state.values["name"] = 42
        #expect(state.string("name") == nil)
    }

    @Test
    func `bool accessor returns stored bool`() {
        var state = WizardState()
        state.values["flag"] = true
        #expect(state.bool("flag") == true)
    }

    @Test
    func `bool accessor returns nil for missing key`() {
        let state = WizardState()
        #expect(state.bool("flag") == nil)
    }

    @Test
    func `int accessor returns stored int`() {
        var state = WizardState()
        state.values["index"] = 2
        #expect(state.int("index") == 2)
    }

    @Test
    func `int accessor returns nil for missing key`() {
        let state = WizardState()
        #expect(state.int("index") == nil)
    }

    @Test
    func `int accessor returns nil for wrong type`() {
        var state = WizardState()
        state.values["index"] = "two"
        #expect(state.int("index") == nil)
    }

    @Test
    func `intSet accessor returns stored set`() {
        var state = WizardState()
        state.values["features"] = Set<Int>([0, 2, 4])
        #expect(state.intSet("features") == [0, 2, 4])
    }

    @Test
    func `tabDefinitions accessor returns stored tabs`() {
        var state = WizardState()
        let tabs = [TabDefinition(name: "Home", icon: "house")]
        state.values["tabs"] = tabs
        #expect(state.tabDefinitions("tabs")?.count == 1)
        #expect(state.tabDefinitions("tabs")?[0].name == "Home")
    }

    @Test
    func `stringArray accessor returns stored array`() {
        var state = WizardState()
        state.values["items"] = ["a", "b", "c"]
        #expect(state.stringArray("items") == ["a", "b", "c"])
    }

    @Test
    func `targetDefinitions accessor returns stored targets`() {
        var state = WizardState()
        let targets = [TargetDefinition(name: "Core", dependencies: ["Foundation"])]
        state.values["targets"] = targets
        #expect(state.targetDefinitions("targets")?.count == 1)
        #expect(state.targetDefinitions("targets")?[0].name == "Core")
    }

    @Test
    func `platformVersions accessor returns stored platform versions`() {
        var state = WizardState()
        let pvs = [PlatformVersion(platform: "iOS", version: "18.0")]
        state.values["platforms"] = pvs
        #expect(state.platformVersions("platforms")?.count == 1)
        #expect(state.platformVersions("platforms")?[0].platform == "iOS")
    }

    @Test
    func `platformVersions accessor returns nil for missing key`() {
        let state = WizardState()
        #expect(state.platformVersions("platforms") == nil)
    }
}

struct WizardStepVisibilityTests {
    @Test
    func `YesNoStep always visible by default`() {
        let step = YesNoStep(id: "test", title: "Test", prompt: "Test?")
        let state = WizardState()
        #expect(step.isVisible(state: state))
    }

    @Test
    func `StringStep with visibility closure hides when condition false`() {
        let step = StringStep(
            id: "author",
            title: "Author",
            prompt: "Author name",
            isVisible: { $0.string("author") == nil }
        )
        var state = WizardState()
        state.values["author"] = "John"
        #expect(!step.isVisible(state: state))
    }

    @Test
    func `StringStep with visibility closure shows when condition true`() {
        let step = StringStep(
            id: "author",
            title: "Author",
            prompt: "Author name",
            isVisible: { $0.string("author") == nil }
        )
        let state = WizardState()
        #expect(step.isVisible(state: state))
    }

    @Test
    func `MultiSelectStep always visible by default`() {
        let step = MultiSelectStep(
            id: "features",
            title: "Features",
            prompt: "Select features",
            options: ["A", "B", "C"]
        )
        let state = WizardState()
        #expect(step.isVisible(state: state))
    }

    @Test
    func `CustomStep visibility respects closure`() {
        let step = CustomStep(
            id: "deps",
            title: "Dependencies",
            isVisible: { state in
                let count = (state.string("targets") ?? "").split(separator: ",").count
                return count > 1
            },
            execute: { _ in .next },
            summaryValue: { _ in nil }
        )

        var state = WizardState()
        state.values["targets"] = "Core"
        #expect(!step.isVisible(state: state))

        state.values["targets"] = "Core, UI"
        #expect(step.isVisible(state: state))
    }

    @Test
    func `SingleSelectStep always visible by default`() {
        let step = SingleSelectStep(
            id: "system",
            title: "System",
            prompt: "Select",
            options: ["A", "B"]
        )
        let state = WizardState()
        #expect(step.isVisible(state: state))
    }

    @Test
    func `SingleSelectStep visibility respects closure`() {
        let step = SingleSelectStep(
            id: "system",
            title: "System",
            prompt: "Select",
            options: ["A"],
            isVisible: { $0.bool("show") == true }
        )
        var state = WizardState()
        #expect(!step.isVisible(state: state))
        state.values["show"] = true
        #expect(step.isVisible(state: state))
    }

    @Test
    func `TabsStep visibility respects closure`() {
        let step = TabsStep(
            id: "tabs",
            title: "Tabs",
            prompt: "Enter tabs",
            isVisible: { $0.bool("wantTabs") == true }
        )

        var state = WizardState()
        #expect(!step.isVisible(state: state))

        state.values["wantTabs"] = true
        #expect(step.isVisible(state: state))

        state.values["wantTabs"] = false
        #expect(!step.isVisible(state: state))
    }
}

struct WizardStepSummaryTests {
    @Test
    func `StringStep summary returns stored value`() {
        let step = StringStep(id: "name", title: "Name", prompt: "Name")
        var state = WizardState()
        state.values["name"] = "MyApp"
        #expect(step.summaryValue(state: state) == "MyApp")
    }

    @Test
    func `StringStep summary returns nil for missing value`() {
        let step = StringStep(id: "name", title: "Name", prompt: "Name")
        let state = WizardState()
        #expect(step.summaryValue(state: state) == nil)
    }

    @Test
    func `YesNoStep summary returns Yes/No`() {
        let step = YesNoStep(id: "flag", title: "Flag", prompt: "Enable?")
        var state = WizardState()

        state.values["flag"] = true
        #expect(step.summaryValue(state: state) == "Yes")

        state.values["flag"] = false
        #expect(step.summaryValue(state: state) == "No")
    }

    @Test
    func `YesNoStep summary returns nil for missing value`() {
        let step = YesNoStep(id: "flag", title: "Flag", prompt: "Enable?")
        let state = WizardState()
        #expect(step.summaryValue(state: state) == nil)
    }

    @Test
    func `MultiSelectStep summary returns selected option names`() {
        let step = MultiSelectStep(
            id: "features",
            title: "Features",
            prompt: "Select",
            options: ["Alpha", "Beta", "Gamma"]
        )
        var state = WizardState()
        state.values["features"] = Set<Int>([0, 2])
        #expect(step.summaryValue(state: state) == "Alpha, Gamma")
    }

    @Test
    func `MultiSelectStep summary returns None for empty selection`() {
        let step = MultiSelectStep(
            id: "features",
            title: "Features",
            prompt: "Select",
            options: ["Alpha", "Beta"]
        )
        var state = WizardState()
        state.values["features"] = Set<Int>()
        #expect(step.summaryValue(state: state) == "None")
    }

    @Test
    func `MultiSelectStep summary returns nil for missing value`() {
        let step = MultiSelectStep(
            id: "features",
            title: "Features",
            prompt: "Select",
            options: ["Alpha"]
        )
        let state = WizardState()
        #expect(step.summaryValue(state: state) == nil)
    }

    @Test
    func `SingleSelectStep summary returns selected option name`() {
        let step = SingleSelectStep(
            id: "system",
            title: "Project system",
            prompt: "Select",
            options: ["SPM", "XcodeGen"]
        )
        var state = WizardState()
        state.values["system"] = 0
        #expect(step.summaryValue(state: state) == "SPM")

        state.values["system"] = 1
        #expect(step.summaryValue(state: state) == "XcodeGen")
    }

    @Test
    func `SingleSelectStep summary returns nil for missing value`() {
        let step = SingleSelectStep(
            id: "system",
            title: "System",
            prompt: "Select",
            options: ["A", "B"]
        )
        #expect(step.summaryValue(state: WizardState()) == nil)
    }

    @Test
    func `SingleSelectStep summary returns nil for out-of-range index`() {
        let step = SingleSelectStep(
            id: "system",
            title: "System",
            prompt: "Select",
            options: ["A", "B"]
        )
        var state = WizardState()
        state.values["system"] = 5
        #expect(step.summaryValue(state: state) == nil)
    }

    @Test
    func `TabsStep summary formats tabs correctly`() {
        let step = TabsStep(id: "tabs", title: "Tabs", prompt: "Enter tabs")
        var state = WizardState()
        state.values["tabs"] = [
            TabDefinition(name: "Home", icon: "house"),
            TabDefinition(name: "Settings", icon: "gearshape"),
        ]
        #expect(step.summaryValue(state: state) == "Home:house, Settings:gearshape")
    }

    @Test
    func `TabsStep summary returns None for empty tabs`() {
        let step = TabsStep(id: "tabs", title: "Tabs", prompt: "Enter tabs")
        var state = WizardState()
        state.values["tabs"] = [TabDefinition]()
        #expect(step.summaryValue(state: state) == "None")
    }

    @Test
    func `CustomStep summary uses provided closure`() {
        let step = CustomStep(
            id: "custom",
            title: "Custom",
            execute: { _ in .next },
            summaryValue: { state in
                state.string("custom").map { "Value: \($0)" }
            }
        )
        var state = WizardState()
        state.values["custom"] = "test"
        #expect(step.summaryValue(state: state) == "Value: test")
    }
}

struct WizardStepDefaultTests {
    @Test
    func `ValidatedStringStep resolves static default`() {
        let step = ValidatedStringStep(
            id: "target",
            title: "Target",
            prompt: "Deployment target",
            staticDefault: "18.0",
            validator: { _ in true }
        )
        #expect(step.summaryValue(state: WizardState()) == nil)
    }

    @Test
    func `YesNoStep uses provided default value`() {
        let stepTrue = YesNoStep(id: "a", title: "A", prompt: "?", defaultValue: true)
        #expect(stepTrue.defaultValue == true)

        let stepFalse = YesNoStep(id: "b", title: "B", prompt: "?", defaultValue: false)
        #expect(stepFalse.defaultValue == false)
    }

    @Test
    func `StringStep stores staticDefault`() {
        let step = StringStep(
            id: "author",
            title: "Author",
            prompt: "Author name",
            staticDefault: "Author"
        )
        #expect(step.staticDefault == "Author")
    }

    @Test
    func `SingleSelectStep stores default index`() {
        let step = SingleSelectStep(
            id: "system",
            title: "System",
            prompt: "Select",
            options: ["SPM", "XcodeGen"],
            defaultIndex: 1
        )
        #expect(step.defaultIndex == 1)
    }

    @Test
    func `ValidatedStringStep stores dynamic default closure`() {
        let step = ValidatedStringStep(
            id: "bundleID",
            title: "Bundle ID",
            prompt: "Bundle ID",
            defaultValue: { state in
                "com.example.\(state.string("name") ?? "app")"
            },
            validator: { _ in true }
        )

        var state = WizardState()
        state.values["name"] = "MyApp"
        let resolved = step.defaultValue?(state)
        #expect(resolved == "com.example.MyApp")
    }
}

struct WizardEngineHelperTests {
    @Test
    func `PromptEngine.isBackCommand recognizes back commands`() {
        #expect(PromptEngine.isBackCommand("<"))
        #expect(PromptEngine.isBackCommand("back"))
        #expect(PromptEngine.isBackCommand("  back  "))
        #expect(PromptEngine.isBackCommand("BACK"))
        #expect(PromptEngine.isBackCommand("  <  "))
    }

    @Test
    func `PromptEngine.isBackCommand rejects non-back input`() {
        #expect(!PromptEngine.isBackCommand(""))
        #expect(!PromptEngine.isBackCommand("next"))
        #expect(!PromptEngine.isBackCommand("yes"))
        #expect(!PromptEngine.isBackCommand("backward"))
        #expect(!PromptEngine.isBackCommand("<<"))
    }
}
