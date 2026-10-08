import Foundation
import os

/// Centralized wrapper around `Process()` invocations.
///
/// Every utility that shells out (xcodegen, swift package resolve, git, open,
/// which, etc.) previously duplicated the same Process setup + try/catch
/// boilerplate, with each call site catching errors silently, losing
/// `error.localizedDescription` and giving the user no diagnostic.
///
/// `ShellRunner` collapses all that into one place. Three variants, picked by
/// what the caller needs to do on failure:
///
/// - `run(...)` — full `Output` (exit status + stdout + stderr) or throws
///   `RunError` when the process can't launch. Use when the caller needs to
///   branch on the actual output or wants to attach the stderr to a
///   higher-level error message. Most callers don't need this; the two
///   convenience wrappers below cover the common shapes.
///
/// - `runDiscardingOutput(...)` — returns `Bool`, prints a warning to stderr
///   on failure but does NOT propagate the error. Use when the shell-out is
///   **best-effort and the caller should continue regardless**:
///   `swift package resolve` failing shouldn't undo the freshly scaffolded
///   project (the user can re-resolve later), `git init` failing shouldn't
///   prevent the files from being written, `open Xcode` failing shouldn't
///   crash the CLI. The warning carries the child's stderr (or its stdout when
///   stderr is empty); the `Bool` lets the caller skip downstream steps that
///   depend on success.
///
/// - `runCapturingStdout(...)` — returns `String?` of the trimmed output, or
///   `nil` on any failure. Use for read-only tool probes (`git config
///   user.name`, `which xcodegen`) where you want the value if it's there and
///   are fine with nil otherwise. Probes never stream, even under `--verbose`.
///
/// Pipes are drained while the child runs, stdout and stderr on separate
/// threads. A child that fills one pipe's buffer (64 KB) blocks until it is
/// read, so waiting for exit first, or reading one pipe to the end before the
/// other, can deadlock.
enum ShellRunner {
    struct Output {
        /// The exit status, or the signal number when `terminatedBySignal`.
        let exitCode: Int32
        let stdout: String
        let stderr: String
        /// Whether a signal ended the process (Ctrl-C reaches children too).
        var terminatedBySignal = false
    }

    /// The process could not be launched (binary missing, permission
    /// denied, and so on). A process that runs and fails is an `Output`.
    enum RunError: Error, CustomStringConvertible {
        case launchFailed(String)

        var description: String {
            switch self {
            case let .launchFailed(message): "launch failed: \(message)"
            }
        }
    }

    /// The most lines of child output a failure warning quotes; longer output keeps its tail.
    static let failureDetailLineLimit = 20

    private static let verboseState = OSAllocatedUnfairLock(initialState: false)

    /// When true (`--verbose`), `run` and `runDiscardingOutput` stream the
    /// child's stdout and stderr to the terminal as they arrive, while still
    /// capturing them for failure messages.
    static var isVerbose: Bool {
        get { verboseState.withLock { $0 } }
        set { verboseState.withLock { $0 = newValue } }
    }

    /// Run a process and return captured output. Throws `RunError.launchFailed`
    /// on `Process.run()` failure (binary missing, permission denied, etc).
    ///
    /// `streamOutput` overrides ``isVerbose`` for this call. When streaming,
    /// a stream that isn't captured goes straight to the terminal.
    static func run(
        executable: String,
        arguments: [String],
        cwd: String? = nil,
        captureStdout: Bool = false,
        captureStderr: Bool = false,
        streamOutput: Bool? = nil
    ) throws(RunError) -> Output {
        let stream = streamOutput ?? isVerbose
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let cwd {
            process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }

        let stdoutPipe = captureStdout ? Pipe() : nil
        let stderrPipe = captureStderr ? Pipe() : nil
        let passthroughOut: FileHandle = stream ? .standardOutput : .nullDevice
        let passthroughErr: FileHandle = stream ? .standardError : .nullDevice
        process.standardOutput = stdoutPipe ?? passthroughOut
        process.standardError = stderrPipe ?? passthroughErr

        if stream {
            // Our own buffered progress lines go out before the child's.
            fflush(stdout)
        }
        do {
            try process.run()
        } catch {
            throw RunError.launchFailed(error.localizedDescription)
        }

        // stderr drains on its own thread, never a GCD global queue: callers
        // block here synchronously, and when they are Swift concurrency
        // threads (a parallel test run) they can occupy the width the
        // default-QoS global queue shares with the cooperative pool, so a
        // block queued there never starts and the wait below never returns.
        let stderrData = DataBox()
        let stderrDone = DispatchSemaphore(value: 0)
        if let stderrPipe {
            let handle = stderrPipe.fileHandleForReading
            let reader = Thread {
                stderrData.data = drain(handle, echoTo: stream ? .standardError : nil)
                stderrDone.signal()
            }
            reader.start()
        } else {
            stderrDone.signal()
        }
        let stdoutData = stdoutPipe.map { drain($0.fileHandleForReading, echoTo: stream ? .standardOutput : nil) } ?? Data()
        stderrDone.wait()
        process.waitUntilExit()

        return Output(
            exitCode: process.terminationStatus,
            stdout: lossyUTF8(stdoutData),
            stderr: lossyUTF8(stderrData.data),
            terminatedBySignal: process.terminationReason == .uncaughtSignal
        )
    }

    /// Run a process and discard output. Returns `true` on success.
    /// On failure, warns on stderr with `failureLabel` and the launch error,
    /// or the exit code plus the child's stderr (its stdout when stderr is empty).
    @discardableResult
    static func runDiscardingOutput(
        executable: String,
        arguments: [String],
        cwd: String? = nil,
        successLabel: String? = nil,
        failureLabel: String? = nil
    ) -> Bool {
        do {
            let output = try run(
                executable: executable,
                arguments: arguments,
                cwd: cwd,
                captureStdout: true,
                captureStderr: true
            )
            guard output.exitCode == 0 else {
                if let failureLabel {
                    Console.warn("\(failureLabel) \(failureDetail(for: output))")
                }
                return false
            }
            if let successLabel {
                print("  \(UISymbols.check) \(successLabel)")
            }
            return true
        } catch {
            if let failureLabel, case let .launchFailed(message) = error {
                Console.warn("\(failureLabel): \(message)")
            }
            return false
        }
    }

    /// Run a process and return its trimmed stdout, or nil on failure or
    /// empty output. Used by `ToolChecker` for `which` and version queries.
    /// `mergeStderr` sends stderr into the same pipe and returns the output
    /// even on a non-zero exit (some tools print `--version` to stderr).
    static func runCapturingStdout(
        executable: String,
        arguments: [String],
        cwd: String? = nil,
        mergeStderr: Bool = false
    ) -> String? {
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            if let cwd {
                process.currentDirectoryURL = URL(fileURLWithPath: cwd)
            }

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = mergeStderr ? pipe : FileHandle.nullDevice

            try process.run()
            // One pipe, read to the end before waiting, so a chatty child can't block on a full buffer.
            let data = drain(pipe.fileHandleForReading, echoTo: nil)
            process.waitUntilExit()
            guard process.terminationStatus == 0 || mergeStderr else { return nil }

            let text = lossyUTF8(data).trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }

    /// `(exit N)`, `(exit N: one line)`, or `(exit N):` followed by the indented
    /// output, from stderr or, when stderr is empty, stdout. A process a
    /// signal ended reads `(signal N…)` instead.
    static func failureDetail(for output: Output) -> String {
        let status = output.terminatedBySignal ? "signal \(output.exitCode)" : "exit \(output.exitCode)"
        let stderr = output.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = stderr.isEmpty ? output.stdout.trimmingCharacters(in: .whitespacesAndNewlines) : stderr
        guard !text.isEmpty else { return "(\(status))" }
        var lines = text.components(separatedBy: .newlines)
        if lines.count == 1 {
            return "(\(status): \(text))"
        }
        if lines.count > failureDetailLineLimit {
            let dropped = lines.count - failureDetailLineLimit
            lines = ["... (\(dropped) earlier lines)"] + lines.suffix(failureDetailLineLimit)
        }
        return "(\(status)):\n" + lines.map { "      \($0)" }.joined(separator: "\n")
    }

    /// `data` as UTF-8, with U+FFFD for invalid bytes. A failable decode
    /// would drop a tool's whole output, diagnostics included, over one
    /// stray byte.
    static func lossyUTF8(_ data: Data) -> String {
        // swiftlint:disable:next optional_data_string_conversion
        String(decoding: data, as: UTF8.self)
    }

    /// Reads `handle` until end of file, echoing each chunk as it arrives. A
    /// read error ends the output early instead of raising: `availableData`
    /// raises an Objective-C exception Swift can't catch.
    private static func drain(_ handle: FileHandle, echoTo echo: FileHandle?) -> Data {
        var data = Data()
        while let chunk = try? handle.read(upToCount: 65536), !chunk.isEmpty {
            data.append(chunk)
            try? echo?.write(contentsOf: chunk)
        }
        return data
    }

    /// Carries the stderr bytes off the reader thread; the semaphore orders the write before the read.
    private final class DataBox: @unchecked Sendable {
        var data = Data()
    }
}
