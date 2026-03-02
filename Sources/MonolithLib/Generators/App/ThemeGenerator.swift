import Foundation

/// Generates a {Name}Theme: LMKTheme struct using ColorDeriver.
enum ThemeGenerator {

    static func generate(config: AppConfig) -> String {
        guard let palette = ColorDeriver.derive(from: config.primaryColor) else {
            return generateFallback(config: config)
        }

        let themeName = "\(config.name)Theme"
        var lines: [String] = []

        lines.append("import UIKit")
        lines.append("import LumiKitUI")
        lines.append("")
        lines.append("/// Theme derived from primary color \(config.primaryColor).")
        lines.append("struct \(themeName): LMKTheme {")
        lines.append("")

        // Primary
        lines.addMark("Primary Colors")
        lines.append(ColorCodeGenerator.varColorProperty("primary", light: palette.primary.light, dark: palette.primary.dark))
        lines.append(ColorCodeGenerator.varColorProperty("primaryDark", light: palette.primaryDark.light, dark: palette.primaryDark.dark))
        lines.append("")

        // Secondary / Tertiary
        lines.addMark("Secondary & Tertiary")
        lines.append(ColorCodeGenerator.varColorProperty("secondary", light: palette.secondary.light, dark: palette.secondary.dark))
        lines.append(ColorCodeGenerator.varColorProperty("tertiary", light: palette.tertiary.light, dark: palette.tertiary.dark))
        lines.append("")

        // Semantic
        lines.addMark("Semantic Colors")
        lines.append(ColorCodeGenerator.varColorProperty("success", light: palette.success.light, dark: palette.success.dark))
        lines.append(ColorCodeGenerator.varColorProperty("warning", light: palette.warning.light, dark: palette.warning.dark))
        lines.append(ColorCodeGenerator.varColorProperty("error", light: palette.error.light, dark: palette.error.dark))
        lines.append(ColorCodeGenerator.varColorProperty("info", light: palette.info.light, dark: palette.info.dark))
        lines.append("")

        // Text
        lines.addMark("Text Colors")
        lines.append("    var textPrimary: UIColor { .label }")
        lines.append("    var textSecondary: UIColor { .secondaryLabel }")
        lines.append("    var textTertiary: UIColor { .tertiaryLabel }")
        lines.append("")

        // Backgrounds
        lines.addMark("Background Colors")
        lines.append(ColorCodeGenerator.varColorProperty("backgroundPrimary", light: palette.backgroundPrimary.light, dark: palette.backgroundPrimary.dark))
        lines.append(ColorCodeGenerator.varColorProperty("backgroundSecondary", light: palette.backgroundSecondary.light, dark: palette.backgroundSecondary.dark))
        lines.append(ColorCodeGenerator.varColorProperty("backgroundTertiary", light: palette.backgroundTertiary.light, dark: palette.backgroundTertiary.dark))
        lines.append("")

        // Divider
        lines.addMark("Divider & Border")
        lines.append(ColorCodeGenerator.varColorProperty("divider", light: palette.divider.light, dark: palette.divider.dark))
        lines.append("    var imageBorder: UIColor { divider.withAlphaComponent(\(palette.imageBorder.alpha)) }")
        lines.append("")

        // Grays
        lines.addMark("Grays")
        lines.append(ColorCodeGenerator.varGrayProperty("graySoft", lightWhite: palette.graySoft.lightWhite, darkWhite: palette.graySoft.darkWhite))
        lines.append(ColorCodeGenerator.varGrayProperty("grayMuted", lightWhite: palette.grayMuted.lightWhite, darkWhite: palette.grayMuted.darkWhite))
        lines.append("")

        // White / Black
        lines.addMark("White & Black")
        lines.append(ColorCodeGenerator.varColorProperty("white", light: palette.white.light, dark: palette.white.dark))
        lines.append(ColorCodeGenerator.varColorProperty("black", light: palette.black.light, dark: palette.black.dark))
        lines.append("")

        // Photo Browser
        lines.addMark("Photo Browser")
        lines.append(ColorCodeGenerator.varColorProperty("photoBrowserBackground", light: palette.photoBrowserBackground.light, dark: palette.photoBrowserBackground.dark))

        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func generateFallback(config: AppConfig) -> String {
        let themeName = "\(config.name)Theme"
        return """
        import UIKit
        import LumiKitUI

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
