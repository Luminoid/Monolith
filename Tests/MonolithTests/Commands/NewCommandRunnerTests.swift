import Foundation
import Testing
@testable import MonolithLib

private struct RunnerGenerationFailed: Error {}

/// The post-config pipeline's failure handling: what is left on disk, and that
/// failures propagate (so the CLI exits non-zero) instead of returning.
///
/// Nested under `MonolithIntegrationSuite` so `.serialized` keeps these apart
/// from `SignalHandlerTests`: both touch the process-wide SIGINT handler.
extension MonolithIntegrationSuite {
    struct NewCommandRunnerTests {
        private func makeOutputDir() throws -> String {
            let dir = NSTemporaryDirectory() + "monolith-runner-\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            return dir
        }

        /// No cleanup of the SIGINT handler here: disarming it is the runner's job, and the tests check that.
        private func run(outputDir: String, force: Bool = false, generate: () throws -> Void) throws {
            try NewCommandRunner.run(
                projectName: "Partial",
                outputDir: outputDir,
                force: force,
                noInteractive: true,
                dryRun: false,
                shouldInitGit: false,
                shouldResolve: false,
                shouldOpen: false,
                hasGitHooks: false,
                projectSystem: .spm,
                printDryRun: {},
                generate: generate
            )
        }

        @Test
        func `a failed generation removes the output it created`() throws {
            let outputDir = try makeOutputDir()
            defer { try? FileManager.default.removeItem(atPath: outputDir) }
            let project = "\(outputDir)/Partial"

            #expect(throws: RunnerGenerationFailed.self) {
                try run(outputDir: outputDir) {
                    try FileWriter.writeFile(at: "Package.swift", content: "// partial\n", basePath: project)
                    throw RunnerGenerationFailed()
                }
            }
            #expect(!FileManager.default.fileExists(atPath: project))
        }

        @Test
        func `a failed generation never removes a directory that existed before the run`() throws {
            let outputDir = try makeOutputDir()
            defer { try? FileManager.default.removeItem(atPath: outputDir) }
            let project = "\(outputDir)/Partial"
            try FileManager.default.createDirectory(atPath: project, withIntermediateDirectories: true)
            try "keep\n".write(toFile: "\(project)/notes.txt", atomically: true, encoding: .utf8)

            #expect(throws: RunnerGenerationFailed.self) {
                try run(outputDir: outputDir, force: true) {
                    try FileWriter.writeFile(at: "Package.swift", content: "// partial\n", basePath: project)
                    throw RunnerGenerationFailed()
                }
            }
            #expect(FileManager.default.fileExists(atPath: "\(project)/notes.txt"))
        }

        /// Every file was written; only a post-step failed, so the output stays for the user to finish.
        @Test
        func `an incomplete generation keeps its output and still fails`() throws {
            let outputDir = try makeOutputDir()
            defer { try? FileManager.default.removeItem(atPath: outputDir) }
            let project = "\(outputDir)/Partial"

            #expect(throws: IncompleteGenerationError.self) {
                try run(outputDir: outputDir) {
                    try FileWriter.writeFile(at: "project.yml", content: "name: Partial\n", basePath: project)
                    throw IncompleteGenerationError(description: "xcodegen failed")
                }
            }
            #expect(FileManager.default.fileExists(atPath: "\(project)/project.yml"))
        }

        /// The Ctrl-C cleanup covers the writes only. Left armed, an interrupt
        /// during git init or a slow package resolve deleted the finished project.
        @Test
        func `the Ctrl-C cleanup is disarmed once generation finishes`() throws {
            let outputDir = try makeOutputDir()
            defer { try? FileManager.default.removeItem(atPath: outputDir) }

            var armedDuringGeneration = false
            try run(outputDir: outputDir) {
                armedDuringGeneration = SignalHandler.isArmed
                try FileWriter.writeFile(at: "Package.swift", content: "// done\n", basePath: "\(outputDir)/Partial")
            }
            #expect(armedDuringGeneration)
            #expect(!SignalHandler.isArmed)
            #expect(FileManager.default.fileExists(atPath: "\(outputDir)/Partial/Package.swift"))
        }

        @Test
        func `the Ctrl-C cleanup is disarmed after a failed generation too`() throws {
            let outputDir = try makeOutputDir()
            defer { try? FileManager.default.removeItem(atPath: outputDir) }

            #expect(throws: RunnerGenerationFailed.self) {
                try run(outputDir: outputDir) { throw RunnerGenerationFailed() }
            }
            #expect(!SignalHandler.isArmed)
        }

        @Test
        func `a non-interactive run into a non-empty directory throws before generating`() throws {
            let outputDir = try makeOutputDir()
            defer { try? FileManager.default.removeItem(atPath: outputDir) }
            let project = "\(outputDir)/Partial"
            try FileManager.default.createDirectory(atPath: project, withIntermediateDirectories: true)
            try "keep\n".write(toFile: "\(project)/notes.txt", atomically: true, encoding: .utf8)

            var generated = false
            #expect(throws: OverwriteProtection.RefusedError.self) {
                try run(outputDir: outputDir) { generated = true }
            }
            #expect(!generated)
            #expect(FileManager.default.fileExists(atPath: "\(project)/notes.txt"))
        }
    }
}
