import Testing
@testable import MonolithLib

@Suite("ListCommand")
struct ListCommandTests {
    @Test("all app features have display names")
    func appFeaturesHaveDisplayNames() {
        for feature in AppFeature.allCases {
            #expect(!feature.displayName.isEmpty, "\(feature.rawValue) missing displayName")
        }
    }

    @Test("all package features have display names")
    func packageFeaturesHaveDisplayNames() {
        for feature in PackageFeature.allCases {
            #expect(!feature.displayName.isEmpty, "\(feature.rawValue) missing displayName")
        }
    }

    @Test("all CLI features have display names")
    func cliFeaturesHaveDisplayNames() {
        for feature in CLIFeature.allCases {
            #expect(!feature.displayName.isEmpty, "\(feature.rawValue) missing displayName")
        }
    }

    @Test("all project types are iterable")
    func projectTypesIterable() {
        #expect(ProjectType.allCases.count == 3)
        #expect(ProjectType.allCases.contains(.app))
        #expect(ProjectType.allCases.contains(.package))
        #expect(ProjectType.allCases.contains(.cli))
    }

    @Test("app prompt options excludes auto-derived features")
    func appPromptOptionsExcludesAutoDerived() {
        let options = AppFeature.promptOptions
        #expect(!options.contains(.tabs))
        #expect(!options.contains(.macCatalyst))
    }
}
