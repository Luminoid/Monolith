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
}
