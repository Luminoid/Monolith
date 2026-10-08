/// The `CommandConfiguration` block every generated ArgumentParser command
/// declares: the `new cli` command (`CLIMainGenerator`) and the executable
/// sibling of a `new package` (`PackageSourceGenerator.generateExecutable`).
/// One renderer keeps the two from drifting, the starting version above all.
enum ArgumentParserStub {
    /// The version a freshly generated command reports for `--version`.
    static let initialVersion = "0.1.0"

    /// A `static let configuration = CommandConfiguration(...)` declaration,
    /// indented one level (it sits inside the command type).
    ///
    /// - Parameters:
    ///   - access: An access modifier with its trailing space (`"public "`),
    ///     or empty for internal.
    ///   - commandName: The name `--help` prints after `USAGE:`; the binary's
    ///     name, so it matches what users type.
    ///   - subcommands: Type names listed in `subcommands:`.
    ///   - defaultSubcommand: The type that runs when no subcommand is given.
    static func configuration(
        access: String = "",
        commandName: String,
        abstract: String,
        includeVersion: Bool = true,
        subcommands: [String] = [],
        defaultSubcommand: String? = nil
    ) -> String {
        var arguments = [
            "commandName: \"\(commandName)\"",
            "abstract: \"\(abstract)\"",
        ]
        if includeVersion {
            arguments.append("version: \"\(initialVersion)\"")
        }
        if !subcommands.isEmpty {
            arguments.append("subcommands: [\(subcommands.map { "\($0).self" }.joined(separator: ", "))]")
        }
        if let defaultSubcommand {
            arguments.append("defaultSubcommand: \(defaultSubcommand).self")
        }
        var lines = ["    \(access)static let configuration = CommandConfiguration("]
        lines.append(arguments.map { "        \($0)" }.joined(separator: ",\n"))
        lines.append("    )")
        return lines.joined(separator: "\n")
    }
}
