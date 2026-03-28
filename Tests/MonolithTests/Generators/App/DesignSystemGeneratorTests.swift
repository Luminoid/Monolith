import Foundation
import Testing
@testable import MonolithLib

struct DesignSystemGeneratorTests {
    @Test
    func `generates DesignSystem enum`() {
        let output = DesignSystemGenerator.generate()
        #expect(output.contains("enum DesignSystem"))
        #expect(output.contains("import UIKit"))
    }

    @Test
    func `has Cell sub-enum with heights`() {
        let output = DesignSystemGenerator.generate()
        #expect(output.contains("enum Cell"))
        #expect(output.contains("defaultHeight"))
        #expect(output.contains("compactHeight"))
    }

    @Test
    func `has Layout sub-enum with corner radii`() {
        let output = DesignSystemGenerator.generate()
        #expect(output.contains("enum Layout"))
        #expect(output.contains("cardCornerRadius"))
        #expect(output.contains("buttonCornerRadius"))
        #expect(output.contains("iconSize"))
    }

    @Test
    func `MARK sections present`() {
        let output = DesignSystemGenerator.generate()
        #expect(output.contains("// MARK: - Cell"))
        #expect(output.contains("// MARK: - Layout"))
    }
}
