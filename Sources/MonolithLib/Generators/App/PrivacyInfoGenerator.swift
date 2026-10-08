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

        /// Free disk space checks before writes (`E174.1`). `85F4.1` is only for
        /// showing free space to the user.
        static let diskSpace = Self(
            name: "NSPrivacyAccessedAPICategoryDiskSpace",
            reasons: ["E174.1"]
        )

        /// File timestamps (FileManager attributes, URLResourceKey creation/modification).
        /// `C617.1` = files inside the app, App Group, or CloudKit container (the
        /// common case, and the one declared here).
        /// `3B52.1` = files the user granted access to (document picker imports).
        /// `DDA9.1` = showing timestamps to the user.
        static let fileTimestamp = Self(
            name: "NSPrivacyAccessedAPICategoryFileTimestamp",
            reasons: ["C617.1"]
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

        // The header lists ready-to-paste API category snippets for the
        // categories apps reach for most: UserDefaults, file timestamps, and
        // disk space. Apps that touch UserDefaults anywhere (including
        // @AppStorage and App Group defaults) MUST declare CA92.1, so the
        // comment makes it obvious which block to copy out of the comment
        // and into the array.
        lines.append("""
        <?xml version="1.0" encoding="UTF-8"?>
        <!--
          PrivacyInfo.xcprivacy — required by App Store Connect for every shipped bundle
          (app, widget extension, share extension, embedded framework).

          Apple's automated check (run at upload) compares this manifest against
          the set of required-reason APIs your binary actually links. Declare
          ONLY the categories you actually use. Common additions (paste inside
          the NSPrivacyAccessedAPITypes array and reorder as needed):

            UserDefaults (any UserDefaults call, including @AppStorage / App Group):
              <dict>
                  <key>NSPrivacyAccessedAPIType</key>
                  <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
                  <key>NSPrivacyAccessedAPITypeReasons</key>
                  <array><string>CA92.1</string></array>
              </dict>

            FileTimestamp (FileManager.attributesOfItem, URLResourceKey creation/modification
            of files in the app, App Group, or CloudKit container; add 3B52.1 for files
            the user picked with a document picker):
              <dict>
                  <key>NSPrivacyAccessedAPIType</key>
                  <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
                  <key>NSPrivacyAccessedAPITypeReasons</key>
                  <array><string>C617.1</string></array>
              </dict>

            DiskSpace (volumeAvailableCapacity*, systemFreeSize):
              <dict>
                  <key>NSPrivacyAccessedAPIType</key>
                  <string>NSPrivacyAccessedAPICategoryDiskSpace</string>
                  <key>NSPrivacyAccessedAPITypeReasons</key>
                  <array><string>E174.1</string></array>
              </dict>

          Edit before submission if your app:
            - tracks users → set NSPrivacyTracking to true and list domains
            - collects data → add NSPrivacyCollectedDataType entries

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

    /// Sensible defaults: an empty `<array/>` for both roles, for a bundle
    /// whose own code calls no required-reason API. Callers that know what
    /// the bundle links pass `categories` (see `appCategories`). The header
    /// comment in the manifest lists ready-to-paste snippets for adopters to
    /// add once they touch a required-reason API. An empty array is not a
    /// safe default for code that does use one: App Store Connect flags every
    /// required-reason API the binary links but the manifest leaves out
    /// (ITMS-91053), so add the category as soon as the code uses it.
    static func defaultCategories(for role: BundleRole) -> [APICategory] {
        switch role {
        case .app: []
        case .extensionTarget: []
        }
    }

    /// The required-reason categories a generated app's own code reaches.
    /// - Every CloudKit app keeps its opt-in sync preference in
    ///   `UserDefaults` (`CA92.1`).
    /// - LumiKit is linked statically into the app binary, and it reads
    ///   `UserDefaults` and file modification dates in its own containers
    ///   (`CA92.1`, `C617.1`).
    /// Returns `[]` when neither applies, which renders as `<array/>`.
    static func appCategories(hasCloudKit: Bool, hasLumiKit: Bool) -> [APICategory] {
        var categories: [APICategory] = []
        if hasCloudKit || hasLumiKit {
            categories.append(.userDefaults)
        }
        if hasLumiKit {
            categories.append(.fileTimestamp)
        }
        return categories
    }
}
