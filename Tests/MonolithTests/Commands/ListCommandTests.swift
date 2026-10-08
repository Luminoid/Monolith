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

    @Test
    func `the CLI heading is spelled CLI`() {
        #expect(ListFeaturesCommand.heading(for: .cli) == "CLI")
        #expect(ListFeaturesCommand.heading(for: .app) == "App")
        #expect(ListFeaturesCommand.heading(for: .package) == "Package")
    }

    /// darkMode is selectable (LumiKit also turns it on); coreDataAuditHook
    /// can't be passed to --features.
    @Test
    func `only features --features rejects are tagged auto-derived`() {
        for feature in [AppFeature.tabs, .macCatalyst, .coreDataAuditHook] {
            #expect(ListFeaturesCommand.note(for: feature) == " (auto-derived)", "\(feature)")
        }
        for feature in [AppFeature.darkMode, .lumiKit, .strictConcurrency] {
            #expect(ListFeaturesCommand.note(for: feature).isEmpty, "\(feature)")
        }
    }

    @Test
    func `list features takes a project type and rejects others`() throws {
        #expect(try ListFeaturesCommand.parse(["--type", "cli"]).type == .cli)
        #expect(throws: (any Error).self) { try ListFeaturesCommand.parse(["--type", "widget"]) }
    }
}
