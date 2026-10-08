import Foundation
import Testing
@testable import MonolithLib

/// Package-side input validation: the `--targets` / `--target-deps` /
/// `--platforms` parsers, `validateForGeneration()`, and the platform
/// declarations the manifest gets.
struct PackageValidationTests {
    private func makeConfig(
        name: String = "MultiLib",
        platforms: [PlatformVersion] = [PlatformVersion(platform: "iOS", version: "18.0")],
        targets: [TargetDefinition] = [TargetDefinition(name: "MultiLib", dependencies: [])],
        externalPackages: [ExternalPackage] = []
    ) -> PackageConfig {
        PackageConfig(
            name: name,
            platforms: platforms,
            targets: targets,
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit,
            externalPackages: externalPackages
        )
    }

    // MARK: - Duplicates

    /// Regression: `--targets A,A` trapped in `Dictionary(uniqueKeysWithValues:)`
    /// (exit 133), even with `--dry-run`.
    @Test
    func `duplicate target names are an error, not a crash`() {
        let config = makeConfig(targets: [
            TargetDefinition(name: "A", dependencies: []),
            TargetDefinition(name: "A", dependencies: []),
        ])
        let error = #expect(throws: PackageConfigError.self) { try config.validate() }
        if case let .duplicateTargetNames(names) = error {
            #expect(names == ["A"])
        } else {
            Issue.record("Expected .duplicateTargetNames, got \(String(describing: error))")
        }
    }

    @Test
    func `target names that differ only in case are duplicates`() {
        let config = makeConfig(targets: [
            TargetDefinition(name: "Core", dependencies: []),
            TargetDefinition(name: "core", dependencies: []),
        ])
        #expect(throws: PackageConfigError.self) { try config.validate() }
    }

    @Test
    func `duplicate external package names are an error`() {
        let ext = ExternalPackage(name: "ExtPkg", url: "../ExtPkg", requirement: "", packageName: nil)
        let config = makeConfig(
            targets: [TargetDefinition(name: "MultiLib", dependencies: ["ExtPkg"])],
            externalPackages: [ext, ext]
        )
        let error = #expect(throws: PackageConfigError.self) { try config.validate() }
        if case let .duplicateExternalPackageNames(names) = error {
            #expect(names == ["ExtPkg"])
        } else {
            Issue.record("Expected .duplicateExternalPackageNames, got \(String(describing: error))")
        }
    }

    @Test
    func `LookinServer is a recognized registry product`() {
        // Was missing from the hand-written built-in list.
        let config = makeConfig(targets: [TargetDefinition(name: "MultiLib", dependencies: ["lookinserver"])])
        let error = #expect(throws: PackageConfigError.self) { try config.validate() }
        if case let .misspelledExternalProduct(_, _, suggestions) = error {
            #expect(suggestions == ["LookinServer"])
        } else {
            Issue.record("Expected .misspelledExternalProduct, got \(String(describing: error))")
        }
    }

    // MARK: - validateForGeneration

    /// Regression: a loaded config skipped the name check, so these names
    /// wrote outside the output directory or into it directly.
    @Test
    func `validateForGeneration rejects names that escape or empty the output path`() {
        for name in ["../escaped tool", "", "a/b", "Café"] {
            #expect(throws: ConfigValidationError.self, "\(name)") {
                try makeConfig(name: name).validateForGeneration()
            }
        }
    }

    @Test
    func `validateForGeneration accepts a kebab-cased package name`() throws {
        try makeConfig(name: "multi-lib", targets: [TargetDefinition(name: "MultiLib", dependencies: [])]).validateForGeneration()
    }

    @Test
    func `validateForGeneration checks platforms`() {
        let unknown = makeConfig(platforms: [PlatformVersion(platform: "Android", version: "1.0")])
        #expect(throws: ConfigValidationError.self) { try unknown.validateForGeneration() }

        let badVersion = makeConfig(platforms: [PlatformVersion(platform: "iOS", version: "18")])
        #expect(throws: ConfigValidationError.self) { try badVersion.validateForGeneration() }

        let twice = makeConfig(platforms: [PlatformVersion(platform: "iOS", version: "18.0"), PlatformVersion(platform: "ios", version: "26.0")])
        #expect(throws: ConfigValidationError.self) { try twice.validateForGeneration() }
    }

    @Test
    func `validateForGeneration requires a target and well-formed externals`() {
        #expect(throws: ConfigValidationError.self) { try makeConfig(targets: []).validateForGeneration() }

        let noRequirement = ExternalPackage(name: "ExtPkg", url: "https://example.com/ExtPkg.git", requirement: "", packageName: nil)
        let config = makeConfig(targets: [TargetDefinition(name: "MultiLib", dependencies: ["ExtPkg"])], externalPackages: [noRequirement])
        #expect(throws: ConfigValidationError.self) { try config.validateForGeneration() }
    }

    @Test
    func `validateForGeneration runs the structural checks too`() {
        let config = makeConfig(targets: [
            TargetDefinition(name: "A", dependencies: ["B"]),
            TargetDefinition(name: "B", dependencies: ["A"]),
        ])
        #expect(throws: PackageConfigError.self) { try config.validateForGeneration() }
    }

    // MARK: - TargetDefinition.parseList

    @Test
    func `parseList reads executables and per-target deps`() throws {
        let targets = try TargetDefinition.parseList(targets: "MultiLib, MultiLibUI, multi-tool:exec", deps: "MultiLibUI:MultiLib,SnapKit; multi-tool:MultiLib")
        #expect(targets.map(\.name) == ["MultiLib", "MultiLibUI", "multi-tool"])
        #expect(targets.map(\.isExecutable) == [false, false, true])
        #expect(targets[1].dependencies == ["MultiLib", "SnapKit"])
        #expect(targets[2].dependencies == ["MultiLib"])
    }

    @Test
    func `parseList merges a target listed twice in deps`() throws {
        let targets = try TargetDefinition.parseList(targets: "A,B,C", deps: "C:A;C:B,A")
        #expect(targets[2].dependencies == ["A", "B"])
    }

    /// Regression: entries without `:` or naming an unknown target were dropped.
    @Test
    func `parseList rejects a deps entry without a colon or for an unknown target`() {
        #expect(throws: ConfigValidationError.self) {
            try TargetDefinition.parseList(targets: "A,B", deps: "B")
        }
        let error = #expect(throws: ConfigValidationError.self) {
            try TargetDefinition.parseList(targets: "MultiLibCore,MultiLibUI", deps: "MultiLibIU:MultiLibCore")
        }
        #expect(error?.description.contains("Did you mean 'MultiLibUI'?") == true)
    }

    // MARK: - PlatformVersion.parseList

    @Test
    func `platform parseList canonicalizes names`() throws {
        let platforms = try PlatformVersion.parseList("ios 18.0, MACOS 15.0,visionos 2.0")
        #expect(platforms.map(\.platform) == ["iOS", "macOS", "visionOS"])
        #expect(platforms.map(\.version) == ["18.0", "15.0", "2.0"])
    }

    @Test
    func `platform parseList rejects unknown platforms, bad versions, and repeats`() {
        let unknown = #expect(throws: ConfigValidationError.self) { try PlatformVersion.parseList("Android 1.0") }
        #expect(unknown?.description.contains("Android") == true)
        #expect(throws: ConfigValidationError.self) { try PlatformVersion.parseList("iOS") }
        #expect(throws: ConfigValidationError.self) { try PlatformVersion.parseList("iOS 18") }
        #expect(throws: ConfigValidationError.self) { try PlatformVersion.parseList("iOS 18.0,ios 26.0") }
    }

    // MARK: - spmDeclaration

    /// Regression: only the major was kept, so 18.4 became `.v18` (a lower
    /// floor) and macOS 10.15 became `.v10`, which doesn't exist.
    @Test
    func `spmDeclaration uses a constant only when PackageDescription has one`() {
        let cases: [(String, String, String)] = [
            ("iOS", "18.0", ".iOS(.v18)"),
            ("iOS", "18.4", ".iOS(\"18.4\")"),
            ("iOS", "26.0", ".iOS(.v26)"),
            ("iOS", "27.0", ".iOS(\"27.0\")"),
            ("iOS", "19.0", ".iOS(\"19.0\")"),
            ("macOS", "10.15", ".macOS(.v10_15)"),
            ("macOS", "10.12", ".macOS(\"10.12\")"),
            ("macOS", "15.0", ".macOS(.v15)"),
            ("macCatalyst", "18.0", ".macCatalyst(.v18)"),
            ("watchOS", "11.0", ".watchOS(.v11)"),
            ("tvOS", "18.2", ".tvOS(\"18.2\")"),
            ("visionOS", "2.0", ".visionOS(.v2)"),
            ("ios", "18.0", ".iOS(.v18)"),
        ]
        for (platform, version, expected) in cases {
            #expect(PlatformVersion(platform: platform, version: version).spmDeclaration == expected)
        }
    }

    /// Writes generated manifests to disk and has SwiftPM evaluate them, so a
    /// constant that doesn't exist (or a deprecated one) fails here rather
    /// than in an adopter's first build.
    @Test
    func `generated platform declarations pass swift package dump-package`() throws {
        let declared = [
            PlatformVersion(platform: "iOS", version: "18.4"),
            PlatformVersion(platform: "macOS", version: "10.15"),
            PlatformVersion(platform: "macCatalyst", version: "26.0"),
            PlatformVersion(platform: "tvOS", version: "18.0"),
            PlatformVersion(platform: "watchOS", version: "9.0"),
            PlatformVersion(platform: "visionOS", version: "1.0"),
        ]
        try expectDumpPackageSucceeds(PackageSwiftGenerator.generate(config: makeConfig(platforms: declared)))
        try expectDumpPackageSucceeds(PackageSwiftGenerator.generate(config: makeConfig(platforms: [
            PlatformVersion(platform: "macOS", version: "10.12"),
            PlatformVersion(platform: "iOS", version: "27.0"),
        ])))
    }

    /// The scenario that failed end to end: SnapKit wired into an iOS-only package.
    @Test
    func `a SnapKit package declaring only iOS keeps a valid manifest and the logging core`() throws {
        let outputDir = NSTemporaryDirectory() + "monolith-snapkit-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: outputDir) }
        let config = makeConfig(name: "SKPkg", targets: [TargetDefinition(name: "SKPkg", dependencies: ["SnapKit"])])
        try config.validateForGeneration()
        try PackageProjectGenerator.generate(config: config, outputDir: outputDir)

        let manifest = try String(contentsOfFile: "\(outputDir)/SKPkg/Package.swift", encoding: .utf8)
        #expect(manifest.contains(".iOS(.v18)"))
        #expect(manifest.contains(".macOS(.v13)"))
        #expect(!manifest.contains(".tvOS("))
        #expect(!manifest.contains(".watchOS("))
        #expect(!manifest.contains(".visionOS("))
        #expect(FileManager.default.fileExists(atPath: "\(outputDir)/SKPkg/Sources/SKPkg/Logging/SKPkgLog.swift"))
        try expectDumpPackageSucceeds(manifest)
    }

    private func expectDumpPackageSucceeds(_ manifest: String) throws {
        let dir = NSTemporaryDirectory() + "monolith-dump-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try manifest.write(toFile: "\(dir)/Package.swift", atomically: true, encoding: .utf8)
        let output = try ShellRunner.run(
            executable: "/usr/bin/xcrun",
            arguments: ["swift", "package", "dump-package", "--package-path", dir],
            // Integration tests change the process cwd and delete it, so
            // never inherit it.
            cwd: dir,
            captureStdout: true,
            captureStderr: true,
            streamOutput: false
        )
        #expect(output.exitCode == 0, "dump-package failed:\n\(output.stderr)\n\(manifest)")
        #expect(!output.stderr.contains("warning:"), "dump-package warned:\n\(output.stderr)")
    }
}
