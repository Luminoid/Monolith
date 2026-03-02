extension String {
    var capitalizingFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
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
