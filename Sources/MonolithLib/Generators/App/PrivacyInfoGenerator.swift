import Foundation

/// Generates a PrivacyInfo.xcprivacy manifest. Apple requires one per shipped bundle
/// (app, widget extension, share extension, embedded framework). At App Store upload
/// the manifests are concatenated; missing files surface as "Missing API usage
/// description" feedback in App Store Connect.
///
/// The generator emits a baseline manifest with:
/// - NSPrivacyTracking = false
/// - empty tracking domains
/// - empty collected data types
/// - declared required-reason APIs derived from the requested category set
///
/// Apps that actually track users or collect data must edit the generated file
/// before submission. The header comment in the output explains how.
enum PrivacyInfoGenerator {
    /// A required-reason API category and its declared reason codes.
    /// Reason codes are the four-character identifiers Apple publishes at
    /// https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
    struct APICategory {
        let name: String
        let reasons: [String]

        /// `UserDefaults` read/write of this bundle's own defaults.
        static let userDefaults = Self(
            name: "NSPrivacyAccessedAPICategoryUserDefaults",
            reasons: ["CA92.1"]
        )

        /// Free disk space checks before writes.
        static let diskSpace = Self(
            name: "NSPrivacyAccessedAPICategoryDiskSpace",
            reasons: ["85F4.1"]
        )

        /// File timestamps (FileManager attributes, URLResourceKey creation/modification).
        /// `3B52.1` = user-initiated access (export/import flows).
        /// `C617.1` = display timestamps to user.
        static let fileTimestamp = Self(
            name: "NSPrivacyAccessedAPICategoryFileTimestamp",
            reasons: ["3B52.1"]
        )

        /// `systemUptime` / `kern.boottime`. Declare only if shipped in Release.
        static let systemBootTime = Self(
            name: "NSPrivacyAccessedAPICategorySystemBootTime",
            reasons: ["35F9.1"]
        )

        /// Active keyboard list. Rarely used; declare if reading installed keyboards.
        static let activeKeyboards = Self(
            name: "NSPrivacyAccessedAPICategoryActiveKeyboards",
            reasons: ["54BD.1"]
        )
    }

    /// Bundle role determines the sensible-default API category set.
    /// - app: opens UserDefaults at minimum.
    /// - extension: usually only touches the App Group container.
    enum BundleRole {
        case app
        case extensionTarget
    }

    /// Generate a PrivacyInfo.xcprivacy XML plist.
    /// - Parameters:
    ///   - role: the bundle's role (drives the default category set).
    ///   - categories: explicit category overrides. If `nil`, sensible defaults
    ///     for the role are used. Pass `[]` to declare "considered and declared none."
    static func generate(role: BundleRole, categories: [APICategory]? = nil) -> String {
        let resolved = categories ?? defaultCategories(for: role)
        var lines: [String] = []

        lines.append("""
        <?xml version="1.0" encoding="UTF-8"?>
        <!--
          PrivacyInfo.xcprivacy — required by App Store Connect for every shipped bundle
          (app, widget extension, share extension, embedded framework).

          Edit before submission if your app:
            - tracks users → set NSPrivacyTracking to true and list domains
            - collects data → add NSPrivacyCollectedDataType entries
            - uses required-reason APIs not declared below → add categories

          Reference: https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
        -->
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>NSPrivacyTracking</key>
            <false/>
            <key>NSPrivacyTrackingDomains</key>
            <array/>
            <key>NSPrivacyCollectedDataTypes</key>
            <array/>
            <key>NSPrivacyAccessedAPITypes</key>
        """)

        if resolved.isEmpty {
            lines.append("    <array/>")
        } else {
            lines.append("    <array>")
            for category in resolved {
                lines.append("        <dict>")
                lines.append("            <key>NSPrivacyAccessedAPIType</key>")
                lines.append("            <string>\(category.name)</string>")
                lines.append("            <key>NSPrivacyAccessedAPITypeReasons</key>")
                lines.append("            <array>")
                for reason in category.reasons {
                    lines.append("                <string>\(reason)</string>")
                }
                lines.append("            </array>")
                lines.append("        </dict>")
            }
            lines.append("    </array>")
        }

        lines.append("""
        </dict>
        </plist>

        """)

        return lines.joined(separator: "\n")
    }

    /// Sensible defaults: apps declare UserDefaults; extensions declare nothing
    /// (App Group container access via FileManager is not in any required-reason
    /// category). Adjust per project.
    static func defaultCategories(for role: BundleRole) -> [APICategory] {
        switch role {
        case .app: [.userDefaults]
        case .extensionTarget: []
        }
    }
}
