import Foundation
import Testing
@testable import MonolithLib

@Suite("CLIConfig")
struct CLIConfigTests {
    @Test("computed properties match feature flags")
    func computedProperties() {
        let config = CLIConfig(
            name: "mytool",
            includeArgumentParser: true,
            features: [.argumentParser, .devTooling, .gitHooks, .strictConcurrency],
            author: "Test",
        )
        #expect(config.hasDevTooling)
        #expect(config.hasGitHooks)
        #expect(config.hasStrictConcurrency)
        #expect(config.includeArgumentParser)
    }

    @Test("default config has no features")
    func defaultNoFeatures() {
        let config = CLIConfig(
            name: "mytool",
            includeArgumentParser: false,
            features: [],
            author: "Test",
        )
        #expect(!config.hasDevTooling)
        #expect(!config.hasGitHooks)
        #expect(!config.hasStrictConcurrency)
        #expect(!config.includeArgumentParser)
    }
}
