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
        lines.append("    static let textPrimary: UIColor = .label")
        lines.append("    static let textSecondary: UIColor = .secondaryLabel")
        lines.append("    static let textTertiary: UIColor = .tertiaryLabel")
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
        lines.append("    static let imageBorder: UIColor = divider.withAlphaComponent(\(palette.imageBorder.alpha))")
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
            static let \(name): UIColor = UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: \(dark.r255) / 255.0, green: \(dark.g255) / 255.0, blue: \(dark.b255) / 255.0, alpha: 1.0)
                    : UIColor(red: \(light.r255) / 255.0, green: \(light.g255) / 255.0, blue: \(light.b255) / 255.0, alpha: 1.0)
            }
        """
    }

    private static func grayProperty(_ name: String, lightWhite: Double, darkWhite: Double) -> String {
        """
            static let \(name): UIColor = UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(white: \(darkWhite), alpha: 1)
                    : UIColor(white: \(lightWhite), alpha: 1)
            }
        """
    }

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
