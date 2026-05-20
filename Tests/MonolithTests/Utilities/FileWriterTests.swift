import Foundation
import Testing
@testable import MonolithLib

struct FileWriterTests {
    // MARK: - writeFile

    @Test
    func `writeFile creates a file with the given content`() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        try FileWriter.writeFile(
            at: "out.txt",
            content: "hello",
            basePath: tempDir
        )

        let fullPath = (tempDir as NSString).appendingPathComponent("out.txt")
        let read = try String(contentsOfFile: fullPath, encoding: .utf8)
        #expect(read == "hello")
    }

    @Test
    func `writeFile creates intermediate directories`() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        try FileWriter.writeFile(
            at: "a/b/c/deep.txt",
            content: "deep",
            basePath: tempDir
        )

        let fullPath = (tempDir as NSString).appendingPathComponent("a/b/c/deep.txt")
        #expect(FileManager.default.fileExists(atPath: fullPath))
        #expect(try String(contentsOfFile: fullPath, encoding: .utf8) == "deep")
    }

    @Test
    func `writeFile overwrites an existing file`() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        try FileWriter.writeFile(at: "f.txt", content: "v1", basePath: tempDir)
        try FileWriter.writeFile(at: "f.txt", content: "v2", basePath: tempDir)

        let fullPath = (tempDir as NSString).appendingPathComponent("f.txt")
        #expect(try String(contentsOfFile: fullPath, encoding: .utf8) == "v2")
    }

    @Test
    func `writeFile with executable=true sets 0o755`() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        try FileWriter.writeFile(
            at: "script.sh",
            content: "#!/bin/sh\necho hi\n",
            basePath: tempDir,
            executable: true
        )

        let fullPath = (tempDir as NSString).appendingPathComponent("script.sh")
        let attrs = try FileManager.default.attributesOfItem(atPath: fullPath)
        let perms = (attrs[.posixPermissions] as? NSNumber)?.intValue ?? 0
        #expect(perms == 0o755)
    }

    @Test
    func `writeFile without executable flag does not set executable bit`() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        try FileWriter.writeFile(at: "data.txt", content: "x", basePath: tempDir)

        let fullPath = (tempDir as NSString).appendingPathComponent("data.txt")
        let attrs = try FileManager.default.attributesOfItem(atPath: fullPath)
        let perms = (attrs[.posixPermissions] as? NSNumber)?.intValue ?? 0
        // Default umask varies by environment; just confirm execute bit is OFF.
        #expect((perms & 0o111) == 0)
    }

    // MARK: - resolveOutputPath

    @Test
    func `resolveOutputPath joins outputDir with project name`() {
        let path = FileWriter.resolveOutputPath(projectName: "MyApp", outputDir: "/tmp")
        #expect(path == "/tmp/MyApp")
    }

    @Test
    func `resolveOutputPath uses currentDirectoryPath when outputDir is nil`() {
        let cwd = FileManager.default.currentDirectoryPath
        let path = FileWriter.resolveOutputPath(projectName: "X", outputDir: nil)
        #expect(path == "\(cwd)/X")
    }

    // MARK: - gitAuthorName

    @Test
    func `gitAuthorName returns the configured author or nil`() {
        // No assertion on exact content — CI machines may or may not have
        // user.name set. Just confirm it doesn't crash and returns a String? .
        let name = FileWriter.gitAuthorName()
        if let name {
            #expect(!name.isEmpty)
            #expect(!name.contains("\n"))
        }
    }

    // MARK: - gitInit

    @Test
    func `gitInit returns true on a fresh directory`() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        // Need at least one file for `git commit` to succeed.
        try FileWriter.writeFile(at: "README.md", content: "x", basePath: tempDir)

        let result = FileWriter.gitInit(at: tempDir, hasGitHooks: false)
        #expect(result)
        #expect(FileManager.default.fileExists(atPath: (tempDir as NSString).appendingPathComponent(".git")))
    }

    @Test
    func `gitInit with hasGitHooks configures core.hooksPath`() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        try FileWriter.writeFile(at: "README.md", content: "x", basePath: tempDir)
        try FileWriter.writeFile(at: "Scripts/git-hooks/pre-commit", content: "#!/bin/sh\n", basePath: tempDir, executable: true)

        let result = FileWriter.gitInit(at: tempDir, hasGitHooks: true)
        #expect(result)

        // Verify core.hooksPath was set.
        let configPath = (tempDir as NSString).appendingPathComponent(".git/config")
        let config = try String(contentsOfFile: configPath, encoding: .utf8)
        #expect(config.contains("hooksPath = Scripts/git-hooks"))
    }

    @Test
    func `gitInit returns false on a nonexistent directory`() {
        let fake = "/tmp/monolith-test-nonexistent-\(UUID().uuidString)"
        let result = FileWriter.gitInit(at: fake, hasGitHooks: false)
        #expect(!result)
    }

    // MARK: - Helpers

    private func makeTempDir() throws -> String {
        let path = NSTemporaryDirectory() + "monolith-test-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }
}
