import Testing
@testable import MonolithLib

struct AddableFeatureTests {
    @Test
    func `all addable features have display names`() {
        for feature in AddableFeature.allCases {
            #expect(!feature.displayName.isEmpty)
        }
    }

    @Test
    func `addable feature count is 10`() {
        #expect(AddableFeature.allCases.count == 10)
    }

    @Test
    func `tier 1 features apply to all project types`() {
        let tier1: [AddableFeature] = [.devTooling, .gitHooks, .claudeMD, .licenseChangelog]
        for feature in tier1 {
            #expect(!feature.requiresAppProject)
            #expect(!feature.needsProjectSystemEdit)
        }
    }

    @Test
    func `tier 1 app extensions are app-only but write-only`() {
        let appOnlyAdditive: [AddableFeature] = [.privacyManifest, .appIconValidation]
        for feature in appOnlyAdditive {
            #expect(feature.requiresAppProject)
            #expect(!feature.needsProjectSystemEdit)
        }
    }

    @Test
    func `tier 2 features need project system edits and are app-only`() {
        let tier2: [AddableFeature] = [.localization, .macCatalyst, .lottie, .widget]
        for feature in tier2 {
            #expect(feature.requiresAppProject)
            #expect(feature.needsProjectSystemEdit)
        }
    }

    @Test
    func `allNames lists every addable feature`() {
        let names = AddableFeature.allNames.components(separatedBy: ", ")
        #expect(names == AddableFeature.allCases.map(\.rawValue))
    }

    @Test
    func `raw values match expected strings`() {
        #expect(AddableFeature.devTooling.rawValue == "devTooling")
        #expect(AddableFeature.gitHooks.rawValue == "gitHooks")
        #expect(AddableFeature.claudeMD.rawValue == "claudeMD")
        #expect(AddableFeature.licenseChangelog.rawValue == "licenseChangelog")
    }
}
