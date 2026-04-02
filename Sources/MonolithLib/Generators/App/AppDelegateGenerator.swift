import Foundation

enum AppDelegateGenerator {
    static func generate(config: AppConfig) -> String {
        var lines: [String] = []

        if config.hasLumiKit {
            lines.append("import LumiKitUI")
        }
        if config.hasSwiftData {
            lines.append("import SwiftData")
        }
        lines.append("import UIKit")
        lines.append("")

        lines.append("@main")
        lines.append("class AppDelegate: UIResponder, UIApplicationDelegate {")

        lines.addMark("Properties")
        if config.hasSwiftData {
            lines.append("    var modelContainer: ModelContainer?")
            lines.append("")
        }

        lines.addMark("Application Lifecycle")
        lines.append("""
            func application(
                _ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
            ) -> Bool {
        """)

        // Phase 1: Core Infrastructure
        lines.append("        // Phase 1: Core Infrastructure")
        if config.hasLumiKit {
            lines.append("        configureLumiKit()")
        }
        if config.hasSwiftData {
            lines.append("        modelContainer = createModelContainer()")
        }
        lines.append("")

        // Phase 2: System Services
        lines.append("        // Phase 2: System Services")
        lines.append("        setupMemoryWarningObserver()")
        lines.append("")

        // Phase 3: Configuration
        lines.append("        // Phase 3: Configuration")
        lines.append("        // Add migration or cache setup here")
        lines.append("")

        // Phase 4: Deferred Work
        lines.append("""
                // Phase 4: Deferred Work
                deferPostLaunchWork()

                return true
            }

        """)

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
            lines.addMark("Mac Catalyst Menu")
            lines.append("""
                #if targetEnvironment(macCatalyst)
                override func buildMenu(with builder: any UIMenuBuilder) {
                    super.buildMenu(with: builder)
                    guard builder.system == .main else { return }

                    let refreshCommand = UIKeyCommand(
                        title: "Refresh",
                        action: #selector(handleRefreshMenu),
                        input: "r",
                        modifierFlags: .command
                    )

            """)
            lines.append("        let menu = UIMenu(title: \"\(config.name)\", children: [refreshCommand])")
            lines.append("""
                    builder.insertSibling(menu, afterMenu: .view)
                }

                @objc private func handleRefreshMenu() {
                    NotificationCenter.default.post(name: AppNotification.macMenuRefresh, object: nil)
                }
                #endif
            """)
        }

        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }
}
