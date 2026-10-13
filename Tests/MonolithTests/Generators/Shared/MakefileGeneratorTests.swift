import Foundation
import Testing
@testable import MonolithLib

struct MakefileGeneratorTests {
    /// The recipe lines of `target` (tab-indented lines after `target:` up to
    /// the next blank line), without the leading tab.
    private func recipe(_ target: String, in output: String) -> [String] {
        let lines = output.components(separatedBy: "\n")
        guard let start = lines.firstIndex(where: { $0.hasPrefix("\(target):") }) else { return [] }
        var body: [String] = []
        for line in lines[(start + 1)...] {
            guard line.hasPrefix("\t") else { break }
            body.append(String(line.dropFirst()))
        }
        return body
    }

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
        #expect(output.contains("release: archive\n"))
    }

    @Test
    func `release archives and opens the archive instead of uploading`() {
        let output = MakefileGenerator.generate(projectType: .app, appName: "TestApp", projectSystem: .xcodeGen)
        #expect(recipe("release", in: output) == ["open build/$(SCHEME).xcarchive"])
        #expect(!output.contains("altool"))
        #expect(!output.contains("-exportArchive"))
        #expect(!output.contains("ExportOptions.plist"))
        #expect(!output.contains("export:"))
        #expect(!output.contains("upload:"))
        let phony = output.components(separatedBy: "\n").first ?? ""
        #expect(phony.hasSuffix(" archive release"), "\(phony)")
    }

    @Test
    func `archive recipe is well formed`() {
        let output = MakefileGenerator.generate(projectType: .app, appName: "TestApp", projectSystem: .xcodeProj)
        #expect(recipe("archive", in: output) == [
            "xcodebuild archive \\",
            "  -project $(PROJECT) \\",
            "  -scheme $(SCHEME) \\",
            "  -destination 'generic/platform=iOS' \\",
            "  -archivePath build/$(SCHEME).xcarchive \\",
            "  -allowProvisioningUpdates",
        ])
    }

    @Test
    func `app icon validation runs first in archive`() {
        let output = MakefileGenerator.generate(projectType: .app, appName: "TestApp", hasAppIconValidation: true, hasMacCatalyst: true)
        #expect(recipe("archive", in: output).first == "bash Scripts/validate-app-icon.sh")
        #expect(recipe("archive-mac", in: output).first == "bash Scripts/validate-app-icon.sh")
        let plain = MakefileGenerator.generate(projectType: .app, appName: "TestApp")
        #expect(recipe("archive", in: plain).first == "xcodebuild archive \\")
    }

    @Test
    func `Mac Catalyst adds build, archive, and release targets`() {
        let output = MakefileGenerator.generate(projectType: .app, appName: "TestApp", projectSystem: .xcodeGen, hasMacCatalyst: true)
        #expect(recipe("build-catalyst", in: output) == [
            "xcodebuild build \\",
            "  -project $(PROJECT) \\",
            "  -scheme $(SCHEME) \\",
            "  -destination 'platform=macOS,variant=Mac Catalyst' \\",
            "  -skipPackagePluginValidation \\",
            "  -quiet \\",
            "  CODE_SIGNING_ALLOWED=NO",
        ])
        let archive = recipe("archive-mac", in: output)
        #expect(archive.contains("  -destination 'generic/platform=macOS,variant=Mac Catalyst' \\"))
        #expect(archive.contains("  -archivePath build/$(SCHEME)-mac.xcarchive \\"))
        #expect(archive.last == "  -allowProvisioningUpdates")
        #expect(output.contains("release-mac: archive-mac\n"))
        #expect(recipe("release-mac", in: output) == ["open build/$(SCHEME)-mac.xcarchive"])

        let phony = output.components(separatedBy: "\n").first ?? ""
        for target in ["build-catalyst", "archive-mac", "release-mac"] {
            #expect(phony.contains(" \(target)"), "\(target) missing from .PHONY")
            #expect(output.contains("@echo \"  make \(target) "), "\(target) missing from help")
        }
    }

    @Test
    func `no Mac Catalyst targets by default`() {
        let output = MakefileGenerator.generate(projectType: .app, appName: "TestApp")
        #expect(!output.contains("catalyst"))
        #expect(!output.contains("archive-mac"))
        #expect(!output.contains("release-mac"))
    }

    @Test
    func `PROJECT is omitted without an Xcode project`() {
        // A detected app without a project file (`add devTooling`) builds by scheme alone.
        let output = MakefileGenerator.generate(projectType: .app, appName: "TestApp", projectSystem: .spm, hasMacCatalyst: true)
        #expect(!output.contains("PROJECT"))
        #expect(recipe("build-catalyst", in: output)[1] == "  -scheme $(SCHEME) \\")
    }

    @Test
    func `every xcodebuild recipe continues each line but the last`() {
        let outputs = [
            MakefileGenerator.generate(projectType: .app, appName: "TestApp", projectSystem: .xcodeProj, disableTestParallelism: true, hasMacCatalyst: true),
            MakefileGenerator.generate(projectType: .package, appName: "MyLib", hasDefaultIsolation: true),
        ]
        for output in outputs {
            for target in ["build", "build-clean", "test", "build-catalyst", "archive", "archive-mac"] {
                let body = recipe(target, in: output).drop { !$0.hasPrefix("xcodebuild") }
                guard !body.isEmpty else { continue }
                #expect(body.dropLast().allSatisfy { $0.hasSuffix(" \\") }, "\(target): \(body)")
                #expect(body.last?.hasSuffix("\\") == false, "\(target) ends on a continuation")
            }
        }
    }

    @Test
    func `no recipe sets pipefail`() {
        // No recipe pipes, so `set -o pipefail` did nothing.
        for output in [
            MakefileGenerator.generate(projectType: .app, appName: "TestApp"),
            MakefileGenerator.generate(projectType: .package, appName: "MyLib", hasDefaultIsolation: true),
        ] {
            #expect(!output.contains("pipefail"))
        }
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
    func `package xcodebuild destination takes the simulator version knob`() {
        let output = MakefileGenerator.generate(projectType: .package, appName: "MyLib", hasDefaultIsolation: true)
        #expect(output.contains("IOS_VERSION ?= \(Defaults.simulatorOS)\n"))
        #expect(output.contains("DESTINATION = platform=iOS Simulator,name=\(Defaults.simulatorDevice),OS=$(IOS_VERSION)\n"))
    }

    @Test
    func `package help names the build mode it emits`() {
        let xcodebuild = MakefileGenerator.generate(projectType: .package, appName: "MyLib", hasDefaultIsolation: true)
        #expect(xcodebuild.contains("Build for the iOS Simulator (xcodebuild)\""))
        #expect(xcodebuild.contains("Run tests on the iOS Simulator (xcodebuild)\""))
        #expect(!xcodebuild.contains("swift build"))

        let swiftPM = MakefileGenerator.generate(projectType: .cli)
        #expect(swiftPM.contains("Build (swift build)\""))
        #expect(swiftPM.contains("Run tests (swift test)\""))
        #expect(!swiftPM.contains("xcodebuild"))
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
        // Every xcodebuild invocation against an SPM
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
        // Every build and test invocation passes `-quiet` so
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
    func `disableTestParallelism adds -parallel-testing-enabled NO to test target only`() {
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

        #expect(recipe("test", in: output).contains("  -parallel-testing-enabled NO \\"))
        #expect(recipe("test", in: output).last == "  CODE_SIGNING_ALLOWED=NO")
        #expect(!recipe("build", in: output).contains { $0.contains("-parallel-testing-enabled") })
    }

    @Test
    func `disableTestParallelism off by default`() {
        let output = MakefileGenerator.generate(projectType: .app, appName: "TestApp")
        #expect(!output.contains("-parallel-testing-enabled"))
    }
}
