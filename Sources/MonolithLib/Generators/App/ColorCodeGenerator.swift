/// Shared helpers for generating UIColor Swift code from RGB/gray values.
/// Used by both ThemeGenerator (`LMKColorTheme` initializer arguments) and
/// DarkModeGenerator (`static let` properties, including the gray fills).
///
/// **LumiKit-aware emission**: when targeting a LumiKit-enabled project, emits
/// `.lmk_dynamic(lightHex: 0x..., darkHex: 0x...)`, one argument line per
/// color role, about 80% shorter than the inline `UIColor { traitCollection in
/// ... }` form. The standalone path (no LumiKit) keeps the inline form because
/// adding a hex initializer to the app would duplicate work LumiKit already does.
enum ColorCodeGenerator {
    /// Hex literal `0xRRGGBB` from an RGB triple. Used for the `lmk_dynamic`
    /// compact form. `r255`/`g255`/`b255` are already clamped + rounded to
    /// 0...255 in `ColorDeriver.RGB`, so no further clamping needed.
    private static func hexLiteral(_ rgb: ColorDeriver.RGB) -> String {
        String(format: "0x%02X%02X%02X", rgb.r255, rgb.g255, rgb.b255)
    }

    /// One `LMKColorTheme` initializer argument (`role: .lmk_dynamic(lightHex:darkHex:)`),
    /// without indentation or a trailing comma.
    static func lumiKitColorArgument(_ role: String, light: ColorDeriver.RGB, dark: ColorDeriver.RGB) -> String {
        "\(role): .lmk_dynamic(lightHex: \(hexLiteral(light)), darkHex: \(hexLiteral(dark)))"
    }

    /// Generate a `static let` color property (for standalone AppTheme enum).
    static func staticColorProperty(_ name: String, light: ColorDeriver.RGB, dark: ColorDeriver.RGB) -> String {
        """
            static let \(name): UIColor = UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: \(dark.r255) / 255.0, green: \(dark.g255) / 255.0, blue: \(dark.b255) / 255.0, alpha: 1.0)
                    : UIColor(red: \(light.r255) / 255.0, green: \(light.g255) / 255.0, blue: \(light.b255) / 255.0, alpha: 1.0)
            }
        """
    }

    /// Generate a `static let` gray property (for standalone AppTheme enum).
    static func staticGrayProperty(_ name: String, lightWhite: Double, darkWhite: Double) -> String {
        """
            static let \(name): UIColor = UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(white: \(darkWhite), alpha: 1)
                    : UIColor(white: \(lightWhite), alpha: 1)
            }
        """
    }
}
