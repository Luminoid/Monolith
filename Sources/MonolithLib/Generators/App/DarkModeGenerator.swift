import Foundation

/// Generates the standalone `AppTheme` for apps without LumiKit, as adaptive
/// `UIColor { traitCollection in }` colors.
///
/// Member names are `LMKColor` role names, and the roles `ColorDeriver` does
/// not derive (status colors, fills, text colors, `outline`) take LumiKit's
/// default values, so adopting LumiKit later swaps `AppTheme.` for `LMKColor.`
/// without changing a color.
enum DarkModeGenerator {
    /// LumiKit's default `fill` and `fillStrong` grays (white levels, light / dark).
    private static let fill = (light: 0.85, dark: 0.25)
    private static let fillStrong = (light: 0.75, dark: 0.35)

    static func generate(config: AppConfig) -> String {
        guard let palette = ColorDeriver.derive(from: config.primaryColor) else {
            return generateFallback(config: config)
        }

        var lines: [String] = []
        // One MARK section per role group. A blank line separates the members:
        // SwiftFormat's blankLinesBetweenScopes wants one after every
        // `UIColor { traitCollection in ... }` body.
        func section(_ title: String, _ members: [String], isLast: Bool = false) {
            lines.addMark(title)
            lines.append(members.joined(separator: "\n\n"))
            if !isLast { lines.append("") }
        }
        func color(_ name: String, _ pair: ColorDeriver.ColorPair, doc: String? = nil) -> String {
            let property = ColorCodeGenerator.staticColorProperty(name, light: pair.light, dark: pair.dark)
            return doc.map { "    /// \($0)\n" + property } ?? property
        }

        lines.append("import UIKit")
        lines.append("")
        lines.append("/// Adaptive color theme derived from primary color \(config.primaryColor).")
        lines.append("/// Uses UIColor { traitCollection in } for automatic light/dark mode support.")
        lines.append("/// Each accent meets WCAG AA text contrast (4.5:1) against `onAccent` and every")
        lines.append("/// background, in both appearances. Member names match LumiKit's `LMKColor`.")
        lines.append("enum AppTheme {")

        section("Accents", [
            color("primary", palette.primary),
            color("primaryVariant", palette.primaryVariant, doc: "The pressed and selected shade of `primary`."),
            color("secondary", palette.secondary),
            color("tertiary", palette.tertiary),
            color("onAccent", palette.onAccent, doc: "Text and icons on a filled accent; dark in Dark Mode, where the accents are light."),
        ])
        let statusColors = """
            static let success: UIColor = .systemGreen
            static let warning: UIColor = .systemOrange
            static let error: UIColor = .systemRed
            static let info: UIColor = .systemBlue
        """
        section("Status Colors", [statusColors])
        let textColors = """
            static let textPrimary: UIColor = .label
            static let textSecondary: UIColor = .secondaryLabel
            static let textTertiary: UIColor = .tertiaryLabel
        """
        section("Text Colors", [textColors])
        section("Background Colors", [
            color("backgroundPrimary", palette.backgroundPrimary),
            color("backgroundSecondary", palette.backgroundSecondary),
            color("backgroundTertiary", palette.backgroundTertiary),
        ])
        section("Lines and Fills", [
            color("divider", palette.divider),
            "    static let outline: UIColor = divider.withAlphaComponent(0.5)",
            ColorCodeGenerator.staticGrayProperty("fill", lightWhite: fill.light, darkWhite: fill.dark),
            ColorCodeGenerator.staticGrayProperty("fillStrong", lightWhite: fillStrong.light, darkWhite: fillStrong.dark),
        ], isLast: true)

        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func generateFallback(config: AppConfig) -> String {
        """
        import UIKit

        /// Adaptive color theme with system defaults.
        /// Primary color \(config.primaryColor) could not be parsed, so this uses system colors.
        enum AppTheme {
            static let primary: UIColor = .systemBlue
            static let primaryVariant: UIColor = .systemBlue
            static let secondary: UIColor = .systemGray
            static let tertiary: UIColor = .systemGray2
            static let onAccent: UIColor = .white
            static let success: UIColor = .systemGreen
            static let warning: UIColor = .systemOrange
            static let error: UIColor = .systemRed
            static let info: UIColor = .systemBlue
            static let textPrimary: UIColor = .label
            static let textSecondary: UIColor = .secondaryLabel
            static let textTertiary: UIColor = .tertiaryLabel
            static let backgroundPrimary: UIColor = .systemBackground
            static let backgroundSecondary: UIColor = .secondarySystemBackground
            static let backgroundTertiary: UIColor = .tertiarySystemBackground
            static let divider: UIColor = .separator
            static let outline: UIColor = .separator
            static let fill: UIColor = .systemGray5
            static let fillStrong: UIColor = .systemGray4
        }

        """
    }
}
