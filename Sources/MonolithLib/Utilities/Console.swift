import Foundation

/// Where CLI output goes: progress on stdout, warnings and errors on stderr.
///
/// Keeping warnings off stdout lets a script capture the progress log (or
/// discard it) and still see what went wrong, and lets `2>` collect only the
/// problems.
enum Console {
    /// Writes `line` and a newline to stderr. Flushes stdout first so the two
    /// streams stay in order when both go to the same terminal or file.
    static func printError(_ line: String) {
        fflush(stdout)
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }

    /// `  ⚠ message` on stderr, for a problem the command recovers from.
    static func warn(_ message: String) {
        printError("  \(UISymbols.warn) \(message)")
    }
}
