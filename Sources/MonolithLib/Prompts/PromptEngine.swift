import ArgumentParser
import CEditLine
import Foundation

/// Reads the answers to the wizard and the overwrite prompt.
///
/// Wizard prompts read in raw terminal mode through `LineEditor` (arrow
/// keys, UTF-8 text, the up arrow as "back"); yes/no prompts read through
/// editline. Every prompt fails instead of looping when input ends: a
/// closed stdin throws `InputClosedError`, and Ctrl-C cancels with exit 130.
/// A `PromptScript` stands in for the terminal in tests.
enum PromptEngine {
    /// Standard input ended while a prompt was waiting.
    struct InputClosedError: Error, CustomStringConvertible {
        var description: String {
            "stdin closed; pass --no-interactive"
        }
    }

    /// Result of a wizard prompt: a value, or a back-navigation request.
    enum WizardInput<T> {
        case value(T)
        case back
    }

    /// What one read produced.
    enum Read: Equatable {
        case line(String)
        /// The up arrow (raw mode only).
        case back
        /// Ctrl-C or Ctrl-D.
        case interrupt
        case endOfInput
    }

    // MARK: - Input Source

    /// Answers prompts in place of the terminal. Tests set it with `$script.withValue`.
    @TaskLocal static var script: PromptScript?

    /// Overrides the terminal check. Tests set it with `$terminalOverride.withValue`.
    @TaskLocal static var terminalOverride: Bool?

    /// Whether the up arrow and `<` go back. `WizardEngine` sets it for each
    /// step: every step but the first allows it.
    @TaskLocal static var isBackEnabled = true

    /// Whether prompts can be answered: stdin is a terminal, or a script answers them.
    static var isInteractiveTerminal: Bool {
        if let terminalOverride { return terminalOverride }
        return script != nil || isatty(STDIN_FILENO) != 0
    }

    // MARK: - Output

    /// Prompt output: stdout, or the script's transcript in tests.
    static func write(_ text: String) {
        if let script {
            script.record(text)
        } else {
            print(text, terminator: "")
        }
    }

    /// `write` plus a newline.
    static func line(_ text: String = "") {
        write(text + "\n")
    }

    /// Clear the terminal screen. A script records nothing.
    static func clearScreen() {
        guard script == nil else { return }
        print("\u{1B}[2J\u{1B}[H", terminator: "")
    }

    // MARK: - Reading

    /// Reads one wizard answer: trimmed text, or `nil` for back (`<` or the
    /// up arrow). `question` names the prompt for a script.
    private static func wizardAnswer(prompt: String, question: String) throws -> String? {
        let read = if let script {
            script.read(question: question, prompt: prompt)
        } else {
            readRawLine(prompt: prompt)
        }
        switch read {
        case let .line(text):
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            return isBackCommand(trimmed) ? nil : trimmed
        case .back:
            return nil
        case .interrupt:
            try cancel()
        case .endOfInput:
            throw InputClosedError()
        }
    }

    /// Reads one line through editline, for the yes/no prompts.
    private static func cookedAnswer(prompt: String, question: String) throws -> String {
        let read: Read
        if let script {
            read = script.read(question: question, prompt: prompt)
        } else if isatty(STDIN_FILENO) == 0 {
            print(prompt, terminator: "")
            fflush(stdout)
            read = readLine().map(Read.line) ?? .endOfInput
        } else if let cString = readline(prompt) {
            defer { free(cString) }
            read = .line(String(cString: cString))
        } else {
            read = .endOfInput
        }
        switch read {
        case let .line(text):
            return text.trimmingCharacters(in: .whitespaces)
        case .back:
            return "<"
        case .interrupt:
            try cancel()
        case .endOfInput:
            throw InputClosedError()
        }
    }

    /// Ctrl-C at a raw-mode prompt. The terminal is already restored. Raise a
    /// real SIGINT, whose default action ends the process with 130; if
    /// SIGINT is ignored, or a script answered, exit 130 through ArgumentParser.
    private static func cancel() throws -> Never {
        if script == nil {
            raise(SIGINT)
        }
        throw ExitCode(130)
    }

    /// Read a line in raw terminal mode: typing, Backspace, Delete, Home,
    /// End, left/right, the up arrow as back, Ctrl-C/Ctrl-D to cancel.
    private static func readRawLine(prompt: String) -> Read {
        print(prompt, terminator: "")
        fflush(stdout)

        var saved = termios()
        guard tcgetattr(STDIN_FILENO, &saved) == 0 else {
            return readLine().map(Read.line) ?? .endOfInput
        }
        var raw = saved
        raw.c_lflag &= ~tcflag_t(ICANON | ECHO | ISIG)
        raw.c_iflag &= ~tcflag_t(IXON)
        withUnsafeMutablePointer(to: &raw.c_cc) { pointer in
            pointer.withMemoryRebound(to: cc_t.self, capacity: Int(NCCS)) { cc in
                cc[Int(VMIN)] = 1
                cc[Int(VTIME)] = 0
            }
        }
        // TCSANOW, not TCSAFLUSH: flushing would drop pasted type-ahead.
        tcsetattr(STDIN_FILENO, TCSANOW, &raw)
        defer {
            tcsetattr(STDIN_FILENO, TCSANOW, &saved)
            print()
        }

        var editor = LineEditor(backEnabled: isBackEnabled)
        while true {
            var byte: UInt8 = 0
            let count = Darwin.read(STDIN_FILENO, &byte, 1)
            if count < 0, errno == EINTR { continue }
            guard count == 1 else { return .endOfInput }
            switch editor.feed(byte) {
            case .none:
                continue
            case .redraw:
                redraw(prompt: prompt, editor: editor)
            case let .submit(text):
                return .line(text)
            case .back:
                return .back
            case .interrupt:
                return .interrupt
            }
        }
    }

    /// Reprints the prompt and the line, then puts the cursor back by
    /// printing the text before it again, which lands right whatever the
    /// characters' display widths (wide CJK, emoji).
    private static func redraw(prompt: String, editor: LineEditor) {
        var output = "\r\(prompt)\(editor.left)\(editor.right)\u{1B}[K"
        if !editor.right.isEmpty {
            output += "\r\(prompt)\(editor.left)"
        }
        print(output, terminator: "")
        fflush(stdout)
    }

    // MARK: - Back Navigation

    /// Whether `input` asks to go back. Only `<` does, so any word, "back"
    /// included, can be an answer.
    static func isBackCommand(_ input: String) -> Bool {
        input.trimmingCharacters(in: .whitespaces) == "<"
    }

    // MARK: - Yes/No

    /// Ask a yes/no question on an editline prompt. Empty input takes the
    /// default; anything but y/yes/n/no asks again.
    static func askYesNo(prompt: String, default defaultValue: Bool = true) throws -> Bool {
        let hint = defaultValue ? "Y/n" : "y/N"
        while true {
            let input = try cookedAnswer(prompt: "  \(prompt) [\(hint)]: ", question: prompt)
            if let answer = yesNo(input, default: defaultValue) {
                return answer
            }
            line("  \(UISymbols.warn) Answer y or n.")
        }
    }

    /// `true` for y/yes, `false` for n/no, the default for empty input, nil otherwise.
    static func yesNo(_ input: String, default defaultValue: Bool) -> Bool? {
        switch input.lowercased() {
        case "": defaultValue
        case "y", "yes": true
        case "n", "no": false
        default: nil
        }
    }

    // MARK: - Wizard Prompts

    /// A text answer. Empty input takes `defaultValue`.
    static func wizardString(prompt: String, default defaultValue: String? = nil) throws -> WizardInput<String> {
        let displayPrompt = if let defaultValue {
            "  \(prompt) [\(defaultValue)]: "
        } else {
            "  \(prompt): "
        }
        guard let input = try wizardAnswer(prompt: displayPrompt, question: prompt) else { return .back }
        return .value(input.isEmpty ? defaultValue ?? "" : input)
    }

    /// A text answer `validator` accepts; asks again until it does.
    static func wizardValidatedString(
        prompt: String,
        default defaultValue: String? = nil,
        hint: String? = nil,
        validator: (String) -> Bool
    ) throws -> WizardInput<String> {
        while true {
            switch try wizardString(prompt: prompt, default: defaultValue) {
            case .back:
                return .back
            case let .value(value):
                if validator(value) { return .value(value) }
                line("  \(UISymbols.warn) \(hint ?? "Invalid input"). Try again.")
            }
        }
    }

    /// A yes/no answer. Empty input takes the default.
    static func wizardYesNo(prompt: String, default defaultValue: Bool = true) throws -> WizardInput<Bool> {
        let hint = defaultValue ? "Y/n" : "y/N"
        while true {
            guard let input = try wizardAnswer(prompt: "  \(prompt) [\(hint)]: ", question: prompt) else { return .back }
            if let answer = yesNo(input, default: defaultValue) {
                return .value(answer)
            }
            line("  \(UISymbols.warn) Answer y or n.")
        }
    }

    /// Choose any number of `options` (0-based indices). `current` starts
    /// marked, and Enter keeps it. Numbers replace the selection; `+n` and
    /// `-n` add and remove; `none` clears it when `allowsEmpty`.
    static func wizardMultiSelect(
        prompt: String,
        options: [String],
        current: Set<Int> = [],
        allowsEmpty: Bool = true
    ) throws -> WizardInput<Set<Int>> {
        line("  \(prompt):")
        for (index, option) in options.enumerated() {
            line("    \(index + 1). [\(current.contains(index) ? "x" : " ")] \(option)")
        }
        let clear = allowsEmpty ? "; none clears" : ""
        line("    Enter keeps the marked ones. Numbers choose (1,3,5); +4 adds and -2 removes\(clear).")
        while true {
            guard let input = try wizardAnswer(prompt: "    > ", question: prompt) else { return .back }
            switch parseSelection(input, current: current, optionCount: options.count, allowsEmpty: allowsEmpty) {
            case let .success(selection):
                return .value(selection)
            case let .failure(problem):
                line("  \(UISymbols.warn) \(problem.description)")
            }
        }
    }

    /// Why a multi-select answer was rejected.
    struct SelectionProblem: Error, CustomStringConvertible, Equatable {
        let description: String
    }

    /// The selection `input` makes from `current`. See `wizardMultiSelect`.
    static func parseSelection(
        _ input: String,
        current: Set<Int>,
        optionCount: Int,
        allowsEmpty: Bool
    ) -> Result<Set<Int>, SelectionProblem> {
        let atLeastOne = SelectionProblem(description: "Choose at least one option.")
        if input.isEmpty {
            return current.isEmpty && !allowsEmpty ? .failure(atLeastOne) : .success(current)
        }
        if input.lowercased() == "none" {
            return allowsEmpty ? .success([]) : .failure(atLeastOne)
        }
        let tokens = input.split(whereSeparator: { $0 == "," || $0 == " " }).map(String.init)
        let isDelta = tokens.contains { $0.hasPrefix("+") || $0.hasPrefix("-") }
        var selection = isDelta ? current : []
        for token in tokens {
            let removes = token.hasPrefix("-")
            let digits = token.hasPrefix("+") || removes ? String(token.dropFirst()) : token
            guard let number = Int(digits), (1 ... optionCount).contains(number) else {
                return .failure(SelectionProblem(description: "'\(token)' is not an option. Use numbers from 1 to \(optionCount)."))
            }
            if removes {
                selection.remove(number - 1)
            } else {
                selection.insert(number - 1)
            }
        }
        if selection.isEmpty, !allowsEmpty {
            return .failure(atLeastOne)
        }
        return .success(selection)
    }

    /// Choose one of `options` (0-based index). Empty input takes the default.
    static func wizardSelect(
        prompt: String,
        options: [String],
        default defaultIndex: Int = 0
    ) throws -> WizardInput<Int> {
        line("  \(prompt):")
        for (index, option) in options.enumerated() {
            let marker = index == defaultIndex ? " (default)" : ""
            line("    (\(index + 1)) \(option)\(marker)")
        }
        while true {
            guard let input = try wizardAnswer(prompt: "    > ", question: prompt) else { return .back }
            if input.isEmpty { return .value(defaultIndex) }
            if let choice = Int(input), (1 ... options.count).contains(choice) {
                return .value(choice - 1)
            }
            line("  \(UISymbols.warn) Enter a number from 1 to \(options.count).")
        }
    }

    /// Tabs as `Name:icon` pairs, parsed like `--tabs`; asks again on a
    /// malformed entry. Empty input keeps `current`.
    static func wizardTabs(prompt: String, current: [TabDefinition] = []) throws -> WizardInput<[TabDefinition]> {
        line("  \(prompt)")
        line("    Format: Name:sf_symbol_name (icons from SF Symbols at developer.apple.com/sf-symbols)")
        let currentText = current.map { "\($0.name):\($0.icon)" }.joined(separator: ", ")
        let displayPrompt = currentText.isEmpty ? "    > " : "    [\(currentText)] > "
        while true {
            guard let input = try wizardAnswer(prompt: displayPrompt, question: prompt) else { return .back }
            if input.isEmpty { return .value(current) }
            do {
                return try .value(TabDefinition.parseList(input))
            } catch {
                line("  \(UISymbols.warn) \(error.description)")
            }
        }
    }
}

// MARK: - Script

/// Answers prompts in place of the terminal, for tests: each read asks
/// `answer` with the prompt's question, and a `nil` answer is end of input.
/// Everything the prompts write goes to `transcript`.
final class PromptScript: @unchecked Sendable {
    /// Ctrl-C, as an answer.
    static let interrupt = "\u{03}"

    /// Reads after this many end input, so a prompt that keeps asking fails
    /// the test instead of hanging it.
    private static let readLimit = 500

    private let answer: (_ question: String) -> String?
    private(set) var transcript = ""
    /// The questions asked, in order.
    private(set) var questions: [String] = []

    init(_ answer: @escaping (_ question: String) -> String?) {
        self.answer = answer
    }

    /// Answers in order, whatever the question; input ends after the last.
    convenience init(lines: [String?]) {
        var remaining = lines[...]
        self.init { _ in remaining.popFirst() ?? nil }
    }

    /// Answers by question: the first key the question contains gives the
    /// next of its answers. Any other question, or a key whose answers ran
    /// out, gets Enter (the default).
    convenience init(answers: KeyValuePairs<String, [String]>) {
        var queues = answers.map { (key: $0.key, answers: $0.value[...]) }
        self.init { question in
            guard let index = queues.firstIndex(where: { question.contains($0.key) && !$0.answers.isEmpty }) else { return "" }
            return queues[index].answers.popFirst()
        }
    }

    func record(_ text: String) {
        transcript += text
    }

    func read(question: String, prompt: String) -> PromptEngine.Read {
        record(prompt)
        guard questions.count < Self.readLimit, let reply = answer(question) else {
            questions.append(question)
            return .endOfInput
        }
        questions.append(question)
        record(reply + "\n")
        return reply == Self.interrupt ? .interrupt : .line(reply)
    }
}
