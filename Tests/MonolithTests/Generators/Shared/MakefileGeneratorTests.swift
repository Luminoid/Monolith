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
        // Assert against actual recipe lines (which start with a tab) so the
        // help-text blurb "swift build / xcodebuild" doesn't trigger a false
        // negative on the `contains("swift build")` check. xcodebuild-backed
        // packages should NOT have a `\tswift build` recipe line.
        let output = MakefileGenerator.generate(
            projectType: .package, appName: "MyLib",
            hasDefaultIsolation: true
        )
        #expect(output.contains("SCHEME = MyLib"))
        #expect(output.contains("xcodebuild build"))
        #expect(output.contains("xcodebuild test"))
        #expect(!output.contains("\tswift build"))
        #expect(!output.contains("\tswift test"))
    }

    @Test
    func `excludes setup-hooks when git hooks disabled`() {
        let output = MakefileGenerator.generate(projectType: .package, hasGitHooks: false)
        #expect(!output.contains("setup-hooks"))
    }

    @Test
    func `help target is the default goal`() {
        let output = MakefileGenerator.generate(projectType: .package)
        #expect(output.contains(".DEFAULT_GOAL := help"))
        #expect(output.contains("help:"))
        #expect(output.contains("@echo \"Project targets:\""))
    }

    @Test
    func `localization adds audit-strings target wired into check and help`() throws {
        let output = MakefileGenerator.generate(
            projectType: .app, appName: "MyApp",
            hasLocalization: true
        )
        #expect(output.contains("audit-strings:"))
        #expect(output.contains("python3 Scripts/localization/audit_strings.py"))
        // The `check` target should also invoke it so CI catches missing
        // translations alongside lint/format issues.
        let checkRange = try #require(output.range(of: "check:"))
        let nextSection = output.range(of: "\n\n", range: checkRange.upperBound ..< output.endIndex)
            ?? (output.endIndex ..< output.endIndex)
        let checkBody = output[checkRange.upperBound ..< nextSection.lowerBound]
        #expect(checkBody.contains("audit_strings.py"))
        // help listing includes the audit-strings line.
        #expect(output.contains("make audit-strings"))
    }

    @Test
    func `localization is omitted when feature disabled`() {
        let output = MakefileGenerator.generate(projectType: .app, appName: "MyApp")
        #expect(!output.contains("audit-strings"))
        #expect(!output.contains("audit_strings.py"))
    }

    @Test
    func `package Makefile uses xcodeBuildScheme when provided`() {
        // When the caller resolves the package as mixed-kind (executables +
        // libs, or test-helper libs alongside MainActor libs), the Makefile
        // SCHEME tracks `<Name>-Package` umbrella instead of `<Name>`. One
        // xcodebuild invocation then covers every target.
        let output = MakefileGenerator.generate(
            projectType: .package, appName: "MultiLib",
            hasDefaultIsolation: true,
            xcodeBuildScheme: "MultiLib-Package"
        )
        #expect(output.contains("SCHEME = MultiLib-Package"))
        #expect(!output.contains("SCHEME = MultiLib\n"))
    }

    @Test
    func `package Makefile falls back to appName when xcodeBuildScheme is nil`() {
        // Single-library packages don't need the umbrella; the named scheme
        // is the only product.
        let output = MakefileGenerator.generate(
            projectType: .package, appName: "MyLib",
            hasDefaultIsolation: true
        )
        #expect(output.contains("SCHEME = MyLib"))
        #expect(!output.contains("SCHEME = MyLib-Package"))
    }

    @Test
    func `package xcodebuild includes -skipPackagePluginValidation on both build and test`() {
        // Workspace convention: every xcodebuild invocation against an SPM
        // package passes this flag so adopters don't get plugin-trust prompts
        // the moment any dependency adds an SPM build tool plugin.
        let output = MakefileGenerator.generate(
            projectType: .package, appName: "MyLib",
            hasDefaultIsolation: true
        )
        #expect(output.components(separatedBy: "-skipPackagePluginValidation").count - 1 == 2)
    }

    @Test
    func `app xcodebuild includes -skipPackagePluginValidation on build, build-clean, and test`() {
        // Three occurrences: `build`, `build-clean` (added v0.4 — runs
        // `clean build` to verify zero-warning state), and `test`.
        let output = MakefileGenerator.generate(projectType: .app, appName: "TestApp")
        #expect(output.components(separatedBy: "-skipPackagePluginValidation").count - 1 == 3)
    }

    @Test
    func `app xcodebuild includes -quiet on every invocation`() {
        // Workspace convention: every xcodebuild invocation passes `-quiet` so
        // the recipe output isn't flooded with per-file compile lines. Three
        // occurrences in recipe lines for an app (build / build-clean / test);
        // the `make help` line that documents the flag also mentions `-quiet`
        // in its description text but isn't an xcodebuild call. Count only
        // continuation-prefixed (`\t  -quiet \\`) occurrences to focus on
        // actual command-line emissions.
        let output = MakefileGenerator.generate(projectType: .app, appName: "TestApp")
        let recipeQuietCount = output.components(separatedBy: "\t  -quiet \\").count - 1
        #expect(recipeQuietCount == 3, "expected 3 recipe -quiet flags, got \(recipeQuietCount)")
    }

    @Test
    func `app Makefile emits build-clean target`() {
        let output = MakefileGenerator.generate(projectType: .app, appName: "TestApp")
        #expect(output.contains("build-clean:"))
        #expect(output.contains("xcodebuild clean build"))
    }

    @Test
    func `disableTestParallelism adds -parallel-testing-enabled NO to test target only`() throws {
        // Singleton-prone apps (a shared repository on top of Core Data or
        // SwiftData + CloudKit) race when Swift Testing's in-process
        // scheduler runs suites in parallel. The flag should land in the
        // `test:` recipe, not the `build:` recipe (no test runner involved
        // there), so assert it's scoped to test, not just present somewhere.
        let output = MakefileGenerator.generate(
            projectType: .app, appName: "TestApp",
            disableTestParallelism: true
        )
        #expect(output.contains("-parallel-testing-enabled NO"))

        let testRange = try #require(output.range(of: "test:"))
        let nextTarget = output.range(of: "\n\narchive:", range: testRange.upperBound ..< output.endIndex)
            ?? (output.endIndex ..< output.endIndex)
        let testBody = output[testRange.upperBound ..< nextTarget.lowerBound]
        #expect(testBody.contains("-parallel-testing-enabled NO"))

        let buildRange = try #require(output.range(of: "build:"))
        let buildEnd = output.range(of: "\n\ntest:", range: buildRange.upperBound ..< output.endIndex)
            ?? (output.endIndex ..< output.endIndex)
        let buildBody = output[buildRange.upperBound ..< buildEnd.lowerBound]
        #expect(!buildBody.contains("-parallel-testing-enabled"))
    }

    @Test
    func `disableTestParallelism off by default`() {
        let output = MakefileGenerator.generate(projectType: .app, appName: "TestApp")
        #expect(!output.contains("-parallel-testing-enabled"))
    }
}
