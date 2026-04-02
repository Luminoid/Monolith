import Foundation

enum SceneDelegateGenerator {
    static func generate(config: AppConfig) -> String {
        var lines: [String] = []

        if config.hasSwiftData {
            lines.append("import SwiftData")
        }
        lines.append("import UIKit")
        lines.append("")

        lines.append("""
        class SceneDelegate: UIResponder, UIWindowSceneDelegate {
            // MARK: - Properties

            var window: UIWindow?

        """)

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

        if config.hasTabs {
            if config.hasSwiftData {
                lines.append("        let rootVC = MainTabBarController(modelContainer: modelContainer)")
            } else {
                lines.append("        let rootVC = MainTabBarController()")
            }
        } else {
            lines.append("        let rootVC = ViewController()")
        }
        lines.append("        window.rootViewController = UINavigationController(rootViewController: rootVC)")
        lines.append("        window.makeKeyAndVisible()")
        lines.append("    }")

        if config.hasMacCatalyst {
            lines.addMark("Mac Catalyst")
            lines.append("""
                #if targetEnvironment(macCatalyst)
                private func configureMacWindowIfNeeded(_ windowScene: UIWindowScene) {
                    if let titlebar = windowScene.titlebar {
                        titlebar.titleVisibility = .hidden
                        titlebar.toolbar = nil
                    }
                    windowScene.sizeRestrictions?.minimumSize = CGSize(width: 600, height: 800)
                    windowScene.sizeRestrictions?.maximumSize = CGSize(width: 1200, height: 1500)
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
}
