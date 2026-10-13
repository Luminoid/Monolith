import Foundation
import Testing
@testable import MonolithLib

struct GitRunnerTests {
    // MARK: - authorName

    @Test
    func `authorName returns the configured author or nil`() {
        // No assertion on exact content — CI machines may or may not have
        // user.name set. Just confirm it doesn't crash and returns a String? .
        let name = GitRunner.authorName()
        if let name {
            #expect(!name.isEmpty)
            #expect(!name.contains("\n"))
        }
    }

    // MARK: - initRepository

    @Test
    func `initRepository returns true on a fresh directory`() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        // Need at least one file for `git commit` to succeed.
        try FileWriter.writeFile(at: "README.md", content: "x", basePath: tempDir)

        let result = GitRunner.initRepository(at: tempDir, hasGitHooks: false)
        #expect(result)
        #expect(FileManager.default.fileExists(atPath: (tempDir as NSString).appendingPathComponent(".git")))
    }

    @Test
    func `initRepository with hasGitHooks configures core.hooksPath`() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        try FileWriter.writeFile(at: "README.md", content: "x", basePath: tempDir)
        try FileWriter.writeFile(at: "Scripts/git-hooks/pre-commit", content: "#!/bin/sh\n", basePath: tempDir, executable: true)

        let result = GitRunner.initRepository(at: tempDir, hasGitHooks: true)
        #expect(result)

        // Verify core.hooksPath was set.
        let configPath = (tempDir as NSString).appendingPathComponent(".git/config")
        let config = try String(contentsOfFile: configPath, encoding: .utf8)
        #expect(config.contains("hooksPath = Scripts/git-hooks"))
    }

    /// A failed step stops the chain; the steps after it never run. An empty
    /// directory makes `git commit` fail (nothing to commit), so the hooks
    /// path step after it must not have run.
    @Test
    func `initRepository stops at a failed commit and leaves later steps unrun`() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let result = GitRunner.initRepository(at: tempDir, hasGitHooks: true)
        #expect(!result)
        let config = try String(contentsOfFile: (tempDir as NSString).appendingPathComponent(".git/config"), encoding: .utf8)
        #expect(!config.contains("hooksPath"))
    }

    /// The labels are what the failure warning tells the user to run by hand.
    @Test
    func `initRepository steps are labeled with the commands they run`() {
        let steps = GitRunner.initSteps(hasGitHooks: true)
        #expect(steps.map(\.label) == [
            "git init",
            "git add .",
            "git commit -m \"Initial commit\"",
            "git config core.hooksPath Scripts/git-hooks",
        ])
        #expect(steps.last?.args == ["config", "core.hooksPath", "Scripts/git-hooks"])
        #expect(GitRunner.initSteps(hasGitHooks: false).count == 3)
    }

    @Test
    func `initRepository returns false on a nonexistent directory`() {
        let fake = "/tmp/monolith-test-nonexistent-\(UUID().uuidString)"
        let result = GitRunner.initRepository(at: fake, hasGitHooks: false)
        #expect(!result)
    }

    @Test
    func `authorNameOrPlaceholder is never empty`() {
        let author = GitRunner.authorNameOrPlaceholder()
        #expect(author == GitRunner.authorName() ?? GitRunner.placeholderAuthor)
        #expect(!author.isEmpty)
    }

    // MARK: - Helpers

    private func makeTempDir() throws -> String {
        let path = NSTemporaryDirectory() + "monolith-test-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }
}
