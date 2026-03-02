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
        lines.append("    // MARK: - Primary Colors")
        lines.append("")
        lines.append(colorProperty("primary", light: palette.primary.light, dark: palette.primary.dark))
        lines.append(colorProperty("primaryDark", light: palette.primaryDark.light, dark: palette.primaryDark.dark))
        lines.append("")

        // Secondary / Tertiary
        lines.append("    // MARK: - Secondary & Tertiary")
        lines.append("")
        lines.append(colorProperty("secondary", light: palette.secondary.light, dark: palette.secondary.dark))
        lines.append(colorProperty("tertiary", light: palette.tertiary.light, dark: palette.tertiary.dark))
        lines.append("")

        // Semantic
        lines.append("    // MARK: - Semantic Colors")
        lines.append("")
        lines.append(colorProperty("success", light: palette.success.light, dark: palette.success.dark))
        lines.append(colorProperty("warning", light: palette.warning.light, dark: palette.warning.dark))
        lines.append(colorProperty("error", light: palette.error.light, dark: palette.error.dark))
        lines.append(colorProperty("info", light: palette.info.light, dark: palette.info.dark))
        lines.append("")

        // Text
        lines.append("    // MARK: - Text Colors")
        lines.append("")
        lines.append("    var textPrimary: UIColor { .label }")
        lines.append("    var textSecondary: UIColor { .secondaryLabel }")
        lines.append("    var textTertiary: UIColor { .tertiaryLabel }")
        lines.append("")

        // Backgrounds
        lines.append("    // MARK: - Background Colors")
        lines.append("")
        lines.append(colorProperty("backgroundPrimary", light: palette.backgroundPrimary.light, dark: palette.backgroundPrimary.dark))
        lines.append(colorProperty("backgroundSecondary", light: palette.backgroundSecondary.light, dark: palette.backgroundSecondary.dark))
        lines.append(colorProperty("backgroundTertiary", light: palette.backgroundTertiary.light, dark: palette.backgroundTertiary.dark))
        lines.append("")

        // Divider
        lines.append("    // MARK: - Divider & Border")
        lines.append("")
        lines.append(colorProperty("divider", light: palette.divider.light, dark: palette.divider.dark))
        lines.append("    var imageBorder: UIColor { divider.withAlphaComponent(\(palette.imageBorder.alpha)) }")
        lines.append("")

        // Grays
        lines.append("    // MARK: - Grays")
        lines.append("")
        lines.append(grayProperty("graySoft", lightWhite: palette.graySoft.lightWhite, darkWhite: palette.graySoft.darkWhite))
        lines.append(grayProperty("grayMuted", lightWhite: palette.grayMuted.lightWhite, darkWhite: palette.grayMuted.darkWhite))
        lines.append("")

        // White / Black
        lines.append("    // MARK: - White & Black")
        lines.append("")
        lines.append(colorProperty("white", light: palette.white.light, dark: palette.white.dark))
        lines.append(colorProperty("black", light: palette.black.light, dark: palette.black.dark))
        lines.append("")

        // Photo Browser
        lines.append("    // MARK: - Photo Browser")
        lines.append("")
        lines.append(colorProperty("photoBrowserBackground", light: palette.photoBrowserBackground.light, dark: palette.photoBrowserBackground.dark))

        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func colorProperty(_ name: String, light: ColorDeriver.RGB, dark: ColorDeriver.RGB) -> String {
        """
            var \(name): UIColor {
                UIColor { traitCollection in
                    traitCollection.userInterfaceStyle == .dark
                        ? UIColor(red: \(dark.r255) / 255.0, green: \(dark.g255) / 255.0, blue: \(dark.b255) / 255.0, alpha: 1.0)
                        : UIColor(red: \(light.r255) / 255.0, green: \(light.g255) / 255.0, blue: \(light.b255) / 255.0, alpha: 1.0)
                }
            }
        """
    }

    private static func grayProperty(_ name: String, lightWhite: Double, darkWhite: Double) -> String {
        """
            var \(name): UIColor {
                UIColor { traitCollection in
                    traitCollection.userInterfaceStyle == .dark
                        ? UIColor(white: \(darkWhite), alpha: 1)
                        : UIColor(white: \(lightWhite), alpha: 1)
                }
            }
        """
    }

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
