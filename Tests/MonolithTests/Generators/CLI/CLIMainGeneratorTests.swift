import Foundation
import Testing
@testable import MonolithLib

struct CLIMainGeneratorTests {
    @Test
    func `generates with ArgumentParser`() {
        let config = CLIConfig(name: "mytool", includeArgumentParser: true, features: [], author: "Test", licenseType: .apache2)
        let output = CLIMainGenerator.generate(config: config)

        #expect(output.contains("import ArgumentParser"))
        #expect(output.contains("@main"))
        #expect(output.contains("ParsableCommand"))
        #expect(output.contains("Mytool"))
        #expect(output.contains("func run()"))
        #expect(output.contains("verbose"))
    }

    @Test
    func `generates without ArgumentParser`() {
        let config = CLIConfig(name: "mytool", includeArgumentParser: false, features: [], author: "Test", licenseType: .apache2)
        let output = CLIMainGenerator.generate(config: config)

        #expect(!output.contains("import ArgumentParser"))
        #expect(output.contains("@main"))
        #expect(output.contains("Mytool"))
        #expect(output.contains("static func main()"))
        #expect(output.contains("Hello from mytool"))
    }

    @Test
    func `capitalizes first letter of name`() {
        let config = CLIConfig(name: "myApp", includeArgumentParser: false, features: [], author: "Test", licenseType: .apache2)
        let output = CLIMainGenerator.generate(config: config)
        #expect(output.contains("struct MyApp"))
    }
}
