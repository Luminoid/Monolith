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
            author: "Test",
            licenseType: .proprietary
        )
    }

    @Test
    func `generates AppTheme enum with valid color`() {
        let output = DarkModeGenerator.generate(config: makeConfig())
        #expect(output.contains("enum AppTheme"))
        #expect(output.contains("import UIKit"))
    }

    /// `AppTheme` members are LumiKit `LMKColor` role names, so moving to
    /// LumiKit later swaps the type name without renaming any member.
    private static let lumiKitRoles = [
        "primary", "primaryVariant", "secondary", "tertiary", "onAccent",
        "success", "warning", "error", "info",
        "textPrimary", "textSecondary", "textTertiary",
        "backgroundPrimary", "backgroundSecondary", "backgroundTertiary",
        "divider", "outline", "fill", "fillStrong",
    ]

    @Test(arguments: ["#4CAF7D", "invalid"])
    func `declares exactly the LumiKit role names`(primaryColor: String) {
        let output = DarkModeGenerator.generate(config: makeConfig(primaryColor: primaryColor))
        let declared = output.components(separatedBy: "\n").compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("static let ") else { return nil }
            return String(trimmed.dropFirst("static let ".count).prefix { $0.isLetter || $0.isNumber })
        }
        #expect(declared == Self.lumiKitRoles)
        for oldName in ["primaryDark", "imageBorder", "graySoft", "grayMuted", "photoBrowserBackground", "static let white", "static let black"] {
            #expect(!output.contains(oldName), "Pre-LumiKit name emitted: \(oldName)")
        }
    }

    @Test
    func `status colors and fills match LumiKit's defaults`() {
        let output = DarkModeGenerator.generate(config: makeConfig())
        #expect(output.contains("static let success: UIColor = .systemGreen"))
        #expect(output.contains("static let warning: UIColor = .systemOrange"))
        #expect(output.contains("static let error: UIColor = .systemRed"))
        #expect(output.contains("static let info: UIColor = .systemBlue"))
        #expect(output.contains("? UIColor(white: 0.25, alpha: 1)\n            : UIColor(white: 0.85, alpha: 1)"))
        #expect(output.contains("? UIColor(white: 0.35, alpha: 1)\n            : UIColor(white: 0.75, alpha: 1)"))
    }

    @Test
    func `on-accent turns dark in dark mode`() throws {
        let output = DarkModeGenerator.generate(config: makeConfig())
        let dark = try #require(ColorDeriver.derive(from: "#4CAF7D")).onAccent.dark
        #expect(output.contains("""
            static let onAccent: UIColor = UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: \(dark.r255) / 255.0, green: \(dark.g255) / 255.0, blue: \(dark.b255) / 255.0, alpha: 1.0)
                    : UIColor(red: 250 / 255.0, green: 250 / 255.0, blue: 250 / 255.0, alpha: 1.0)
        """))
    }

    @Test
    func `a blank line follows every color body`() {
        // SwiftFormat's blankLinesBetweenScopes fails `make check` when a
        // `UIColor { traitCollection in ... }` body runs straight into the next member.
        let lines = DarkModeGenerator.generate(config: makeConfig()).components(separatedBy: "\n")
        for (index, line) in lines.enumerated().dropLast() where line == "    }" {
            #expect(lines[index + 1].isEmpty || lines[index + 1] == "}", "no blank line after line \(index + 1): \(lines[index + 1])")
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
    func `outline derives from divider`() {
        let output = DarkModeGenerator.generate(config: makeConfig())
        #expect(output.contains("static let outline: UIColor = divider.withAlphaComponent(0.5)"))
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
        #expect(output.contains("// MARK: - Accents"))
        #expect(output.contains("// MARK: - Background Colors"))
        #expect(output.contains("// MARK: - Text Colors"))
    }

    @Test
    func `primary color hex in documentation comment`() {
        let output = DarkModeGenerator.generate(config: makeConfig(primaryColor: "#FF6B35"))
        #expect(output.contains("#FF6B35"))
    }
}
