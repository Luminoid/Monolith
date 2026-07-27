import ArgumentParser
import Foundation
import Testing
@testable import MonolithLib

/// Command-level tests for `monolith new app`. These drive the real
/// `ParsableCommand` (parse + run) rather than calling a generator directly,
/// because the behavior under test lives in flag parsing and config loading,
/// not in any generator.
///
/// Child of `MonolithIntegrationSuite` so `.serialized` propagates: every test
/// here runs inside `withTempDir`, which mutates `currentDirectoryPath`. The
/// temp dir also means a regression that fails to reject writes its project
/// into a throwaway directory instead of into the repo.
extension MonolithIntegrationSuite {
    struct NewAppCommandTests {
        // MARK: - --project-system spm is rejected, not silently substituted

        @Test
        func `new app rejects --project-system spm`() throws {
            try withTempDir(prefix: "monolith-test-spm-flag") { tempDir in
                var command = try NewAppCommand.parse([
                    "--name", "SpmRejected",
                    "--bundle-id", "com.example.spmrejected",
                    "--no-interactive",
                    "--project-system", "spm",
                ])

                var message = ""
                #expect(throws: (any Error).self) {
                    do {
                        try command.run()
                    } catch {
                        message = "\(error)"
                        throw error
                    }
                }

                #expect(message.contains("not supported for apps"))
                #expect(message.contains("code signing"))
                // Nothing was generated: the throw happens during config build.
                #expect(!FileManager.default.fileExists(atPath: "\(tempDir)/SpmRejected"))
            }
        }

        @Test
        func `new app still accepts xcodeproj and xcodegen`() throws {
            for system in ["xcodeproj", "xcodegen", "xcode"] {
                let command = try NewAppCommand.parse([
                    "--name", "Accepted",
                    "--bundle-id", "com.example.accepted",
                    "--no-interactive",
                    "--project-system", system,
                ])
                #expect(command.projectSystem == system)
            }
        }

        // MARK: - --load-config can't smuggle spm past the flag check

        @Test
        func `new app rejects a config file that sets projectSystem spm`() throws {
            try withTempDir(prefix: "monolith-test-spm-config") { tempDir in
                let configPath = "\(tempDir)/spm-app.json"
                let spmAppConfig = AppConfig(
                    name: "SmuggledSpm",
                    bundleID: "com.example.smuggledspm",
                    deploymentTarget: Defaults.deploymentTarget,
                    platforms: [.iPhone],
                    projectSystem: .spm,
                    tabs: [],
                    primaryColor: Defaults.primaryColor,
                    features: [],
                    author: "Test",
                    licenseType: .proprietary
                )
                try ConfigFile.save(
                    ConfigFile.MonolithConfig(projectType: .app, app: spmAppConfig, package: nil, cli: nil, initGit: false),
                    to: configPath
                )

                var command = try NewAppCommand.parse(["--load-config", configPath])

                var message = ""
                #expect(throws: (any Error).self) {
                    do {
                        try command.run()
                    } catch {
                        message = "\(error)"
                        throw error
                    }
                }

                #expect(message.contains("projectSystem 'spm'"))
                #expect(message.contains("not supported for apps"))
                #expect(!FileManager.default.fileExists(atPath: "\(tempDir)/SmuggledSpm"))
            }
        }
    }
}
