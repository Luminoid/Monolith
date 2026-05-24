import Foundation
import Testing
@testable import MonolithLib

struct PrivacyInfoGeneratorTests {
    /// Strip the leading `<!-- ... -->` comment so substring assertions can
    /// distinguish "declared in the manifest body" from "mentioned in the
    /// header's paste-this-snippet documentation."
    private func bodyOnly(_ output: String) -> String {
        guard let commentEnd = output.range(of: "-->") else { return output }
        return String(output[commentEnd.upperBound...])
    }

    @Test
    func `app role declares empty API types array by default`() {
        // Previously emitted `NSPrivacyAccessedAPICategoryUserDefaults` with
        // reason `CA92.1` by default. That's now an over-declaration — the
        // freshly-scaffolded app has no actual `UserDefaults` call, so
        // declaring the category would mismatch the binary. Adopters paste
        // the category in once they touch a required-reason API; the header
        // comment shows them how.
        let output = PrivacyInfoGenerator.generate(role: .app)
        let body = bodyOnly(output)
        #expect(body.contains("<key>NSPrivacyAccessedAPITypes</key>"))
        #expect(body.contains("<array/>"))
        #expect(!body.contains("NSPrivacyAccessedAPICategoryUserDefaults"))
    }

    @Test
    func `extension role also declares empty API types array`() {
        let output = PrivacyInfoGenerator.generate(role: .extensionTarget)
        let body = bodyOnly(output)
        #expect(body.contains("<key>NSPrivacyAccessedAPITypes</key>"))
        #expect(body.contains("<array/>"))
        #expect(!body.contains("NSPrivacyAccessedAPICategoryUserDefaults"))
    }

    @Test
    func `header comment lists ready-to-paste category snippets`() {
        // The header now carries paste-ready snippets for the four most
        // common required-reason categories. The snippets are documentation,
        // not active declarations — they live before the `</comment>`.
        let output = PrivacyInfoGenerator.generate(role: .app)
        #expect(output.contains("NSPrivacyAccessedAPICategoryUserDefaults"))
        #expect(output.contains("CA92.1"))
        #expect(output.contains("NSPrivacyAccessedAPICategoryFileTimestamp"))
        #expect(output.contains("NSPrivacyAccessedAPICategoryDiskSpace"))
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
        let body = bodyOnly(output)
        #expect(body.contains("<array/>"))
        #expect(!body.contains("CA92.1"))
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
