import Testing
@testable import MonolithLib

struct AddableFeatureTests {
    @Test
    func `all addable features have display names`() {
        for feature in AddableFeature.allCases {
            #expect(!feature.displayName.isEmpty)
        }
    }

    @Test
    func `addable feature count is 4`() {
        #expect(AddableFeature.allCases.count == 4)
    }

    @Test
    func `devTooling returns 4 files`() {
        let files = AddableFeature.devTooling.filePaths(projectType: .app, appName: "Test")
        #expect(files.count == 4)
        #expect(files.contains(".swiftlint.yml"))
        #expect(files.contains(".swiftformat"))
        #expect(files.contains("Makefile"))
        #expect(files.contains("Brewfile"))
    }

    @Test
    func `gitHooks returns pre-commit`() {
        let files = AddableFeature.gitHooks.filePaths(projectType: .app, appName: "Test")
        #expect(files.count == 1)
        #expect(files.contains("Scripts/git-hooks/pre-commit"))
    }

    @Test
    func `claudeMD returns CLAUDE.md path`() {
        let files = AddableFeature.claudeMD.filePaths(projectType: .app, appName: "Test")
        #expect(files.count == 1)
        #expect(files.contains(".claude/CLAUDE.md"))
    }

    @Test
    func `licenseChangelog returns LICENSE and CHANGELOG`() {
        let files = AddableFeature.licenseChangelog.filePaths(projectType: .package, appName: nil)
        #expect(files.count == 2)
        #expect(files.contains("LICENSE"))
        #expect(files.contains("CHANGELOG.md"))
    }

    @Test
    func `raw values match expected strings`() {
        #expect(AddableFeature.devTooling.rawValue == "devTooling")
        #expect(AddableFeature.gitHooks.rawValue == "gitHooks")
        #expect(AddableFeature.claudeMD.rawValue == "claudeMD")
        #expect(AddableFeature.licenseChangelog.rawValue == "licenseChangelog")
    }
}
