import Foundation
import Testing
@testable import MonolithLib

struct OverwriteProtectionTests {
    @Test
    func `empty directory returns proceed`() throws {
        let dir = NSTemporaryDirectory() + "monolith-overwrite-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: dir) }

        #expect(OverwriteProtection.directoryState(at: dir) == .absentOrEmpty)
    }

    @Test
    func `non-empty directory detected correctly`() throws {
        let dir = NSTemporaryDirectory() + "monolith-overwrite-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try "test".write(toFile: "\(dir)/file.txt", atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: dir) }

        #expect(OverwriteProtection.directoryState(at: dir) == .nonEmpty)
    }

    @Test
    func `nonexistent directory reads as absent`() {
        #expect(OverwriteProtection.directoryState(at: "/tmp/nonexistent-\(UUID().uuidString)") == .absentOrEmpty)
    }

    @Test
    func `force flag returns proceed for non-empty directory`() throws {
        let dir = NSTemporaryDirectory() + "monolith-overwrite-\(UUID().uuidString)"
        let projectDir = "\(dir)/TestProject"
        try FileManager.default.createDirectory(atPath: projectDir, withIntermediateDirectories: true)
        try "test".write(toFile: "\(projectDir)/file.txt", atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let result = try OverwriteProtection.check(
            projectName: "TestProject",
            outputDir: dir,
            force: true,
            interactive: false
        )
        #expect(result == .proceed)
    }

    /// End of input at the overwrite prompt fails instead of reading as an answer.
    @Test
    func `stdin closing at the overwrite prompt throws`() throws {
        let dir = NSTemporaryDirectory() + "monolith-overwrite-\(UUID().uuidString)"
        let projectDir = "\(dir)/TestProject"
        try FileManager.default.createDirectory(atPath: projectDir, withIntermediateDirectories: true)
        try "test".write(toFile: "\(projectDir)/file.txt", atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: dir) }

        PromptEngine.$script.withValue(PromptScript(lines: [])) {
            #expect(throws: PromptEngine.InputClosedError.self) {
                try OverwriteProtection.check(projectName: "TestProject", outputDir: dir, force: false, interactive: true)
            }
        }
        let declined = try PromptEngine.$script.withValue(PromptScript(lines: ["maybe", "n"])) {
            try OverwriteProtection.check(projectName: "TestProject", outputDir: dir, force: false, interactive: true)
        }
        #expect(declined == .abort)
    }

    /// The refusal must throw, not return: a returned `.abort` let the CLI
    /// exit 0 after failing, so scripts read the refusal as success.
    @Test
    func `non-interactive without force throws for non-empty directory`() throws {
        let dir = NSTemporaryDirectory() + "monolith-overwrite-\(UUID().uuidString)"
        let projectDir = "\(dir)/TestProject"
        try FileManager.default.createDirectory(atPath: projectDir, withIntermediateDirectories: true)
        try "test".write(toFile: "\(projectDir)/file.txt", atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let error = #expect(throws: OverwriteProtection.RefusedError.self) {
            try OverwriteProtection.check(
                projectName: "TestProject",
                outputDir: dir,
                force: false,
                interactive: false
            )
        }
        #expect(error?.description.contains("--force") == true)
        #expect(error?.description.contains(projectDir) == true)
    }

    @Test
    func `clean directory returns proceed without force`() throws {
        let result = try OverwriteProtection.check(
            projectName: "FreshProject-\(UUID().uuidString)",
            outputDir: NSTemporaryDirectory(),
            force: false,
            interactive: false
        )
        #expect(result == .proceed)
    }

    /// A directory that can't be listed must not read as empty, or a
    /// non-interactive run would write into it without `--force`.
    @Test
    func `unreadable directory counts as non-empty`() throws {
        let dir = NSTemporaryDirectory() + "monolith-overwrite-\(UUID().uuidString)"
        let projectDir = "\(dir)/Locked"
        try FileManager.default.createDirectory(atPath: projectDir, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: projectDir)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: projectDir)
            try? FileManager.default.removeItem(atPath: dir)
        }
        // Root ignores permission bits; nothing to check there.
        guard getuid() != 0 else { return }

        guard case .unreadable = OverwriteProtection.directoryState(at: projectDir) else {
            Issue.record("expected .unreadable, got \(OverwriteProtection.directoryState(at: projectDir))")
            return
        }
        #expect(throws: OverwriteProtection.RefusedError.self) {
            try OverwriteProtection.check(projectName: "Locked", outputDir: dir, force: false, interactive: false)
        }
    }
}
