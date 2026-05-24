import Foundation

/// Generates the app's `AppDelegate.swift`.
///
/// The generated delegate is feature-driven: SwiftData, Core Data, CloudKit
/// remote notifications, `UNUserNotificationCenterDelegate`, and Mac Catalyst
/// menu scaffolding are each emitted only when the corresponding feature flag
/// is set. The four-phase launch comment structure (Core Infrastructure /
/// System Services / Configuration / Deferred Work) is preserved as a guide
/// for adopters extending the delegate.
enum AppDelegateGenerator {
    static func generate(config: AppConfig) -> String {
        var lines: [String] = []

        // Imports
        if config.hasCoreData {
            lines.append("import CoreData")
        }
        if config.hasLumiKit {
            lines.append("import LumiKitUI")
        }
        if config.hasSwiftData {
            lines.append("import SwiftData")
        }
        lines.append("import UIKit")
        if config.hasNotifications {
            lines.append("import UserNotifications")
        }
        lines.append("")

        // Class declaration + base conformance
        var conformances = ["UIResponder", "UIApplicationDelegate"]
        if config.hasNotifications {
            conformances.append("UNUserNotificationCenterDelegate")
        }
        lines.append("@main")
        // `final` matches Plantfolio/Petfolio and satisfies SwiftFormat's
        // `preferFinalClasses`. Subclassing AppDelegate isn't needed for any
        // pattern Monolith supports today.
        lines.append("final class AppDelegate: \(conformances.joined(separator: ", ")) {")

        // Properties — only emit the MARK section when there's at least one
        // stored property to declare. An empty `// MARK: - Properties` block
        // is dead scaffolding that adopters either delete (noise in their
        // first commit) or leave (lint warnings on unused MARK sections).
        if config.hasSwiftData {
            lines.addMark("Properties")
            lines.append("    var modelContainer: ModelContainer?")
        }

        // didFinishLaunching
        lines.addMark("Application Lifecycle")
        lines.append("""
            func application(
                _ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
            ) -> Bool {
        """)
        lines.append("        // Phase 1: Core Infrastructure")
        if config.hasLumiKit {
            lines.append("        configureLumiKit()")
        }
        if config.hasSwiftData {
            lines.append("        modelContainer = createModelContainer()")
        }
        if config.hasCoreData {
            lines.append("        _ = \(config.name)CoreDataStack.shared")
        }
        lines.append("")
        lines.append("        // Phase 2: System Services")
        lines.append("        setupMemoryWarningObserver()")
        if config.hasNotifications {
            lines.append("        UNUserNotificationCenter.current().delegate = self")
        }
        if config.hasCloudKitNotifications {
            lines.append("        application.registerForRemoteNotifications()")
        }
        lines.append("")
        lines.append("        // Phase 3: Configuration")
        lines.append("        // Add migration or cache setup here")
        lines.append("")
        lines.append("""
                // Phase 4: Deferred Work
                deferPostLaunchWork()

                return true
            }

        """)

        // configurationForConnecting
        lines.addMark("Scene Configuration")
        lines.append("""
            func application(
                _ application: UIApplication,
                configurationForConnecting connectingSceneSession: UISceneSession,
                options: UIScene.ConnectionOptions
            ) -> UISceneConfiguration {
                UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
            }

        """)

        // Remote notifications (CloudKit silent push)
        if config.hasCloudKitNotifications {
            lines.addMark("Remote Notifications")
            lines.append("""
                func application(
                    _ application: UIApplication,
                    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
                ) {
                    // CloudKit silent pushes don't need the token; this delegate just confirms registration.
                }

                func application(
                    _ application: UIApplication,
                    didFailToRegisterForRemoteNotificationsWithError error: any Error
                ) {
                    print("Remote notification registration failed: \\(error)")
                }

            """)
        }

        // UNUserNotificationCenterDelegate
        if config.hasNotifications {
            lines.addMark("User Notifications")
            lines.append("""
                func userNotificationCenter(
                    _ center: UNUserNotificationCenter,
                    willPresent notification: UNNotification,
                    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
                ) {
                    // Show banner + list + sound when the app is foreground; default is to suppress.
                    completionHandler([.banner, .list, .sound])
                }

                func userNotificationCenter(
                    _ center: UNUserNotificationCenter,
                    didReceive response: UNNotificationResponse,
                    withCompletionHandler completionHandler: @escaping () -> Void
                ) {
                    NotificationCenter.default.post(
                        name: AppNotification.userNotificationReceived,
                        object: response.notification
                    )
                    completionHandler()
                }

            """)
        }

        if config.hasLumiKit {
            lines.addMark("LumiKit Configuration")
            lines.append("    private func configureLumiKit() {")
            lines.append("        let theme = \(config.name)Theme()")
            lines.append("        LMKThemeManager.shared.apply(theme)")
            lines.append("    }")
            lines.append("")
        }

        if config.hasSwiftData {
            lines.addMark("SwiftData")
            lines.append("""
                private func createModelContainer() -> ModelContainer? {
                    do {
                        let schema = Schema([
                            // Add your @Model types here
                        ])
                        let config = ModelConfiguration(schema: schema)
                        return try ModelContainer(for: schema, configurations: [config])
                    } catch {
                        print("Failed to create ModelContainer: \\(error)")
                        return nil
                    }
                }

            """)
        }

        lines.addMark("Memory Warning")
        lines.append("""
            private func setupMemoryWarningObserver() {
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(handleMemoryWarning),
                    name: UIApplication.didReceiveMemoryWarningNotification,
                    object: nil
                )
            }

            @objc private func handleMemoryWarning(_ notification: Notification) {
                NotificationCenter.default.post(name: AppNotification.memoryWarningReceived, object: nil)
            }

        """)

        lines.addMark("Deferred Work")
        lines.append("""
            private func deferPostLaunchWork() {
                Task { @MainActor in
                    // Perform non-blocking post-launch work here
                }
            }
        """)

        if config.hasMacCatalyst {
            lines.append("")
            lines.append(macCatalystMenu(config: config))
        }

        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    // MARK: - Mac Catalyst Menu

    /// Generates an `override func buildMenu(with:)` block.
    /// The default ⌘R Refresh command is always emitted. When tabs are
    /// declared, ⌘1…⌘N commands for tab switching are appended.
    /// Adopters insert further commands via `buildMenu` overrides in their own
    /// code; this scaffold avoids hardcoding domain-specific actions.
    private static func macCatalystMenu(config: AppConfig) -> String {
        var lines: [String] = []
        lines.append("    // MARK: - Mac Catalyst Menu")
        lines.append("")
        lines.append("    #if targetEnvironment(macCatalyst)")
        lines.append("    override func buildMenu(with builder: any UIMenuBuilder) {")
        lines.append("        super.buildMenu(with: builder)")
        lines.append("        guard builder.system == .main else { return }")
        lines.append("")
        lines.append("        let refreshCommand = UIKeyCommand(")
        lines.append("            title: \"Refresh\",")
        lines.append("            action: #selector(handleRefreshMenu),")
        lines.append("            input: \"r\",")
        lines.append("            modifierFlags: .command")
        lines.append("        )")

        if config.hasTabs {
            lines.append("")
            lines.append("        let tabCommands: [UIKeyCommand] = [")
            for (index, tab) in config.tabs.prefix(9).enumerated() {
                let shortcut = index + 1
                lines.append("            UIKeyCommand(title: \"\(tab.name)\", action: #selector(handleTabMenu(_:)), input: \"\(shortcut)\", modifierFlags: .command, propertyList: \(index)),")
            }
            lines.append("        ]")
            lines.append("        let tabMenu = UIMenu(title: \"Tabs\", options: .displayInline, children: tabCommands)")
            lines.append("")
            lines.append("        let appMenu = UIMenu(title: \"\(config.name)\", children: [refreshCommand, tabMenu])")
        } else {
            lines.append("")
            lines.append("        let appMenu = UIMenu(title: \"\(config.name)\", children: [refreshCommand])")
        }

        lines.append("        builder.insertSibling(appMenu, afterMenu: .view)")
        lines.append("    }")
        lines.append("")
        lines.append("    @objc private func handleRefreshMenu() {")
        lines.append("        NotificationCenter.default.post(name: AppNotification.macMenuRefresh, object: nil)")
        lines.append("    }")

        if config.hasTabs {
            lines.append("")
            lines.append("    @objc private func handleTabMenu(_ sender: UIKeyCommand) {")
            lines.append("        guard let index = sender.propertyList as? Int else { return }")
            lines.append("        NotificationCenter.default.post(name: AppNotification.macMenuSwitchTab, object: index)")
            lines.append("    }")
        }

        lines.append("    #endif")
        return lines.joined(separator: "\n")
    }
}
