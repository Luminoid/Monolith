enum MakefileGenerator {
    static func generate(projectType: ProjectType, appName: String? = nil, hasFastlane: Bool = false, hasGitHooks: Bool = false) -> String {
        var lines: [String] = []

        // Base targets (all project types)
        var phonyTargets = ["lint", "lint-fix", "format", "check"]

        lines.append("""
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

            lines.append("""

            SCHEME = \(appName)
            DESTINATION = platform=iOS Simulator,name=iPhone 17

            build:
            \txcodebuild build \\
            \t  -scheme $(SCHEME) \\
            \t  -destination '$(DESTINATION)' \\
            \t  -skipPackagePluginValidation \\
            \t  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5

            test:
            \txcodebuild test \\
            \t  -scheme $(SCHEME) \\
            \t  -destination '$(DESTINATION)' \\
            \t  -skipPackagePluginValidation \\
            \t  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20

            archive:
            \txcodebuild archive \\
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

            lines.append("""

            build:
            \tswift build

            test:
            \tswift test
            """)
        }

        let phonyLine = ".PHONY: \(phonyTargets.joined(separator: " "))"

        return phonyLine + "\n\n" + lines.joined(separator: "\n") + "\n"
    }
}
