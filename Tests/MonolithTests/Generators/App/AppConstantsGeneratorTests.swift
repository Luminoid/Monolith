import Foundation
import Testing
@testable import MonolithLib

struct AppConstantsGeneratorTests {
    private func makeConfig(
        macCatalyst: Bool = false,
        tabs: [TabDefinition] = [],
        name: String = "TestApp"
    ) -> AppConfig {
        var platforms: Set<Platform> = [.iPhone]
        if macCatalyst { platforms.insert(.macCatalyst) }

        return AppConfig(
            name: name,
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: platforms,
            projectSystem: .xcodeProj,
            tabs: tabs,
            primaryColor: "#007AFF",
            features: [],
            author: "Test"
        )
    }

    @Test
    func `generates AppNotification with app name`() {
        let output = AppConstantsGenerator.generate(config: makeConfig(name: "MyApp"))
        #expect(output.contains("nonisolated enum AppNotification"))
        #expect(output.contains("\"MyAppDataChanged\""))
        #expect(output.contains("\"MyAppMemoryWarning\""))
    }

    @Test
    func `Mac Catalyst adds menu notifications`() {
        let output = AppConstantsGenerator.generate(config: makeConfig(macCatalyst: true))
        #expect(output.contains("macMenuRefresh"))
    }

    @Test
    func `Mac Catalyst with tabs adds switch tab notification`() {
        let config = makeConfig(
            macCatalyst: true,
            tabs: [TabDefinition(name: "Home", icon: "house")]
        )
        let output = AppConstantsGenerator.generate(config: config)
        #expect(output.contains("macMenuSwitchTab"))
    }

    @Test
    func `tabs generate TabBarTag enum`() {
        let tabs = [
            TabDefinition(name: "Home", icon: "house"),
            TabDefinition(name: "Settings", icon: "gear"),
        ]
        let output = AppConstantsGenerator.generate(config: makeConfig(tabs: tabs))
        #expect(output.contains("nonisolated enum TabBarTag: Int"))
        #expect(output.contains("case home = 0"))
        #expect(output.contains("case settings = 1"))
    }

    @Test
    func `no TabBarTag without tabs`() {
        let output = AppConstantsGenerator.generate(config: makeConfig())
        #expect(!output.contains("TabBarTag"))
    }

    @Test
    func `Mac Catalyst adds MacWindow constants`() {
        let output = AppConstantsGenerator.generate(config: makeConfig(macCatalyst: true))
        #expect(output.contains("enum MacWindow"))
        #expect(output.contains("minWidth"))
        #expect(output.contains("maxHeight"))
    }

    @Test
    func `generates UserDefaultsKey and ReuseIdentifier`() {
        let output = AppConstantsGenerator.generate(config: makeConfig())
        #expect(output.contains("nonisolated enum UserDefaultsKey"))
        #expect(output.contains("nonisolated enum ReuseIdentifier"))
        #expect(output.contains("nonisolated enum AppConstants"))
    }

    @Test
    func `MARK sections present`() {
        let output = AppConstantsGenerator.generate(config: makeConfig())
        #expect(output.contains("// MARK: - Notifications"))
        #expect(output.contains("// MARK: - UserDefaults Keys"))
        #expect(output.contains("// MARK: - App Constants"))
    }
}
