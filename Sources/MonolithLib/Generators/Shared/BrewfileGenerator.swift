enum BrewfileGenerator {
    static func generate(projectSystem: ProjectSystem? = nil, hasRSwift: Bool = false) -> String {
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
