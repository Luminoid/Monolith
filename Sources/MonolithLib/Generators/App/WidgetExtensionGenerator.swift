import Foundation

/// Generates a WidgetKit extension target: a single-widget SwiftUI scaffold,
/// `Info.plist`, an App Group entitlements file, and a stub shared model file
/// suitable for compiling into both the host app and the widget extension.
///
/// The generator is intentionally minimal — one widget, one timeline entry,
/// no remote data. Adopters expand the timeline provider to read their own
/// shared state (typically from an App Group container file).
enum WidgetExtensionGenerator {
    /// The widget target's `Info.plist`. Modern WidgetKit extensions still
    /// require `NSExtensionPointIdentifier` to surface as a widget host; the
    /// bundle metadata keys mirror what `GENERATE_INFOPLIST_FILE` would have
    /// produced so the extension links cleanly when bundle metadata is sourced
    /// from this file (`GENERATE_INFOPLIST_FILE: NO`). Adopters typically
    /// don't edit this file — bundle ID lives in the project settings.
    static func generateInfoPlist() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleDevelopmentRegion</key>
            <string>$(DEVELOPMENT_LANGUAGE)</string>
            <key>CFBundleDisplayName</key>
            <string>$(PRODUCT_NAME)</string>
            <key>CFBundleExecutable</key>
            <string>$(EXECUTABLE_NAME)</string>
            <key>CFBundleIdentifier</key>
            <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
            <key>CFBundleInfoDictionaryVersion</key>
            <string>6.0</string>
            <key>CFBundleName</key>
            <string>$(PRODUCT_NAME)</string>
            <key>CFBundlePackageType</key>
            <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
            <key>CFBundleShortVersionString</key>
            <string>$(MARKETING_VERSION)</string>
            <key>CFBundleVersion</key>
            <string>$(CURRENT_PROJECT_VERSION)</string>
            <key>NSExtension</key>
            <dict>
                <key>NSExtensionPointIdentifier</key>
                <string>com.apple.widgetkit-extension</string>
            </dict>
        </dict>
        </plist>

        """
    }

    /// `.entitlements` plist declaring App Group membership for the widget
    /// target. The host app must declare the same group via
    /// `generateAppEntitlements(appGroup:)` so both ends can resolve the same
    /// `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`.
    static func generateEntitlements(appGroup: String) -> String {
        generateAppGroupEntitlements(appGroup: appGroup)
    }

    /// `.entitlements` plist for the **host app** target declaring App Group
    /// membership. Required whenever a widget (or any extension) shares state
    /// with the app through a group container. Without this on the app side
    /// `containerURL(forSecurityApplicationGroupIdentifier:)` returns `nil` at
    /// runtime and silently breaks every shared-state code path.
    static func generateAppEntitlements(appGroup: String) -> String {
        generateAppGroupEntitlements(appGroup: appGroup)
    }

    private static func generateAppGroupEntitlements(appGroup: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>com.apple.security.application-groups</key>
            <array>
                <string>\(appGroup)</string>
            </array>
        </dict>
        </plist>

        """
    }

    /// The widget bundle entry point — a `WidgetBundle` containing one widget.
    static func generateBundle(appName: String) -> String {
        """
        import SwiftUI
        import WidgetKit

        @main
        struct \(appName)WidgetBundle: WidgetBundle {
            var body: some Widget {
                \(appName)Widget()
            }
        }

        """
    }

    /// A single timeline widget with a placeholder, snapshot, and timeline
    /// provider returning the current `Date` once per hour.
    ///
    /// Per workspace lesson: widget views that need precise edge alignment
    /// should NOT use `.contentMarginsDisabled()` plus `.padding()` /
    /// `ZStack(alignment:)` (overlay positioning breaks under the widget
    /// runtime even though `ImageRenderer` shows it correctly). Position
    /// edge-anchored content via `GeometryReader` + `.offset(...)` instead.
    static func generateWidget(appName: String, appGroup: String) -> String {
        """
        import SwiftUI
        import WidgetKit

        struct \(appName)Widget: Widget {
            let kind: String = "\(appName)Widget"

            var body: some WidgetConfiguration {
                StaticConfiguration(kind: kind, provider: \(appName)WidgetProvider()) { entry in
                    \(appName)WidgetView(entry: entry)
                        .containerBackground(.fill.tertiary, for: .widget)
                }
                .configurationDisplayName("\(appName)")
                .description("Shows the latest \(appName) state.")
                .supportedFamilies([.systemSmall, .systemMedium])
            }
        }

        struct \(appName)WidgetEntry: TimelineEntry {
            let date: Date
            let message: String
        }

        struct \(appName)WidgetProvider: TimelineProvider {
            func placeholder(in context: Context) -> \(appName)WidgetEntry {
                \(appName)WidgetEntry(date: Date(), message: "Loading…")
            }

            func getSnapshot(in context: Context, completion: @escaping (\(appName)WidgetEntry) -> Void) {
                completion(\(appName)WidgetEntry(date: Date(), message: "\(appName)"))
            }

            func getTimeline(in context: Context, completion: @escaping (Timeline<\(appName)WidgetEntry>) -> Void) {
                // TODO: read shared state from the App Group container:
                // let container = FileManager.default.containerURL(
                //     forSecurityApplicationGroupIdentifier: "\(appGroup)"
                // )
                let entry = \(appName)WidgetEntry(date: Date(), message: "\(appName)")
                let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
                completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
            }
        }

        struct \(appName)WidgetView: View {
            let entry: \(appName)WidgetEntry

            var body: some View {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.message)
                        .font(.headline)
                    Text(entry.date, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }

        """
    }

    /// A small Swift file with the App Group identifier + shared container URL.
    /// Designed to be added to both the app target and the widget target so
    /// neither hardcodes the string.
    static func generateAppGroupConstants(appGroup: String) -> String {
        """
        import Foundation

        /// App Group shared between the app and its widget extension.
        /// Both targets must declare this group in their entitlements.
        enum AppGroup {
            static let identifier = "\(appGroup)"

            /// Shared container URL. Use this for files larger than ~1 KB —
            /// App Group `UserDefaults` is backed by a plist with a ~4 MB hard
            /// limit and will silently corrupt under larger writes.
            static var containerURL: URL? {
                FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
            }
        }

        """
    }
}
