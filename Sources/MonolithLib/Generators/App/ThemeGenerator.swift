import Foundation

/// Generates a {Name}Theme: LMKTheme struct using ColorDeriver.
///
/// Each color emits as a one-liner using LumiKit 0.9.0's `lmk_dynamic` helper
/// (`UIColor.lmk_dynamic(lightHex: 0x..., darkHex: 0x...)`). Earlier versions
/// of this generator produced ~5 lines of inline `UIColor { traitCollection in
/// ... }` math per color, which made theme files ~160 lines for 22 colors. The
/// compact form is ~50 lines and reads top-to-bottom as a palette table.
enum ThemeGenerator {
    static func generate(config: AppConfig) -> String {
        guard let palette = ColorDeriver.derive(from: config.primaryColor) else {
            return generateFallback(config: config)
        }

        let themeName = "\(config.name)Theme"
        var lines: [String] = []

        lines.append("import LumiKitUI")
        lines.append("import UIKit")
        lines.append("")
        lines.append("/// Theme derived from primary color \(config.primaryColor).")
        lines.append("struct \(themeName): LMKTheme {")

        // Each block emits its MARK header, then the color-property closures
        // separated by blank lines. The blank lines satisfy SwiftFormat's
        // `blankLinesBetweenScopes` rule (adjacent computed properties without
        // a blank between them is a lint error).

        // Primary
        lines.addMark("Primary Colors")
        appendColorProperties(into: &lines, [
            ("primary", palette.primary),
            ("primaryDark", palette.primaryDark),
        ])

        // Secondary / Tertiary
        lines.addMark("Secondary & Tertiary")
        appendColorProperties(into: &lines, [
            ("secondary", palette.secondary),
            ("tertiary", palette.tertiary),
        ])

        // Semantic
        lines.addMark("Semantic Colors")
        appendColorProperties(into: &lines, [
            ("success", palette.success),
            ("warning", palette.warning),
            ("error", palette.error),
            ("info", palette.info),
        ])

        // Text
        lines.addMark("Text Colors")
        lines.append("""
            var textPrimary: UIColor { .label }
            var textSecondary: UIColor { .secondaryLabel }
            var textTertiary: UIColor { .tertiaryLabel }
        """)

        // Backgrounds
        lines.addMark("Background Colors")
        appendColorProperties(into: &lines, [
            ("backgroundPrimary", palette.backgroundPrimary),
            ("backgroundSecondary", palette.backgroundSecondary),
            ("backgroundTertiary", palette.backgroundTertiary),
        ])

        // Divider
        lines.addMark("Divider & Border")
        lines.append(ColorCodeGenerator.varColorPropertyLumiKit("divider", light: palette.divider.light, dark: palette.divider.dark))
        lines.append("    var imageBorder: UIColor { divider.withAlphaComponent(\(palette.imageBorder.alpha)) }")

        // Grays
        lines.addMark("Grays")
        lines.append(ColorCodeGenerator.varGrayProperty("graySoft", lightWhite: palette.graySoft.lightWhite, darkWhite: palette.graySoft.darkWhite))
        lines.append("")
        lines.append(ColorCodeGenerator.varGrayProperty("grayMuted", lightWhite: palette.grayMuted.lightWhite, darkWhite: palette.grayMuted.darkWhite))

        // White / Black
        lines.addMark("White & Black")
        appendColorProperties(into: &lines, [
            ("white", palette.white),
            ("black", palette.black),
        ])

        // photoBrowserBackground intentionally omitted: LumiKit's `LMKTheme`
        // protocol ships a default implementation (always-dark `#1A1A1A`) since
        // every photo-browser background should look the same across apps.
        // Override here only when an app needs a different always-dark variant.

        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    /// Append a list of color properties to `lines` as compact one-liners.
    /// Each color renders as a single `var name: UIColor { .lmk_dynamic(...) }`
    /// line; properties are separated by blank lines so SwiftFormat's
    /// `blankLinesBetweenScopes` rule is satisfied.
    private static func appendColorProperties(
        into lines: inout [String],
        _ properties: [(name: String, color: ColorDeriver.ColorPair)]
    ) {
        for (index, property) in properties.enumerated() {
            if index > 0 { lines.append("") }
            lines.append(ColorCodeGenerator.varColorPropertyLumiKit(
                property.name,
                light: property.color.light,
                dark: property.color.dark
            ))
        }
    }

    // MARK: - Helpers

    private static func generateFallback(config: AppConfig) -> String {
        let themeName = "\(config.name)Theme"
        return """
        import LumiKitUI
        import UIKit

        /// Fallback theme using system colors.
        struct \(themeName): LMKTheme {
            var primary: UIColor { .systemBlue }
            var primaryDark: UIColor { .systemBlue }
            var secondary: UIColor { .systemGray }
            var tertiary: UIColor { .systemGray2 }
            var success: UIColor { .systemGreen }
            var warning: UIColor { .systemOrange }
            var error: UIColor { .systemRed }
            var info: UIColor { .systemCyan }
            var textPrimary: UIColor { .label }
            var textSecondary: UIColor { .secondaryLabel }
            var textTertiary: UIColor { .tertiaryLabel }
            var backgroundPrimary: UIColor { .systemBackground }
            var backgroundSecondary: UIColor { .secondarySystemBackground }
            var backgroundTertiary: UIColor { .tertiarySystemBackground }
            var divider: UIColor { .separator }
            var imageBorder: UIColor { .separator }
            var graySoft: UIColor { .systemGray4 }
            var grayMuted: UIColor { .systemGray5 }
            var white: UIColor { .white }
            var black: UIColor { .black }
        }
        """
    }
}
