enum SwiftLintGenerator {
    /// Generated and third-party paths both linters skip: R.swift's output
    /// and fastlane's Ruby-adjacent folder. `SwiftFormatGenerator` takes the
    /// same list through `excludeExtras`.
    static func toolExcludes(appName: String?, hasRSwift: Bool, hasFastlane: Bool) -> [String] {
        var paths: [String] = []
        if hasRSwift, let appName {
            paths.append("\(appName)/Generated")
        }
        if hasFastlane {
            paths.append("fastlane")
        }
        return paths
    }

    /// The directories the config lints. They match what the pre-commit hook
    /// hands SwiftLint (every staged `.swift` file), so test and widget
    /// sources pass the same rules before they reach a commit.
    static func includedPaths(projectType: ProjectType, appName: String?, hasWidget: Bool = false) -> [String] {
        switch projectType {
        case .app:
            guard let appName else { return ["Sources", "Tests"] }
            var paths = [appName, "\(appName)Tests"]
            if hasWidget {
                paths.append("\(appName)Widget")
            }
            return paths
        case .package, .cli:
            return ["Sources", "Tests"]
        }
    }

    static func generate(
        projectType: ProjectType,
        appName: String? = nil,
        hasRSwift: Bool = false,
        hasFastlane: Bool = false,
        hasWidget: Bool = false
    ) -> String {
        let included = includedPaths(projectType: projectType, appName: appName, hasWidget: hasWidget)
            .map { "  - \($0)" }
            .joined(separator: "\n")
        let excluded = ([".build"] + toolExcludes(appName: appName, hasRSwift: hasRSwift, hasFastlane: hasFastlane))
            .map { "  - \($0)" }

        return """
        # By default, SwiftLint uses a set of sensible default rules you can adjust. Find all the available rules
        # by running `swiftlint rules` or visiting https://realm.github.io/SwiftLint/rule-directory.html.

        # Rules turned on by default can be disabled.
        disabled_rules:
          - function_body_length
          - function_parameter_count
          - identifier_name
          - large_tuple
          - trailing_whitespace

        # Rules turned off by default can be enabled.
        opt_in_rules:
          - contains_over_filter_count
          - empty_count
          - first_where
          - force_unwrapping
          - for_where
          - implicit_return
          - prefer_self_in_static_references
          - private_over_fileprivate
          - sorted_first_last

        # Case-sensitive paths to include during linting. Directory paths supplied on the
        # command line will be ignored. Wildcards are supported.
        included:
        \(included)

        # Case-sensitive paths to ignore during linting. Takes precedence over `included`. Wildcards
        # are supported.
        excluded:
        \(excluded.joined(separator: "\n"))

        # If true, SwiftLint will not fail if no lintable files are found.
        allow_zero_lintable_files: false

        # If true, SwiftLint will treat all warnings as errors.
        strict: false

        # If true, SwiftLint will treat all errors as warnings.
        lenient: false

        # If true, SwiftLint will check for updates after linting or analyzing.
        # Off: the check calls GitHub on every run, including each commit hook.
        check_for_updates: false

        # Configurable rules can be customized. All rules support setting their severity level.
        force_cast: warning # implicitly
        force_try:
          severity: warning # explicitly

        trailing_comma:
          mandatory_comma: true

        # Rules that have both warning and error levels can set just the warning level implicitly.
        line_length: 200

        # To set both levels implicitly, use an array.
        type_body_length:
          - 1000 # warning
          - 2000 # error

        # To set both levels explicitly, use a dictionary.
        file_length:
          warning: 2000
          error: 3000

        # Naming rules can set warnings/errors for `min_length` and `max_length`. Additionally, they can
        # set excluded names and allowed symbols.
        type_name:
          min_length: 3
          max_length:
            warning: 60
            error: 70
          allowed_symbols: ["_"]
        cyclomatic_complexity:
          warning: 20
          error: 40

        # The default reporter (SwiftLint's output format) can be configured as `checkstyle`, `codeclimate`, `csv`,
        # `emoji`, `github-actions-logging`, `gitlab`, `html`, `json`, `junit`, `markdown`, `relative-path`, `sarif`,
        # `sonarqube`, `summary`, or `xcode` (default).
        reporter: "xcode"

        """
    }
}
