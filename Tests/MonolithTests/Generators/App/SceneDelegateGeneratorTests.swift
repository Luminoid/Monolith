import Foundation
import Testing
@testable import MonolithLib

struct SceneDelegateGeneratorTests {
    private func makeConfig(
        swiftData: Bool = false,
        coreData: Bool = false,
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
        if coreData { features.insert(.coreData) }
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
    func `SwiftData tabs path retrieves model container from AppDelegate`() {
        // The tabs path still touches the container directly (passes it to
        // `MainTabBarController(modelContainer:)`), so SceneDelegate imports
        // SwiftData and binds the container locally. The no-tabs path doesn't
        // touch the container anymore (see below) — AppDelegate keeps it as a
        // non-optional property and the scene leaves it alone.
        let tabs = [TabDefinition(name: "Home", icon: "house.fill")]
        let output = SceneDelegateGenerator.generate(config: makeConfig(swiftData: true, tabs: tabs))
        #expect(output.contains("import SwiftData"))
        #expect(output.contains("(UIApplication.shared.delegate as? AppDelegate)?.modelContainer"))
    }

    @Test
    func `SwiftData no-tabs path drops the container guard entirely`() {
        // AppDelegate's `modelContainer` is now non-optional (init `fatalError`s
        // on failure, per workspace lessons). The pre-fatalError generator
        // emitted `guard ... modelContainer != nil` here as a defensive check;
        // with `fatalError` upstream, that check is dead code. The no-tabs
        // placeholder `ViewController()` consumes no container, so no binding
        // or guard is emitted at all. `import SwiftData` is also dropped from
        // SceneDelegate in this configuration since nothing on the scene side
        // references the SwiftData type.
        let output = SceneDelegateGenerator.generate(config: makeConfig(swiftData: true))
        #expect(!output.contains("guard (UIApplication.shared.delegate as? AppDelegate)?.modelContainer != nil"))
        #expect(!output.contains("guard let modelContainer ="))
        #expect(!output.contains("guard let _ ="))
        #expect(!output.contains("import SwiftData"))
    }

    @Test
    func `SwiftData tabs path keeps named binding for downstream injection`() {
        let tabs = [TabDefinition(name: "Home", icon: "house.fill")]
        let output = SceneDelegateGenerator.generate(config: makeConfig(swiftData: true, tabs: tabs))
        #expect(output.contains("guard let modelContainer ="))
        #expect(!output.contains("guard let _ ="))
    }

    @Test
    func `Mac Catalyst adds window configuration that delegates to MacWindowConfig`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig(macCatalyst: true))
        #expect(output.contains("#if targetEnvironment(macCatalyst)"))
        #expect(output.contains("configureMacWindowIfNeeded"))
        // SceneDelegate delegates to the dedicated `MacWindowConfig.configure`
        // function (sole owner of the window-config recipe). Inlining the
        // titlebar / size restrictions here would duplicate `MacWindowConfig`'s
        // body and create magic-number drift across files.
        #expect(output.contains("MacWindowConfig.configure(windowScene)"))
        #expect(!output.contains("titlebar.titleVisibility = .hidden"), "should delegate, not inline")
        #expect(!output.contains("CGSize(width: 600, height: 800)"), "no inline magic numbers")
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
    }

    // Regression: with Core Data, a raw CKContainer.accept() accepts the share
    // at the CloudKit layer but never imports records into the persistent
    // container's shared store. acceptShareInvitations(from:into:) is required.
    // cloudKitSharing resolves to Core Data by default (no SwiftData), so this
    // is the path real sharing apps take.
    @Test
    func `CoreData sharing imports the share into the shared store`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig(coreData: true, cloudKitSharing: true))
        #expect(output.contains("userDidAcceptCloudKitShareWith"))
        #expect(output.contains("import CoreData")) // acceptShareInvitations lives in CoreData
        #expect(output.contains("acceptShareInvitations("))
        #expect(output.contains("TestAppCoreDataStack.shared"))
        #expect(output.contains("stack.sharedStore"))
        #expect(!output.contains(".accept(cloudKitShareMetadata)"))
    }

    /// The raw CKContainer.accept() path is the SwiftData fallback (SwiftData
    /// has no Core Data shared store to import into).
    @Test
    func `SwiftData sharing keeps the raw CKContainer accept path`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig(swiftData: true, cloudKitSharing: true))
        #expect(output.contains(".accept(cloudKitShareMetadata)"))
        #expect(!output.contains("acceptShareInvitations("))
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
