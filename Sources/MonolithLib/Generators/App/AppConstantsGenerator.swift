import Foundation

enum AppConstantsGenerator {
    static func generate(config: AppConfig) -> String {
        var lines: [String] = []

        lines.append("import Foundation")
        lines.append("")

        lines.addMark("Notifications", indent: 0)
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

        lines.addMark("UserDefaults Keys", indent: 0)
        lines.append("""
        nonisolated enum UserDefaultsKey {
            enum Display {
                static let dateFormat = "display.dateFormat"
            }
        }

        """)

        lines.addMark("Reuse Identifiers", indent: 0)
        lines.append("""
        nonisolated enum ReuseIdentifier {
            // Add cell reuse identifiers here
            // static let exampleCell = "ExampleCell"
        }

        """)

        if config.hasTabs {
            lines.addMark("Tab Bar Tags", indent: 0)
            lines.append("nonisolated enum TabBarTag: Int {")
            for (index, tab) in config.tabs.enumerated() {
                let caseName = tab.name.prefix(1).lowercased() + tab.name.dropFirst()
                lines.append("    case \(caseName) = \(index)")
            }
            lines.append("}")
            lines.append("")
        }

        lines.addMark("App Constants", indent: 0)
        lines.append("""
        nonisolated enum AppConstants {
            static let maxNameLength = 100

            enum DateFormat {
                static let defaultFormat = "MM/dd/yyyy"
            }
        """)

        if config.hasMacCatalyst {
            lines.append("")
            lines.append("""
                enum MacWindow {
                    static let minWidth: CGFloat = 600
                    static let minHeight: CGFloat = 800
                    static let maxWidth: CGFloat = 1200
                    static let maxHeight: CGFloat = 1500
                }
            """)
        }

        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }
}
