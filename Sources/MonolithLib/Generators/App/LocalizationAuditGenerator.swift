import Foundation

/// Generates the `Scripts/localization/audit_strings.py` script that vets a
/// generated app's `Localizable.xcstrings` for the three failure modes
/// workspace lessons.md flags as bug-magnets:
///
/// 1. **Missing locales** — a key has no translation for one of the supported
///    locales. Surfaces as untranslated UI on the user's device.
/// 2. **Untranslated state** — a key has a value but `state != "translated"`,
///    typically because Xcode auto-extracted it but a translator never
///    confirmed.
/// 3. **Placeholder arity mismatch** — `en` uses `%lld` but `es` dropped it.
///    Foundation crashes at runtime when the format-arg list disagrees with
///    the format string.
/// 4. **Swift interpolation keys** — `String(localized: "name \(value)")`
///    bakes the format specifier (`%lld`, `%@`, `%f`) into the catalog key.
///    A literal `\(...)` in the key means lookup silently misses and the
///    raw key renders as text. Reference:
///    workspace `rules/lessons.md` → "Localization (String Catalogs)".
///
/// The generated script reads the project's `Localizable.xcstrings` and exits
/// non-zero when any issue is found, so it slots cleanly into `make check`.
enum LocalizationAuditGenerator {
    /// `appName` is the app target's name (used to construct the relative
    /// path to `Localizable.xcstrings`). `locales` is the comma-separated list
    /// of locale codes the catalog supports — defaults to `en, es, zh-Hans`
    /// to match the workspace standard.
    static func generate(appName: String, locales: [String] = ["en", "es", "zh-Hans"]) -> String {
        let localeTuple = locales.map { "\"\($0)\"" }.joined(separator: ", ")
        return """
        #!/usr/bin/env python3
        r\"""Audit `Localizable.xcstrings` for gaps across \(locales.joined(separator: " / ")).

        Reports:
          * keys missing any supported locale
          * keys with state != "translated"
          * placeholder arity mismatches between locales (e.g. en has %@ but es
            dropped it)
          * keys containing Swift `\\(...)` interpolation (always wrong — the
            catalog key needs the baked format specifier, not the source form)

        Run from the repo root:
            python3 Scripts/localization/audit_strings.py
        \"""
        from __future__ import annotations

        import json
        import re
        import sys
        from pathlib import Path

        LOCALES = (\(localeTuple))
        PLACEHOLDER_RE = re.compile(r"%(?:\\d+\\$)?(?:@|lld|ld|d|f|%)")
        SWIFT_INTERPOLATION_RE = re.compile(r"\\\\\\(")
        XCSTRINGS = (
            Path(__file__).resolve().parents[2]
            / "\(appName)"
            / "Resources"
            / "Localizable.xcstrings"
        )


        def units_for_locale(locale_entry: dict) -> list[dict]:
            \"""Return all stringUnit dicts for a locale entry, flattening plural variations.\"""
            if "stringUnit" in locale_entry:
                return [locale_entry["stringUnit"]]
            units: list[dict] = []
            variations = locale_entry.get("variations", {})
            plural = variations.get("plural", {})
            for form_entry in plural.values():
                if "stringUnit" in form_entry:
                    units.append(form_entry["stringUnit"])
            return units


        def main() -> int:
            if not XCSTRINGS.exists():
                print(f"error: {XCSTRINGS} not found", file=sys.stderr)
                return 2
            payload = json.loads(XCSTRINGS.read_text())
            strings = payload.get("strings", {})

            issues: list[str] = []
            for key, entry in sorted(strings.items()):
                if SWIFT_INTERPOLATION_RE.search(key):
                    issues.append(
                        f"{key}: key contains Swift interpolation \\\\(...) — "
                        "use %@ / %lld / %f format specifiers instead "
                        "(Foundation looks up the format-specifier form, so this key never resolves)"
                    )
                localizations = entry.get("localizations", {})
                placeholder_sets: dict[str, tuple[str, ...]] = {}
                for locale in LOCALES:
                    units = units_for_locale(localizations.get(locale, {}))
                    if not units:
                        issues.append(f"{key}: missing {locale}")
                        continue
                    for unit in units:
                        if unit.get("state") != "translated":
                            issues.append(f"{key}: {locale} state={unit.get('state')}")
                    placeholders: list[str] = []
                    for unit in units:
                        placeholders.extend(PLACEHOLDER_RE.findall(unit.get("value", "")))
                    placeholder_sets[locale] = tuple(sorted(set(placeholders)))
                unique = {tuple(v) for v in placeholder_sets.values()}
                if len(unique) > 1:
                    issues.append(f"{key}: placeholder mismatch {placeholder_sets}")

            if issues:
                for issue in issues:
                    print(issue)
                print(f"\\n{len(issues)} issue(s) across {len(strings)} keys")
                return 1

            print(f"OK: {len(strings)} keys, all locales translated, placeholders aligned")
            return 0


        if __name__ == "__main__":
            sys.exit(main())
        """
    }
}
