import ArgumentParser

struct CompletionsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "completions",
        abstract: "Generate shell completion scripts."
    )

    @Argument(help: "Shell type: zsh, bash, or fish (default: zsh)")
    var shell: String = "zsh"

    func run() throws {
        let completionShell: CompletionShell = switch shell.lowercased() {
        case "zsh": .zsh
        case "bash": .bash
        case "fish": .fish
        default:
            throw ValidationError("Unknown shell '\(shell)'. Valid: zsh, bash, fish")
        }

        let script = Monolith.completionScript(for: completionShell)
        print(script)
    }
}
