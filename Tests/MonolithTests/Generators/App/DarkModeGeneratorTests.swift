import Foundation
import Testing
@testable import MonolithLib

@Suite("DarkModeGenerator")
struct DarkModeGeneratorTests {
    private func makeConfig(
        primaryColor: String = "#4CAF7D",
        name: String = "TestApp"
    ) -> AppConfig {
        AppConfig(
            name: name,
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .spm,
            tabs: [],
            primaryColor: primaryColor,
            features: [.darkMode],
            author: "Test"
        )
    }

    @Test("generates AppTheme enum with valid color")
    func generatesAppTheme() {
        let output = DarkModeGenerator.generate(config: makeConfig())
        #expect(output.contains("enum AppTheme"))
        #expect(output.contains("import UIKit"))
    }

    @Test("generates all 22 color properties")
    func allColorProperties() {
        let output = DarkModeGenerator.generate(config: makeConfig())
        let expectedProperties = [
            "primary", "primaryDark", "secondary", "tertiary",
            "success", "warning", "error", "info",
            "textPrimary", "textSecondary", "textTertiary",
            "backgroundPrimary", "backgroundSecondary", "backgroundTertiary",
            "divider", "imageBorder",
            "graySoft", "grayMuted",
            "white", "black",
            "photoBrowserBackground",
        ]
        for prop in expectedProperties {
            #expect(output.contains(prop), "Missing property: \(prop)")
        }
    }

    @Test("uses UIColor adaptive pattern for derived colors")
    func adaptiveColorPattern() {
        let output = DarkModeGenerator.generate(config: makeConfig())
        #expect(output.contains("UIColor {"))
        #expect(output.contains("traitCollection"))
        #expect(output.contains("userInterfaceStyle"))
    }

    @Test("uses static let for properties")
    func staticLetPattern() {
        let output = DarkModeGenerator.generate(config: makeConfig())
        #expect(output.contains("static let primary"))
        #expect(output.contains("static let backgroundPrimary"))
    }

    @Test("text colors use system labels")
    func textColorsUseSystemLabels() {
        let output = DarkModeGenerator.generate(config: makeConfig())
        #expect(output.contains("textPrimary: UIColor = .label"))
        #expect(output.contains("textSecondary: UIColor = .secondaryLabel"))
        #expect(output.contains("textTertiary: UIColor = .tertiaryLabel"))
    }

    @Test("imageBorder derives from divider")
    func imageBorderDerived() {
        let output = DarkModeGenerator.generate(config: makeConfig())
        #expect(output.contains("imageBorder: UIColor = divider.withAlphaComponent"))
    }

    @Test("fallback generated for invalid color")
    func fallbackForInvalidColor() {
        let output = DarkModeGenerator.generate(config: makeConfig(primaryColor: "invalid"))
        #expect(output.contains("systemBlue"))
        #expect(output.contains("could not be parsed"))
    }

    @Test("MARK sections present")
    func markSections() {
        let output = DarkModeGenerator.generate(config: makeConfig())
        #expect(output.contains("// MARK: - Primary Colors"))
        #expect(output.contains("// MARK: - Background Colors"))
        #expect(output.contains("// MARK: - Text Colors"))
    }

    @Test("primary color hex in documentation comment")
    func primaryColorInDocComment() {
        let output = DarkModeGenerator.generate(config: makeConfig(primaryColor: "#FF6B35"))
        #expect(output.contains("#FF6B35"))
    }
}
