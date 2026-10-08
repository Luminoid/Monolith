import Foundation
import Testing
@testable import MonolithLib

struct CLIConfigTests {
    @Test
    func `computed properties match feature flags`() {
        let config = CLIConfig(
            name: "mytool",
            features: [.argumentParser, .devTooling, .gitHooks, .strictConcurrency],
            author: "Test",
            licenseType: .apache2
        )
        #expect(config.hasDevTooling)
        #expect(config.hasGitHooks)
        #expect(config.includeArgumentParser)
    }

    @Test
    func `default config has no features`() {
        let config = CLIConfig(
            name: "mytool",
            features: [],
            author: "Test",
            licenseType: .apache2
        )
        #expect(!config.hasDevTooling)
        #expect(!config.hasGitHooks)
        #expect(!config.includeArgumentParser)
    }

    /// The ArgumentParser choice lives in `features` alone; the convenience
    /// init only adds or removes it there.
    @Test
    func `includeArgumentParser is derived from features`() {
        let on = CLIConfig(name: "mytool", includeArgumentParser: true, features: [.devTooling], author: "Test", licenseType: .apache2)
        #expect(on.features == [.argumentParser, .devTooling])
        #expect(on.includeArgumentParser)

        let off = CLIConfig(name: "mytool", includeArgumentParser: false, features: [.argumentParser], author: "Test", licenseType: .apache2)
        #expect(off.features.isEmpty)
        #expect(!off.includeArgumentParser)
    }

    @Test
    func `legacy includeArgumentParser key still turns ArgumentParser on`() throws {
        let legacyJSON = """
        {"name": "mytool", "includeArgumentParser": true, "features": ["devTooling"], "author": "Test", "licenseType": "apache2"}
        """
        let decoded = try JSONDecoder().decode(CLIConfig.self, from: Data(legacyJSON.utf8))
        #expect(decoded.features == [.argumentParser, .devTooling])
    }

    @Test
    func `CLI names may be kebab-cased but not Unicode or reserved`() throws {
        try CLIConfig(name: "my-tool", features: [], author: "Test", licenseType: .apache2).validateForGeneration()
        for bad in ["", "my tool", "tööl", "../tool", "class"] {
            #expect(throws: ConfigValidationError.self, "\(bad)") {
                try CLIConfig(name: bad, features: [], author: "Test", licenseType: .apache2).validateForGeneration()
            }
        }
    }

    @Test
    func `parseList rejects an unknown CLI feature`() {
        let error = #expect(throws: ConfigValidationError.self) {
            try CLIFeature.parseList("argumentParser,gitHook")
        }
        #expect(error?.description.contains("Did you mean 'gitHooks'?") == true)
    }
}
