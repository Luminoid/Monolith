import Foundation
import Testing
@testable import MonolithLib

/// Tests for the `WizardEngine` state-machine helpers, and for whole runs
/// answered by a `PromptScript`.
struct WizardEngineTests {
    // MARK: - Mock Step

    /// Minimal `WizardStep` that lets the test control `isVisible`. The
    /// `execute`/`summaryValue` paths are unused by the helper-level tests.
    private struct MockStep: WizardStep {
        let id: String
        let title: String
        let visible: (WizardState) -> Bool

        init(id: String, visible: @escaping (WizardState) -> Bool = { _ in true }) {
            self.id = id
            self.title = id.capitalized
            self.visible = visible
        }

        func isVisible(state: WizardState) -> Bool {
            visible(state)
        }

        func execute(state _: inout WizardState) -> WizardAction {
            .next
        }

        func summaryValue(state _: WizardState) -> String? {
            nil
        }
    }

    // MARK: - visibleCount

    @Test
    func `visibleCount returns total when all steps visible`() {
        let steps: [any WizardStep] = [
            MockStep(id: "a"),
            MockStep(id: "b"),
            MockStep(id: "c"),
        ]
        #expect(WizardEngine.visibleCount(steps: steps, state: WizardState()) == 3)
    }

    @Test
    func `visibleCount excludes hidden steps`() {
        let steps: [any WizardStep] = [
            MockStep(id: "a"),
            MockStep(id: "b", visible: { _ in false }),
            MockStep(id: "c"),
        ]
        #expect(WizardEngine.visibleCount(steps: steps, state: WizardState()) == 2)
    }

    @Test
    func `visibleCount reacts to state-dependent visibility`() {
        var state = WizardState()
        let steps: [any WizardStep] = [
            MockStep(id: "a"),
            MockStep(id: "tabs", visible: { $0.bool("wantTabs") == true }),
            MockStep(id: "c"),
        ]
        #expect(WizardEngine.visibleCount(steps: steps, state: state) == 2)
        state.values["wantTabs"] = true
        #expect(WizardEngine.visibleCount(steps: steps, state: state) == 3)
    }

    // MARK: - visibleIndex

    @Test
    func `visibleIndex is 1-based among visible siblings`() {
        let steps: [any WizardStep] = [
            MockStep(id: "a"),
            MockStep(id: "b"),
            MockStep(id: "c"),
        ]
        #expect(WizardEngine.visibleIndex(at: 0, steps: steps, state: WizardState()) == 1)
        #expect(WizardEngine.visibleIndex(at: 1, steps: steps, state: WizardState()) == 2)
        #expect(WizardEngine.visibleIndex(at: 2, steps: steps, state: WizardState()) == 3)
    }

    @Test
    func `visibleIndex skips hidden steps in its count`() {
        let steps: [any WizardStep] = [
            MockStep(id: "a"),
            MockStep(id: "hidden", visible: { _ in false }),
            MockStep(id: "c"),
        ]
        // At absolute index 2, only "a" and "c" are visible, so visible number is 2.
        #expect(WizardEngine.visibleIndex(at: 2, steps: steps, state: WizardState()) == 2)
    }

    // MARK: - previousVisibleIndex

    @Test
    func `previousVisibleIndex returns the prior visible absolute index`() {
        let steps: [any WizardStep] = [
            MockStep(id: "a"),
            MockStep(id: "b"),
            MockStep(id: "c"),
        ]
        #expect(WizardEngine.previousVisibleIndex(before: 2, steps: steps, state: WizardState()) == 1)
        #expect(WizardEngine.previousVisibleIndex(before: 1, steps: steps, state: WizardState()) == 0)
    }

    @Test
    func `previousVisibleIndex skips hidden steps`() {
        let steps: [any WizardStep] = [
            MockStep(id: "a"),
            MockStep(id: "hidden", visible: { _ in false }),
            MockStep(id: "c"),
        ]
        // Coming back from c (index 2) skips the hidden middle step.
        #expect(WizardEngine.previousVisibleIndex(before: 2, steps: steps, state: WizardState()) == 0)
    }

    @Test
    func `previousVisibleIndex returns input when at first visible step`() {
        let steps: [any WizardStep] = [
            MockStep(id: "a"),
            MockStep(id: "b"),
        ]
        // At absolute index 0, there is no prior visible step. The engine's
        // contract is to return the input (stay on current) rather than -1.
        #expect(WizardEngine.previousVisibleIndex(before: 0, steps: steps, state: WizardState()) == 0)
    }

    @Test
    func `previousVisibleIndex returns input when no prior step is visible`() {
        let steps: [any WizardStep] = [
            MockStep(id: "hidden1", visible: { _ in false }),
            MockStep(id: "hidden2", visible: { _ in false }),
            MockStep(id: "c"),
        ]
        // From c at index 2, scanning back finds no visible step — stays on c.
        #expect(WizardEngine.previousVisibleIndex(before: 2, steps: steps, state: WizardState()) == 2)
    }

    // MARK: - Steps a flag answered

    @Test
    func `fixed steps are skipped but count as answered`() {
        var state = WizardState()
        let steps: [any WizardStep] = [MockStep(id: "a"), MockStep(id: "b"), MockStep(id: "c")]
        state.fix("b", "from a flag")
        #expect(WizardEngine.visibleCount(steps: steps, state: state) == 2)
        #expect(WizardEngine.visibleIndex(at: 2, steps: steps, state: state) == 2)
        #expect(WizardEngine.previousVisibleIndex(before: 2, steps: steps, state: state) == 0)
    }

    // MARK: - Whole runs

    private var runSteps: [any WizardStep] {
        [
            StringStep(id: "name", title: "Name", prompt: "Name"),
            MultiSelectStep(id: "features", title: "Features", prompt: "Features", options: ["A", "B", "C"], preselected: { _ in [0] }),
            YesNoStep(id: "git", title: "Git", prompt: "Git?"),
        ]
    }

    /// Going back to a multi-select shows the earlier answer, and Enter keeps it.
    @Test
    func `back navigation keeps an earlier selection`() throws {
        var state = WizardState()
        let script = PromptScript(lines: ["Tool", "2,3", "<", "", "", ""])
        try PromptEngine.$script.withValue(script) {
            try WizardEngine.run(title: "Test", steps: runSteps, state: &state)
        }
        #expect(state.intSet("features") == [1, 2])
        #expect(state.bool("git") == true)
        #expect(script.questions.filter { $0 == "Features" }.count == 2)
    }

    /// "Proceed? n" goes through the steps again with every answer as the default.
    @Test
    func `declining the summary keeps the answers`() throws {
        var state = WizardState()
        let script = PromptScript(lines: ["Tool", "3", "n", "n", "", "", "", "y"])
        try PromptEngine.$script.withValue(script) {
            try WizardEngine.run(title: "Test", steps: runSteps, state: &state)
        }
        #expect(state.string("name") == "Tool")
        #expect(state.intSet("features") == [2])
        #expect(state.bool("git") == false)
        #expect(script.questions.filter { $0 == "Proceed?" }.count == 2)
    }

    @Test
    func `a step a flag answered is not asked and shows on the summary`() throws {
        var state = WizardState()
        state.fix("name", "FromFlag")
        let script = PromptScript(lines: ["", "", ""])
        try PromptEngine.$script.withValue(script) {
            try WizardEngine.run(title: "Test", steps: runSteps, state: &state)
        }
        #expect(!script.questions.contains("Name"))
        #expect(script.transcript.contains("Name      FromFlag"))
        #expect(state.intSet("features") == [0])
    }

    @Test
    func `the wizard stops when input ends`() {
        var state = WizardState()
        #expect(throws: PromptEngine.InputClosedError.self) {
            try PromptEngine.$script.withValue(PromptScript(lines: ["Tool"])) {
                try WizardEngine.run(title: "Test", steps: runSteps, state: &state)
            }
        }
    }
}
