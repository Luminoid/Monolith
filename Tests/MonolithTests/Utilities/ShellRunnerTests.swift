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
}

struct SignalHandlerTests {
    @Test
    func `removePartialOutput deletes existing directory`() throws {
        let path = NSTemporaryDirectory() + "monolith-test-cleanup-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        try "x".write(toFile: path + "/file.txt", atomically: true, encoding: .utf8)
        #expect(FileManager.default.fileExists(atPath: path))

        SignalHandler.removePartialOutput(at: path)

        #expect(!FileManager.default.fileExists(atPath: path))
    }

    @Test
    func `removePartialOutput is a no-op when directory is absent`() {
        let path = "/tmp/monolith-test-nonexistent-\(UUID().uuidString)"
        // Should not crash, should not print anything alarming.
        SignalHandler.removePartialOutput(at: path)
        #expect(!FileManager.default.fileExists(atPath: path))
    }

    @Test
    func `install is idempotent`() {
        SignalHandler.uninstall()
        defer { SignalHandler.uninstall() }

        SignalHandler.install(cleanup: {})
        SignalHandler.install(cleanup: {}) // second install replaces cleanup, doesn't crash
        // No direct assertion — just confirm no crash. The actual SIGINT
        // delivery path is not exercised here (would terminate the test runner).
    }
}
