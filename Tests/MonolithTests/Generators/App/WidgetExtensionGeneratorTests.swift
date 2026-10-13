import Foundation
import Testing
@testable import MonolithLib

struct WidgetExtensionGeneratorTests {
    @Test
    func `Info plist declares widgetkit extension point`() {
        let output = WidgetExtensionGenerator.generateInfoPlist()
        #expect(output.contains("com.apple.widgetkit-extension"))
        #expect(output.contains("NSExtensionPointIdentifier"))
    }

    @Test
    func `entitlements declare requested App Group`() throws {
        let output = WidgetExtensionGenerator.generateEntitlements(appGroup: "group.com.test.app")
        let plist = try PropertyListSerialization.propertyList(from: Data(output.utf8), format: nil) as? [String: Any]
        #expect(plist?["com.apple.security.application-groups"] as? [String] == ["group.com.test.app"])
    }

    @Test
    func `widget bundle uses appName as type prefix`() {
        let output = WidgetExtensionGenerator.generateBundle(appName: "MyApp")
        #expect(output.contains("struct MyAppWidgetBundle: WidgetBundle"))
        #expect(output.contains("MyAppWidget()"))
        #expect(output.contains("@main"))
    }

    @Test
    func `widget sample reads shared state through AppGroup`() {
        let output = WidgetExtensionGenerator.generateWidget(appName: "MyApp")
        #expect(output.contains("MyAppWidget"))
        #expect(output.contains("TimelineProvider"))
        #expect(output.contains("AppGroup.containerURL?.appendingPathComponent(\"widget.json\")"))
        #expect(!output.contains("forSecurityApplicationGroupIdentifier"), "the group identifier lives in AppGroup.swift only")
        #expect(output.contains("supportedFamilies"))
    }

    @Test
    func `App Group constants point bulk data at the container`() {
        let output = WidgetExtensionGenerator.generateAppGroupConstants(appGroup: "group.com.test.app")
        #expect(output.contains("static let identifier = \"group.com.test.app\""))
        #expect(output.contains("FileManager.default.containerURL"))
        #expect(output.contains("UserDefaults(suiteName: identifier)"))
        #expect(!output.contains("corrupt"))
    }

    @Test
    func `files include the widget's privacy manifest and not the app's entitlements`() {
        let paths = WidgetExtensionGenerator.files(appName: "MyApp", appGroup: "group.x").map(\.path)
        #expect(paths.contains("MyAppWidget/PrivacyInfo.xcprivacy"))
        #expect(paths.contains("MyApp/Shared/AppGroup.swift"))
        #expect(!paths.contains("MyApp/MyApp.entitlements"))
    }
}
