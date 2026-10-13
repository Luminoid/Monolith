import Foundation

enum ReadmeGenerator {
    static func generateForApp(config: AppConfig) -> String {
        var sections: [String] = []

        sections.append("# \(config.name)")
        sections.append("> iOS app scaffolded with [Monolith](https://github.com/Luminoid/Monolith).")

        // Getting Started: one-time setup, then open the project. Apps are
        // XcodeGen or plain .xcodeproj projects.
        let tools = config.projectSystem == .xcodeGen ? "SwiftLint, SwiftFormat, and XcodeGen" : "SwiftLint + SwiftFormat"
        var setup = ProjectDocs.setupCommands(hasDevTooling: config.hasDevTooling, hasGitHooks: config.hasGitHooks, tools: tools)
        if config.hasFastlane {
            setup.append(ProjectDocs.Command("bundle install", "install fastlane"))
        }
        if config.projectSystem == .xcodeGen {
            setup.append(ProjectDocs.Command("xcodegen generate", "generate \(config.name).xcodeproj"))
        }
        setup.append(ProjectDocs.Command("open \(config.name).xcodeproj"))
        sections.append((["## Getting Started", ""] + ProjectDocs.bashBlock(setup)).joined(separator: "\n"))

        // Build & Test: the Makefile targets only when dev tooling wrote one.
        sections.append((["## Build & Test", ""] + ProjectDocs.bashBlock(ProjectDocs.appBuildCommands(config: config))).joined(separator: "\n"))

        sections.append(techStackSection(config: config))

        if config.hasCloudKit {
            sections.append(cloudKitSection(config: config))
        }

        // Next Steps. Setup lives in Getting Started; these are the first
        // code changes. The SampleItem placeholder differs by persistence
        // layer: SwiftData writes a `SampleItem.swift` @Model file; Core Data
        // seeds a `SampleItem` entity inside the `.xcdatamodeld`
        // (codegen=class, no Swift file). A minimal scaffold with neither
        // gets no step.
        var steps: [String] = []
        if config.hasSwiftData {
            steps.append("Replace `SampleItem` in `Core/Models/SampleItem.swift` with your domain models, and register each `@Model` type in `AppSchema.models` there")
        } else if config.hasCoreData {
            steps.append("Replace the `SampleItem` entity in `Core/Models/\(config.name).xcdatamodeld` with your domain model entities")
        }
        steps.append("Build feature view controllers in `Features/`")
        var nextSteps = ["## Next Steps", ""]
        for (index, step) in steps.enumerated() {
            nextSteps.append("\(index + 1). \(step)")
        }
        sections.append(nextSteps.joined(separator: "\n"))

        if let license = ProjectDocs.licenseSection(hasLicenseChangelog: config.hasLicenseChangelog, author: config.author, licenseType: config.licenseType) {
            sections.append(license)
        }

        return sections.joined(separator: "\n\n") + "\n"
    }

    static func generateForPackage(config: PackageConfig) -> String {
        var sections: [String] = []

        sections.append("# \(config.name)")
        sections.append("> Swift Package scaffolded with [Monolith](https://github.com/Luminoid/Monolith).")

        // Installation: the first thing a downstream consumer needs. Skipped
        // for proprietary packages that aren't meant for external consumption.
        if config.licenseType != .proprietary {
            let org = githubOrgSlug(author: config.author)
            var install = ["## Installation", "", "Add to your `Package.swift`:", "", "```swift", "dependencies: ["]
            install.append("    .package(url: \"https://github.com/\(org)/\(config.name).git\", from: \"0.1.0\"),")
            install.append("]")
            install.append("```")
            sections.append(install.joined(separator: "\n"))
        }

        // Development. Header reads "Development" rather than "Local
        // Development": adopters of a published package read this as the
        // contributor entry point, not a "vs. cloud" distinction.
        var development = ["## Development", ""]
        let setup = ProjectDocs.setupCommands(hasDevTooling: config.hasDevTooling, hasGitHooks: config.hasGitHooks)
        if !setup.isEmpty {
            development += ProjectDocs.bashBlock(setup)
            development.append("")
        }
        let scheme = ProjectDocs.xcodebuildScheme(for: config)
        if scheme != nil {
            development.append("This package needs UIKit, so it builds and tests with `xcodebuild` on the iOS Simulator rather than SwiftPM on the Mac.")
            development.append("")
        }
        development.append("Build & test:")
        development.append("")
        development += ProjectDocs.bashBlock(ProjectDocs.swiftPMBuildCommands(hasDevTooling: config.hasDevTooling, xcodebuildScheme: scheme))
        sections.append(development.joined(separator: "\n"))

        // Targets: libraries and executables in separate tables, since they
        // have different semantics (libraries are imported, executables run).
        sections += ProjectDocs.targetTables(config: config)

        if let license = ProjectDocs.licenseSection(hasLicenseChangelog: config.features.contains(.licenseChangelog), author: config.author, licenseType: config.licenseType) {
            sections.append(license)
        }

        return sections.joined(separator: "\n\n") + "\n"
    }

    static func generateForCLI(config: CLIConfig) -> String {
        var sections: [String] = []

        sections.append("# \(config.name)")
        sections.append("> Swift CLI scaffolded with [Monolith](https://github.com/Luminoid/Monolith).")

        let run = config.includeArgumentParser ? "swift run \(config.name) --help" : "swift run \(config.name)"
        sections.append((["## Usage", ""] + ProjectDocs.bashBlock([ProjectDocs.Command(run)])).joined(separator: "\n"))

        // Development mirrors the package README: setup once, then build & test.
        var development = ["## Development", ""]
        let setup = ProjectDocs.setupCommands(hasDevTooling: config.hasDevTooling, hasGitHooks: config.hasGitHooks)
        if !setup.isEmpty {
            development += ProjectDocs.bashBlock(setup)
            development.append("")
        }
        development.append("Build & test:")
        development.append("")
        development += ProjectDocs.bashBlock(ProjectDocs.swiftPMBuildCommands(hasDevTooling: config.hasDevTooling, xcodebuildScheme: nil))
        development.append("")
        let library = "`\(config.libraryName)` library (`\(CLIMainGenerator.librarySourcePath(config: config))`)"
        development.append("The command lives in the \(library); the `\(config.name)` executable only calls it, so tests can import it.")
        sections.append(development.joined(separator: "\n"))

        if let license = ProjectDocs.licenseSection(hasLicenseChangelog: config.features.contains(.licenseChangelog), author: config.author, licenseType: config.licenseType) {
            sections.append(license)
        }

        return sections.joined(separator: "\n\n") + "\n"
    }

    // MARK: - Helpers

    /// Render the README's Tech Stack list. Extracted out of `generateForApp`
    /// to keep that function under the cyclomatic-complexity ceiling — every
    /// feature-conditional bullet here adds a branch to the parent counter
    /// even though each is just a single `append`.
    private static func techStackSection(config: AppConfig) -> String {
        var lines: [String] = ["## Tech Stack", ""]
        lines.append("- **Platform**: iOS \(config.deploymentTarget)+")
        lines.append("- **UI Framework**: UIKit (programmatic)")
        if config.hasSwiftData { lines.append("- **Data**: SwiftData") }
        if config.hasCoreData { lines.append("- **Data**: Core Data") }
        if config.hasCloudKit { lines.append("- **Sync**: CloudKit") }
        if config.hasLumiKit { lines.append("- **Design System**: LumiKit") }
        if config.hasSnapKit { lines.append("- **Layout**: SnapKit") }
        if config.hasLottie { lines.append("- **Animations**: Lottie") }
        if config.hasLookin { lines.append("- **UI Debugging**: LookinServer (iOS only)") }
        if config.hasCombine { lines.append("- **Reactive**: Combine") }
        return lines.joined(separator: "\n")
    }

    /// A short CloudKit note. CLAUDE.md carries the full checklist when the
    /// project has one.
    private static func cloudKitSection(config: AppConfig) -> String {
        var text = "## CloudKit\n\nCloudKit can't remove or rename a record type or field once it's in the Production schema. "
            + "Before a TestFlight or App Store build, run a development build that saves every entity, "
            + "check the Development schema in the CloudKit Console, and deploy it to Production."
        if config.hasClaudeMD {
            text += " `.claude/CLAUDE.md` lists the safe schema changes."
        }
        return text
    }

    /// `https://github.com/<org>/<name>` when the author slugs to a real
    /// GitHub org, else nil (no link beats a link to `<your-org>`).
    static func githubRepositoryURL(author: String, name: String) -> String? {
        let org = githubOrgSlug(author: author)
        guard org != "<your-org>" else { return nil }
        return "https://github.com/\(org)/\(name)"
    }

    /// Derive a GitHub-org-style slug from the author name.
    ///
    /// GitHub usernames/orgs are alphanumeric + hyphens. Case is preserved —
    /// GitHub is case-insensitive on lookup but case-preserving on display, so
    /// "Acme/MultiLib" reads correctly while "acme/MultiLib" would redirect
    /// via 301 on first clone (working, but jarring in docs).
    ///
    /// The Installation block's `<your-org>` placeholder is jarring when
    /// Monolith already knows the author from git, so we replace it with a
    /// best-effort slug. Falls back to `<your-org>` when:
    /// - `author` is empty, the default literal "Author", or the SPM-config
    ///   "Test" placeholder used in test fixtures
    /// - the name has a non-ASCII letter: dropping it would leave a different
    ///   handle (`Zoë` → `Zo`), which reads right but points at someone else
    ///
    /// The slug isn't guaranteed to match the adopter's actual GitHub handle
    /// — it's a sensible default that's still easy to find-and-replace if
    /// wrong. Better than `<your-org>` in the common case.
    static func githubOrgSlug(author: String) -> String {
        let placeholders: Set = ["", "Author", "Test"]
        guard !placeholders.contains(author) else { return "<your-org>" }
        guard !author.unicodeScalars.contains(where: { !$0.isASCII && $0.properties.isAlphabetic }) else {
            return "<your-org>"
        }

        // Replace spaces with hyphens, drop characters outside [A-Za-z0-9-].
        // Case is preserved (see doc-comment) so "Acme" stays "Acme".
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
