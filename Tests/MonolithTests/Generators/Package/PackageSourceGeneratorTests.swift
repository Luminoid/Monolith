import Foundation
import Testing
@testable import MonolithLib

struct PackageSourceGeneratorTests {
    // MARK: - Library placeholder

    @Test
    func `library placeholder emits public enum stub`() {
        let output = PackageSourceGenerator.generateSource(targetName: "MyLib")
        #expect(output.contains("public enum MyLib {}"))
        #expect(output.contains("placeholder"))
        #expect(output.hasSuffix("\n"))
    }

    // MARK: - Test-helper placeholder

    @Test
    func `helper imports Swift Testing as the default`() {
        // Workspace standard is Swift Testing. The stub does NOT pre-import
        // XCTest as an actual import statement — adopters wanting interop add
        // it themselves (the docstring still mentions XCTest as a hint).
        let output = PackageSourceGenerator.generateTestHelper(targetName: "MultiLibTesting")
        let importLines = output.split(separator: "\n").filter { $0.hasPrefix("import ") }
        #expect(importLines.contains("import Testing"))
        #expect(!importLines.contains("import XCTest"))
    }

    @Test
    func `helper exposes a public namespace enum`() {
        let output = PackageSourceGenerator.generateTestHelper(targetName: "MultiLibTesting")
        #expect(output.contains("public enum MultiLibTesting"))
        // No reminder-comment line — SwiftLint's `todo` rule (on by default
        // in the generated .swiftlint.yml) would reject it. The empty enum
        // body is the prompt; the doc-comment carries the explainer.
        let marker = "// " + "TODO"
        #expect(!output.contains(marker))
    }

    @Test
    func `helper UpperCamelCases the namespace type name`() {
        // The target name may be kebab-case (`-testing`) but the Swift type
        // must be a valid identifier.
        let output = PackageSourceGenerator.generateTestHelper(targetName: "multi-lib-testing")
        #expect(output.contains("public enum MultiLibTesting"))
    }

    @Test
    func `helper imports internal lib deps`() {
        // When the helper depends on the library it's testing, the stub
        // surfaces that wiring as an `import <Lib>` line so adopters see
        // the dep wired up in Package.swift exercised in the source.
        let output = PackageSourceGenerator.generateTestHelper(
            targetName: "MultiLibTesting",
            internalLibDeps: ["MultiLibCore"]
        )
        #expect(output.contains("import Testing"))
        #expect(output.contains("import MultiLibCore"))
    }

    @Test
    func `helper sorts internal lib deps deterministically`() throws {
        let output = PackageSourceGenerator.generateTestHelper(
            targetName: "MultiLibTesting",
            internalLibDeps: ["ZetaLib", "AlphaLib", "MultiLibCore"]
        )
        let alphaIdx = try #require(output.range(of: "import AlphaLib"))
        let multiIdx = try #require(output.range(of: "import MultiLibCore"))
        let zetaIdx = try #require(output.range(of: "import ZetaLib"))
        #expect(alphaIdx.lowerBound < multiIdx.lowerBound)
        #expect(multiIdx.lowerBound < zetaIdx.lowerBound)
    }

    // MARK: - Executable placeholder

    @Test
    func `executable stub imports ArgumentParser`() {
        let output = PackageSourceGenerator.generateExecutable(targetName: "multi-tool")
        #expect(output.contains("import ArgumentParser"))
        #expect(output.contains("@main"))
        #expect(output.contains("struct MultiTool: ParsableCommand"))
        #expect(output.contains("commandName: \"multi-tool\""))
    }

    @Test
    func `executable stub without sibling deps has no extra imports`() {
        let output = PackageSourceGenerator.generateExecutable(targetName: "multi-tool")
        let importLines = output.split(separator: "\n").filter { $0.hasPrefix("import ") }
        #expect(importLines.count == 1)
        #expect(importLines.first == "import ArgumentParser")
    }

    @Test
    func `executable stub with internal lib dep imports the lib`() {
        // When the executable depends on a sibling lib in the same package,
        // surface that wiring as an `import <Lib>` line in the stub. Otherwise
        // the dep in Package.swift is dead weight with no breadcrumb in source.
        let output = PackageSourceGenerator.generateExecutable(
            targetName: "multi-tool",
            internalLibDeps: ["MultiLib"]
        )
        #expect(output.contains("import ArgumentParser"))
        #expect(output.contains("import MultiLib"))
    }

    @Test
    func `executable stub sorts internal lib deps deterministically`() throws {
        // Set ordering is unstable; the generator sorts so regenerating the
        // same package twice produces byte-identical output.
        let output = PackageSourceGenerator.generateExecutable(
            targetName: "multi-tool",
            internalLibDeps: ["ZetaLib", "AlphaLib", "MultiLib"]
        )
        let alphaIdx = try #require(output.range(of: "import AlphaLib"))
        let multiIdx = try #require(output.range(of: "import MultiLib"))
        let zetaIdx = try #require(output.range(of: "import ZetaLib"))
        #expect(alphaIdx.lowerBound < multiIdx.lowerBound)
        #expect(multiIdx.lowerBound < zetaIdx.lowerBound)
    }

    @Test
    func `executable type name UpperCamelCases the kebab-case target`() {
        // Target name stays kebab-case (used by `swift run`); the Swift type
        // must be a valid identifier, which forces UpperCamelCase.
        let output = PackageSourceGenerator.generateExecutable(targetName: "causeway-tools")
        #expect(output.contains("struct CausewayTools: ParsableCommand"))
        #expect(output.contains("commandName: \"causeway-tools\""))
    }

    // MARK: - Full import-list sorting

    @Test
    func `helper sorts the FULL import list including Testing`() throws {
        // Regression: the prior generator hard-coded `import Testing` first
        // and only sorted the tail. With deps like `Causeway` that sort
        // BEFORE `Testing` alphabetically, SwiftFormat's `sortImports` rule
        // (which the generated .swiftformat opts in to) would reject the
        // output on the first `make check`.
        let output = PackageSourceGenerator.generateTestHelper(
            targetName: "CausewayTesting",
            internalLibDeps: ["Causeway"]
        )
        let causewayIdx = try #require(output.range(of: "import Causeway"))
        let testingIdx = try #require(output.range(of: "import Testing"))
        #expect(causewayIdx.lowerBound < testingIdx.lowerBound)
    }

    @Test
    func `executable sorts the FULL import list including ArgumentParser`() throws {
        // Same regression as helper — `Adapters` sorts before `ArgumentParser`.
        let output = PackageSourceGenerator.generateExecutable(
            targetName: "my-tool",
            internalLibDeps: ["Adapters"]
        )
        let adaptersIdx = try #require(output.range(of: "import Adapters"))
        let apIdx = try #require(output.range(of: "import ArgumentParser"))
        #expect(adaptersIdx.lowerBound < apIdx.lowerBound)
    }

    // MARK: - External deps in plain source

    @Test
    func `plain source stub imports external deps so they are not dead weight`() {
        // Regression: `CausewayLumiKit` wired `LumiKitUI` as a Package.swift
        // dep but the generated source was an empty placeholder with no
        // `import LumiKitUI` line — broken deps would link silently instead
        // of failing loud at compile time.
        let output = PackageSourceGenerator.generateSource(
            targetName: "CausewayLumiKit",
            externalDeps: ["LumiKitUI"]
        )
        #expect(output.contains("import LumiKitUI"))
        #expect(output.contains("public enum CausewayLumiKit {}"))
    }

    @Test
    func `plain source stub with no external deps has no extra imports`() {
        // Backwards-compat: targets with no external deps still get the
        // bare placeholder, no `import` line at all.
        let output = PackageSourceGenerator.generateSource(targetName: "MyLib")
        let importLines = output.split(separator: "\n").filter { $0.hasPrefix("import ") }
        #expect(importLines.isEmpty)
    }

    @Test
    func `plain source stub sorts external deps deterministically`() throws {
        let output = PackageSourceGenerator.generateSource(
            targetName: "MyLib",
            externalDeps: ["ZetaPkg", "AlphaPkg", "BetaPkg"]
        )
        let alphaIdx = try #require(output.range(of: "import AlphaPkg"))
        let betaIdx = try #require(output.range(of: "import BetaPkg"))
        let zetaIdx = try #require(output.range(of: "import ZetaPkg"))
        #expect(alphaIdx.lowerBound < betaIdx.lowerBound)
        #expect(betaIdx.lowerBound < zetaIdx.lowerBound)
    }
}
