import Foundation

/// Builds the app target's `.entitlements` plists by composing capability
/// blocks from the resolved feature set.
///
/// Each block maps to a feature that needs entitlement keys:
/// - **App Group** (`hasWidget`): the host app and its widget resolve the same
///   `containerURL(forSecurityApplicationGroupIdentifier:)`.
/// - **CloudKit** (`hasCloudKit`): `aps-environment` (silent pushes),
///   the iCloud container identifier, the `CloudKit` service, and the
///   key-value-store identifier.
/// - **Mac Catalyst** (`hasMacCatalyst`): a second file for the Mac build with
///   the same keys plus App Sandbox and outgoing network access. The Mac App
///   Store rejects an unsandboxed app, and a sandboxed app without
///   `network.client` can't reach CloudKit or any other server.
///
/// Emitting the CloudKit keys is what actually turns sync on. Without them
/// `NSPersistentCloudKitContainer` silently falls back to a local-only store
/// and `registerForRemoteNotifications()` fails at runtime — yet the Info.plist
/// (`CKSharingSupported`, `remote-notification` background mode), AppDelegate
/// (`registerForRemoteNotifications()`), and Core Data stack
/// (`NSPersistentCloudKitContainer`) are all already wired, so the omission is
/// invisible until an adopter tries to sync.
enum EntitlementsGenerator {
    /// The iOS entitlements file, relative to the project root.
    static func appPath(appName: String) -> String {
        "\(appName)/\(appName).entitlements"
    }

    /// The Mac Catalyst entitlements file, relative to the project root. The
    /// app target points `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]` at it.
    static func macCatalystPath(appName: String) -> String {
        "\(appName)/\(appName)-MacCatalyst.entitlements"
    }

    /// Composes the app target's iOS `.entitlements`.
    ///
    /// - Parameters:
    ///   - appGroup: App Group identifier (`group.<bundleID>`) when a widget or
    ///     other extension shares container state, else `nil`.
    ///   - cloudKitContainer: iCloud container identifier (`iCloud.<bundleID>`)
    ///     when CloudKit sync is enabled, else `nil`.
    ///   - apsEnvironment: APNs environment (`development`) when the app
    ///     registers for remote notifications (CloudKit silent pushes), else
    ///     `nil`. Xcode promotes this to `production` at distribution-signing
    ///     time.
    /// - Returns: a well-formed entitlements plist. Callers must only invoke
    ///   this when at least one capability is present (`appGroup != nil ||
    ///   cloudKitContainer != nil`); an all-`nil` call yields an empty `<dict>`.
    static func appEntitlements(
        appGroup: String?,
        cloudKitContainer: String?,
        apsEnvironment: String?
    ) -> String {
        plist(entries: capabilityEntries(
            appGroup: appGroup,
            cloudKitContainer: cloudKitContainer,
            apsEnvironment: apsEnvironment
        ))
    }

    /// Composes the Mac Catalyst `.entitlements`: App Sandbox and outgoing
    /// network access, then the same capability keys as the iOS file. Valid
    /// with every capability `nil` (a plain Catalyst app still needs the
    /// sandbox). `aps-environment` keeps the iOS spelling, which is what
    /// Xcode's Push Notifications capability writes for a Catalyst target.
    static func macCatalystEntitlements(
        appGroup: String?,
        cloudKitContainer: String?,
        apsEnvironment: String?
    ) -> String {
        let sandbox = """
            <key>com.apple.security.app-sandbox</key>
            <true/>
            <key>com.apple.security.network.client</key>
            <true/>
        """
        return plist(entries: [sandbox] + capabilityEntries(
            appGroup: appGroup,
            cloudKitContainer: cloudKitContainer,
            apsEnvironment: apsEnvironment
        ))
    }

    // MARK: - Helpers

    private static func capabilityEntries(
        appGroup: String?,
        cloudKitContainer: String?,
        apsEnvironment: String?
    ) -> [String] {
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

        return entries
    }

    private static func plist(entries: [String]) -> String {
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
