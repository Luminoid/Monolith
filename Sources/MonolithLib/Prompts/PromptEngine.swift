import Foundation

enum PromptEngine {
    // MARK: - String Input

    /// Ask for a string value with an optional default.
    static func askString(prompt: String, default defaultValue: String? = nil) -> String {
        if let defaultValue {
            print("  \(prompt) [\(defaultValue)]: ", terminator: "")
        } else {
            print("  \(prompt): ", terminator: "")
        }

        guard let input = readLine()?.trimmingCharacters(in: .whitespaces), !input.isEmpty else {
            return defaultValue ?? ""
        }
        return input
    }

    // MARK: - Validated String Input

    /// Ask for a string value with validation. Loops until input passes the validator.
    static func askValidatedString(
        prompt: String,
        default defaultValue: String? = nil,
        hint: String? = nil,
        validator: (String) -> Bool,
    ) -> String {
        while true {
            let value = askString(prompt: prompt, default: defaultValue)
            if validator(value) { return value }
            let hintMsg = hint ?? "Invalid input"
            print("  \u{26A0} \(hintMsg). Try again.")
        }
    }

    // MARK: - Feature Parsing

    /// Parse a comma-separated string into a set of enum values.
    static func parseFeatures<F: RawRepresentable & CaseIterable>(
        _ input: String?,
        type: F.Type = F.self,
    ) -> Set<F> where F.RawValue == String, F: Hashable {
        guard let input, !input.isEmpty else { return [] }
        let names = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return Set(names.compactMap { name in
            F.allCases.first { $0.rawValue == name }
        })
    }

    // MARK: - Yes/No

    /// Ask a yes/no question. Returns the default if input is empty.
    static func askYesNo(prompt: String, default defaultValue: Bool = true) -> Bool {
        let hint = defaultValue ? "Y/n" : "y/N"
        print("  \(prompt) [\(hint)]: ", terminator: "")

        guard let input = readLine()?.trimmingCharacters(in: .whitespaces).lowercased(), !input.isEmpty else {
            return defaultValue
        }

        return ["y", "yes"].contains(input)
    }

    // MARK: - Single Select

    /// Ask user to select one option from a numbered list. Returns the selected index (0-based).
    static func askSelect(prompt: String, options: [String], default defaultIndex: Int = 0) -> Int {
        print("  \(prompt):")
        for (index, option) in options.enumerated() {
            let marker = index == defaultIndex ? " (default)" : ""
            print("    (\(index + 1)) \(option)\(marker)")
        }
        print("    > ", terminator: "")

        guard let input = readLine()?.trimmingCharacters(in: .whitespaces),
              !input.isEmpty,
              let choice = Int(input),
              choice >= 1, choice <= options.count
        else {
            return defaultIndex
        }

        return choice - 1
    }

    // MARK: - Multi Select

    /// Ask user to select multiple options from a numbered list.
    /// Input format: comma-separated numbers (e.g., "1, 3, 5") or "none".
    /// Returns set of selected indices (0-based).
    static func askMultiSelect(prompt: String, options: [String]) -> Set<Int> {
        print("  \(prompt) (comma-separated numbers, or none):")
        for (index, option) in options.enumerated() {
            print("    \(index + 1). \(option)")
        }
        print("    > ", terminator: "")

        guard let input = readLine()?.trimmingCharacters(in: .whitespaces),
              !input.isEmpty,
              input.lowercased() != "none"
        else {
            return []
        }

        let indices = input
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 >= 1 && $0 <= options.count }
            .map { $0 - 1 }

        return Set(indices)
    }

    // MARK: - Tabs

    /// Ask for tab definitions in "name:icon, name:icon" format.
    /// Returns empty array if no tabs entered.
    static func askTabs(prompt: String) -> [TabDefinition] {
        print("  \(prompt)")
        print("    > ", terminator: "")

        guard let input = readLine()?.trimmingCharacters(in: .whitespaces), !input.isEmpty else {
            return []
        }

        return parseTabs(input)
    }

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

    // MARK: - Header

    /// Print a styled header for the prompt session.
    static func printHeader(title: String) {
        print()
        print("  \(title)")
        print()
    }
}
