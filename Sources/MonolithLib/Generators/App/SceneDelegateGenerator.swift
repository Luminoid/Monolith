import Foundation

/// Generates `SceneDelegate.swift`.
///
/// The base output sets up the window and root view controller. Optional
/// sections are appended when the corresponding feature flag is set:
///
/// - `hasMacCatalyst`: Mac window configuration
/// - `hasSwiftData`: hands the AppDelegate's ModelContainer to the root
/// - `hasTabs`: the tab bar controller as root, with state restoration of the
///   selected tab
/// - `hasDeepLinks` / `hasSpotlight` / `hasNotifications`: routing stubs. What
///   arrives before the UI is up (a link, result, or tap that launched the app)
///   is held and flushed in `sceneDidBecomeActive`, then routed through the
///   root view controller. A broadcast at that point would reach no observer:
///   tab roots are built on first selection.
/// - Core Data `cloudKitSharing`: share acceptance, from both the
///   already-connected callback and a cold launch's connection options
/// - `hasDeferredLaunchWork`: post-launch work run once per process, after the
///   first activation
enum SceneDelegateGenerator {
    static func generate(config: AppConfig) -> String {
        var lines: [String] = []

        lines.append(contentsOf: imports(config: config))
        lines.append("")

        // `final` satisfies SwiftFormat's `preferFinalClasses`.
        lines.append("final class SceneDelegate: UIResponder, UIWindowSceneDelegate {")
        lines.append(contentsOf: properties(config: config))

        lines.addMark("Scene Lifecycle")
        lines.append(contentsOf: willConnect(config: config))
        lines.append(contentsOf: activationHandlers(config: config))

        if config.hasTabs {
            lines.addMark("State Restoration")
            lines.append("""
                /// Saves the selected tab with the scene's session; `scene(_:willConnectTo:options:)`
                /// reselects it when the system restores the scene.
                func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
                    guard let tag = (window?.rootViewController as? MainTabBarController)?.selectedTabTag else { return nil }
                    let activity = NSUserActivity(activityType: Self.restorationActivityType)
                    activity.addUserInfoEntries(from: [Self.selectedTabKey: tag.identifier])
                    return activity
                }
            """)
        }

        if config.hasDeepLinks {
            lines.addMark("Deep Links")
            lines.append("""
                func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
                    guard let url = URLContexts.first?.url else { return }
                    handleDeepLink(url)
                }

                private func handleDeepLink(_ url: URL) {
                    // Parse `url` and route through the root view controller, for example:
                    // \(routeExample(config: config))
                }
            """)
        }

        if config.hasSpotlight {
            lines.addMark("Spotlight")
            lines.append(spotlightHandlers(config: config))
        }

        if config.hasNotifications {
            lines.addMark("Notifications")
            lines.append(notificationHandlers(config: config))
        }

        if AppConstantsGenerator.hasCoreDataSharing(config: config) {
            lines.addMark("CloudKit Sharing")
            lines.append(cloudKitShareHandler(config: config))
        }

        if config.hasDeferredLaunchWork {
            lines.addMark("Deferred Launch Work")
            lines.append("""
                /// Starts post-launch work once per process: on the first activation, not on every
                /// app switch or window focus, and two seconds in so the first frames render first.
                private func deferLaunchWork() {
                    guard !Self.didRunLaunchWork else { return }
                    Self.didRunLaunchWork = true
                    launchWorkTask = Task { @MainActor in
                        try? await Task.sleep(for: .seconds(2))
                        guard !Task.isCancelled else { return }
                        // Main-actor bookkeeping goes here (scheduling a Spotlight reindex, reloading
                        // widget timelines). Heavy work belongs off the main actor, in a detached
                        // task: Task.detached(priority: .utility) { ... }
                    }
                }
            """)
        }

        if config.hasMacCatalyst {
            lines.addMark("Mac Catalyst")
            lines.append(config.hasLumiKit ? lumiKitMacWindowConfiguration : macWindowConfiguration)
        }

        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    // MARK: - Sections

    /// The import lines, sorted the way SwiftFormat's case-insensitive `sortImports` orders them.
    private static func imports(config: AppConfig) -> [String] {
        let sharing = AppConstantsGenerator.hasCoreDataSharing(config: config)
        var imports: [String] = []
        if sharing {
            // `CKShare.Metadata`, plus NSPersistentCloudKitContainer's
            // `acceptShareInvitations(from:into:)` and `NSPersistentStore`
            // from CoreData.
            imports.append("import CloudKit")
            imports.append("import CoreData")
        }
        if config.hasSpotlight {
            imports.append("import CoreSpotlight")
        }
        if config.hasLumiKit {
            // `LMKLogger` lives in LumiKitCore, which LumiKitUI does not
            // re-export; only the share-accept failure paths use it.
            if sharing {
                imports.append("import LumiKitCore")
            }
            // `LMKNavigationController` (the root of a tab-less app),
            // `LMKScene` (the Mac window), and `LMKErrorHandler` (share
            // acceptance) live in LumiKitUI. A tabbed iPhone/iPad app's scene
            // may name none of them: its root is the tab bar controller.
            if !config.hasTabs || config.hasMacCatalyst || sharing {
                imports.append("import LumiKitUI")
            }
        } else if sharing {
            // `Logger.app` for the share-accept failure paths.
            imports.append("import os")
        }
        if config.hasSwiftData {
            // The scene hands the AppDelegate's `ModelContainer` to the root.
            imports.append("import SwiftData")
        }
        imports.append("import UIKit")
        if config.hasNotifications {
            imports.append("import UserNotifications")
        }
        return imports
    }

    /// The stored properties and constants.
    private static func properties(config: AppConfig) -> [String] {
        var lines: [String] = []
        lines.addMark("Properties")
        lines.append("    var window: UIWindow?")
        if config.hasDeepLinks || config.hasSpotlight || config.hasNotifications {
            lines.append("    /// What arrives before the UI is up waits for `sceneDidBecomeActive`.")
        }
        if config.hasDeepLinks {
            lines.append("    private var pendingDeepLink: URL?")
        }
        if config.hasSpotlight {
            lines.append("    private var pendingSpotlightIdentifier: String?")
        }
        if config.hasNotifications {
            lines.append("    private var pendingNotificationResponse: UNNotificationResponse?")
        }
        if AppConstantsGenerator.hasCoreDataSharing(config: config) {
            lines.append("    private var shareAcceptTask: Task<Void, Never>?")
        }
        if config.hasDeferredLaunchWork {
            lines.append("    private var launchWorkTask: Task<Void, Never>?")
            lines.append("    /// Deferred launch work runs once per process, not once per scene activation.")
            lines.append("    private static var didRunLaunchWork = false")
        }
        if config.hasTabs {
            lines.addMark("Constants")
            lines.append("""
                /// The user activity that carries the selected tab through state restoration.
                private static let restorationActivityType = "\(config.bundleID).restoration"
                private static let selectedTabKey = "selectedTab"
            """)
        }
        return lines
    }

    /// `scene(_:willConnectTo:options:)`: the window, the root view controller,
    /// and whatever the launch carried in its connection options.
    private static func willConnect(config: AppConfig) -> [String] {
        var lines: [String] = []
        lines.append("""
            func scene(
                _ scene: UIScene,
                willConnectTo session: UISceneSession,
                options connectionOptions: UIScene.ConnectionOptions
            ) {
                guard let windowScene = (scene as? UIWindowScene) else { return }

        """)

        if config.hasMacCatalyst {
            lines.append("        configureMacWindowIfNeeded(windowScene)")
            lines.append("")
        }

        // The AppDelegate's container is non-optional (its builder
        // `fatalError`s when even a local store fails); the `as?` chain
        // re-wraps it in an Optional, hence the `guard let`.
        if config.hasSwiftData {
            lines.append("""
                    guard let modelContainer = (UIApplication.shared.delegate as? AppDelegate)?.modelContainer else {
                        return
                    }

            """)
        }

        lines.append("        let window = UIWindow(windowScene: windowScene)")
        lines.append("        self.window = window")
        lines.append("")

        let containerArgument = config.hasSwiftData ? "modelContainer: modelContainer" : ""
        if config.hasTabs {
            lines.append("        let rootVC = MainTabBarController(\(containerArgument))")
            lines.append("""
                    // Reselect the tab the user left when the system restores this scene.
                    if let identifier = session.stateRestorationActivity?.userInfo?[Self.selectedTabKey] as? String,
                       let tag = TabBarTag(identifier: identifier) {
                        rootVC.selectTab(for: tag)
                    }
            """)
            // The tab bar controller is the root: it wraps each tab in its own
            // navigation controller, so a navigation controller around it would
            // stack an empty bar above every tab's bar.
            lines.append("        window.rootViewController = rootVC")
        } else {
            lines.append("        let rootVC = ViewController(\(containerArgument))")
            let navWrapper = config.hasLumiKit ? "LMKNavigationController" : "UINavigationController"
            lines.append("        window.rootViewController = \(navWrapper)(rootViewController: rootVC)")
        }
        lines.append("        window.makeKeyAndVisible()")

        if config.hasDeepLinks {
            lines.append("""

                    // Capture an inbound deep-link URL for handling once the UI is ready.
                    if let url = connectionOptions.urlContexts.first?.url {
                        pendingDeepLink = url
                    }
            """)
        }

        if config.hasSpotlight {
            lines.append("""

                    // A Spotlight result that launched the app opens once the UI is up.
                    if let activity = connectionOptions.userActivities.first(where: { $0.activityType == CSSearchableItemActionType }) {
                        handleSpotlightActivity(activity)
                    }
            """)
        }

        if AppConstantsGenerator.hasCoreDataSharing(config: config) {
            lines.append("""

                    // A share accepted from a cold launch arrives here. UIKit calls
                    // `windowScene(_:userDidAcceptCloudKitShareWith:)` only for a scene that is
                    // already connected.
                    if let metadata = connectionOptions.cloudKitShareMetadata {
                        acceptCloudKitShare(metadata)
                    }
            """)
        }

        lines.append("    }")
        return lines
    }

    /// `sceneDidBecomeActive` (flushes held routing work and starts the
    /// deferred launch work) and `sceneDidDisconnect` (cancels stored tasks).
    private static func activationHandlers(config: AppConfig) -> [String] {
        var lines: [String] = []
        var activeBody: [String] = []
        if config.hasDeferredLaunchWork {
            activeBody.append("        deferLaunchWork()")
        }
        if config.hasDeepLinks {
            activeBody.append("""
                    if let url = pendingDeepLink {
                        pendingDeepLink = nil
                        handleDeepLink(url)
                    }
            """)
        }
        if config.hasSpotlight {
            activeBody.append("""
                    if let identifier = pendingSpotlightIdentifier {
                        pendingSpotlightIdentifier = nil
                        showSpotlightItem(identifier)
                    }
            """)
        }
        if config.hasNotifications {
            activeBody.append("""
                    if let response = pendingNotificationResponse {
                        pendingNotificationResponse = nil
                        showNotification(response)
                    }
            """)
        }
        if !activeBody.isEmpty {
            lines.append("")
            lines.append("    func sceneDidBecomeActive(_ scene: UIScene) {")
            lines.append(contentsOf: activeBody)
            lines.append("    }")
        }

        var disconnectBody: [String] = []
        if config.hasDeferredLaunchWork {
            disconnectBody.append("        launchWorkTask?.cancel()")
        }
        if AppConstantsGenerator.hasCoreDataSharing(config: config) {
            disconnectBody.append("        shareAcceptTask?.cancel()")
        }
        if !disconnectBody.isEmpty {
            lines.append("")
            lines.append("    func sceneDidDisconnect(_ scene: UIScene) {")
            lines.append(contentsOf: disconnectBody)
            lines.append("    }")
        }
        return lines
    }

    /// A one-line example of routing through the app's root view controller,
    /// for the routing stubs' comments.
    private static func routeExample(config: AppConfig) -> String {
        guard let firstTab = config.tabs.first else {
            return "(window?.rootViewController as? UINavigationController)?.pushViewController(detail, animated: true)"
        }
        return "(window?.rootViewController as? MainTabBarController)?.selectTab(for: .\(AppConstantsGenerator.caseName(for: firstTab)))"
    }

    private static func spotlightHandlers(config: AppConfig) -> String {
        """
            func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
                if userActivity.activityType == CSSearchableItemActionType {
                    handleSpotlightActivity(userActivity)
                }
            }

            /// Opens a Spotlight result now, or once the UI is up when the result launched the app.
            private func handleSpotlightActivity(_ activity: NSUserActivity) {
                guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }
                guard window?.windowScene?.activationState == .foregroundActive else {
                    pendingSpotlightIdentifier = identifier
                    return
                }
                showSpotlightItem(identifier)
            }

            /// Shows the content behind a Spotlight result; `identifier` is the indexed item's
            /// `uniqueIdentifier`.
            private func showSpotlightItem(_ identifier: String) {
                // Look up the item and route through the root view controller, for example:
                // \(routeExample(config: config))
            }
        """
    }

    private static func notificationHandlers(config: AppConfig) -> String {
        """
            /// Called by the AppDelegate when the user taps a notification. A tap that launched the
            /// app waits for `sceneDidBecomeActive`, when the UI is up.
            func handleNotificationResponse(_ response: UNNotificationResponse) {
                guard window?.windowScene?.activationState == .foregroundActive else {
                    pendingNotificationResponse = response
                    return
                }
                showNotification(response)
            }

            /// Shows the content behind a tapped notification.
            private func showNotification(_ response: UNNotificationResponse) {
                // Read `response.notification.request.content.userInfo` and route through the root
                // view controller, for example:
                // \(routeExample(config: config))
            }
        """
    }

    /// The Core Data share-acceptance path. The accepted share is imported
    /// into the stack's shared store via `acceptShareInvitations(from:into:)`
    /// (a raw `CKContainer.accept()` accepts at the CloudKit layer but never
    /// materializes records into the persistent container). Accepts started
    /// from the already-connected callback and from a cold launch's connection
    /// options both go through `acceptCloudKitShare(_:)`, whose task is stored
    /// and cancelled when the scene disconnects. With sync off there is no
    /// shared store, so the scene posts a notification for the app to surface.
    private static func cloudKitShareHandler(config: AppConfig) -> String {
        let acceptFailureLine = AppDelegateGenerator.logError("Failed to accept CloudKit share", category: .network, config: config)
        let noStoreLine = AppDelegateGenerator.logError(
            "No shared store available to accept CloudKit share",
            category: .data,
            config: config,
            includesError: false
        )
        // With LumiKit the failure also reaches the user, through the root.
        let taskHeader = config.hasLumiKit ? "Task { @MainActor [weak self] in" : "Task { @MainActor in"
        let presentFailure = config.hasLumiKit
            ? """

                            if let host = self?.window?.rootViewController {
                                LMKErrorHandler.present(from: host, error: error)
                            }
            """
            : ""
        return """
            func windowScene(
                _ windowScene: UIWindowScene,
                userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
            ) {
                acceptCloudKitShare(cloudKitShareMetadata)
            }

            /// Imports an accepted share into the shared store, where its records appear.
            private func acceptCloudKitShare(_ metadata: CKShare.Metadata) {
                let stack = \(config.name)CoreDataStack.shared
                guard let sharedStore = stack.sharedStore else {
                    // Sync is off, so there is no shared store to import into. Observe this
                    // notification to ask the user to turn sync on.
                    \(noStoreLine)
                    NotificationCenter.default.post(name: AppNotification.cloudKitShareRequiresSync, object: nil)
                    return
                }
                shareAcceptTask = \(taskHeader)
                    do {
                        try await stack.container.acceptShareInvitations(from: [metadata], into: sharedStore)
                    } catch {
                        \(acceptFailureLine)\(presentFailure)
                    }
                }
            }
        """
    }

    /// The Mac window setup for a LumiKit app: `LMKScene.configureMacWindow`, a
    /// no-op off Mac Catalyst, reading the minimum size from
    /// `AppConstants.MacWindow` (no `MacWindowConfig.swift` is generated
    /// alongside it). No maximum: it would block full screen and wide window
    /// tiling. The app runs in the scaled iPad idiom, where navigation bars
    /// stay in the window, so the title bar can hide; under the Mac idiom the
    /// bar's title and back button live in the window toolbar, hence the
    /// comment on `hidesTitleBar`.
    private static let lumiKitMacWindowConfiguration = """
        /// A minimum window size and a hidden title bar on Mac Catalyst; a no-op on iOS and iPadOS.
        private func configureMacWindowIfNeeded(_ windowScene: UIWindowScene) {
            LMKScene.configureMacWindow(
                for: windowScene,
                minimumSize: CGSize(width: AppConstants.MacWindow.minWidth, height: AppConstants.MacWindow.minHeight),
                // No maximum, so full screen and wide window tiling keep working.
                maximumSize: nil,
                // The app runs in the scaled iPad idiom, where navigation bars stay in the
                // window. Pass `false` if it moves to the Mac idiom (device family 6): there a
                // navigation bar's title and back button live in the window toolbar, and hiding
                // the title bar hides every screen's title.
                hidesTitleBar: true
            )
        }
    """

    /// The Mac window setup without LumiKit: delegates to the generated
    /// `MacWindowConfig` enum, the sole owner of the window recipe, so the
    /// size constants live in one place. The empty `#else` keeps the call site
    /// free of its own `#if targetEnvironment(macCatalyst)`.
    private static let macWindowConfiguration = """
        #if targetEnvironment(macCatalyst)
            private func configureMacWindowIfNeeded(_ windowScene: UIWindowScene) {
                MacWindowConfig.configure(windowScene)
            }
        #else
            private func configureMacWindowIfNeeded(_ windowScene: UIWindowScene) {}
        #endif
    """
}
