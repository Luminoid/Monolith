import ArgumentParser
import Testing
@testable import MonolithLib

struct CompletionsCommandTests {
    @Test
    func `zsh completion script contains monolith`() {
        let script = Monolith.completionScript(for: .zsh)
        #expect(script.contains("monolith"))
    }

    @Test
    func `bash completion script contains monolith`() {
        let script = Monolith.completionScript(for: .bash)
        #expect(script.contains("monolith"))
    }

    @Test
    func `fish completion script contains monolith`() {
        let script = Monolith.completionScript(for: .fish)
        #expect(script.contains("monolith"))
    }

    @Test
    func `completion scripts contain subcommands`() {
        let script = Monolith.completionScript(for: .zsh)
        #expect(script.contains("new"))
        #expect(script.contains("version"))
    }

    @Test
    func `the shell is case-insensitive and defaults to zsh`() throws {
        #expect(try CompletionsCommand.parse([]).shell == .zsh)
        #expect(try CompletionsCommand.parse(["BASH"]).shell == .bash)
        #expect(throws: (any Error).self) { try CompletionsCommand.parse(["tcsh"]) }
    }

    /// The help used to say "(default: zsh)" twice: once in the text, once from ArgumentParser.
    @Test
    func `help names the default shell once`() {
        let help = CompletionsCommand.helpMessage()
        #expect(help.components(separatedBy: "default: zsh").count - 1 == 1)
        #expect(help.contains("fish"))
    }

    /// `--preset`, `--license`, `--features`, and `add`'s feature complete
    /// from their values.
    @Test
    func `completions list option values`() {
        let script = Monolith.completionScript(for: .zsh)
        for value in ["minimal", "apache2", "swiftData", "defaultIsolation", "widget"] {
            #expect(script.contains(value), "\(value)")
        }
    }
}
