import Foundation
import Testing
@testable import MonolithLib

/// Nested under `MonolithIntegrationSuite` so `.serialized` keeps these
/// apart from the suites that change `currentDirectoryPath` (`withTempDir`):
/// `resolveOutputPath` reads it.
extension MonolithIntegrationSuite {
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

        @Test
        func `writeFile rejects relative paths containing ..`() throws {
            let tempDir = try makeTempDir()
            defer { try? FileManager.default.removeItem(atPath: tempDir) }

            // Single-segment escape attempt.
            #expect(throws: FileWriterError.self) {
                try FileWriter.writeFile(at: "../escape.txt", content: "x", basePath: tempDir)
            }
            // Mid-path escape attempt that would still resolve outside basePath.
            #expect(throws: FileWriterError.self) {
                try FileWriter.writeFile(at: "Sources/../../escape.txt", content: "x", basePath: tempDir)
            }
        }

        @Test
        func `writeFile rejects absolute paths in the relative arg`() throws {
            let tempDir = try makeTempDir()
            defer { try? FileManager.default.removeItem(atPath: tempDir) }

            #expect(throws: FileWriterError.self) {
                try FileWriter.writeFile(at: "/etc/passwd", content: "x", basePath: tempDir)
            }
        }

        @Test
        func `writeFile accepts normal relative paths`() throws {
            let tempDir = try makeTempDir()
            defer { try? FileManager.default.removeItem(atPath: tempDir) }

            try FileWriter.writeFile(at: "Sources/Foo.swift", content: "x", basePath: tempDir)
            let written = (tempDir as NSString).appendingPathComponent("Sources/Foo.swift")
            #expect(FileManager.default.fileExists(atPath: written))
        }

        // MARK: - writeToolingFiles

        @Test
        func `tooling files share generated-path excludes and thread app options`() throws {
            let tempDir = try makeTempDir()
            defer { try? FileManager.default.removeItem(atPath: tempDir) }

            try FileWriter.writeToolingFiles(
                projectType: .app,
                appName: "MyApp",
                hasRSwift: true,
                hasFastlane: true,
                projectSystem: .xcodeGen,
                basePath: tempDir,
                hasMacCatalyst: true,
                hasWidget: true
            )

            let read = { (name: String) in try String(contentsOfFile: (tempDir as NSString).appendingPathComponent(name), encoding: .utf8) }
            #expect(try read(".swiftformat").contains("--exclude .build,Build,build,MyApp/Generated,fastlane\n"))
            let lint = try read(".swiftlint.yml")
            #expect(lint.contains("excluded:\n  - .build\n  - MyApp/Generated\n  - fastlane\n"))
            #expect(lint.contains("included:\n  - MyApp\n  - MyAppTests\n  - MyAppWidget\n"))
            #expect(try read("Makefile").contains("build-catalyst:"))
        }

        // MARK: - writeOptionalFiles

        /// A public project's CHANGELOG links `[Unreleased]` to its GitHub
        /// commits; a proprietary one has no public repository to link.
        @Test
        func `the CHANGELOG links Unreleased for a named open-source project`() throws {
            let tempDir = try makeTempDir()
            defer { try? FileManager.default.removeItem(atPath: tempDir) }

            try FileWriter.writeOptionalFiles(claudeMDContent: nil, licenseAuthor: "Jane Doe", licenseType: .mit, projectName: "Tool", basePath: tempDir)
            let changelog = try String(contentsOfFile: "\(tempDir)/CHANGELOG.md", encoding: .utf8)
            #expect(changelog.contains("[Unreleased]: https://github.com/"))
            #expect(changelog.contains("/Tool/commits/main"))

            try FileWriter.writeOptionalFiles(claudeMDContent: nil, licenseAuthor: "Jane Doe", licenseType: .proprietary, projectName: "Tool", basePath: tempDir)
            let proprietary = try String(contentsOfFile: "\(tempDir)/CHANGELOG.md", encoding: .utf8)
            #expect(!proprietary.contains("[Unreleased]:"))
        }

        // MARK: - Interrupts

        /// A Ctrl-C during `new` stops generation at the next write.
        @Test
        func `writeFile throws after an interrupt while writes are guarded`() throws {
            let tempDir = try makeTempDir()
            defer {
                SignalHandler.uninstall()
                try? FileManager.default.removeItem(atPath: tempDir)
            }
            SignalHandler.install()
            guard SignalHandler.isArmed else { return } // SIGINT ignored in this environment
            SignalHandler.handler(SIGINT) // what a delivered SIGINT runs
            #expect(SignalHandler.wasInterrupted)

            SignalHandler.$guardsWrites.withValue(true) {
                #expect(throws: SignalHandler.InterruptedError.self) {
                    try FileWriter.writeFile(at: "late.txt", content: "x", basePath: tempDir)
                }
            }
            // Outside `new`'s generation (e.g. `add`), writes don't check.
            try FileWriter.writeFile(at: "unguarded.txt", content: "x", basePath: tempDir)
            #expect(!FileManager.default.fileExists(atPath: "\(tempDir)/late.txt"))
            #expect(FileManager.default.fileExists(atPath: "\(tempDir)/unguarded.txt"))
        }

        // MARK: - Helpers

        private func makeTempDir() throws -> String {
            let path = NSTemporaryDirectory() + "monolith-test-\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            return path
        }
    }
}
