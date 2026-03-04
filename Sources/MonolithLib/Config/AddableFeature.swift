/// Features that can be added to existing projects without modifying existing files.
enum AddableFeature: String, CaseIterable, Sendable {
    case devTooling
    case gitHooks
    case claudeMD
    case licenseChangelog

    var displayName: String {
        switch self {
        case .devTooling: "Dev tooling (SwiftLint + SwiftFormat + Makefile + Brewfile)"
        case .gitHooks: "Git hooks (pre-commit lint + format)"
        case .claudeMD: "CLAUDE.md"
        case .licenseChangelog: "LICENSE + CHANGELOG"
        }
    }

    /// Files this feature writes (relative paths).
    func filePaths(projectType: ProjectType, appName: String?) -> [String] {
        switch self {
        case .devTooling:
            [".swiftlint.yml", ".swiftformat", "Makefile", "Brewfile"]
        case .gitHooks:
            ["Scripts/git-hooks/pre-commit"]
        case .claudeMD:
            [".claude/CLAUDE.md"]
        case .licenseChangelog:
            ["LICENSE", "CHANGELOG.md"]
        }
    }
}
