import Foundation

/// Generates a {Name}Theme: LMKTheme struct using ColorDeriver.
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
        lines.append(ColorCodeGenerator.varColorProperty("divider", light: palette.divider.light, dark: palette.divider.dark))
        lines.append("")
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

        // Photo Browser. When the derived light/dark colors are identical
        // (`photoBrowserBackground` is intentionally always-dark in
        // `ColorDeriver`), the dynamic-color wrapper is pointless overhead and
        // emits the same RGB triple twice. Collapse to a static color when
        // both modes match.
        lines.addMark("Photo Browser")
        let photo = palette.photoBrowserBackground
        if photo.light == photo.dark {
            let c = photo.dark
            lines.append("    var photoBrowserBackground: UIColor { UIColor(red: \(c.r255) / 255.0, green: \(c.g255) / 255.0, blue: \(c.b255) / 255.0, alpha: 1.0) }")
        } else {
            lines.append(ColorCodeGenerator.varColorProperty("photoBrowserBackground", light: photo.light, dark: photo.dark))
        }

        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    /// Append a list of color properties to `lines`, separated by blank lines
    /// so SwiftFormat's `blankLinesBetweenScopes` rule is satisfied.
    private static func appendColorProperties(
        into lines: inout [String],
        _ properties: [(name: String, color: ColorDeriver.ColorPair)]
    ) {
        for (index, property) in properties.enumerated() {
            if index > 0 { lines.append("") }
            lines.append(ColorCodeGenerator.varColorProperty(
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
            var photoBrowserBackground: UIColor { UIColor(white: 0.1, alpha: 1) }
        }
        """
    }
}
