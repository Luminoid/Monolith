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
        #expect(output.contains("TODO"))
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
}
