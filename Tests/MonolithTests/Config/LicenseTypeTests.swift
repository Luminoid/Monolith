import Foundation
import Testing
@testable import MonolithLib

@Suite("LicenseType")
struct LicenseTypeTests {
    @Test("displayName is non-empty for all cases", arguments: LicenseType.allCases)
    func displayNameNonEmpty(type: LicenseType) {
        #expect(!type.displayName.isEmpty)
    }

    @Test("shortDescription is non-empty for all cases", arguments: LicenseType.allCases)
    func shortDescriptionNonEmpty(type: LicenseType) {
        #expect(!type.shortDescription.isEmpty)
    }

    @Test("defaultFor returns proprietary for app")
    func defaultForApp() {
        #expect(LicenseType.defaultFor(.app) == .proprietary)
    }

    @Test("defaultFor returns mit for package")
    func defaultForPackage() {
        #expect(LicenseType.defaultFor(.package) == .mit)
    }

    @Test("defaultFor returns apache2 for cli")
    func defaultForCLI() {
        #expect(LicenseType.defaultFor(.cli) == .apache2)
    }

    @Test("Codable round-trip preserves value", arguments: LicenseType.allCases)
    func codableRoundTrip(type: LicenseType) throws {
        let data = try JSONEncoder().encode(type)
        let decoded = try JSONDecoder().decode(LicenseType.self, from: data)
        #expect(decoded == type)
    }

    @Test("raw values match expected strings")
    func rawValues() {
        #expect(LicenseType.mit.rawValue == "mit")
        #expect(LicenseType.apache2.rawValue == "apache2")
        #expect(LicenseType.proprietary.rawValue == "proprietary")
    }
}
