enum PackageSourceGenerator {
    /// Generate a placeholder source file for a target.
    static func generateSource(targetName: String) -> String {
        """
        /// \(targetName) module placeholder. Add real public types here.
        public enum \(targetName) {}

        """
    }

    /// Generate the ArgumentParser stub for an executable sibling target (declared
    /// via `--targets name:exec`). One subcommand to make the pattern obvious;
    /// adopters extend by adding more types to `subcommands:`.
    static func generateExecutable(targetName: String) -> String {
        let typeName = targetName.upperCamelCased
        return """
        import ArgumentParser

        @main
        struct \(typeName): ParsableCommand {
            static let configuration = CommandConfiguration(
                commandName: "\(targetName)",
                abstract: "\(targetName) command-line tool.",
                version: "0.1.0",
                subcommands: [Run.self]
            )
        }

        struct Run: ParsableCommand {
            static let configuration = CommandConfiguration(
                commandName: "run",
                abstract: "Default subcommand. Replace with real commands."
            )

            func run() throws {
                print("Hello from \(targetName)!")
            }
        }

        """
    }
}
