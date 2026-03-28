import Foundation
import Testing
@testable import MonolithLib

struct ThemeGeneratorTests {
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
            features: [.lumiKit],
            author: "Test"
        )
    }

    @Test
    func `generates LMKTheme-conforming struct`() {
        let output = ThemeGenerator.generate(config: makeConfig())
        #expect(output.contains("struct TestAppTheme: LMKTheme"))
        #expect(output.contains("import LumiKitUI"))
    }

    @Test
    func `uses var instead of static let for LMKTheme conformance`() {
        let output = ThemeGenerator.generate(config: makeConfig())
        #expect(output.contains("var primary: UIColor"))
        #expect(output.contains("var backgroundPrimary: UIColor"))
        #expect(!output.contains("static let primary"))
    }

    @Test
    func `generates all 22 LMKTheme properties`() {
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

    @Test
    func `theme name matches app name`() {
        let output = ThemeGenerator.generate(config: makeConfig(name: "MyApp"))
        #expect(output.contains("struct MyAppTheme: LMKTheme"))
    }

    @Test
    func `fallback generated for invalid color`() {
        let output = ThemeGenerator.generate(config: makeConfig(primaryColor: "bad"))
        #expect(output.contains("Fallback theme"))
        #expect(output.contains("systemBlue"))
    }

    @Test
    func `uses UIColor adaptive closures`() {
        let output = ThemeGenerator.generate(config: makeConfig())
        #expect(output.contains("UIColor {"))
        #expect(output.contains("traitCollection"))
    }
}
