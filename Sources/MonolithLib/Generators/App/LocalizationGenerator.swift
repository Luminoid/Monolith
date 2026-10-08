import Foundation

enum LocalizationGenerator {
    /// The `L10n` group a catalog key's constant lives in.
    private enum Section { case app, common, tab }

    /// One catalog key: its source-language value, the translator comment, and
    /// the `L10n` constant that reads it. A key the code reads inline (the View
    /// menu's Refresh title) has no constant and no section.
    private struct Entry {
        let key: String
        let value: String
        let comment: String
        let constant: String?
        let section: Section?
    }

    /// Generate a Localizable.xcstrings String Catalog with sample keys.
    ///
    /// Each key gets a `localizations` entry for every locale in `config.locales`.
    /// The first locale is treated as the **source language**; subsequent locales
    /// start in `state: "new"` (not yet translated) so the localization audit
    /// surfaces them as outstanding work. Source-language entries are
    /// `state: "translated"` with the literal English value as a starting
    /// point; adopters fill in actual translations. Each key carries the same
    /// translator comment as the code that reads it (its `L10n` constant, or the
    /// View menu's inline lookup), which is what Xcode would extract.
    static func generateStringCatalog(config: AppConfig) -> String {
        let locales = config.locales.isEmpty ? ["en"] : config.locales
        let sourceLocale = locales[0]

        var strings: [String] = []
        for entry in entries(for: config) {
            let value = escaped(entry.value)
            var localizationLines: [String] = []
            for (index, locale) in locales.enumerated() {
                let state = index == 0 ? "translated" : "new"
                // Non-source locales start with the source value as a
                // placeholder so the file parses; adopters replace it with the
                // real translation. `state: new` keeps the audit honest: the
                // entry exists but isn't claimed as translated.
                localizationLines.append("""
                                "\(locale)": {
                                    "stringUnit": {
                                        "state": "\(state)",
                                        "value": "\(value)"
                                    }
                                }
                """)
            }
            strings.append("""
                    "\(entry.key)": {
                        "comment": "\(escaped(entry.comment))",
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

    /// Generate an L10n helper enum of `String(localized:defaultValue:comment:)`
    /// constants. The default value is the source-language text, so a key missing
    /// from the catalog still shows readable text instead of the raw key.
    static func generateL10n(config: AppConfig) -> String {
        let all = entries(for: config)
        func constants(in section: Section, indent: String) -> [String] {
            all.filter { $0.section == section }.compactMap { entry in
                entry.constant.map { constant in
                    "\(indent)static let \(constant) = String(localized: \"\(entry.key)\", defaultValue: \"\(escaped(entry.value))\", comment: \"\(escaped(entry.comment))\")"
                }
            }
        }

        var lines: [String] = []
        lines.append("import Foundation")
        lines.append("")
        lines.append("enum L10n {")

        // App
        lines.addMark("App")
        lines.append(contentsOf: constants(in: .app, indent: "    "))
        lines.append("")

        // Common
        lines.addMark("Common")
        lines.append(contentsOf: constants(in: .common, indent: "    "))

        // Tabs
        if !config.tabs.isEmpty {
            lines.addMark("Tabs")
            lines.append("    enum Tab {")
            lines.append(contentsOf: constants(in: .tab, indent: "        "))
            lines.append("    }")
        }

        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    /// The catalog keys for `config`, in catalog order.
    private static func entries(for config: AppConfig) -> [Entry] {
        var entries = [
            Entry(key: "app.title", value: config.name, comment: "The app's name", constant: "appTitle", section: .app),
            Entry(key: "common.ok", value: "OK", comment: "Button that accepts an alert", constant: "ok", section: .common),
            Entry(key: "common.cancel", value: "Cancel", comment: "Button that dismisses without saving", constant: "cancel", section: .common),
            Entry(key: "common.settings", value: "Settings", comment: "Title of the Settings screen", constant: "settings", section: .common),
            Entry(key: "common.done", value: "Done", comment: "Button that finishes editing", constant: "done", section: .common),
            Entry(key: "common.error", value: "Error", comment: "Title of an error alert", constant: "error", section: .common),
        ]
        for tab in config.tabs {
            entries.append(Entry(
                key: "tab.\(tab.name.lowercased())",
                value: tab.name,
                comment: "Tab bar title",
                constant: tab.name.prefix(1).lowercased() + tab.name.dropFirst(),
                section: .tab
            ))
        }
        if config.hasTabs {
            // The View menu's Refresh (⌘R) exists on every idiom whenever the
            // app has tabs (`AppDelegateGenerator.menu`), which reads this key
            // inline rather than through an `L10n` constant.
            let refresh = AppDelegateGenerator.refreshCommandTitle
            entries.append(Entry(key: refresh.key, value: refresh.value, comment: refresh.comment, constant: nil, section: nil))
        }
        return entries
    }

    /// `text` as the body of a JSON or Swift string literal (both escape a
    /// backslash and a double quote the same way; in Swift an unescaped
    /// backslash would start an escape or an interpolation).
    private static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}
