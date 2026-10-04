import Foundation

/// Generates `MainTabBarController.swift`.
///
/// A LumiKit app subclasses `LMKTabBarController` and describes its tabs as
/// `LMKTab`s: the controller builds each root on first selection, wraps it in
/// an `LMKNavigationController`, styles the bar from the theme, and provides
/// ⌘1…⌘N on iPhone and iPad. Without LumiKit the controller is a plain
/// `UITabBarController` that builds its navigation controllers up front.
enum TabBarGenerator {
    static func generate(config: AppConfig) -> String {
        if config.hasLumiKit {
            return generateLumiKit(config: config)
        }

        var lines: [String] = []

        if config.hasSwiftData {
            lines.append("import SwiftData")
        }
        lines.append("import UIKit")
        lines.append("")

        lines.append("private typealias NavController = UINavigationController")
        lines.append("")

        lines.append("final class MainTabBarController: UITabBarController {")

        lines.addMark("Properties")

        if config.hasSwiftData {
            lines.append("    private let modelContainer: ModelContainer")
            lines.append("")
        }

        lines.append("    private var navControllers: [TabBarTag: NavController] = [:]")
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
            // A parameterless designated initializer that delegates through the
            // `nibName:bundle:` designated init on UITabBarController. We can't
            // rely on Swift to inherit `init()` from UIKit because the
            // `@available(*, unavailable) required init?(coder:)` below breaks
            // initializer inheritance — every later call site (SceneDelegate)
            // would fail to compile with "missing argument for parameter 'coder'".
            lines.append("    init() {")
            lines.append("        super.init(nibName: nil, bundle: nil)")
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

        for (offset, tab) in config.tabs.enumerated() {
            let caseName = tab.name.prefix(1).lowercased() + tab.name.dropFirst()
            // Blank line BETWEEN tabs, not before the first one (a leading blank
            // trips SwiftFormat's blankLinesAtStartOfScope inside buildTabs()).
            if offset > 0 {
                lines.append("")
            }
            lines.append("        let \(caseName)VC = \(tab.name)ViewController()")
            lines.append("        let \(caseName)Nav = NavController(rootViewController: \(caseName)VC)")
            lines.append("        \(caseName)Nav.tabBarItem = UITabBarItem(")
            // When localization is on, the tab bar must read from the catalog
            // (L10n.Tab.<case>) like the per-tab nav-bar titles do; a hardcoded
            // literal would leave the tab bar English while nav bars localize.
            if config.hasLocalization {
                lines.append("            title: L10n.Tab.\(caseName),")
            } else {
                lines.append("            title: \"\(tab.name)\",")
            }
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
            lines.append(macMenuHandlers)
        }

        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    // MARK: - LumiKit

    private static func generateLumiKit(config: AppConfig) -> String {
        var lines: [String] = []

        lines.append("import LumiKitUI")
        if config.hasSwiftData {
            lines.append("import SwiftData")
        }
        lines.append("import UIKit")
        lines.append("")

        lines.append("final class MainTabBarController: LMKTabBarController {")

        if config.hasSwiftData {
            lines.addMark("Properties")
            lines.append("    private let modelContainer: ModelContainer")
        }

        lines.addMark("Initialization")
        if config.hasSwiftData {
            lines.append("""
                init(modelContainer: ModelContainer) {
                    self.modelContainer = modelContainer
                    super.init(tabs: Self.makeTabs())
                }
            """)
        } else {
            // A parameterless designated initializer: the unavailable
            // `init?(coder:)` below stops initializer inheritance, so the
            // SceneDelegate's `MainTabBarController()` needs one declared here.
            lines.append("""
                init() {
                    super.init(tabs: Self.makeTabs())
                }
            """)
        }
        lines.append("")
        lines.append("""
            @available(*, unavailable)
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
        """)

        if config.hasMacCatalyst {
            // `LMKTabBarController` offers ⌘1…⌘N itself except under the Mac
            // idiom. This app runs in the scaled iPad idiom on the Mac, where
            // the AppDelegate's menu already binds those keys, so the
            // controller's copies are switched off there.
            lines.addMark("Lifecycle")
            lines.append("""
                override func viewDidLoad() {
                    super.viewDidLoad()

                    #if targetEnvironment(macCatalyst)
                        // The app menu (AppDelegate.buildMenu) owns ⌘1…⌘N on the Mac.
                        tabKeyCommandsEnabled = false
                        setupMacMenuHandlers()
                    #endif
                }
            """)
        }

        lines.addMark("Setup")
        lines.append("    /// The tabs in display order. Each root is built on first selection and")
        lines.append("    /// wrapped in an `LMKNavigationController`.")
        lines.append("    private static func makeTabs() -> [LMKTab] {")
        lines.append("        [")
        for tab in config.tabs {
            let caseName = tab.name.prefix(1).lowercased() + tab.name.dropFirst()
            // Localized apps read the tab title from the catalog, like the
            // per-tab navigation titles do.
            let title = config.hasLocalization ? "L10n.Tab.\(caseName)" : "\"\(tab.name)\""
            lines.append(
                "            LMKTab(identifier: TabBarTag.\(caseName).identifier, title: \(title), "
                    + "systemImage: \"\(tab.icon)\") { \(tab.name)ViewController() },"
            )
        }
        lines.append("        ]")
        lines.append("    }")

        lines.addMark("Actions")
        lines.append("""
            func selectTab(for tag: TabBarTag) {
                selectTab(identifier: tag.identifier)
            }
        """)

        if config.hasMacCatalyst {
            lines.addMark("Mac Catalyst")
            lines.append(macMenuHandlers)
        }

        lines.append("}")
        lines.addMark("TabBarTag", indent: 0)
        lines.append("""
        private extension TabBarTag {
            /// The `LMKTab` identifier for this tab.
            var identifier: String { String(describing: self) }
        }
        """)
        lines.append("")

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    /// Observes the Mac menu's tab commands (posted by the AppDelegate's
    /// `buildMenu`) and selects the matching tab.
    private static let macMenuHandlers = """
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
                guard let index = notification.object as? Int,
                      let tag = TabBarTag(rawValue: index) else { return }
                selectTab(for: tag)
            }
        #endif
    """
}
