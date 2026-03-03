import Foundation
import Testing
@testable import MonolithLib

@Suite("BrewfileGenerator")
struct BrewfileGeneratorTests {
    @Test("base tools")
    func base() {
        let output = BrewfileGenerator.generate()
        #expect(output.contains(#"brew "swiftlint""#))
        #expect(output.contains(#"brew "swiftformat""#))
    }

    @Test("includes xcodegen for XcodeGen project")
    func xcodeGen() {
        let output = BrewfileGenerator.generate(projectSystem: .xcodeGen)
        #expect(output.contains(#"brew "xcodegen""#))
    }

    @Test("excludes xcodegen for SPM project")
    func spm() {
        let output = BrewfileGenerator.generate(projectSystem: .spm)
        #expect(!output.contains("xcodegen"))
    }

    @Test("includes mint comment when R.swift enabled")
    func rSwift() {
        let output = BrewfileGenerator.generate(hasRSwift: true)
        #expect(output.contains("mint"))
    }
}
