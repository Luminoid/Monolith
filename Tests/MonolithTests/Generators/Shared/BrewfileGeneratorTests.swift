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

    @Test
    func `tools have minimum-version pin comments`() {
        // Pins document the floor the generated configs target — adopters
        // with newer installs are fine (brew bundle still installs latest),
        // but the comment tells you what to roll back to if a tool regresses.
        let output = BrewfileGenerator.generate(projectSystem: .xcodeGen)
        #expect(output.contains(#"brew "swiftlint"   # 0.59+"#))
        #expect(output.contains(#"brew "swiftformat" # 0.54+"#))
        #expect(output.contains(#"brew "xcodegen"    # 2.42+"#))
    }

    @Test
    func `header explains pinning contract`() {
        // Without context, the `# 0.59+` markers look like inline noise.
        // The header sentence should explain that they're floor versions,
        // not exact pins.
        let output = BrewfileGenerator.generate()
        #expect(output.contains("minimum compatible version"))
    }

    @Test
    func `has header comment explaining usage`() throws {
        // Without a header, a freshly-scaffolded Brewfile is two anonymous lines
        // with no indication of how to use it. The header documents `brew bundle`
        // and `brew bundle add` so newcomers don't need to look up the workflow.
        let output = BrewfileGenerator.generate()
        #expect(output.hasPrefix("# Brewfile"))
        #expect(output.contains("brew bundle"))
        // Header lines come BEFORE the first `brew "..."` directive.
        let firstBrew = try #require(output.range(of: #"brew ""#))
        let header = output[..<firstBrew.lowerBound]
        #expect(header.contains("#"))
    }
}
