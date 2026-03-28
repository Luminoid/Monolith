import Foundation
import Testing
@testable import MonolithLib

struct LicenseChangelogGeneratorTests {
    @Test
    func `MIT license contains MIT text`() {
        let output = LicenseChangelogGenerator.generateLicense(author: "Test Author", type: .mit)
        #expect(output.contains("MIT License"))
        #expect(output.contains("Permission is hereby granted"))
    }

    @Test
    func `Apache 2.0 license contains Apache text`() {
        let output = LicenseChangelogGenerator.generateLicense(author: "Test Author", type: .apache2)
        #expect(output.contains("Apache License"))
        #expect(output.contains("Version 2.0"))
        #expect(output.contains("Grant of Patent License"))
    }

    @Test
    func `Proprietary license contains all rights reserved`() {
        let output = LicenseChangelogGenerator.generateLicense(author: "Test Author", type: .proprietary)
        #expect(output.contains("All rights reserved"))
        #expect(output.contains("proprietary and confidential"))
        #expect(!output.contains("MIT"))
        #expect(!output.contains("Apache"))
    }

    @Test
    func `default type is MIT`() {
        let output = LicenseChangelogGenerator.generateLicense(author: "Test")
        #expect(output.contains("MIT License"))
    }

    @Test(arguments: LicenseType.allCases)
    func `license contains author for all types`(type: LicenseType) {
        let output = LicenseChangelogGenerator.generateLicense(author: "Jane Doe", type: type)
        #expect(output.contains("Jane Doe"))
    }

    @Test(arguments: LicenseType.allCases)
    func `license contains current year for all types`(type: LicenseType) {
        let year = Calendar.current.component(.year, from: Date())
        let output = LicenseChangelogGenerator.generateLicense(author: "Test", type: type)
        #expect(output.contains(String(year)))
    }

    @Test
    func `changelog follows Keep a Changelog format`() {
        let output = LicenseChangelogGenerator.generateChangelog()
        #expect(output.contains("# Changelog"))
        #expect(output.contains("Keep a Changelog"))
        #expect(output.contains("Semantic Versioning"))
        #expect(output.contains("[Unreleased]"))
        #expect(output.contains("### Added"))
    }
}
