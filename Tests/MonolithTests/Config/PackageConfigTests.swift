import Foundation
import Testing
@testable import MonolithLib

struct PackageConfigTests {
    @Test
    func `hasDefaultIsolation needs MainActor targets, which imply the feature`() throws {
        let withoutTargets = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [],
            features: [.defaultIsolation],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        #expect(!withoutTargets.hasDefaultIsolation, "Should be false without mainActorTargets")

        let withTargets = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [],
            features: [.defaultIsolation],
            mainActorTargets: ["UI"],
            author: "Test",
            licenseType: .mit
        )
        #expect(withTargets.hasDefaultIsolation)

        let withoutFeature = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [],
            features: [],
            mainActorTargets: ["UI"],
            author: "Test",
            licenseType: .mit
        )
        // Package.swift isolates the targets either way, so the Makefile and
        // docs must follow them, not the flag.
        #expect(withoutFeature.hasDefaultIsolation)
        #expect(withoutFeature.features == [.defaultIsolation])
        #expect(withoutFeature.requiresXcodebuild)

        let decoded = try JSONDecoder().decode(PackageConfig.self, from: Data("""
        {"name": "Test", "platforms": [], "targets": [], "features": [], "mainActorTargets": ["UI"], "author": "Test"}
        """.utf8))
        #expect(decoded.features == [.defaultIsolation])
    }

    @Test
    func `hasDevTooling and hasGitHooks`() {
        let config = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [],
            features: [.devTooling, .gitHooks],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        #expect(config.hasDevTooling)
        #expect(config.hasGitHooks)
    }

    // MARK: - validate()

    @Test
    func `validate passes for a well-formed multi-target config`() throws {
        let config = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [
                TargetDefinition(name: "Core", dependencies: []),
                TargetDefinition(name: "UI", dependencies: ["Core", "SnapKit"]),
            ],
            features: [],
            mainActorTargets: ["UI"],
            author: "Test",
            licenseType: .mit
        )
        try config.validate()
    }

    @Test
    func `validate throws on unknown main-actor target`() {
        let config = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [TargetDefinition(name: "Core", dependencies: [])],
            features: [.defaultIsolation],
            mainActorTargets: ["UI"],
            author: "Test",
            licenseType: .mit
        )
        #expect(throws: PackageConfigError.self) {
            try config.validate()
        }
    }

    @Test
    func `validate throws on case-insensitive target dependency typo`() {
        let config = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [
                TargetDefinition(name: "Core", dependencies: []),
                TargetDefinition(name: "UI", dependencies: ["core"]),
            ],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        #expect(throws: PackageConfigError.self) {
            try config.validate()
        }
    }

    @Test
    func `validate allows unrecognized external dependency name`() throws {
        let config = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [TargetDefinition(name: "Core", dependencies: ["SomeUnknownLibrary"])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        try config.validate()
    }

    @Test
    func `validate detects two-target dependency cycle`() {
        let config = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [
                TargetDefinition(name: "A", dependencies: ["B"]),
                TargetDefinition(name: "B", dependencies: ["A"]),
            ],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        #expect(throws: PackageConfigError.self) {
            try config.validate()
        }
    }

    @Test
    func `validate detects three-target dependency cycle`() {
        let config = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [
                TargetDefinition(name: "A", dependencies: ["B"]),
                TargetDefinition(name: "B", dependencies: ["C"]),
                TargetDefinition(name: "C", dependencies: ["A"]),
            ],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        #expect(throws: PackageConfigError.self) {
            try config.validate()
        }
    }

    @Test
    func `validate allows diamond dependency (no cycle)`() throws {
        let config = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [
                TargetDefinition(name: "Core", dependencies: []),
                TargetDefinition(name: "A", dependencies: ["Core"]),
                TargetDefinition(name: "B", dependencies: ["Core"]),
                TargetDefinition(name: "Top", dependencies: ["A", "B"]),
            ],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        try config.validate()
    }

    // MARK: - New v0.2 fields

    @Test
    func `validate throws on unknown test-helper target`() {
        let config = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [TargetDefinition(name: "Core", dependencies: [])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit,
            testHelperTargets: ["TestingHelpers"]
        )
        #expect(throws: PackageConfigError.self) {
            try config.validate()
        }
    }

    @Test
    func `validate rejects library target name with colon`() {
        // Regression: `--targets "Foo:lib:Bar"` (mistakenly using the wrong
        // dep-syntax) used to silently create `Sources/Foo:lib:Bar/...`.
        // Validate the name so the user gets a clear error.
        let config = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [TargetDefinition(name: "Foo:lib:Bar", dependencies: [])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        #expect(throws: PackageConfigError.self) {
            try config.validate()
        }
    }

    @Test
    func `validate rejects library target name with kebab-case`() {
        // Libraries must be Swift identifiers (`public enum <Name> {}` won't
        // compile with a hyphen). Kebab-case is allowed only for executables.
        let config = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [TargetDefinition(name: "my-lib", dependencies: [])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        #expect(throws: PackageConfigError.self) {
            try config.validate()
        }
    }

    @Test
    func `validate accepts executable target name with kebab-case`() throws {
        // Executables convention: kebab-cased binary, UpperCamelCased struct
        // (matches `swift-format` / `swift-protobuf` precedent).
        let config = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [TargetDefinition(name: "multi-tool", dependencies: [], isExecutable: true)],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        try config.validate()
    }

    @Test
    func `validate rejects target name starting with digit`() {
        // Swift identifiers cannot start with a digit.
        let config = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [TargetDefinition(name: "1Foo", dependencies: [])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        #expect(throws: PackageConfigError.self) {
            try config.validate()
        }
    }

    @Test
    func `validate rejects empty target name`() {
        let config = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [TargetDefinition(name: "", dependencies: [])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        #expect(throws: PackageConfigError.self) {
            try config.validate()
        }
    }

    @Test
    func `validate accepts target name with underscore and digits`() throws {
        let config = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [TargetDefinition(name: "_Foo_v2", dependencies: [])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        try config.validate()
    }

    @Test
    func `invalid target name error explains the common cause`() {
        // The error message should call out the most likely cause:
        // passing dep-syntax to --targets instead of --target-deps.
        let err = PackageConfigError.invalidTargetName("Foo:lib:Bar", isExecutable: false)
        let message = String(describing: err)
        #expect(message.contains("Foo:lib:Bar"))
        #expect(message.contains("--target-deps"))
    }

    @Test
    func `validate throws when test-helper target is also MainActor-isolated`() {
        // A MainActor-isolated test helper can't be called from nonisolated
        // test contexts (Swift Testing's `@Test` default), which forces every
        // adopter test that uses the helper into `@MainActor`. Catch at config
        // time since the generated source is otherwise valid Swift.
        let config = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [
                TargetDefinition(name: "Core", dependencies: []),
                TargetDefinition(name: "CoreTesting", dependencies: ["Core"]),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["Core", "CoreTesting"],
            author: "Test",
            licenseType: .mit,
            testHelperTargets: ["CoreTesting"]
        )
        #expect(throws: PackageConfigError.self) {
            try config.validate()
        }
    }

    @Test
    func `validate accepts test-helper target that is not MainActor-isolated`() throws {
        // Negative: the standard multi-target framework layout — UI lib is MainActor,
        // test helper is nonisolated — must pass.
        let config = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [
                TargetDefinition(name: "Core", dependencies: []),
                TargetDefinition(name: "CoreTesting", dependencies: ["Core"]),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["Core"],
            author: "Test",
            licenseType: .mit,
            testHelperTargets: ["CoreTesting"]
        )
        try config.validate()
    }

    @Test
    func `validate throws on unknown target-resources key`() {
        let config = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [TargetDefinition(name: "Core", dependencies: [])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit,
            targetResources: ["Missing": ["Resources"]]
        )
        #expect(throws: PackageConfigError.self) {
            try config.validate()
        }
    }

    @Test
    func `validate throws when external package name collides with target`() {
        let config = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [TargetDefinition(name: "ExtLib", dependencies: [])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit,
            externalPackages: [
                ExternalPackage(name: "ExtLib", url: "https://example.com/ExtLib", requirement: "from: \"0.1.0\"", packageName: nil),
            ]
        )
        #expect(throws: PackageConfigError.self) {
            try config.validate()
        }
    }

    @Test
    func `validate accepts user-declared external package as a target dep`() throws {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLib", dependencies: ["ExtLib"])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit,
            externalPackages: [
                ExternalPackage(name: "ExtLib", url: "https://example.com/ExtLib", requirement: "from: \"0.1.0\"", packageName: nil),
            ]
        )
        try config.validate()
    }

    @Test
    func `validate accepts packageDeps that reference known externals`() throws {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "Core", dependencies: [])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit,
            packageDeps: ["LumiKitUI"]
        )
        try config.validate()
    }

    @Test
    func `validate flags a typoed packageDeps entry`() {
        // Case-insensitive match against a target name → typo.
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "Core", dependencies: [])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit,
            packageDeps: ["core"]
        )
        #expect(throws: PackageConfigError.self) {
            try config.validate()
        }
    }

    @Test
    func `validate throws when --external-packages declares an unconsumed entry`() {
        // The user declared LumiKit via --external-packages but never put
        // 'LumiKit' (or a product name) in any --target-deps / --package-deps.
        // Without this check, Package.swift would silently omit the
        // .package(url:...) line and the user would never know.
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MultiLib", dependencies: []),
                TargetDefinition(name: "MultiLibUI", dependencies: ["MultiLib"]),
            ],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit,
            externalPackages: [
                ExternalPackage(name: "LumiKit", url: "https://github.com/Luminoid/LumiKit.git", requirement: "from: \"0.8.0\"", packageName: nil),
            ]
        )
        let error = #expect(throws: PackageConfigError.self) {
            try config.validate()
        }
        if case let .externalPackageNotConsumed(names) = error {
            #expect(names == ["LumiKit"])
        } else {
            Issue.record("Expected .externalPackageNotConsumed, got \(String(describing: error))")
        }
    }

    @Test
    func `validate accepts --external-packages entry consumed via packageDeps`() throws {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLib", dependencies: [])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit,
            packageDeps: ["ExtLib"],
            externalPackages: [
                ExternalPackage(name: "ExtLib", url: "https://example.com/ExtLib", requirement: "from: \"0.1.0\"", packageName: nil),
            ]
        )
        try config.validate()
    }

    @Test
    func `validate suggests product names when target depends on bare 'LumiKit'`() {
        // LumiKit's SPM package is named LumiKit but ships products
        // LumiKitUI / LumiKitCore / LumiKitPhoto / LumiKitDebug / LumiKitLottie. Depending on
        // "LumiKit" looks like a registry product but is not — SPM would fail
        // later with "Missing package product 'LumiKit'". Catch at config time.
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLib", dependencies: ["LumiKit"])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let error = #expect(throws: PackageConfigError.self) {
            try config.validate()
        }
        if case let .misspelledExternalProduct(_, dep, suggestions) = error {
            #expect(dep == "LumiKit")
            #expect(suggestions.contains("LumiKitUI"))
            #expect(suggestions.contains("LumiKitCore"))
        } else {
            Issue.record("Expected .misspelledExternalProduct, got \(String(describing: error))")
        }
    }

    @Test
    func `validate flags case-insensitive misspelling of a known external`() {
        // "lumikitui" → LumiKitUI: case-insensitive match against a built-in
        // external product. SPM is case-sensitive, so the lowercase form
        // would fail later as an unresolvable product.
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLib", dependencies: ["lumikitui"])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let error = #expect(throws: PackageConfigError.self) {
            try config.validate()
        }
        if case let .misspelledExternalProduct(_, _, suggestions) = error {
            #expect(suggestions == ["LumiKitUI"])
        } else {
            Issue.record("Expected .misspelledExternalProduct, got \(String(describing: error))")
        }
    }

    // MARK: - mergingRequiredPlatforms

    @Test
    func `mergingRequiredPlatforms adds macOS 15 floor when LumiKitUI is wired`() {
        // Regression: a package wiring LumiKitUI but declaring only iOS fails
        // `swift build` on macOS hosts because the implicit macOS floor is
        // 10.13 but LumiKitUI requires macOS 15. Merge adds the missing
        // platform so `swift build` from any host succeeds. Other platforms
        // the dependency supports (Mac Catalyst) are not added.
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
            targets: [TargetDefinition(name: "MultiLib", dependencies: ["LumiKitUI"])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let merged = config.mergingRequiredPlatforms()
        #expect(merged.platforms.map(\.platform) == ["iOS", "macOS"])
        #expect(merged.platforms.first { $0.platform == "macOS" }?.version == "15.0")
    }

    /// Regression: the SnapKit 5.x floors added tvOS, visionOS, and watchOS
    /// entries the user never declared, `.macOS(.v10)` broke the manifest,
    /// and the logging core was skipped over a macOS 10.13 nobody wrote.
    @Test
    func `mergingRequiredPlatforms adds only macOS for SnapKit, at the logging core floor`() {
        let config = PackageConfig(
            name: "SKPkg",
            platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
            targets: [TargetDefinition(name: "SKPkg", dependencies: ["SnapKit"])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let merged = config.mergingRequiredPlatforms()
        #expect(merged.platforms.map(\.spmDeclaration) == [".iOS(.v18)", ".macOS(.v13)"])
        #expect(LogCoreGenerator.placement(for: merged) != nil)
    }

    @Test
    func `mergingRequiredPlatforms raises a declared tvOS to SnapKit's floor`() {
        let config = PackageConfig(
            name: "SKPkg",
            platforms: [PlatformVersion(platform: "tvOS", version: "13.0"), PlatformVersion(platform: "macOS", version: "11.0")],
            targets: [TargetDefinition(name: "SKPkg", dependencies: ["SnapKit"])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let merged = config.mergingRequiredPlatforms()
        #expect(merged.platforms.map(\.spmDeclaration) == [".tvOS(.v14)", ".macOS(.v12)"])
    }

    @Test
    func `registry floors match the pinned SnapKit and Lottie manifests`() {
        let snapKit = KnownPackages.registry["SnapKit"]?.platformFloors.map(\.spmDeclaration)
        #expect(snapKit == [".iOS(.v14)", ".macOS(.v12)", ".tvOS(.v14)"])
        let lottie = KnownPackages.registry["Lottie"]?.platformFloors.map(\.spmDeclaration)
        #expect(lottie == [".iOS(.v13)", ".macOS(.v10_15)", ".tvOS(.v13)", ".visionOS(.v1)"])
    }

    @Test
    func `mergingRequiredPlatforms raises declared platform to required floor`() {
        // Declared macOS 12.0 + LumiKit needs macOS 15.0 → result is 15.0.
        let config = PackageConfig(
            name: "MyLib",
            platforms: [
                PlatformVersion(platform: "iOS", version: "18.0"),
                PlatformVersion(platform: "macOS", version: "12.0"),
            ],
            targets: [TargetDefinition(name: "MyLib", dependencies: ["LumiKitCore"])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let merged = config.mergingRequiredPlatforms()
        let macOS = merged.platforms.first { $0.platform == "macOS" }
        #expect(macOS?.version == "15.0")
    }

    @Test
    func `mergingRequiredPlatforms keeps declared version when above required floor`() {
        // Declared macOS 16 + LumiKit needs macOS 15 → keep declared (higher).
        let config = PackageConfig(
            name: "MyLib",
            platforms: [
                PlatformVersion(platform: "iOS", version: "18.0"),
                PlatformVersion(platform: "macOS", version: "16.0"),
            ],
            targets: [TargetDefinition(name: "MyLib", dependencies: ["LumiKitCore"])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let merged = config.mergingRequiredPlatforms()
        let macOS = merged.platforms.first { $0.platform == "macOS" }
        #expect(macOS?.version == "16.0")
    }

    @Test
    func `mergingRequiredPlatforms is a no-op when no known deps are wired`() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
            targets: [TargetDefinition(name: "MyLib", dependencies: ["SomeUnknownDep"])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let merged = config.mergingRequiredPlatforms()
        #expect(merged.platforms.count == 1)
        #expect(merged.platforms.first?.platform == "iOS")
    }

    @Test
    func `mergingRequiredPlatforms ignores internal target dependencies`() {
        // Internal target deps don't need a platform floor merge — only
        // external deps introduce platform requirements.
        let config = PackageConfig(
            name: "MyLib",
            platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
            targets: [
                TargetDefinition(name: "Core", dependencies: []),
                TargetDefinition(name: "UI", dependencies: ["Core"]),
            ],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let merged = config.mergingRequiredPlatforms()
        #expect(merged.platforms.count == 1)
    }

    @Test
    func `mergingRequiredPlatforms picks up packageDeps wiring`() {
        // Cross-cutting `--package-deps LumiKitUI` should trigger the merge
        // even if no individual target lists it directly.
        let config = PackageConfig(
            name: "MyLib",
            platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
            targets: [TargetDefinition(name: "MyLib", dependencies: [])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit,
            packageDeps: ["LumiKitUI"]
        )
        let merged = config.mergingRequiredPlatforms()
        let macOS = merged.platforms.first { $0.platform == "macOS" }
        #expect(macOS?.version == "15.0")
    }

    @Test
    func `mergingRequiredPlatforms is idempotent`() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
            targets: [TargetDefinition(name: "MyLib", dependencies: ["LumiKitUI"])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let once = config.mergingRequiredPlatforms()
        let twice = once.mergingRequiredPlatforms()
        #expect(once.platforms.count == twice.platforms.count)
        for (a, b) in zip(once.platforms, twice.platforms) {
            #expect(a.platform == b.platform)
            #expect(a.version == b.version)
        }
    }
}
