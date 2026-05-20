import Foundation

/// Centralized symbols used across CLI output.
///
/// Before extraction, checkmarks were encoded inconsistently across files:
/// `"\u{2713}"` literal Unicode escape in most places, raw `"✓"` glyph in one,
/// `"\u{2717}"` in another. Unifying them into named constants keeps output
/// consistent and makes future style changes (color, ASCII fallback for non-
/// UTF-8 terminals) trivial.
enum UISymbols {
    /// U+2713 ✓ — success marker.
    static let check = "\u{2713}"

    /// U+2717 ✗ — failure marker (used in tool-availability tables).
    static let cross = "\u{2717}"

    /// U+26A0 ⚠ — warning marker (non-fatal issues, missing optional tools).
    static let warn = "\u{26A0}"

    /// U+21BB ↻ — already-present / idempotent skip marker.
    static let cycle = "\u{21BB}"

    /// U+2500 ─ — light horizontal box-drawing character for separators.
    static let hRule = "\u{2500}"

    /// U+2191 ↑ — up arrow used in wizard back-navigation hints.
    static let upArrow = "\u{2191}"
}
