import Foundation
import Testing
@testable import MonolithLib

struct SceneDelegateGeneratorTests {
    private func makeConfig(
        swiftData: Bool = false,
        lumiKit: Bool = false,
        macCatalyst: Bool = false,
        deepLinks: Bool = false,
        spotlight: Bool = false,
        cloudKitSharing: Bool = false,
        deferredLaunchWork: Bool = false,
        tabs: [TabDefinition] = []
    ) -> AppConfig {
        var features: Set<AppFeature> = []
        if swiftData { features.insert(.swiftData) }
        if lumiKit { features.insert(.lumiKit) }
        if deepLinks { features.insert(.deepLinks) }
        if spotlight { features.insert(.spotlight) }
        if cloudKitSharing { features.insert(.cloudKitSharing) }
        if deferredLaunchWork { features.insert(.deferredLaunchWork) }

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

    // MARK: - LumiKit navigation wrapper

    @Test
    func `LumiKit wraps root in LMKNavigationController`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig(lumiKit: true))
        #expect(output.contains("LMKNavigationController(rootViewController: rootVC)"))
        #expect(!output.contains("UINavigationController(rootViewController: rootVC)"))
    }

    @Test
    func `without LumiKit uses UINavigationController`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig())
        #expect(output.contains("UINavigationController(rootViewController: rootVC)"))
        #expect(!output.contains("LMKNavigationController"))
    }

    // MARK: - Deep links

    @Test
    func `deep links add URL handler scaffolding`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig(deepLinks: true))
        #expect(output.contains("private var pendingDeepLink: URL?"))
        #expect(output.contains("openURLContexts URLContexts"))
        #expect(output.contains("handleDeepLink"))
    }

    @Test
    func `no deep link scaffolding without feature`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig())
        #expect(!output.contains("handleDeepLink"))
        #expect(!output.contains("pendingDeepLink"))
    }

    // MARK: - Spotlight

    @Test
    func `Spotlight imports CoreSpotlight and handles activity`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig(spotlight: true))
        #expect(output.contains("import CoreSpotlight"))
        #expect(output.contains("CSSearchableItemActionType"))
        #expect(output.contains("handleSpotlightActivity"))
        #expect(output.contains("spotlightItemSelected"))
    }

    @Test
    func `no Spotlight scaffolding without feature`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig())
        #expect(!output.contains("import CoreSpotlight"))
        #expect(!output.contains("handleSpotlightActivity"))
    }

    // MARK: - CloudKit sharing

    @Test
    func `CloudKit sharing imports CloudKit and handles share metadata`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig(cloudKitSharing: true))
        #expect(output.contains("import CloudKit"))
        #expect(output.contains("userDidAcceptCloudKitShareWith"))
        #expect(output.contains("CKContainer"))
        #expect(output.contains(".accept(cloudKitShareMetadata"))
    }

    @Test
    func `no CloudKit sharing without feature`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig())
        #expect(!output.contains("import CloudKit"))
        #expect(!output.contains("userDidAcceptCloudKitShareWith"))
    }

    // MARK: - Deferred launch work

    @Test
    func `deferred launch work adds activate-time helper`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig(deferredLaunchWork: true))
        #expect(output.contains("sceneDidBecomeActive"))
        #expect(output.contains("deferLaunchWork"))
    }

    @Test
    func `no deferred launch work without feature`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig())
        #expect(!output.contains("deferLaunchWork"))
    }

    // MARK: - Feature composition

    @Test
    func `features compose without duplicate imports`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig(
            swiftData: true,
            lumiKit: true,
            macCatalyst: true,
            deepLinks: true,
            spotlight: true,
            cloudKitSharing: true,
            deferredLaunchWork: true
        ))
        // Each import should appear exactly once
        let uikitOccurrences = output.components(separatedBy: "import UIKit").count - 1
        #expect(uikitOccurrences == 1)
        let cloudKitOccurrences = output.components(separatedBy: "import CloudKit").count - 1
        #expect(cloudKitOccurrences == 1)
    }
}
