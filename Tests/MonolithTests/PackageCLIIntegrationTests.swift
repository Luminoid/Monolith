import Foundation
import Testing
@testable import MonolithLib

/// End-to-end coverage for Package and CLI generators across every feature
/// flag and every license type. Kept in a separate suite from the App
/// generator tests so neither hits `type_body_length` and to mirror the
/// `Sources/MonolithLib/Generators/{Package,CLI}` directory split.
///
/// Nested under `MonolithIntegrationSuite` so `.serialized` propagates
/// downward and `withTempDir` calls cannot race sibling suites.
extension MonolithIntegrationSuite {
    struct PackageCLIIntegrationTests {
        // MARK: - Package — Full Feature Coverage

        @Test
        func `Package with every PackageFeature generates expected files`() throws {
            try withTempDir(prefix: "monolith-test-pkg-all") { tempDir in
                let config = PackageConfig(
                    name: "BigLib",
                    platforms: [
                        PlatformVersion(platform: "iOS", version: "18.0"),
                        PlatformVersion(platform: "macOS", version: "15.0"),
                    ],
                    targets: [
                        TargetDefinition(name: "BigLibCore", dependencies: []),
                        TargetDefinition(name: "BigLibUI", dependencies: ["BigLibCore"]),
                    ],
                    features: [.strictConcurrency, .defaultIsolation, .devTooling, .gitHooks, .claudeMD, .licenseChangelog],
                    mainActorTargets: ["BigLibUI"],
                    author: "Test",
                    licenseType: .mit
                )
                try config.validate()
                try PackageProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/BigLib"
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Package.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/.swiftlint.yml"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/.swiftformat"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Makefile"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Brewfile"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Scripts/git-hooks/pre-commit"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/.claude/CLAUDE.md"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/LICENSE"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/CHANGELOG.md"))

                let pkg = try String(contentsOfFile: "\(basePath)/Package.swift", encoding: .utf8)
                #expect(pkg.contains(".iOS(.v18)"))
                #expect(pkg.contains(".macOS(.v15)"))
                // defaultIsolation only emitted for targets in mainActorTargets
                #expect(pkg.contains(".defaultIsolation(MainActor.self)"))
            }
        }

        @Test
        func `Package with packageDeps, xctestTargets, targetResources, and externalPackages wires them in`() throws {
            try withTempDir(prefix: "monolith-test-pkg-advanced") { tempDir in
                let config = PackageConfig(
                    name: "MultiLib",
                    platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
                    targets: [
                        TargetDefinition(name: "MultiLibCore", dependencies: []),
                        // ExtPkg is referenced here so the external-package registry
                        // override resolves it and emits the .package(url:) entry.
                        TargetDefinition(name: "MultiLibUI", dependencies: ["MultiLibCore", "ExtPkg"]),
                        TargetDefinition(name: "MultiLibTesting", dependencies: ["MultiLibCore"]),
                    ],
                    features: [.devTooling],
                    mainActorTargets: [],
                    author: "Test",
                    licenseType: .mit,
                    packageDeps: ["LumiKitUI"],
                    xctestTargets: ["MultiLibTesting"],
                    targetResources: ["MultiLibUI": ["Resources"]],
                    externalPackages: [
                        ExternalPackage(
                            name: "ExtPkg",
                            url: "https://example.com/ExtPkg",
                            requirement: "from: \"0.1.0\"",
                            packageName: nil
                        ),
                    ]
                )
                try config.validate()
                try PackageProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/MultiLib"
                let pkg = try String(contentsOfFile: "\(basePath)/Package.swift", encoding: .utf8)

                // packageDeps merged into every target
                #expect(pkg.contains("LumiKitUI"))
                // xctestTargets emits linkerSettings
                #expect(pkg.contains("linkerSettings"))
                #expect(pkg.contains(".linkedFramework(\"XCTest\")"))
                // targetResources emits .process(...) AND materializes the
                // directory so `swift build` doesn't warn about a missing path.
                #expect(pkg.contains(".process(\"Resources\")"))
                #expect(FileManager.default.fileExists(atPath: "\(tempDir)/MultiLib/Sources/MultiLibUI/Resources/.gitkeep"))
                // externalPackages emits the URL verbatim
                #expect(pkg.contains("https://example.com/ExtPkg"))
                #expect(pkg.contains("from: \"0.1.0\""))
            }
        }

        @Test
        func `Package with no features omits tooling and docs`() throws {
            try withTempDir(prefix: "monolith-test-pkg-bare") { tempDir in
                let config = PackageConfig(
                    name: "Bare",
                    platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
                    targets: [TargetDefinition(name: "Bare", dependencies: [])],
                    features: [],
                    mainActorTargets: [],
                    author: "Test",
                    licenseType: .mit
                )
                try PackageProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/Bare"
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Package.swift"))
                #expect(!FileManager.default.fileExists(atPath: "\(basePath)/Makefile"))
                #expect(!FileManager.default.fileExists(atPath: "\(basePath)/.swiftlint.yml"))
                #expect(!FileManager.default.fileExists(atPath: "\(basePath)/Scripts/git-hooks/pre-commit"))
                #expect(!FileManager.default.fileExists(atPath: "\(basePath)/.claude/CLAUDE.md"))
                #expect(!FileManager.default.fileExists(atPath: "\(basePath)/LICENSE"))
                #expect(!FileManager.default.fileExists(atPath: "\(basePath)/CHANGELOG.md"))
            }
        }

        // MARK: - CLI — Full Feature Coverage

        @Test
        func `CLI with every CLIFeature generates expected files`() throws {
            try withTempDir(prefix: "monolith-test-cli-all") { tempDir in
                let config = CLIConfig(
                    name: "everycli",
                    includeArgumentParser: true,
                    features: [.strictConcurrency, .devTooling, .gitHooks, .claudeMD, .licenseChangelog],
                    author: "Test",
                    licenseType: .apache2
                )
                try CLIProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/everycli"
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Package.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Sources/everycli/everycli.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/.swiftlint.yml"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/.swiftformat"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Makefile"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Brewfile"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Scripts/git-hooks/pre-commit"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/.claude/CLAUDE.md"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/LICENSE"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/CHANGELOG.md"))

                let pkg = try String(contentsOfFile: "\(basePath)/Package.swift", encoding: .utf8)
                #expect(pkg.contains("ArgumentParser"))
            }
        }

        @Test
        func `CLI without ArgumentParser omits dependency from Package_swift`() throws {
            try withTempDir(prefix: "monolith-test-cli-no-ap") { tempDir in
                let config = CLIConfig(
                    name: "noap",
                    includeArgumentParser: false,
                    features: [],
                    author: "Test",
                    licenseType: .apache2
                )
                try CLIProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/noap"
                let pkg = try String(contentsOfFile: "\(basePath)/Package.swift", encoding: .utf8)
                #expect(!pkg.contains("ArgumentParser"))

                let main = try String(contentsOfFile: "\(basePath)/Sources/noap/noap.swift", encoding: .utf8)
                #expect(!main.contains("ParsableCommand"))
            }
        }

        // MARK: - License Variants End-to-End

        @Test
        func `each LicenseType generates a matching LICENSE file`() throws {
            try withTempDir(prefix: "monolith-test-licenses") { tempDir in
                for (index, license) in LicenseType.allCases.enumerated() {
                    let config = CLIConfig(
                        name: "lic\(index)",
                        includeArgumentParser: false,
                        features: [.licenseChangelog],
                        author: "Test Author",
                        licenseType: license
                    )
                    try CLIProjectGenerator.generate(config: config)

                    let basePath = "\(tempDir)/lic\(index)"
                    #expect(FileManager.default.fileExists(atPath: "\(basePath)/LICENSE"), "Missing LICENSE for \(license)")
                    let body = try String(contentsOfFile: "\(basePath)/LICENSE", encoding: .utf8)
                    switch license {
                    case .mit:
                        #expect(body.contains("MIT License"))
                    case .apache2:
                        #expect(body.contains("Apache License"))
                    case .proprietary:
                        #expect(body.lowercased().contains("all rights reserved")
                            || body.lowercased().contains("proprietary"))
                    }
                }
            }
        }
    }
}
