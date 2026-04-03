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
}
