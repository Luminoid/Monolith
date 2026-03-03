import Foundation
import Testing
@testable import MonolithLib

@Suite("MakefileGenerator")
struct MakefileGeneratorTests {
    @Test("base targets for package")
    func basePackage() {
        let output = MakefileGenerator.generate(projectType: .package)
        #expect(output.contains(".PHONY:"))
        #expect(output.contains("lint:"))
        #expect(output.contains("lint-fix:"))
        #expect(output.contains("format:"))
        #expect(output.contains("check:"))
        #expect(output.contains("swift build"))
        #expect(output.contains("swift test"))
    }

    @Test("app targets include SCHEME")
    func appTargets() {
        let output = MakefileGenerator.generate(projectType: .app, appName: "TestApp")
        #expect(output.contains("SCHEME = TestApp"))
        #expect(output.contains("xcodebuild build"))
        #expect(output.contains("xcodebuild test"))
        #expect(output.contains("archive:"))
        #expect(output.contains("release: archive export upload"))
    }

    @Test("app with Fastlane adds targets")
    func appFastlane() {
        let output = MakefileGenerator.generate(projectType: .app, appName: "TestApp", hasFastlane: true)
        #expect(output.contains("fastlane-validate:"))
        #expect(output.contains("fastlane-beta:"))
        #expect(output.contains("bundle exec fastlane"))
    }

    @Test("includes setup-hooks when git hooks enabled")
    func setupHooks() {
        let output = MakefileGenerator.generate(projectType: .package, hasGitHooks: true)
        #expect(output.contains("setup-hooks:"))
        #expect(output.contains("git config core.hooksPath Scripts/git-hooks"))
        #expect(output.contains("setup-hooks"))
    }

    @Test("excludes setup-hooks when git hooks disabled")
    func noSetupHooks() {
        let output = MakefileGenerator.generate(projectType: .package, hasGitHooks: false)
        #expect(!output.contains("setup-hooks"))
    }
}
