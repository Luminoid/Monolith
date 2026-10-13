import Foundation
import Testing
@testable import MonolithLib

struct CLIMainGeneratorTests {
    private func config(_ name: String, argumentParser: Bool = true) -> CLIConfig {
        CLIConfig(name: name, includeArgumentParser: argumentParser, features: [], author: "Test", licenseType: .apache2)
    }

    // MARK: - Library source

    @Test
    func `ArgumentParser command is a public ParsableCommand in the library`() {
        let output = CLIMainGenerator.generate(config: config("mytool"))

        #expect(output.contains("import ArgumentParser"))
        #expect(output.contains("public struct Mytool: ParsableCommand {"))
        #expect(output.contains("public static let configuration = CommandConfiguration("))
        #expect(output.contains("public init() {}"))
        #expect(output.contains("public func run() throws {"))
        #expect(output.contains("var verbose = false"))
        // The executable's main.swift is the entry point; a library can't hold `@main`.
        #expect(!output.contains("@main"))
    }

    @Test
    func `run refers to its configuration through Self`() {
        // The generated .swiftlint.yml enables prefer_self_in_static_references,
        // so `<Type>.configuration` inside `run()` failed the CLI's own `make check`.
        let output = CLIMainGenerator.generate(config: config("my-tool"))
        #expect(output.contains("\\(Self.configuration.commandName ?? \"my-tool\")"))
        #expect(!output.contains("MyTool.configuration"))
    }

    @Test
    func `commandName is the name exactly as typed`() {
        // Lowercasing made `AuditCLI --help` print `USAGE: auditcli`.
        #expect(CLIMainGenerator.generate(config: config("AuditCLI")).contains("commandName: \"AuditCLI\""))
        #expect(CLIMainGenerator.generate(config: config("my-tool")).contains("commandName: \"my-tool\""))
    }

    @Test
    func `version comes from the shared stub`() {
        let output = CLIMainGenerator.generate(config: config("mytool"))
        #expect(output.contains("version: \"\(ArgumentParserStub.initialVersion)\""))
    }

    @Test
    func `hyphenated name yields a valid type name`() {
        // `my-tool` is the wizard's own example; `struct My-tool` didn't compile.
        let output = CLIMainGenerator.generate(config: config("my-tool"))
        #expect(output.contains("public struct MyTool: ParsableCommand"))
        #expect(!output.contains("My-tool"))
    }

    @Test
    func `plain command is a public enum with run(arguments:)`() {
        let output = CLIMainGenerator.generate(config: config("mytool", argumentParser: false))

        #expect(!output.contains("import ArgumentParser"))
        #expect(!output.contains("@main"))
        #expect(output.contains("public enum Mytool {"))
        #expect(output.contains("public static func run(arguments: [String]) {"))
        #expect(output.contains("static func greeting(for arguments: [String]) -> String"))
        #expect(output.contains("Hello from mytool!"))
    }

    // MARK: - main.swift

    @Test
    func `main imports the library and calls the command`() {
        #expect(CLIMainGenerator.generateMain(config: config("my-tool")) == "import MyToolKit\n\nMyTool.main()\n")
        #expect(CLIMainGenerator.generateMain(config: config("my-tool", argumentParser: false))
            == "import MyToolKit\n\nMyTool.run(arguments: Array(CommandLine.arguments.dropFirst()))\n")
    }

    // MARK: - Tests

    @Test
    func `suite imports the library and holds real tests`() {
        // The suite used to be empty (0 tests), and it imported the executable.
        let output = CLIMainGenerator.generateTests(config: config("my-tool"))
        #expect(output.contains("@testable import MyToolKit"))
        #expect(output.contains("struct MyToolTests {"))
        #expect(output.contains("try MyTool.parse([])"))
        #expect(output.contains("try MyTool.parse([\"--verbose\"])"))
        #expect(output.components(separatedBy: "@Test").count - 1 == 2)
    }

    @Test
    func `plain test suite checks the greeting`() {
        let output = CLIMainGenerator.generateTests(config: config("my-tool", argumentParser: false))
        #expect(output.contains("@testable import MyToolKit"))
        #expect(output.contains("#expect(MyTool.greeting(for: []) == \"Hello from my-tool!\")"))
        #expect(!output.contains("parse("))
    }

    // MARK: - Paths

    @Test
    func `paths split library, executable, and tests`() {
        let cli = config("my-tool")
        #expect(CLIMainGenerator.librarySourcePath(config: cli) == "Sources/MyToolKit/MyTool.swift")
        #expect(CLIMainGenerator.mainPath(config: cli) == "Sources/my-tool/main.swift")
        #expect(CLIMainGenerator.testsPath(config: cli) == "Tests/MyToolKitTests/MyToolTests.swift")
    }

    // MARK: - Next steps

    @Test
    func `next steps set the hooks path directly without a Makefile`() {
        #expect(CLIProjectGenerator.nextSteps(hasDevTooling: false, hasGitHooks: true) == ["git config core.hooksPath Scripts/git-hooks"])
        #expect(CLIProjectGenerator.nextSteps(hasDevTooling: true, hasGitHooks: true) == ["brew bundle", "make setup-hooks"])
        #expect(CLIProjectGenerator.nextSteps(hasDevTooling: false, hasGitHooks: false).isEmpty)
    }
}
