import Foundation
import Testing
@testable import MonolithLib

struct CLIConfigTests {
    @Test
    func `computed properties match feature flags`() {
        let config = CLIConfig(
            name: "mytool",
            includeArgumentParser: true,
            features: [.argumentParser, .devTooling, .gitHooks, .strictConcurrency],
            author: "Test",
            licenseType: .apache2
        )
        #expect(config.hasDevTooling)
        #expect(config.hasGitHooks)
        #expect(config.hasStrictConcurrency)
        #expect(config.includeArgumentParser)
    }

    @Test
    func `default config has no features`() {
        let config = CLIConfig(
            name: "mytool",
            includeArgumentParser: false,
            features: [],
            author: "Test",
            licenseType: .apache2
        )
        #expect(!config.hasDevTooling)
        #expect(!config.hasGitHooks)
        #expect(!config.hasStrictConcurrency)
        #expect(!config.includeArgumentParser)
    }
}
