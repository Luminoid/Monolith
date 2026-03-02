enum ToolingGenerator {

    // MARK: - SwiftLint

    static func generateSwiftLint(projectType: ProjectType, appName: String? = nil, hasRSwift: Bool = false, hasFastlane: Bool = false) -> String {
        let included: String = switch projectType {
        case .app:
            if let appName { "  - \(appName)" } else { "  - Sources" }
        case .package, .cli:
            "  - Sources"
        }

        var excluded: [String] = ["  - .build"]
        if hasRSwift, let appName {
            excluded.append("  - \(appName)/Generated")
        }
        if hasFastlane {
            excluded.append("  - fastlane")
        }

        return """
        disabled_rules:
          - function_body_length
          - function_parameter_count
          - identifier_name
          - large_tuple
          - trailing_whitespace
          - trailing_comma

        opt_in_rules:
          - empty_count
          - implicit_return

        included:
        \(included)

        excluded:
        \(excluded.joined(separator: "\n"))

        allow_zero_lintable_files: false
        strict: false
        lenient: false
        check_for_updates: true

        force_cast: warning
        force_try:
          severity: warning
        line_length: 300
        type_body_length:
          - 1800
          - 2500
        file_length:
          warning: 2500
          error: 3500
        type_name:
          min_length: 3
          max_length:
            warning: 40
            error: 50
          allowed_symbols: ["_"]
        cyclomatic_complexity:
          warning: 20
          error: 40

        reporter: "xcode"

        """
    }

    // MARK: - SwiftFormat

    static func generateSwiftFormat(excludeExtras: [String] = []) -> String {
        var excludeParts = [".build", "Build"]
        excludeParts.append(contentsOf: excludeExtras)
        let excludeValue = excludeParts.joined(separator: ",")

        return """
        # file options

        --exclude \(excludeValue)

        # format options

        --allman false
        --binarygrouping 4,8
        --commas always
        --decimalgrouping 3,6
        --elseposition same-line
        --voidtype void
        --exponentcase lowercase
        --exponentgrouping disabled
        --fractiongrouping disabled
        --header ignore
        --hexgrouping 4,8
        --hexliteralcase uppercase
        --ifdef indent
        --indent 4
        --indentcase false
        --importgrouping testable-bottom
        --linebreaks lf
        --maxwidth 300
        --octalgrouping 4,8
        --operatorfunc spaced
        --patternlet hoist
        --ranges spaced
        --self remove
        --semicolons inline
        --swiftversion 6.2
        --trimwhitespace always
        --wraparguments preserve
        --wrapcollections preserve
        --wrapconditions after-first

        # rules

        --enable unusedPrivateDeclarations
        --enable emptyExtensions
        --enable isEmpty
        --enable docComments
        --enable preferFinalClasses
        --enable redundantAsync
        --enable redundantEquatable
        --enable redundantMemberwiseInit
        --enable redundantProperty
        --enable redundantThrows

        --disable redundantSelf
        --disable unusedArguments
        --disable wrapMultilineStatementBraces

        """
    }

    // MARK: - Makefile

    static func generateMakefile(projectType: ProjectType, appName: String? = nil, hasFastlane: Bool = false) -> String {
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

    // MARK: - Brewfile

    static func generateBrewfile(projectSystem: ProjectSystem? = nil, hasRSwift: Bool = false) -> String {
        var lines: [String] = []

        lines.append(#"brew "swiftlint""#)
        lines.append(#"brew "swiftformat""#)

        if projectSystem == .xcodeGen {
            lines.append(#"brew "xcodegen""#)
        }

        if hasRSwift {
            lines.append(#"# brew "mint"          # Uncomment if using R.swift"#)
        }

        return lines.joined(separator: "\n") + "\n"
    }
}
