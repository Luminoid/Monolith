import Testing
@testable import MonolithLib

@Suite("AddableFeature")
struct AddableFeatureTests {
    @Test("all addable features have display names")
    func displayNames() {
        for feature in AddableFeature.allCases {
            #expect(!feature.displayName.isEmpty)
        }
    }

    @Test("addable feature count is 4")
    func featureCount() {
        #expect(AddableFeature.allCases.count == 4)
    }

    @Test("devTooling returns 4 files")
    func devToolingFiles() {
        let files = AddableFeature.devTooling.filePaths(projectType: .app, appName: "Test")
        #expect(files.count == 4)
        #expect(files.contains(".swiftlint.yml"))
        #expect(files.contains(".swiftformat"))
        #expect(files.contains("Makefile"))
        #expect(files.contains("Brewfile"))
    }

    @Test("gitHooks returns pre-commit")
    func gitHooksFiles() {
        let files = AddableFeature.gitHooks.filePaths(projectType: .app, appName: "Test")
        #expect(files.count == 1)
        #expect(files.contains("Scripts/git-hooks/pre-commit"))
    }

    @Test("claudeMD returns CLAUDE.md path")
    func claudeMDFiles() {
        let files = AddableFeature.claudeMD.filePaths(projectType: .app, appName: "Test")
        #expect(files.count == 1)
        #expect(files.contains(".claude/CLAUDE.md"))
    }

    @Test("licenseChangelog returns LICENSE and CHANGELOG")
    func licenseChangelogFiles() {
        let files = AddableFeature.licenseChangelog.filePaths(projectType: .package, appName: nil)
        #expect(files.count == 2)
        #expect(files.contains("LICENSE"))
        #expect(files.contains("CHANGELOG.md"))
    }

    @Test("raw values match expected strings")
    func rawValues() {
        #expect(AddableFeature.devTooling.rawValue == "devTooling")
        #expect(AddableFeature.gitHooks.rawValue == "gitHooks")
        #expect(AddableFeature.claudeMD.rawValue == "claudeMD")
        #expect(AddableFeature.licenseChangelog.rawValue == "licenseChangelog")
    }
}
