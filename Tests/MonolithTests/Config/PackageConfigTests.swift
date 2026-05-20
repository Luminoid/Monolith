import Foundation
import Testing
@testable import MonolithLib

struct PackageConfigTests {
    @Test
    func `hasStrictConcurrency requires feature flag`() {
        let config = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [],
            features: [.strictConcurrency],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        #expect(config.hasStrictConcurrency)
    }

    @Test
    func `hasDefaultIsolation requires both feature and non-empty targets`() {
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
        #expect(!withoutFeature.hasDefaultIsolation, "Should be false without feature flag")
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
}
