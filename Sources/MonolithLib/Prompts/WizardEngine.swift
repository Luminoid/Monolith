import Foundation

enum WizardEngine {
    // MARK: - Run

    /// Run a wizard flow with the given steps. Returns when all visible steps are completed and confirmed.
    static func run(title: String, steps: [any WizardStep], state: inout WizardState) {
        var index = 0
        var navigatingBack = false

        while index < steps.count {
            let step = steps[index]

            // Skip invisible steps (forward)
            guard step.isVisible(state: state) else {
                index += 1
                continue
            }

            // Render page (skip when navigating back — just re-prompt)
            let visibleNumber = visibleIndex(at: index, steps: steps, state: state)
            let totalVisible = visibleCount(steps: steps, state: state)
            if !navigatingBack {
                renderPage(
                    title: title,
                    step: step,
                    stepNumber: visibleNumber,
                    totalVisible: totalVisible,
                    state: state,
                    steps: steps,
                    currentIndex: index,
                )
            }
            navigatingBack = false

            // Execute step (disable back on first visible step)
            PromptEngine.wizardBackEnabled = visibleNumber > 1
            let action = step.execute(state: &state)

            switch action {
            case .next:
                index += 1
            case .back:
                navigatingBack = true
                index = previousVisibleIndex(before: index, steps: steps, state: state)
            }
        }

        // Summary page with confirmation loop
        while true {
            renderSummary(title: title, steps: steps, state: state)
            let proceed = PromptEngine.askYesNo(prompt: "Proceed?")
            if proceed { break }
            // Restart from first step — all values preserved as defaults
            index = 0
            navigatingBack = false
            while index < steps.count {
                let step = steps[index]
                guard step.isVisible(state: state) else {
                    index += 1
                    continue
                }
                let visNum = visibleIndex(at: index, steps: steps, state: state)
                let total = visibleCount(steps: steps, state: state)
                if !navigatingBack {
                    renderPage(
                        title: title,
                        step: step,
                        stepNumber: visNum,
                        totalVisible: total,
                        state: state,
                        steps: steps,
                        currentIndex: index,
                    )
                }
                navigatingBack = false
                PromptEngine.wizardBackEnabled = visNum > 1
                let action = step.execute(state: &state)
                switch action {
                case .next: index += 1
                case .back:
                    navigatingBack = true
                    index = previousVisibleIndex(before: index, steps: steps, state: state)
                }
            }
        }
    }

    // MARK: - Rendering

    private static let lineWidth = 48
    private static let separator = String(repeating: "\u{2500}", count: lineWidth)

    private static func renderPage(
        title: String,
        step: any WizardStep,
        stepNumber: Int,
        totalVisible: Int,
        state: WizardState,
        steps: [any WizardStep],
        currentIndex: Int,
    ) {
        PromptEngine.clearScreen()

        // Header
        let stepLabel = "Step \(stepNumber) of \(totalVisible)"
        let padding = max(0, lineWidth - title.count - stepLabel.count - 4)
        print("  \(separator)")
        print("  \(title)\(String(repeating: " ", count: padding))\(stepLabel)")
        print("  \(separator)")
        print()

        // Back hint (shown from step 2 onward)
        if stepNumber > 1 {
            print("  \u{1B}[2m(\u{2191} or type \u{1B}[22mback\u{1B}[2m to go back)\u{1B}[0m")
            print()
        }

        // Summary of previously answered steps
        for i in 0 ..< currentIndex {
            let prev = steps[i]
            guard prev.isVisible(state: state) else { continue }
            if let value = prev.summaryValue(state: state), !value.isEmpty {
                print("  \(prev.title): \(value)")
            }
        }
        if currentIndex > 0 {
            print("  \u{2500}")
            print()
        }
    }

    private static func renderSummary(title: String, steps: [any WizardStep], state: WizardState) {
        PromptEngine.clearScreen()

        // Header
        let summaryLabel = "Summary"
        let padding = max(0, lineWidth - title.count - summaryLabel.count - 4)
        print("  \(separator)")
        print("  \(title)\(String(repeating: " ", count: padding))\(summaryLabel)")
        print("  \(separator)")
        print()

        // All values
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
                print("  \(padded)  \(value)")
            }
        }
        print()
    }

    // MARK: - Navigation Helpers

    /// Find the 1-based visible step number for the step at `index`.
    private static func visibleIndex(at index: Int, steps: [any WizardStep], state: WizardState) -> Int {
        var count = 0
        for i in 0 ... index where steps[i].isVisible(state: state) {
            count += 1
        }
        return count
    }

    /// Count total visible steps.
    private static func visibleCount(steps: [any WizardStep], state: WizardState) -> Int {
        steps.count { $0.isVisible(state: state) }
    }

    /// Find the index of the previous visible step before `index`. Returns `index` if none found (stay on current).
    private static func previousVisibleIndex(before index: Int, steps: [any WizardStep], state: WizardState) -> Int {
        var i = index - 1
        while i >= 0 {
            if steps[i].isVisible(state: state) { return i }
            i -= 1
        }
        // No previous visible step — stay on current
        return index
    }
}
