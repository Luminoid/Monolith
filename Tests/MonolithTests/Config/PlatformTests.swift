import Foundation
import Testing
@testable import MonolithLib

struct PlatformTests {
    @Test
    func `parseList accepts canonical names`() throws {
        let result = try Platform.parseList("iPhone,iPad,macCatalyst")
        #expect(result == Set([.iPhone, .iPad, .macCatalyst]))
    }

    @Test
    func `parseList is case-insensitive`() throws {
        let result = try Platform.parseList("IPHONE,ipad,MACCATALYST")
        #expect(result == Set([.iPhone, .iPad, .macCatalyst]))
    }

    @Test
    func `parseList accepts mac and catalyst aliases for macCatalyst`() throws {
        #expect(try Platform.parseList("mac") == Set([.macCatalyst]))
        #expect(try Platform.parseList("catalyst") == Set([.macCatalyst]))
    }

    @Test
    func `parseList trims whitespace around tokens`() throws {
        let result = try Platform.parseList("  iPhone , iPad ")
        #expect(result == Set([.iPhone, .iPad]))
    }

    /// Regression: an unknown token was skipped with a warning, and an
    /// all-typo list silently became iPhone only.
    @Test
    func `parseList rejects an unknown token`() {
        let error = #expect(throws: ConfigValidationError.self) {
            try Platform.parseList("iPhone,android,iPad")
        }
        #expect(error?.description.contains("android") == true)
    }

    @Test
    func `parseList suggests the closest platform`() {
        let error = #expect(throws: ConfigValidationError.self) {
            try Platform.parseList("iPhnoe")
        }
        #expect(error?.description.contains("Did you mean 'iPhone'?") == true)
    }

    @Test
    func `parseList rejects input that names no platform`() {
        #expect(throws: ConfigValidationError.self) { try Platform.parseList("") }
        #expect(throws: ConfigValidationError.self) { try Platform.parseList(" , ") }
    }

    // MARK: - ProjectSystem.parseForApps

    @Test
    func `parseForApps accepts xcodeproj, xcode, and xcodegen in any case`() throws {
        #expect(try ProjectSystem.parseForApps("xcodeproj") == .xcodeProj)
        #expect(try ProjectSystem.parseForApps("Xcode") == .xcodeProj)
        #expect(try ProjectSystem.parseForApps("XcodeGen") == .xcodeGen)
    }

    /// Regression: an unknown value warned and fell back to xcodeproj.
    @Test
    func `parseForApps rejects unknown values and spm`() {
        let unknown = #expect(throws: ConfigValidationError.self) { try ProjectSystem.parseForApps("xcodgen") }
        #expect(unknown?.description.contains("Did you mean 'xcodegen'?") == true)
        let spm = #expect(throws: ConfigValidationError.self) { try ProjectSystem.parseForApps("spm") }
        #expect(spm?.description.contains("not supported for apps") == true)
    }
}
