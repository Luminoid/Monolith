import Foundation
import Testing
@testable import MonolithLib

struct PrivacyInfoGeneratorTests {
    @Test
    func `app role gets UserDefaults reason by default`() {
        let output = PrivacyInfoGenerator.generate(role: .app)
        #expect(output.contains("NSPrivacyAccessedAPICategoryUserDefaults"))
        #expect(output.contains("CA92.1"))
    }

    @Test
    func `extension role declares empty API types array by default`() {
        let output = PrivacyInfoGenerator.generate(role: .extensionTarget)
        // Empty array form, not a populated one
        #expect(output.contains("<key>NSPrivacyAccessedAPITypes</key>"))
        #expect(output.contains("<array/>"))
        #expect(!output.contains("NSPrivacyAccessedAPICategoryUserDefaults"))
    }

    @Test
    func `baseline tracking flags are off`() {
        let output = PrivacyInfoGenerator.generate(role: .app)
        #expect(output.contains("<key>NSPrivacyTracking</key>"))
        #expect(output.contains("<false/>"))
        #expect(output.contains("<key>NSPrivacyTrackingDomains</key>"))
        #expect(output.contains("<key>NSPrivacyCollectedDataTypes</key>"))
    }

    @Test
    func `explicit empty categories override role defaults`() {
        let output = PrivacyInfoGenerator.generate(role: .app, categories: [])
        #expect(output.contains("<array/>"))
        #expect(!output.contains("CA92.1"))
    }

    @Test
    func `multiple categories produce multiple dict entries`() {
        let output = PrivacyInfoGenerator.generate(role: .app, categories: [.userDefaults, .diskSpace, .fileTimestamp])
        #expect(output.contains("NSPrivacyAccessedAPICategoryUserDefaults"))
        #expect(output.contains("NSPrivacyAccessedAPICategoryDiskSpace"))
        #expect(output.contains("NSPrivacyAccessedAPICategoryFileTimestamp"))
        #expect(output.contains("CA92.1"))
        #expect(output.contains("85F4.1"))
        #expect(output.contains("3B52.1"))
    }

    @Test
    func `output is well-formed XML plist`() {
        let output = PrivacyInfoGenerator.generate(role: .app)
        #expect(output.hasPrefix("<?xml"))
        #expect(output.contains("<!DOCTYPE plist"))
        #expect(output.contains("<plist version=\"1.0\">"))
        #expect(output.contains("</plist>"))
    }

    @Test
    func `header comment guides adopters`() {
        let output = PrivacyInfoGenerator.generate(role: .app)
        #expect(output.contains("App Store Connect"))
        #expect(output.contains("Edit before submission"))
    }
}
