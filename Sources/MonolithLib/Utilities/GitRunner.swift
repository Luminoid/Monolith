import Foundation

/// The git calls `new` and `add` make: the author name for LICENSE and the
/// wizard, and the repository setup after generation.
enum GitRunner {
    /// The author a project gets when git has no `user.name`.
    static let placeholderAuthor = "Author"

    /// `git config user.name`, or nil when it isn't set.
    static func authorName() -> String? {
        ShellRunner.runCapturingStdout(
            executable: "/usr/bin/git",
            arguments: ["config", "user.name"]
        )
    }

    /// `authorName()`, or `placeholderAuthor` when git has none.
    static func authorNameOrPlaceholder() -> String {
        authorName() ?? placeholderAuthor
    }

    /// The git steps `initRepository` runs, in order. Each label is the
    /// command a user can run by hand when a step fails.
    static func initSteps(hasGitHooks: Bool) -> [(args: [String], label: String)] {
        var steps: [(args: [String], label: String)] = [
            (["init"], "git init"),
            (["add", "."], "git add ."),
            (["commit", "-m", "Initial commit"], "git commit -m \"Initial commit\""),
        ]
        if hasGitHooks {
            steps.append((["config", "core.hooksPath", "Scripts/git-hooks"], "git config core.hooksPath Scripts/git-hooks"))
        }
        return steps
    }

    /// Initialize a git repository and create an initial commit. When
    /// `hasGitHooks` is true, also points `core.hooksPath` at the shared
    /// hooks. A failed step stops the chain; the warning names it and the
    /// steps that did not run (a commit without a git identity, for example,
    /// leaves `core.hooksPath` unset). Returns whether every step ran.
    @discardableResult
    static func initRepository(at path: String, hasGitHooks: Bool = false) -> Bool {
        let steps = initSteps(hasGitHooks: hasGitHooks)
        for (index, step) in steps.enumerated() {
            let ok = ShellRunner.runDiscardingOutput(
                executable: "/usr/bin/git",
                arguments: step.args,
                cwd: path,
                failureLabel: "\(step.label) failed"
            )
            guard ok else {
                let notRun = steps[(index + 1)...].map(\.label)
                if !notRun.isEmpty {
                    let pronoun = notRun.count == 1 ? "it" : "them"
                    Console.warn("Not run after that failure: \(notRun.joined(separator: "; ")). Run \(pronoun) by hand in \(path).")
                }
                return false
            }
        }

        print("  \(UISymbols.check) git repository initialized")
        return true
    }
}
