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
        lines.append("    func application(")
        lines.append("        _ application: UIApplication,")
        lines.append("        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?")
        lines.append("    ) -> Bool {")

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
        lines.append("        // Phase 4: Deferred Work")
        lines.append("        deferPostLaunchWork()")
        lines.append("")
        lines.append("        return true")
        lines.append("    }")
        lines.append("")

        lines.addMark("Scene Configuration")
        lines.append("    func application(")
        lines.append("        _ application: UIApplication,")
        lines.append("        configurationForConnecting connectingSceneSession: UISceneSession,")
        lines.append("        options: UIScene.ConnectionOptions")
        lines.append("    ) -> UISceneConfiguration {")
        lines.append("        UISceneConfiguration(name: \"Default Configuration\", sessionRole: connectingSceneSession.role)")
        lines.append("    }")
        lines.append("")

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
            lines.append("    private func createModelContainer() -> ModelContainer? {")
            lines.append("        do {")
            lines.append("            let schema = Schema([")
            lines.append("                // Add your @Model types here")
            lines.append("            ])")
            lines.append("            let config = ModelConfiguration(schema: schema)")
            lines.append("            return try ModelContainer(for: schema, configurations: [config])")
            lines.append("        } catch {")
            lines.append("            print(\"Failed to create ModelContainer: \\(error)\")")
            lines.append("            return nil")
            lines.append("        }")
            lines.append("    }")
            lines.append("")
        }

        lines.addMark("Memory Warning")
        lines.append("    private func setupMemoryWarningObserver() {")
        lines.append("        NotificationCenter.default.addObserver(")
        lines.append("            self,")
        lines.append("            selector: #selector(handleMemoryWarning),")
        lines.append("            name: UIApplication.didReceiveMemoryWarningNotification,")
        lines.append("            object: nil")
        lines.append("        )")
        lines.append("    }")
        lines.append("")
        lines.append("    @objc private func handleMemoryWarning(_ notification: Notification) {")
        lines.append("        NotificationCenter.default.post(name: AppNotification.memoryWarningReceived, object: nil)")
        lines.append("    }")
        lines.append("")

        lines.addMark("Deferred Work")
        lines.append("    private func deferPostLaunchWork() {")
        lines.append("        Task { @MainActor in")
        lines.append("            // Perform non-blocking post-launch work here")
        lines.append("        }")
        lines.append("    }")

        if config.hasMacCatalyst {
            lines.addMark("Mac Catalyst Menu")
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
            lines.append("")
            lines.append("        let menu = UIMenu(title: \"\(config.name)\", children: [refreshCommand])")
            lines.append("        builder.insertSibling(menu, afterMenu: .view)")
            lines.append("    }")
            lines.append("")
            lines.append("    @objc private func handleRefreshMenu() {")
            lines.append("        NotificationCenter.default.post(name: AppNotification.macMenuRefresh, object: nil)")
            lines.append("    }")
            lines.append("    #endif")
        }

        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }
}
