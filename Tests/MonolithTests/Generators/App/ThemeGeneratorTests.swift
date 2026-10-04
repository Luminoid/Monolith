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
            "primary:", "primaryVariant:", "secondary:", "tertiary:",
            "success:", "warning:", "error:", "info:", "onAccent:",
            "backgroundPrimary:", "backgroundSecondary:", "backgroundTertiary:",
            "divider:", "fill:", "fillStrong:",
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
        // are LMKColorTheme's own defaults. The derived `black` pair turns
        // near-white in dark mode, so it must never become the scrim.
        for role in ["textPrimary:", "textSecondary:", "textTertiary:", "outline:", "scrim:"] {
            #expect(!output.contains(role), "Default role emitted: \(role)")
        }
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
        #expect(arguments.count == 15)
        // Every argument but the last ends in a comma; the last has none
        // (SwiftFormat's collections-only trailing commas).
        #expect(arguments.dropLast().allSatisfy { $0.hasSuffix(",") })
        #expect(arguments.last?.hasSuffix(",") == false)
        #expect(Array(lines[(close + 1)...].prefix(2)) == ["    )", "}"])
    }

    @Test
    func `each color emits as a one-line lmk_dynamic argument (compact form)`() {
        // One line per role; the hex form for derived colors, the light/dark
        // form for the two grays. No inline `UIColor { traitCollection in }`.
        let output = ThemeGenerator.generate(config: makeConfig())
        #expect(output.contains("primary: .lmk_dynamic(lightHex: 0x"))
        #expect(output.contains("fill: .lmk_dynamic(light: UIColor(white: 0.85, alpha: 1), dark: UIColor(white: 0.35, alpha: 1))"))
        #expect(output.contains("fillStrong: .lmk_dynamic(light: UIColor(white: 0.75, alpha: 1), dark: UIColor(white: 0.45, alpha: 1))"))
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
        #expect(output.contains("primary: .systemBlue,"))
        #expect(output.contains("fillStrong: .systemGray4\n"))
        #expect(!output.contains("struct TestAppTheme"))
    }
}
