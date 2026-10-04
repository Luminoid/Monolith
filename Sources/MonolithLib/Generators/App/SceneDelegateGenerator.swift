import Foundation

/// Generates `SceneDelegate.swift`.
///
/// The base output sets up the window and root view controller. Optional
/// sections are appended when the corresponding feature flag is set:
///
/// - `hasMacCatalyst`: Mac window configuration
/// - `hasSwiftData`: pulls the ModelContainer from the AppDelegate
/// - `hasTabs`: instantiates the tab bar controller as root
/// - `hasDeepLinks`: deep-link stubs (`willConnectTo` + `openURLContexts`)
/// - `hasSpotlight`: NSUserActivity / Spotlight handler stub
/// - `hasCloudKitSharing`: `userDidAcceptCloudKitShareWith` handler
/// - `hasDeferredLaunchWork`: emits a `deferLaunchWork()` helper called from
///   `sceneDidBecomeActive` (Spotlight reindex, widget refresh, etc.)
enum SceneDelegateGenerator {
    static func generate(config: AppConfig) -> String {
        var lines: [String] = []

        // Imports
        lines.append(contentsOf: imports(config: config))
        lines.append("")

        // `final` satisfies SwiftFormat's `preferFinalClasses` and matches the
        // shipped Plantfolio/Petfolio convention.
        if config.hasDeepLinks {
            lines.append("""
            final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
                // MARK: - Properties

                var window: UIWindow?
                private var pendingDeepLink: URL?
            """)
        } else {
            lines.append("""
            final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
                // MARK: - Properties

                var window: UIWindow?
            """)
        }
        lines.append("")

        // willConnectTo
        lines.addMark("Scene Lifecycle")
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

        // SwiftData container handoff. AppDelegate's `modelContainer` is now
        // non-optional (it `fatalError`s on init failure per the workspace
        // lessons), so the historical no-tabs `guard != nil` defensive check
        // is dropped — it would be dead code. The tabs path still binds the
        // container locally because `MainTabBarController(modelContainer:)`
        // consumes it directly; the `as?` chain unavoidably re-wraps in an
        // Optional, so the `guard let` form stays.
        if config.hasSwiftData, config.hasTabs {
            lines.append("""
                    guard let modelContainer = (UIApplication.shared.delegate as? AppDelegate)?.modelContainer else {
                        return
                    }

            """)
        }

        lines.append("        let window = UIWindow(windowScene: windowScene)")
        lines.append("        self.window = window")
        lines.append("")

        if config.hasTabs {
            if config.hasSwiftData {
                lines.append("        let rootVC = MainTabBarController(modelContainer: modelContainer)")
            } else {
                lines.append("        let rootVC = MainTabBarController()")
            }
        } else {
            lines.append("        let rootVC = ViewController()")
        }

        if config.hasTabs {
            // The tab bar controller is the root: it wraps each tab in its own
            // navigation controller, so a navigation controller around it would
            // stack an empty bar above every tab's bar.
            lines.append("        window.rootViewController = rootVC")
        } else {
            let navWrapper = config.hasLumiKit ? "LMKNavigationController" : "UINavigationController"
            lines.append("        window.rootViewController = \(navWrapper)(rootViewController: rootVC)")
        }
        lines.append("        window.makeKeyAndVisible()")

        if config.hasDeepLinks {
            lines.append("")
            lines.append("        // Capture an inbound deep-link URL for handling once the UI is ready.")
            lines.append("        if let url = connectionOptions.urlContexts.first?.url {")
            lines.append("            pendingDeepLink = url")
            lines.append("        }")
        }

        if config.hasSpotlight {
            lines.append("")
            lines.append("        // Capture inbound Spotlight activity.")
            lines.append("        for activity in connectionOptions.userActivities")
            lines.append("            where activity.activityType == CSSearchableItemActionType {")
            lines.append("            handleSpotlightActivity(activity)")
            lines.append("        }")
        }

        lines.append("    }")

        // sceneDidBecomeActive
        if config.hasDeferredLaunchWork || config.hasDeepLinks {
            lines.append("")
            lines.append("    func sceneDidBecomeActive(_ scene: UIScene) {")
            if config.hasDeferredLaunchWork {
                lines.append("        deferLaunchWork()")
            }
            if config.hasDeepLinks {
                lines.append("        if let url = pendingDeepLink {")
                lines.append("            handleDeepLink(url)")
                lines.append("            pendingDeepLink = nil")
                lines.append("        }")
            }
            lines.append("    }")
        }

        // Deep link handler
        if config.hasDeepLinks {
            lines.addMark("Deep Links")
            lines.append("""
                func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
                    guard let url = URLContexts.first?.url else { return }
                    handleDeepLink(url)
                }

                private func handleDeepLink(_ url: URL) {
                    // Parse `url` and route to the appropriate VC. Example:
                    // NotificationCenter.default.post(name: AppNotification.deepLinkReceived, object: url)
                }
            """)
        }

        // Spotlight
        if config.hasSpotlight {
            lines.addMark("Spotlight")
            lines.append("""
                func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
                    if userActivity.activityType == CSSearchableItemActionType {
                        handleSpotlightActivity(userActivity)
                    }
                }

                private func handleSpotlightActivity(_ activity: NSUserActivity) {
                    guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }
                    NotificationCenter.default.post(
                        name: AppNotification.spotlightItemSelected,
                        object: identifier
                    )
                }
            """)
        }

        // CloudKit sharing
        if config.hasCloudKitSharing {
            lines.addMark("CloudKit Sharing")
            lines.append(cloudKitShareHandler(config: config))
        }

        // Deferred launch work
        if config.hasDeferredLaunchWork {
            lines.addMark("Deferred Launch Work")
            lines.append("""
                private func deferLaunchWork() {
                    Task { @MainActor in
                        // Non-blocking startup work (Spotlight reindex, widget refresh,
                        // background sync coordination, etc.). Runs each time the scene
                        // becomes active; gate with a flag if you only want it on cold launch.
                    }
                }
            """)
        }

        if config.hasMacCatalyst, config.hasLumiKit {
            lines.addMark("Mac Catalyst")
            lines.append(lumiKitMacWindowConfiguration)
        } else if config.hasMacCatalyst {
            lines.addMark("Mac Catalyst")
            // Delegate to the dedicated `MacWindowConfig` enum (sole owner of the
            // window-config recipe). Inlining `windowScene.sizeRestrictions?.minimumSize
            // = CGSize(width: 600, height: 800)` here was the third copy of the
            // same magic-number set in the workspace (AppConstants + MacWindowConfig
            // + the inline body) and violated the no-magic-numbers rule. The empty
            // `#else` no-op preserves the call-site symmetry so non-Mac builds
            // compile without a `#if targetEnvironment(macCatalyst)` at every
            // call site.
            lines.append("""
                #if targetEnvironment(macCatalyst)
                    private func configureMacWindowIfNeeded(_ windowScene: UIWindowScene) {
                        MacWindowConfig.configure(windowScene)
                    }
                #else
                    private func configureMacWindowIfNeeded(_ windowScene: UIWindowScene) {}
                #endif
            """)
        }

        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    /// The Mac window setup for a LumiKit app: `LMKScene.configureMacWindow`, a
    /// no-op off Mac Catalyst, reading the bounds from `AppConstants.MacWindow`
    /// (no `MacWindowConfig.swift` is generated alongside it). The app runs in
    /// the scaled iPad idiom, where navigation bars stay in the window, so the
    /// title bar can hide; under the Mac idiom the bar's title and back button
    /// live in the window toolbar, hence the comment on `hidesTitleBar`.
    private static let lumiKitMacWindowConfiguration = """
        /// Window size limits and a hidden title bar on Mac Catalyst; a no-op on iOS and iPadOS.
        private func configureMacWindowIfNeeded(_ windowScene: UIWindowScene) {
            LMKScene.configureMacWindow(
                for: windowScene,
                minimumSize: CGSize(width: AppConstants.MacWindow.minWidth, height: AppConstants.MacWindow.minHeight),
                maximumSize: CGSize(width: AppConstants.MacWindow.maxWidth, height: AppConstants.MacWindow.maxHeight),
                // The app runs in the scaled iPad idiom, where navigation bars stay in the
                // window. Pass `false` if it moves to the Mac idiom (device family 6): there a
                // navigation bar's title and back button live in the window toolbar, and hiding
                // the title bar hides every screen's title.
                hidesTitleBar: true
            )
        }
    """

    /// The import lines, sorted the way SwiftFormat's case-insensitive `sortImports` orders them.
    private static func imports(config: AppConfig) -> [String] {
        var imports: [String] = []
        if config.hasCloudKitSharing {
            imports.append("import CloudKit")
        }
        if config.hasCloudKitSharing, config.hasCoreData {
            // The Core Data accept path calls NSPersistentCloudKitContainer's
            // acceptShareInvitations(from:into:) and references NSPersistentStore,
            // both defined in CoreData.
            imports.append("import CoreData")
        }
        if config.hasSpotlight {
            imports.append("import CoreSpotlight")
        }
        if config.hasLumiKit {
            // `LMKLogger` lives in LumiKitCore, which LumiKitUI does not
            // re-export; only the share-accept failure paths use it.
            if config.hasCloudKitSharing {
                imports.append("import LumiKitCore")
            }
            // Needed for `LMKNavigationController` (the root of a tab-less app)
            // and `LMKScene` (the Mac window) further down; without it those
            // lines fail with "cannot find ... in scope". A tabbed iPhone/iPad
            // app's scene names neither: its root is the tab bar controller.
            if !config.hasTabs || config.hasMacCatalyst {
                imports.append("import LumiKitUI")
            }
        } else if config.hasCloudKitSharing {
            // `os.Logger` for the share-accept failure paths.
            imports.append("import os")
        }
        if config.hasSwiftData, config.hasTabs {
            // SwiftData is only referenced from the scene when we hand a
            // `ModelContainer` to `MainTabBarController(modelContainer:)`.
            // The no-tabs path doesn't touch the container directly anymore
            // (the AppDelegate keeps it as a property; no scene-side handoff).
            imports.append("import SwiftData")
        }
        imports.append("import UIKit")
        return imports
    }

    /// The `userDidAcceptCloudKitShareWith` handler. Core Data must import the
    /// accepted share into its shared store via `acceptShareInvitations(from:into:)`
    /// (a raw `CKContainer.accept()` accepts at the CloudKit layer but never
    /// materializes records into the persistent container's shared store). The
    /// raw-accept path is the SwiftData fallback, which has no shared store.
    private static func cloudKitShareHandler(config: AppConfig) -> String {
        let acceptFailureLine = AppDelegateGenerator.logError("Failed to accept CloudKit share", category: .network, config: config)
        if config.hasCoreData {
            let noStoreLine = AppDelegateGenerator.logError(
                "No shared store available to accept CloudKit share",
                category: .data,
                config: config,
                includesError: false
            )
            return """
                func windowScene(
                    _ windowScene: UIWindowScene,
                    userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
                ) {
                    Task { @MainActor in
                        let stack = \(config.name)CoreDataStack.shared
                        guard let sharedStore = stack.sharedStore else {
                            \(noStoreLine)
                            return
                        }
                        do {
                            try await stack.container.acceptShareInvitations(
                                from: [cloudKitShareMetadata],
                                into: sharedStore
                            )
                        } catch {
                            \(acceptFailureLine)
                        }
                    }
                }
            """
        }
        return """
            func windowScene(
                _ windowScene: UIWindowScene,
                userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
            ) {
                let container = CKContainer(identifier: cloudKitShareMetadata.containerIdentifier)
                container.accept(cloudKitShareMetadata) { _, error in
                    if let error {
                        \(acceptFailureLine)
                    }
                }
            }
        """
    }
}
