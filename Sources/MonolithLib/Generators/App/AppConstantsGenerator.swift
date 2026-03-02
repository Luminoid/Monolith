import Foundation

enum AppConstantsGenerator {

    static func generate(config: AppConfig) -> String {
        var lines: [String] = []

        lines.append("import Foundation")
        lines.append("")

        // MARK: - AppNotification
        lines.append("// MARK: - Notifications")
        lines.append("")
        lines.append("nonisolated enum AppNotification {")
        lines.append("    static let dataChanged = NSNotification.Name(\"\(config.name)DataChanged\")")
        lines.append("    static let memoryWarningReceived = NSNotification.Name(\"\(config.name)MemoryWarning\")")

        if config.hasMacCatalyst {
            lines.append("")
            lines.append("    // Mac Catalyst Menu")
            lines.append("    static let macMenuRefresh = NSNotification.Name(\"\(config.name)MacMenuRefresh\")")

            if config.hasTabs {
                lines.append("    static let macMenuSwitchTab = NSNotification.Name(\"\(config.name)MacMenuSwitchTab\")")
            }
        }

        lines.append("}")
        lines.append("")

        // MARK: - UserDefaultsKey
        lines.append("// MARK: - UserDefaults Keys")
        lines.append("")
        lines.append("nonisolated enum UserDefaultsKey {")
        lines.append("    enum Display {")
        lines.append("        static let dateFormat = \"display.dateFormat\"")
        lines.append("    }")
        lines.append("}")
        lines.append("")

        // MARK: - ReuseIdentifier
        lines.append("// MARK: - Reuse Identifiers")
        lines.append("")
        lines.append("nonisolated enum ReuseIdentifier {")
        lines.append("    // Add cell reuse identifiers here")
        lines.append("    // static let exampleCell = \"ExampleCell\"")
        lines.append("}")
        lines.append("")

        // MARK: - TabBarTag
        if config.hasTabs {
            lines.append("// MARK: - Tab Bar Tags")
            lines.append("")
            lines.append("nonisolated enum TabBarTag: Int {")
            for (index, tab) in config.tabs.enumerated() {
                let caseName = tab.name.prefix(1).lowercased() + tab.name.dropFirst()
                lines.append("    case \(caseName) = \(index)")
            }
            lines.append("}")
            lines.append("")
        }

        // MARK: - AppConstants
        lines.append("// MARK: - App Constants")
        lines.append("")
        lines.append("nonisolated enum AppConstants {")
        lines.append("    static let maxNameLength = 100")
        lines.append("")
        lines.append("    enum DateFormat {")
        lines.append("        static let defaultFormat = \"MM/dd/yyyy\"")
        lines.append("    }")

        if config.hasMacCatalyst {
            lines.append("")
            lines.append("    enum MacWindow {")
            lines.append("        static let minWidth: CGFloat = 600")
            lines.append("        static let minHeight: CGFloat = 800")
            lines.append("        static let maxWidth: CGFloat = 1200")
            lines.append("        static let maxHeight: CGFloat = 1500")
            lines.append("    }")
        }

        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }
}
