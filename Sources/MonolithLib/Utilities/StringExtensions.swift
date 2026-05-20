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
    /// Skips the leading blank line if the array already ends with one.
    mutating func addMark(_ title: String, indent: Int = 4) {
        let prefix = String(repeating: " ", count: indent)
        if last != "" { append("") }
        append("\(prefix)// MARK: - \(title)")
        append("")
    }
}
