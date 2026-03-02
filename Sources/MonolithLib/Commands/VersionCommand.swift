import ArgumentParser

struct VersionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Print the Monolith version."
    )

    func run() {
        print("monolith 0.1.0")
    }
}
