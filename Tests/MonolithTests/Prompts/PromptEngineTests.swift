import ArgumentParser
import Foundation
import Testing
@testable import MonolithLib

/// `PromptEngine`'s prompts, answered by a `PromptScript` in place of the
/// terminal. The raw-mode key handling is `LineEditorTests`.
struct PromptEngineTests {
    /// Runs `body` with `script` answering the prompts.
    private func answering<T>(_ script: PromptScript, _ body: () throws -> T) rethrows -> T {
        try PromptEngine.$script.withValue(script, operation: body)
    }

    // MARK: - End of input

    /// Regression: end of input read as an empty answer, so a validated
    /// prompt asked again forever (`new cli < /dev/null` printed "Try again"
    /// at ~30 MB/s).
    @Test
    func `end of input throws instead of asking again`() {
        let script = PromptScript(lines: [])
        answering(script) {
            #expect(throws: PromptEngine.InputClosedError.self) {
                try PromptEngine.wizardValidatedString(prompt: "Name", validator: { !$0.isEmpty })
            }
            #expect(throws: PromptEngine.InputClosedError.self) { try PromptEngine.wizardYesNo(prompt: "Sure?") }
            #expect(throws: PromptEngine.InputClosedError.self) { try PromptEngine.askYesNo(prompt: "Proceed?") }
        }
        #expect(script.questions.count == 3)
        #expect(PromptEngine.InputClosedError().description == "stdin closed; pass --no-interactive")
    }

    @Test
    func `Ctrl-C cancels with exit code 130`() {
        answering(PromptScript(lines: [PromptScript.interrupt])) {
            let error = #expect(throws: ExitCode.self) { try PromptEngine.wizardString(prompt: "Name") }
            #expect(error?.rawValue == 130)
        }
    }

    // MARK: - Back navigation

    @Test
    func `only the angle bracket goes back`() {
        #expect(PromptEngine.isBackCommand("<"))
        #expect(PromptEngine.isBackCommand("  <  "))
        #expect(!PromptEngine.isBackCommand("back"))
        #expect(!PromptEngine.isBackCommand("Back"))
        #expect(!PromptEngine.isBackCommand(""))
        #expect(!PromptEngine.isBackCommand("<<"))
    }

    /// Regression: typing "back" always went back, so an app couldn't be named "Back".
    @Test
    func `back is an answer like any other word`() throws {
        try answering(PromptScript(lines: ["Back", "<"])) {
            guard case let .value(name) = try PromptEngine.wizardString(prompt: "App name") else {
                Issue.record("'Back' went back")
                return
            }
            #expect(name == "Back")
            guard case .back = try PromptEngine.wizardString(prompt: "App name") else {
                Issue.record("'<' didn't go back")
                return
            }
        }
    }

    // MARK: - Yes/No

    @Test
    func `yes-no answers`() {
        #expect(PromptEngine.yesNo("", default: true) == true)
        #expect(PromptEngine.yesNo("", default: false) == false)
        #expect(PromptEngine.yesNo("Y", default: false) == true)
        #expect(PromptEngine.yesNo("no", default: true) == false)
        #expect(PromptEngine.yesNo("maybe", default: true) == nil)
    }

    @Test
    func `an unclear yes-no answer asks again`() throws {
        let script = PromptScript(lines: ["sure", "n"])
        let answer = try answering(script) { try PromptEngine.askYesNo(prompt: "Proceed?") }
        #expect(answer == false)
        #expect(script.transcript.contains("Answer y or n."))
    }

    // MARK: - Multi-select

    @Test
    func `Enter keeps the marked options`() throws {
        let script = PromptScript(lines: [""])
        let result = try answering(script) {
            try PromptEngine.wizardMultiSelect(prompt: "Features", options: ["A", "B", "C"], current: [0, 2])
        }
        guard case let .value(selection) = result else {
            Issue.record("went back")
            return
        }
        #expect(selection == [0, 2])
        #expect(script.transcript.contains("1. [x] A"))
        #expect(script.transcript.contains("2. [ ] B"))
    }

    @Test
    func `an invalid selection asks again`() throws {
        let script = PromptScript(lines: ["1,9", "two", "2"])
        let result = try answering(script) {
            try PromptEngine.wizardMultiSelect(prompt: "Features", options: ["A", "B", "C"])
        }
        guard case let .value(selection) = result else {
            Issue.record("went back")
            return
        }
        #expect(selection == [1])
        #expect(script.transcript.contains("'9' is not an option"))
        #expect(script.transcript.contains("'two' is not an option"))
    }

    @Test
    func `selection parsing`() throws {
        let parse = { (input: String, current: Set<Int>, allowsEmpty: Bool) in
            PromptEngine.parseSelection(input, current: current, optionCount: 5, allowsEmpty: allowsEmpty)
        }
        #expect(try parse("", [1], true).get() == [1])
        #expect(try parse("1,3 5", [1], true).get() == [0, 2, 4])
        #expect(try parse("+4,-2", [1, 2], true).get() == [2, 3])
        #expect(try parse("none", [1], true).get() == [])
        #expect(try parse("NONE", [], true).get() == [])
        #expect(throws: PromptEngine.SelectionProblem.self) { try parse("none", [1], false).get() }
        #expect(throws: PromptEngine.SelectionProblem.self) { try parse("", [], false).get() }
        #expect(throws: PromptEngine.SelectionProblem.self) { try parse("-1", [0], false).get() }
        #expect(throws: PromptEngine.SelectionProblem.self) { try parse("0", [], true).get() }
        #expect(throws: PromptEngine.SelectionProblem.self) { try parse("6", [], true).get() }
    }

    // MARK: - Single select

    /// Regression: an out-of-range or non-numeric answer silently took the default.
    @Test
    func `an invalid choice asks again`() throws {
        let script = PromptScript(lines: ["9", "x", "2"])
        let result = try answering(script) {
            try PromptEngine.wizardSelect(prompt: "System", options: ["A", "B"], default: 0)
        }
        guard case let .value(index) = result else {
            Issue.record("went back")
            return
        }
        #expect(index == 1)
        #expect(script.transcript.components(separatedBy: "Enter a number from 1 to 2.").count - 1 == 2)
    }

    // MARK: - Tabs

    /// Tabs parse like `--tabs`: a malformed entry asks again instead of
    /// being dropped.
    @Test
    func `a malformed tab asks again`() throws {
        let script = PromptScript(lines: ["Home:house,NoIcon", "Home:house, Settings:gearshape"])
        let result = try answering(script) { try PromptEngine.wizardTabs(prompt: "Tabs") }
        guard case let .value(tabs) = result else {
            Issue.record("went back")
            return
        }
        #expect(tabs.map(\.name) == ["Home", "Settings"])
        #expect(tabs.map(\.icon) == ["house", "gearshape"])
        #expect(script.transcript.contains("Invalid --tabs entry 'NoIcon'"))
    }

    @Test
    func `Enter keeps the current tabs`() throws {
        let current = [TabDefinition(name: "Home", icon: "house")]
        let result = try answering(PromptScript(lines: [""])) { try PromptEngine.wizardTabs(prompt: "Tabs", current: current) }
        guard case let .value(tabs) = result else {
            Issue.record("went back")
            return
        }
        #expect(tabs.map(\.name) == ["Home"])
    }

    // MARK: - Terminal check

    @Test
    func `a script counts as a terminal and the override wins`() {
        PromptEngine.$script.withValue(PromptScript(lines: [])) {
            #expect(PromptEngine.isInteractiveTerminal)
            PromptEngine.$terminalOverride.withValue(false) {
                #expect(!PromptEngine.isInteractiveTerminal)
            }
        }
    }
}
