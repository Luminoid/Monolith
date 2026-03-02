import Foundation

enum SceneDelegateGenerator {

    static func generate(config: AppConfig) -> String {
        var lines: [String] = []

        lines.append("import UIKit")
        if config.hasSwiftData {
            lines.append("import SwiftData")
        }
        lines.append("")

        lines.append("class SceneDelegate: UIResponder, UIWindowSceneDelegate {")
        lines.append("")
        lines.append("    // MARK: - Properties")
        lines.append("")
        lines.append("    var window: UIWindow?")
        lines.append("")

        // MARK: - Scene Lifecycle
        lines.append("    // MARK: - Scene Lifecycle")
        lines.append("")
        lines.append("    func scene(")
        lines.append("        _ scene: UIScene,")
        lines.append("        willConnectTo session: UISceneSession,")
        lines.append("        options connectionOptions: UIScene.ConnectionOptions")
        lines.append("    ) {")
        lines.append("        guard let windowScene = (scene as? UIWindowScene) else { return }")
        lines.append("")

        if config.hasMacCatalyst {
            lines.append("        configureMacWindowIfNeeded(windowScene)")
            lines.append("")
        }

        if config.hasSwiftData {
            lines.append("        guard let modelContainer = (UIApplication.shared.delegate as? AppDelegate)?.modelContainer else {")
            lines.append("            return")
            lines.append("        }")
            lines.append("")
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

        // Mac Catalyst window config
        if config.hasMacCatalyst {
            lines.append("")
            lines.append("    // MARK: - Mac Catalyst")
            lines.append("")
            lines.append("    #if targetEnvironment(macCatalyst)")
            lines.append("    private func configureMacWindowIfNeeded(_ windowScene: UIWindowScene) {")
            lines.append("        if let titlebar = windowScene.titlebar {")
            lines.append("            titlebar.titleVisibility = .hidden")
            lines.append("            titlebar.toolbar = nil")
            lines.append("        }")
            lines.append("        windowScene.sizeRestrictions?.minimumSize = CGSize(width: 600, height: 800)")
            lines.append("        windowScene.sizeRestrictions?.maximumSize = CGSize(width: 1200, height: 1500)")
            lines.append("    }")
            lines.append("    #else")
            lines.append("    private func configureMacWindowIfNeeded(_ windowScene: UIWindowScene) {}")
            lines.append("    #endif")
        }

        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }
}
