import Foundation
import Testing
@testable import MonolithLib

struct BrewfileGeneratorTests {
    @Test
    func `base tools`() {
        let output = BrewfileGenerator.generate()
        #expect(output.contains(#"brew "swiftlint""#))
        #expect(output.contains(#"brew "swiftformat""#))
    }

    @Test
    func `includes xcodegen for XcodeGen project`() {
        let output = BrewfileGenerator.generate(projectSystem: .xcodeGen)
        #expect(output.contains(#"brew "xcodegen""#))
    }

    @Test
    func `excludes xcodegen for SPM project`() {
        let output = BrewfileGenerator.generate(projectSystem: .spm)
        #expect(!output.contains("xcodegen"))
    }

    @Test
    func `includes mint comment when R.swift enabled`() {
        let output = BrewfileGenerator.generate(hasRSwift: true)
        #expect(output.contains("mint"))
    }
}
