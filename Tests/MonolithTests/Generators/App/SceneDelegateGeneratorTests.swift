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
        notifications: Bool = false,
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
        if notifications { features.insert(.notifications) }

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
    func `tab bar controller is the window root, not wrapped in a navigation controller`() {
        // Each tab carries its own navigation controller; an outer one would
        // stack an empty bar above every tab's bar.
        let tabs = [TabDefinition(name: "Home", icon: "house.fill")]
        for lumiKit in [false, true] {
            let output = SceneDelegateGenerator.generate(config: makeConfig(lumiKit: lumiKit, tabs: tabs))
            #expect(output.contains("        window.rootViewController = rootVC\n"))
            #expect(!output.contains("NavigationController(rootViewController: rootVC)"))
        }
        // A tabbed LumiKit scene names no LumiKit type, so it skips the import.
        let lumiKit = SceneDelegateGenerator.generate(config: makeConfig(lumiKit: true, tabs: tabs))
        #expect(!lumiKit.contains("import LumiKitUI"))
    }

    @Test
    func `tab bar with SwiftData passes model container`() {
        let tabs = [TabDefinition(name: "Home", icon: "house.fill")]
        let output = SceneDelegateGenerator.generate(config: makeConfig(swiftData: true, tabs: tabs))
        #expect(output.contains("MainTabBarController(modelContainer: modelContainer)"))
    }

    @Test(arguments: [false, true])
    func `SwiftData scene hands the AppDelegate container to the root`(tabs: Bool) {
        // The AppDelegate's container is non-optional; the `as?` chain re-wraps
        // it, hence the `guard let`. Both roots take the container in `init`.
        let tabList = tabs ? [TabDefinition(name: "Home", icon: "house.fill")] : []
        let output = SceneDelegateGenerator.generate(config: makeConfig(swiftData: true, tabs: tabList))
        #expect(output.contains("import SwiftData"))
        #expect(output.contains("guard let modelContainer = (UIApplication.shared.delegate as? AppDelegate)?.modelContainer else {"))
        #expect(!output.contains("modelContainer != nil"))
        #expect(!output.contains("guard let _ ="))
        let root = tabs ? "MainTabBarController" : "ViewController"
        #expect(output.contains("let rootVC = \(root)(modelContainer: modelContainer)"))
    }

    @Test
    func `no SwiftData import without SwiftData`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig(tabs: [TabDefinition(name: "Home", icon: "house.fill")]))
        #expect(!output.contains("import SwiftData"))
        #expect(!output.contains("modelContainer"))
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
    func `LumiKit Mac Catalyst configures the window through LMKScene`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig(lumiKit: true, macCatalyst: true))
        #expect(output.contains("import LumiKitUI"))
        #expect(output.contains("        configureMacWindowIfNeeded(windowScene)"))
        // Minimum size only: a maximum would block full screen and wide tiling.
        #expect(output.contains("""
                LMKScene.configureMacWindow(
                    for: windowScene,
                    minimumSize: CGSize(width: AppConstants.MacWindow.minWidth, height: AppConstants.MacWindow.minHeight),
                    // No maximum, so full screen and wide window tiling keep working.
                    maximumSize: nil,
        """))
        #expect(!output.contains("maxWidth"))
        #expect(!output.contains("maxHeight"))
        // Generated apps run in the scaled iPad idiom, so the title bar hides;
        // the comment above the argument says when to pass `false`.
        #expect(output.contains("            hidesTitleBar: true\n        )"))
        // `LMKScene.configureMacWindow` is a no-op off Catalyst: no `#if` and
        // no separate `MacWindowConfig` helper.
        #expect(!output.contains("MacWindowConfig"))
        #expect(!output.contains("#if targetEnvironment(macCatalyst)"))
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
    }

    /// A Spotlight result that launches the app arrives before any screen
    /// exists (tab roots build on first selection), so it is held and routed
    /// once the scene is active, never broadcast.
    @Test
    func `Spotlight results that launch the app wait for activation`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig(spotlight: true, tabs: [TabDefinition(name: "Home", icon: "house")]))
        #expect(output.contains("    private var pendingSpotlightIdentifier: String?"))
        #expect(output.contains("""
                guard window?.windowScene?.activationState == .foregroundActive else {
                    pendingSpotlightIdentifier = identifier
                    return
                }
                showSpotlightItem(identifier)
        """))
        #expect(output.contains("""
            func sceneDidBecomeActive(_ scene: UIScene) {
                if let identifier = pendingSpotlightIdentifier {
                    pendingSpotlightIdentifier = nil
                    showSpotlightItem(identifier)
                }
            }
        """))
        #expect(output.contains("// (window?.rootViewController as? MainTabBarController)?.selectTab(for: .home)"))
        #expect(!output.contains("NotificationCenter.default.post"))
        #expect(!output.contains("spotlightItemSelected"))
    }

    // MARK: - Notifications

    @Test
    func `notification taps are held until the scene is active`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig(notifications: true))
        #expect(output.contains("import UserNotifications"))
        #expect(output.contains("    private var pendingNotificationResponse: UNNotificationResponse?"))
        #expect(output.contains("    func handleNotificationResponse(_ response: UNNotificationResponse) {"))
        #expect(output.contains("pendingNotificationResponse = response"))
        #expect(output.contains("""
                if let response = pendingNotificationResponse {
                    pendingNotificationResponse = nil
                    showNotification(response)
                }
        """))
        // A tab-less app routes through its navigation controller.
        #expect(output.contains("// (window?.rootViewController as? UINavigationController)?.pushViewController(detail, animated: true)"))
    }

    @Test
    func `no notification routing without feature`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig())
        #expect(!output.contains("import UserNotifications"))
        #expect(!output.contains("handleNotificationResponse"))
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
        #expect(output.contains("try await stack.container.acceptShareInvitations(from: [metadata], into: sharedStore)"))
        #expect(output.contains("TestAppCoreDataStack.shared"))
        #expect(output.contains("stack.sharedStore"))
        #expect(!output.contains(".accept("))
    }

    /// UIKit calls `windowScene(_:userDidAcceptCloudKitShareWith:)` only for a
    /// scene that is already connected; a share accepted from a cold launch
    /// arrives in the connection options. Both go through one stored task.
    @Test
    func `shares accepted on a cold launch are imported too`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig(coreData: true, cloudKitSharing: true))
        #expect(output.contains("""
                if let metadata = connectionOptions.cloudKitShareMetadata {
                    acceptCloudKitShare(metadata)
                }
        """))
        #expect(output.contains("""
            ) {
                acceptCloudKitShare(cloudKitShareMetadata)
            }
        """))
        #expect(output.contains("    private func acceptCloudKitShare(_ metadata: CKShare.Metadata) {"))
        #expect(output.contains("    private var shareAcceptTask: Task<Void, Never>?"))
        #expect(output.contains("        shareAcceptTask = Task { @MainActor in"))
        #expect(output.contains("""
            func sceneDidDisconnect(_ scene: UIScene) {
                shareAcceptTask?.cancel()
            }
        """))
        // Every Task the scene starts is stored.
        #expect(!output.contains("        Task {"))
    }

    @Test
    func `a share accepted with sync off asks the app to surface it`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig(coreData: true, cloudKitSharing: true))
        #expect(output.contains("NotificationCenter.default.post(name: AppNotification.cloudKitShareRequiresSync, object: nil)"))
    }

    /// SwiftData has no shared database, so validation rejects SwiftData with
    /// CloudKit sharing; the generator emits no share path for it either.
    @Test
    func `SwiftData never gets a share acceptance path`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig(swiftData: true, cloudKitSharing: true))
        #expect(!output.contains("userDidAcceptCloudKitShareWith"))
        #expect(!output.contains("CKContainer"))
        #expect(!output.contains("import CloudKit"))
    }

    @Test
    func `share acceptance failures log through Logger app without LumiKit`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig(coreData: true, cloudKitSharing: true))
        #expect(!output.contains("print("))
        #expect(output.contains("import os"))
        #expect(output.contains(
            "Logger.app.error(\"Failed to accept CloudKit share: \\(String(describing: error), privacy: .private)\")"
        ))
        // Nothing to present without LumiKit, so the task captures nothing.
        #expect(!output.contains("[weak self]"))
        let imports = output.split(separator: "\n").filter { $0.hasPrefix("import ") }
        #expect(imports == imports.sorted { $0.lowercased() < $1.lowercased() })
    }

    @Test
    func `share acceptance failures log and reach the user with LumiKit`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig(coreData: true, lumiKit: true, cloudKitSharing: true))
        #expect(!output.contains("print("))
        #expect(!output.contains("import os"))
        // LMKLogger lives in LumiKitCore, which LumiKitUI does not re-export;
        // LMKErrorHandler lives in LumiKitUI.
        #expect(output.contains("import LumiKitCore"))
        #expect(output.contains("import LumiKitUI"))
        #expect(output.contains("LMKLogger.error(\"Failed to accept CloudKit share\", error: error, category: LMKLogger.LogCategory.network)"))
        #expect(output.contains("LMKLogger.error(\"No shared store available to accept CloudKit share\", category: LMKLogger.LogCategory.data)"))
        #expect(output.contains("shareAcceptTask = Task { @MainActor [weak self] in"))
        #expect(output.contains("""
                        if let host = self?.window?.rootViewController {
                            LMKErrorHandler.present(from: host, error: error)
                        }
        """))
    }

    @Test
    func `no logging imports without CloudKit sharing`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig(lumiKit: true))
        #expect(!output.contains("import os"))
        #expect(!output.contains("import LumiKitCore"))
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

    /// The work used to start an untracked Task on every activation (each app
    /// switch and window focus). It now runs once per process, from a stored,
    /// cancellable task.
    @Test
    func `deferred launch work runs once per process from a stored task`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig(deferredLaunchWork: true))
        #expect(output.contains("    private var launchWorkTask: Task<Void, Never>?"))
        #expect(output.contains("    private static var didRunLaunchWork = false"))
        #expect(output.contains("""
                guard !Self.didRunLaunchWork else { return }
                Self.didRunLaunchWork = true
                launchWorkTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled else { return }
        """))
        #expect(output.contains("""
            func sceneDidDisconnect(_ scene: UIScene) {
                launchWorkTask?.cancel()
            }
        """))
        #expect(!output.contains("        Task { @MainActor in"))
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
            coreData: true,
            lumiKit: true,
            macCatalyst: true,
            deepLinks: true,
            spotlight: true,
            cloudKitSharing: true,
            deferredLaunchWork: true,
            notifications: true,
            tabs: [TabDefinition(name: "Home", icon: "house")]
        ))
        // Each import should appear exactly once
        let uikitOccurrences = output.components(separatedBy: "import UIKit").count - 1
        #expect(uikitOccurrences == 1)
        let cloudKitOccurrences = output.components(separatedBy: "import CloudKit").count - 1
        #expect(cloudKitOccurrences == 1)
        let imports = output.split(separator: "\n").filter { $0.hasPrefix("import ") }
        #expect(imports == imports.sorted { $0.lowercased() < $1.lowercased() })
        // One activation handler flushes everything that waited for the UI.
        #expect(output.components(separatedBy: "func sceneDidBecomeActive").count - 1 == 1)
        #expect(output.components(separatedBy: "func sceneDidDisconnect").count - 1 == 1)
    }

    // MARK: - State restoration

    @Test
    func `tabbed scene saves and restores the selected tab`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig(tabs: [TabDefinition(name: "Home", icon: "house")]))
        #expect(output.contains("    private static let restorationActivityType = \"com.test.app.restoration\""))
        #expect(output.contains("    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {"))
        #expect(output.contains("activity.addUserInfoEntries(from: [Self.selectedTabKey: tag.identifier])"))
        // The restored tab is selected before the root becomes the window's root.
        guard let restore = output.range(of: "rootVC.selectTab(for: tag)"),
              let install = output.range(of: "window.rootViewController = rootVC")
        else {
            Issue.record("missing restoration in willConnectTo")
            return
        }
        #expect(restore.lowerBound < install.lowerBound)
        #expect(output.contains("session.stateRestorationActivity?.userInfo?[Self.selectedTabKey] as? String"))
    }

    @Test
    func `tab-less scene has no state restoration`() {
        let output = SceneDelegateGenerator.generate(config: makeConfig())
        #expect(!output.contains("stateRestorationActivity"))
    }
}
