import ArgumentParser

struct CompletionsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "completions",
        abstract: "Generate shell completion scripts."
    )

    /// The shells ArgumentParser writes completion scripts for.
    enum Shell: String, CaseIterable, ExpressibleByArgument {
        case zsh
        case bash
        case fish

        /// Case-insensitive, so `ZSH` works.
        init?(argument: String) {
            self.init(rawValue: argument.lowercased())
        }

        var completionShell: CompletionShell {
            switch self {
            case .zsh: .zsh
            case .bash: .bash
            case .fish: .fish
            }
        }
    }

    @Argument(help: "Shell type")
    var shell: Shell = .zsh

    func run() {
        print(Monolith.completionScript(for: shell.completionShell))
    }
}
