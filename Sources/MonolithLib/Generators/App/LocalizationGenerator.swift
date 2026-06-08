import Foundation

enum LocalizationGenerator {
    /// Default locales for the workspace convention: en + Simplified Chinese + Spanish.
    /// Matches Petfolio (and Plantfolio's 4-locale set minus zh-Hant) — apps
    /// that ship in the Lumi ecosystem typically target these three. Apps
    /// targeting fewer locales pass `--locales en`; apps targeting more pass
    /// the full list including their additions.
    static let defaultLocales = ["en", "zh-Hans", "es"]

    /// Generate a Localizable.xcstrings String Catalog with sample keys.
    ///
    /// Each key gets a `localizations` entry for every locale in `config.locales`.
    /// The first locale is treated as the **source language**; subsequent locales
    /// start in `state: "new"` (not yet translated) so the localization audit
    /// surfaces them as outstanding work. Source-language entries are
    /// `state: "translated"` with the literal English value as a starting
    /// point — adopters fill in actual translations.
    static func generateStringCatalog(config: AppConfig) -> String {
        var entries: [(key: String, value: String)] = [
            ("app.title", config.name),
            ("common.ok", "OK"),
            ("common.cancel", "Cancel"),
            ("common.settings", "Settings"),
            ("common.done", "Done"),
            ("common.error", "Error"),
        ]

        for tab in config.tabs {
            entries.append(("tab.\(tab.name.lowercased())", tab.name))
        }

        if config.hasMacCatalyst {
            // ⌘R Refresh command in the Mac Catalyst menu (AppDelegate.buildMenu).
            entries.append(("menu.refresh", "Refresh"))
        }

        let locales = config.locales.isEmpty ? ["en"] : config.locales
        let sourceLocale = locales[0]

        var strings: [String] = []
        for entry in entries {
            let escaped = entry.value.replacingOccurrences(of: "\"", with: "\\\"")
            var localizationLines: [String] = []
            for (index, locale) in locales.enumerated() {
                let state = index == 0 ? "translated" : "new"
                // Non-source locales start with the source value as a
                // placeholder so the file parses; adopters replace it with the
                // real translation. `state: new` keeps the audit honest — the
                // entry exists but isn't claimed as translated.
                localizationLines.append("""
                                "\(locale)": {
                                    "stringUnit": {
                                        "state": "\(state)",
                                        "value": "\(escaped)"
                                    }
                                }
                """)
            }
            strings.append("""
                    "\(entry.key)": {
                        "localizations": {
            \(localizationLines.joined(separator: ",\n"))
                        }
                    }
            """)
        }

        return """
        {
            "sourceLanguage": "\(sourceLocale)",
            "version": "1.0",
            "strings": {
        \(strings.joined(separator: ",\n"))
            }
        }
        """
    }

    /// Generate an L10n helper enum with String(localized:) constants.
    static func generateL10n(config: AppConfig) -> String {
        var lines: [String] = []

        lines.append("import Foundation")
        lines.append("")
        lines.append("enum L10n {")

        // App
        lines.addMark("App")
        lines.append("    static let appTitle = String(localized: \"app.title\")")
        lines.append("")

        // Common
        lines.addMark("Common")
        lines.append(contentsOf: """
            static let ok = String(localized: "common.ok")
            static let cancel = String(localized: "common.cancel")
            static let settings = String(localized: "common.settings")
            static let done = String(localized: "common.done")
            static let error = String(localized: "common.error")
        """.components(separatedBy: "\n"))

        // Tabs
        if !config.tabs.isEmpty {
            lines.addMark("Tabs")
            lines.append("    enum Tab {")
            for tab in config.tabs {
                let propertyName = tab.name.prefix(1).lowercased() + tab.name.dropFirst()
                lines.append("        static let \(propertyName) = String(localized: \"tab.\(tab.name.lowercased())\")")
            }
            lines.append("    }")
        }

        // Menu (Mac Catalyst)
        if config.hasMacCatalyst {
            lines.addMark("Menu")
            lines.append("    enum Menu {")
            lines.append("        static let refresh = String(localized: \"menu.refresh\")")
            lines.append("    }")
        }

        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }
}
