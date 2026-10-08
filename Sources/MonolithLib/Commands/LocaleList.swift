import ArgumentParser

/// `--locales` on `new app` and `add localization`.
enum LocaleList {
    /// Comma-separated locale identifiers (`en`, `zh-Hans`, `pt-BR`), the
    /// first being the source language. Checked for shape and duplicates
    /// with the rules `AppConfig.validateForGeneration` applies, since a bad
    /// identifier would only surface later as an unused catalog column.
    static func parse(_ input: String) throws -> [String] {
        let locales = CommaList.tokens(input)
        guard !locales.isEmpty else {
            throw ValidationError("--locales needs at least one locale, e.g. 'en' or 'en,zh-Hans,es'.")
        }
        if let invalid = locales.first(where: { !Validators.validateLocale($0) }) {
            throw ValidationError("Invalid locale '\(invalid)' in --locales. Use identifiers such as en, zh-Hans, or pt-BR.")
        }
        if let duplicate = DuplicateNames.find(in: locales, ignoringCase: true).first {
            throw ValidationError("Locale '\(duplicate)' appears more than once in --locales.")
        }
        return locales
    }
}
