import Foundation

enum AppConstantsGenerator {
    static func generate(config: AppConfig) -> String {
        var lines: [String] = []

        lines.append("import Foundation")
        lines.append("")

        // `memoryWarningReceived` is posted from AppDelegate's memory-warning
        // observer — the only notification that has an actual emitter in the
        // generated scaffold. Other notifications are emitted only when their
        // feature is enabled; `dataChanged` was a placeholder with no posters
        // or observers and has been removed (YAGNI). Adopters add their own
        // `static let xChanged` entries here as features grow.
        lines.addMark("Notifications", indent: 0)
        lines.append("nonisolated enum AppNotification {")
        lines.append("    static let memoryWarningReceived = NSNotification.Name(\"\(config.name)MemoryWarning\")")

        if config.hasNotifications {
            lines.append("    static let userNotificationReceived = NSNotification.Name(\"\(config.name)UserNotificationReceived\")")
        }

        if config.hasDeepLinks {
            lines.append("    static let deepLinkReceived = NSNotification.Name(\"\(config.name)DeepLinkReceived\")")
        }

        if config.hasSpotlight {
            lines.append("    static let spotlightItemSelected = NSNotification.Name(\"\(config.name)SpotlightItemSelected\")")
        }

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

        // UserDefaults / ReuseIdentifier / AppConstants — emit only the
        // structural containers (the `nonisolated enum ...` shells) with a
        // commented-out example inside each. Live unused entries (`maxNameLength
        // = 100`, `dateFormat = "MM/dd/yyyy"`, etc.) bloat the YAGNI surface
        // and tend to be copy-pasted into other files where they take on a
        // life of their own. Adopters fill these in when they hit a real need.

        lines.addMark("UserDefaults Keys", indent: 0)
        lines.append("""
        nonisolated enum UserDefaultsKey {
            // Add typed UserDefaults keys here as nested enums per feature.
            // enum Display {
            //     static let dateFormat = "display.dateFormat"
            // }
        }
        """)

        lines.addMark("Reuse Identifiers", indent: 0)
        lines.append("""
        nonisolated enum ReuseIdentifier {
            // Add cell reuse identifiers here.
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
        }

        lines.addMark("App Constants", indent: 0)
        if config.hasMacCatalyst {
            lines.append("""
            nonisolated enum AppConstants {
                // Add domain constants here as they accumulate.
                // static let maxNameLength = 100

                enum MacWindow {
                    static let minWidth: CGFloat = 600
                    static let minHeight: CGFloat = 800
                    static let maxWidth: CGFloat = 1200
                    static let maxHeight: CGFloat = 1500
                }
            }
            """)
        } else {
            lines.append("""
            nonisolated enum AppConstants {
                // Add domain constants here as they accumulate.
                // static let maxNameLength = 100
            }
            """)
        }
        lines.append("")

        return lines.joined(separator: "\n")
    }
}
