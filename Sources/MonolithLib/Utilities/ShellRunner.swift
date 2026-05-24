import Foundation

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
/// - `runDiscardingOutput(...)` — returns `Bool`, prints a one-line warning
///   to the user on failure but does NOT propagate the error. Use when the
///   shell-out is **best-effort and the caller should continue regardless**:
///   `swift package resolve` failing shouldn't undo the freshly scaffolded
///   project (the user can re-resolve later), `git init` failing shouldn't
///   prevent the files from being written, `open Xcode` failing shouldn't
///   crash the CLI. The warning tells the user; the `Bool` lets the caller
///   skip downstream steps that depend on success (e.g. skip `git config
///   core.hooksPath` when the `git init` returned false).
///
/// - `runCapturingStdout(...)` — returns `String?` of the trimmed first line,
///   or `nil` on any failure. Use for read-only tool probes (`git config
///   user.name`, `which xcodegen`) where you want the value if it's there and
///   are fine with nil otherwise.
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

    /// Run a process and return captured output. Throws `RunError.launchFailed`
    /// on `Process.run()` failure (binary missing, permission denied, etc).
    static func run(
        executable: String,
        arguments: [String],
        cwd: String? = nil,
        captureStdout: Bool = false,
        captureStderr: Bool = false
    ) throws -> Output {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let cwd {
            process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }

        let stdoutPipe = captureStdout ? Pipe() : nil
        let stderrPipe = captureStderr ? Pipe() : nil
        process.standardOutput = stdoutPipe ?? FileHandle.nullDevice
        process.standardError = stderrPipe ?? FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw RunError.launchFailed(error.localizedDescription)
        }
        process.waitUntilExit()

        let stdoutString = stdoutPipe.map(Self.readPipe) ?? ""
        let stderrString = stderrPipe.map(Self.readPipe) ?? ""
        return Output(
            exitCode: process.terminationStatus,
            stdout: stdoutString,
            stderr: stderrString
        )
    }

    /// Run a process and discard output. Returns `true` on success.
    /// Prints `failureLabel` with `error.localizedDescription` on launch
    /// failure, or `(exit N)` on non-zero exit — both routed through
    /// `UISymbols.warn`.
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
                captureStderr: failureLabel != nil
            )
            guard output.exitCode == 0 else {
                if let failureLabel {
                    let detail = output.stderr.isEmpty
                        ? "(exit \(output.exitCode))"
                        : "(exit \(output.exitCode): \(output.stderr.trimmingCharacters(in: .whitespacesAndNewlines)))"
                    print("  \(UISymbols.warn) \(failureLabel) \(detail)")
                }
                return false
            }
            if let successLabel {
                print("  \(UISymbols.check) \(successLabel)")
            }
            return true
        } catch let RunError.launchFailed(message) {
            if let failureLabel {
                print("  \(UISymbols.warn) \(failureLabel): \(message)")
            }
            return false
        } catch {
            if let failureLabel {
                print("  \(UISymbols.warn) \(failureLabel): \(error)")
            }
            return false
        }
    }

    /// Run a process and return the trimmed first line of stdout, or nil on
    /// failure. Used by `ToolChecker` for `which` and version queries.
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
            process.waitUntilExit()
            guard process.terminationStatus == 0 || mergeStderr else { return nil }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }

    private static func readPipe(_ pipe: Pipe) -> String {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
