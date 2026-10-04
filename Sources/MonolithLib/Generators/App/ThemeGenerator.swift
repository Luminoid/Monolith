import Foundation

/// Generates `{Name}Theme.swift`: the app's LumiKit theme as a value,
/// `extension LMKTheme { static let {name} = LMKTheme(colors: LMKColorTheme(...)) }`,
/// which `AppDelegateGenerator` applies at launch with `LMKTheme.apply(.{name})`.
///
/// The palette comes from `ColorDeriver`. Each derived role is one
/// `.lmk_dynamic(lightHex:darkHex:)` argument, so the file reads top to bottom
/// as a palette table. Roles whose LumiKit default already matches the
/// derivation are left out, since `LMKColorTheme` gives every role a default:
/// the text colors (system labels), `outline` (the divider at 50% opacity),
/// and `scrim` (black). The derived `black` pair is not emitted at all: it turns
/// near-white in dark mode, which suits text but not the dimming base `scrim` is.
enum ThemeGenerator {
    static func generate(config: AppConfig) -> String {
        let member = themeMemberName(for: config)
        guard let palette = ColorDeriver.derive(from: config.primaryColor) else {
            return generateFallback(config: config, member: member)
        }

        let colorArguments: [(String, ColorDeriver.ColorPair)] = [
            ("primary", palette.primary),
            ("primaryVariant", palette.primaryDark),
            ("secondary", palette.secondary),
            ("tertiary", palette.tertiary),
            ("success", palette.success),
            ("warning", palette.warning),
            ("error", palette.error),
            ("info", palette.info),
            ("onAccent", palette.white),
            ("backgroundPrimary", palette.backgroundPrimary),
            ("backgroundSecondary", palette.backgroundSecondary),
            ("backgroundTertiary", palette.backgroundTertiary),
            ("divider", palette.divider),
        ]
        var arguments = colorArguments.map { role, pair in
            ColorCodeGenerator.lumiKitColorArgument(role, light: pair.light, dark: pair.dark)
        }
        arguments.append(ColorCodeGenerator.lumiKitGrayArgument(
            "fill",
            lightWhite: palette.grayMuted.lightWhite,
            darkWhite: palette.grayMuted.darkWhite
        ))
        arguments.append(ColorCodeGenerator.lumiKitGrayArgument(
            "fillStrong",
            lightWhite: palette.graySoft.lightWhite,
            darkWhite: palette.graySoft.darkWhite
        ))

        let summary = [
            "/// The app theme, derived from primary color \(config.primaryColor) and applied",
            "/// at launch by `AppDelegate` (`LMKTheme.apply(.\(member))`).",
            "///",
            "/// Roles not passed here keep LumiKit's defaults: the text colors (system",
            "/// labels), `outline` (the divider at 50% opacity), `scrim` (black), and",
            "/// `link` / `selection` (derived from `primary`). Pass one to override it.",
        ]
        return render(member: member, summary: summary, arguments: arguments)
    }

    /// The `LMKTheme` static member the app's theme is declared as: the app name
    /// in lowerCamelCase (`MyApp` to `myApp`, `LMKApp` to `lmkApp`), with a
    /// `Theme` suffix when that would be a Swift keyword or shadow one of
    /// `LMKTheme`'s own static members (`Default` to `defaultTheme`).
    static func themeMemberName(for config: AppConfig) -> String {
        let camel = config.name.upperCamelCased
        let uppercaseRun = camel.prefix { $0.isUppercase }.count
        let nextIsLowercase = camel.dropFirst(uppercaseRun).first?.isLowercase ?? false
        // An acronym run keeps its last capital when a lowercase word follows it
        // (`LMKApp` -> `lmk` + `App`); a single leading capital is just lowered.
        let lowered = uppercaseRun > 1 && nextIsLowercase ? uppercaseRun - 1 : uppercaseRun
        let name = camel.prefix(lowered).lowercased() + camel.dropFirst(lowered)
        let lmkThemeStatics: Set = ["default", "current", "currentReference", "updates", "apply", "update", "reset", "observe"]
        if Validators.reservedNames.contains(name) || lmkThemeStatics.contains(name) {
            return name + "Theme"
        }
        return name
    }

    // MARK: - Helpers

    /// The theme file: imports, the doc comment, and the `LMKTheme` extension with
    /// one `LMKColorTheme` argument per line.
    private static func render(member: String, summary: [String], arguments: [String]) -> String {
        var lines: [String] = []
        lines.append("import LumiKitUI")
        lines.append("import UIKit")
        lines.append("")
        lines.append(contentsOf: summary)
        lines.append("extension LMKTheme {")
        lines.append("    static let \(member) = LMKTheme(")
        lines.append("        colors: LMKColorTheme(")
        for (index, argument) in arguments.enumerated() {
            let separator = index < arguments.count - 1 ? "," : ""
            lines.append("            \(argument)\(separator)")
        }
        lines.append("        )")
        lines.append("    )")
        lines.append("}")
        lines.append("")
        return lines.joined(separator: "\n")
    }

    /// System-color theme for a primary color `ColorDeriver` cannot parse.
    private static func generateFallback(config: AppConfig, member: String) -> String {
        let summary = [
            "/// Fallback theme using system colors, applied at launch by `AppDelegate`",
            "/// (`LMKTheme.apply(.\(member))`). Roles not passed here keep LumiKit's defaults.",
        ]
        let arguments = [
            "primary: .systemBlue",
            "tertiary: .systemGray2",
            "info: .systemCyan",
            "outline: .separator",
            "fill: .systemGray5",
            "fillStrong: .systemGray4",
        ]
        return render(member: member, summary: summary, arguments: arguments)
    }
}
