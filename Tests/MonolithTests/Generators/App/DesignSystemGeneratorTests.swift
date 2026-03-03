import Foundation
import Testing
@testable import MonolithLib

@Suite("DesignSystemGenerator")
struct DesignSystemGeneratorTests {
    @Test("generates DesignSystem enum")
    func generatesEnum() {
        let output = DesignSystemGenerator.generate()
        #expect(output.contains("enum DesignSystem"))
        #expect(output.contains("import UIKit"))
    }

    @Test("has Cell sub-enum with heights")
    func cellSubEnum() {
        let output = DesignSystemGenerator.generate()
        #expect(output.contains("enum Cell"))
        #expect(output.contains("defaultHeight"))
        #expect(output.contains("compactHeight"))
    }

    @Test("has Layout sub-enum with corner radii")
    func layoutSubEnum() {
        let output = DesignSystemGenerator.generate()
        #expect(output.contains("enum Layout"))
        #expect(output.contains("cardCornerRadius"))
        #expect(output.contains("buttonCornerRadius"))
        #expect(output.contains("iconSize"))
    }

    @Test("MARK sections present")
    func markSections() {
        let output = DesignSystemGenerator.generate()
        #expect(output.contains("// MARK: - Cell"))
        #expect(output.contains("// MARK: - Layout"))
    }
}
