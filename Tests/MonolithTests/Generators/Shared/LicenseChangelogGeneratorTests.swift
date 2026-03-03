import Foundation
import Testing
@testable import MonolithLib

@Suite("LicenseChangelogGenerator")
struct LicenseChangelogGeneratorTests {
    @Test("license contains MIT text")
    func licenseIsMIT() {
        let output = LicenseChangelogGenerator.generateLicense(author: "Test Author")
        #expect(output.contains("MIT License"))
        #expect(output.contains("Permission is hereby granted"))
    }

    @Test("license contains author name")
    func licenseAuthorName() {
        let output = LicenseChangelogGenerator.generateLicense(author: "John Doe")
        #expect(output.contains("John Doe"))
    }

    @Test("license contains current year")
    func licenseCurrentYear() {
        let year = Calendar.current.component(.year, from: Date())
        let output = LicenseChangelogGenerator.generateLicense(author: "Test")
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
