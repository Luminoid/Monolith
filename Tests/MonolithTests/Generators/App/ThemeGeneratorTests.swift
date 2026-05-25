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
    func `generates all 21 LMKTheme properties (photoBrowserBackground inherits from protocol)`() {
        let output = ThemeGenerator.generate(config: makeConfig())
        let expectedProperties = [
            "var primary:", "var primaryDark:", "var secondary:", "var tertiary:",
            "var success:", "var warning:", "var error:", "var info:",
            "var textPrimary:", "var textSecondary:", "var textTertiary:",
            "var backgroundPrimary:", "var backgroundSecondary:", "var backgroundTertiary:",
            "var divider:", "var imageBorder:",
            "var graySoft:", "var grayMuted:",
            "var white:", "var black:",
        ]
        for prop in expectedProperties {
            #expect(output.contains(prop), "Missing property: \(prop)")
        }
        // `photoBrowserBackground` is intentionally NOT emitted — LumiKit's
        // LMKTheme protocol ships a default implementation (always-dark
        // #1A1A1A). Apps that need a different always-dark variant can add
        // the property here themselves.
        #expect(!output.contains("var photoBrowserBackground:"))
    }

    @Test
    func `each color emits as a one-line lmk_dynamic call (compact form)`() {
        // Compact theme: 21 colors × 1 line each ≈ 50 lines total. The previous
        // verbose form was ~5 lines per color (~150 lines total). The compact
        // form requires LumiKit 0.9.0+ for the `lmk_dynamic` helper.
        let output = ThemeGenerator.generate(config: makeConfig())
        #expect(output.contains(".lmk_dynamic(lightHex:"))
        // No inline `UIColor { traitCollection in` blocks in the compact form
        // (except inside the gray helpers, which use a different generator).
        // Asserting the count of `traitCollection` occurrences should match
        // the gray helper count (2) — graySoft + grayMuted.
        let traitCount = output.components(separatedBy: "traitCollection").count - 1
        #expect(traitCount <= 4, "expected ≤4 traitCollection refs (gray helpers only), got \(traitCount)")
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
