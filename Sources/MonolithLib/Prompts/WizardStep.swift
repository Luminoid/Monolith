import Foundation

// MARK: - State

/// Mutable state container for wizard values, keyed by step ID.
struct WizardState {
    var values: [String: Any] = [:]
    /// Steps whose value came from a command-line flag. The wizard skips
    /// them but still shows them on the summary page.
    var fixed: Set<String> = []

    /// Store a flag's value for step `id` and skip the step. A `nil` value
    /// still skips it, for a step the flags make moot.
    mutating func fix(_ id: String, _ value: Any?) {
        if let value {
            values[id] = value
        }
        fixed.insert(id)
    }

    func string(_ key: String) -> String? {
        values[key] as? String
    }

    func bool(_ key: String) -> Bool? {
        values[key] as? Bool
    }

    func int(_ key: String) -> Int? {
        values[key] as? Int
    }

    func intSet(_ key: String) -> Set<Int>? {
        values[key] as? Set<Int>
    }

    func tabDefinitions(_ key: String) -> [TabDefinition]? {
        values[key] as? [TabDefinition]
    }

    func targetDefinitions(_ key: String) -> [TargetDefinition]? {
        values[key] as? [TargetDefinition]
    }

    func platformVersions(_ key: String) -> [PlatformVersion]? {
        values[key] as? [PlatformVersion]
    }
}

// MARK: - Action

/// Result of executing a wizard step.
enum WizardAction {
    case next
    case back
}

// MARK: - Step Protocol

/// A single page in the wizard flow.
protocol WizardStep {
    /// Unique key for storing this step's value in WizardState.
    var id: String { get }

    /// Display label shown in the summary (e.g., "App name").
    var title: String { get }

    /// Whether this step should be shown given the current state.
    func isVisible(state: WizardState) -> Bool

    /// Execute the step: prompt the user, store the answer in state, and
    /// return the navigation action. Throws when input ends or is cancelled.
    func execute(state: inout WizardState) throws -> WizardAction

    /// Format this step's stored value for display in summary. Returns nil if no value.
    func summaryValue(state: WizardState) -> String?
}

// MARK: - Concrete Steps

/// A text input step with validation.
struct ValidatedStringStep: WizardStep {
    let id: String
    let title: String
    let prompt: String
    let defaultValue: ((WizardState) -> String)?
    let staticDefault: String?
    let hint: String?
    let validator: (String) -> Bool
    let visibility: ((WizardState) -> Bool)?

    init(
        id: String,
        title: String,
        prompt: String,
        defaultValue: ((WizardState) -> String)? = nil,
        staticDefault: String? = nil,
        hint: String? = nil,
        validator: @escaping (String) -> Bool,
        isVisible: ((WizardState) -> Bool)? = nil
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.defaultValue = defaultValue
        self.staticDefault = staticDefault
        self.hint = hint
        self.validator = validator
        self.visibility = isVisible
    }

    func isVisible(state: WizardState) -> Bool {
        visibility?(state) ?? true
    }

    func execute(state: inout WizardState) throws -> WizardAction {
        let resolvedDefault = state.string(id) ?? defaultValue?(state) ?? staticDefault
        let result = try PromptEngine.wizardValidatedString(
            prompt: prompt,
            default: resolvedDefault,
            hint: hint,
            validator: validator
        )
        switch result {
        case let .value(v):
            state.values[id] = v
            return .next
        case .back:
            return .back
        }
    }

    func summaryValue(state: WizardState) -> String? {
        state.string(id)
    }
}

/// A text input step without validation.
struct StringStep: WizardStep {
    let id: String
    let title: String
    let prompt: String
    let defaultValue: ((WizardState) -> String)?
    let staticDefault: String?
    let visibility: ((WizardState) -> Bool)?

    init(
        id: String,
        title: String,
        prompt: String,
        defaultValue: ((WizardState) -> String)? = nil,
        staticDefault: String? = nil,
        isVisible: ((WizardState) -> Bool)? = nil
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.defaultValue = defaultValue
        self.staticDefault = staticDefault
        self.visibility = isVisible
    }

    func isVisible(state: WizardState) -> Bool {
        visibility?(state) ?? true
    }

    func execute(state: inout WizardState) throws -> WizardAction {
        let resolvedDefault = state.string(id) ?? defaultValue?(state) ?? staticDefault
        let result = try PromptEngine.wizardString(prompt: prompt, default: resolvedDefault)
        switch result {
        case let .value(v):
            state.values[id] = v
            return .next
        case .back:
            return .back
        }
    }

    func summaryValue(state: WizardState) -> String? {
        state.string(id)
    }
}

/// A yes/no step.
struct YesNoStep: WizardStep {
    let id: String
    let title: String
    let prompt: String
    let defaultValue: Bool
    let visibility: ((WizardState) -> Bool)?

    init(
        id: String,
        title: String,
        prompt: String,
        defaultValue: Bool = true,
        isVisible: ((WizardState) -> Bool)? = nil
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.defaultValue = defaultValue
        self.visibility = isVisible
    }

    func isVisible(state: WizardState) -> Bool {
        visibility?(state) ?? true
    }

    func execute(state: inout WizardState) throws -> WizardAction {
        let resolvedDefault = state.bool(id) ?? defaultValue
        let result = try PromptEngine.wizardYesNo(prompt: prompt, default: resolvedDefault)
        switch result {
        case let .value(v):
            state.values[id] = v
            return .next
        case .back:
            return .back
        }
    }

    func summaryValue(state: WizardState) -> String? {
        guard let v = state.bool(id) else { return nil }
        return v ? "Yes" : "No"
    }
}

/// A multi-select step. The options it starts with marked are the previous
/// answer (back navigation, or "Proceed? n"), else `preselected`.
struct MultiSelectStep: WizardStep {
    let id: String
    let title: String
    let prompt: String
    let options: [String]
    let visibility: ((WizardState) -> Bool)?
    let preselected: ((WizardState) -> Set<Int>)?
    /// Whether no selection is an answer. When false, `none` is refused.
    let allowsEmpty: Bool
    /// Why a selection can't be used, or nil when it can; the step asks again.
    let validate: ((Set<Int>) -> String?)?

    init(
        id: String,
        title: String,
        prompt: String,
        options: [String],
        isVisible: ((WizardState) -> Bool)? = nil,
        preselected: ((WizardState) -> Set<Int>)? = nil,
        allowsEmpty: Bool = true,
        validate: ((Set<Int>) -> String?)? = nil
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.options = options
        self.visibility = isVisible
        self.preselected = preselected
        self.allowsEmpty = allowsEmpty
        self.validate = validate
    }

    func isVisible(state: WizardState) -> Bool {
        visibility?(state) ?? true
    }

    func execute(state: inout WizardState) throws -> WizardAction {
        var current = state.intSet(id) ?? preselected?(state) ?? []
        while true {
            let result = try PromptEngine.wizardMultiSelect(prompt: prompt, options: options, current: current, allowsEmpty: allowsEmpty)
            switch result {
            case let .value(selection):
                if let problem = validate?(selection) {
                    PromptEngine.line("  \(UISymbols.warn) \(problem)")
                    current = selection
                    continue
                }
                state.values[id] = selection
                return .next
            case .back:
                return .back
            }
        }
    }

    func summaryValue(state: WizardState) -> String? {
        guard let indices = state.intSet(id) else { return nil }
        if indices.isEmpty { return "None" }
        return indices.sorted().compactMap { idx in
            idx < options.count ? options[idx] : nil
        }.joined(separator: ", ")
    }
}

/// A single-select step (pick one from a numbered list).
struct SingleSelectStep: WizardStep {
    let id: String
    let title: String
    let prompt: String
    let options: [String]
    let defaultIndex: Int
    let visibility: ((WizardState) -> Bool)?
    /// Runs when the answer differs from an earlier one, e.g. to drop a
    /// later step's answer that was derived from it.
    let onChange: ((inout WizardState) -> Void)?

    init(
        id: String,
        title: String,
        prompt: String,
        options: [String],
        defaultIndex: Int = 0,
        isVisible: ((WizardState) -> Bool)? = nil,
        onChange: ((inout WizardState) -> Void)? = nil
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.options = options
        self.defaultIndex = defaultIndex
        self.visibility = isVisible
        self.onChange = onChange
    }

    func isVisible(state: WizardState) -> Bool {
        visibility?(state) ?? true
    }

    func execute(state: inout WizardState) throws -> WizardAction {
        let previous = state.int(id)
        let result = try PromptEngine.wizardSelect(
            prompt: prompt,
            options: options,
            default: previous ?? defaultIndex
        )
        switch result {
        case let .value(v):
            state.values[id] = v
            if let previous, previous != v {
                onChange?(&state)
            }
            return .next
        case .back:
            return .back
        }
    }

    func summaryValue(state: WizardState) -> String? {
        guard let index = state.int(id), index < options.count else { return nil }
        return options[index]
    }
}

/// A tabs input step (Name:icon format).
struct TabsStep: WizardStep {
    let id: String
    let title: String
    let prompt: String
    let visibility: ((WizardState) -> Bool)?

    init(
        id: String,
        title: String,
        prompt: String,
        isVisible: ((WizardState) -> Bool)? = nil
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.visibility = isVisible
    }

    func isVisible(state: WizardState) -> Bool {
        visibility?(state) ?? true
    }

    func execute(state: inout WizardState) throws -> WizardAction {
        let result = try PromptEngine.wizardTabs(prompt: prompt, current: state.tabDefinitions(id) ?? [])
        switch result {
        case let .value(v):
            state.values[id] = v
            return .next
        case .back:
            return .back
        }
    }

    func summaryValue(state: WizardState) -> String? {
        guard let tabs = state.tabDefinitions(id) else { return nil }
        if tabs.isEmpty { return "None" }
        return tabs.map { "\($0.name):\($0.icon)" }.joined(separator: ", ")
    }
}

/// A value only a command-line flag sets, shown on the summary page. It
/// never prompts: it is visible only once `WizardState.fix` stored its
/// value, which also skips it.
struct InfoStep: WizardStep {
    let id: String
    let title: String

    func isVisible(state: WizardState) -> Bool {
        state.values[id] != nil
    }

    func execute(state _: inout WizardState) -> WizardAction {
        .next
    }

    func summaryValue(state: WizardState) -> String? {
        state.string(id)
    }
}

/// A custom step with a closure for complex logic (e.g., target deps loop).
struct CustomStep: WizardStep {
    let id: String
    let title: String
    let visibility: ((WizardState) -> Bool)?
    let action: (inout WizardState) throws -> WizardAction
    let summary: (WizardState) -> String?

    init(
        id: String,
        title: String,
        isVisible: ((WizardState) -> Bool)? = nil,
        execute: @escaping (inout WizardState) throws -> WizardAction,
        summaryValue: @escaping (WizardState) -> String?
    ) {
        self.id = id
        self.title = title
        self.visibility = isVisible
        self.action = execute
        self.summary = summaryValue
    }

    func isVisible(state: WizardState) -> Bool {
        visibility?(state) ?? true
    }

    func execute(state: inout WizardState) throws -> WizardAction {
        try action(&state)
    }

    func summaryValue(state: WizardState) -> String? {
        summary(state)
    }
}
