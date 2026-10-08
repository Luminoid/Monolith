/// Text the generated CLAUDE.md and README share: build commands, the target
/// tables, what `make check` runs, the license footer. Both generators render
/// from here so the two documents can't disagree.
enum ProjectDocs {
    /// One line of a bash block, with an optional trailing comment.
    struct Command: Equatable {
        let command: String
        let comment: String?

        init(_ command: String, _ comment: String? = nil) {
            self.command = command
            self.comment = comment
        }
    }

    // MARK: - Blocks

    /// A fenced bash block. Comments line up one column past the widest
    /// commented command; uncommented lines (long xcodebuild invocations)
    /// don't widen the column.
    static func bashBlock(_ commands: [Command]) -> [String] {
        let width = commands.filter { $0.comment != nil }.map(\.command.count).max() ?? 0
        var lines = ["```bash"]
        for entry in commands {
            if let comment = entry.comment {
                let padding = String(repeating: " ", count: width - entry.command.count)
                lines.append("\(entry.command)\(padding)  # \(comment)")
            } else {
                lines.append(entry.command)
            }
        }
        lines.append("```")
        return lines
    }

    /// The CLAUDE.md blockquote line that says where general conventions live.
    /// Only names the lint configs when dev tooling wrote them.
    static func conventionsLine(name: String, hasDevTooling: Bool) -> String {
        hasDevTooling
            ? "> General Swift conventions are enforced by `.swiftlint.yml` and `.swiftformat`; this file holds \(name)-specific rules."
            : "> This file holds \(name)-specific rules."
    }

    /// What `make check` runs, mirroring `MakefileGenerator`'s `check` recipe.
    static func checkBlurb(hasLocalization: Bool = false, hasAppIconValidation: Bool = false) -> String {
        var parts = ["SwiftLint", "SwiftFormat"]
        if hasLocalization {
            parts.append("strings audit")
        }
        if hasAppIconValidation {
            parts.append("app icon validation")
        }
        return parts.joined(separator: " + ")
    }

    /// The one-time setup lines: Homebrew tools, then the pre-commit hook.
    /// `make setup-hooks` needs the Makefile that dev tooling writes; without
    /// it, the hooks path is set directly.
    static func setupCommands(hasDevTooling: Bool, hasGitHooks: Bool, tools: String = "SwiftLint + SwiftFormat") -> [Command] {
        var commands: [Command] = []
        if hasDevTooling {
            commands.append(Command("brew bundle", "install \(tools)"))
        }
        if hasGitHooks {
            commands.append(hasDevTooling
                ? Command("make setup-hooks", "wire the pre-commit lint + format hook")
                : Command("git config core.hooksPath Scripts/git-hooks", "wire the pre-commit hook"))
        }
        return commands
    }

    /// The README's `## License` footer, when `licenseChangelog` wrote LICENSE
    /// and CHANGELOG and the author is a real name.
    static func licenseSection(hasLicenseChangelog: Bool, author: String, licenseType: LicenseType) -> String? {
        guard hasLicenseChangelog, !author.isEmpty, author != "Author" else { return nil }
        return "## License\n\n\(licenseType.displayName). © \(author). See [LICENSE](LICENSE) and [CHANGELOG](CHANGELOG.md)."
    }

    // MARK: - Apps

    /// Build and test commands for an app: the Makefile targets when dev
    /// tooling wrote a Makefile, else the xcodebuild invocations they wrap.
    static func appBuildCommands(config: AppConfig) -> [Command] {
        if config.hasDevTooling {
            return [
                Command("make build", "build for the iOS Simulator"),
                Command("make test", "run the tests"),
                Command("make check", checkBlurb(hasLocalization: config.hasLocalization, hasAppIconValidation: config.hasAppIconValidation)),
            ]
        }
        let flags = "-project \(config.name).xcodeproj -scheme \(config.name) -destination '\(Defaults.simulatorDestination)' -quiet"
        // Serial when the Makefile's test recipe would be (`TestGenerator.appTestsRunSerially`).
        let testFlags = TestGenerator.appTestsRunSerially(config: config) ? "\(flags) -parallel-testing-enabled NO" : flags
        return [Command("xcodebuild build \(flags)"), Command("xcodebuild test \(testFlags)")]
    }

    // MARK: - Packages and CLIs

    /// Build and test commands for a SwiftPM project. With dev tooling, the
    /// Makefile targets lead; otherwise the commands they wrap. A non-nil
    /// `xcodebuildScheme` means the package needs UIKit and builds on the
    /// iOS Simulator.
    static func swiftPMBuildCommands(hasDevTooling: Bool, xcodebuildScheme: String?) -> [Command] {
        if hasDevTooling {
            let usesXcodebuild = xcodebuildScheme != nil
            return [
                Command("make build", usesXcodebuild ? "xcodebuild build, iOS Simulator" : "swift build"),
                Command("make test", usesXcodebuild ? "xcodebuild test, iOS Simulator" : "swift test"),
                Command("make check", checkBlurb()),
            ]
        }
        if let xcodebuildScheme {
            return xcodebuildCommands(scheme: xcodebuildScheme).map { Command($0) }
        }
        return [Command("swift build"), Command("swift test")]
    }

    /// The xcodebuild invocations a UIKit package builds and tests with; the
    /// generated Makefile runs the same flags.
    static func xcodebuildCommands(scheme: String) -> [String] {
        let flags = "-scheme \(scheme) -destination '\(Defaults.simulatorDestination)' -skipPackagePluginValidation -quiet CODE_SIGNING_ALLOWED=NO"
        return ["xcodebuild build \(flags)", "xcodebuild test \(flags)"]
    }

    /// The xcodebuild scheme when `config` builds through xcodebuild, else nil.
    static func xcodebuildScheme(for config: PackageConfig) -> String? {
        config.requiresXcodebuild ? config.xcodeBuildScheme : nil
    }

    /// Targets that need UIKit to build: MainActor-isolated targets, targets
    /// wired to a UIKit-only product (directly or through `packageDeps`), and
    /// targets that depend on one of those.
    static func uikitTargets(config: PackageConfig) -> Set<String> {
        let packageWideUIKit = config.packageDeps.contains { KnownPackages.uikitOnlyProducts.contains($0) }
        var bound = Set(config.targets.filter { target in
            packageWideUIKit
                || config.mainActorTargets.contains(target.name)
                || target.dependencies.contains { KnownPackages.uikitOnlyProducts.contains($0) }
        }.map(\.name))
        // Propagate through internal edges until nothing changes.
        var changed = true
        while changed {
            changed = false
            for target in config.targets where !bound.contains(target.name) && target.dependencies.contains(where: bound.contains) {
                bound.insert(target.name)
                changed = true
            }
        }
        return bound
    }

    /// Why a package needs UIKit, for the sentence that introduces its
    /// xcodebuild commands: the MainActor targets and the UIKit-only products.
    static func uikitReason(config: PackageConfig) -> String {
        var reasons: [String] = []
        let mainActor = config.targets.map(\.name).filter { config.mainActorTargets.contains($0) }
        if !mainActor.isEmpty {
            let noun = mainActor.count == 1 ? "target" : "targets"
            reasons.append("MainActor-isolated \(noun) \(codeList(mainActor))")
        }
        var products: [String] = []
        for dep in config.targets.flatMap(\.dependencies) + config.packageDeps
            where KnownPackages.uikitOnlyProducts.contains(dep) && !products.contains(dep) {
            products.append(dep)
        }
        if !products.isEmpty {
            let noun = products.count == 1 ? "dependency" : "dependencies"
            reasons.append("UIKit-only \(noun) \(codeList(products.sorted()))")
        }
        return reasons.joined(separator: "; ")
    }

    /// The `## Libraries` and `## Executables` sections. The `Default
    /// isolation` column reflects each target's OWN `defaultIsolation(MainActor.self)`
    /// setting, not transitive exposure through dependencies, and appears only
    /// when the package opts into default isolation. The `Kind` column
    /// separates test-helper libraries (imported by test targets, with no test
    /// target of their own) from regular ones.
    static func targetTables(config: PackageConfig) -> [String] {
        var sections: [String] = []
        let libraries = config.targets.filter { !$0.isExecutable }
        let executables = config.targets.filter(\.isExecutable)
        let showKind = !config.testHelperTargets.isEmpty
        let showIsolation = config.hasDefaultIsolation

        if !libraries.isEmpty {
            var columns = ["Target"]
            if showKind { columns.append("Kind") }
            columns.append("Dependencies")
            if showIsolation { columns.append("Default isolation") }

            var lines = ["## Libraries", ""]
            lines.append("| \(columns.joined(separator: " | ")) |")
            lines.append("|\(columns.map { String(repeating: "-", count: $0.count + 2) }.joined(separator: "|"))|")
            for target in libraries {
                var cells = [target.name]
                if showKind {
                    cells.append(config.testHelperTargets.contains(target.name) ? "Test helper" : "Library")
                }
                cells.append(dependencyCell(target))
                if showIsolation {
                    cells.append(config.mainActorTargets.contains(target.name) ? "MainActor" : "—")
                }
                lines.append("| \(cells.joined(separator: " | ")) |")
            }
            if showKind {
                lines.append("")
                lines.append("> Test-helper libraries are imported by test targets and have no test target of their own.")
            }
            sections.append(lines.joined(separator: "\n"))
        }

        if !executables.isEmpty {
            var lines = ["## Executables", "", "| Binary | Dependencies | Run |", "|--------|--------------|-----|"]
            for target in executables {
                lines.append("| `\(target.name)` | \(dependencyCell(target)) | `swift run \(target.name)` |")
            }
            sections.append(lines.joined(separator: "\n"))
        }

        return sections
    }

    // MARK: - Helpers

    private static func dependencyCell(_ target: TargetDefinition) -> String {
        target.dependencies.isEmpty ? "—" : target.dependencies.joined(separator: ", ")
    }

    private static func codeList(_ names: [String]) -> String {
        names.map { "`\($0)`" }.joined(separator: ", ")
    }
}
