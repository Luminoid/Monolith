import Foundation
import Testing
@testable import MonolithLib

struct ShellRunnerTests {
    // MARK: - run

    @Test
    func `run captures stdout when requested`() throws {
        let output = try ShellRunner.run(
            executable: "/bin/echo",
            arguments: ["hello world"],
            captureStdout: true
        )
        #expect(output.exitCode == 0)
        #expect(output.stdout.contains("hello world"))
    }

    @Test
    func `run captures stderr separately when requested`() throws {
        let output = try ShellRunner.run(
            executable: "/bin/sh",
            arguments: ["-c", "echo OUT; echo ERR >&2; exit 0"],
            captureStdout: true,
            captureStderr: true
        )
        #expect(output.exitCode == 0)
        #expect(output.stdout.contains("OUT"))
        #expect(output.stderr.contains("ERR"))
        #expect(!output.stdout.contains("ERR"))
    }

    @Test
    func `run surfaces non-zero exit code`() throws {
        let output = try ShellRunner.run(
            executable: "/bin/sh",
            arguments: ["-c", "exit 7"]
        )
        #expect(output.exitCode == 7)
    }

    @Test
    func `run throws launchFailed for a nonexistent binary`() {
        #expect(throws: ShellRunner.RunError.self) {
            try ShellRunner.run(
                executable: "/tmp/monolith-test-not-a-binary-\(UUID().uuidString)",
                arguments: []
            )
        }
    }

    @Test
    func `run respects cwd`() throws {
        let tempDir = NSTemporaryDirectory()
        let output = try ShellRunner.run(
            executable: "/bin/pwd",
            arguments: [],
            cwd: tempDir,
            captureStdout: true
        )
        // macOS resolves /tmp -> /private/tmp; tolerate both.
        #expect(output.stdout.contains(tempDir.trimmingCharacters(in: CharacterSet(charactersIn: "/"))))
    }

    // MARK: - runDiscardingOutput

    @Test
    func `runDiscardingOutput returns true on exit 0`() {
        let ok = ShellRunner.runDiscardingOutput(
            executable: "/usr/bin/true",
            arguments: []
        )
        #expect(ok)
    }

    @Test
    func `runDiscardingOutput returns false on non-zero exit`() {
        let ok = ShellRunner.runDiscardingOutput(
            executable: "/usr/bin/false",
            arguments: []
        )
        #expect(!ok)
    }

    @Test
    func `runDiscardingOutput returns false when binary is missing`() {
        let ok = ShellRunner.runDiscardingOutput(
            executable: "/tmp/monolith-test-not-a-binary-\(UUID().uuidString)",
            arguments: []
        )
        #expect(!ok)
    }

    // MARK: - runCapturingStdout

    @Test
    func `runCapturingStdout returns trimmed stdout`() {
        let result = ShellRunner.runCapturingStdout(
            executable: "/bin/echo",
            arguments: ["  hello  "]
        )
        #expect(result == "hello")
    }

    @Test
    func `runCapturingStdout returns nil when binary fails`() {
        let result = ShellRunner.runCapturingStdout(
            executable: "/usr/bin/false",
            arguments: []
        )
        #expect(result == nil)
    }

    @Test
    func `runCapturingStdout returns nil when stdout is empty`() {
        let result = ShellRunner.runCapturingStdout(
            executable: "/usr/bin/true",
            arguments: []
        )
        #expect(result == nil)
    }

    @Test
    func `runCapturingStdout with mergeStderr captures stderr too`() {
        let result = ShellRunner.runCapturingStdout(
            executable: "/bin/sh",
            arguments: ["-c", "echo ERR >&2"],
            mergeStderr: true
        )
        #expect(result?.contains("ERR") == true)
    }

    // MARK: - Pipes

    /// A pipe buffer holds 64 KB. Reading the pipes only after exit, or one
    /// after the other, leaves a child that fills both blocked forever.
    @Test
    func `run drains more than a pipe buffer on both streams`() throws {
        let output = try ShellRunner.run(
            executable: "/bin/sh",
            arguments: ["-c", "head -c 200000 /dev/zero | tr '\\0' o; head -c 200000 /dev/zero | tr '\\0' e >&2"],
            captureStdout: true,
            captureStderr: true,
            streamOutput: false
        )
        #expect(output.exitCode == 0)
        #expect(output.stdout.count == 200_000)
        #expect(output.stderr.count == 200_000)
    }

    @Test
    func `runCapturingStdout drains more than a pipe buffer`() {
        let result = ShellRunner.runCapturingStdout(
            executable: "/bin/sh",
            arguments: ["-c", "head -c 200000 /dev/zero | tr '\\0' o"]
        )
        #expect(result?.count == 200_000)
    }

    @Test
    func `streaming still captures the output`() throws {
        let output = try ShellRunner.run(
            executable: "/bin/sh",
            arguments: ["-c", "echo streamed-out; echo streamed-err >&2"],
            captureStdout: true,
            captureStderr: true,
            streamOutput: true
        )
        #expect(output.stdout.contains("streamed-out"))
        #expect(output.stderr.contains("streamed-err"))
    }

    // MARK: - Failure detail

    @Test
    func `failure detail quotes stderr`() {
        let detail = ShellRunner.failureDetail(for: .init(exitCode: 2, stdout: "noise", stderr: "bad thing\n"))
        #expect(detail == "(exit 2: bad thing)")
    }

    /// Tools such as `git commit` with nothing to commit explain themselves on stdout.
    @Test
    func `failure detail falls back to stdout when stderr is empty`() {
        let detail = ShellRunner.failureDetail(for: .init(exitCode: 1, stdout: "nothing to commit\n", stderr: ""))
        #expect(detail == "(exit 1: nothing to commit)")
    }

    @Test
    func `failure detail without output is the exit code`() {
        #expect(ShellRunner.failureDetail(for: .init(exitCode: 5, stdout: "", stderr: " \n")) == "(exit 5)")
    }

    /// Ctrl-C reaches child processes too; the warning says a signal ended
    /// the child instead of reporting the signal number as an exit code.
    @Test
    func `failure detail names a signal that ended the process`() throws {
        let output = try ShellRunner.run(executable: "/bin/sh", arguments: ["-c", "kill -TERM $$"])
        #expect(output.terminatedBySignal)
        #expect(output.exitCode == SIGTERM)
        #expect(ShellRunner.failureDetail(for: output) == "(signal \(SIGTERM))")
        let withText = ShellRunner.Output(exitCode: SIGINT, stdout: "", stderr: "stopped\n", terminatedBySignal: true)
        #expect(ShellRunner.failureDetail(for: withText) == "(signal \(SIGINT): stopped)")
    }

    /// A stray invalid byte used to empty the whole output, diagnostics included.
    @Test
    func `output with invalid UTF-8 keeps its readable text`() throws {
        let output = try ShellRunner.run(
            executable: "/bin/sh",
            arguments: ["-c", "printf 'bad \\377 byte\\n' >&2; printf 'out \\377\\n'"],
            captureStdout: true,
            captureStderr: true
        )
        #expect(output.stderr.contains("bad"))
        #expect(output.stderr.contains("byte"))
        #expect(output.stdout.contains("out"))
        #expect(ShellRunner.runCapturingStdout(executable: "/bin/sh", arguments: ["-c", "printf 'probe \\377'"])?.contains("probe") == true)
    }

    @Test
    func `failure detail indents multi-line output and keeps the tail`() {
        let lines = (1 ... 30).map { "line \($0)" }.joined(separator: "\n")
        let detail = ShellRunner.failureDetail(for: .init(exitCode: 1, stdout: "", stderr: lines))
        #expect(detail.hasPrefix("(exit 1):\n      ... (10 earlier lines)\n      line 11"))
        #expect(detail.hasSuffix("      line 30"))
        #expect(!detail.contains("line 10\n"))
    }
}
