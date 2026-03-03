import Foundation
import Testing
@testable import MonolithLib

@Suite("MacCatalystGenerator")
struct MacCatalystGeneratorTests {
    @Test("generates targetEnvironment guard")
    func targetEnvironmentGuard() {
        let output = MacCatalystGenerator.generateWindowConfig()
        #expect(output.contains("#if targetEnvironment(macCatalyst)"))
        #expect(output.contains("#endif"))
    }

    @Test("generates MacWindowConfig enum")
    func macWindowConfigEnum() {
        let output = MacCatalystGenerator.generateWindowConfig()
        #expect(output.contains("enum MacWindowConfig"))
        #expect(output.contains("static func configure"))
    }

    @Test("configures titlebar")
    func configuresTitlebar() {
        let output = MacCatalystGenerator.generateWindowConfig()
        #expect(output.contains("titlebar"))
        #expect(output.contains("titleVisibility = .hidden"))
    }

    @Test("sets window size restrictions")
    func sizeRestrictions() {
        let output = MacCatalystGenerator.generateWindowConfig()
        #expect(output.contains("minimumSize"))
        #expect(output.contains("maximumSize"))
        #expect(output.contains("AppConstants.MacWindow"))
    }

    @Test("imports UIKit")
    func importsUIKit() {
        let output = MacCatalystGenerator.generateWindowConfig()
        #expect(output.contains("import UIKit"))
    }
}
