import ArgumentParser

public struct Monolith: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "monolith",
        abstract: "Project scaffold CLI for iOS apps, Swift Packages, and Swift CLIs.",
        version: "0.1.0",
        subcommands: [
            NewCommand.self, ListCommand.self, AddCommand.self,
            DoctorCommand.self, CompletionsCommand.self, VersionCommand.self,
        ]
    )

    public init() {}
}
