import Foundation
import Testing
@testable import MonolithLib

@Suite("PackageConfig")
struct PackageConfigTests {
    @Test("hasStrictConcurrency requires feature flag")
    func strictConcurrency() {
        let config = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [],
            features: [.strictConcurrency],
            mainActorTargets: [],
            author: "Test"
        )
        #expect(config.hasStrictConcurrency)
    }

    @Test("hasDefaultIsolation requires both feature and non-empty targets")
    func defaultIsolationRequiresBoth() {
        let withoutTargets = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [],
            features: [.defaultIsolation],
            mainActorTargets: [],
            author: "Test"
        )
        #expect(!withoutTargets.hasDefaultIsolation, "Should be false without mainActorTargets")

        let withTargets = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [],
            features: [.defaultIsolation],
            mainActorTargets: ["UI"],
            author: "Test"
        )
        #expect(withTargets.hasDefaultIsolation)

        let withoutFeature = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [],
            features: [],
            mainActorTargets: ["UI"],
            author: "Test"
        )
        #expect(!withoutFeature.hasDefaultIsolation, "Should be false without feature flag")
    }

    @Test("hasDevTooling and hasGitHooks")
    func devToolingAndGitHooks() {
        let config = PackageConfig(
            name: "Test",
            platforms: [],
            targets: [],
            features: [.devTooling, .gitHooks],
            mainActorTargets: [],
            author: "Test"
        )
        #expect(config.hasDevTooling)
        #expect(config.hasGitHooks)
    }
}
