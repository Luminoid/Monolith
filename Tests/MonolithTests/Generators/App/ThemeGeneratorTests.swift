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
            author: "Test",
            licenseType: .proprietary
        )
    }

    @Test
    func `declares the theme as an LMKTheme value`() {
        let output = ThemeGenerator.generate(config: makeConfig())
        #expect(output.contains("extension LMKTheme {"))
        #expect(output.contains("    static let testApp = LMKTheme(\n        colors: LMKColorTheme(\n"))
        #expect(output.contains("import LumiKitUI"))
        // LumiKit 1.0: `LMKColorTheme` is a struct, so nothing conforms to it,
        // and the 0.x `struct <Name>Theme: LMKTheme` protocol form is gone.
        #expect(!output.contains("struct TestAppTheme"))
        #expect(!output.contains(": LMKColorTheme {"))
        #expect(!output.contains("var primary: UIColor"))
    }

    @Test
    func `passes each derived role as an LMKColorTheme argument`() {
        let output = ThemeGenerator.generate(config: makeConfig())
        let expectedArguments = [
            "primary:", "secondary:", "tertiary:", "onAccent:",
            "backgroundPrimary:", "backgroundSecondary:", "backgroundTertiary:",
            "divider:",
        ]
        for argument in expectedArguments {
            #expect(output.contains("            \(argument) .lmk_dynamic("), "Missing argument: \(argument)")
        }
        // 0.x role names that 1.0 renamed must not reach the generated code.
        for oldName in ["primaryDark:", "imageBorder:", "graySoft:", "grayMuted:", "white:", "black:"] {
            #expect(!output.contains("            \(oldName)"), "0.x role emitted: \(oldName)")
        }
    }

    @Test
    func `leaves roles at LumiKit defaults when the derivation matches them`() {
        let output = ThemeGenerator.generate(config: makeConfig())
        // System label colors, the 50%-alpha divider outline, and a black scrim
        // are LMKColorTheme's own defaults; LumiKit derives `primaryVariant`,
        // `link`, and `selection` from `primary`. The status colors and fills
        // aren't derived from the input, so LumiKit's tuned defaults stay.
        let defaultRoles = [
            "textPrimary:", "textSecondary:", "textTertiary:", "outline:", "scrim:",
            "primaryVariant:", "link:", "selection:",
            "success:", "warning:", "error:", "info:", "fill:", "fillStrong:",
        ]
        for role in defaultRoles {
            #expect(!output.contains(role), "Default role emitted: \(role)")
        }
    }

    @Test
    func `on-accent carries a dark value for dark mode`() throws {
        // Dark-mode accents are light, so the text on them is dark.
        let output = ThemeGenerator.generate(config: makeConfig())
        let palette = try #require(ColorDeriver.derive(from: "#4CAF7D"))
        let dark = palette.onAccent.dark
        let darkHex = String(format: "0x%02X%02X%02X", dark.r255, dark.g255, dark.b255)
        #expect(output.contains("onAccent: .lmk_dynamic(lightHex: 0xFAFAFA, darkHex: \(darkHex))"))
        #expect(ColorDeriver.relativeLuminance(dark) < 0.05)
    }

    @Test
    func `emitted hex values are the derived palette`() throws {
        let output = ThemeGenerator.generate(config: makeConfig(primaryColor: "#FF6B35"))
        let palette = try #require(ColorDeriver.derive(from: "#FF6B35"))
        let light = palette.primary.light, dark = palette.primary.dark
        let expected = String(format: "primary: .lmk_dynamic(lightHex: 0x%02X%02X%02X, darkHex: 0x%02X%02X%02X)", light.r255, light.g255, light.b255, dark.r255, dark.g255, dark.b255)
        #expect(output.contains(expected))
    }

    @Test
    func `argument list is well formed`() {
        let output = ThemeGenerator.generate(config: makeConfig())
        let lines = output.components(separatedBy: "\n")
        guard let open = lines.firstIndex(of: "        colors: LMKColorTheme("),
              let close = lines.firstIndex(of: "        )") else {
            Issue.record("LMKColorTheme argument list not found")
            return
        }
        let arguments = Array(lines[(open + 1) ..< close])
        #expect(arguments.count == 8)
        // Every argument but the last ends in a comma; the last has none
        // (SwiftFormat's collections-only trailing commas).
        #expect(arguments.dropLast().allSatisfy { $0.hasSuffix(",") })
        #expect(arguments.last?.hasSuffix(",") == false)
        #expect(Array(lines[(close + 1)...].prefix(2)) == ["    )", "}"])
    }

    @Test
    func `each color emits as a one-line lmk_dynamic argument (compact form)`() {
        // One line per role in the hex form. No inline `UIColor { traitCollection in }`.
        let output = ThemeGenerator.generate(config: makeConfig())
        #expect(output.contains("primary: .lmk_dynamic(lightHex: 0x"))
        #expect(!output.contains("UIColor(white:"))
        #expect(!output.contains("traitCollection"))
    }

    @Test
    func `theme member name follows the app name`() {
        #expect(ThemeGenerator.generate(config: makeConfig(name: "MyApp")).contains("static let myApp = LMKTheme("))
        #expect(ThemeGenerator.themeMemberName(for: makeConfig(name: "LMKApp")) == "lmkApp")
        #expect(ThemeGenerator.themeMemberName(for: makeConfig(name: "URL2Go")) == "url2Go")
        #expect(ThemeGenerator.themeMemberName(for: makeConfig(name: "my-app")) == "myApp")
        #expect(ThemeGenerator.themeMemberName(for: makeConfig(name: "X")) == "x")
    }

    @Test
    func `theme member name avoids keywords and LMKTheme statics`() {
        // `Default` would lower to `default`: a keyword and `LMKTheme.default`.
        #expect(ThemeGenerator.themeMemberName(for: makeConfig(name: "Default")) == "defaultTheme")
        #expect(ThemeGenerator.themeMemberName(for: makeConfig(name: "Current")) == "currentTheme")
        #expect(ThemeGenerator.themeMemberName(for: makeConfig(name: "Return")) == "returnTheme")
    }

    @Test
    func `fallback generated for invalid color`() {
        let output = ThemeGenerator.generate(config: makeConfig(primaryColor: "bad"))
        #expect(output.contains("Fallback theme"))
        #expect(output.contains("static let testApp = LMKTheme("))
        #expect(output.contains("            primary: .systemBlue\n        )"))
        // Only `primary`; every other role keeps LumiKit's default.
        #expect(!output.contains("fill"))
        #expect(!output.contains("struct TestAppTheme"))
    }
}
