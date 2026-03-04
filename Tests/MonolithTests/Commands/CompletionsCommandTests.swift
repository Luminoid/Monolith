import ArgumentParser
import Testing
@testable import MonolithLib

@Suite("CompletionsCommand")
struct CompletionsCommandTests {
    @Test("zsh completion script contains monolith")
    func zshCompletion() {
        let script = Monolith.completionScript(for: .zsh)
        #expect(script.contains("monolith"))
    }

    @Test("bash completion script contains monolith")
    func bashCompletion() {
        let script = Monolith.completionScript(for: .bash)
        #expect(script.contains("monolith"))
    }

    @Test("fish completion script contains monolith")
    func fishCompletion() {
        let script = Monolith.completionScript(for: .fish)
        #expect(script.contains("monolith"))
    }

    @Test("completion scripts contain subcommands")
    func completionContainsSubcommands() {
        let script = Monolith.completionScript(for: .zsh)
        #expect(script.contains("new"))
        #expect(script.contains("version"))
    }
}
