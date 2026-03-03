import Foundation
import Testing
@testable import MonolithLib

@Suite("TabBarGenerator")
struct TabBarGeneratorTests {
    private func makeConfig(
        swiftData: Bool = false,
        lumiKit: Bool = false,
        macCatalyst: Bool = false,
        tabs: [TabDefinition] = [
            TabDefinition(name: "Home", icon: "house.fill"),
            TabDefinition(name: "Settings", icon: "gear"),
        ],
    ) -> AppConfig {
        var features: Set<AppFeature> = []
        if swiftData { features.insert(.swiftData) }
        if lumiKit { features.insert(.lumiKit) }

        var platforms: Set<Platform> = [.iPhone]
        if macCatalyst { platforms.insert(.macCatalyst) }

        return AppConfig(
            name: "TestApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: platforms,
            projectSystem: .spm,
            tabs: tabs,
            primaryColor: "#007AFF",
            features: features,
            author: "Test",
        )
    }

    @Test("basic tab bar structure")
    func basicStructure() {
        let output = TabBarGenerator.generate(config: makeConfig())
        #expect(output.contains("class MainTabBarController: UITabBarController"))
        #expect(output.contains("navControllers"))
        #expect(output.contains("buildTabs()"))
        #expect(output.contains("selectTab"))
    }

    @Test("builds tabs for each definition")
    func buildsTabs() {
        let output = TabBarGenerator.generate(config: makeConfig())
        #expect(output.contains("HomeViewController"))
        #expect(output.contains("SettingsViewController"))
        #expect(output.contains("house.fill"))
        #expect(output.contains("gear"))
        #expect(output.contains("TabBarTag.home"))
        #expect(output.contains("TabBarTag.settings"))
    }

    @Test("SwiftData adds modelContainer init")
    func swiftDataInit() {
        let output = TabBarGenerator.generate(config: makeConfig(swiftData: true))
        #expect(output.contains("import SwiftData"))
        #expect(output.contains("init(modelContainer: ModelContainer)"))
        #expect(output.contains("self.modelContainer = modelContainer"))
    }

    @Test("no SwiftData uses standard init")
    func noSwiftDataInit() {
        let output = TabBarGenerator.generate(config: makeConfig())
        #expect(!output.contains("import SwiftData"))
        #expect(!output.contains("init(modelContainer:"))
    }

    @Test("LumiKit sets tab bar tint color")
    func lumiKitTintColor() {
        let output = TabBarGenerator.generate(config: makeConfig(lumiKit: true))
        #expect(output.contains("import LumiKitUI"))
        #expect(output.contains("LMKColor.primary"))
    }

    @Test("Mac Catalyst adds menu handlers")
    func macCatalystHandlers() {
        let output = TabBarGenerator.generate(config: makeConfig(macCatalyst: true))
        #expect(output.contains("#if targetEnvironment(macCatalyst)"))
        #expect(output.contains("setupMacMenuHandlers"))
        #expect(output.contains("handleMacMenuSwitchTab"))
        #expect(output.contains("AppNotification.macMenuSwitchTab"))
    }

    @Test("no Mac Catalyst without platform")
    func noMacCatalyst() {
        let output = TabBarGenerator.generate(config: makeConfig())
        #expect(!output.contains("#if targetEnvironment"))
        #expect(!output.contains("setupMacMenuHandlers"))
    }

    @Test("three tabs generates three entries")
    func threeTabs() {
        let tabs = [
            TabDefinition(name: "Home", icon: "house.fill"),
            TabDefinition(name: "Search", icon: "magnifyingglass"),
            TabDefinition(name: "Profile", icon: "person.fill"),
        ]
        let output = TabBarGenerator.generate(config: makeConfig(tabs: tabs))
        #expect(output.contains("HomeViewController"))
        #expect(output.contains("SearchViewController"))
        #expect(output.contains("ProfileViewController"))
        #expect(output.contains("homeNav, searchNav, profileNav"))
    }
}
