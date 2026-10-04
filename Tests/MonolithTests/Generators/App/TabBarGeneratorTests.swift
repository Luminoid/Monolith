import Foundation
import Testing
@testable import MonolithLib

struct TabBarGeneratorTests {
    private func makeConfig(
        swiftData: Bool = false,
        lumiKit: Bool = false,
        macCatalyst: Bool = false,
        localization: Bool = false,
        tabs: [TabDefinition] = [
            TabDefinition(name: "Home", icon: "house.fill"),
            TabDefinition(name: "Settings", icon: "gear"),
        ]
    ) -> AppConfig {
        var features: Set<AppFeature> = []
        if swiftData { features.insert(.swiftData) }
        if lumiKit { features.insert(.lumiKit) }
        if localization { features.insert(.localization) }

        var platforms: Set<Platform> = [.iPhone]
        if macCatalyst { platforms.insert(.macCatalyst) }

        return AppConfig(
            name: "TestApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: platforms,
            projectSystem: .xcodeProj,
            tabs: tabs,
            primaryColor: "#007AFF",
            features: features,
            author: "Test",
            licenseType: .proprietary
        )
    }

    @Test
    func `basic tab bar structure`() {
        let output = TabBarGenerator.generate(config: makeConfig())
        #expect(output.contains("class MainTabBarController: UITabBarController"))
        #expect(output.contains("navControllers"))
        #expect(output.contains("buildTabs()"))
        #expect(output.contains("selectTab"))
    }

    // Regression: when localization is on, the tab bar must read titles from
    // the catalog (L10n.Tab.<case>), matching the per-tab nav-bar titles — a
    // hardcoded literal leaves the tab bar English while nav bars localize.
    @Test
    func `localized tab titles use L10n_Tab`() {
        let output = TabBarGenerator.generate(config: makeConfig(localization: true))
        #expect(output.contains("title: L10n.Tab.home"))
        #expect(output.contains("title: L10n.Tab.settings"))
        #expect(!output.contains("title: \"Home\""))
    }

    @Test
    func `non-localized tab titles use literals`() {
        let output = TabBarGenerator.generate(config: makeConfig())
        #expect(output.contains("title: \"Home\""))
        #expect(!output.contains("L10n.Tab"))
    }

    @Test
    func `builds tabs for each definition`() {
        let output = TabBarGenerator.generate(config: makeConfig())
        #expect(output.contains("HomeViewController"))
        #expect(output.contains("SettingsViewController"))
        #expect(output.contains("house.fill"))
        #expect(output.contains("gear"))
        #expect(output.contains("TabBarTag.home"))
        #expect(output.contains("TabBarTag.settings"))
    }

    @Test
    func `SwiftData adds modelContainer init`() {
        let output = TabBarGenerator.generate(config: makeConfig(swiftData: true))
        #expect(output.contains("import SwiftData"))
        #expect(output.contains("init(modelContainer: ModelContainer)"))
        #expect(output.contains("self.modelContainer = modelContainer"))
    }

    @Test
    func `no SwiftData uses standard init`() {
        let output = TabBarGenerator.generate(config: makeConfig())
        #expect(!output.contains("import SwiftData"))
        #expect(!output.contains("init(modelContainer:"))
    }

    // MARK: - LumiKit

    @Test
    func `LumiKit subclasses LMKTabBarController with LMKTab definitions`() {
        let output = TabBarGenerator.generate(config: makeConfig(lumiKit: true))
        #expect(output.contains("import LumiKitUI"))
        #expect(output.contains("final class MainTabBarController: LMKTabBarController {"))
        #expect(output.contains("        super.init(tabs: Self.makeTabs())"))
        #expect(output.contains(
            "            LMKTab(identifier: TabBarTag.home.identifier, title: \"Home\", systemImage: \"house.fill\") { HomeViewController() },"
        ))
        #expect(output.contains(
            "            LMKTab(identifier: TabBarTag.settings.identifier, title: \"Settings\", systemImage: \"gear\") { SettingsViewController() },"
        ))
        // LMKTabBarController builds and wraps the roots and themes the bar
        // itself, so none of the hand-rolled UITabBarController setup remains.
        #expect(!output.contains("UITabBarController"))
        #expect(!output.contains("UITabBarItem"))
        #expect(!output.contains("navControllers"))
        #expect(!output.contains("tintColor"))
    }

    @Test
    func `LumiKit selects tabs by identifier`() {
        let output = TabBarGenerator.generate(config: makeConfig(lumiKit: true))
        #expect(output.contains("    func selectTab(for tag: TabBarTag) {\n        selectTab(identifier: tag.identifier)\n    }"))
        #expect(output.contains("private extension TabBarTag {"))
        #expect(output.contains("var identifier: String { String(describing: self) }"))
    }

    @Test
    func `LumiKit tabs read localized titles`() {
        let output = TabBarGenerator.generate(config: makeConfig(lumiKit: true, localization: true))
        #expect(output.contains("title: L10n.Tab.home,"))
        #expect(!output.contains("title: \"Home\""))
    }

    @Test
    func `LumiKit SwiftData init passes the tabs to super`() {
        let output = TabBarGenerator.generate(config: makeConfig(swiftData: true, lumiKit: true))
        #expect(output.contains("import SwiftData"))
        #expect(output.contains(
            "    init(modelContainer: ModelContainer) {\n        self.modelContainer = modelContainer\n        super.init(tabs: Self.makeTabs())\n    }"
        ))
    }

    @Test
    func `LumiKit on Mac Catalyst hands tab shortcuts to the app menu`() {
        let output = TabBarGenerator.generate(config: makeConfig(lumiKit: true, macCatalyst: true))
        #expect(output.contains("tabKeyCommandsEnabled = false"))
        #expect(output.contains("setupMacMenuHandlers()"))
        #expect(output.contains("handleMacMenuSwitchTab"))
        let plain = TabBarGenerator.generate(config: makeConfig(lumiKit: true))
        #expect(!plain.contains("tabKeyCommandsEnabled"))
        #expect(!plain.contains("override func viewDidLoad()"))
    }

    @Test
    func `standard tab bar does not import LumiKit`() {
        let output = TabBarGenerator.generate(config: makeConfig())
        #expect(!output.contains("LumiKit"))
        #expect(!output.contains("LMK"))
        #expect(output.contains("private typealias NavController = UINavigationController"))
    }

    @Test
    func `Mac Catalyst adds menu handlers`() {
        let output = TabBarGenerator.generate(config: makeConfig(macCatalyst: true))
        #expect(output.contains("#if targetEnvironment(macCatalyst)"))
        #expect(output.contains("setupMacMenuHandlers"))
        #expect(output.contains("handleMacMenuSwitchTab"))
        #expect(output.contains("AppNotification.macMenuSwitchTab"))
    }

    @Test
    func `no Mac Catalyst without platform`() {
        let output = TabBarGenerator.generate(config: makeConfig())
        #expect(!output.contains("#if targetEnvironment"))
        #expect(!output.contains("setupMacMenuHandlers"))
    }

    @Test
    func `three tabs generates three entries`() {
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
