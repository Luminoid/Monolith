import Foundation

/// Builds the app target's `.entitlements` plist by composing capability blocks
/// from the resolved feature set.
///
/// Each block maps to a feature that needs entitlement keys:
/// - **App Group** (`hasWidget`): the host app and its widget resolve the same
///   `containerURL(forSecurityApplicationGroupIdentifier:)`.
/// - **CloudKit** (`hasCloudKit`): `aps-environment` (silent pushes),
///   the iCloud container identifier, the `CloudKit` service, and the
///   key-value-store identifier.
///
/// Emitting the CloudKit keys is what actually turns sync on. Without them
/// `NSPersistentCloudKitContainer` silently falls back to a local-only store
/// and `registerForRemoteNotifications()` fails at runtime — yet the Info.plist
/// (`CKSharingSupported`, `remote-notification` background mode), AppDelegate
/// (`registerForRemoteNotifications()`), and Core Data stack
/// (`NSPersistentCloudKitContainer`) are all already wired, so the omission is
/// invisible until an adopter tries to sync.
enum EntitlementsGenerator {
    /// Composes the app target's `.entitlements`.
    ///
    /// - Parameters:
    ///   - appGroup: App Group identifier (`group.<bundleID>`) when a widget or
    ///     other extension shares container state, else `nil`.
    ///   - cloudKitContainer: iCloud container identifier (`iCloud.<bundleID>`)
    ///     when CloudKit sync is enabled, else `nil`.
    ///   - apsEnvironment: APNs environment (`development`) when the app
    ///     registers for remote notifications (CloudKit silent pushes), else
    ///     `nil`. Xcode promotes this to `production` at distribution-signing
    ///     time, matching the workspace's hand-authored apps.
    /// - Returns: a well-formed entitlements plist. Callers must only invoke
    ///   this when at least one capability is present (`appGroup != nil ||
    ///   cloudKitContainer != nil`); an all-`nil` call yields an empty `<dict>`.
    static func appEntitlements(
        appGroup: String?,
        cloudKitContainer: String?,
        apsEnvironment: String?
    ) -> String {
        var entries: [String] = []

        if let apsEnvironment {
            entries.append("""
                <key>aps-environment</key>
                <string>\(apsEnvironment)</string>
            """)
        }

        if let cloudKitContainer {
            entries.append("""
                <key>com.apple.developer.icloud-container-identifiers</key>
                <array>
                    <string>\(cloudKitContainer)</string>
                </array>
                <key>com.apple.developer.icloud-services</key>
                <array>
                    <string>CloudKit</string>
                </array>
                <key>com.apple.developer.ubiquity-kvstore-identifier</key>
                <string>$(TeamIdentifierPrefix)$(CFBundleIdentifier)</string>
            """)
        }

        if let appGroup {
            entries.append("""
                <key>com.apple.security.application-groups</key>
                <array>
                    <string>\(appGroup)</string>
                </array>
            """)
        }

        let body = entries.joined(separator: "\n")
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        \(body)
        </dict>
        </plist>

        """
    }
}
