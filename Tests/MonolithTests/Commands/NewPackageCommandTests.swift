import ArgumentParser
import Foundation
import Testing
@testable import MonolithLib

/// Flag parsing and the wizard of `monolith new package`. Configs are built
/// with `resolveConfig()`, which writes nothing.
struct NewPackageCommandTests {
    private func config(_ arguments: [String]) throws -> PackageConfig {
        try NewPackageCommand.parse(arguments).resolveConfig().config
    }

    // MARK: - Flags

    @Test
    func `a bare name gets one iOS library target`() throws {
        let config = try config(["--name", "Pkg", "--no-interactive"])
        #expect(config.targets.map(\.name) == ["Pkg"])
        #expect(config.platforms.map(\.platform) == ["iOS"])
        #expect(config.licenseType == .mit)
        #expect(config.features.isEmpty)
    }

    /// Regression: `--preset full` printed the empty-main-actor-targets
    /// warning, though a clean full run should print nothing.
    @Test
    func `defaultIsolation isolates the only library target`() throws {
        let full = try config(["--name", "Pkg", "--preset", "full", "--no-interactive"])
        #expect(full.features.contains(.defaultIsolation))
        #expect(full.mainActorTargets == ["Pkg"])

        let withTool = try config(["--name", "Pkg", "--targets", "Pkg,pkg-tool:exec", "--features", "defaultIsolation", "--no-interactive"])
        #expect(withTool.mainActorTargets == ["Pkg"])

        // Two libraries: no safe guess, so the warning stays.
        let twoLibraries = try config(["--name", "Pkg", "--targets", "PkgCore,PkgUI", "--features", "defaultIsolation", "--no-interactive"])
        #expect(twoLibraries.mainActorTargets.isEmpty)

        let explicit = try config(["--name", "Pkg", "--targets", "PkgCore,PkgUI", "--features", "defaultIsolation", "--main-actor-targets", "PkgUI", "--no-interactive"])
        #expect(explicit.mainActorTargets == ["PkgUI"])
    }

    /// Regression: `--main-actor-targets` without the feature isolated the
    /// target in Package.swift but left the Makefile and docs on `swift build`.
    @Test
    func `--main-actor-targets alone turns on defaultIsolation`() throws {
        let flagOnly = try config(["--name", "Pkg", "--targets", "PkgCore,PkgUI", "--main-actor-targets", "PkgUI", "--no-interactive"])
        let withFeature = try config(["--name", "Pkg", "--targets", "PkgCore,PkgUI", "--features", "defaultIsolation", "--main-actor-targets", "PkgUI", "--no-interactive"])
        #expect(flagOnly.features == withFeature.features)
        #expect(flagOnly.requiresXcodebuild)
        #expect(ClaudeMDGenerator.generateForPackage(config: flagOnly) == ClaudeMDGenerator.generateForPackage(config: withFeature))
    }

    @Test
    func `the package flags reach the config`() throws {
        let config = try config([
            "--name", "MultiLib", "--targets", "MultiLibCore,MultiLibTesting,multilib-tool:exec",
            "--target-deps", "MultiLibTesting:MultiLibCore", "--platforms", "iOS 18.0,macOS 15.0",
            "--package-deps", "MultiLibCore", "--test-helper-targets", "MultiLibTesting",
            "--target-resources", "MultiLibCore:Resources", "--external-packages", "ExtPkg=../ExtPkg",
            "--license", "apache2", "--no-interactive",
        ])
        #expect(config.targets.map(\.name) == ["MultiLibCore", "MultiLibTesting", "multilib-tool"])
        #expect(config.targets.last?.isExecutable == true)
        #expect(config.targets[1].dependencies == ["MultiLibCore"])
        #expect(config.platforms.map(\.platform) == ["iOS", "macOS"])
        #expect(config.packageDeps == ["MultiLibCore"])
        #expect(config.testHelperTargets == ["MultiLibTesting"])
        #expect(config.targetResources == ["MultiLibCore": ["Resources"]])
        #expect(config.externalPackages.map(\.name) == ["ExtPkg"])
        #expect(config.licenseType == .apache2)
    }

    @Test
    func `bad values fail at parse or config time`() {
        #expect(throws: (any Error).self) { try NewPackageCommand.parse(["--preset", "everything"]) }
        #expect(throws: (any Error).self) { try config(["--name", "Pkg", "--target-resources", "NoColon", "--no-interactive"]) }
        #expect(throws: (any Error).self) { try config(["--no-interactive"]) }
    }

    @Test
    func `--git and --no-git are exclusive`() {
        #expect(throws: (any Error).self) { try NewPackageCommand.parse(["--name", "Pkg", "--git", "--no-git"]) }
    }

    @Test
    func `--load-config refuses the package options`() {
        for extra in [["--targets", "A"], ["--target-deps", "A:B"], ["--main-actor-targets", "A"], ["--external-packages", "X=../X"], ["--license", "mit"]] {
            #expect(throws: (any Error).self, "\(extra)") { try NewPackageCommand.parse(["--load-config", "pkg.json"] + extra) }
        }
    }

    // MARK: - Wizard

    private func wizard(
        _ arguments: [String] = [],
        answers: KeyValuePairs<String, [String]>
    ) throws -> (resolved: ResolvedConfig<PackageConfig>, script: PromptScript) {
        let command = try NewPackageCommand.parse(arguments)
        let script = PromptScript(answers: answers)
        let resolved = try PromptEngine.$script.withValue(script) { try command.resolveConfig() }
        return (resolved, script)
    }

    @Test
    func `the wizard reads executable targets and isolates the only library`() throws {
        let (resolved, _) = try wizard(answers: [
            "Package name": ["MultiLib"], "Targets": ["MultiLibCore, multilib-tool:exec"],
            "multilib-tool deps": ["MultiLibCore"], "Feature preset": ["3"],
        ])
        let config = resolved.config
        #expect(config.targets.map(\.name) == ["MultiLibCore", "multilib-tool"])
        #expect(config.targets.last?.isExecutable == true)
        #expect(config.targets.last?.dependencies == ["MultiLibCore"])
        #expect(config.features == Preset.full.packageFeatures())
        #expect(config.mainActorTargets == ["MultiLibCore"])
        #expect(config.platforms.map(\.platform) == ["iOS"])
    }

    /// The package wizard used to offer strictConcurrency, a no-op.
    @Test
    func `the wizard offers no no-op feature`() throws {
        let (_, script) = try wizard(answers: ["Package name": ["Pkg"]])
        #expect(!script.transcript.contains("Strict concurrency"))
    }

    @Test
    func `the wizard asks for MainActor targets with several libraries`() throws {
        let (resolved, script) = try wizard(answers: [
            "Package name": ["Pkg"], "Targets": ["PkgCore,PkgUI"], "Optional features": ["1"], "MainActor targets": ["PkgUI"],
        ])
        #expect(resolved.config.mainActorTargets == ["PkgUI"])
        #expect(script.questions.contains("MainActor targets (comma-separated)"))
    }

    @Test
    func `flags answer the package wizard`() throws {
        let (resolved, script) = try wizard(
            ["--name", "Pkg", "--targets", "PkgCore,PkgUI", "--target-deps", "PkgUI:PkgCore", "--platforms", "macOS 15.0", "--features", "devTooling"],
            answers: [:]
        )
        let config = resolved.config
        #expect(config.targets.map(\.dependencies) == [[], ["PkgCore"]])
        #expect(config.platforms.map(\.platform) == ["macOS"])
        #expect(config.features == [.devTooling])
        for skipped in ["Package name", "Target platforms", "Targets", "PkgUI deps", "Feature preset", "Optional features"] {
            #expect(!script.questions.contains { $0.contains(skipped) }, "\(skipped) was asked")
        }
    }

    @Test
    func `the wizard needs --targets with --target-deps`() throws {
        let command = try NewPackageCommand.parse(["--target-deps", "A:B"])
        PromptEngine.$script.withValue(PromptScript(lines: [])) {
            let error = #expect(throws: (any Error).self) { try command.resolveConfig() }
            #expect("\(String(describing: error))".contains("--target-deps needs --targets"))
        }
    }
}
