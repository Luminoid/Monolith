import Foundation
import Testing
@testable import MonolithLib

@Suite("AppConstantsGenerator")
struct AppConstantsGeneratorTests {
    private func makeConfig(
        macCatalyst: Bool = false,
        tabs: [TabDefinition] = [],
        name: String = "TestApp",
    ) -> AppConfig {
        var platforms: Set<Platform> = [.iPhone]
        if macCatalyst { platforms.insert(.macCatalyst) }

        return AppConfig(
            name: name,
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: platforms,
            projectSystem: .spm,
            tabs: tabs,
            primaryColor: "#007AFF",
            features: [],
            author: "Test",
        )
    }

    @Test("generates AppNotification with app name")
    func appNotification() {
        let output = AppConstantsGenerator.generate(config: makeConfig(name: "MyApp"))
        #expect(output.contains("nonisolated enum AppNotification"))
        #expect(output.contains("\"MyAppDataChanged\""))
        #expect(output.contains("\"MyAppMemoryWarning\""))
    }

    @Test("Mac Catalyst adds menu notifications")
    func macCatalystMenuNotifications() {
        let output = AppConstantsGenerator.generate(config: makeConfig(macCatalyst: true))
        #expect(output.contains("macMenuRefresh"))
    }

    @Test("Mac Catalyst with tabs adds switch tab notification")
    func macCatalystTabNotification() {
        let config = makeConfig(
            macCatalyst: true,
            tabs: [TabDefinition(name: "Home", icon: "house")],
        )
        let output = AppConstantsGenerator.generate(config: config)
        #expect(output.contains("macMenuSwitchTab"))
    }

    @Test("tabs generate TabBarTag enum")
    func tabBarTagEnum() {
        let tabs = [
            TabDefinition(name: "Home", icon: "house"),
            TabDefinition(name: "Settings", icon: "gear"),
        ]
        let output = AppConstantsGenerator.generate(config: makeConfig(tabs: tabs))
        #expect(output.contains("nonisolated enum TabBarTag: Int"))
        #expect(output.contains("case home = 0"))
        #expect(output.contains("case settings = 1"))
    }

    @Test("no TabBarTag without tabs")
    func noTabBarTagWithoutTabs() {
        let output = AppConstantsGenerator.generate(config: makeConfig())
        #expect(!output.contains("TabBarTag"))
    }

    @Test("Mac Catalyst adds MacWindow constants")
    func macWindowConstants() {
        let output = AppConstantsGenerator.generate(config: makeConfig(macCatalyst: true))
        #expect(output.contains("enum MacWindow"))
        #expect(output.contains("minWidth"))
        #expect(output.contains("maxHeight"))
    }

    @Test("generates UserDefaultsKey and ReuseIdentifier")
    func utilityEnums() {
        let output = AppConstantsGenerator.generate(config: makeConfig())
        #expect(output.contains("nonisolated enum UserDefaultsKey"))
        #expect(output.contains("nonisolated enum ReuseIdentifier"))
        #expect(output.contains("nonisolated enum AppConstants"))
    }

    @Test("MARK sections present")
    func markSections() {
        let output = AppConstantsGenerator.generate(config: makeConfig())
        #expect(output.contains("// MARK: - Notifications"))
        #expect(output.contains("// MARK: - UserDefaults Keys"))
        #expect(output.contains("// MARK: - App Constants"))
    }
}
