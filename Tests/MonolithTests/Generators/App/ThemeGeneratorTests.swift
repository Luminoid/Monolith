import Foundation
import Testing
@testable import MonolithLib

@Suite("ThemeGenerator")
struct ThemeGeneratorTests {
    private func makeConfig(
        primaryColor: String = "#4CAF7D",
        name: String = "TestApp",
    ) -> AppConfig {
        AppConfig(
            name: name,
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .spm,
            tabs: [],
            primaryColor: primaryColor,
            features: [.lumiKit],
            author: "Test",
        )
    }

    @Test("generates LMKTheme-conforming struct")
    func generatesLMKTheme() {
        let output = ThemeGenerator.generate(config: makeConfig())
        #expect(output.contains("struct TestAppTheme: LMKTheme"))
        #expect(output.contains("import LumiKitUI"))
    }

    @Test("uses var instead of static let for LMKTheme conformance")
    func usesVarProperties() {
        let output = ThemeGenerator.generate(config: makeConfig())
        #expect(output.contains("var primary: UIColor"))
        #expect(output.contains("var backgroundPrimary: UIColor"))
        #expect(!output.contains("static let primary"))
    }

    @Test("generates all 22 LMKTheme properties")
    func allLMKThemeProperties() {
        let output = ThemeGenerator.generate(config: makeConfig())
        let expectedProperties = [
            "var primary:", "var primaryDark:", "var secondary:", "var tertiary:",
            "var success:", "var warning:", "var error:", "var info:",
            "var textPrimary:", "var textSecondary:", "var textTertiary:",
            "var backgroundPrimary:", "var backgroundSecondary:", "var backgroundTertiary:",
            "var divider:", "var imageBorder:",
            "var graySoft:", "var grayMuted:",
            "var white:", "var black:",
            "var photoBrowserBackground:",
        ]
        for prop in expectedProperties {
            #expect(output.contains(prop), "Missing property: \(prop)")
        }
    }

    @Test("theme name matches app name")
    func themeNameMatchesApp() {
        let output = ThemeGenerator.generate(config: makeConfig(name: "MyApp"))
        #expect(output.contains("struct MyAppTheme: LMKTheme"))
    }

    @Test("fallback generated for invalid color")
    func fallbackForInvalidColor() {
        let output = ThemeGenerator.generate(config: makeConfig(primaryColor: "bad"))
        #expect(output.contains("Fallback theme"))
        #expect(output.contains("systemBlue"))
    }

    @Test("uses UIColor adaptive closures")
    func adaptiveColorClosures() {
        let output = ThemeGenerator.generate(config: makeConfig())
        #expect(output.contains("UIColor {"))
        #expect(output.contains("traitCollection"))
    }
}
