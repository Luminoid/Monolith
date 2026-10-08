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
    func `generates a main-actor MacWindowConfig enum`() {
        let output = MacCatalystGenerator.generateWindowConfig()
        let lines = output.components(separatedBy: "\n")
        let enumLine = lines.firstIndex(of: "    enum MacWindowConfig {")
        #expect(enumLine.map { lines[$0 - 1] } == "    @MainActor", "UIWindowScene is main-actor isolated")
        #expect(output.contains("static func configure(_ windowScene: UIWindowScene)"))
    }

    @Test
    func `configures titlebar`() {
        let output = MacCatalystGenerator.generateWindowConfig()
        #expect(output.contains("titlebar"))
        #expect(output.contains("titleVisibility = .hidden"))
    }

    @Test
    func `sets a minimum window size and no maximum`() {
        let output = MacCatalystGenerator.generateWindowConfig()
        #expect(output.contains("sizeRestrictions?.minimumSize"))
        #expect(output.contains("AppConstants.MacWindow.minWidth"))
        #expect(output.contains("AppConstants.MacWindow.minHeight"))
        #expect(!output.contains("maximumSize"))
        #expect(!output.contains("maxWidth"))
    }

    @Test
    func `inline constants carry the minimum size without AppConstants`() {
        let output = MacCatalystGenerator.generateWindowConfig(inlineConstants: true)
        #expect(!output.contains("AppConstants"))
        #expect(output.contains("static let minimumSize = CGSize(width: 600, height: 800)"))
        #expect(output.contains("windowScene.sizeRestrictions?.minimumSize = minimumSize"))
        #expect(!output.contains("maximumSize"))
    }

    @Test
    func `inline minimum size matches a new app's AppConstants`() {
        let config = AppConfig(
            name: "MyApp",
            bundleID: "com.example.myapp",
            deploymentTarget: "18.0",
            platforms: [.iPhone, .iPad, .macCatalyst],
            projectSystem: .xcodeGen,
            tabs: [],
            primaryColor: "#007AFF",
            features: [],
            author: "Test",
            licenseType: .proprietary
        )
        let constants = AppConstantsGenerator.generate(config: config)
        #expect(constants.contains("static let minWidth: CGFloat = \(MacCatalystGenerator.minimumWindowWidth)"))
        #expect(constants.contains("static let minHeight: CGFloat = \(MacCatalystGenerator.minimumWindowHeight)"))
    }

    @Test
    func `imports UIKit`() {
        let output = MacCatalystGenerator.generateWindowConfig()
        #expect(output.contains("import UIKit"))
    }
}
