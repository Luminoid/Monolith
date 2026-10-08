import Foundation

/// Ctrl-C (SIGINT) while a `new` command writes the project.
///
/// `NewCommandRunner` arms the handler for the writes only. The handler does
/// nothing but record the interrupt and restore the default action (so a
/// second Ctrl-C ends the process at once): it runs in signal context, where
/// only async-signal-safe work is allowed, and touching `Console`, `print`,
/// `FileManager`, or the allocator there can deadlock when the signal lands
/// inside one of them. The rest happens on the main thread:
/// `FileWriter.writeFile` throws `InterruptedError` before its next write,
/// and `NewCommandRunner` removes the partial output and exits with 130.
/// A child process such as xcodegen gets the terminal's SIGINT too, so a
/// `ShellRunner` wait for it returns and the next write stops generation.
///
/// Outside the writes nothing is armed. The wizard's raw-mode Ctrl-C raises
/// SIGINT under the default action, which ends the process with 130 after
/// the terminal is restored. Git init, package resolve, and open run after
/// `uninstall()`, so a Ctrl-C there ends the process and the finished
/// project stays. A SIGINT that was already ignored when Monolith started
/// stays ignored.
enum SignalHandler {
    /// Thrown by `throwIfInterrupted()` once a SIGINT arrived.
    struct InterruptedError: Error, CustomStringConvertible {
        var description: String {
            "Interrupted."
        }
    }

    /// Set by the handler. One preallocated `sig_atomic_t`, so the handler
    /// does a single aligned store and touches no other state.
    private nonisolated(unsafe) static let flag: UnsafeMutablePointer<sig_atomic_t> = {
        let pointer = UnsafeMutablePointer<sig_atomic_t>.allocate(capacity: 1)
        pointer.initialize(to: 0)
        return pointer
    }()

    /// The SIGINT action `install()` replaced; `uninstall()` puts it back.
    private nonisolated(unsafe) static var previousAction: sigaction?

    /// Whether `FileWriter.writeFile` checks for an interrupt. On only while
    /// `NewCommandRunner` generates, so a test that raises SIGINT can't stop
    /// another test's writes.
    @TaskLocal static var guardsWrites = false

    /// Records the interrupt and restores the default action. Both are
    /// async-signal-safe. Internal so tests can run it without a signal.
    static let handler: @convention(c) (Int32) -> Void = { _ in
        Self.flag.pointee = 1
        signal(SIGINT, SIG_DFL)
    }

    /// Arm the handler. Idempotent: a second call keeps the first one's
    /// saved action. Does nothing when SIGINT is ignored.
    static func install() {
        guard previousAction == nil else { return }
        flag.pointee = 0
        var current = sigaction()
        sigaction(SIGINT, nil, &current)
        if isIgnored(current) { return }

        var action = sigaction()
        action.__sigaction_u = __sigaction_u(__sa_handler: handler)
        sigemptyset(&action.sa_mask)
        action.sa_flags = 0
        sigaction(SIGINT, &action, nil)
        previousAction = current
    }

    /// Disarm: restore the action `install()` replaced and clear the flag.
    /// `NewCommandRunner` calls it once the writes are done, so the steps
    /// after them (git init, resolve, open) can't delete a finished project.
    static func uninstall() {
        if var previous = previousAction {
            sigaction(SIGINT, &previous, nil)
        }
        previousAction = nil
        flag.pointee = 0
    }

    /// Whether the handler is armed.
    static var isArmed: Bool {
        previousAction != nil
    }

    /// Whether a SIGINT arrived since `install()`.
    static var wasInterrupted: Bool {
        flag.pointee != 0
    }

    /// Throws `InterruptedError` when a SIGINT arrived since `install()`.
    static func throwIfInterrupted() throws {
        if wasInterrupted {
            throw InterruptedError()
        }
    }

    /// Remove a partially written output directory. Safe to call when the
    /// directory was never created.
    static func removePartialOutput(at path: String) {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return }
        do {
            try fm.removeItem(atPath: path)
            print("  \(UISymbols.check) Removed partial output at \(path)")
        } catch {
            Console.warn("Could not remove partial output at \(path): \(error.localizedDescription)")
        }
    }

    /// `SIG_IGN`, the ignore action, is the handler value 1.
    private static func isIgnored(_ action: sigaction) -> Bool {
        unsafeBitCast(action.__sigaction_u.__sa_handler, to: Int.self) == 1
    }
}
