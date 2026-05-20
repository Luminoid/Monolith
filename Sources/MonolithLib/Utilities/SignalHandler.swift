import Foundation

/// Graceful SIGINT (Ctrl-C) handling.
///
/// Two scenarios:
///
/// 1. **During the interactive wizard**: `PromptEngine` puts the terminal into
///    raw mode and reads `0x03` directly. It restores the terminal and exits.
///    No file-system cleanup needed because the wizard runs *before* any
///    project files are written.
///
/// 2. **During generation (after the wizard)**: `Process.run()` and
///    `String.write(toFile:)` execute on the main thread without trapping
///    signals. Without a handler, Ctrl-C terminates the process mid-write and
///    leaves a partial output directory behind that the next `--force`-less
///    run will reject.
///
/// `install(cleanup:)` registers a SIGINT handler that invokes the closure on
/// the main thread before exiting. Used by the `new` commands to roll back the
/// output directory if generation is aborted partway.
enum SignalHandler {
    /// Storage for the active cleanup. `nonisolated(unsafe)` because POSIX
    /// signal handlers must use C function pointers — they cannot capture
    /// Swift state. We trampoline through a global var the handler reads.
    private nonisolated(unsafe) static var activeCleanup: (() -> Void)?
    private nonisolated(unsafe) static var installed = false

    /// Install a SIGINT handler that runs `cleanup` and exits with code 130
    /// (the conventional "terminated by SIGINT" exit code).
    ///
    /// Idempotent — the latest `cleanup` replaces any previous one. Tests can
    /// reset by calling `uninstall()`.
    static func install(cleanup: @escaping () -> Void) {
        activeCleanup = cleanup
        guard !installed else { return }

        signal(SIGINT, sigintHandler)
        installed = true
    }

    /// C-compatible signal handler. Must be a top-level non-capturing function
    /// (or a static func with no captures) to convert to `sig_t`.
    private static let sigintHandler: @convention(c) (Int32) -> Void = { _ in
        // Restore default handler so a second Ctrl-C terminates immediately,
        // even if the cleanup hangs.
        signal(SIGINT, SIG_DFL)
        // Print a newline so the next message doesn't sit on the prompt line.
        print()
        print("  \(UISymbols.warn) Interrupted. Cleaning up...")
        activeCleanup?()
        Darwin.exit(130)
    }

    /// Remove the registered cleanup. Used by tests; production code rarely
    /// needs this because the process exits anyway.
    static func uninstall() {
        activeCleanup = nil
        signal(SIGINT, SIG_DFL)
        installed = false
    }

    /// Default cleanup: remove a partially-written output directory if it
    /// exists. Safe to call when the directory was never created.
    static func removePartialOutput(at path: String) {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return }
        do {
            try fm.removeItem(atPath: path)
            print("  \(UISymbols.check) Removed partial output at \(path)")
        } catch {
            print("  \(UISymbols.warn) Could not remove partial output at \(path): \(error.localizedDescription)")
        }
    }
}
