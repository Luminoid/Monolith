import Foundation
import Testing
@testable import MonolithLib

@Suite("SceneDelegateGenerator")
struct SceneDelegateGeneratorTests {
    private func makeConfig(
        swiftData: Bool = false,
        macCatalyst: Bool = false,
        tabs: [TabDefinition] = []
    ) -> AppConfig {
        var features: Set<AppFeature> = []
        if swiftData { features.insert(.swiftData) }

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
            author: "Test"
        )
    }

    @Test("basic scene delegate structure")
    func basicStructure() {
        let output = SceneDelegateGenerator.generate(config: makeConfig())
        #expect(output.contains("import UIKit"))
        #expect(output.contains("class SceneDelegate"))
        #expect(output.contains("UIWindowSceneDelegate"))
        #expect(output.contains("var window: UIWindow?"))
        #expect(output.contains("guard let windowScene"))
    }

    @Test("window creation and display")
    func windowCreation() {
        let output = SceneDelegateGenerator.generate(config: makeConfig())
        #expect(output.contains("let window = UIWindow(windowScene: windowScene)"))
        #expect(output.contains("window.makeKeyAndVisible()"))
    }

    @Test("uses ViewController when no tabs")
    func noTabsUsesViewController() {
        let output = SceneDelegateGenerator.generate(config: makeConfig())
        #expect(output.contains("let rootVC = ViewController()"))
        #expect(output.contains("UINavigationController(rootViewController: rootVC)"))
    }

    @Test("uses MainTabBarController with tabs")
    func tabsUsesTabBar() {
        let tabs = [
            TabDefinition(name: "Home", icon: "house.fill"),
            TabDefinition(name: "Settings", icon: "gear"),
        ]
        let output = SceneDelegateGenerator.generate(config: makeConfig(tabs: tabs))
        #expect(output.contains("MainTabBarController()"))
    }

    @Test("tab bar with SwiftData passes model container")
    func tabBarWithSwiftData() {
        let tabs = [TabDefinition(name: "Home", icon: "house.fill")]
        let output = SceneDelegateGenerator.generate(config: makeConfig(swiftData: true, tabs: tabs))
        #expect(output.contains("MainTabBarController(modelContainer: modelContainer)"))
    }

    @Test("SwiftData retrieves model container from AppDelegate")
    func swiftDataContainer() {
        let output = SceneDelegateGenerator.generate(config: makeConfig(swiftData: true))
        #expect(output.contains("import SwiftData"))
        #expect(output.contains("(UIApplication.shared.delegate as? AppDelegate)?.modelContainer"))
    }

    @Test("Mac Catalyst adds window configuration")
    func macCatalystConfig() {
        let output = SceneDelegateGenerator.generate(config: makeConfig(macCatalyst: true))
        #expect(output.contains("#if targetEnvironment(macCatalyst)"))
        #expect(output.contains("configureMacWindowIfNeeded"))
        #expect(output.contains("titlebar.titleVisibility = .hidden"))
        #expect(output.contains("minimumSize"))
        #expect(output.contains("maximumSize"))
    }

    @Test("no Mac Catalyst without feature flag")
    func noMacCatalystByDefault() {
        let output = SceneDelegateGenerator.generate(config: makeConfig())
        #expect(!output.contains("#if targetEnvironment"))
        #expect(!output.contains("configureMacWindowIfNeeded"))
    }
}
