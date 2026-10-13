import ArgumentParser
import Foundation
import Testing
@testable import MonolithLib

/// Flag parsing and the wizard of `monolith new cli`. Configs are built with
/// `resolveConfig()`, which writes nothing.
struct NewCLICommandTests {
    private func config(_ arguments: [String]) throws -> CLIConfig {
        try NewCLICommand.parse(arguments).resolveConfig().config
    }

    // MARK: - Flags

    @Test
    func `flags build the config`() throws {
        let plain = try config(["--name", "tool", "--no-interactive"])
        #expect(plain.includeArgumentParser)
        #expect(plain.licenseType == .apache2)
        #expect(plain.features == [.argumentParser])

        let full = try config(["--name", "tool", "--preset", "full", "--license", "mit", "--no-argument-parser", "--no-interactive"])
        #expect(!full.includeArgumentParser)
        #expect(full.licenseType == .mit)
        #expect(full.features == Preset.full.cliFeatures().subtracting([.argumentParser]))
    }

    @Test
    func `contradicting and malformed flags fail`() {
        #expect(throws: (any Error).self) { try config(["--name", "tool", "--features", "argumentParser", "--no-argument-parser", "--no-interactive"]) }
        #expect(throws: (any Error).self) { try config(["--name", "tool", "--features", "colors", "--no-interactive"]) }
        #expect(throws: (any Error).self) { try NewCLICommand.parse(["--license", "bsd"]) }
        #expect(throws: (any Error).self) { try NewCLICommand.parse(["--git", "--no-git"]) }
        #expect(throws: (any Error).self) { try NewCLICommand.parse(["--load-config", "cli.json", "--features", "devTooling"]) }
        #expect(throws: (any Error).self) { try NewCLICommand.parse(["--load-config", "cli.json", "--no-argument-parser"]) }
    }

    /// Non-interactive git is off unless `--git`.
    @Test
    func `non-interactive git is off unless --git`() throws {
        #expect(try !NewCLICommand.parse(["--name", "tool", "--no-interactive"]).resolveConfig().initGit)
        #expect(try NewCLICommand.parse(["--name", "tool", "--no-interactive", "--git"]).resolveConfig().initGit)
    }

    // MARK: - Wizard

    private func wizard(_ arguments: [String] = [], script: PromptScript) throws -> ResolvedConfig<CLIConfig> {
        let command = try NewCLICommand.parse(arguments)
        return try PromptEngine.$script.withValue(script) { try command.resolveConfig() }
    }

    /// Regression: with stdin at end of input, the name prompt asked again forever.
    @Test
    func `the wizard stops when input ends`() {
        let script = PromptScript(lines: [])
        #expect(throws: PromptEngine.InputClosedError.self) { try wizard(script: script) }
        #expect(script.questions.count == 1)
    }

    @Test
    func `the wizard refuses to start without a terminal`() throws {
        let output = NSTemporaryDirectory() + "monolith-test-cli-tty-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: output) }
        let command = try NewCLICommand.parse(["--name", "tool", "--output", output])
        PromptEngine.$terminalOverride.withValue(false) {
            #expect(throws: NewCommandWizard.NotATerminalError.self) { try command.run() }
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: output).isEmpty)
    }

    @Test
    func `the features step starts from the preset`() throws {
        let script = PromptScript(answers: ["CLI name": ["tool"], "Feature preset": ["3"]])
        let resolved = try wizard(script: script)
        #expect(resolved.config.features == Preset.full.cliFeatures())
        #expect(!script.transcript.contains("Strict concurrency"))
    }

    @Test
    func `flags answer the CLI wizard`() throws {
        let script = PromptScript(answers: [:])
        let resolved = try wizard(["--name", "tool", "--features", "devTooling", "--license", "mit", "--no-git", "--no-argument-parser"], script: script)
        #expect(resolved.config.name == "tool")
        #expect(resolved.config.features == [.devTooling])
        #expect(resolved.config.licenseType == .mit)
        #expect(!resolved.initGit)
        #expect(script.questions.contains("Open project in Xcode after generation?"))
        for skipped in ["CLI name", "ArgumentParser", "Feature preset", "Optional features", "License type", "Initialize git"] {
            #expect(!script.questions.contains { $0.contains(skipped) }, "\(skipped) was asked")
        }
        #expect(script.transcript.contains("Features"))
    }
}
