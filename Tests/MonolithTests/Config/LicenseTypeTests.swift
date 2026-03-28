import Foundation
import Testing
@testable import MonolithLib

struct LicenseTypeTests {
    @Test(arguments: LicenseType.allCases)
    func `displayName is non-empty for all cases`(type: LicenseType) {
        #expect(!type.displayName.isEmpty)
    }

    @Test(arguments: LicenseType.allCases)
    func `shortDescription is non-empty for all cases`(type: LicenseType) {
        #expect(!type.shortDescription.isEmpty)
    }

    @Test
    func `defaultFor returns proprietary for app`() {
        #expect(LicenseType.defaultFor(.app) == .proprietary)
    }

    @Test
    func `defaultFor returns mit for package`() {
        #expect(LicenseType.defaultFor(.package) == .mit)
    }

    @Test
    func `defaultFor returns apache2 for cli`() {
        #expect(LicenseType.defaultFor(.cli) == .apache2)
    }

    @Test(arguments: LicenseType.allCases)
    func `Codable round-trip preserves value`(type: LicenseType) throws {
        let data = try JSONEncoder().encode(type)
        let decoded = try JSONDecoder().decode(LicenseType.self, from: data)
        #expect(decoded == type)
    }

    @Test
    func `raw values match expected strings`() {
        #expect(LicenseType.mit.rawValue == "mit")
        #expect(LicenseType.apache2.rawValue == "apache2")
        #expect(LicenseType.proprietary.rawValue == "proprietary")
    }
}
