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
/// - `run(...)` — full `Output` (exitCode + stdout + stderr) or throws
///   `RunError`. Use when the caller needs to branch on the actual output or
///   wants to attach the stderr to a higher-level error message. Most callers
///   don't need this; the two convenience wrappers below cover the common
///   shapes.
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
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    enum RunError: Error, CustomStringConvertible {
        case launchFailed(String)
        case nonZeroExit(Int32, stderr: String)

        var description: String {
            switch self {
            case let .launchFailed(message): "launch failed: \(message)"
            case let .nonZeroExit(code, stderr):
                stderr.isEmpty ? "exited with code \(code)" : "exited with code \(code): \(stderr)"
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
    ) throws -> Output {
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
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData.data, encoding: .utf8) ?? ""
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
        } catch let RunError.launchFailed(message) {
            if let failureLabel {
                Console.warn("\(failureLabel): \(message)")
            }
            return false
        } catch {
            if let failureLabel {
                Console.warn("\(failureLabel): \(error)")
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

            let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }

    /// `(exit N)`, `(exit N: one line)`, or `(exit N):` followed by the indented
    /// output, from stderr or, when stderr is empty, stdout.
    static func failureDetail(for output: Output) -> String {
        let stderr = output.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = stderr.isEmpty ? output.stdout.trimmingCharacters(in: .whitespacesAndNewlines) : stderr
        guard !text.isEmpty else { return "(exit \(output.exitCode))" }
        var lines = text.components(separatedBy: .newlines)
        if lines.count == 1 {
            return "(exit \(output.exitCode): \(text))"
        }
        if lines.count > failureDetailLineLimit {
            let dropped = lines.count - failureDetailLineLimit
            lines = ["... (\(dropped) earlier lines)"] + lines.suffix(failureDetailLineLimit)
        }
        return "(exit \(output.exitCode)):\n" + lines.map { "      \($0)" }.joined(separator: "\n")
    }

    /// Reads `handle` until end of file, echoing each chunk as it arrives.
    private static func drain(_ handle: FileHandle, echoTo echo: FileHandle?) -> Data {
        var data = Data()
        while true {
            let chunk = handle.availableData
            if chunk.isEmpty { break }
            data.append(chunk)
            echo?.write(chunk)
        }
        return data
    }

    /// Carries the stderr bytes off the reader thread; the semaphore orders the write before the read.
    private final class DataBox: @unchecked Sendable {
        var data = Data()
    }
}
