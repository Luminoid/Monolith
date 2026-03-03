import Foundation

enum LocalizationGenerator {
    /// Generate a Localizable.xcstrings String Catalog with sample keys.
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

        var strings: [String] = []
        for entry in entries {
            let escaped = entry.value.replacingOccurrences(of: "\"", with: "\\\"")
            strings.append("""
                    "\(entry.key)": {
                        "localizations": {
                            "en": {
                                "stringUnit": {
                                    "state": "translated",
                                    "value": "\(escaped)"
                                }
                            }
                        }
                    }
            """)
        }

        return """
        {
            "sourceLanguage": "en",
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
        lines.append("")

        // App
        lines.addMark("App")
        lines.append("    static let appTitle = String(localized: \"app.title\")")
        lines.append("")

        // Common
        lines.addMark("Common")
        lines.append("    static let ok = String(localized: \"common.ok\")")
        lines.append("    static let cancel = String(localized: \"common.cancel\")")
        lines.append("    static let settings = String(localized: \"common.settings\")")
        lines.append("    static let done = String(localized: \"common.done\")")
        lines.append("    static let error = String(localized: \"common.error\")")

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

        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }
}
