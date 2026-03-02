import Foundation

enum TabBarGenerator {

    static func generate(config: AppConfig) -> String {
        var lines: [String] = []

        lines.append("import UIKit")
        if config.hasSwiftData {
            lines.append("import SwiftData")
        }
        if config.hasLumiKit {
            lines.append("import LumiKitUI")
        }
        lines.append("")

        lines.append("class MainTabBarController: UITabBarController {")
        lines.append("")

        // MARK: - Properties
        lines.append("    // MARK: - Properties")
        lines.append("")

        if config.hasSwiftData {
            lines.append("    private let modelContainer: ModelContainer")
            lines.append("")
        }

        lines.append("    private var navControllers: [TabBarTag: UINavigationController] = [:]")
        lines.append("")

        // MARK: - Initialization
        lines.append("    // MARK: - Initialization")
        lines.append("")

        if config.hasSwiftData {
            lines.append("    init(modelContainer: ModelContainer) {")
            lines.append("        self.modelContainer = modelContainer")
            lines.append("        super.init(nibName: nil, bundle: nil)")
            lines.append("    }")
        } else {
            lines.append("    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {")
            lines.append("        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)")
            lines.append("    }")
        }
        lines.append("")
        lines.append("    @available(*, unavailable)")
        lines.append("    required init?(coder: NSCoder) {")
        lines.append("        fatalError(\"init(coder:) has not been implemented\")")
        lines.append("    }")
        lines.append("")

        // MARK: - Lifecycle
        lines.append("    // MARK: - Lifecycle")
        lines.append("")
        lines.append("    override func viewDidLoad() {")
        lines.append("        super.viewDidLoad()")
        lines.append("")
        if config.hasLumiKit {
            lines.append("        tabBar.tintColor = LMKColor.primary")
        }
        lines.append("        buildTabs()")

        if config.hasMacCatalyst {
            lines.append("")
            lines.append("        #if targetEnvironment(macCatalyst)")
            lines.append("        setupMacMenuHandlers()")
            lines.append("        #endif")
        }

        lines.append("    }")
        lines.append("")

        // MARK: - Tab Building
        lines.append("    // MARK: - Setup")
        lines.append("")
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

        // MARK: - Tab Selection
        lines.append("    // MARK: - Actions")
        lines.append("")
        lines.append("    func selectTab(for tag: TabBarTag) {")
        lines.append("        guard let index = viewControllers?.firstIndex(where: { $0.tabBarItem.tag == tag.rawValue }) else { return }")
        lines.append("        selectedIndex = index")
        lines.append("    }")

        // Mac Catalyst handlers
        if config.hasMacCatalyst {
            lines.append("")
            lines.append("    // MARK: - Mac Catalyst")
            lines.append("")
            lines.append("    #if targetEnvironment(macCatalyst)")
            lines.append("    private func setupMacMenuHandlers() {")
            lines.append("        NotificationCenter.default.addObserver(")
            lines.append("            self,")
            lines.append("            selector: #selector(handleMacMenuSwitchTab(_:)),")
            lines.append("            name: AppNotification.macMenuSwitchTab,")
            lines.append("            object: nil")
            lines.append("        )")
            lines.append("    }")
            lines.append("")
            lines.append("    @objc private func handleMacMenuSwitchTab(_ notification: Notification) {")
            lines.append("        guard let tagValue = notification.userInfo?[\"tab\"] as? Int,")
            lines.append("              let tag = TabBarTag(rawValue: tagValue) else { return }")
            lines.append("        selectTab(for: tag)")
            lines.append("    }")
            lines.append("    #endif")
        }

        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }
}
