import Foundation

enum WizardEngine {
    // MARK: - Run

    /// Run the steps, then the summary page. Answering no at "Proceed?" goes
    /// through the steps again with every answer kept as the default.
    /// Returns once the user confirms; throws when input ends or is cancelled.
    static func run(title: String, steps: [any WizardStep], state: inout WizardState) throws {
        try runSteps(title: title, steps: steps, state: &state)
        while true {
            renderSummary(title: title, steps: steps, state: state)
            if try PromptEngine.askYesNo(prompt: "Proceed?") {
                return
            }
            try runSteps(title: title, steps: steps, state: &state)
        }
    }

    /// One pass over the active steps, with back navigation.
    private static func runSteps(title: String, steps: [any WizardStep], state: inout WizardState) throws {
        var index = 0
        var navigatingBack = false
        while index < steps.count {
            let step = steps[index]
            guard isActive(step, state: state) else {
                index += 1
                continue
            }

            // Render the page, except when navigating back: then just re-prompt.
            let stepNumber = visibleIndex(at: index, steps: steps, state: state)
            if !navigatingBack {
                renderPage(
                    title: title,
                    stepNumber: stepNumber,
                    totalVisible: visibleCount(steps: steps, state: state),
                    state: state,
                    steps: steps,
                    currentIndex: index
                )
            }
            navigatingBack = false

            // The first step has nothing to go back to.
            let action = try PromptEngine.$isBackEnabled.withValue(stepNumber > 1) {
                try step.execute(state: &state)
            }
            switch action {
            case .next:
                index += 1
            case .back:
                navigatingBack = true
                index = previousVisibleIndex(before: index, steps: steps, state: state)
            }
        }
    }

    // MARK: - Rendering

    private static let lineWidth = 48
    private static let separator = String(repeating: UISymbols.hRule, count: lineWidth)

    private static func renderPage(
        title: String,
        stepNumber: Int,
        totalVisible: Int,
        state: WizardState,
        steps: [any WizardStep],
        currentIndex: Int
    ) {
        PromptEngine.clearScreen()

        // Header
        let stepLabel = "Step \(stepNumber) of \(totalVisible)"
        let padding = max(0, lineWidth - title.count - stepLabel.count - 4)
        PromptEngine.line("  \(separator)")
        PromptEngine.line("  \(title)\(String(repeating: " ", count: padding))\(stepLabel)")
        PromptEngine.line("  \(separator)")
        PromptEngine.line()

        // Back hint (shown from step 2 onward)
        if stepNumber > 1 {
            PromptEngine.line("  \u{1B}[2m(\(UISymbols.upArrow) or type \u{1B}[22m<\u{1B}[2m to go back)\u{1B}[0m")
            PromptEngine.line()
        }

        // Summary of previously answered steps, flag values included
        for i in 0 ..< currentIndex {
            let prev = steps[i]
            guard prev.isVisible(state: state) else { continue }
            if let value = prev.summaryValue(state: state), !value.isEmpty {
                PromptEngine.line("  \(prev.title): \(value)")
            }
        }
        if currentIndex > 0 {
            PromptEngine.line("  \(UISymbols.hRule)")
            PromptEngine.line()
        }
    }

    private static func renderSummary(title: String, steps: [any WizardStep], state: WizardState) {
        PromptEngine.clearScreen()

        // Header
        let summaryLabel = "Summary"
        let padding = max(0, lineWidth - title.count - summaryLabel.count - 4)
        PromptEngine.line("  \(separator)")
        PromptEngine.line("  \(title)\(String(repeating: " ", count: padding))\(summaryLabel)")
        PromptEngine.line("  \(separator)")
        PromptEngine.line()

        // All values, the ones flags set included
        let maxTitleLen = steps
            .filter { $0.isVisible(state: state) }
            .compactMap { step -> Int? in
                guard step.summaryValue(state: state) != nil else { return nil }
                return step.title.count
            }
            .max() ?? 0

        for step in steps {
            guard step.isVisible(state: state) else { continue }
            if let value = step.summaryValue(state: state) {
                let padded = step.title.padding(toLength: maxTitleLen, withPad: " ", startingAt: 0)
                PromptEngine.line("  \(padded)  \(value)")
            }
        }
        PromptEngine.line()
    }

    // MARK: - Navigation Helpers

    /// Whether the wizard stops at `step`: it is visible, and no flag set its value.
    static func isActive(_ step: any WizardStep, state: WizardState) -> Bool {
        step.isVisible(state: state) && !state.fixed.contains(step.id)
    }

    /// Find the 1-based number of the step at `index` among the active steps.
    /// `internal` (not `private`) so tests can exercise the pure-logic
    /// state-machine helpers without needing a TTY for the full `run` loop.
    static func visibleIndex(at index: Int, steps: [any WizardStep], state: WizardState) -> Int {
        var count = 0
        for i in 0 ... index where isActive(steps[i], state: state) {
            count += 1
        }
        return count
    }

    /// Count the active steps.
    static func visibleCount(steps: [any WizardStep], state: WizardState) -> Int {
        steps.count { isActive($0, state: state) }
    }

    /// Find the index of the previous active step before `index`. Returns `index` if none found (stay on current).
    static func previousVisibleIndex(before index: Int, steps: [any WizardStep], state: WizardState) -> Int {
        var i = index - 1
        while i >= 0 {
            if isActive(steps[i], state: state) { return i }
            i -= 1
        }
        // No previous active step: stay on current
        return index
    }
}
