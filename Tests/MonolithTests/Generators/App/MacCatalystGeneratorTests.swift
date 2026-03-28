import Foundation
import Testing
@testable import MonolithLib

struct MacCatalystGeneratorTests {
    @Test
    func `generates targetEnvironment guard`() {
        let output = MacCatalystGenerator.generateWindowConfig()
        #expect(output.contains("#if targetEnvironment(macCatalyst)"))
        #expect(output.contains("#endif"))
    }

    @Test
    func `generates MacWindowConfig enum`() {
        let output = MacCatalystGenerator.generateWindowConfig()
        #expect(output.contains("enum MacWindowConfig"))
        #expect(output.contains("static func configure"))
    }

    @Test
    func `configures titlebar`() {
        let output = MacCatalystGenerator.generateWindowConfig()
        #expect(output.contains("titlebar"))
        #expect(output.contains("titleVisibility = .hidden"))
    }

    @Test
    func `sets window size restrictions`() {
        let output = MacCatalystGenerator.generateWindowConfig()
        #expect(output.contains("minimumSize"))
        #expect(output.contains("maximumSize"))
        #expect(output.contains("AppConstants.MacWindow"))
    }

    @Test
    func `imports UIKit`() {
        let output = MacCatalystGenerator.generateWindowConfig()
        #expect(output.contains("import UIKit"))
    }
}
