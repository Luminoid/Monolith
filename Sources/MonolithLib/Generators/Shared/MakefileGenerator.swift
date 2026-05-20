enum MakefileGenerator {
    static func generate(
        projectType: ProjectType,
        appName: String? = nil,
        hasFastlane: Bool = false,
        hasGitHooks: Bool = false,
        hasDefaultIsolation: Bool = false,
        hasLocalization: Bool = false,
        projectSystem: ProjectSystem? = nil
    ) -> String {
        var lines: [String] = []

        // Base targets (all project types)
        var phonyTargets = ["help", "lint", "lint-fix", "format", "check"]

        let helpExtra = hasLocalization
            ? "\n\t@echo \"  make audit-strings Audit Localizable.xcstrings for gaps\""
            : ""

        lines.append("""
        help:
        \t@echo "Project targets:"
        \t@echo "  make build        Compile"
        \t@echo "  make test         Run tests"
        \t@echo "  make lint         Run SwiftLint"
        \t@echo "  make lint-fix     Run SwiftLint --fix"
        \t@echo "  make format       Run SwiftFormat (modifies files)"
        \t@echo "  make check        SwiftLint --strict + SwiftFormat --lint (CI check)"\(helpExtra)

        lint:
        \tswiftlint

        lint-fix:
        \tswiftlint --fix

        format:
        \tswiftformat .

        check:
        \tswiftlint --strict
        \tswiftformat --lint .
        """)

        if hasLocalization {
            phonyTargets.append("audit-strings")
            lines.append("""
            \tpython3 Scripts/localization/audit_strings.py

            audit-strings:
            \tpython3 Scripts/localization/audit_strings.py
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

            lines.append("""

            SCHEME = \(appName)
            DESTINATION = \(Defaults.simulatorDestination)

            build:
            \txcodebuild build \\
            """)
            if hasProject { lines.append("\t  -project $(PROJECT) \\") }
            lines.append("""
            \t  -scheme $(SCHEME) \\
            \t  -destination '$(DESTINATION)' \\
            \t  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5

            test:
            \txcodebuild test \\
            """)
            if hasProject { lines.append("\t  -project $(PROJECT) \\") }
            lines.append("""
            \t  -scheme $(SCHEME) \\
            \t  -destination '$(DESTINATION)' \\
            \t  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20

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
                lines.append("""

                SCHEME = \(appName)
                DESTINATION = \(Defaults.simulatorDestination)

                build:
                \txcodebuild build \\
                \t  -scheme $(SCHEME) \\
                \t  -destination '$(DESTINATION)' \\
                \t  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5

                test:
                \txcodebuild test \\
                \t  -scheme $(SCHEME) \\
                \t  -destination '$(DESTINATION)' \\
                \t  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
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
}
