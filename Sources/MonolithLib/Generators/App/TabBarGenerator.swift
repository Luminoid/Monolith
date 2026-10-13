import Foundation

/// Generates `MainTabBarController.swift`.
///
/// A LumiKit app subclasses `LMKTabBarController` and describes its tabs as
/// `LMKTab`s: the controller builds each root on first selection, wraps it in
/// an `LMKNavigationController`, styles the bar from the theme, and shows a
/// sidebar in regular-width iPad and Mac windows. Without LumiKit the
/// controller is a plain `UITabBarController` that builds its navigation
/// controllers in `init`, so a selection made before the view loads (state
/// restoration) sticks.
///
/// Both variants answer the View menu's commands (`AppDelegate.buildMenu`)
/// through the responder chain: `selectTabFromMenu(_:)` and
/// `refreshFromMenu(_:)`, disabled while a sheet is presented, with the
/// selected tab checked. The menu owns ⌘1…⌘N on every idiom, so a LumiKit
/// controller turns its own tab key commands off.
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

        if config.hasSwiftData {
            lines.addMark("Properties")
            lines.append("    private let modelContainer: ModelContainer")
        }

        lines.addMark("Constants")
        lines.append(menuActionsConstant)

        lines.addMark("Initialization")
        if config.hasSwiftData {
            lines.append("""
                init(modelContainer: ModelContainer) {
                    self.modelContainer = modelContainer
                    super.init(nibName: nil, bundle: nil)
                    buildTabs()
                }
            """)
        } else {
            // A parameterless designated initializer that delegates through the
            // `nibName:bundle:` designated init on UITabBarController. We can't
            // rely on Swift to inherit `init()` from UIKit because the
            // `@available(*, unavailable) required init?(coder:)` below breaks
            // initializer inheritance; every later call site (SceneDelegate)
            // would fail to compile with "missing argument for parameter 'coder'".
            lines.append("""
                init() {
                    super.init(nibName: nil, bundle: nil)
                    buildTabs()
                }
            """)
        }
        lines.append("")
        lines.append(unavailableCoderInit)

        lines.addMark("Setup")
        lines.append("    /// Builds the tabs in `init`, so a selection made before the view loads sticks.")
        lines.append("    private func buildTabs() {")
        for (offset, tab) in config.tabs.enumerated() {
            let caseName = AppConstantsGenerator.caseName(for: tab)
            // Blank line BETWEEN tabs, not before the first one (a leading blank
            // trips SwiftFormat's blankLinesAtStartOfScope inside buildTabs()).
            if offset > 0 {
                lines.append("")
            }
            lines.append("        let \(caseName)VC = \(tab.name)ViewController(\(config.hasSwiftData ? "modelContainer: modelContainer" : ""))")
            lines.append("        let \(caseName)Nav = NavController(rootViewController: \(caseName)VC)")
            lines.append("        \(caseName)Nav.tabBarItem = UITabBarItem(")
            // When localization is on, the tab bar must read from the catalog
            // (L10n.Tab.<case>) like the per-tab nav-bar titles do; a hardcoded
            // literal would leave the tab bar English while nav bars localize.
            lines.append("            title: \(tabTitle(tab, config: config)),")
            lines.append("            image: UIImage(systemName: \"\(tab.icon)\"),")
            lines.append("            tag: TabBarTag.\(caseName).rawValue")
            lines.append("        )")
        }
        lines.append("")
        let tabNames = config.tabs.map { "\(AppConstantsGenerator.caseName(for: $0))Nav" }
        lines.append("        viewControllers = [\(tabNames.joined(separator: ", "))]")
        lines.append("    }")

        lines.addMark("Actions")
        lines.append("""
            /// The selected tab.
            var selectedTabTag: TabBarTag? {
                selectedViewController.flatMap { TabBarTag(rawValue: $0.tabBarItem.tag) }
            }

            func selectTab(for tag: TabBarTag) {
                guard let viewController = viewControllers?.first(where: { $0.tabBarItem.tag == tag.rawValue }) else { return }
                // `selectedViewController`, not `selectedIndex`: it also refreshes the bar's
                // highlight when the change comes from a menu or key command.
                selectedViewController = viewController
            }
        """)

        lines.addMark("Menu")
        lines.append(menuHandlers)

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

        lines.addMark("Constants")
        lines.append(menuActionsConstant)

        // In regular-width iPad and Mac windows the tabs move to a sidebar.
        let wantsSidebar = config.platforms.contains(.iPad) || config.hasMacCatalyst
        let styleArgument = wantsSidebar ? ", style: Style(prefersSidebarOnIPad: true)" : ""
        let tabsArgument = config.hasSwiftData ? "modelContainer: modelContainer" : ""
        lines.addMark("Initialization")
        // `init()` must be declared: the unavailable `init?(coder:)` below
        // stops initializer inheritance.
        lines.append("""
            init(\(config.hasSwiftData ? "modelContainer: ModelContainer" : "")) {
                super.init(tabs: Self.makeTabs(\(tabsArgument))\(styleArgument))
                // The View menu (AppDelegate.buildMenu) owns ⌘1…⌘N on every idiom.
                tabKeyCommandsEnabled = false
            }

        """)
        lines.append(unavailableCoderInit)

        lines.addMark("Setup")
        lines.append("    /// The tabs in display order. Each root is built on first selection and")
        lines.append("    /// wrapped in an `LMKNavigationController`.")
        let parameter = config.hasSwiftData ? "modelContainer: ModelContainer" : ""
        lines.append("    private static func makeTabs(\(parameter)) -> [LMKTab] {")
        lines.append("        [")
        for tab in config.tabs {
            let caseName = AppConstantsGenerator.caseName(for: tab)
            lines.append(
                "            LMKTab(identifier: TabBarTag.\(caseName).identifier, title: \(tabTitle(tab, config: config)), "
                    + "systemImage: \"\(tab.icon)\") { \(tab.name)ViewController(\(tabsArgument)) },"
            )
        }
        lines.append("        ]")
        lines.append("    }")

        lines.addMark("Actions")
        lines.append("""
            /// The selected tab.
            var selectedTabTag: TabBarTag? {
                selectedIdentifier.flatMap { TabBarTag(identifier: $0) }
            }

            func selectTab(for tag: TabBarTag) {
                selectTab(identifier: tag.identifier)
            }
        """)

        lines.addMark("Menu")
        lines.append(menuHandlers)

        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    /// The tab's title expression: the catalog entry when localized, else a literal.
    private static func tabTitle(_ tab: TabDefinition, config: AppConfig) -> String {
        config.hasLocalization ? "L10n.Tab.\(AppConstantsGenerator.caseName(for: tab))" : "\"\(tab.name)\""
    }

    private static let unavailableCoderInit = """
        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    """

    private static let menuActionsConstant = """
        /// The View menu's actions, disabled while a sheet is presented.
        private static let menuActions: Set<Selector> = [
            #selector(selectTabFromMenu(_:)),
            #selector(refreshFromMenu(_:)),
        ]
    """

    /// The View menu's actions plus their validation. A presented controller's
    /// responder chain reaches its presenter, so without `canPerformAction` a
    /// shortcut would switch tabs underneath a sheet.
    private static let menuHandlers = """
        /// View ▸ <tab> (⌘1…⌘N); the command's `propertyList` is the tab's identifier.
        @objc func selectTabFromMenu(_ sender: Any?) {
            guard let identifier = (sender as? UICommand)?.propertyList as? String,
                  let tag = TabBarTag(identifier: identifier) else { return }
            selectTab(for: tag)
        }

        /// View ▸ Refresh (⌘R). Screens that reload observe `AppNotification.refreshRequested`;
        /// a screen can instead implement `refreshFromMenu(_:)` itself, and the responder chain
        /// reaches it first.
        @objc func refreshFromMenu(_: Any?) {
            NotificationCenter.default.post(name: AppNotification.refreshRequested, object: nil)
        }

        /// A presented controller's responder chain reaches its presenter, so without this a
        /// shortcut would switch tabs underneath a sheet.
        override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
            if Self.menuActions.contains(action) {
                return presentedViewController == nil
            }
            return super.canPerformAction(action, withSender: sender)
        }

        /// Checks the selected tab in the View menu.
        override func validate(_ command: UICommand) {
            super.validate(command)
            guard command.action == #selector(selectTabFromMenu(_:)), let identifier = command.propertyList as? String else { return }
            command.state = identifier == selectedTabTag?.identifier ? .on : .off
        }
    """
}
