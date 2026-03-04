import Foundation
import Testing
@testable import MonolithLib

@Suite("WizardState")
struct WizardStateTests {
    @Test("string accessor returns stored string")
    func stringAccessor() {
        var state = WizardState()
        state.values["name"] = "MyApp"
        #expect(state.string("name") == "MyApp")
    }

    @Test("string accessor returns nil for missing key")
    func stringMissing() {
        let state = WizardState()
        #expect(state.string("name") == nil)
    }

    @Test("string accessor returns nil for wrong type")
    func stringWrongType() {
        var state = WizardState()
        state.values["name"] = 42
        #expect(state.string("name") == nil)
    }

    @Test("bool accessor returns stored bool")
    func boolAccessor() {
        var state = WizardState()
        state.values["flag"] = true
        #expect(state.bool("flag") == true)
    }

    @Test("bool accessor returns nil for missing key")
    func boolMissing() {
        let state = WizardState()
        #expect(state.bool("flag") == nil)
    }

    @Test("int accessor returns stored int")
    func intAccessor() {
        var state = WizardState()
        state.values["index"] = 2
        #expect(state.int("index") == 2)
    }

    @Test("int accessor returns nil for missing key")
    func intMissing() {
        let state = WizardState()
        #expect(state.int("index") == nil)
    }

    @Test("int accessor returns nil for wrong type")
    func intWrongType() {
        var state = WizardState()
        state.values["index"] = "two"
        #expect(state.int("index") == nil)
    }

    @Test("intSet accessor returns stored set")
    func intSetAccessor() {
        var state = WizardState()
        state.values["features"] = Set<Int>([0, 2, 4])
        #expect(state.intSet("features") == [0, 2, 4])
    }

    @Test("tabDefinitions accessor returns stored tabs")
    func tabDefinitionsAccessor() {
        var state = WizardState()
        let tabs = [TabDefinition(name: "Home", icon: "house")]
        state.values["tabs"] = tabs
        #expect(state.tabDefinitions("tabs")?.count == 1)
        #expect(state.tabDefinitions("tabs")?[0].name == "Home")
    }

    @Test("stringArray accessor returns stored array")
    func stringArrayAccessor() {
        var state = WizardState()
        state.values["items"] = ["a", "b", "c"]
        #expect(state.stringArray("items") == ["a", "b", "c"])
    }

    @Test("targetDefinitions accessor returns stored targets")
    func targetDefinitionsAccessor() {
        var state = WizardState()
        let targets = [TargetDefinition(name: "Core", dependencies: ["Foundation"])]
        state.values["targets"] = targets
        #expect(state.targetDefinitions("targets")?.count == 1)
        #expect(state.targetDefinitions("targets")?[0].name == "Core")
    }

    @Test("platformVersions accessor returns stored platform versions")
    func platformVersionsAccessor() {
        var state = WizardState()
        let pvs = [PlatformVersion(platform: "iOS", version: "18.0")]
        state.values["platforms"] = pvs
        #expect(state.platformVersions("platforms")?.count == 1)
        #expect(state.platformVersions("platforms")?[0].platform == "iOS")
    }

    @Test("platformVersions accessor returns nil for missing key")
    func platformVersionsMissing() {
        let state = WizardState()
        #expect(state.platformVersions("platforms") == nil)
    }
}

@Suite("WizardStep Visibility")
struct WizardStepVisibilityTests {
    @Test("YesNoStep always visible by default")
    func yesNoAlwaysVisible() {
        let step = YesNoStep(id: "test", title: "Test", prompt: "Test?")
        let state = WizardState()
        #expect(step.isVisible(state: state))
    }

    @Test("StringStep with visibility closure hides when condition false")
    func stringStepHidden() {
        let step = StringStep(
            id: "author",
            title: "Author",
            prompt: "Author name",
            isVisible: { $0.string("author") == nil },
        )
        var state = WizardState()
        state.values["author"] = "John"
        #expect(!step.isVisible(state: state))
    }

    @Test("StringStep with visibility closure shows when condition true")
    func stringStepVisible() {
        let step = StringStep(
            id: "author",
            title: "Author",
            prompt: "Author name",
            isVisible: { $0.string("author") == nil },
        )
        let state = WizardState()
        #expect(step.isVisible(state: state))
    }

    @Test("MultiSelectStep always visible by default")
    func multiSelectAlwaysVisible() {
        let step = MultiSelectStep(
            id: "features",
            title: "Features",
            prompt: "Select features",
            options: ["A", "B", "C"],
        )
        let state = WizardState()
        #expect(step.isVisible(state: state))
    }

    @Test("CustomStep visibility respects closure")
    func customStepVisibility() {
        let step = CustomStep(
            id: "deps",
            title: "Dependencies",
            isVisible: { state in
                let count = (state.string("targets") ?? "").split(separator: ",").count
                return count > 1
            },
            execute: { _ in .next },
            summaryValue: { _ in nil },
        )

        var state = WizardState()
        state.values["targets"] = "Core"
        #expect(!step.isVisible(state: state))

        state.values["targets"] = "Core, UI"
        #expect(step.isVisible(state: state))
    }

    @Test("SingleSelectStep always visible by default")
    func singleSelectAlwaysVisible() {
        let step = SingleSelectStep(
            id: "system",
            title: "System",
            prompt: "Select",
            options: ["A", "B"],
        )
        let state = WizardState()
        #expect(step.isVisible(state: state))
    }

    @Test("SingleSelectStep visibility respects closure")
    func singleSelectVisibility() {
        let step = SingleSelectStep(
            id: "system",
            title: "System",
            prompt: "Select",
            options: ["A"],
            isVisible: { $0.bool("show") == true },
        )
        var state = WizardState()
        #expect(!step.isVisible(state: state))
        state.values["show"] = true
        #expect(step.isVisible(state: state))
    }

    @Test("TabsStep visibility respects closure")
    func tabsStepVisibility() {
        let step = TabsStep(
            id: "tabs",
            title: "Tabs",
            prompt: "Enter tabs",
            isVisible: { $0.bool("wantTabs") == true },
        )

        var state = WizardState()
        #expect(!step.isVisible(state: state))

        state.values["wantTabs"] = true
        #expect(step.isVisible(state: state))

        state.values["wantTabs"] = false
        #expect(!step.isVisible(state: state))
    }
}

@Suite("WizardStep Summary Values")
struct WizardStepSummaryTests {
    @Test("StringStep summary returns stored value")
    func stringSummary() {
        let step = StringStep(id: "name", title: "Name", prompt: "Name")
        var state = WizardState()
        state.values["name"] = "MyApp"
        #expect(step.summaryValue(state: state) == "MyApp")
    }

    @Test("StringStep summary returns nil for missing value")
    func stringSummaryNil() {
        let step = StringStep(id: "name", title: "Name", prompt: "Name")
        let state = WizardState()
        #expect(step.summaryValue(state: state) == nil)
    }

    @Test("YesNoStep summary returns Yes/No")
    func yesNoSummary() {
        let step = YesNoStep(id: "flag", title: "Flag", prompt: "Enable?")
        var state = WizardState()

        state.values["flag"] = true
        #expect(step.summaryValue(state: state) == "Yes")

        state.values["flag"] = false
        #expect(step.summaryValue(state: state) == "No")
    }

    @Test("YesNoStep summary returns nil for missing value")
    func yesNoSummaryNil() {
        let step = YesNoStep(id: "flag", title: "Flag", prompt: "Enable?")
        let state = WizardState()
        #expect(step.summaryValue(state: state) == nil)
    }

    @Test("MultiSelectStep summary returns selected option names")
    func multiSelectSummary() {
        let step = MultiSelectStep(
            id: "features",
            title: "Features",
            prompt: "Select",
            options: ["Alpha", "Beta", "Gamma"],
        )
        var state = WizardState()
        state.values["features"] = Set<Int>([0, 2])
        #expect(step.summaryValue(state: state) == "Alpha, Gamma")
    }

    @Test("MultiSelectStep summary returns None for empty selection")
    func multiSelectSummaryNone() {
        let step = MultiSelectStep(
            id: "features",
            title: "Features",
            prompt: "Select",
            options: ["Alpha", "Beta"],
        )
        var state = WizardState()
        state.values["features"] = Set<Int>()
        #expect(step.summaryValue(state: state) == "None")
    }

    @Test("MultiSelectStep summary returns nil for missing value")
    func multiSelectSummaryNil() {
        let step = MultiSelectStep(
            id: "features",
            title: "Features",
            prompt: "Select",
            options: ["Alpha"],
        )
        let state = WizardState()
        #expect(step.summaryValue(state: state) == nil)
    }

    @Test("SingleSelectStep summary returns selected option name")
    func singleSelectSummary() {
        let step = SingleSelectStep(
            id: "system",
            title: "Project system",
            prompt: "Select",
            options: ["SPM", "XcodeGen"],
        )
        var state = WizardState()
        state.values["system"] = 0
        #expect(step.summaryValue(state: state) == "SPM")

        state.values["system"] = 1
        #expect(step.summaryValue(state: state) == "XcodeGen")
    }

    @Test("SingleSelectStep summary returns nil for missing value")
    func singleSelectSummaryNil() {
        let step = SingleSelectStep(
            id: "system",
            title: "System",
            prompt: "Select",
            options: ["A", "B"],
        )
        #expect(step.summaryValue(state: WizardState()) == nil)
    }

    @Test("SingleSelectStep summary returns nil for out-of-range index")
    func singleSelectSummaryOutOfRange() {
        let step = SingleSelectStep(
            id: "system",
            title: "System",
            prompt: "Select",
            options: ["A", "B"],
        )
        var state = WizardState()
        state.values["system"] = 5
        #expect(step.summaryValue(state: state) == nil)
    }

    @Test("TabsStep summary formats tabs correctly")
    func tabsSummary() {
        let step = TabsStep(id: "tabs", title: "Tabs", prompt: "Enter tabs")
        var state = WizardState()
        state.values["tabs"] = [
            TabDefinition(name: "Home", icon: "house"),
            TabDefinition(name: "Settings", icon: "gearshape"),
        ]
        #expect(step.summaryValue(state: state) == "Home:house, Settings:gearshape")
    }

    @Test("TabsStep summary returns None for empty tabs")
    func tabsSummaryNone() {
        let step = TabsStep(id: "tabs", title: "Tabs", prompt: "Enter tabs")
        var state = WizardState()
        state.values["tabs"] = [TabDefinition]()
        #expect(step.summaryValue(state: state) == "None")
    }

    @Test("CustomStep summary uses provided closure")
    func customSummary() {
        let step = CustomStep(
            id: "custom",
            title: "Custom",
            execute: { _ in .next },
            summaryValue: { state in
                state.string("custom").map { "Value: \($0)" }
            },
        )
        var state = WizardState()
        state.values["custom"] = "test"
        #expect(step.summaryValue(state: state) == "Value: test")
    }
}

@Suite("WizardStep Defaults")
struct WizardStepDefaultTests {
    @Test("ValidatedStringStep resolves static default")
    func validatedStringStaticDefault() {
        let step = ValidatedStringStep(
            id: "target",
            title: "Target",
            prompt: "Deployment target",
            staticDefault: "18.0",
            validator: { _ in true },
        )
        #expect(step.summaryValue(state: WizardState()) == nil)
    }

    @Test("YesNoStep uses provided default value")
    func yesNoDefault() {
        let stepTrue = YesNoStep(id: "a", title: "A", prompt: "?", defaultValue: true)
        #expect(stepTrue.defaultValue == true)

        let stepFalse = YesNoStep(id: "b", title: "B", prompt: "?", defaultValue: false)
        #expect(stepFalse.defaultValue == false)
    }

    @Test("StringStep stores staticDefault")
    func stringStaticDefault() {
        let step = StringStep(
            id: "author",
            title: "Author",
            prompt: "Author name",
            staticDefault: "Author",
        )
        #expect(step.staticDefault == "Author")
    }

    @Test("SingleSelectStep stores default index")
    func singleSelectDefaultIndex() {
        let step = SingleSelectStep(
            id: "system",
            title: "System",
            prompt: "Select",
            options: ["SPM", "XcodeGen"],
            defaultIndex: 1,
        )
        #expect(step.defaultIndex == 1)
    }

    @Test("ValidatedStringStep stores dynamic default closure")
    func validatedStringDynamicDefault() {
        let step = ValidatedStringStep(
            id: "bundleID",
            title: "Bundle ID",
            prompt: "Bundle ID",
            defaultValue: { state in
                "com.example.\(state.string("name") ?? "app")"
            },
            validator: { _ in true },
        )

        var state = WizardState()
        state.values["name"] = "MyApp"
        let resolved = step.defaultValue?(state)
        #expect(resolved == "com.example.MyApp")
    }
}

@Suite("WizardEngine Helpers")
struct WizardEngineHelperTests {
    @Test("PromptEngine.isBackCommand recognizes back commands")
    func backCommands() {
        #expect(PromptEngine.isBackCommand("<"))
        #expect(PromptEngine.isBackCommand("back"))
        #expect(PromptEngine.isBackCommand("  back  "))
        #expect(PromptEngine.isBackCommand("BACK"))
        #expect(PromptEngine.isBackCommand("  <  "))
    }

    @Test("PromptEngine.isBackCommand rejects non-back input")
    func notBackCommands() {
        #expect(!PromptEngine.isBackCommand(""))
        #expect(!PromptEngine.isBackCommand("next"))
        #expect(!PromptEngine.isBackCommand("yes"))
        #expect(!PromptEngine.isBackCommand("backward"))
        #expect(!PromptEngine.isBackCommand("<<"))
    }
}
