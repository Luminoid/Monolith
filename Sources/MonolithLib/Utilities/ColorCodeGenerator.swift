/// Shared helpers for generating UIColor Swift code from RGB/gray values.
/// Used by both ThemeGenerator (LMKTheme `var` properties) and DarkModeGenerator (`static let` properties).
enum ColorCodeGenerator {
    /// Generate a `var` color property (for LMKTheme conformance).
    static func varColorProperty(_ name: String, light: ColorDeriver.RGB, dark: ColorDeriver.RGB) -> String {
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

    /// Generate a `var` gray property (for LMKTheme conformance).
    static func varGrayProperty(_ name: String, lightWhite: Double, darkWhite: Double) -> String {
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
