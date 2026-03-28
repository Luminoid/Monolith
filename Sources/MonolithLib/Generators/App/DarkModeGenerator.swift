import Foundation

/// Generates standalone AppTheme for apps without LumiKit.
/// Uses ColorDeriver to produce adaptive UIColor { traitCollection in } patterns.
enum DarkModeGenerator {
    static func generate(config: AppConfig) -> String {
        guard let palette = ColorDeriver.derive(from: config.primaryColor) else {
            return generateFallback(config: config)
        }

        var lines: [String] = []

        lines.append("import UIKit")
        lines.append("")
        lines.append("/// Adaptive color theme derived from primary color \(config.primaryColor).")
        lines.append("/// Uses UIColor { traitCollection in } for automatic light/dark mode support.")
        lines.append("enum AppTheme {")

        // Primary
        lines.addMark("Primary Colors")
        lines.append(ColorCodeGenerator.staticColorProperty("primary", light: palette.primary.light, dark: palette.primary.dark))
        lines.append(ColorCodeGenerator.staticColorProperty("primaryDark", light: palette.primaryDark.light, dark: palette.primaryDark.dark))
        lines.append("")

        // Secondary / Tertiary
        lines.addMark("Secondary & Tertiary")
        lines.append(ColorCodeGenerator.staticColorProperty("secondary", light: palette.secondary.light, dark: palette.secondary.dark))
        lines.append(ColorCodeGenerator.staticColorProperty("tertiary", light: palette.tertiary.light, dark: palette.tertiary.dark))
        lines.append("")

        // Semantic
        lines.addMark("Semantic Colors")
        lines.append(ColorCodeGenerator.staticColorProperty("success", light: palette.success.light, dark: palette.success.dark))
        lines.append(ColorCodeGenerator.staticColorProperty("warning", light: palette.warning.light, dark: palette.warning.dark))
        lines.append(ColorCodeGenerator.staticColorProperty("error", light: palette.error.light, dark: palette.error.dark))
        lines.append(ColorCodeGenerator.staticColorProperty("info", light: palette.info.light, dark: palette.info.dark))
        lines.append("")

        // Text
        lines.addMark("Text Colors")
        lines.append("    static let textPrimary: UIColor = .label")
        lines.append("    static let textSecondary: UIColor = .secondaryLabel")
        lines.append("    static let textTertiary: UIColor = .tertiaryLabel")
        lines.append("")

        // Backgrounds
        lines.addMark("Background Colors")
        lines.append(ColorCodeGenerator.staticColorProperty("backgroundPrimary", light: palette.backgroundPrimary.light, dark: palette.backgroundPrimary.dark))
        lines.append(ColorCodeGenerator.staticColorProperty("backgroundSecondary", light: palette.backgroundSecondary.light, dark: palette.backgroundSecondary.dark))
        lines.append(ColorCodeGenerator.staticColorProperty("backgroundTertiary", light: palette.backgroundTertiary.light, dark: palette.backgroundTertiary.dark))
        lines.append("")

        // Divider
        lines.addMark("Divider & Border")
        lines.append(ColorCodeGenerator.staticColorProperty("divider", light: palette.divider.light, dark: palette.divider.dark))
        lines.append("    static let imageBorder: UIColor = divider.withAlphaComponent(\(palette.imageBorder.alpha))")
        lines.append("")

        // Grays
        lines.addMark("Grays")
        lines.append(ColorCodeGenerator.staticGrayProperty("graySoft", lightWhite: palette.graySoft.lightWhite, darkWhite: palette.graySoft.darkWhite))
        lines.append(ColorCodeGenerator.staticGrayProperty("grayMuted", lightWhite: palette.grayMuted.lightWhite, darkWhite: palette.grayMuted.darkWhite))
        lines.append("")

        // White / Black
        lines.addMark("White & Black")
        lines.append(ColorCodeGenerator.staticColorProperty("white", light: palette.white.light, dark: palette.white.dark))
        lines.append(ColorCodeGenerator.staticColorProperty("black", light: palette.black.light, dark: palette.black.dark))
        lines.append("")

        // Photo Browser
        lines.addMark("Photo Browser")
        lines.append(ColorCodeGenerator.staticColorProperty("photoBrowserBackground", light: palette.photoBrowserBackground.light, dark: palette.photoBrowserBackground.dark))

        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func generateFallback(config: AppConfig) -> String {
        """
        import UIKit

        /// Adaptive color theme with system defaults.
        /// Primary color \(config.primaryColor) could not be parsed — using system colors.
        enum AppTheme {
            static let primary: UIColor = .systemBlue
            static let primaryDark: UIColor = .systemBlue
            static let secondary: UIColor = .systemGray
            static let tertiary: UIColor = .systemGray2
            static let success: UIColor = .systemGreen
            static let warning: UIColor = .systemOrange
            static let error: UIColor = .systemRed
            static let info: UIColor = .systemCyan
            static let textPrimary: UIColor = .label
            static let textSecondary: UIColor = .secondaryLabel
            static let textTertiary: UIColor = .tertiaryLabel
            static let backgroundPrimary: UIColor = .systemBackground
            static let backgroundSecondary: UIColor = .secondarySystemBackground
            static let backgroundTertiary: UIColor = .tertiarySystemBackground
            static let divider: UIColor = .separator
            static let imageBorder: UIColor = .separator
            static let graySoft: UIColor = .systemGray4
            static let grayMuted: UIColor = .systemGray5
            static let white: UIColor = .white
            static let black: UIColor = .black
            static let photoBrowserBackground: UIColor = UIColor(white: 0.1, alpha: 1)
        }
        """
    }
}
