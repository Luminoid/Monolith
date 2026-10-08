import Foundation

/// Generates `{Name}Theme.swift`: the app's LumiKit theme as a value,
/// `extension LMKTheme { static let {name} = LMKTheme(colors: LMKColorTheme(...)) }`,
/// which `AppDelegateGenerator` applies at launch with `LMKTheme.apply(.{name})`.
///
/// The palette comes from `ColorDeriver`. Each derived role is one
/// `.lmk_dynamic(lightHex:darkHex:)` argument, so the file reads top to bottom
/// as a palette table. Only the roles that differ from LumiKit's defaults are
/// passed (`LMKColorTheme` gives every role a default): the accents,
/// `onAccent`, the backgrounds, and the divider. LumiKit derives
/// `primaryVariant`, `link`, and `selection` from `primary` and `outline` from
/// the divider, and the status colors, fills, text colors, and `scrim` don't
/// depend on the input color, so those keep LumiKit's tuned defaults.
enum ThemeGenerator {
    static func generate(config: AppConfig) -> String {
        let member = themeMemberName(for: config)
        guard let palette = ColorDeriver.derive(from: config.primaryColor) else {
            return generateFallback(config: config, member: member)
        }

        let colorArguments: [(String, ColorDeriver.ColorPair)] = [
            ("primary", palette.primary),
            ("secondary", palette.secondary),
            ("tertiary", palette.tertiary),
            ("onAccent", palette.onAccent),
            ("backgroundPrimary", palette.backgroundPrimary),
            ("backgroundSecondary", palette.backgroundSecondary),
            ("backgroundTertiary", palette.backgroundTertiary),
            ("divider", palette.divider),
        ]
        let arguments = colorArguments.map { role, pair in
            ColorCodeGenerator.lumiKitColorArgument(role, light: pair.light, dark: pair.dark)
        }

        let summary = [
            "/// The app theme, derived from primary color \(config.primaryColor) and applied",
            "/// at launch by `AppDelegate` (`LMKTheme.apply(.\(member))`). Each accent meets",
            "/// WCAG AA text contrast (4.5:1) against `onAccent` and every background, in",
            "/// both appearances; keep that when you adjust one.",
            "///",
            "/// Roles not passed here keep LumiKit's defaults: `primaryVariant`, `link`, and",
            "/// `selection` (derived from `primary`), `outline` (the divider at 50% opacity),",
            "/// the status colors, fills, text colors (system labels), and `scrim`. Pass one",
            "/// to override it.",
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

    /// System-blue theme for a primary color `ColorDeriver` cannot parse.
    private static func generateFallback(config: AppConfig, member: String) -> String {
        let summary = [
            "/// Fallback theme with a system blue `primary`, applied at launch by `AppDelegate`",
            "/// (`LMKTheme.apply(.\(member))`). Every other role keeps LumiKit's default.",
        ]
        let arguments = ["primary: .systemBlue"]
        return render(member: member, summary: summary, arguments: arguments)
    }
}
