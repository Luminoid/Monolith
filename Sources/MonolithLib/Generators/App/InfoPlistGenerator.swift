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

        static let empty = Self()
    }

    static func generate(options: Options = .empty) -> String {
        var lines: [String] = []
        lines.append("""
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
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
            lines.append("            <key>CFBundleURLSchemes</key>")
            lines.append("            <array>")
            for scheme in options.urlSchemes {
                lines.append("                <string>\(scheme)</string>")
            }
            lines.append("            </array>")
            lines.append("        </dict>")
            lines.append("    </array>")
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
