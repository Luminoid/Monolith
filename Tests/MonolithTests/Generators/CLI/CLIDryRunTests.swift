import Foundation
import Testing
@testable import MonolithLib

/// Guards `DryRunPlanner.plannedCLIFiles` (the `new cli --dry-run` preview)
/// against drift from `CLIProjectGenerator.generate`: each test generates a
/// CLI and asserts the plan equals the files written, in order.
///
/// Nested under `MonolithIntegrationSuite` so `.serialized` propagates
/// downward and `withTempDir` (which chdirs) cannot race sibling suites.
extension MonolithIntegrationSuite {
    struct CLIDryRunTests {
        /// All regular files under `basePath`, as paths relative to it.
        private func realFiles(under basePath: String) -> Set<String> {
            let baseURL = URL(fileURLWithPath: basePath)
            guard let enumerator = FileManager.default.enumerator(
                at: baseURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: []
            ) else { return [] }

            let prefix = baseURL.standardizedFileURL.path + "/"
            var result: Set<String> = []
            for case let url as URL in enumerator {
                let isRegular = (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile ?? false
                let full = url.standardizedFileURL.path
                guard isRegular, full.hasPrefix(prefix) else { continue }
                result.insert(String(full.dropFirst(prefix.count)))
            }
            return result
        }

        @Test(arguments: [
            CLIConfig(
                name: "my-tool",
                includeArgumentParser: true,
                features: [.argumentParser, .devTooling, .gitHooks, .claudeMD, .licenseChangelog],
                author: "Test",
                licenseType: .apache2
            ),
            CLIConfig(name: "ToolX", includeArgumentParser: false, features: [], author: "Test", licenseType: .apache2),
            CLIConfig(name: "hooks_only", includeArgumentParser: false, features: [.gitHooks], author: "Test", licenseType: .mit),
        ])
        func `dry-run plan matches real generation`(config: CLIConfig) throws {
            try withTempDir(prefix: "monolith-dryrun-cli") { tempDir in
                try CLIProjectGenerator.generate(config: config)

                let planned = DryRunPlanner.plannedCLIFiles(config: config)
                let real = realFiles(under: "\(tempDir)/\(config.name)")

                #expect(planned.count == Set(planned).count, "dry-run lists a file twice: \(planned)")
                #expect(real.subtracting(planned).sorted() == [], "dry-run omits real files")
                #expect(Set(planned).subtracting(real).sorted() == [], "dry-run lists files that aren't generated")
            }
        }

        @Test
        func `dry-run plan names the library, executable, and test files`() {
            let config = CLIConfig(name: "my-tool", includeArgumentParser: true, features: [], author: "Test", licenseType: .apache2)
            let planned = DryRunPlanner.plannedCLIFiles(config: config)
            #expect(Array(planned.prefix(4)) == [
                "Package.swift",
                "Sources/MyToolKit/MyTool.swift",
                "Sources/my-tool/main.swift",
                "Tests/MyToolKitTests/MyToolTests.swift",
            ])
        }
    }
}
