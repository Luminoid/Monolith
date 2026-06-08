import Foundation

/// Generates the `Scripts/localization/audit_strings.py` script that vets a
/// generated app's `Localizable.xcstrings` for the failure modes workspace
/// lessons.md flags as bug-magnets:
///
/// 1. **Missing locales** — a key has no translation for a locale that other
///    keys in the catalog DO translate. Surfaces as untranslated UI on the
///    user's device.
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
/// The generated script derives the supported-locale set from the catalog
/// itself at runtime (union of every key's `localizations` keys), so a
/// freshly-scaffolded en-only app and a localized en/es/zh-Hans app both
/// audit cleanly with no hand-tuning. It exits non-zero only on genuine
/// breakage (missing locales, placeholder mismatches, raw `\(...)` keys);
/// untranslated entries (state != "translated") are reported as non-fatal
/// warnings, so a freshly-scaffolded multi-locale app still passes
/// `make check` before its translations are filled in.
enum LocalizationAuditGenerator {
    /// `appName` is the app target's name (used to construct the relative
    /// path to `Localizable.xcstrings`).
    static func generate(appName: String) -> String {
        """
        #!/usr/bin/env python3
        r\"""Audit `Localizable.xcstrings` for gaps across the catalog's locales.

        The supported-locale set is derived from the catalog itself (union of
        every key's `localizations` keys), so a freshly-scaffolded en-only
        catalog and a fully-localized en/es/zh-Hans catalog both pass without
        editing this script. Add a new locale by adding a translation to one
        key — the audit picks it up automatically and starts flagging keys
        that haven't been translated yet.

        Fatal (exit 1):
          * keys missing any locale that's translated elsewhere in the catalog
          * placeholder arity mismatches between locales (e.g. en has %@ but es
            dropped it)
          * keys containing Swift `\\(...)` interpolation (always wrong — the
            catalog key needs the baked format specifier, not the source form)

        Warning (exit 0, reported only):
          * keys with state != "translated" (expected pending work; a fresh
            multi-locale scaffold is born with every non-source locale state=new)

        Run from the repo root:
            python3 Scripts/localization/audit_strings.py
        \"""
        from __future__ import annotations

        import json
        import re
        import sys
        from pathlib import Path

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


        def derive_locales(strings: dict) -> tuple[str, ...]:
            \"""Union of every key's localizations keys. Preserves first-seen
            order so reports read deterministically (en first when present).
            \"""
            seen: list[str] = []
            for entry in strings.values():
                for locale in entry.get("localizations", {}):
                    if locale not in seen:
                        seen.append(locale)
            return tuple(seen)


        def main() -> int:
            if not XCSTRINGS.exists():
                print(f"error: {XCSTRINGS} not found", file=sys.stderr)
                return 2
            payload = json.loads(XCSTRINGS.read_text())
            strings = payload.get("strings", {})
            locales = derive_locales(strings)
            if not locales:
                # Empty catalog or every key has no localizations — nothing to
                # audit. `make check` should pass: the catalog is structurally
                # valid, it just has no content yet.
                print(f"OK: {len(strings)} keys, no localizations declared")
                return 0

            # Genuine breakage (fails the build) vs pending work (reported only).
            # Untranslated entries are expected on a fresh multi-locale scaffold
            # (every non-source locale is born state=new), so they must NOT fail
            # `make check`; missing locales, placeholder mismatches, and raw
            # \\(...) keys are real bugs and DO fail.
            errors: list[str] = []
            warnings: list[str] = []
            for key, entry in sorted(strings.items()):
                if SWIFT_INTERPOLATION_RE.search(key):
                    errors.append(
                        f"{key}: key contains Swift interpolation \\\\(...) — "
                        "use %@ / %lld / %f format specifiers instead "
                        "(Foundation looks up the format-specifier form, so this key never resolves)"
                    )
                localizations = entry.get("localizations", {})
                placeholder_sets: dict[str, tuple[str, ...]] = {}
                for locale in locales:
                    units = units_for_locale(localizations.get(locale, {}))
                    if not units:
                        errors.append(f"{key}: missing {locale}")
                        continue
                    for unit in units:
                        if unit.get("state") != "translated":
                            warnings.append(f"{key}: {locale} not yet translated (state={unit.get('state')})")
                    placeholders: list[str] = []
                    for unit in units:
                        placeholders.extend(PLACEHOLDER_RE.findall(unit.get("value", "")))
                    placeholder_sets[locale] = tuple(sorted(set(placeholders)))
                unique = {tuple(v) for v in placeholder_sets.values()}
                if len(unique) > 1:
                    errors.append(f"{key}: placeholder mismatch {placeholder_sets}")

            for warning in warnings:
                print(warning)
            for error in errors:
                print(error)

            scope = f"{len(strings)} keys ({', '.join(locales)})"
            if errors:
                print(f"\\n{len(errors)} error(s), {len(warnings)} untranslated (non-fatal) across {scope}")
                return 1
            if warnings:
                print(f"\\n{len(warnings)} untranslated (non-fatal), 0 errors across {scope}")
                return 0

            print(f"OK: {len(strings)} keys, {len(locales)} locale(s) ({', '.join(locales)}), all translated and placeholders aligned")
            return 0


        if __name__ == "__main__":
            sys.exit(main())
        """
    }
}
