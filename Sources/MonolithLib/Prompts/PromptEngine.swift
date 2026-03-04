import CEditLine
import Foundation

enum PromptEngine {
    // MARK: - Line Input

    /// Whether stdin is an interactive terminal (editline features require a TTY).
    private static let isTTY = isatty(STDIN_FILENO) != 0

    /// Whether back navigation (up arrow / `<`) is allowed in the current wizard step.
    /// Set by `WizardEngine` before each step executes.
    nonisolated(unsafe) static var wizardBackEnabled = true

    /// Read a line using editline (supports arrow keys, cursor movement, etc.).
    /// Falls back to Swift's `readLine()` when stdin is not a TTY (piped input).
    private static func editlineRead(prompt: String) -> String? {
        guard isTTY else {
            print(prompt, terminator: "")
            return readLine()
        }
        guard let cString = readline(prompt) else { return nil }
        defer { free(cString) }
        return String(cString: cString)
    }

    // MARK: - Wizard Line Input (Raw Terminal)

    /// Read a line in raw terminal mode with up arrow mapped to back navigation.
    /// Handles: typing, backspace, left/right cursor, up arrow (back), Ctrl+C/D.
    /// Falls back to Swift's `readLine()` when stdin is not a TTY.
    private static func wizardReadLine(prompt: String) -> String? {
        guard isTTY else {
            print(prompt, terminator: "")
            return readLine()
        }

        print(prompt, terminator: "")
        fflush(stdout)

        // Save terminal state
        var saved = termios()
        tcgetattr(STDIN_FILENO, &saved)

        // Enter raw mode
        var raw = saved
        raw.c_lflag &= ~tcflag_t(ICANON | ECHO | ISIG)
        raw.c_iflag &= ~tcflag_t(IXON)
        withUnsafeMutablePointer(to: &raw.c_cc) { ptr in
            ptr.withMemoryRebound(to: cc_t.self, capacity: Int(NCCS)) { cc in
                cc[Int(VMIN)] = 1
                cc[Int(VTIME)] = 0
            }
        }
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)

        var buffer: [UInt8] = []
        var cursor = 0

        func redraw() {
            // Carriage return, reprint prompt + buffer, clear trailing chars
            let text = String(bytes: buffer, encoding: .utf8) ?? ""
            print("\r\(prompt)\(text)\u{1B}[K", terminator: "")
            // Move cursor back if not at end
            let back = buffer.count - cursor
            if back > 0 { print("\u{1B}[\(back)D", terminator: "") }
            fflush(stdout)
        }

        func restore() {
            tcsetattr(STDIN_FILENO, TCSAFLUSH, &saved)
            print()
        }

        while true {
            var ch: UInt8 = 0
            guard Darwin.read(STDIN_FILENO, &ch, 1) == 1 else {
                restore()
                return nil
            }

            switch ch {
            case 0x0A, 0x0D: // Enter
                restore()
                return String(bytes: buffer, encoding: .utf8) ?? ""

            case 0x7F, 0x08: // Backspace
                if cursor > 0 {
                    cursor -= 1
                    buffer.remove(at: cursor)
                    redraw()
                }

            case 0x1B: // ESC — read sequence
                var seq = [UInt8](repeating: 0, count: 2)
                guard Darwin.read(STDIN_FILENO, &seq, 2) == 2, seq[0] == 0x5B else { continue }
                switch seq[1] {
                case 0x41: // Up arrow → back (only if allowed)
                    if wizardBackEnabled {
                        restore()
                        return "<"
                    }
                case 0x42: // Down arrow → ignore
                    break
                case 0x43: // Right arrow
                    if cursor < buffer.count { cursor += 1; redraw() }
                case 0x44: // Left arrow
                    if cursor > 0 { cursor -= 1; redraw() }
                default:
                    break
                }

            case 0x03: // Ctrl+C
                restore()
                Darwin.exit(0)

            case 0x04: // Ctrl+D
                restore()
                Darwin.exit(0)

            case 32 ... 126: // Printable ASCII
                buffer.insert(ch, at: cursor)
                cursor += 1
                redraw()

            default:
                break
            }
        }
    }

    // MARK: - Feature Parsing

    /// Parse a comma-separated string into a set of enum values.
    /// Warns on stderr for unrecognized feature names.
    static func parseFeatures<F: RawRepresentable & CaseIterable & Hashable>(
        _ input: String?,
        type: F.Type = F.self,
    ) -> Set<F> where F.RawValue == String {
        guard let input, !input.isEmpty else { return [] }
        let names = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        var result = Set<F>()
        for name in names {
            if let feature = F.allCases.first(where: { $0.rawValue == name }) {
                result.insert(feature)
            } else {
                let valid = F.allCases.map(\.rawValue).joined(separator: ", ")
                FileHandle.standardError.write(
                    Data("warning: unrecognized feature '\(name)' (valid: \(valid))\n".utf8),
                )
            }
        }
        return result
    }

    // MARK: - Yes/No

    /// Ask a yes/no question. Returns the default if input is empty.
    static func askYesNo(prompt: String, default defaultValue: Bool = true) -> Bool {
        let hint = defaultValue ? "Y/n" : "y/N"

        guard let input = editlineRead(prompt: "  \(prompt) [\(hint)]: ")?
            .trimmingCharacters(in: .whitespaces).lowercased(),
            !input.isEmpty
        else {
            return defaultValue
        }

        return ["y", "yes"].contains(input)
    }

    // MARK: - Tabs

    /// Parse "Home:house, Settings:gearshape" format into TabDefinitions.
    static func parseTabs(_ input: String) -> [TabDefinition] {
        input
            .split(separator: ",")
            .compactMap { segment in
                let parts = segment.trimmingCharacters(in: .whitespaces).split(separator: ":", maxSplits: 1)
                guard parts.count == 2 else { return nil }
                let name = parts[0].trimmingCharacters(in: .whitespaces)
                let icon = parts[1].trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty, !icon.isEmpty else { return nil }
                return TabDefinition(name: String(name), icon: String(icon))
            }
    }

    // MARK: - Wizard Input

    /// Result of a wizard prompt — either a value or a back-navigation request.
    enum WizardInput<T> {
        case value(T)
        case back
    }

    /// Check if raw input is a back-navigation command.
    static func isBackCommand(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespaces).lowercased()
        return trimmed == "<" || trimmed == "back"
    }

    /// Wizard variant of askString. Returns `.back` if user types `<`/`back` or presses up arrow.
    static func wizardString(prompt: String, default defaultValue: String? = nil) -> WizardInput<String> {
        let displayPrompt = if let defaultValue {
            "  \(prompt) [\(defaultValue)]: "
        } else {
            "  \(prompt): "
        }

        guard let input = wizardReadLine(prompt: displayPrompt)?.trimmingCharacters(in: .whitespaces),
              !input.isEmpty
        else {
            return .value(defaultValue ?? "")
        }

        if isBackCommand(input) { return .back }
        return .value(input)
    }

    /// Wizard variant of askValidatedString. Loops until valid, returns `.back` on back command.
    static func wizardValidatedString(
        prompt: String,
        default defaultValue: String? = nil,
        hint: String? = nil,
        validator: (String) -> Bool,
    ) -> WizardInput<String> {
        while true {
            let result = wizardString(prompt: prompt, default: defaultValue)
            switch result {
            case .back:
                return .back
            case let .value(value):
                if validator(value) { return .value(value) }
                let hintMsg = hint ?? "Invalid input"
                print("  \u{26A0} \(hintMsg). Try again.")
            }
        }
    }

    /// Wizard variant of askYesNo. Returns `.back` on back command or up arrow.
    static func wizardYesNo(prompt: String, default defaultValue: Bool = true) -> WizardInput<Bool> {
        let hint = defaultValue ? "Y/n" : "y/N"

        guard let input = wizardReadLine(prompt: "  \(prompt) [\(hint)]: ")?
            .trimmingCharacters(in: .whitespaces),
            !input.isEmpty
        else {
            return .value(defaultValue)
        }

        if isBackCommand(input) { return .back }
        return .value(["y", "yes"].contains(input.lowercased()))
    }

    /// Wizard variant of askMultiSelect. Returns `.back` on back command or up arrow.
    static func wizardMultiSelect(prompt: String, options: [String]) -> WizardInput<Set<Int>> {
        print("  \(prompt) (e.g., 1,3,5 or none):")
        for (index, option) in options.enumerated() {
            print("    \(index + 1). \(option)")
        }

        guard let input = wizardReadLine(prompt: "    > ")?.trimmingCharacters(in: .whitespaces),
              !input.isEmpty
        else {
            return .value([])
        }

        if isBackCommand(input) { return .back }
        if input.lowercased() == "none" { return .value([]) }

        let indices = input
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 >= 1 && $0 <= options.count }
            .map { $0 - 1 }

        return .value(Set(indices))
    }

    /// Wizard variant of askSelect. Returns `.back` on back command or up arrow.
    /// Returns the selected index (0-based).
    static func wizardSelect(
        prompt: String,
        options: [String],
        default defaultIndex: Int = 0,
    ) -> WizardInput<Int> {
        print("  \(prompt):")
        for (index, option) in options.enumerated() {
            let marker = index == defaultIndex ? " (default)" : ""
            print("    (\(index + 1)) \(option)\(marker)")
        }

        guard let input = wizardReadLine(prompt: "    > ")?.trimmingCharacters(in: .whitespaces),
              !input.isEmpty
        else {
            return .value(defaultIndex)
        }

        if isBackCommand(input) { return .back }

        guard let choice = Int(input),
              choice >= 1, choice <= options.count
        else {
            return .value(defaultIndex)
        }

        return .value(choice - 1)
    }

    /// Wizard variant of askTabs. Returns `.back` on back command or up arrow.
    static func wizardTabs(prompt: String) -> WizardInput<[TabDefinition]> {
        print("  \(prompt)")
        print("    Format: Name:sf_symbol_name \u{2014} icons from SF Symbols (developer.apple.com/sf-symbols)")

        guard let input = wizardReadLine(prompt: "    > ")?.trimmingCharacters(in: .whitespaces),
              !input.isEmpty
        else {
            return .value([])
        }

        if isBackCommand(input) { return .back }
        return .value(parseTabs(input))
    }

    /// Clear terminal screen using ANSI escape codes.
    static func clearScreen() {
        print("\u{1B}[2J\u{1B}[H", terminator: "")
    }
}
