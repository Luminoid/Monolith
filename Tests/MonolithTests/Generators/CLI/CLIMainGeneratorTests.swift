import Foundation
import Testing
@testable import MonolithLib

@Suite("CLIMainGenerator")
struct CLIMainGeneratorTests {

    @Test("generates with ArgumentParser")
    func withArgumentParser() {
        let config = CLIConfig(name: "mytool", includeArgumentParser: true, features: [], author: "Test")
        let output = CLIMainGenerator.generate(config: config)

        #expect(output.contains("import ArgumentParser"))
        #expect(output.contains("@main"))
        #expect(output.contains("ParsableCommand"))
        #expect(output.contains("Mytool"))
        #expect(output.contains("func run()"))
        #expect(output.contains("verbose"))
    }

    @Test("generates without ArgumentParser")
    func withoutArgumentParser() {
        let config = CLIConfig(name: "mytool", includeArgumentParser: false, features: [], author: "Test")
        let output = CLIMainGenerator.generate(config: config)

        #expect(!output.contains("import ArgumentParser"))
        #expect(output.contains("@main"))
        #expect(output.contains("Mytool"))
        #expect(output.contains("static func main()"))
        #expect(output.contains("Hello from mytool"))
    }

    @Test("capitalizes first letter of name")
    func capitalizesName() {
        let config = CLIConfig(name: "myApp", includeArgumentParser: false, features: [], author: "Test")
        let output = CLIMainGenerator.generate(config: config)
        #expect(output.contains("struct MyApp"))
    }
}
