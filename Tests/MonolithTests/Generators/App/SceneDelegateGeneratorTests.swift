import Foundation
import Testing
@testable import MonolithLib

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
            projectSystem: .xcodeProj,
            tabs: tabs,
            primaryColor: "#007AFF",
            features: features,
            author: "Test",
            licenseType: .proprietary
        )
    }

    @Test
    func `basic scene delegate structure`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig())
        #expect(output.contains("import UIKit"))
        #expect(output.contains("class SceneDelegate"))
        #expect(output.contains("UIWindowSceneDelegate"))
        #expect(output.contains("var window: UIWindow?"))
        #expect(output.contains("guard let windowScene"))
    }

    @Test
    func `window creation and display`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig())
        #expect(output.contains("let window = UIWindow(windowScene: windowScene)"))
        #expect(output.contains("window.makeKeyAndVisible()"))
    }

    @Test
    func `uses ViewController when no tabs`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig())
        #expect(output.contains("let rootVC = ViewController()"))
        #expect(output.contains("UINavigationController(rootViewController: rootVC)"))
    }

    @Test
    func `uses MainTabBarController with tabs`() {
        let tabs = [
            TabDefinition(name: "Home", icon: "house.fill"),
            TabDefinition(name: "Settings", icon: "gear"),
        ]
        let output = SceneDelegateGenerator.generate(config: makeConfig(tabs: tabs))
        #expect(output.contains("MainTabBarController()"))
    }

    @Test
    func `tab bar with SwiftData passes model container`() {
        let tabs = [TabDefinition(name: "Home", icon: "house.fill")]
        let output = SceneDelegateGenerator.generate(config: makeConfig(swiftData: true, tabs: tabs))
        #expect(output.contains("MainTabBarController(modelContainer: modelContainer)"))
    }

    @Test
    func `SwiftData retrieves model container from AppDelegate`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig(swiftData: true))
        #expect(output.contains("import SwiftData"))
        #expect(output.contains("(UIApplication.shared.delegate as? AppDelegate)?.modelContainer"))
    }

    @Test
    func `Mac Catalyst adds window configuration`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig(macCatalyst: true))
        #expect(output.contains("#if targetEnvironment(macCatalyst)"))
        #expect(output.contains("configureMacWindowIfNeeded"))
        #expect(output.contains("titlebar.titleVisibility = .hidden"))
        #expect(output.contains("minimumSize"))
        #expect(output.contains("maximumSize"))
    }

    @Test
    func `no Mac Catalyst without feature flag`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig())
        #expect(!output.contains("#if targetEnvironment"))
        #expect(!output.contains("configureMacWindowIfNeeded"))
    }
}
