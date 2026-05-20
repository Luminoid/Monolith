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
        func `Package with packageDeps, testHelperTargets, targetResources, and externalPackages wires them in`() throws {
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
                    testHelperTargets: ["MultiLibTesting"],
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
                // testHelperTargets emit NO linkerSettings (Swift Testing is
                // bundled with the toolchain; XCTest interop is opt-in by
                // adding `import XCTest` to the source).
                #expect(!pkg.contains("linkerSettings"))
                #expect(!pkg.contains(".linkedFramework(\"XCTest\")"))
                // The helper source uses Swift Testing as the default, and
                // pulls in any internal-lib deps it depends on so the wiring
                // in Package.swift isn't dead weight.
                let testingSource = try String(
                    contentsOfFile: "\(basePath)/Sources/MultiLibTesting/MultiLibTesting.swift",
                    encoding: .utf8
                )
                #expect(testingSource.contains("import Testing"))
                #expect(testingSource.contains("import MultiLibCore"))
                #expect(testingSource.contains("public enum MultiLibTesting"))
                // Stub no longer emits XCTest as an import statement —
                // adopters add `import XCTest` themselves if they want
                // interop. (The docstring may still mention XCTest as a hint,
                // so check the actual `import …` lines, not the substring.)
                let testingImports = testingSource.split(separator: "\n").filter { $0.hasPrefix("import ") }
                #expect(!testingImports.contains("import XCTest"))
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
        func `Package with MainActor lib + executable uses umbrella scheme in Makefile`() throws {
            // Mixed-kind packages (MainActor library + executable sibling)
            // need the `<Name>-Package` umbrella scheme so one xcodebuild
            // covers libs + tools. Without this, `make build` only builds
            // the lib and the executable goes stale.
            try withTempDir(prefix: "monolith-test-umbrella") { tempDir in
                let config = PackageConfig(
                    name: "MixedLib",
                    platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
                    targets: [
                        TargetDefinition(name: "MixedLib", dependencies: []),
                        TargetDefinition(name: "mixed-tool", dependencies: ["MixedLib"], isExecutable: true),
                    ],
                    features: [.defaultIsolation, .devTooling],
                    mainActorTargets: ["MixedLib"],
                    author: "Test",
                    licenseType: .mit
                )
                try config.validate()
                try PackageProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/MixedLib"
                let makefile = try String(contentsOfFile: "\(basePath)/Makefile", encoding: .utf8)
                #expect(makefile.contains("SCHEME = MixedLib-Package"))
                // Sanity: no bare scheme assignment for the same package.
                #expect(!makefile.contains("SCHEME = MixedLib\n"))
            }
        }

        @Test
        func `Package with executable sibling target wires CLI scaffolding end-to-end`() throws {
            try withTempDir(prefix: "monolith-test-pkg-exec") { tempDir in
                let config = PackageConfig(
                    name: "MultiLib",
                    platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
                    targets: [
                        TargetDefinition(name: "MultiLib", dependencies: []),
                        TargetDefinition(name: "multi-tool", dependencies: ["MultiLib"], isExecutable: true),
                    ],
                    features: [.devTooling],
                    mainActorTargets: [],
                    author: "Test",
                    licenseType: .mit
                )
                try config.validate()
                try PackageProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/MultiLib"

                // Library source uses the target name as-is.
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Sources/MultiLib/MultiLib.swift"))
                // Executable source dir is UpperCamelCase even though the
                // binary stays kebab-case (swift-format / swift-protobuf convention).
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Sources/MultiTool/MultiTool.swift"))
                // Old kebab-case path should NOT exist.
                #expect(!FileManager.default.fileExists(atPath: "\(basePath)/Sources/multi-tool"))

                // Test fixture written for the lib but NOT the exec.
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Tests/MultiLibTests/MultiLibTests.swift"))
                #expect(!FileManager.default.fileExists(atPath: "\(basePath)/Tests/multi-toolTests"))

                // Executable source carries the ArgumentParser stub with a proper
                // UpperCamelCase @main type but a kebab-case commandName so
                // `swift run multi-tool` works as users expect.
                let execSource = try String(contentsOfFile: "\(basePath)/Sources/MultiTool/MultiTool.swift", encoding: .utf8)
                #expect(execSource.contains("import ArgumentParser"))
                #expect(execSource.contains("@main"))
                #expect(execSource.contains("struct MultiTool: ParsableCommand"))
                #expect(execSource.contains("commandName: \"multi-tool\""))
                // Executable deps on internal libs surface as `import <Lib>`
                // lines in the stub, so the dep wired up in Package.swift isn't
                // dead weight to adopters reading the source.
                #expect(execSource.contains("import MultiLib"))

                // Package.swift target name stays kebab-case, but path: points
                // at the CamelCase directory.
                let pkg = try String(contentsOfFile: "\(basePath)/Package.swift", encoding: .utf8)
                #expect(pkg.contains(".library(name: \"MultiLib\""))
                #expect(pkg.contains(".executable(name: \"multi-tool\""))
                #expect(pkg.contains(".executableTarget("))
                #expect(pkg.contains("name: \"multi-tool\""))
                #expect(pkg.contains("path: \"Sources/MultiTool\""))
                #expect(pkg.contains("apple/swift-argument-parser.git"))
                #expect(pkg.components(separatedBy: ".testTarget(").count - 1 == 1)
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
