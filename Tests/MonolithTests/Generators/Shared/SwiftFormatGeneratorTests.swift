import Foundation
import Testing
@testable import MonolithLib

struct SwiftFormatGeneratorTests {
    @Test
    func `includes correct options`() {
        let output = SwiftFormatGenerator.generate()
        #expect(output.contains("--indent 4"))
        #expect(output.contains("--maxwidth 200"))
        #expect(output.contains("--swiftversion 6.2"))
        #expect(output.contains("--self remove"))
        #expect(output.contains("--importgrouping testable-bottom"))
    }

    @Test
    func `includes correct enabled rules`() {
        let output = SwiftFormatGenerator.generate()
        #expect(output.contains("--enable unusedPrivateDeclarations"))
        #expect(output.contains("--enable preferFinalClasses"))
        #expect(output.contains("--enable redundantAsync"))
        #expect(output.contains("--enable sortImports"))
    }

    @Test
    func `includes correct disabled rules`() {
        let output = SwiftFormatGenerator.generate()
        #expect(output.contains("--disable consecutiveSpaces"))
        #expect(output.contains("--disable markTypes"))
        #expect(output.contains("--disable redundantSelf"))
        #expect(output.contains("--disable unusedArguments"))
        #expect(output.contains("--disable wrapMultilineStatementBraces"))
    }

    @Test
    func `extra excludes`() {
        let output = SwiftFormatGenerator.generate(excludeExtras: ["fastlane", "Generated"])
        #expect(output.contains("--exclude .build,Build,fastlane,Generated"))
    }
}
