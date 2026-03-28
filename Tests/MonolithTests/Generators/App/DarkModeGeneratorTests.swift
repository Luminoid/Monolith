import Foundation
import Testing
@testable import MonolithLib

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
            projectSystem: .xcodeProj,
            tabs: [],
            primaryColor: primaryColor,
            features: [.darkMode],
            author: "Test"
        )
    }

    @Test
    func `generates AppTheme enum with valid color`() {
        let output = DarkModeGenerator.generate(config: makeConfig())
        #expect(output.contains("enum AppTheme"))
        #expect(output.contains("import UIKit"))
    }

    @Test
    func `generates all 22 color properties`() {
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

    @Test
    func `uses UIColor adaptive pattern for derived colors`() {
        let output = DarkModeGenerator.generate(config: makeConfig())
        #expect(output.contains("UIColor {"))
        #expect(output.contains("traitCollection"))
        #expect(output.contains("userInterfaceStyle"))
    }

    @Test
    func `uses static let for properties`() {
        let output = DarkModeGenerator.generate(config: makeConfig())
        #expect(output.contains("static let primary"))
        #expect(output.contains("static let backgroundPrimary"))
    }

    @Test
    func `text colors use system labels`() {
        let output = DarkModeGenerator.generate(config: makeConfig())
        #expect(output.contains("textPrimary: UIColor = .label"))
        #expect(output.contains("textSecondary: UIColor = .secondaryLabel"))
        #expect(output.contains("textTertiary: UIColor = .tertiaryLabel"))
    }

    @Test
    func `imageBorder derives from divider`() {
        let output = DarkModeGenerator.generate(config: makeConfig())
        #expect(output.contains("imageBorder: UIColor = divider.withAlphaComponent"))
    }

    @Test
    func `fallback generated for invalid color`() {
        let output = DarkModeGenerator.generate(config: makeConfig(primaryColor: "invalid"))
        #expect(output.contains("systemBlue"))
        #expect(output.contains("could not be parsed"))
    }

    @Test
    func `MARK sections present`() {
        let output = DarkModeGenerator.generate(config: makeConfig())
        #expect(output.contains("// MARK: - Primary Colors"))
        #expect(output.contains("// MARK: - Background Colors"))
        #expect(output.contains("// MARK: - Text Colors"))
    }

    @Test
    func `primary color hex in documentation comment`() {
        let output = DarkModeGenerator.generate(config: makeConfig(primaryColor: "#FF6B35"))
        #expect(output.contains("#FF6B35"))
    }
}
