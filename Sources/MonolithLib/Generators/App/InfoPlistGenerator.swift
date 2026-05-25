/// Generates the app's Info.plist.
///
/// The base manifest is the scene/orientation skeleton Xcode produces for a fresh
/// iOS project. Optional sections are appended when the corresponding usage is
/// requested via `Options`. Apps that adopt features Apple gates behind a usage
/// description (photo library, camera, location, microphone, etc.) MUST set the
/// usage string before App Review or face automatic rejection.
enum InfoPlistGenerator {
    /// Optional Info.plist entries. Each requested field is appended to the base
    /// dict. Caller controls the strings so apps can match their UX copy.
    struct Options {
        var photoLibraryUsageDescription: String?
        var cameraUsageDescription: String?
        var microphoneUsageDescription: String?
        var locationWhenInUseUsageDescription: String?
        var locationAlwaysUsageDescription: String?
        var contactsUsageDescription: String?
        var calendarUsageDescription: String?
        var faceIDUsageDescription: String?
        var userNotificationsUsageDescription: String?
        var bluetoothUsageDescription: String?

        /// `UIBackgroundModes` flags. Common values:
        /// - "remote-notification" (required for CloudKit silent push)
        /// - "fetch" (background app refresh)
        /// - "processing" (BGProcessingTaskRequest)
        /// - "audio", "location", "voip", etc.
        var backgroundModes: [String] = []

        /// Sets `CKSharingSupported = true`. Required for CloudKit shared-database
        /// acceptance flow (Family Sharing-style sharing).
        var cloudKitSharing: Bool = false

        /// URL schemes registered for deep linking, e.g. ["myapp"].
        var urlSchemes: [String] = []

        /// Reverse-DNS identifier used as `CFBundleURLName` when `urlSchemes` is
        /// non-empty. Apple recommends setting this so system tools can
        /// disambiguate URL handler identity if multiple apps register the
        /// same scheme. Typically the app's bundle ID (`dev.luminoid.pharos`).
        var urlIdentifier: String?

        /// `LSApplicationCategoryType`. Required for Mac App Store distribution
        /// (App Store Connect rejects uploads silently otherwise; the archive
        /// warning is non-fatal so adopters miss it). Defaults to nil — caller
        /// should pass the appropriate `public.app-category.<X>` string.
        /// See: https://developer.apple.com/documentation/bundleresources/information_property_list/lsapplicationcategorytype
        var applicationCategoryType: String?

        static let empty = Self()
    }

    static func generate(options: Options = .empty) -> String {
        var lines: [String] = []
        // Standard bundle metadata keys backed by Xcode build variables.
        // These get auto-merged into the binary's Info.plist when
        // `GENERATE_INFOPLIST_FILE = YES`; since the generator ships a
        // hand-written file with `GENERATE_INFOPLIST_FILE = NO` (see
        // `XcodeGenGenerator`), we have to declare them ourselves or the
        // simulator's launch process fails with "Missing bundle ID" or worse.
        // The `$(VARIABLE)` form resolves at build time from the target's
        // build settings — `PRODUCT_BUNDLE_IDENTIFIER`, `MARKETING_VERSION`,
        // `CURRENT_PROJECT_VERSION`, etc. all live in `project.pbxproj`.
        lines.append("""
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleDevelopmentRegion</key>
            <string>$(DEVELOPMENT_LANGUAGE)</string>
            <key>CFBundleExecutable</key>
            <string>$(EXECUTABLE_NAME)</string>
            <key>CFBundleIdentifier</key>
            <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
            <key>CFBundleInfoDictionaryVersion</key>
            <string>6.0</string>
            <key>CFBundleName</key>
            <string>$(PRODUCT_NAME)</string>
            <key>CFBundleDisplayName</key>
            <string>$(PRODUCT_NAME)</string>
            <key>CFBundlePackageType</key>
            <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
            <key>CFBundleShortVersionString</key>
            <string>$(MARKETING_VERSION)</string>
            <key>CFBundleVersion</key>
            <string>$(CURRENT_PROJECT_VERSION)</string>
            <key>LSRequiresIPhoneOS</key>
            <true/>
            <key>UIApplicationSceneManifest</key>
            <dict>
                <key>UIApplicationSupportsMultipleScenes</key>
                <false/>
                <key>UISceneConfigurations</key>
                <dict>
                    <key>UIWindowSceneSessionRoleApplication</key>
                    <array>
                        <dict>
                            <key>UISceneConfigurationName</key>
                            <string>Default Configuration</string>
                            <key>UISceneDelegateClassName</key>
                            <string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
                        </dict>
                    </array>
                </dict>
            </dict>
            <key>UILaunchScreen</key>
            <dict/>
            <key>UISupportedInterfaceOrientations</key>
            <array>
                <string>UIInterfaceOrientationPortrait</string>
            </array>
            <key>UISupportedInterfaceOrientations~ipad</key>
            <array>
                <string>UIInterfaceOrientationLandscapeLeft</string>
                <string>UIInterfaceOrientationLandscapeRight</string>
                <string>UIInterfaceOrientationPortrait</string>
                <string>UIInterfaceOrientationPortraitUpsideDown</string>
            </array>
        """)

        appendUsageString(&lines, key: "NSPhotoLibraryUsageDescription", value: options.photoLibraryUsageDescription)
        appendUsageString(&lines, key: "NSCameraUsageDescription", value: options.cameraUsageDescription)
        appendUsageString(&lines, key: "NSMicrophoneUsageDescription", value: options.microphoneUsageDescription)
        appendUsageString(&lines, key: "NSLocationWhenInUseUsageDescription", value: options.locationWhenInUseUsageDescription)
        appendUsageString(&lines, key: "NSLocationAlwaysAndWhenInUseUsageDescription", value: options.locationAlwaysUsageDescription)
        appendUsageString(&lines, key: "NSContactsUsageDescription", value: options.contactsUsageDescription)
        appendUsageString(&lines, key: "NSCalendarsUsageDescription", value: options.calendarUsageDescription)
        appendUsageString(&lines, key: "NSFaceIDUsageDescription", value: options.faceIDUsageDescription)
        appendUsageString(&lines, key: "NSUserNotificationsUsageDescription", value: options.userNotificationsUsageDescription)
        appendUsageString(&lines, key: "NSBluetoothAlwaysUsageDescription", value: options.bluetoothUsageDescription)

        if !options.backgroundModes.isEmpty {
            lines.append("    <key>UIBackgroundModes</key>")
            lines.append("    <array>")
            for mode in options.backgroundModes {
                lines.append("        <string>\(mode)</string>")
            }
            lines.append("    </array>")
        }

        if options.cloudKitSharing {
            lines.append("    <key>CKSharingSupported</key>")
            lines.append("    <true/>")
        }

        if !options.urlSchemes.isEmpty {
            lines.append("    <key>CFBundleURLTypes</key>")
            lines.append("    <array>")
            lines.append("        <dict>")
            // CFBundleURLName is Apple's recommended reverse-DNS identifier for
            // disambiguating URL handler identity when multiple apps register
            // the same scheme. Defaults to the bundle ID. Without it, system
            // tools (Settings → Default Apps for URLs, Universal Links
            // disambiguation, etc.) can't tell competing handlers apart.
            if let identifier = options.urlIdentifier, !identifier.isEmpty {
                lines.append("            <key>CFBundleURLName</key>")
                lines.append("            <string>\(identifier)</string>")
            }
            lines.append("            <key>CFBundleURLSchemes</key>")
            lines.append("            <array>")
            for scheme in options.urlSchemes {
                lines.append("                <string>\(scheme)</string>")
            }
            lines.append("            </array>")
            lines.append("        </dict>")
            lines.append("    </array>")
        }

        if let category = options.applicationCategoryType, !category.isEmpty {
            lines.append("    <key>LSApplicationCategoryType</key>")
            lines.append("    <string>\(category)</string>")
        }

        lines.append("""
        </dict>
        </plist>

        """)

        return lines.joined(separator: "\n")
    }

    private static func appendUsageString(_ lines: inout [String], key: String, value: String?) {
        guard let value, !value.isEmpty else { return }
        lines.append("    <key>\(key)</key>")
        lines.append("    <string>\(value)</string>")
    }
}
