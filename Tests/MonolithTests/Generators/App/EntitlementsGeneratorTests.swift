import Foundation
import Testing
@testable import MonolithLib

struct EntitlementsGeneratorTests {
    @Test
    func `widget-only app declares the App Group and nothing else`() {
        let output = EntitlementsGenerator.appEntitlements(
            appGroup: "group.com.test.app",
            cloudKitContainer: nil,
            apsEnvironment: nil
        )
        #expect(output.contains("com.apple.security.application-groups"))
        #expect(output.contains("group.com.test.app"))
        #expect(!output.contains("icloud"))
        #expect(!output.contains("aps-environment"))
    }

    @Test
    func `CloudKit app declares iCloud container, service, kvstore, and aps environment`() {
        let output = EntitlementsGenerator.appEntitlements(
            appGroup: nil,
            cloudKitContainer: "iCloud.com.test.app",
            apsEnvironment: "development"
        )
        #expect(output.contains("<key>aps-environment</key>"))
        #expect(output.contains("<string>development</string>"))
        #expect(output.contains("com.apple.developer.icloud-container-identifiers"))
        #expect(output.contains("<string>iCloud.com.test.app</string>"))
        #expect(output.contains("com.apple.developer.icloud-services"))
        #expect(output.contains("<string>CloudKit</string>"))
        #expect(output.contains("com.apple.developer.ubiquity-kvstore-identifier"))
        // No App Group when there's no widget sharing state.
        #expect(!output.contains("application-groups"))
    }

    @Test
    func `CloudKit app with a widget declares both capabilities`() {
        let output = EntitlementsGenerator.appEntitlements(
            appGroup: "group.com.test.app",
            cloudKitContainer: "iCloud.com.test.app",
            apsEnvironment: "development"
        )
        #expect(output.contains("com.apple.security.application-groups"))
        #expect(output.contains("com.apple.developer.icloud-services"))
        #expect(output.contains("aps-environment"))
    }

    @Test
    func `output is a well-formed plist that parses`() throws {
        let output = EntitlementsGenerator.appEntitlements(
            appGroup: "group.com.test.app",
            cloudKitContainer: "iCloud.com.test.app",
            apsEnvironment: "development"
        )
        let data = try #require(output.data(using: .utf8))
        // Throws if the generated XML is malformed — guards against indentation
        // bugs in the composed-block string building.
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        let dict = try #require(plist as? [String: Any])
        #expect(dict["aps-environment"] as? String == "development")
        let containers = try #require(dict["com.apple.developer.icloud-container-identifiers"] as? [String])
        #expect(containers == ["iCloud.com.test.app"])
        let groups = try #require(dict["com.apple.security.application-groups"] as? [String])
        #expect(groups == ["group.com.test.app"])
    }

    // MARK: - Mac Catalyst

    private func parse(_ output: String) throws -> [String: Any] {
        let plist = try PropertyListSerialization.propertyList(from: Data(output.utf8), format: nil)
        return try #require(plist as? [String: Any])
    }

    @Test
    func `Mac Catalyst file adds the sandbox and network keys to the iOS capabilities`() throws {
        let ios = try parse(EntitlementsGenerator.appEntitlements(
            appGroup: "group.com.test.app", cloudKitContainer: "iCloud.com.test.app", apsEnvironment: "development"
        ))
        let mac = try parse(EntitlementsGenerator.macCatalystEntitlements(
            appGroup: "group.com.test.app", cloudKitContainer: "iCloud.com.test.app", apsEnvironment: "development"
        ))
        #expect(mac["com.apple.security.app-sandbox"] as? Bool == true)
        #expect(mac["com.apple.security.network.client"] as? Bool == true)
        #expect(Set(mac.keys).subtracting(ios.keys) == ["com.apple.security.app-sandbox", "com.apple.security.network.client"])
        #expect(Set(ios.keys).isSubset(of: mac.keys))
        #expect(mac["aps-environment"] as? String == "development")
    }

    @Test
    func `plain Mac Catalyst app is sandboxed with network access only`() throws {
        let mac = try parse(EntitlementsGenerator.macCatalystEntitlements(appGroup: nil, cloudKitContainer: nil, apsEnvironment: nil))
        #expect(Set(mac.keys) == ["com.apple.security.app-sandbox", "com.apple.security.network.client"])
    }

    @Test
    func `entitlement paths sit beside the app sources`() {
        #expect(EntitlementsGenerator.appPath(appName: "MyApp") == "MyApp/MyApp.entitlements")
        #expect(EntitlementsGenerator.macCatalystPath(appName: "MyApp") == "MyApp/MyApp-MacCatalyst.entitlements")
    }
}
