import Testing
@testable import MonolithLib

@Suite("Preset")
struct PresetTests {
    // MARK: - App Presets

    @Test("minimal app preset returns empty features")
    func minimalAppFeatures() {
        let features = Preset.minimal.appFeatures(projectSystem: .spm)
        #expect(features.isEmpty)
    }

    @Test("standard app preset returns devTooling, gitHooks, claudeMD")
    func standardAppFeatures() {
        let features = Preset.standard.appFeatures(projectSystem: .spm)
        #expect(features.contains(.devTooling))
        #expect(features.contains(.gitHooks))
        #expect(features.contains(.claudeMD))
        #expect(features.count == 3)
    }

    @Test("full app preset for SPM excludes rSwift and fastlane")
    func fullAppSPMExcludesXcodeGenOnly() {
        let features = Preset.full.appFeatures(projectSystem: .spm)
        #expect(!features.contains(.rSwift))
        #expect(!features.contains(.fastlane))
        #expect(features.contains(.swiftData))
        #expect(features.contains(.devTooling))
    }

    @Test("full app preset for XcodeGen includes rSwift and fastlane")
    func fullAppXcodeGenIncludesAll() {
        let features = Preset.full.appFeatures(projectSystem: .xcodeGen)
        #expect(features.contains(.rSwift))
        #expect(features.contains(.fastlane))
    }

    // MARK: - Package Presets

    @Test("minimal package preset returns empty features")
    func minimalPackageFeatures() {
        let features = Preset.minimal.packageFeatures()
        #expect(features.isEmpty)
    }

    @Test("standard package preset returns devTooling, gitHooks, claudeMD")
    func standardPackageFeatures() {
        let features = Preset.standard.packageFeatures()
        #expect(features.contains(.devTooling))
        #expect(features.contains(.gitHooks))
        #expect(features.contains(.claudeMD))
        #expect(features.count == 3)
    }

    @Test("full package preset returns all features")
    func fullPackageFeatures() {
        let features = Preset.full.packageFeatures()
        #expect(features.count == PackageFeature.allCases.count)
    }

    // MARK: - CLI Presets

    @Test("minimal CLI preset returns empty features")
    func minimalCLIFeatures() {
        let features = Preset.minimal.cliFeatures()
        #expect(features.isEmpty)
    }

    @Test("full CLI preset returns all features")
    func fullCLIFeatures() {
        let features = Preset.full.cliFeatures()
        #expect(features.count == CLIFeature.allCases.count)
    }

    // MARK: - Display Names

    @Test("all presets have display names")
    func displayNames() {
        for preset in Preset.allCases {
            #expect(!preset.displayName.isEmpty)
        }
    }

    @Test("preset count is 3")
    func presetCount() {
        #expect(Preset.allCases.count == 3)
    }
}
