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
        if config.hasCloudKitSharing {
            lines.append("import CloudKit")
        }
        if config.hasCloudKitSharing, config.hasCoreData {
            // The Core Data accept path calls NSPersistentCloudKitContainer's
            // acceptShareInvitations(from:into:) and references NSPersistentStore,
            // both defined in CoreData.
            lines.append("import CoreData")
        }
        if config.hasSpotlight {
            lines.append("import CoreSpotlight")
        }
        if config.hasLumiKit {
            // Needed for `LMKNavigationController` further down — without this
            // import the rootViewController line below fails with "cannot find
            // 'LMKNavigationController' in scope".
            lines.append("import LumiKitUI")
        }
        if config.hasSwiftData, config.hasTabs {
            // SwiftData is only referenced from the scene when we hand a
            // `ModelContainer` to `MainTabBarController(modelContainer:)`.
            // The no-tabs path doesn't touch the container directly anymore
            // (the AppDelegate keeps it as a property; no scene-side handoff).
            lines.append("import SwiftData")
        }
        lines.append("import UIKit")
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

        let navWrapper = config.hasLumiKit ? "LMKNavigationController" : "UINavigationController"
        lines.append("        window.rootViewController = \(navWrapper)(rootViewController: rootVC)")
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

        if config.hasMacCatalyst {
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

    /// The `userDidAcceptCloudKitShareWith` handler. Core Data must import the
    /// accepted share into its shared store via `acceptShareInvitations(from:into:)`
    /// (a raw `CKContainer.accept()` accepts at the CloudKit layer but never
    /// materializes records into the persistent container's shared store). The
    /// raw-accept path is the SwiftData fallback, which has no shared store.
    private static func cloudKitShareHandler(config: AppConfig) -> String {
        if config.hasCoreData {
            return """
                func windowScene(
                    _ windowScene: UIWindowScene,
                    userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
                ) {
                    Task { @MainActor in
                        let stack = \(config.name)CoreDataStack.shared
                        guard let sharedStore = stack.sharedStore else {
                            print("No shared store available to accept CloudKit share")
                            return
                        }
                        do {
                            try await stack.container.acceptShareInvitations(
                                from: [cloudKitShareMetadata],
                                into: sharedStore
                            )
                        } catch {
                            print("Failed to accept CloudKit share: \\(error)")
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
                        print("Failed to accept CloudKit share: \\(error)")
                    }
                }
            }
        """
    }
}
