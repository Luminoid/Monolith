import Foundation
import Testing
@testable import MonolithLib

struct LogCoreGeneratorTests {
    private func makeConfig(
        name: String = "MultiLib",
        platforms: [PlatformVersion] = [PlatformVersion(platform: "iOS", version: "18.0")],
        targets: [TargetDefinition],
        testHelperTargets: Set<String> = []
    ) -> PackageConfig {
        PackageConfig(
            name: name,
            platforms: platforms,
            targets: targets,
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit,
            testHelperTargets: testHelperTargets
        )
    }

    // MARK: - Rendering

    @Test
    func `rendering leaves no tokens behind`() {
        let files = LogCoreGenerator.render(prefix: "ABC", subsystem: "com.example.abc", module: "AbcCore")
        for text in [files.source, files.tests, files.categories] {
            #expect(!text.contains("__"))
        }
    }

    @Test
    func `rendering substitutes prefix, subsystem, and module`() {
        let files = LogCoreGenerator.render(prefix: "ABC", subsystem: "com.example.abc", module: "AbcCore")

        #expect(files.source.contains("public nonisolated enum ABCLog {"))
        #expect(files.source.contains("public nonisolated enum ABCLogLevel"))
        #expect(files.source.contains("public nonisolated struct ABCLogEntry"))
        #expect(files.source.contains("public static let subsystem = \"com.example.abc\""))
        #expect(files.source.hasPrefix("//\n//  ABCLog.swift\n//  AbcCore\n"))

        #expect(files.tests.contains("@testable import AbcCore"))
        #expect(files.tests.contains("struct ABCLogTests"))
        // The test asserts its own file name, so the file must be written as `<Prefix>LogTests.swift`.
        #expect(files.tests.contains("\"ABCLogTests.swift\""))

        #expect(files.categories.contains("package extension ABCLog.Category {"))
        #expect(files.categories.contains("nonisolated static let general = ABCLog.Category(\"General\")"))
    }

    @Test
    func `rendered files end with exactly one newline`() {
        let files = LogCoreGenerator.render(prefix: "ABC", subsystem: "com.example.abc", module: "AbcCore")
        for text in [files.source, files.tests, files.categories] {
            #expect(text.hasSuffix("}\n"))
            #expect(!text.hasSuffix("\n\n"))
        }
    }

    /// Rendering is substitution only, so a copy can be checked by substituting back.
    @Test
    func `rendering is plain token substitution`() {
        let source = LogCoreGenerator.render(prefix: "ABC", subsystem: "com.example.abc", module: "AbcCore").source
        let restored = source
            .replacingOccurrences(of: "ABCLog", with: "__PREFIX__Log")
            .replacingOccurrences(of: "com.example.abc", with: "__SUBSYSTEM__")
            .replacingOccurrences(of: "AbcCore", with: "__MODULE__")
        #expect(restored == LogCoreGenerator.coreTemplate + "\n")
    }

    @Test
    func `categories file flags a placeholder subsystem`() {
        let placeholder = LogCoreGenerator.renderCategories(prefix: "ABC", subsystem: "com.example.abc", module: "Abc")
        #expect(placeholder.contains("a placeholder"))
        let real = LogCoreGenerator.renderCategories(prefix: "ABC", subsystem: "dev.acme.abc", module: "Abc")
        #expect(!real.contains("placeholder"))
    }

    // MARK: - Placement

    @Test
    func `placement prefers the target named after the package`() {
        let config = makeConfig(name: "MultiLib", targets: [
            TargetDefinition(name: "MultiLibCore", dependencies: []),
            TargetDefinition(name: "MultiLib", dependencies: []),
        ])
        let placement = LogCoreGenerator.placement(for: config)
        #expect(placement?.module == "MultiLib")
        #expect(placement?.prefix == "MultiLib")
        #expect(placement?.subsystem == "com.example.multilib")
        #expect(placement?.paths == [
            "Sources/MultiLib/Logging/MultiLibLog.swift",
            "Sources/MultiLib/Logging/MultiLibLog+Categories.swift",
            "Tests/MultiLibTests/MultiLibLogTests.swift",
        ])
    }

    /// The core belongs where every other target can reach it: a target with no in-package dependencies.
    @Test
    func `placement picks a target the others can depend on`() {
        let config = makeConfig(name: "MultiLib", targets: [
            TargetDefinition(name: "MultiLibUI", dependencies: ["MultiLibCore"]),
            TargetDefinition(name: "MultiLibCore", dependencies: []),
        ])
        #expect(LogCoreGenerator.placement(for: config)?.module == "MultiLibCore")
    }

    @Test
    func `executables and test helpers never hold the core`() {
        let config = makeConfig(
            name: "MultiLib",
            targets: [
                TargetDefinition(name: "MultiLibTesting", dependencies: []),
                TargetDefinition(name: "multi-tool", dependencies: [], isExecutable: true),
                TargetDefinition(name: "MultiLibCore", dependencies: []),
            ],
            testHelperTargets: ["MultiLibTesting"]
        )
        #expect(LogCoreGenerator.placement(for: config)?.module == "MultiLibCore")

        let toolsOnly = makeConfig(name: "tools", targets: [TargetDefinition(name: "tools", dependencies: [], isExecutable: true)])
        #expect(LogCoreGenerator.placement(for: toolsOnly) == nil)
    }

    @Test
    func `a kebab-cased package name becomes an UpperCamelCase prefix`() {
        let config = makeConfig(name: "multi-lib", targets: [TargetDefinition(name: "MultiLibCore", dependencies: [])])
        #expect(LogCoreGenerator.placement(for: config)?.prefix == "MultiLib")
        #expect(LogCoreGenerator.placement(for: config)?.subsystem == "com.example.multi-lib")
    }

    /// A target named like one of the core's types would clash with its own placeholder enum.
    @Test
    func `a target named like a core type gets a prefix from its own name`() {
        let config = makeConfig(name: "Multi", targets: [TargetDefinition(name: "MultiLog", dependencies: [])])
        #expect(LogCoreGenerator.placement(for: config)?.prefix == "MultiLog")
    }

    @Test
    func `a declared platform below the floor skips the core`() {
        let config = makeConfig(
            platforms: [PlatformVersion(platform: "iOS", version: "15.0")],
            targets: [TargetDefinition(name: "MultiLib", dependencies: [])]
        )
        #expect(LogCoreGenerator.placement(for: config) == nil)
        #expect(LogCoreGenerator.platformsBelowFloor(config.platforms).map(\.platform) == ["iOS"])

        let atFloor = makeConfig(
            platforms: [PlatformVersion(platform: "iOS", version: "16.0"), PlatformVersion(platform: "macOS", version: "13.0")],
            targets: [TargetDefinition(name: "MultiLib", dependencies: [])]
        )
        #expect(LogCoreGenerator.placement(for: atFloor) != nil)
    }

    @Test
    func `the host floor adds macOS only when it is missing`() {
        let iOSOnly = LogCoreGenerator.addingHostFloor(to: [PlatformVersion(platform: "iOS", version: "18.0")])
        #expect(iOSOnly.map(\.spmDeclaration) == [".iOS(.v18)", ".macOS(.v13)"])

        let declared = [PlatformVersion(platform: "iOS", version: "18.0"), PlatformVersion(platform: "macOS", version: "15.0")]
        #expect(LogCoreGenerator.addingHostFloor(to: declared).map(\.spmDeclaration) == [".iOS(.v18)", ".macOS(.v15)"])
    }
}

// MARK: - Generated packages

extension MonolithIntegrationSuite {
    struct LogCoreIntegrationTests {
        @Test
        func `generated packages carry the log core and its tests`() throws {
            try withTempDir(prefix: "monolith-test-logcore") { tempDir in
                let config = PackageConfig(
                    name: "MultiLib",
                    platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
                    targets: [
                        TargetDefinition(name: "MultiLibCore", dependencies: []),
                        TargetDefinition(name: "MultiLibUI", dependencies: ["MultiLibCore"]),
                    ],
                    features: [],
                    mainActorTargets: [],
                    author: "Test",
                    licenseType: .mit
                )
                try PackageProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/MultiLib"
                let source = try String(contentsOfFile: "\(basePath)/Sources/MultiLibCore/Logging/MultiLibLog.swift", encoding: .utf8)
                #expect(source == LogCoreGenerator.render(prefix: "MultiLib", subsystem: "com.example.multilib", module: "MultiLibCore").source)
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Sources/MultiLibCore/Logging/MultiLibLog+Categories.swift"))
                #expect(FileManager.default.fileExists(atPath: "\(basePath)/Tests/MultiLibCoreTests/MultiLibLogTests.swift"))
                #expect(!FileManager.default.fileExists(atPath: "\(basePath)/Sources/MultiLibUI/Logging"))

                // `swift build` on a Mac host builds for macOS, so the core's floor is declared.
                let pkg = try String(contentsOfFile: "\(basePath)/Package.swift", encoding: .utf8)
                #expect(pkg.contains(".iOS(.v18)"))
                #expect(pkg.contains(".macOS(.v13)"))
            }
        }

        @Test
        func `a package below the floor is generated without the core`() throws {
            try withTempDir(prefix: "monolith-test-logcore-old") { tempDir in
                let config = PackageConfig(
                    name: "OldLib",
                    platforms: [PlatformVersion(platform: "iOS", version: "15.0")],
                    targets: [TargetDefinition(name: "OldLib", dependencies: [])],
                    features: [],
                    mainActorTargets: [],
                    author: "Test",
                    licenseType: .mit
                )
                try PackageProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/OldLib"
                #expect(!FileManager.default.fileExists(atPath: "\(basePath)/Sources/OldLib/Logging"))
                let pkg = try String(contentsOfFile: "\(basePath)/Package.swift", encoding: .utf8)
                #expect(!pkg.contains(".macOS("))
            }
        }

        /// The dry run lists the same files the real run writes.
        @Test
        func `dry run lists exactly the files a real run writes`() throws {
            try withTempDir(prefix: "monolith-test-logcore-dry") { tempDir in
                let config = PackageConfig(
                    name: "MultiLib",
                    platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
                    targets: [TargetDefinition(name: "MultiLib", dependencies: [])],
                    features: [.devTooling],
                    mainActorTargets: [],
                    author: "Test",
                    licenseType: .mit
                )
                let planned = DryRunPlanner.plannedPackageFiles(config: config)
                #expect(planned.contains("Sources/MultiLib/Logging/MultiLibLog.swift"))
                #expect(planned.contains("Tests/MultiLibTests/MultiLibLogTests.swift"))

                try PackageProjectGenerator.generate(config: config)
                let basePath = "\(tempDir)/MultiLib"
                let enumerator = FileManager.default.enumerator(atPath: basePath)
                var written: Set<String> = []
                while let path = enumerator?.nextObject() as? String {
                    var isDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: "\(basePath)/\(path)", isDirectory: &isDirectory), !isDirectory.boolValue {
                        written.insert(path)
                    }
                }
                #expect(written == Set(planned))
            }
        }
    }
}
