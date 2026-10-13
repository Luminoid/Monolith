import Foundation
import Testing
@testable import MonolithLib

struct EntitlementsMergerTests {
    private func dictionary(_ plist: String) throws -> [String: Any] {
        try #require(PropertyListSerialization.propertyList(from: Data(plist.utf8), format: nil) as? [String: Any])
    }

    /// The entitlements `new app --features cloudKit` writes.
    private let cloudKitEntitlements = EntitlementsGenerator.appEntitlements(
        appGroup: nil,
        cloudKitContainer: "iCloud.com.example.myapp",
        apsEnvironment: "development"
    )

    @Test
    func `an App Group merges into iCloud entitlements without dropping them`() throws {
        let merged = try EntitlementsMerger.merge(
            EntitlementsMerger.appGroupAdditions("group.com.example.myapp"),
            into: cloudKitEntitlements,
            path: "MyApp/MyApp.entitlements"
        )

        #expect(merged.changed)
        let plist = try dictionary(merged.content)
        #expect(plist["com.apple.security.application-groups"] as? [String] == ["group.com.example.myapp"])
        #expect(plist["com.apple.developer.icloud-container-identifiers"] as? [String] == ["iCloud.com.example.myapp"])
        #expect(plist["com.apple.developer.icloud-services"] as? [String] == ["CloudKit"])
        #expect(plist["aps-environment"] as? String == "development")
        #expect(plist["com.apple.developer.ubiquity-kvstore-identifier"] as? String == "$(TeamIdentifierPrefix)$(CFBundleIdentifier)")
    }

    @Test
    func `an App Group already declared is not added twice`() throws {
        let existing = EntitlementsGenerator.appEntitlements(appGroup: "group.a", cloudKitContainer: nil, apsEnvironment: nil)
        let merged = try EntitlementsMerger.merge(EntitlementsMerger.appGroupAdditions("group.a"), into: existing, path: "x")
        #expect(!merged.changed)
        #expect(try dictionary(merged.content)["com.apple.security.application-groups"] as? [String] == ["group.a"])
    }

    @Test
    func `a second App Group is appended after the existing one`() throws {
        let existing = EntitlementsGenerator.appEntitlements(appGroup: "group.a", cloudKitContainer: nil, apsEnvironment: nil)
        let merged = try EntitlementsMerger.merge(EntitlementsMerger.appGroupAdditions("group.b"), into: existing, path: "x")
        #expect(merged.changed)
        #expect(try dictionary(merged.content)["com.apple.security.application-groups"] as? [String] == ["group.a", "group.b"])
    }

    @Test
    func `an existing scalar keeps its value`() throws {
        let existing = EntitlementsGenerator.appEntitlements(appGroup: nil, cloudKitContainer: "iCloud.x", apsEnvironment: "production")
        let merged = try EntitlementsMerger.merge(["aps-environment": "development", "com.apple.security.app-sandbox": true], into: existing, path: "x")
        let plist = try dictionary(merged.content)
        #expect(plist["aps-environment"] as? String == "production")
        #expect(plist["com.apple.security.app-sandbox"] as? Bool == true)
    }

    @Test
    func `no file yet creates one`() throws {
        let merged = try EntitlementsMerger.merge(EntitlementsMerger.appGroupAdditions("group.a"), into: nil, path: "x")
        #expect(merged.changed)
        #expect(try dictionary(merged.content)["com.apple.security.application-groups"] as? [String] == ["group.a"])
    }

    @Test
    func `a malformed file is an error, not a replacement`() {
        #expect(throws: EntitlementsMerger.MergeError.self) {
            _ = try EntitlementsMerger.merge(EntitlementsMerger.appGroupAdditions("group.a"), into: "<plist><dict>", path: "x")
        }
    }
}
