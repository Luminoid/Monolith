enum MakefileGenerator {
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
        disableTestParallelism: Bool = false
    ) -> String {
        var lines: [String] = []

        // Base targets (all project types)
        var phonyTargets = ["help", "lint", "lint-fix", "format", "check"]

        lines.append(helpBlock(
            projectType: projectType,
            hasLocalization: hasLocalization,
            hasAppIconValidation: hasAppIconValidation,
            hasGitHooks: hasGitHooks,
            hasFastlane: hasFastlane
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
            checkRecipe.append("\tbash Scripts/validate-app-icon.sh")
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
            \tbash Scripts/validate-app-icon.sh
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
            phonyTargets.append(contentsOf: ["build", "test", "archive", "export", "upload", "release"])

            let hasProject = projectSystem == .xcodeProj || projectSystem == .xcodeGen

            if hasProject {
                lines.append("")
                lines.append("PROJECT = \(appName).xcodeproj")
            }

            // The build/test pipelines preserve exit status via `set -o
            // pipefail`. The previous `2>&1 | tail -5` swallowed all error
            // context: a build failure showed only the last 5 lines (often
            // just "** BUILD FAILED **" with no diagnostics).
            //
            // Adopters who want prettified output can run `make build |
            // xcpretty` from the shell (xcpretty isn't piped in by default
            // because installing it is per-developer, and a missing xcpretty
            // shouldn't break the recipe).
            //
            // The `IOS_VERSION` knob exists so adopters can bump the
            // simulator runtime version without editing each xcodebuild
            // invocation.
            lines.append("""

            SCHEME = \(appName)
            IOS_VERSION ?= \(Defaults.simulatorOS)
            DESTINATION = platform=iOS Simulator,name=\(Defaults.simulatorDevice),OS=$(IOS_VERSION)

            build:
            \tset -o pipefail; xcodebuild build \\
            """)
            if hasProject { lines.append("\t  -project $(PROJECT) \\") }
            lines.append("""
            \t  -scheme $(SCHEME) \\
            \t  -destination '$(DESTINATION)' \\
            \t  -skipPackagePluginValidation \\
            \t  CODE_SIGNING_ALLOWED=NO

            test:
            \tset -o pipefail; xcodebuild test \\
            """)
            if hasProject { lines.append("\t  -project $(PROJECT) \\") }
            lines.append("""
            \t  -scheme $(SCHEME) \\
            \t  -destination '$(DESTINATION)' \\
            \t  -skipPackagePluginValidation \\
            """)
            // Singleton-prone apps (a shared repository on top of Core Data
            // or SwiftData + CloudKit) race when Swift Testing's in-process
            // scheduler runs suites in parallel. The workspace's documented
            // case (Petfolio's PetRepository.shared) needed
            // -parallel-testing-enabled NO to stop intermittent failures
            // around persistence setup. Emit the flag automatically when the
            // template wires a persistence layer; harmless for apps that
            // later wrap suites in a serialized parent (the flag pins the
            // worker count at 1, the parent's .serialized trait propagates
            // downward, both end at the same place).
            if disableTestParallelism {
                lines.append("\t  -parallel-testing-enabled NO \\")
            }
            lines.append("""
            \t  CODE_SIGNING_ALLOWED=NO

            archive:
            \txcodebuild archive \\
            """)
            if hasProject { lines.append("\t  -project $(PROJECT) \\") }
            lines.append("""
            \t  -scheme $(SCHEME) \\
            \t  -archivePath build/$(SCHEME).xcarchive \\
            \t  -destination 'generic/platform=iOS' \\
            \t  -allowProvisioningUpdates

            export:
            \txcodebuild -exportArchive \\
            \t  -archivePath build/$(SCHEME).xcarchive \\
            \t  -exportOptionsPlist ExportOptions.plist \\
            \t  -exportPath build/export

            upload:
            \txcrun altool --upload-app \\
            \t  --file build/export/$(SCHEME).ipa \\
            \t  --apiKey $(API_KEY) \\
            \t  --apiIssuer $(API_ISSUER) \\
            \t  --type ios

            release: archive export upload
            """)

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

            if hasDefaultIsolation, let appName {
                // `-skipPackagePluginValidation` matches the workspace convention
                // (LumiKit/Prism use it) — it suppresses Xcode's plugin-trust
                // prompt for any SPM build tool plugins the package may add later
                // (e.g. swift-format, swift-openapi-generator). Harmless if there
                // are no plugins; required as soon as there are.
                //
                // SCHEME prefers the caller's resolved choice: `<Name>-Package`
                // umbrella for mixed-target packages (executables + libs, or
                // test-helper libs alongside MainActor libs) so one xcodebuild
                // invocation covers every target. Falls back to the named
                // `<Name>` scheme for single-purpose packages.
                let scheme = xcodeBuildScheme ?? appName
                lines.append("""

                SCHEME = \(scheme)
                DESTINATION = \(Defaults.simulatorDestination)

                build:
                \tset -o pipefail; xcodebuild build \\
                \t  -scheme $(SCHEME) \\
                \t  -destination '$(DESTINATION)' \\
                \t  -skipPackagePluginValidation \\
                \t  CODE_SIGNING_ALLOWED=NO

                test:
                \tset -o pipefail; xcodebuild test \\
                \t  -scheme $(SCHEME) \\
                \t  -destination '$(DESTINATION)' \\
                \t  -skipPackagePluginValidation \\
                \t  CODE_SIGNING_ALLOWED=NO
                """)
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

    /// Build the `help:` recipe lines: one `@echo` per target we'll actually
    /// emit, aligned by widest target name. Extracted out of `generate` to
    /// keep that function under the cyclomatic-complexity ceiling — every
    /// conditional target added a branch to the parent counter even though
    /// the work was just appending to an array.
    private static func helpBlock(
        projectType: ProjectType,
        hasLocalization: Bool,
        hasAppIconValidation: Bool,
        hasGitHooks: Bool,
        hasFastlane: Bool
    ) -> String {
        var entries: [(target: String, blurb: String)] = []
        switch projectType {
        case .app:
            entries.append(("build", "Compile (xcodebuild, pipefail)"))
            entries.append(("test", "Run tests"))
        case .package, .cli:
            entries.append(("build", "swift build or xcodebuild"))
            entries.append(("test", "swift test or xcodebuild test"))
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
        if projectType == .app {
            entries.append(("archive", "Build .xcarchive"))
            entries.append(("export", "Export .ipa from archive"))
            entries.append(("upload", "Upload .ipa to App Store Connect"))
            entries.append(("release", "archive + export + upload"))
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
