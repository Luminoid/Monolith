import ArgumentParser

struct NewCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "new",
        abstract: "Create a new project.",
        subcommands: [NewAppCommand.self, NewCLICommand.self, NewPackageCommand.self]
    )
}
