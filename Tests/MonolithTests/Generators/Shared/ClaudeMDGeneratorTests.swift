import Foundation
import Testing
@testable import MonolithLib

struct ClaudeMDGeneratorTests {
    // MARK: - App

    @Test
    func `app CLAUDE.md has app name and tech stack`() {
        let config = AppConfig(
            name: "MyApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .xcodeProj,
            tabs: [],
            primaryColor: "#007AFF",
            features: [.swiftData, .lumiKit],
            author: "Test",
            licenseType: .proprietary
        )
        let output = ClaudeMDGenerator.generateForApp(config: config)
        #expect(output.contains("# MyApp"))
        #expect(output.contains("SwiftData"))
        #expect(output.contains("LumiKit"))
        #expect(output.contains("make build"))
    }

    @Test
    func `app CLAUDE.md shows tab navigation when tabs present`() {
        let config = AppConfig(
            name: "MyApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .xcodeProj,
            tabs: [TabDefinition(name: "Home", icon: "house")],
            primaryColor: "#007AFF",
            features: [],
            author: "Test",
            licenseType: .proprietary
        )
        let output = ClaudeMDGenerator.generateForApp(config: config)
        #expect(output.contains("UITabBarController"))
    }

    @Test
    func `app CLAUDE.md shows xcodebuild for XcodeGen`() {
        let config = AppConfig(
            name: "MyApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .xcodeGen,
            tabs: [],
            primaryColor: "#007AFF",
            features: [],
            author: "Test",
            licenseType: .proprietary
        )
        let output = ClaudeMDGenerator.generateForApp(config: config)
        #expect(output.contains("xcodegen generate"))
        #expect(output.contains("make build"))
    }

    // MARK: - Package

    @Test
    func `package CLAUDE.md has target table`() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "Core", dependencies: []),
                TargetDefinition(name: "UI", dependencies: ["Core"]),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["UI"],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(output.contains("# MyLib"))
        #expect(output.contains("| Core |"))
        #expect(output.contains("| UI |"))
        #expect(output.contains("xcodebuild"))
        #expect(output.contains("-scheme MyLib"))
        #expect(!output.contains("-scheme MyLib-Package"))
    }

    @Test
    func `package CLAUDE.md uses literal bullet, not Swift escape syntax`() {
        // Regression: an earlier version emitted "\\u{2022}" (literal backslash-u
        // sequence) into the rendered markdown footer because the Swift string
        // literal was double-escaped. The output must be the actual bullet glyph.
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLib", dependencies: [])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(output.contains("•"))
        #expect(!output.contains("\\u{2022}"))
    }

    @Test
    func `package CLAUDE.md xcodebuild includes -skipPackagePluginValidation`() {
        // Workspace convention (LumiKit / Prism use it). Without the flag, any
        // package that later adds an SPM build tool plugin triggers an Xcode
        // plugin-trust prompt that breaks unattended xcodebuild invocations.
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLibUI", dependencies: [])],
            features: [.defaultIsolation],
            mainActorTargets: ["MyLibUI"],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        // Flag present on both build and test invocations.
        #expect(output.components(separatedBy: "-skipPackagePluginValidation").count - 1 == 2)
    }

    // MARK: - #3 — Umbrella scheme

    @Test
    func `package CLAUDE.md uses umbrella scheme when package has executable targets`() {
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MultiLib", dependencies: []),
                TargetDefinition(name: "multi-tool", dependencies: ["MultiLib"], isExecutable: true),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["MultiLib"],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(output.contains("-scheme MultiLib-Package"))
        // Bare scheme must not appear as a build target — the umbrella
        // covers everything.
        #expect(!output.contains("-scheme MultiLib "))
    }

    @Test
    func `package CLAUDE.md uses umbrella scheme when package has test-helper targets`() {
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MultiLib", dependencies: []),
                TargetDefinition(name: "MultiLibTesting", dependencies: ["MultiLib"]),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["MultiLib"],
            author: "Test",
            licenseType: .mit,
            testHelperTargets: ["MultiLibTesting"]
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(output.contains("-scheme MultiLib-Package"))
    }

    @Test
    func `package CLAUDE.md keeps named scheme for single-library packages`() {
        // No executables, no test-helpers → named scheme is sufficient.
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLibUI", dependencies: [])],
            features: [.defaultIsolation],
            mainActorTargets: ["MyLibUI"],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(output.contains("-scheme MyLib "))
        #expect(!output.contains("-scheme MyLib-Package"))
    }

    @Test
    func `package CLAUDE.md documents why umbrella scheme is used`() {
        // The umbrella scheme is auto-generated by Xcode; future readers may
        // "simplify" Package.swift in ways that drop it. Document the reason
        // so the build command stays load-bearing.
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MultiLib", dependencies: []),
                TargetDefinition(name: "MultiLibTesting", dependencies: ["MultiLib"]),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["MultiLib"],
            author: "Test",
            licenseType: .mit,
            testHelperTargets: ["MultiLibTesting"]
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(output.contains("MultiLib-Package` umbrella scheme is required"))
        // Tailored explainer: this package has a test-helper but no exec.
        #expect(output.contains("test-helper library that needs to build"))
        #expect(!output.contains("executable sibling targets"))
        #expect(!output.contains("mixes target kinds")) // generic fallback should not appear
    }

    @Test
    func `package CLAUDE.md umbrella explainer mentions executables when only execs are present`() {
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MultiLib", dependencies: []),
                TargetDefinition(name: "multi-tool", dependencies: ["MultiLib"], isExecutable: true),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["MultiLib"],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(output.contains("executable sibling targets alongside libraries"))
        #expect(!output.contains("test-helper library that needs to build"))
    }

    @Test
    func `package CLAUDE.md umbrella explainer mentions both kinds when both are present`() {
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MultiLib", dependencies: []),
                TargetDefinition(name: "MultiLibTesting", dependencies: ["MultiLib"]),
                TargetDefinition(name: "multi-tool", dependencies: ["MultiLib"], isExecutable: true),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["MultiLib"],
            author: "Test",
            licenseType: .mit,
            testHelperTargets: ["MultiLibTesting"]
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(output.contains("mixes executables, test-helper libs, and MainActor libs"))
    }

    @Test
    func `package CLAUDE.md umbrella explainer avoids workspace-banned em dashes`() {
        // Workspace rule 1: no inline em dashes as parenthetical separators
        // (`key — explanation` mid-sentence). The umbrella blockquote used to
        // contain ` scheme — that only builds...`; replaced with a comma.
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MultiLib", dependencies: []),
                TargetDefinition(name: "MultiLibTesting", dependencies: ["MultiLib"]),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["MultiLib"],
            author: "Test",
            licenseType: .mit,
            testHelperTargets: ["MultiLibTesting"]
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        // The specific banned form: ` scheme — that only builds...`
        #expect(!output.contains("scheme — that"))
        // The replacement form: ` scheme, which only builds the main library.`
        #expect(output.contains("scheme, which only builds the main library"))
    }

    @Test
    func `package CLAUDE.md omits umbrella explainer for single-library packages`() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLibUI", dependencies: [])],
            features: [.defaultIsolation],
            mainActorTargets: ["MyLibUI"],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(!output.contains("umbrella scheme is required"))
    }

    @Test
    func `package CLAUDE.md splits libraries from executables in tables`() throws {
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MultiLib", dependencies: []),
                TargetDefinition(name: "multi-tool", dependencies: ["MultiLib"], isExecutable: true),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["MultiLib"],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)

        // Two separate sections — not one mixed table.
        #expect(output.contains("## Libraries"))
        #expect(output.contains("## Executables"))

        // Library table column header is "Default isolation" (wording matters —
        // the prior "MainActor" column header was misleading because a library
        // that depends on a MainActor lib isn't itself MainActor-isolated).
        // The cell VALUE can still be the string "MainActor" — that's the
        // accurate name of the isolation level for targets that opt in.
        #expect(output.contains("| Target | Dependencies | Default isolation |"))
        #expect(!output.contains("| Target | Dependencies | MainActor |"))
        #expect(output.contains("| MultiLib | — | MainActor |"))

        // Executable table row formats the binary as backticked code + run command.
        #expect(output.contains("| `multi-tool` |"))
        #expect(output.contains("swift run multi-tool"))

        // The exec must NOT appear in the libraries table.
        let libsHeader = try #require(output.range(of: "## Libraries"))
        let execsHeader = try #require(output.range(of: "## Executables"))
        let librariesSection = output[libsHeader.upperBound ..< execsHeader.lowerBound]
        #expect(!librariesSection.contains("multi-tool"))
    }

    @Test
    func `package CLAUDE.md adds swift run snippet for executable targets`() {
        // When a package has executable sibling target(s), the Build & Test
        // section should also show how to run them. Without this, the only
        // mention of the executable is the Executables table — adopters have
        // to infer that `swift run <name>` is the entry point.
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MultiLib", dependencies: []),
                TargetDefinition(name: "multi-tool", dependencies: ["MultiLib"], isExecutable: true),
                TargetDefinition(name: "multi-codegen", dependencies: ["MultiLib"], isExecutable: true),
            ],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(output.contains("swift run multi-tool"))
        #expect(output.contains("swift run multi-codegen"))
        // Plural form for ≥2 executables.
        #expect(output.contains("Run executable sibling targets:"))
    }

    @Test
    func `package CLAUDE.md omits swift run snippet for lib-only packages`() {
        // No executables = no run snippet (the table is the only mention).
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLib", dependencies: [])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(!output.contains("Run executable"))
        #expect(!output.contains("swift run "))
    }

    @Test
    func `package CLAUDE.md run snippet uses singular phrasing for one executable`() {
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MultiLib", dependencies: []),
                TargetDefinition(name: "multi-tool", dependencies: ["MultiLib"], isExecutable: true),
            ],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(output.contains("Run executable sibling target:"))
        #expect(!output.contains("Run executable sibling targets:"))
    }

    // MARK: - CLI

    @Test
    func `CLI CLAUDE.md has run command`() {
        let config = CLIConfig(
            name: "mytool",
            includeArgumentParser: true,
            features: [],
            author: "Test",
            licenseType: .apache2
        )
        let output = ClaudeMDGenerator.generateForCLI(config: config)
        #expect(output.contains("# mytool"))
        #expect(output.contains("swift run mytool"))
    }
}
