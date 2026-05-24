extension String {
    var capitalizingFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }

    /// Convert `kebab-case` or `snake_case` names into UpperCamelCase, suitable
    /// for use as a Swift type identifier (e.g. `causeway-tools` -> `CausewayTools`).
    /// Pass-through for names that already contain no separators.
    var upperCamelCased: String {
        split(whereSeparator: { $0 == "-" || $0 == "_" })
            .map { String($0).capitalizingFirst }
            .joined()
    }
}

extension [String] {
    /// Append a MARK section header with blank lines above and below.
    ///
    /// Two cases where the leading blank line is suppressed:
    /// 1. The array already ends with an empty element (`addMark` called after
    ///    a separate `append("")`).
    /// 2. The previous element is a heredoc string whose own trailing
    ///    character is `\n` (i.e. the heredoc ended on a blank line). Without
    ///    this, generators that emit blocks via triple-quoted literals end up
    ///    with TWO consecutive blank lines between sections, which SwiftLint's
    ///    `vertical_whitespace` rule flags as an error on the generated source.
    ///
    /// Additionally suppresses the leading blank if the previous element ends
    /// with `{` — that would create the `blankLinesAtStartOfScope` violation
    /// SwiftFormat flags. This is the case `addMark` immediately after the
    /// class/struct/enum opening brace.
    mutating func addMark(_ title: String, indent: Int = 4) {
        let prefix = String(repeating: " ", count: indent)
        if needsLeadingBlankBeforeMark { append("") }
        append("\(prefix)// MARK: - \(title)")
        append("")
    }

    /// Returns true when an `addMark` (or any new-section append) should be
    /// preceded by a blank line. False when the prior content already ends
    /// with one, or with an opening brace where a blank line is forbidden by
    /// SwiftFormat's `blankLinesAtStartOfScope` rule.
    private var needsLeadingBlankBeforeMark: Bool {
        guard let last else { return false }
        if last.isEmpty { return false }
        // Multi-line heredoc that already ends on a blank line. `hasSuffix("\n")`
        // catches "line1\nline2\n" (which renders as an extra trailing blank
        // after the array is joined with "\n"). The empty-element check above
        // handles the single-empty-string case.
        if last.hasSuffix("\n") { return false }
        // Opening brace of a scope. Adding a blank here violates
        // `blankLinesAtStartOfScope` ("class Foo {" → "// MARK:" with no
        // intervening blank is the SwiftFormat-approved layout).
        if last.hasSuffix("{") { return false }
        return true
    }
}
