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
    func `entitlements declare requested App Group`() {
        let output = WidgetExtensionGenerator.generateEntitlements(appGroup: "group.com.test.app")
        #expect(output.contains("application-groups"))
        #expect(output.contains("<string>group.com.test.app</string>"))
    }

    @Test
    func `widget bundle uses appName as type prefix`() {
        let output = WidgetExtensionGenerator.generateBundle(appName: "Petfolio")
        #expect(output.contains("struct PetfolioWidgetBundle: WidgetBundle"))
        #expect(output.contains("PetfolioWidget()"))
        #expect(output.contains("@main"))
    }

    @Test
    func `widget references the App Group in TODO`() {
        let output = WidgetExtensionGenerator.generateWidget(appName: "Petfolio", appGroup: "group.test")
        #expect(output.contains("PetfolioWidget"))
        #expect(output.contains("TimelineProvider"))
        #expect(output.contains("group.test"))
        #expect(output.contains("supportedFamilies"))
    }

    @Test
    func `App Group constants warn about UserDefaults size limit`() {
        let output = WidgetExtensionGenerator.generateAppGroupConstants(appGroup: "group.com.test.app")
        #expect(output.contains("group.com.test.app"))
        #expect(output.contains("4 MB"))
        #expect(output.contains("FileManager.default.containerURL"))
    }
}
