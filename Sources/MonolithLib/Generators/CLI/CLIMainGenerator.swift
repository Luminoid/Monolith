/// Source files for a generated CLI.
///
/// A CLI is a library plus a thin executable: `Sources/<libraryName>/<TypeName>.swift`
/// holds the command, and `Sources/<name>/main.swift` only calls it. Tests import the
/// library (`@testable import` can't reach into an executable module), and the
/// executable keeps the name exactly as typed, so `my-tool` builds a `my-tool`
/// binary whose command type is `MyTool`.
enum CLIMainGenerator {
    // MARK: - Paths

    /// The command's source file, in the library target.
    static func librarySourcePath(config: CLIConfig) -> String {
        "Sources/\(config.libraryName)/\(config.typeName).swift"
    }

    /// The executable's entry point.
    static func mainPath(config: CLIConfig) -> String {
        "Sources/\(config.name)/main.swift"
    }

    /// The test suite, in the library's test target.
    static func testsPath(config: CLIConfig) -> String {
        "Tests/\(config.libraryName)Tests/\(config.typeName)Tests.swift"
    }

    // MARK: - Library

    /// The library source that declares the command.
    static func generate(config: CLIConfig) -> String {
        if config.includeArgumentParser {
            generateWithArgumentParser(config: config)
        } else {
            generatePlain(config: config)
        }
    }

    private static func generateWithArgumentParser(config: CLIConfig) -> String {
        let configuration = ArgumentParserStub.configuration(
            access: "public ",
            commandName: config.name,
            abstract: "A Swift CLI tool."
        )
        // `Self.configuration`, not `<TypeName>.configuration`: the generated
        // `.swiftlint.yml` enables `prefer_self_in_static_references`.
        return """
        import ArgumentParser

        /// The `\(config.name)` command. The `\(config.name)` executable's `main.swift` calls `\(config.typeName).main()`.
        public struct \(config.typeName): ParsableCommand {
        \(configuration)

            @Flag(name: .shortAndLong, help: "Enable verbose output.")
            var verbose = false

            public init() {}

            public func run() throws {
                if verbose {
                    print("Running \\(Self.configuration.commandName ?? "\(config.name)") in verbose mode...")
                }
                print("Hello from \(config.name)!")
            }
        }

        """
    }

    private static func generatePlain(config: CLIConfig) -> String {
        """
        /// The `\(config.name)` command. The `\(config.name)` executable's `main.swift` calls `run(arguments:)`.
        public enum \(config.typeName) {
            /// Runs the command with the process arguments, minus the executable path.
            public static func run(arguments: [String]) {
                print(greeting(for: arguments))
            }

            /// The line `run(arguments:)` prints.
            static func greeting(for arguments: [String]) -> String {
                arguments.isEmpty ? "Hello from \(config.name)!" : "Hello from \(config.name)! Arguments: \\(arguments.joined(separator: " "))"
            }
        }

        """
    }

    // MARK: - Executable

    /// The executable's `main.swift`: import the library, run the command.
    static func generateMain(config: CLIConfig) -> String {
        let call = config.includeArgumentParser
            ? "\(config.typeName).main()"
            : "\(config.typeName).run(arguments: Array(CommandLine.arguments.dropFirst()))"
        return """
        import \(config.libraryName)

        \(call)

        """
    }

    // MARK: - Tests

    /// A Swift Testing suite with real smoke tests, so `swift test` exercises
    /// the command from the first run.
    static func generateTests(config: CLIConfig) -> String {
        let body = if config.includeArgumentParser {
            """
                @Test
                func `parses with no arguments`() throws {
                    let command = try \(config.typeName).parse([])
                    #expect(!command.verbose)
                }

                @Test
                func `verbose flag parses`() throws {
                    let command = try \(config.typeName).parse(["--verbose"])
                    #expect(command.verbose)
                }
            """
        } else {
            """
                @Test
                func `greets with no arguments`() {
                    #expect(\(config.typeName).greeting(for: []) == "Hello from \(config.name)!")
                }

                @Test
                func `echoes its arguments`() {
                    #expect(\(config.typeName).greeting(for: ["a", "b"]) == "Hello from \(config.name)! Arguments: a b")
                }
            """
        }
        return """
        import Testing
        @testable import \(config.libraryName)

        struct \(config.typeName)Tests {
        \(body)
        }

        """
    }
}
