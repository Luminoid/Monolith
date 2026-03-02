enum CLIMainGenerator {

    static func generate(config: CLIConfig) -> String {
        if config.includeArgumentParser {
            generateWithArgumentParser(config: config)
        } else {
            generatePlain(config: config)
        }
    }

    private static func generateWithArgumentParser(config: CLIConfig) -> String {
        """
        import ArgumentParser

        @main
        struct \(config.name.capitalizingFirst): ParsableCommand {
            static let configuration = CommandConfiguration(
                commandName: "\(config.name.lowercased())",
                abstract: "A Swift CLI tool.",
                version: "0.1.0"
            )

            @Flag(name: .shortAndLong, help: "Enable verbose output.")
            var verbose = false

            func run() throws {
                if verbose {
                    print("Running \\(\(config.name.capitalizingFirst).configuration.commandName ?? "\(config.name)") in verbose mode...")
                }
                print("Hello from \(config.name)!")
            }
        }

        """
    }

    private static func generatePlain(config: CLIConfig) -> String {
        """
        @main
        struct \(config.name.capitalizingFirst) {
            static func main() {
                print("Hello from \(config.name)!")
            }
        }

        """
    }
}
