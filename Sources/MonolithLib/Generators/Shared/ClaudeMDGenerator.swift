import Foundation

enum ClaudeMDGenerator {
    static func generateForApp(config: AppConfig) -> String {
        let date = formattedDate()
        var sections: [String] = []

        sections.append("""
        # \(config.name) — Claude Code Guide

        > iOS app built with UIKit (programmatic UI).
        > **Inherits general Swift/UIKit standards from [workspace CLAUDE.md](../../.claude/CLAUDE.md).** This file contains \(config.name)-specific rules only.
        """)

        // Tech stack
        var stack: [String] = ["- **Platform**: iOS \(config.deploymentTarget)+", "- **UI**: UIKit (programmatic, storyboard-free)"]
        if config.hasSwiftData { stack.append("- **Data**: SwiftData") }
        if config.hasLumiKit { stack.append("- **Design System**: LumiKit (LMKThemeManager)") }
        if config.hasSnapKit { stack.append("- **Layout**: SnapKit") }
        if config.hasLottie { stack.append("- **Animations**: Lottie") }
        if config.hasLookin { stack.append("- **UI Debugging**: LookinServer (iOS only, debug builds)") }
        if config.hasCombine { stack.append("- **Reactive**: Combine") }
        if config.hasDarkMode { stack.append("- **Appearance**: Light + Dark mode") }
        sections.append(stack.joined(separator: "\n"))

        sections.append("---")

        // Build & Test
        var buildSection = ["## Build & Test", ""]
        switch config.projectSystem {
        case .xcodeProj:
            buildSection.append("```bash")
            buildSection.append("open \(config.name).xcodeproj          # Open in Xcode")
            buildSection.append("make build                        # CLI build")
            buildSection.append("make test                         # CLI test")
            if config.hasDevTooling {
                let checkBlurb = config.hasLocalization
                    ? "# SwiftLint + SwiftFormat + xcstrings audit"
                    : "# SwiftLint + SwiftFormat"
                buildSection.append("make check                        \(checkBlurb)")
            }
            buildSection.append("```")
        case .xcodeGen:
            buildSection.append("```bash")
            buildSection.append("xcodegen generate")
            buildSection.append("make build")
            buildSection.append("make test")
            if config.hasDevTooling {
                buildSection.append("make check  # SwiftLint + SwiftFormat")
            }
            buildSection.append("```")
        case .spm:
            buildSection.append("```bash")
            buildSection.append("swift build")
            buildSection.append("swift test")
            buildSection.append("```")
            if config.hasDevTooling {
                buildSection.append("")
                buildSection.append("```bash")
                buildSection.append("make check  # SwiftLint + SwiftFormat")
                buildSection.append("```")
            }
        }
        sections.append(buildSection.joined(separator: "\n"))

        // Architecture. Only claim patterns the scaffold actually emits —
        // claiming "MVVM" for a generator that ships a plain `ViewController`
        // misleads readers (and gets ignored once they read the source).
        // Navigation likewise reflects the actual root VC the generator wires
        // up in SceneDelegate.
        var arch = ["## Architecture", ""]
        arch.append("- **Pattern**: MVC scaffold (move to MVVM as features grow — extract `\(config.name)ViewModel` types from view controllers when state coupling becomes painful)")
        let navWrapperType = config.hasLumiKit ? "LMKNavigationController" : "UINavigationController"
        arch.append("- **Navigation**: \(config.hasTabs ? "UITabBarController + \(navWrapperType) per tab" : navWrapperType)")
        if config.hasSwiftData {
            arch.append("- **Data Layer**: SwiftData ModelContainer (created in AppDelegate, injected via SceneDelegate)")
        }
        if config.hasLumiKit {
            arch.append("- **Theme**: \(config.name)Theme conforms to LMKTheme, configured in AppDelegate")
        }
        sections.append(arch.joined(separator: "\n"))

        sections.append("---\n\n*Optimized for Claude Code • Last updated: \(date)*")

        return sections.joined(separator: "\n\n") + "\n"
    }

    static func generateForPackage(config: PackageConfig) -> String {
        let date = formattedDate()
        var sections: [String] = []

        let targetNames = config.targets.map(\.name).joined(separator: ", ")

        sections.append("""
        # \(config.name) — Claude Code Guide

        > Swift Package with targets: \(targetNames).
        > **Inherits general Swift/UIKit standards from [workspace CLAUDE.md](../../.claude/CLAUDE.md).** This file contains \(config.name)-specific rules only.
        """)

        // Targets — split libraries from executables. The "Default isolation"
        // column reflects each target's OWN `defaultIsolation(MainActor.self)`
        // setting, not transitive MainActor exposure from dependencies; "—"
        // means non-isolated (the target's types are nonisolated by default).
        // The "Kind" column distinguishes test-helper libs (which are
        // consumed by adopter test targets and get no auto-generated test
        // target of their own) from regular libraries.
        let libraries = config.targets.filter { !$0.isExecutable }
        let executables = config.targets.filter(\.isExecutable)
        let hasTestHelpers = !config.testHelperTargets.isEmpty

        if !libraries.isEmpty {
            var libs: [String] = ["## Libraries", ""]
            if hasTestHelpers {
                libs.append("| Target | Kind | Dependencies | Default isolation |")
                libs.append("|--------|------|--------------|-------------------|")
            } else {
                libs.append("| Target | Dependencies | Default isolation |")
                libs.append("|--------|--------------|-------------------|")
            }
            for target in libraries {
                let deps = target.dependencies.isEmpty ? "—" : target.dependencies.joined(separator: ", ")
                let iso = config.mainActorTargets.contains(target.name) ? "MainActor" : "—"
                if hasTestHelpers {
                    let kind = config.testHelperTargets.contains(target.name) ? "Test helper" : "Library"
                    libs.append("| \(target.name) | \(kind) | \(deps) | \(iso) |")
                } else {
                    libs.append("| \(target.name) | \(deps) | \(iso) |")
                }
            }
            if hasTestHelpers {
                libs.append("")
                libs.append("> Test-helper libraries (`Test helper` kind) are consumed by adopter test")
                libs.append("> targets via `@testable import` and have no auto-generated test target")
                libs.append("> of their own.")
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

        sections.append("---")

        // Build & Test
        var buildSection = ["## Build & Test", ""]
        if config.hasDefaultIsolation {
            // Mixed-target packages use the `<Name>-Package` umbrella scheme
            // so one xcodebuild covers libs + executables + test-helpers.
            // Single-library packages stay on the named `<Name>` scheme.
            let scheme = config.xcodeBuildScheme
            buildSection.append("Targets with MainActor isolation (UIKit) require `xcodebuild`:")
            buildSection.append("")
            buildSection.append("```bash")
            buildSection.append("xcodebuild build -scheme \(scheme) -destination '\(Defaults.simulatorDestination)' -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO")
            buildSection.append("xcodebuild test -scheme \(scheme) -destination '\(Defaults.simulatorDestination)' -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO")
            buildSection.append("```")
            // When the umbrella scheme is in use, document the reason so
            // future readers don't "simplify" Package.swift in a way that
            // drops the auto-generated umbrella and silently breaks the
            // build command (no error — `xcodebuild` would just fail with
            // "scheme not found"). The reason is tailored to the actual
            // cause (executables vs. test-helpers vs. both) so the
            // explainer doesn't carry irrelevant alternatives.
            if scheme.hasSuffix("-Package") {
                let hasEponymousTarget = config.targets.contains { $0.name == config.name }
                let reason = switch (config.hasExecutables, !config.testHelperTargets.isEmpty) {
                case (true, true):
                    "this package mixes executables, test-helper libs, and MainActor libs"
                case (true, false):
                    "this package has executable sibling targets alongside libraries"
                case (false, true):
                    "this package has a test-helper library that needs to build alongside the main libraries"
                case (false, false):
                    // Reached when no target is named like the package —
                    // Xcode then generates no `<Name>` scheme at all.
                    "no target is named `\(config.name)`, so Xcode generates no `\(config.name)` scheme"
                }
                buildSection.append("")
                buildSection.append("> The `\(scheme)` umbrella scheme is required because \(reason).")
                if hasEponymousTarget {
                    buildSection.append("> One `xcodebuild` invocation covers every target. Don't replace it with the named")
                    buildSection.append("> `\(config.name)` scheme, which only builds the main library.")
                } else {
                    buildSection.append("> One `xcodebuild` invocation covers every target. `-scheme \(config.name)` would fail")
                    buildSection.append("> with \"does not contain a scheme named \(config.name)\"; the per-target schemes each build only their own target.")
                }
            }
            buildSection.append("")
            // Bare `swift build` / `swift test` compile EVERY target, so once
            // any target is MainActor-isolated (UIKit) — or any wired
            // dependency is UIKit-based, as LumiKitUI is — they fail on a
            // macOS host with "no such module 'UIKit'". Per-target builds
            // still work for the Foundation-only targets; `swift test` has no
            // per-target equivalent, since `--filter` selects which tests RUN
            // but still builds the whole package.
            let foundationTargets = config.targets
                .filter { !config.mainActorTargets.contains($0.name) && !$0.isExecutable }
            if let first = foundationTargets.first {
                let names = foundationTargets.map { "`\($0.name)`" }.joined(separator: ", ")
                buildSection.append("Foundation-only targets (\(names)) build standalone:")
                buildSection.append("")
                buildSection.append("```bash")
                buildSection.append("swift build --target \(first.name)")
                buildSection.append("```")
                buildSection.append("")
            }
            buildSection
                .append("Bare `swift build` / `swift test` compile every target, including the UIKit ones, so they fail on a macOS host. Use `xcodebuild` above for anything that spans targets.")
        } else {
            buildSection.append("```bash")
            buildSection.append("swift build")
            buildSection.append("swift test")
            buildSection.append("```")
        }

        // Run snippet for executables — adopters need `swift run <name>`
        // alongside the build/test commands.
        if !executables.isEmpty {
            buildSection.append("")
            buildSection.append("Run executable sibling target\(executables.count == 1 ? "" : "s"):")
            buildSection.append("")
            buildSection.append("```bash")
            for target in executables {
                buildSection.append("swift run \(target.name)")
            }
            buildSection.append("```")
        }

        if config.hasDevTooling {
            buildSection.append("")
            buildSection.append("```bash")
            buildSection.append("make check  # SwiftLint + SwiftFormat")
            buildSection.append("```")
        }
        sections.append(buildSection.joined(separator: "\n"))

        sections.append("---\n\n*Optimized for Claude Code • Last updated: \(date)*")

        return sections.joined(separator: "\n\n") + "\n"
    }

    static func generateForCLI(config: CLIConfig) -> String {
        let date = formattedDate()

        return """
        # \(config.name) — Claude Code Guide

        > Swift CLI tool.
        > **Inherits general Swift/UIKit standards from [workspace CLAUDE.md](../../.claude/CLAUDE.md).** This file contains \(config.name)-specific rules only.

        ## Build & Run

        ```bash
        swift build
        swift run \(config.name)
        ```

        ---

        *Optimized for Claude Code • Last updated: \(date)*

        """
    }

    // MARK: - Helpers

    private static func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
