enum MakefileGenerator {
    /// Generate the project Makefile.
    ///
    /// - Parameters:
    ///   - hasDefaultIsolation: for a package or CLI, build and test through
    ///     `xcodebuild` on the iOS Simulator instead of `swift build` /
    ///     `swift test` (MainActor default isolation, a UIKit-only product, or
    ///     anything else `swift build` can't compile for the host). Ignored
    ///     for apps, which always use xcodebuild. The name predates the
    ///     broader meaning.
    ///   - xcodeBuildScheme: the scheme for the xcodebuild package path;
    ///     falls back to `appName`.
    ///   - disableTestParallelism: add `-parallel-testing-enabled NO` to the
    ///     app's `test` recipe.
    ///   - hasMacCatalyst: add the app's `build-catalyst`, `archive-mac`, and
    ///     `release-mac` targets.
    static func generate(
        projectType: ProjectType,
        appName: String? = nil,
        hasFastlane: Bool = false,
        hasGitHooks: Bool = false,
        hasDefaultIsolation: Bool = false,
        hasLocalization: Bool = false,
        hasAppIconValidation: Bool = false,
        projectSystem: ProjectSystem? = nil,
        xcodeBuildScheme: String? = nil,
        disableTestParallelism: Bool = false,
        hasMacCatalyst: Bool = false
    ) -> String {
        var lines: [String] = []

        // Base targets (all project types)
        var phonyTargets = ["help", "lint", "lint-fix", "format", "check"]

        let usesXcodebuild = projectType == .app || (hasDefaultIsolation && appName != nil)
        lines.append(helpBlock(
            projectType: projectType,
            usesXcodebuild: usesXcodebuild,
            hasLocalization: hasLocalization,
            hasAppIconValidation: hasAppIconValidation,
            hasGitHooks: hasGitHooks,
            hasFastlane: hasFastlane,
            hasMacCatalyst: hasMacCatalyst
        ))

        lines.append("""

        lint:
        \tswiftlint

        lint-fix:
        \tswiftlint --fix

        format:
        \tswiftformat .
        """)

        // `check` runs every lint/audit gate the project ships, so any new
        // gate (audit-strings, validate-icon) chains under it here so CI
        // catches regressions before they ship.
        //
        // Build the chained recipe as a single block so the appended audit /
        // validate lines land inside `check:`, not under the trailing target
        // that happens to follow it (which is what happens when each
        // condition emits its own `lines.append` mid-stream).
        var checkRecipe: [String] = [
            "\tswiftlint --strict",
            "\tswiftformat --lint .",
        ]
        if hasLocalization {
            checkRecipe.append("\tpython3 Scripts/localization/audit_strings.py")
        }
        if hasAppIconValidation {
            checkRecipe.append("\tbash \(iconScript)")
        }
        lines.append("")
        lines.append("check:")
        lines.append(contentsOf: checkRecipe)

        if hasLocalization {
            phonyTargets.append("audit-strings")
            lines.append("""

            audit-strings:
            \tpython3 Scripts/localization/audit_strings.py
            """)
        }
        if hasAppIconValidation {
            phonyTargets.append("validate-icon")
            lines.append("""

            validate-icon:
            \tbash \(iconScript)
            """)
        }

        if hasGitHooks {
            phonyTargets.append("setup-hooks")
            lines.append("""

            setup-hooks:
            \tgit config core.hooksPath Scripts/git-hooks
            \t@echo "Git hooks configured to Scripts/git-hooks/"
            """)
        }

        // Project-type-specific targets
        switch projectType {
        case .app:
            guard let appName else { break }
            let app = appSection(
                appName: appName,
                hasProject: projectSystem == .xcodeProj || projectSystem == .xcodeGen,
                hasAppIconValidation: hasAppIconValidation,
                disableTestParallelism: disableTestParallelism,
                hasMacCatalyst: hasMacCatalyst
            )
            phonyTargets.append(contentsOf: app.targets)
            lines.append(contentsOf: app.lines)

            if hasFastlane {
                phonyTargets.append(contentsOf: ["fastlane-validate", "fastlane-beta"])
                lines.append("""

                fastlane-validate:
                \tbundle exec fastlane validate

                fastlane-beta:
                \tbundle exec fastlane beta
                """)
            }

        case .package, .cli:
            phonyTargets.append(contentsOf: ["build", "test"])

            if usesXcodebuild, let appName {
                // SCHEME prefers the caller's resolved choice: `<Name>-Package`
                // umbrella for mixed-target packages (executables + libs, or
                // test-helper libs alongside MainActor libs) so one xcodebuild
                // invocation covers every target. Falls back to the named
                // `<Name>` scheme for single-purpose packages.
                let scheme = xcodeBuildScheme ?? appName
                lines.append("")
                lines.append(contentsOf: simulatorVariables(scheme: scheme))
                lines.append("")
                lines.append(xcodebuildRecipe(target: "build", action: "build", hasProject: false, destination: "$(DESTINATION)", flags: simulatorFlags))
                lines.append("")
                lines.append(xcodebuildRecipe(target: "test", action: "test", hasProject: false, destination: "$(DESTINATION)", flags: simulatorFlags))
            } else {
                lines.append("""

                build:
                \tswift build

                test:
                \tswift test
                """)
            }
        }

        let phonyLine = ".PHONY: \(phonyTargets.joined(separator: " "))"
        let header = phonyLine + "\n.DEFAULT_GOAL := help\n"

        return header + "\n" + lines.joined(separator: "\n") + "\n"
    }

    // MARK: - App

    private static let iconScript = "Scripts/validate-app-icon.sh"

    /// Flags every simulator and Catalyst build or test passes.
    /// `-skipPackagePluginValidation` keeps Xcode's plugin-trust prompt from
    /// stopping a non-interactive build once any dependency adds an SPM build
    /// tool plugin (harmless when none do). `-quiet` drops per-file compile
    /// lines but still prints warnings and errors.
    private static let simulatorFlags = ["-skipPackagePluginValidation", "-quiet", "CODE_SIGNING_ALLOWED=NO"]

    /// The app's xcodebuild targets: simulator build / clean build / test,
    /// Mac Catalyst build, and the archive + release pairs.
    ///
    /// `build-clean` runs `clean build`: incremental builds skip unchanged
    /// files and hide their warnings, so only a clean build shows them all.
    /// Adopters who want prettified output can run `make build | xcpretty`
    /// (not piped by default, so a missing xcpretty can't break a recipe).
    ///
    /// `release` archives and opens the archive, which lands in Xcode's
    /// Organizer for Distribute App: the upload needs an interactive sign-in
    /// or an App Store Connect API key, so it stays a manual step. With the
    /// icon validator, `archive` runs it first so an icon with transparency
    /// never reaches an upload.
    private static func appSection(
        appName: String,
        hasProject: Bool,
        hasAppIconValidation: Bool,
        disableTestParallelism: Bool,
        hasMacCatalyst: Bool
    ) -> (targets: [String], lines: [String]) {
        var targets = ["build", "build-clean", "test"]
        var lines = [""]
        if hasProject {
            lines.append("PROJECT = \(appName).xcodeproj")
        }
        lines.append(contentsOf: simulatorVariables(scheme: appName))

        lines.append("")
        lines.append(xcodebuildRecipe(target: "build", action: "build", hasProject: hasProject, destination: "$(DESTINATION)", flags: simulatorFlags))
        lines.append("")
        lines.append(xcodebuildRecipe(target: "build-clean", action: "clean build", hasProject: hasProject, destination: "$(DESTINATION)", flags: simulatorFlags))

        // Apps with a shared persistence singleton (a repository on top of
        // Core Data, or SwiftData + CloudKit) race when Swift Testing runs
        // suites in parallel, so the test recipe can serialize them. Apps
        // that add such a singleton later can instead wrap suites in a
        // `.serialized` parent.
        var testFlags = simulatorFlags
        if disableTestParallelism {
            testFlags.insert("-parallel-testing-enabled NO", at: testFlags.count - 1)
        }
        lines.append("")
        lines.append(xcodebuildRecipe(target: "test", action: "test", hasProject: hasProject, destination: "$(DESTINATION)", flags: testFlags))

        if hasMacCatalyst {
            targets.append("build-catalyst")
            lines.append("")
            lines.append(xcodebuildRecipe(
                target: "build-catalyst", action: "build", hasProject: hasProject,
                destination: "platform=macOS,variant=Mac Catalyst", flags: simulatorFlags
            ))
        }

        let preamble = hasAppIconValidation ? ["bash \(iconScript)"] : []
        targets.append(contentsOf: ["archive", "release"])
        lines.append("")
        lines.append(xcodebuildRecipe(
            target: "archive", action: "archive", hasProject: hasProject,
            destination: "generic/platform=iOS",
            flags: ["-archivePath build/$(SCHEME).xcarchive", "-allowProvisioningUpdates"],
            preamble: preamble
        ))
        lines.append("""

        # Upload from Xcode's Organizer (Distribute App), which opens on the archive.
        release: archive
        \topen build/$(SCHEME).xcarchive
        """)

        if hasMacCatalyst {
            targets.append(contentsOf: ["archive-mac", "release-mac"])
            lines.append("")
            lines.append(xcodebuildRecipe(
                target: "archive-mac", action: "archive", hasProject: hasProject,
                destination: "generic/platform=macOS,variant=Mac Catalyst",
                flags: ["-archivePath build/$(SCHEME)-mac.xcarchive", "-allowProvisioningUpdates"],
                preamble: preamble
            ))
            lines.append("""

            release-mac: archive-mac
            \topen build/$(SCHEME)-mac.xcarchive
            """)
        }

        return (targets, lines)
    }

    // MARK: - Shared xcodebuild pieces

    /// `SCHEME` plus a simulator `DESTINATION` whose runtime version is the
    /// `IOS_VERSION` knob, so adopters move to a newer simulator runtime with
    /// `make test IOS_VERSION=…` or one edit, not one per recipe.
    private static func simulatorVariables(scheme: String) -> [String] {
        [
            "SCHEME = \(scheme)",
            "IOS_VERSION ?= \(Defaults.simulatorOS)",
            "DESTINATION = platform=iOS Simulator,name=\(Defaults.simulatorDevice),OS=$(IOS_VERSION)",
        ]
    }

    /// One `xcodebuild` target: optional preamble commands, then the call with
    /// one argument per continuation line (`-project` when the project has an
    /// `.xcodeproj`, `-scheme`, `-destination`, then `flags`).
    private static func xcodebuildRecipe(
        target: String,
        action: String,
        hasProject: Bool,
        destination: String,
        flags: [String],
        preamble: [String] = []
    ) -> String {
        var arguments: [String] = []
        if hasProject {
            arguments.append("-project $(PROJECT)")
        }
        arguments.append("-scheme $(SCHEME)")
        arguments.append("-destination '\(destination)'")
        arguments.append(contentsOf: flags)

        var recipe = ["\(target):"]
        recipe.append(contentsOf: preamble.map { "\t\($0)" })
        recipe.append("\txcodebuild \(action) \\")
        for (index, argument) in arguments.enumerated() {
            let continuation = index == arguments.count - 1 ? "" : " \\"
            recipe.append("\t  \(argument)\(continuation)")
        }
        return recipe.joined(separator: "\n")
    }

    // MARK: - Help

    /// Build the `help:` recipe lines: one `@echo` per target we'll actually
    /// emit, aligned by widest target name. Extracted out of `generate` to
    /// keep that function under the cyclomatic-complexity ceiling — every
    /// conditional target added a branch to the parent counter even though
    /// the work was just appending to an array.
    private static func helpBlock(
        projectType: ProjectType,
        usesXcodebuild: Bool,
        hasLocalization: Bool,
        hasAppIconValidation: Bool,
        hasGitHooks: Bool,
        hasFastlane: Bool,
        hasMacCatalyst: Bool
    ) -> String {
        let isApp = projectType == .app
        var entries: [(target: String, blurb: String)] = []
        if isApp {
            entries.append(("build", "Build for the iOS Simulator (xcodebuild -quiet)"))
            entries.append(("build-clean", "Clean build (surfaces all warnings)"))
            entries.append(("test", "Run tests on the iOS Simulator"))
            if hasMacCatalyst {
                entries.append(("build-catalyst", "Build for Mac Catalyst"))
            }
        } else if usesXcodebuild {
            entries.append(("build", "Build for the iOS Simulator (xcodebuild)"))
            entries.append(("test", "Run tests on the iOS Simulator (xcodebuild)"))
        } else {
            entries.append(("build", "Build (swift build)"))
            entries.append(("test", "Run tests (swift test)"))
        }
        entries.append(("lint", "Run SwiftLint"))
        entries.append(("lint-fix", "Run SwiftLint --fix"))
        entries.append(("format", "Run SwiftFormat (modifies files)"))
        entries.append(("check", "Strict lint + format check (CI gate)"))
        if hasLocalization {
            entries.append(("audit-strings", "Audit Localizable.xcstrings for gaps"))
        }
        if hasAppIconValidation {
            entries.append(("validate-icon", "Verify AppIcon has no transparency"))
        }
        if hasGitHooks {
            entries.append(("setup-hooks", "Install pre-commit hooks"))
        }
        if isApp {
            entries.append(("archive", "Build the iOS .xcarchive"))
            entries.append(("release", "Archive, then open it in Xcode's Organizer to upload"))
            if hasMacCatalyst {
                entries.append(("archive-mac", "Build the Mac Catalyst .xcarchive"))
                entries.append(("release-mac", "Archive for Mac, then open it in Xcode's Organizer"))
            }
        }
        if hasFastlane {
            entries.append(("fastlane-validate", "fastlane validate"))
            entries.append(("fastlane-beta", "fastlane beta"))
        }

        let widestTarget = entries.map(\.target.count).max() ?? 0
        var lines: [String] = ["help:", "\t@echo \"Project targets:\""]
        for entry in entries {
            let padding = String(repeating: " ", count: max(0, widestTarget - entry.target.count))
            lines.append("\t@echo \"  make \(entry.target)\(padding)  \(entry.blurb)\"")
        }
        return lines.joined(separator: "\n")
    }
}
