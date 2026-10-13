import ArgumentParser
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
        private func run(
            config: CLIConfig = CLIConfig(name: "Partial", features: [], author: "Test", licenseType: .apache2),
            saveConfigPath: String? = nil,
            outputDir: String,
            force: Bool = false,
            dryRun: Bool = false,
            generate: () throws -> Void
        ) throws {
            try NewCommandRunner.run(
                config: config,
                saveConfigPath: saveConfigPath,
                outputDir: outputDir,
                force: force,
                interactive: false,
                dryRun: dryRun,
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

        // MARK: - Validation

        /// Every config, including one loaded with `--load-config`, is
        /// validated before anything is saved, previewed, or written.
        @Test
        func `an invalid config fails before save, dry run, or generation`() throws {
            let outputDir = try makeOutputDir()
            defer { try? FileManager.default.removeItem(atPath: outputDir) }
            let savePath = "\(outputDir)/saved.json"
            let invalid = CLIConfig(name: "../escaped tool", features: [], author: "Test", licenseType: .apache2)

            var generated = false
            for dryRun in [true, false] {
                let error = #expect(throws: (any Error).self) {
                    try run(config: invalid, saveConfigPath: savePath, outputDir: outputDir, dryRun: dryRun) { generated = true }
                }
                #expect("\(String(describing: error))".contains("Invalid CLI name"))
            }
            #expect(!generated)
            #expect(!FileManager.default.fileExists(atPath: savePath))
            #expect(!FileManager.default.fileExists(atPath: "\(outputDir)/../escaped tool"))
        }

        /// A dry run writes nothing, the `--save-config` file included.
        @Test
        func `a dry run does not save the config`() throws {
            let outputDir = try makeOutputDir()
            defer { try? FileManager.default.removeItem(atPath: outputDir) }
            let savePath = "\(outputDir)/saved.json"

            try run(saveConfigPath: savePath, outputDir: outputDir, dryRun: true, generate: { Issue.record("dry run generated") })
            #expect(!FileManager.default.fileExists(atPath: savePath))
        }

        @Test
        func `a valid config is saved before generation`() throws {
            let outputDir = try makeOutputDir()
            defer { try? FileManager.default.removeItem(atPath: outputDir) }
            let savePath = "\(outputDir)/saved.json"

            var savedFirst = false
            try run(saveConfigPath: savePath, outputDir: outputDir) {
                savedFirst = FileManager.default.fileExists(atPath: savePath)
            }
            #expect(savedFirst)
            let loaded = try ConfigFile.load(from: savePath, expecting: .cli)
            #expect(loaded.cli?.name == "Partial")
        }

        // MARK: - Ctrl-C

        /// The handler only records the SIGINT; the next write stops
        /// generation, and the runner removes the partial output and exits 130.
        @Test
        func `a Ctrl-C during generation removes the partial output and exits 130`() throws {
            let outputDir = try makeOutputDir()
            defer {
                SignalHandler.uninstall()
                try? FileManager.default.removeItem(atPath: outputDir)
            }
            let project = "\(outputDir)/Partial"

            var wroteAfterInterrupt = false
            let error = #expect(throws: ExitCode.self) {
                try run(outputDir: outputDir) {
                    try FileWriter.writeFile(at: "Package.swift", content: "// first\n", basePath: project)
                    // What a delivered SIGINT runs; with SIGINT ignored there is no handler.
                    guard SignalHandler.isArmed else { throw SignalHandler.InterruptedError() }
                    SignalHandler.handler(SIGINT)
                    try FileWriter.writeFile(at: "README.md", content: "late\n", basePath: project)
                    wroteAfterInterrupt = true
                }
            }
            #expect(error?.rawValue == 130)
            #expect(!wroteAfterInterrupt)
            #expect(!FileManager.default.fileExists(atPath: project))
            #expect(!SignalHandler.isArmed)
            #expect(!SignalHandler.wasInterrupted)
        }

        // MARK: - Next steps

        /// The hooks step shows only when git init didn't already set
        /// `core.hooksPath`; `make setup-hooks` needs the dev-tooling Makefile.
        @Test
        func `next steps follow what git init configured`() {
            let summary = NewCommandRunner.Summary(headline: "Done!", steps: ["Build it"])
            let steps = { (devTooling: Bool, hooks: Bool, configured: Bool) in
                NewCommandRunner.nextSteps(summary, hasDevTooling: devTooling, hasGitHooks: hooks, hooksConfigured: configured)
            }
            #expect(steps(true, true, false) == ["brew bundle", "make setup-hooks", "Build it"])
            #expect(steps(false, true, false) == ["git config core.hooksPath Scripts/git-hooks", "Build it"])
            #expect(steps(true, true, true) == ["brew bundle", "Build it"])
            #expect(steps(false, false, false) == ["Build it"])
        }

        @Test
        func `the strictConcurrency warning names the tools version`() {
            #expect(NewCommandRunner.strictConcurrencyWarning.contains("swift-tools-version \(ToolVersion.swift)"))
            #expect(!NewCommandRunner.strictConcurrencyWarning.contains("\u{2014}"))
        }

        // MARK: - Declined overwrite

        /// Regression: declining the overwrite prompt exited 0 without a word.
        @Test
        func `a declined overwrite exits 1`() throws {
            #expect(throws: ExitCode.self) { try NewCommandRunner.stopIfDeclined(.abort) }
            try NewCommandRunner.stopIfDeclined(.proceed)
        }
    }
}
