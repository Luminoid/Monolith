import Foundation
import Testing
@testable import MonolithLib

@Suite("OverwriteProtection")
struct OverwriteProtectionTests {
    @Test("empty directory returns proceed")
    func emptyDirectoryProceeds() throws {
        let dir = NSTemporaryDirectory() + "monolith-overwrite-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: dir) }

        #expect(!OverwriteProtection.directoryExistsAndNonEmpty(at: dir))
    }

    @Test("non-empty directory detected correctly")
    func nonEmptyDirectoryDetected() throws {
        let dir = NSTemporaryDirectory() + "monolith-overwrite-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try "test".write(toFile: "\(dir)/file.txt", atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: dir) }

        #expect(OverwriteProtection.directoryExistsAndNonEmpty(at: dir))
    }

    @Test("nonexistent directory returns false")
    func nonexistentDirectory() {
        #expect(!OverwriteProtection.directoryExistsAndNonEmpty(at: "/tmp/nonexistent-\(UUID().uuidString)"))
    }

    @Test("force flag returns proceed for non-empty directory")
    func forceFlagProceeds() throws {
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

    @Test("non-interactive without force returns abort for non-empty directory")
    func nonInteractiveAborts() throws {
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

    @Test("clean directory returns proceed without force")
    func cleanDirectoryProceeds() {
        let result = OverwriteProtection.check(
            projectName: "FreshProject-\(UUID().uuidString)",
            outputDir: NSTemporaryDirectory(),
            force: false,
            interactive: false
        )
        #expect(result == .proceed)
    }
}
