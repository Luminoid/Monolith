import Foundation

enum ReadmeGenerator {
    static func generateForApp(config: AppConfig) -> String {
        var sections: [String] = []

        sections.append("# \(config.name)")
        sections.append("> iOS app scaffolded with [Monolith](https://github.com/Luminoid/Monolith).")

        // Getting Started
        var gettingStarted = ["## Getting Started", ""]
        if config.hasDevTooling {
            var setupLines = ["brew bundle"]
            if config.hasGitHooks {
                setupLines.append("make setup-hooks")
            }
            gettingStarted.append("```bash")
            gettingStarted.append(contentsOf: setupLines)
            gettingStarted.append("```")
            gettingStarted.append("")
        } else if config.hasGitHooks {
            gettingStarted.append("```bash")
            gettingStarted.append("git config core.hooksPath Scripts/git-hooks")
            gettingStarted.append("```")
            gettingStarted.append("")
        }
        if config.resolvedFeatures.contains(.fastlane) {
            gettingStarted.append("```bash")
            gettingStarted.append("bundle install")
            gettingStarted.append("```")
            gettingStarted.append("")
        }
        switch config.projectSystem {
        case .xcodeProj:
            gettingStarted.append("Open in Xcode:")
            gettingStarted.append("")
            gettingStarted.append("```bash")
            gettingStarted.append("open \(config.name).xcodeproj")
            gettingStarted.append("```")
        case .xcodeGen:
            gettingStarted.append("```bash")
            gettingStarted.append("xcodegen generate")
            gettingStarted.append("open \(config.name).xcodeproj")
            gettingStarted.append("```")
        case .spm:
            gettingStarted.append("```bash")
            gettingStarted.append("swift build")
            gettingStarted.append("```")
        }
        sections.append(gettingStarted.joined(separator: "\n"))

        // Build & Test
        var buildTest = ["## Build & Test", ""]
        switch config.projectSystem {
        case .xcodeProj, .xcodeGen:
            buildTest.append("```bash")
            buildTest.append("make build")
            buildTest.append("make test")
            if config.hasDevTooling {
                buildTest.append("make check  # SwiftLint + SwiftFormat")
            }
            buildTest.append("```")
        case .spm:
            buildTest.append("```bash")
            buildTest.append("swift build")
            buildTest.append("swift test")
            buildTest.append("```")
        }
        sections.append(buildTest.joined(separator: "\n"))

        // Tech Stack
        var techStack = ["## Tech Stack", ""]
        techStack.append("- **Platform**: iOS \(config.deploymentTarget)+")
        techStack.append("- **UI Framework**: UIKit (programmatic)")
        if config.hasSwiftData { techStack.append("- **Data**: SwiftData") }
        if config.hasLumiKit { techStack.append("- **Design System**: LumiKit") }
        if config.hasSnapKit { techStack.append("- **Layout**: SnapKit") }
        if config.hasLottie { techStack.append("- **Animations**: Lottie") }
        if config.hasLookin { techStack.append("- **UI Debugging**: LookinServer (iOS only)") }
        if config.hasCombine { techStack.append("- **Reactive**: Combine") }
        sections.append(techStack.joined(separator: "\n"))

        // Next Steps
        var nextSteps = ["## Next Steps", ""]
        var steps: [String] = []
        if config.hasDevTooling {
            steps.append("Install dev tools: `brew bundle`")
        }
        if config.hasGitHooks {
            steps.append(
                config.hasDevTooling
                    ? "Set up git hooks: `make setup-hooks`"
                    : "Set up git hooks: `git config core.hooksPath Scripts/git-hooks`"
            )
        }
        steps.append("Replace `SampleItem.swift` with your domain models")
        if config.hasSwiftData {
            steps.append("Update `AppDelegate.swift` SwiftData schema with your models")
        }
        steps.append("Build feature view controllers in `Features/`")
        for (index, step) in steps.enumerated() {
            nextSteps.append("\(index + 1). \(step)")
        }
        sections.append(nextSteps.joined(separator: "\n"))

        return sections.joined(separator: "\n\n") + "\n"
    }

    static func generateForPackage(config: PackageConfig) -> String {
        var sections: [String] = []

        sections.append("# \(config.name)")
        sections.append("> Swift Package scaffolded with [Monolith](https://github.com/Luminoid/Monolith).")

        // Installation — first thing a downstream consumer needs. Skipped for
        // proprietary packages that aren't meant for external consumption.
        if config.licenseType != .proprietary {
            let org = githubOrgSlug(author: config.author)
            var install = ["## Installation", "", "Add to your `Package.swift`:", "", "```swift", "dependencies: ["]
            install.append("    .package(url: \"https://github.com/\(org)/\(config.name).git\", from: \"0.1.0\"),")
            install.append("]")
            install.append("```")
            sections.append(install.joined(separator: "\n"))
        }

        // Development setup. Header reads "Development" rather than "Local
        // Development" — adopters of a published package read this as the
        // contributor entry point, not a "vs. cloud" distinction.
        var setup = ["## Development", ""]
        if config.hasDevTooling {
            setup.append("```bash")
            setup.append("brew bundle             # install swiftlint + swiftformat")
            if config.hasGitHooks {
                setup.append("make setup-hooks        # wire pre-commit lint + format")
            }
            setup.append("```")
            setup.append("")
        } else if config.hasGitHooks {
            setup.append("```bash")
            setup.append("git config core.hooksPath Scripts/git-hooks")
            setup.append("```")
            setup.append("")
        }
        setup.append("Build & test:")
        setup.append("")
        // When the Makefile is generated (hasDevTooling), prefer the make
        // shorthands — they wrap the same xcodebuild invocation but stay in
        // sync if we change flags. Falls back to the raw command for packages
        // without a Makefile.
        if config.hasDevTooling {
            setup.append("```bash")
            setup.append("make build")
            setup.append("make test")
            setup.append("```")
        } else if config.hasDefaultIsolation {
            // The scheme is `<Name>-Package` (umbrella) for mixed-target
            // packages — covers every target with one xcodebuild call. Falls
            // back to the named `<Name>` scheme for single-library packages.
            let scheme = config.xcodeBuildScheme
            setup.append("```bash")
            setup.append("xcodebuild build -scheme \(scheme) -destination '\(Defaults.simulatorDestination)' -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO")
            setup.append("xcodebuild test -scheme \(scheme) -destination '\(Defaults.simulatorDestination)' -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO")
            setup.append("```")
        } else {
            setup.append("```bash")
            setup.append("swift build")
            setup.append("swift test")
            setup.append("```")
        }
        sections.append(setup.joined(separator: "\n"))

        // Targets — split libraries from executables since they have different
        // semantics (libraries are imported, executables are run).
        let libraries = config.targets.filter { !$0.isExecutable }
        let executables = config.targets.filter(\.isExecutable)
        let showIsolation = config.hasDefaultIsolation

        if !libraries.isEmpty {
            var libs = ["## Libraries", ""]
            if showIsolation {
                libs.append("| Target | Dependencies | Default isolation |")
                libs.append("|--------|--------------|-------------------|")
            } else {
                libs.append("| Target | Dependencies |")
                libs.append("|--------|--------------|")
            }
            for target in libraries {
                let deps = target.dependencies.isEmpty ? "—" : target.dependencies.joined(separator: ", ")
                if showIsolation {
                    let iso = config.mainActorTargets.contains(target.name) ? "MainActor" : "—"
                    libs.append("| \(target.name) | \(deps) | \(iso) |")
                } else {
                    libs.append("| \(target.name) | \(deps) |")
                }
            }
            sections.append(libs.joined(separator: "\n"))
        }

        if !executables.isEmpty {
            var execs = ["## Executables", "", "| Binary | Dependencies | Run |", "|--------|--------------|-----|"]
            for target in executables {
                let deps = target.dependencies.isEmpty ? "—" : target.dependencies.joined(separator: ", ")
                execs.append("| `\(target.name)` | \(deps) | `swift run \(target.name)` |")
            }
            sections.append(execs.joined(separator: "\n"))
        }

        // License footer — terse, matches LumiKit's README closing.
        // Links CHANGELOG alongside LICENSE so adopters discover the changelog
        // (both files are written by the same `licenseChangelog` feature, so
        // the link is always valid when the section is emitted).
        if config.features.contains(.licenseChangelog), !config.author.isEmpty, config.author != "Author" {
            sections.append("## License\n\n\(config.licenseType.displayName). © \(config.author). See [LICENSE](LICENSE) and [CHANGELOG](CHANGELOG.md).")
        }

        return sections.joined(separator: "\n\n") + "\n"
    }

    static func generateForCLI(config: CLIConfig) -> String {
        var sections: [String] = []

        sections.append("# \(config.name)")
        sections.append("> Swift CLI scaffolded with [Monolith](https://github.com/Luminoid/Monolith).")

        // Getting Started
        var gettingStarted = ["## Getting Started", ""]
        if config.hasDevTooling {
            var setupLines = ["brew bundle"]
            if config.hasGitHooks {
                setupLines.append("make setup-hooks")
            }
            gettingStarted.append("```bash")
            gettingStarted.append(contentsOf: setupLines)
            gettingStarted.append("```")
            gettingStarted.append("")
        } else if config.hasGitHooks {
            gettingStarted.append("```bash")
            gettingStarted.append("git config core.hooksPath Scripts/git-hooks")
            gettingStarted.append("```")
            gettingStarted.append("")
        }
        gettingStarted.append("```bash")
        gettingStarted.append("swift build")
        gettingStarted.append("swift run \(config.name)")
        gettingStarted.append("```")
        sections.append(gettingStarted.joined(separator: "\n"))

        // Next Steps
        if config.hasDevTooling || config.hasGitHooks {
            var nextSteps = ["## Next Steps", ""]
            var steps: [String] = []
            if config.hasDevTooling {
                steps.append("Install dev tools: `brew bundle`")
            }
            if config.hasGitHooks {
                steps.append(
                    config.hasDevTooling
                        ? "Set up git hooks: `make setup-hooks`"
                        : "Set up git hooks: `git config core.hooksPath Scripts/git-hooks`"
                )
            }
            for (index, step) in steps.enumerated() {
                nextSteps.append("\(index + 1). \(step)")
            }
            sections.append(nextSteps.joined(separator: "\n"))
        }

        return sections.joined(separator: "\n\n") + "\n"
    }

    // MARK: - Helpers

    /// Derive a GitHub-org-style slug from the author name.
    ///
    /// GitHub usernames/orgs are alphanumeric + hyphens. Case is preserved —
    /// GitHub is case-insensitive on lookup but case-preserving on display, so
    /// "Luminoid/Causeway" reads correctly while "luminoid/Causeway" would
    /// redirect via 301 on first clone (working, but jarring in docs).
    ///
    /// The Installation block's `<your-org>` placeholder is jarring when
    /// Monolith already knows the author from git, so we replace it with a
    /// best-effort slug. Falls back to `<your-org>` when:
    /// - `author` is empty, the default literal "Author", or the SPM-config
    ///   "Test" placeholder used in test fixtures
    /// - slugging strips everything (non-ASCII-only name)
    ///
    /// The slug isn't guaranteed to match the adopter's actual GitHub handle
    /// — it's a sensible default that's still easy to find-and-replace if
    /// wrong. Better than `<your-org>` in the common case.
    static func githubOrgSlug(author: String) -> String {
        let placeholders: Set = ["", "Author", "Test"]
        guard !placeholders.contains(author) else { return "<your-org>" }

        // Replace spaces with hyphens, drop characters outside [A-Za-z0-9-].
        // Case is preserved (see doc-comment) so "Luminoid" stays "Luminoid".
        let collapsed = author.replacingOccurrences(of: " ", with: "-")
        let filtered = collapsed.unicodeScalars.filter { scalar in
            (scalar >= "a" && scalar <= "z")
                || (scalar >= "A" && scalar <= "Z")
                || (scalar >= "0" && scalar <= "9")
                || scalar == "-"
        }
        let slug = String(String.UnicodeScalarView(filtered))

        // Trim leading/trailing hyphens and collapse runs of hyphens.
        let trimmed = slug
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            .components(separatedBy: "-")
            .filter { !$0.isEmpty }
            .joined(separator: "-")

        return trimmed.isEmpty ? "<your-org>" : trimmed
    }
}
