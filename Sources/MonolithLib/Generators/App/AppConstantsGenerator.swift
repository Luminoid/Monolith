import Foundation

/// Generates `Core/AppConstants.swift`: notification names, UserDefaults keys,
/// reuse identifiers, the tab tags, app constants, and (for an app without
/// LumiKit that logs anything) the shared `Logger.app`.
enum AppConstantsGenerator {
    static func generate(config: AppConfig) -> String {
        var lines: [String] = []

        lines.append("import Foundation")
        if needsAppLogger(config: config) {
            lines.append("import os")
        }
        lines.append("")

        lines.addMark("Notifications", indent: 0)
        lines.append(contentsOf: notificationNames(config: config))

        // UserDefaults / ReuseIdentifier / AppConstants: emit only the
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
            lines.append(contentsOf: tabBarTag(config: config))
        }

        lines.addMark("App Constants", indent: 0)
        if config.hasMacCatalyst {
            // Minimum size only: a maximum would block full screen and wide
            // window tiling on the Mac.
            lines.append("""
            nonisolated enum AppConstants {
                // Add domain constants here as they accumulate.
                // static let maxNameLength = 100

                enum MacWindow {
                    static let minWidth: CGFloat = \(MacCatalystGenerator.minimumWindowWidth)
                    static let minHeight: CGFloat = \(MacCatalystGenerator.minimumWindowHeight)
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

        if needsAppLogger(config: config) {
            lines.addMark("Logging", indent: 0)
            lines.append("""
            extension Logger {
                /// The app's log, under its bundle identifier. Failure paths log the error
                /// description as `privacy: .private`, since it can carry user data.
                static let app = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app", category: "App")
            }
            """)
        }
        lines.append("")

        return lines.joined(separator: "\n")
    }

    /// Whether the app logs through `Logger.app`: an app without LumiKit (which
    /// has `LMKLogger`) whose generated code has a failure path to log, namely
    /// the SwiftData container and every CloudKit path (remote-notification
    /// registration, the Core Data stack's CloudKit fallback, share acceptance).
    static func needsAppLogger(config: AppConfig) -> Bool {
        !config.hasLumiKit && (config.hasSwiftData || config.hasCloudKit)
    }

    /// Whether the app accepts CloudKit shares into a Core Data shared store.
    /// SwiftData has no shared database, so sharing is a Core Data feature.
    static func hasCoreDataSharing(config: AppConfig) -> Bool {
        config.hasCloudKitSharing && config.hasCoreData && !config.hasSwiftData
    }

    /// The tab's lower-camel-case name: its `TabBarTag` case and `L10n.Tab` member.
    static func caseName(for tab: TabDefinition) -> String {
        tab.name.prefix(1).lowercased() + tab.name.dropFirst()
    }

    // MARK: - Sections

    /// The `AppNotification` names. Only notifications something in the
    /// scaffold posts are declared; screens observe them. Routing for deep
    /// links, Spotlight results, and notification taps goes through the root
    /// view controller instead (see `SceneDelegateGenerator`).
    private static func notificationNames(config: AppConfig) -> [String] {
        var names: [String] = []
        if config.hasTabs {
            names.append("""
                /// Posted by the View menu's Refresh command (⌘R). Screens that reload their
                /// content observe it.
                static let refreshRequested = NSNotification.Name("\(config.name)RefreshRequested")
            """)
        }
        if hasCoreDataSharing(config: config) {
            names.append("""
                /// Posted when the user accepts a CloudKit share while sync is off, so the share
                /// has no store to land in. Observe it to offer turning sync on (the setting
                /// applies at the next launch).
                static let cloudKitShareRequiresSync = NSNotification.Name("\(config.name)CloudKitShareRequiresSync")
            """)
        }

        var lines = ["nonisolated enum AppNotification {"]
        if names.isEmpty {
            lines.append("    // Add app-wide notification names here.")
            lines.append("    // static let itemsChanged = NSNotification.Name(\"\(config.name)ItemsChanged\")")
        } else {
            lines.append(names.joined(separator: "\n"))
        }
        lines.append("}")
        return lines
    }

    /// `TabBarTag`, with the stable string identifier that menus, state
    /// restoration, and `LMKTab` use (the raw value is only the position).
    private static func tabBarTag(config: AppConfig) -> [String] {
        var lines = ["nonisolated enum TabBarTag: Int, CaseIterable {"]
        for (index, tab) in config.tabs.enumerated() {
            lines.append("    case \(caseName(for: tab)) = \(index)")
        }
        lines.append("""

            /// A stable name for the tab, used by the View menu and state restoration. The raw
            /// value is only the tab's position.
            var identifier: String {
                String(describing: self)
            }

            init?(identifier: String) {
                guard let tag = Self.allCases.first(where: { $0.identifier == identifier }) else { return nil }
                self = tag
            }
        }
        """)
        return lines
    }
}
