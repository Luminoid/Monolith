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
                buildSection.append("make check                        # SwiftLint + SwiftFormat")
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

        // Architecture
        var arch = ["## Architecture", ""]
        arch.append("- **Pattern**: MVVM")
        arch.append("- **Navigation**: \(config.hasTabs ? "UITabBarController + UINavigationController per tab" : "UINavigationController")")
        if config.hasSwiftData {
            arch.append("- **Data Layer**: SwiftData ModelContainer (created in AppDelegate, injected via SceneDelegate)")
        }
        if config.hasLumiKit {
            arch.append("- **Theme**: \(config.name)Theme conforms to LMKTheme, configured in AppDelegate")
        }
        sections.append(arch.joined(separator: "\n"))

        sections.append("---\n\n*Optimized for Claude Code \\u{2022} Last updated: \(date)*")

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

        // Targets table
        var table = ["## Targets", "", "| Target | Dependencies | MainActor |", "|--------|-------------|-----------|"]
        for target in config.targets {
            let deps = target.dependencies.isEmpty ? "—" : target.dependencies.joined(separator: ", ")
            let mainActor = config.mainActorTargets.contains(target.name) ? "Yes" : "No"
            table.append("| \(target.name) | \(deps) | \(mainActor) |")
        }
        sections.append(table.joined(separator: "\n"))

        sections.append("---")

        // Build & Test
        var buildSection = ["## Build & Test", ""]
        if config.hasDefaultIsolation {
            buildSection.append("Targets with MainActor isolation (UIKit) require `xcodebuild`:")
            buildSection.append("")
            buildSection.append("```bash")
            buildSection.append("xcodebuild build -scheme \(config.name)-Package -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO")
            buildSection.append("xcodebuild test -scheme \(config.name)-Package -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO")
            buildSection.append("```")
            buildSection.append("")
            buildSection.append("Foundation-only targets can use `swift build` / `swift test`.")
        } else {
            buildSection.append("```bash")
            buildSection.append("swift build")
            buildSection.append("swift test")
            buildSection.append("```")
        }
        if config.hasDevTooling {
            buildSection.append("")
            buildSection.append("```bash")
            buildSection.append("make check  # SwiftLint + SwiftFormat")
            buildSection.append("```")
        }
        sections.append(buildSection.joined(separator: "\n"))

        sections.append("---\n\n*Optimized for Claude Code \\u{2022} Last updated: \(date)*")

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

        *Optimized for Claude Code \\u{2022} Last updated: \(date)*

        """
    }

    // MARK: - Helpers

    private static func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
