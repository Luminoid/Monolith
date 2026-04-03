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
        if config.hasDefaultIsolation {
            gettingStarted.append("```bash")
            gettingStarted.append("xcodebuild build -scheme \(config.name)-Package -destination '\(Defaults.simulatorDestination)' CODE_SIGNING_ALLOWED=NO")
            gettingStarted.append("xcodebuild test -scheme \(config.name)-Package -destination '\(Defaults.simulatorDestination)' CODE_SIGNING_ALLOWED=NO")
            gettingStarted.append("```")
        } else {
            gettingStarted.append("```bash")
            gettingStarted.append("swift build")
            gettingStarted.append("swift test")
            gettingStarted.append("```")
        }
        sections.append(gettingStarted.joined(separator: "\n"))

        // Targets
        if !config.targets.isEmpty {
            var targets = ["## Targets", ""]
            targets.append("| Target | Dependencies |")
            targets.append("|--------|-------------|")
            for target in config.targets {
                let deps = target.dependencies.isEmpty ? "—" : target.dependencies.joined(separator: ", ")
                targets.append("| \(target.name) | \(deps) |")
            }
            sections.append(targets.joined(separator: "\n"))
        }

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
}
