import Foundation
import Testing
@testable import MonolithLib

@Suite("LicenseChangelogGenerator")
struct LicenseChangelogGeneratorTests {
    @Test("MIT license contains MIT text")
    func mitLicense() {
        let output = LicenseChangelogGenerator.generateLicense(author: "Test Author", type: .mit)
        #expect(output.contains("MIT License"))
        #expect(output.contains("Permission is hereby granted"))
    }

    @Test("Apache 2.0 license contains Apache text")
    func apache2License() {
        let output = LicenseChangelogGenerator.generateLicense(author: "Test Author", type: .apache2)
        #expect(output.contains("Apache License"))
        #expect(output.contains("Version 2.0"))
        #expect(output.contains("Grant of Patent License"))
    }

    @Test("Proprietary license contains all rights reserved")
    func proprietaryLicense() {
        let output = LicenseChangelogGenerator.generateLicense(author: "Test Author", type: .proprietary)
        #expect(output.contains("All rights reserved"))
        #expect(output.contains("proprietary and confidential"))
        #expect(!output.contains("MIT"))
        #expect(!output.contains("Apache"))
    }

    @Test("default type is MIT")
    func defaultTypeIsMIT() {
        let output = LicenseChangelogGenerator.generateLicense(author: "Test")
        #expect(output.contains("MIT License"))
    }

    @Test("license contains author for all types", arguments: LicenseType.allCases)
    func allTypesContainAuthor(type: LicenseType) {
        let output = LicenseChangelogGenerator.generateLicense(author: "Jane Doe", type: type)
        #expect(output.contains("Jane Doe"))
    }

    @Test("license contains current year for all types", arguments: LicenseType.allCases)
    func allTypesContainYear(type: LicenseType) {
        let year = Calendar.current.component(.year, from: Date())
        let output = LicenseChangelogGenerator.generateLicense(author: "Test", type: type)
        #expect(output.contains(String(year)))
    }

    @Test("changelog follows Keep a Changelog format")
    func changelogFormat() {
        let output = LicenseChangelogGenerator.generateChangelog()
        #expect(output.contains("# Changelog"))
        #expect(output.contains("Keep a Changelog"))
        #expect(output.contains("Semantic Versioning"))
        #expect(output.contains("[Unreleased]"))
        #expect(output.contains("### Added"))
    }
}
