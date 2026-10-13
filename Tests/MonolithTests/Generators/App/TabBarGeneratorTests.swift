import Foundation
import Testing
@testable import MonolithLib

struct TabBarGeneratorTests {
    private func makeConfig(
        swiftData: Bool = false,
        lumiKit: Bool = false,
        macCatalyst: Bool = false,
        iPad: Bool = false,
        localization: Bool = false,
        tabs: [TabDefinition] = [
            TabDefinition(name: "Home", icon: "house.fill"),
            TabDefinition(name: "Settings", icon: "gear"),
        ]
    ) -> AppConfig {
        var features: Set<AppFeature> = []
        if swiftData { features.insert(.swiftData) }
        if lumiKit { features.insert(.lumiKit) }
        if localization { features.insert(.localization) }

        var platforms: Set<Platform> = [.iPhone]
        if macCatalyst { platforms.insert(.macCatalyst) }
        if iPad { platforms.insert(.iPad) }

        return AppConfig(
            name: "TestApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: platforms,
            projectSystem: .xcodeProj,
            tabs: tabs,
            primaryColor: "#007AFF",
            features: features,
            author: "Test",
            licenseType: .proprietary
        )
    }

    @Test
    func `basic tab bar structure`() {
        let output = TabBarGenerator.generate(config: makeConfig())
        #expect(output.contains("class MainTabBarController: UITabBarController"))
        #expect(output.contains("buildTabs()"))
        #expect(output.contains("selectTab"))
        // The dictionary of navigation controllers was written and never read.
        #expect(!output.contains("navControllers"))
    }

    /// The tabs exist from `init` on, so a selection made before the view
    /// loads (state restoration) sticks.
    @Test
    func `standard tab bar builds its tabs in init`() {
        let output = TabBarGenerator.generate(config: makeConfig())
        #expect(output.contains("    init() {\n        super.init(nibName: nil, bundle: nil)\n        buildTabs()\n    }"))
        #expect(!output.contains("override func viewDidLoad()"))
    }

    /// `selectedIndex` doesn't refresh the bar's highlight from menu and
    /// key-command paths; `selectedViewController` does.
    @Test
    func `standard tab bar selects through selectedViewController`() {
        let output = TabBarGenerator.generate(config: makeConfig())
        #expect(output.contains("selectedViewController = viewController"))
        #expect(!output.contains("selectedIndex ="))
        #expect(output.contains("var selectedTabTag: TabBarTag? {"))
    }

    // Regression: when localization is on, the tab bar must read titles from
    // the catalog (L10n.Tab.<case>), matching the per-tab nav-bar titles — a
    // hardcoded literal leaves the tab bar English while nav bars localize.
    @Test
    func `localized tab titles use L10n_Tab`() {
        let output = TabBarGenerator.generate(config: makeConfig(localization: true))
        #expect(output.contains("title: L10n.Tab.home"))
        #expect(output.contains("title: L10n.Tab.settings"))
        #expect(!output.contains("title: \"Home\""))
    }

    @Test
    func `non-localized tab titles use literals`() {
        let output = TabBarGenerator.generate(config: makeConfig())
        #expect(output.contains("title: \"Home\""))
        #expect(!output.contains("L10n.Tab"))
    }

    @Test
    func `builds tabs for each definition`() {
        let output = TabBarGenerator.generate(config: makeConfig())
        #expect(output.contains("HomeViewController"))
        #expect(output.contains("SettingsViewController"))
        #expect(output.contains("house.fill"))
        #expect(output.contains("gear"))
        #expect(output.contains("TabBarTag.home"))
        #expect(output.contains("TabBarTag.settings"))
    }

    @Test
    func `SwiftData adds modelContainer init`() {
        let output = TabBarGenerator.generate(config: makeConfig(swiftData: true))
        #expect(output.contains("import SwiftData"))
        #expect(output.contains("init(modelContainer: ModelContainer)"))
        #expect(output.contains("self.modelContainer = modelContainer"))
    }

    /// The container reaches every tab's root instead of stopping at the tab bar.
    @Test(arguments: [false, true])
    func `SwiftData container is handed to every tab root`(lumiKit: Bool) {
        let output = TabBarGenerator.generate(config: makeConfig(swiftData: true, lumiKit: lumiKit))
        #expect(output.contains("HomeViewController(modelContainer: modelContainer)"))
        #expect(output.contains("SettingsViewController(modelContainer: modelContainer)"))
        #expect(!output.contains("HomeViewController()"))
    }

    @Test
    func `no SwiftData uses standard init`() {
        let output = TabBarGenerator.generate(config: makeConfig())
        #expect(!output.contains("import SwiftData"))
        #expect(!output.contains("init(modelContainer:"))
    }

    // MARK: - LumiKit

    @Test
    func `LumiKit subclasses LMKTabBarController with LMKTab definitions`() {
        let output = TabBarGenerator.generate(config: makeConfig(lumiKit: true))
        #expect(output.contains("import LumiKitUI"))
        #expect(output.contains("final class MainTabBarController: LMKTabBarController {"))
        #expect(output.contains("        super.init(tabs: Self.makeTabs())\n"))
        #expect(output.contains(
            "            LMKTab(identifier: TabBarTag.home.identifier, title: \"Home\", systemImage: \"house.fill\") { HomeViewController() },"
        ))
        #expect(output.contains(
            "            LMKTab(identifier: TabBarTag.settings.identifier, title: \"Settings\", systemImage: \"gear\") { SettingsViewController() },"
        ))
        // LMKTabBarController builds and wraps the roots and themes the bar
        // itself, so none of the hand-rolled UITabBarController setup remains.
        #expect(!output.contains("UITabBarController"))
        #expect(!output.contains("UITabBarItem"))
        #expect(!output.contains("navControllers"))
        #expect(!output.contains("tintColor"))
    }

    @Test
    func `LumiKit selects tabs by identifier`() {
        let output = TabBarGenerator.generate(config: makeConfig(lumiKit: true))
        #expect(output.contains("    func selectTab(for tag: TabBarTag) {\n        selectTab(identifier: tag.identifier)\n    }"))
        #expect(output.contains("selectedIdentifier.flatMap { TabBarTag(identifier: $0) }"))
        // `TabBarTag.identifier` is declared once, in AppConstants.
        #expect(!output.contains("extension TabBarTag"))
    }

    /// In regular-width iPad and Mac windows the tabs move to a sidebar.
    @Test
    func `LumiKit prefers a sidebar when the app runs on iPad or Mac`() {
        for (iPad, macCatalyst) in [(true, false), (false, true)] {
            let output = TabBarGenerator.generate(config: makeConfig(lumiKit: true, macCatalyst: macCatalyst, iPad: iPad))
            #expect(output.contains("super.init(tabs: Self.makeTabs(), style: Style(prefersSidebarOnIPad: true))"))
        }
        let phoneOnly = TabBarGenerator.generate(config: makeConfig(lumiKit: true))
        #expect(!phoneOnly.contains("prefersSidebarOnIPad"))
    }

    @Test
    func `LumiKit tabs read localized titles`() {
        let output = TabBarGenerator.generate(config: makeConfig(lumiKit: true, localization: true))
        #expect(output.contains("title: L10n.Tab.home,"))
        #expect(!output.contains("title: \"Home\""))
    }

    @Test
    func `LumiKit SwiftData init passes the tabs to super`() {
        let output = TabBarGenerator.generate(config: makeConfig(swiftData: true, lumiKit: true))
        #expect(output.contains("import SwiftData"))
        #expect(output.contains(
            "    init(modelContainer: ModelContainer) {\n        super.init(tabs: Self.makeTabs(modelContainer: modelContainer))\n"
        ))
        #expect(output.contains("    private static func makeTabs(modelContainer: ModelContainer) -> [LMKTab] {"))
        // Passed straight through to the tabs; nothing stores it.
        #expect(!output.contains("private let modelContainer"))
    }

    /// The View menu owns ⌘1…⌘N on every idiom, so the controller's own tab
    /// key commands are off everywhere, not only on the Mac.
    @Test(arguments: [false, true])
    func `LumiKit hands tab shortcuts to the View menu on every idiom`(macCatalyst: Bool) {
        let output = TabBarGenerator.generate(config: makeConfig(lumiKit: true, macCatalyst: macCatalyst))
        #expect(output.contains("        tabKeyCommandsEnabled = false\n"))
        #expect(!output.contains("#if targetEnvironment"))
        #expect(!output.contains("setupMacMenuHandlers"))
    }

    @Test
    func `standard tab bar does not import LumiKit`() {
        let output = TabBarGenerator.generate(config: makeConfig())
        #expect(!output.contains("LumiKit"))
        #expect(!output.contains("LMK"))
        #expect(output.contains("private typealias NavController = UINavigationController"))
    }

    /// The View menu's commands resolve through the responder chain to the
    /// tab bar controller, which disables them under a sheet and checks the
    /// selected tab. No NotificationCenter tab switching remains.
    @Test(arguments: [false, true])
    func `tab bar answers the View menu through the responder chain`(lumiKit: Bool) {
        let output = TabBarGenerator.generate(config: makeConfig(lumiKit: lumiKit, macCatalyst: true))
        #expect(output.contains("    @objc func selectTabFromMenu(_ sender: Any?) {"))
        #expect(output.contains("    @objc func refreshFromMenu(_: Any?) {"))
        #expect(output.contains("NotificationCenter.default.post(name: AppNotification.refreshRequested, object: nil)"))
        #expect(output.contains("""
            override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
                if Self.menuActions.contains(action) {
                    return presentedViewController == nil
                }
                return super.canPerformAction(action, withSender: sender)
            }
        """))
        #expect(output.contains("    override func validate(_ command: UICommand) {"))
        #expect(output.contains("command.state = identifier == selectedTabTag?.identifier ? .on : .off"))
        #expect(output.contains("""
            private static let menuActions: Set<Selector> = [
                #selector(selectTabFromMenu(_:)),
                #selector(refreshFromMenu(_:)),
            ]
        """))
        #expect(!output.contains("macMenu"))
        #expect(!output.contains("#if targetEnvironment"))
        #expect(!output.contains("addObserver"))
    }

    @Test
    func `three tabs generates three entries`() {
        let tabs = [
            TabDefinition(name: "Home", icon: "house.fill"),
            TabDefinition(name: "Search", icon: "magnifyingglass"),
            TabDefinition(name: "Profile", icon: "person.fill"),
        ]
        let output = TabBarGenerator.generate(config: makeConfig(tabs: tabs))
        #expect(output.contains("HomeViewController"))
        #expect(output.contains("SearchViewController"))
        #expect(output.contains("ProfileViewController"))
        #expect(output.contains("homeNav, searchNav, profileNav"))
    }
}
