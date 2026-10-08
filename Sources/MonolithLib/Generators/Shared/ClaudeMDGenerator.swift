import Foundation

/// The generated `.claude/CLAUDE.md`. Every guide is self-contained: generated
/// projects are often published, so nothing here may point outside the
/// project. Commands, tables, and the `make check` blurb come from
/// `ProjectDocs`, which the README renders from too.
enum ClaudeMDGenerator {
    static func generateForApp(config: AppConfig) -> String {
        let date = formattedDate()
        var sections: [String] = []

        sections.append("""
        # \(config.name) — Claude Code Guide

        > iOS app built with UIKit (programmatic UI).
        \(ProjectDocs.conventionsLine(name: config.name, hasDevTooling: config.hasDevTooling))
        """)

        // Tech stack
        var stack: [String] = ["- **Platform**: iOS \(config.deploymentTarget)+", "- **UI**: UIKit (programmatic, storyboard-free)"]
        if config.hasSwiftData { stack.append("- **Data**: SwiftData") }
        if config.hasCoreData { stack.append("- **Data**: Core Data") }
        if config.hasCloudKit { stack.append("- **Sync**: CloudKit") }
        if config.hasLumiKit {
            // The major version tells a reader which API generation the code uses.
            let major = DependencyVersion.lumiKit.prefix { $0 != "." }
            stack.append("- **Design System**: LumiKit \(major).x (`LMKTheme`, `LMKColor` and the other `LMK*` tokens)")
        }
        if config.hasSnapKit { stack.append("- **Layout**: SnapKit") }
        if config.hasLottie { stack.append("- **Animations**: Lottie") }
        if config.hasLookin { stack.append("- **UI Debugging**: LookinServer (iOS only, debug builds)") }
        if config.hasCombine { stack.append("- **Reactive**: Combine") }
        if config.hasDarkMode { stack.append("- **Appearance**: Light + Dark mode") }
        sections.append(stack.joined(separator: "\n"))

        sections.append("---")

        // Build & Test. Apps are XcodeGen or plain .xcodeproj projects; the
        // `make` targets exist only when dev tooling wrote the Makefile.
        var commands: [ProjectDocs.Command] = []
        if config.projectSystem == .xcodeGen {
            commands.append(ProjectDocs.Command("xcodegen generate", "regenerate \(config.name).xcodeproj from project.yml"))
        }
        commands.append(ProjectDocs.Command("open \(config.name).xcodeproj", "open in Xcode"))
        commands += ProjectDocs.appBuildCommands(config: config)
        sections.append((["## Build & Test", ""] + ProjectDocs.bashBlock(commands)).joined(separator: "\n"))

        // Architecture. Only claim patterns the scaffold actually emits —
        // claiming "MVVM" for a generator that ships a plain `ViewController`
        // misleads readers (and gets ignored once they read the source).
        // Navigation likewise reflects the actual root VC the generator wires
        // up in SceneDelegate.
        var arch = ["## Architecture", ""]
        arch.append("- **Pattern**: MVC scaffold (move to MVVM as features grow: extract `\(config.name)ViewModel` types from view controllers when state coupling becomes painful)")
        let navWrapperType = config.hasLumiKit ? "LMKNavigationController" : "UINavigationController"
        let tabBarType = config.hasLumiKit ? "LMKTabBarController (tabs declared as `LMKTab`s)" : "UITabBarController"
        arch.append("- **Navigation**: \(config.hasTabs ? "\(tabBarType) + \(navWrapperType) per tab" : navWrapperType)")
        if config.hasSwiftData {
            arch.append("- **Data Layer**: SwiftData ModelContainer (created in AppDelegate, injected via SceneDelegate)")
        }
        if config.hasLumiKit {
            let member = ThemeGenerator.themeMemberName(for: config)
            arch.append("- **Theme**: `LMKTheme.\(member)` in `Shared/Design/\(config.name)Theme.swift`, applied in AppDelegate with `LMKTheme.apply(.\(member))`")
        }
        sections.append(arch.joined(separator: "\n"))

        if config.hasCloudKit {
            sections.append(cloudKitSchemaSection(config: config))
        }

        sections.append("---\n\n*Optimized for Claude Code • Last updated: \(date)*")

        return sections.joined(separator: "\n\n") + "\n"
    }

    /// `logCore` is where the package carries the shared logging core, when
    /// it does (`LogCoreGenerator.placement(for:)` of the generated config).
    /// It's a parameter rather than derived here because `monolith add
    /// claudeMD` writes this guide into existing packages that may not carry
    /// the core.
    static func generateForPackage(config: PackageConfig, logCore: LogCoreGenerator.Placement? = nil) -> String {
        let date = formattedDate()
        var sections: [String] = []

        let targetNames = config.targets.map(\.name).joined(separator: ", ")

        sections.append("""
        # \(config.name) — Claude Code Guide

        > Swift Package with targets: \(targetNames).
        \(ProjectDocs.conventionsLine(name: config.name, hasDevTooling: config.hasDevTooling))
        """)

        sections += ProjectDocs.targetTables(config: config)

        sections.append("---")

        sections.append(packageBuildSection(config: config))

        if let logCore {
            sections.append(loggingSection(logCore))
        }

        sections.append("---\n\n*Optimized for Claude Code • Last updated: \(date)*")

        return sections.joined(separator: "\n\n") + "\n"
    }

    /// `includeLayout` describes the library + thin-executable layout
    /// `CLIProjectGenerator` writes. Off by default because `monolith add
    /// claudeMD` writes this guide into existing CLIs whose layout is unknown.
    static func generateForCLI(config: CLIConfig, includeLayout: Bool = false) -> String {
        let date = formattedDate()
        var sections: [String] = []

        sections.append("""
        # \(config.name) — Claude Code Guide

        > Swift command-line tool.
        \(ProjectDocs.conventionsLine(name: config.name, hasDevTooling: config.hasDevTooling))
        """)

        if includeLayout {
            sections.append(cliLayoutSection(config: config))
        }

        var commands = ProjectDocs.swiftPMBuildCommands(hasDevTooling: config.hasDevTooling, xcodebuildScheme: nil)
        commands.append(ProjectDocs.Command(config.includeArgumentParser ? "swift run \(config.name) --help" : "swift run \(config.name)"))
        sections.append((["## Build & Test", ""] + ProjectDocs.bashBlock(commands)).joined(separator: "\n"))

        sections.append("---\n\n*Optimized for Claude Code • Last updated: \(date)*")

        return sections.joined(separator: "\n\n") + "\n"
    }

    // MARK: - Sections

    /// Where a generated CLI's code lives, and why the logic stays in the library.
    private static func cliLayoutSection(config: CLIConfig) -> String {
        let entryPoint = config.includeArgumentParser
            ? "\(config.typeName).main()"
            : "\(config.typeName).run(arguments:)"
        let command = config.includeArgumentParser
            ? "the `\(config.typeName)` ArgumentParser command; add options, flags, and subcommands here"
            : "the `\(config.typeName)` command"
        return """
        ## Layout

        - `\(CLIMainGenerator.librarySourcePath(config: config))`: \(command).
        - `\(CLIMainGenerator.mainPath(config: config))`: the `\(config.name)` executable's entry point; it only calls `\(entryPoint)`.
        - `Tests/\(config.libraryName)Tests/`: Swift Testing suite, `@testable import \(config.libraryName)`.

        Keep the logic in `\(config.libraryName)`: tests can't import an executable target.
        """
    }

    /// The package's Build & Test section. Packages that need UIKit build on
    /// the iOS Simulator through xcodebuild; the rest use SwiftPM.
    private static func packageBuildSection(config: PackageConfig) -> String {
        let executables = config.targets.filter(\.isExecutable)
        let scheme = ProjectDocs.xcodebuildScheme(for: config)
        var lines = ["## Build & Test", ""]

        if scheme != nil {
            lines.append("This package needs UIKit (\(ProjectDocs.uikitReason(config: config))), so it builds and tests with `xcodebuild` on the iOS Simulator:")
            lines.append("")
        }
        lines += ProjectDocs.bashBlock(ProjectDocs.swiftPMBuildCommands(hasDevTooling: config.hasDevTooling, xcodebuildScheme: scheme))

        if let scheme {
            if config.hasDevTooling {
                // The raw invocation, for filters such as `-only-testing:`.
                lines.append("")
                lines.append("`make build` and `make test` run:")
                lines.append("")
                lines += ProjectDocs.bashBlock(ProjectDocs.xcodebuildCommands(scheme: scheme).map { ProjectDocs.Command($0) })
            }
            lines += umbrellaSchemeNote(config: config, scheme: scheme)
            lines.append("")
            // Bare `swift build` / `swift test` compile EVERY target, so once
            // any target needs UIKit they fail on a macOS host with "no such
            // module 'UIKit'". Per-target builds still work for the targets
            // that don't; `swift test` has no per-target equivalent, since
            // `--filter` selects which tests RUN but still builds the whole
            // package.
            let uikitTargets = ProjectDocs.uikitTargets(config: config)
            let foundationTargets = config.targets.filter { !uikitTargets.contains($0.name) && !$0.isExecutable }
            if let first = foundationTargets.first {
                let names = foundationTargets.map { "`\($0.name)`" }.joined(separator: ", ")
                lines.append("Foundation-only targets (\(names)) build standalone:")
                lines.append("")
                lines += ProjectDocs.bashBlock([ProjectDocs.Command("swift build --target \(first.name)")])
                lines.append("")
            }
            lines.append("Bare `swift build` / `swift test` compile every target, including the UIKit ones, so they fail on a macOS host. Use the commands above for anything that spans targets.")
        }

        // Run snippet for executables: adopters need `swift run <name>`
        // alongside the build/test commands.
        if !executables.isEmpty {
            lines.append("")
            lines.append("Run executable sibling target\(executables.count == 1 ? "" : "s"):")
            lines.append("")
            lines += ProjectDocs.bashBlock(executables.map { ProjectDocs.Command("swift run \($0.name)") })
        }

        return lines.joined(separator: "\n")
    }

    /// When the umbrella scheme is in use, document the reason so future
    /// readers don't "simplify" Package.swift in a way that drops the
    /// auto-generated umbrella and silently breaks the build command (no
    /// error, `xcodebuild` would just fail with "scheme not found"). The
    /// reason is tailored to the actual cause (executables vs. test-helpers
    /// vs. both) so the explainer doesn't carry irrelevant alternatives.
    private static func umbrellaSchemeNote(config: PackageConfig, scheme: String) -> [String] {
        guard scheme.hasSuffix("-Package") else { return [] }
        let hasEponymousTarget = config.targets.contains { $0.name == config.name }
        let reason = switch (config.hasExecutables, !config.testHelperTargets.isEmpty) {
        case (true, true):
            "this package mixes executables, test-helper libs, and MainActor libs"
        case (true, false):
            "this package has executable sibling targets alongside libraries"
        case (false, true):
            "this package has a test-helper library that needs to build alongside the main libraries"
        case (false, false):
            // Reached when no target is named like the package; Xcode then
            // generates no `<Name>` scheme at all.
            "no target is named `\(config.name)`, so Xcode generates no `\(config.name)` scheme"
        }
        var lines = ["", "> The `\(scheme)` umbrella scheme is required because \(reason)."]
        if hasEponymousTarget {
            lines.append("> One `xcodebuild` invocation covers every target. Don't replace it with the named")
            lines.append("> `\(config.name)` scheme, which only builds the main library.")
        } else {
            lines.append("> One `xcodebuild` invocation covers every target. `-scheme \(config.name)` would fail")
            lines.append("> with \"does not contain a scheme named \(config.name)\"; the per-target schemes each build only their own target.")
        }
        return lines
    }

    /// How to use the logging core `LogCoreGenerator` rendered into the package.
    private static func loggingSection(_ logCore: LogCoreGenerator.Placement) -> String {
        let log = "\(logCore.prefix)Log"
        var lines = [
            "## Logging",
            "",
            "`\(log)` (`\(logCore.sourcePath)`) is the package's logging core, a thin layer over `os.Logger`.",
            "",
            "- Add categories in `\(log)+Categories.swift`, one per area: `nonisolated static let network = \(log).Category(\"Network\")`.",
        ]
        if logCore.subsystem.hasPrefix("com.example.") {
            lines.append("- Replace the placeholder subsystem `\(logCore.subsystem)` (`\(log).subsystem`) with your own reverse-DNS identifier.")
        }
        lines += [
            "- Message text is public: static text, codes, ids, counts. User data (full URLs, paths, payloads) goes in `private:`, and errors go in `error:`, never `localizedDescription`.",
            "- On per-frame or polling paths, use `\(log).once(key, …)` so a repeating failure is written once.",
            "- Tests use `\(log).withScopedConfiguration(minimumLevel:handler:)` and never set `\(log).minimumLevel` or `\(log).handler` directly: "
                + "tests run in parallel and share the process-wide values.",
        ]
        return lines.joined(separator: "\n")
    }

    /// The CloudKit schema checklist. A deployed Production schema only grows,
    /// so the safe-change rules depend on the persistence layer.
    private static func cloudKitSchemaSection(config: AppConfig) -> String {
        let showCoreData = config.hasCoreData || !config.hasSwiftData
        let showSwiftData = config.hasSwiftData || !config.hasCoreData
        var lines = [
            "## CloudKit Schema",
            "",
            "Once a record type or field is deployed to the Production schema, CloudKit can't remove or rename it.",
            "",
        ]
        if showCoreData {
            lines.append("- **Core Data**: add a new model version before removing or renaming any entity or attribute, and never edit a shipped version in place.")
        }
        if showSwiftData {
            lines.append("- **SwiftData**: removing or renaming a property or `@Model` type is unsafe once the schema is deployed. Add new properties (optional, or with a default) instead.")
        }
        lines.append("- **Before TestFlight or the App Store**: run a development build that creates and saves every entity, "
            + "check the Development schema in the CloudKit Console, then deploy it to Production.")
        if showCoreData {
            lines.append("- To push the whole Core Data schema without exercising every entity, call `try container.initializeCloudKitSchema()` "
                + "on `\(config.name)CoreDataStack`'s container once from a `#if DEBUG` path, then remove the call.")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
