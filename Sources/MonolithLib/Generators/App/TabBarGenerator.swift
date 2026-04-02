import Foundation

enum TabBarGenerator {
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

        lines.append("final class MainTabBarController: UITabBarController {")

        lines.addMark("Properties")

        if config.hasSwiftData {
            lines.append("    private let modelContainer: ModelContainer")
            lines.append("")
        }

        lines.append("    private var navControllers: [TabBarTag: UINavigationController] = [:]")
        lines.append("")

        lines.addMark("Initialization")

        if config.hasSwiftData {
            lines.append("""
                init(modelContainer: ModelContainer) {
                    self.modelContainer = modelContainer
                    super.init(nibName: nil, bundle: nil)
                }
            """)
        } else {
            lines.append("    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {")
            lines.append("        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)")
            lines.append("    }")
        }
        lines.append("")
        lines.append("""
            @available(*, unavailable)
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }

        """)

        lines.addMark("Lifecycle")
        lines.append("    override func viewDidLoad() {")
        lines.append("        super.viewDidLoad()")
        lines.append("")
        if config.hasLumiKit {
            lines.append("        tabBar.tintColor = LMKColor.primary")
        }
        lines.append("        buildTabs()")

        if config.hasMacCatalyst {
            lines.append("""

                    #if targetEnvironment(macCatalyst)
                    setupMacMenuHandlers()
                    #endif
            """)
        }

        lines.append("    }")
        lines.append("")

        lines.addMark("Setup")
        lines.append("    private func buildTabs() {")

        for tab in config.tabs {
            let caseName = tab.name.prefix(1).lowercased() + tab.name.dropFirst()
            lines.append("")
            lines.append("        let \(caseName)VC = \(tab.name)ViewController()")
            lines.append("        let \(caseName)Nav = UINavigationController(rootViewController: \(caseName)VC)")
            lines.append("        \(caseName)Nav.tabBarItem = UITabBarItem(")
            lines.append("            title: \"\(tab.name)\",")
            lines.append("            image: UIImage(systemName: \"\(tab.icon)\"),")
            lines.append("            tag: TabBarTag.\(caseName).rawValue")
            lines.append("        )")
            lines.append("        navControllers[.\(caseName)] = \(caseName)Nav")
        }

        lines.append("")
        let tabNames = config.tabs.map { tab in
            let caseName = tab.name.prefix(1).lowercased() + tab.name.dropFirst()
            return "\(caseName)Nav"
        }
        lines.append("        viewControllers = [\(tabNames.joined(separator: ", "))]")
        lines.append("    }")
        lines.append("")

        lines.addMark("Actions")
        lines.append("""
            func selectTab(for tag: TabBarTag) {
                guard let index = viewControllers?.firstIndex(where: { $0.tabBarItem.tag == tag.rawValue }) else { return }
                selectedIndex = index
            }
        """)

        if config.hasMacCatalyst {
            lines.addMark("Mac Catalyst")
            lines.append("""
                #if targetEnvironment(macCatalyst)
                private func setupMacMenuHandlers() {
                    NotificationCenter.default.addObserver(
                        self,
                        selector: #selector(handleMacMenuSwitchTab(_:)),
                        name: AppNotification.macMenuSwitchTab,
                        object: nil
                    )
                }

                @objc private func handleMacMenuSwitchTab(_ notification: Notification) {
                    guard let tagValue = notification.userInfo?["tab"] as? Int,
                          let tag = TabBarTag(rawValue: tagValue) else { return }
                    selectTab(for: tag)
                }
                #endif
            """)
        }

        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }
}
