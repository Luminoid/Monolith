import Testing
@testable import MonolithLib

struct ListCommandTests {
    @Test
    func `all app features have display names`() {
        for feature in AppFeature.allCases {
            #expect(!feature.displayName.isEmpty, "\(feature.rawValue) missing displayName")
        }
    }

    @Test
    func `all package features have display names`() {
        for feature in PackageFeature.allCases {
            #expect(!feature.displayName.isEmpty, "\(feature.rawValue) missing displayName")
        }
    }

    @Test
    func `all CLI features have display names`() {
        for feature in CLIFeature.allCases {
            #expect(!feature.displayName.isEmpty, "\(feature.rawValue) missing displayName")
        }
    }

    @Test
    func `all project types are iterable`() {
        #expect(ProjectType.allCases.count == 3)
        #expect(ProjectType.allCases.contains(.app))
        #expect(ProjectType.allCases.contains(.package))
        #expect(ProjectType.allCases.contains(.cli))
    }

    @Test
    func `app prompt options excludes auto-derived features`() {
        let options = AppFeature.promptOptions
        #expect(!options.contains(.tabs))
        #expect(!options.contains(.macCatalyst))
    }
}
