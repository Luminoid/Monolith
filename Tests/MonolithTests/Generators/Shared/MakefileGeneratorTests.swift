import Foundation
import Testing
@testable import MonolithLib

struct MakefileGeneratorTests {
    @Test
    func `base targets for package`() {
        let output = MakefileGenerator.generate(projectType: .package)
        #expect(output.contains(".PHONY:"))
        #expect(output.contains("lint:"))
        #expect(output.contains("lint-fix:"))
        #expect(output.contains("format:"))
        #expect(output.contains("check:"))
        #expect(output.contains("swift build"))
        #expect(output.contains("swift test"))
    }

    @Test
    func `app targets include SCHEME`() {
        let output = MakefileGenerator.generate(projectType: .app, appName: "TestApp")
        #expect(output.contains("SCHEME = TestApp"))
        #expect(output.contains("xcodebuild build"))
        #expect(output.contains("xcodebuild test"))
        #expect(output.contains("archive:"))
        #expect(output.contains("release: archive export upload"))
    }

    @Test
    func `app with Fastlane adds targets`() {
        let output = MakefileGenerator.generate(projectType: .app, appName: "TestApp", hasFastlane: true)
        #expect(output.contains("fastlane-validate:"))
        #expect(output.contains("fastlane-beta:"))
        #expect(output.contains("bundle exec fastlane"))
    }

    @Test
    func `includes setup-hooks when git hooks enabled`() {
        let output = MakefileGenerator.generate(projectType: .package, hasGitHooks: true)
        #expect(output.contains("setup-hooks:"))
        #expect(output.contains("git config core.hooksPath Scripts/git-hooks"))
        #expect(output.contains("setup-hooks"))
    }

    @Test
    func `package with defaultIsolation uses xcodebuild`() {
        let output = MakefileGenerator.generate(
            projectType: .package, appName: "MyLib",
            hasDefaultIsolation: true
        )
        #expect(output.contains("SCHEME = MyLib-Package"))
        #expect(output.contains("xcodebuild build"))
        #expect(output.contains("xcodebuild test"))
        #expect(!output.contains("swift build"))
        #expect(!output.contains("swift test"))
    }

    @Test
    func `excludes setup-hooks when git hooks disabled`() {
        let output = MakefileGenerator.generate(projectType: .package, hasGitHooks: false)
        #expect(!output.contains("setup-hooks"))
    }
}
