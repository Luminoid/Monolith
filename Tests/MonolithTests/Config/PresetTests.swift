import Testing
@testable import MonolithLib

struct PresetTests {
    // MARK: - App Presets

    @Test
    func `minimal app preset returns empty features`() {
        let features = Preset.minimal.appFeatures()
        #expect(features.isEmpty)
    }

    @Test
    func `standard app preset returns devTooling, gitHooks, claudeMD, privacyManifest`() {
        let features = Preset.standard.appFeatures()
        #expect(features.contains(.devTooling))
        #expect(features.contains(.gitHooks))
        #expect(features.contains(.claudeMD))
        #expect(features.contains(.privacyManifest))
        #expect(features.count == 4)
    }

    @Test
    func `full app preset includes core features but not legacy ones`() {
        let features = Preset.full.appFeatures()
        // Modern features included
        #expect(features.contains(.coreData))
        #expect(features.contains(.cloudKitSharing))
        #expect(features.contains(.devTooling))
        #expect(features.contains(.privacyManifest))
        #expect(features.contains(.widget))
        #expect(features.contains(.notifications))
        // Legacy features deliberately excluded from "full" — users opt in explicitly.
        #expect(!features.contains(.rSwift))
        #expect(!features.contains(.fastlane))
    }

    /// Regression: `full` selected both persistence layers, and the app
    /// failed to compile with "invalid redeclaration of 'SampleItem'".
    @Test
    func `full app preset never selects both persistence layers`() {
        let features = Preset.full.appFeatures()
        #expect(!(features.contains(.swiftData) && features.contains(.coreData)))
        #expect(!features.contains(.swiftData))
    }

    @Test(arguments: Preset.allCases)
    func `every app preset passes AppConfig validation`(preset: Preset) throws {
        let config = AppConfig(
            name: "PresetApp",
            bundleID: "com.example.presetapp",
            deploymentTarget: Defaults.deploymentTarget,
            platforms: [.iPhone, .iPad],
            projectSystem: .xcodeProj,
            tabs: [],
            primaryColor: Defaults.primaryColor,
            features: preset.appFeatures(),
            author: "Test",
            licenseType: .proprietary
        )
        try config.validateForGeneration()
    }

    // MARK: - Package Presets

    @Test
    func `minimal package preset returns empty features`() {
        let features = Preset.minimal.packageFeatures()
        #expect(features.isEmpty)
    }

    @Test
    func `standard package preset returns devTooling, gitHooks, claudeMD`() {
        let features = Preset.standard.packageFeatures()
        #expect(features.contains(.devTooling))
        #expect(features.contains(.gitHooks))
        #expect(features.contains(.claudeMD))
        #expect(features.count == 3)
    }

    @Test
    func `full package preset returns all features except strictConcurrency`() {
        let features = Preset.full.packageFeatures()
        #expect(features.count == PackageFeature.allCases.count - 1)
        #expect(!features.contains(.strictConcurrency))
        // Every other feature should be present.
        for feature in PackageFeature.allCases where feature != .strictConcurrency {
            #expect(features.contains(feature))
        }
    }

    // MARK: - CLI Presets

    @Test
    func `minimal CLI preset returns empty features`() {
        let features = Preset.minimal.cliFeatures()
        #expect(features.isEmpty)
    }

    @Test
    func `full CLI preset returns all features except strictConcurrency`() {
        let features = Preset.full.cliFeatures()
        #expect(features.count == CLIFeature.allCases.count - 1)
        #expect(!features.contains(.strictConcurrency))
        for feature in CLIFeature.allCases where feature != .strictConcurrency {
            #expect(features.contains(feature))
        }
    }

    // MARK: - Display Names

    @Test
    func `all presets have display names`() {
        for preset in Preset.allCases {
            #expect(!preset.displayName.isEmpty)
        }
    }

    @Test
    func `preset count is 3`() {
        #expect(Preset.allCases.count == 3)
    }
}
