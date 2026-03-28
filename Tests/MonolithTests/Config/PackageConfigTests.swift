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
            author: "Test"
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

    @Test
    func `hasDevTooling and hasGitHooks`() {
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
