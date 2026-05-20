enum BrewfileGenerator {
    static func generate(projectSystem: ProjectSystem? = nil, hasRSwift: Bool = false) -> String {
        var lines: [String] = [
            "# Brewfile — Homebrew dependencies for local development.",
            "# Install all: `brew bundle`",
            "# Add a tool:  `brew bundle add <name>`",
            "",
            "# Pins document the minimum compatible version. `brew bundle`",
            "# installs the latest, so adopters with newer versions are fine;",
            "# the comment is the contract for `brew unlink && brew install`",
            "# only if you're debugging a tool that worked on an older release.",
            "",
        ]

        // Floor versions chosen for stability (released ≥ ~6 months, no major
        // breaking changes since). Update `ToolVersion.*Floor` when generated
        // configs (.swiftlint.yml, .swiftformat, project.yml) start using
        // newer-than-floor features.
        lines.append(#"brew "swiftlint"   # \#(ToolVersion.swiftlintFloor)+"#)
        lines.append(#"brew "swiftformat" # \#(ToolVersion.swiftformatFloor)+"#)

        if projectSystem == .xcodeGen {
            lines.append(#"brew "xcodegen"    # \#(ToolVersion.xcodegenFloor)+"#)
        }

        if hasRSwift {
            lines.append(#"# brew "mint"          # Uncomment if using R.swift"#)
        }

        return lines.joined(separator: "\n") + "\n"
    }
}
