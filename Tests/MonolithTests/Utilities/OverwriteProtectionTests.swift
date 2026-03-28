import Foundation
import Testing
@testable import MonolithLib

struct OverwriteProtectionTests {
    @Test
    func `empty directory returns proceed`() throws {
        let dir = NSTemporaryDirectory() + "monolith-overwrite-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: dir) }

        #expect(!OverwriteProtection.directoryExistsAndNonEmpty(at: dir))
    }

    @Test
    func `non-empty directory detected correctly`() throws {
        let dir = NSTemporaryDirectory() + "monolith-overwrite-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try "test".write(toFile: "\(dir)/file.txt", atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: dir) }

        #expect(OverwriteProtection.directoryExistsAndNonEmpty(at: dir))
    }

    @Test
    func `nonexistent directory returns false`() {
        #expect(!OverwriteProtection.directoryExistsAndNonEmpty(at: "/tmp/nonexistent-\(UUID().uuidString)"))
    }

    @Test
    func `force flag returns proceed for non-empty directory`() throws {
        let dir = NSTemporaryDirectory() + "monolith-overwrite-\(UUID().uuidString)"
        let projectDir = "\(dir)/TestProject"
        try FileManager.default.createDirectory(atPath: projectDir, withIntermediateDirectories: true)
        try "test".write(toFile: "\(projectDir)/file.txt", atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let result = OverwriteProtection.check(
            projectName: "TestProject",
            outputDir: dir,
            force: true,
            interactive: false
        )
        #expect(result == .proceed)
    }

    @Test
    func `non-interactive without force returns abort for non-empty directory`() throws {
        let dir = NSTemporaryDirectory() + "monolith-overwrite-\(UUID().uuidString)"
        let projectDir = "\(dir)/TestProject"
        try FileManager.default.createDirectory(atPath: projectDir, withIntermediateDirectories: true)
        try "test".write(toFile: "\(projectDir)/file.txt", atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let result = OverwriteProtection.check(
            projectName: "TestProject",
            outputDir: dir,
            force: false,
            interactive: false
        )
        #expect(result == .abort)
    }

    @Test
    func `clean directory returns proceed without force`() {
        let result = OverwriteProtection.check(
            projectName: "FreshProject-\(UUID().uuidString)",
            outputDir: NSTemporaryDirectory(),
            force: false,
            interactive: false
        )
        #expect(result == .proceed)
    }
}
