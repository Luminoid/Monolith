import Foundation

// MARK: - State

/// Mutable state container for wizard values, keyed by step ID.
struct WizardState {
    var values: [String: Any] = [:]

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

    func stringArray(_ key: String) -> [String]? {
        values[key] as? [String]
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

    /// Execute the step — prompt user for input, store in state, return navigation action.
    func execute(state: inout WizardState) -> WizardAction

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
        isVisible: ((WizardState) -> Bool)? = nil,
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

    func execute(state: inout WizardState) -> WizardAction {
        let resolvedDefault = state.string(id) ?? defaultValue?(state) ?? staticDefault
        let result = PromptEngine.wizardValidatedString(
            prompt: prompt,
            default: resolvedDefault,
            hint: hint,
            validator: validator,
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
        isVisible: ((WizardState) -> Bool)? = nil,
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

    func execute(state: inout WizardState) -> WizardAction {
        let resolvedDefault = state.string(id) ?? defaultValue?(state) ?? staticDefault
        let result = PromptEngine.wizardString(prompt: prompt, default: resolvedDefault)
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
        isVisible: ((WizardState) -> Bool)? = nil,
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

    func execute(state: inout WizardState) -> WizardAction {
        let resolvedDefault = state.bool(id) ?? defaultValue
        let result = PromptEngine.wizardYesNo(prompt: prompt, default: resolvedDefault)
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

/// A multi-select step.
struct MultiSelectStep: WizardStep {
    let id: String
    let title: String
    let prompt: String
    let options: [String]
    let visibility: ((WizardState) -> Bool)?

    init(
        id: String,
        title: String,
        prompt: String,
        options: [String],
        isVisible: ((WizardState) -> Bool)? = nil,
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.options = options
        self.visibility = isVisible
    }

    func isVisible(state: WizardState) -> Bool {
        visibility?(state) ?? true
    }

    func execute(state: inout WizardState) -> WizardAction {
        let result = PromptEngine.wizardMultiSelect(prompt: prompt, options: options)
        switch result {
        case let .value(v):
            state.values[id] = v
            return .next
        case .back:
            return .back
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

    init(
        id: String,
        title: String,
        prompt: String,
        options: [String],
        defaultIndex: Int = 0,
        isVisible: ((WizardState) -> Bool)? = nil,
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.options = options
        self.defaultIndex = defaultIndex
        self.visibility = isVisible
    }

    func isVisible(state: WizardState) -> Bool {
        visibility?(state) ?? true
    }

    func execute(state: inout WizardState) -> WizardAction {
        let resolvedDefault = state.int(id) ?? defaultIndex
        let result = PromptEngine.wizardSelect(
            prompt: prompt,
            options: options,
            default: resolvedDefault,
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
        isVisible: ((WizardState) -> Bool)? = nil,
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.visibility = isVisible
    }

    func isVisible(state: WizardState) -> Bool {
        visibility?(state) ?? true
    }

    func execute(state: inout WizardState) -> WizardAction {
        let result = PromptEngine.wizardTabs(prompt: prompt)
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

/// A custom step with a closure for complex logic (e.g., target deps loop).
struct CustomStep: WizardStep {
    let id: String
    let title: String
    let visibility: ((WizardState) -> Bool)?
    let action: (inout WizardState) -> WizardAction
    let summary: (WizardState) -> String?

    init(
        id: String,
        title: String,
        isVisible: ((WizardState) -> Bool)? = nil,
        execute: @escaping (inout WizardState) -> WizardAction,
        summaryValue: @escaping (WizardState) -> String?,
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

    func execute(state: inout WizardState) -> WizardAction {
        action(&state)
    }

    func summaryValue(state: WizardState) -> String? {
        summary(state)
    }
}
