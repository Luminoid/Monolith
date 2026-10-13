enum SwiftFormatGenerator {
    /// The generated `.swiftformat`. `excludeExtras` adds paths to the
    /// default build-directory excludes (see `SwiftLintGenerator.toolExcludes`).
    ///
    /// `--min-version` is the Brewfile floor: an older SwiftFormat stops with
    /// a version error instead of rejecting a rule name it doesn't know. Rules
    /// already on by default at that floor aren't listed, and options use the
    /// kebab-case names SwiftFormat has accepted since 0.57.
    static func generate(excludeExtras: [String] = []) -> String {
        var excludeParts = [".build", "Build", "build"]
        excludeParts.append(contentsOf: excludeExtras)
        let excludeValue = excludeParts.joined(separator: ",")

        return """
        # SwiftFormat configuration
        # https://github.com/nicklockwood/SwiftFormat
        #
        # Install: brew install swiftformat
        # Run:     swiftformat . (format) | swiftformat --lint . (check only)
        #
        # Options reference: swiftformat --options
        # Rules reference:   swiftformat --rules
        # Disable inline:    // swiftformat:disable <rule_name>

        # Oldest SwiftFormat that understands every rule and option below
        --min-version \(ToolVersion.swiftformatFloor)

        # File options — comma-delimited paths to exclude (supports glob patterns)
        --exclude \(excludeValue)

        # Format options — control code style
        --allman false                      # K&R brace style (opening brace on same line)
        --binary-grouping 4,8               # Group binary literals every 4 digits
        --trailing-commas collections-only  # Trailing commas in collections only, not function calls
        --decimal-grouping 3,6              # Group decimal literals every 3 digits
        --else-position same-line           # } else { on same line
        --void-type void                    # Use `void` instead of `Void`
        --exponent-case lowercase           # Lowercase exponent marker (e not E)
        --exponent-grouping disabled
        --fraction-grouping disabled
        --header ignore                     # Don't modify file headers
        --hex-grouping 4,8
        --hex-literal-case uppercase        # 0xFF not 0xff
        --ifdef indent                      # Indent code inside #if blocks
        --indent 4                          # 4-space indentation
        --indent-case false                 # Don't indent case statements
        --import-grouping testable-bottom   # @testable imports at bottom
        --linebreaks lf                     # Unix line endings
        --max-width 200
        --octal-grouping 4,8
        --operator-func spaced              # Spaces around operator functions
        --pattern-let hoist                 # Hoist let/var in patterns: let (x, y)
        --ranges spaced                     # Spaces in ranges: 0 ..< 10
        --self remove                       # Remove redundant self
        --semicolons inline                 # Allow inline semicolons only
        --swift-version \(ToolVersion.swift)
        --trim-whitespace always
        --wrap-arguments preserve           # Don't auto-wrap arguments
        --wrap-collections preserve         # Don't auto-wrap collections
        --wrap-conditions after-first       # Wrap conditions after first

        # Opt-in rules to enable
        --enable unusedPrivateDeclarations
        --enable emptyExtensions
        --enable isEmpty
        --enable preferFinalClasses

        # Default rules to disable (conflict with project style)
        --disable consecutiveSpaces
        --disable redundantSelf
        --disable unusedArguments
        --disable wrapMultilineStatementBraces
        --disable wrapPropertyBodies
        --disable wrapIfStatementBodies
        --disable wrapIfExpressionBodies

        """
    }
}
