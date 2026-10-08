import Foundation

/// Generates a WidgetKit extension target: a single-widget SwiftUI scaffold,
/// `Info.plist`, an App Group entitlements file, and a stub shared model file
/// suitable for compiling into both the host app and the widget extension.
///
/// The generator is intentionally minimal — one widget, one timeline entry,
/// no remote data. Adopters expand the timeline provider to read their own
/// shared state (typically from an App Group container file).
enum WidgetExtensionGenerator {
    /// Every file the widget extension needs, as (relative path, content)
    /// pairs. `new app` and `add widget` both write from this list and their
    /// dry runs list it, so the three can't drift. The host app's own
    /// entitlements are not in it: `new` writes them from
    /// `EntitlementsGenerator`, and `add` merges the App Group into the
    /// existing file.
    ///
    /// The widget's PrivacyInfo is always included, independent of the app's
    /// `privacyManifest` feature: every shipped bundle (the app and each
    /// `.appex`) needs its own manifest for App Store Connect's privacy
    /// report, and the extension's is minimal.
    static func files(appName: String, appGroup: String) -> [(path: String, content: String)] {
        let widgetDir = "\(appName)Widget"
        return [
            ("\(widgetDir)/Info.plist", generateInfoPlist()),
            ("\(widgetDir)/\(appName)Widget.entitlements", generateEntitlements(appGroup: appGroup)),
            ("\(widgetDir)/\(appName)WidgetBundle.swift", generateBundle(appName: appName)),
            ("\(widgetDir)/\(appName)Widget.swift", generateWidget(appName: appName)),
            ("\(appName)/Shared/AppGroup.swift", generateAppGroupConstants(appGroup: appGroup)),
            ("\(widgetDir)/PrivacyInfo.xcprivacy", PrivacyInfoGenerator.generate(role: .extensionTarget)),
        ]
    }

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
    /// target. The host app declares the same group in its own entitlements
    /// (`EntitlementsGenerator` for `new`, `EntitlementsMerger` for `add`) so
    /// both ends resolve the same
    /// `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`;
    /// without it that call returns `nil` in the app.
    static func generateEntitlements(appGroup: String) -> String {
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
    /// provider returning the current `Date` once per hour. The commented
    /// sample reads shared state through `AppGroup`, which compiles into both
    /// the app and the widget, so the group identifier lives in one place.
    ///
    /// Widget views that need precise edge alignment should not combine
    /// `.contentMarginsDisabled()` with `.padding()` / `ZStack(alignment:)`:
    /// overlay positioning can differ under the widget runtime from what
    /// `ImageRenderer` shows. Position edge-anchored content with
    /// `GeometryReader` + `.offset(...)` instead.
    static func generateWidget(appName: String) -> String {
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
                // Read shared state the app wrote to the App Group container:
                //   let url = AppGroup.containerURL?.appendingPathComponent("widget.json")
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

            /// The shared container both targets can read and write. Keep the
            /// shared `UserDefaults(suiteName: identifier)` suite to a few
            /// small values, and put bulk data in a file here instead.
            static var containerURL: URL? {
                FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
            }
        }

        """
    }
}
