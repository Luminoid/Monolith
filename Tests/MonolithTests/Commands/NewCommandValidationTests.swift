import ArgumentParser
import Foundation
import Testing
@testable import MonolithLib

/// Command-level input validation for `monolith new`: bad flags and bad
/// config files fail with a message before anything is written.
///
/// Child of `MonolithIntegrationSuite` so `.serialized` propagates: every test
/// runs inside `withTempDir`, which changes `currentDirectoryPath`.
extension MonolithIntegrationSuite {
    struct NewCommandValidationTests {
        /// Parses and runs `Command` with `arguments`, returning the error
        /// message, or `nil` when the run succeeded.
        private func runMessage<Command: ParsableCommand>(_: Command.Type, _ arguments: [String]) -> String? {
            do {
                var command = try Command.parse(arguments)
                try command.run()
                return nil
            } catch {
                return "\(error)"
            }
        }

        private func directoryIsEmpty(_ path: String) throws -> Bool {
            try FileManager.default.contentsOfDirectory(atPath: path).allSatisfy { $0.hasSuffix(".json") }
        }

        // MARK: - Flags

        /// Regression: `my-app` generated `final class my-appCoreDataStack`.
        @Test
        func `new app rejects a name that isn't a Swift identifier`() throws {
            try withTempDir(prefix: "monolith-test-app-name") { tempDir in
                let message = runMessage(NewAppCommand.self, ["--name", "my-app", "--no-interactive"])
                #expect(message?.contains("Swift identifiers") == true)
                let isEmpty = try directoryIsEmpty(tempDir)
                #expect(isEmpty)
            }
        }

        /// Regression: `--targets A,A` trapped (exit 133), even with `--dry-run`.
        @Test
        func `new package with duplicate targets errors instead of crashing`() throws {
            try withTempDir(prefix: "monolith-test-dup-targets") { tempDir in
                let message = runMessage(NewPackageCommand.self, ["--name", "DupPkg", "--targets", "A,A", "--no-interactive", "--dry-run"])
                #expect(message?.contains("more than once") == true)
                let isEmpty = try directoryIsEmpty(tempDir)
                #expect(isEmpty)
            }
        }

        @Test
        func `bad flag values fail instead of being ignored`() throws {
            try withTempDir(prefix: "monolith-test-bad-flags") { tempDir in
                let app = ["--name", "FlagApp", "--no-interactive", "--dry-run"]
                let cases: [(arguments: [String], expected: String)] = [
                    (app + ["--features", "tabs"], "--tabs"),
                    (app + ["--features", "notAFeature"], "Unknown feature"),
                    (app + ["--platforms", "android"], "Unknown platform"),
                    (app + ["--project-system", "xcodgen"], "Did you mean 'xcodegen'?"),
                    (app + ["--tabs", "Home"], "Invalid --tabs entry"),
                    (app + ["--use-packages", ":"], "Invalid --use-packages entry"),
                    (app + ["--use-packages", "LumiKit"], "--features lumiKit"),
                    (app + ["--features", "swiftData,coreData"], "choose one persistence layer"),
                    (app + ["--target-deps", "Mystery"], "no declared package provides"),
                ]
                for (arguments, expected) in cases {
                    let message = runMessage(NewAppCommand.self, arguments)
                    #expect(message?.contains(expected) == true, "\(arguments): \(message ?? "no error")")
                }

                let package = ["--name", "FlagPkg", "--no-interactive", "--dry-run"]
                let packageCases: [(arguments: [String], expected: String)] = [
                    (package + ["--target-deps", "FlagPkg"], "Invalid --target-deps entry"),
                    (package + ["--target-deps", "Other:SnapKit"], "not in --targets"),
                    (package + ["--platforms", "Android 1.0"], "Unknown package platform"),
                    (package + ["--features", "devTooling,typo"], "Unknown feature"),
                ]
                for (arguments, expected) in packageCases {
                    let message = runMessage(NewPackageCommand.self, arguments)
                    #expect(message?.contains(expected) == true, "\(arguments): \(message ?? "no error")")
                }
                let isEmpty = try directoryIsEmpty(tempDir)
                #expect(isEmpty)
            }
        }

        // MARK: - CLI ArgumentParser default

        @Test
        func `new cli includes ArgumentParser by default and drops it on request`() throws {
            try withTempDir(prefix: "monolith-test-cli-ap") { tempDir in
                // A dry run saves no config, so these generate for real.
                let base = ["--name", "aptool", "--no-interactive", "--save-config"]
                #expect(runMessage(NewCLICommand.self, base + ["\(tempDir)/on.json", "--output", "\(tempDir)/on"]) == nil)
                #expect(runMessage(NewCLICommand.self, base + ["\(tempDir)/off.json", "--output", "\(tempDir)/off", "--no-argument-parser", "--preset", "full"]) == nil)
                let on = try ConfigFile.load(from: "\(tempDir)/on.json")
                let off = try ConfigFile.load(from: "\(tempDir)/off.json")
                #expect(on.cli?.includeArgumentParser == true)
                #expect(off.cli?.includeArgumentParser == false)

                let conflict = runMessage(NewCLICommand.self, ["--name", "aptool", "--no-interactive", "--dry-run", "--features", "argumentParser", "--no-argument-parser"])
                #expect(conflict?.contains("contradicts") == true)
            }
        }

        // MARK: - --load-config

        private func writeConfig(_ json: String, to path: String) throws {
            try json.write(toFile: path, atomically: true, encoding: .utf8)
        }

        /// Regression: a loaded config skipped the name check, so
        /// `"../escaped tool"` wrote outside the output directory.
        @Test
        func `load-config with a bad name fails before writing`() throws {
            try withTempDir(prefix: "monolith-test-load-name") { tempDir in
                let output = "\(tempDir)/out"
                try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
                let packagePath = "\(tempDir)/package.json"
                try writeConfig("""
                {"projectType": "package", "initGit": false, "package": {"name": "../escaped tool",
                  "platforms": [{"platform": "iOS", "version": "18.0"}], "targets": [{"name": "Escaped", "dependencies": []}],
                  "features": [], "mainActorTargets": [], "author": "Test", "licenseType": "mit"}}
                """, to: packagePath)
                let message = runMessage(NewPackageCommand.self, ["--load-config", packagePath, "--output", output])
                #expect(message?.contains("Invalid package name") == true)
                #expect(!FileManager.default.fileExists(atPath: "\(tempDir)/escaped tool"))
                let afterPackage = try FileManager.default.contentsOfDirectory(atPath: output)
                #expect(afterPackage.isEmpty)

                let cliPath = "\(tempDir)/cli.json"
                try writeConfig("""
                {"projectType": "cli", "initGit": false, "cli": {"name": "", "features": [], "author": "Test"}}
                """, to: cliPath)
                #expect(runMessage(NewCLICommand.self, ["--load-config", cliPath, "--output", output])?.contains("name is empty") == true)
                let afterCLI = try FileManager.default.contentsOfDirectory(atPath: output)
                #expect(afterCLI.isEmpty)
            }
        }

        /// A config that fails validation is the config's problem, not the
        /// command line's: no usage line after the message.
        @Test
        func `a config error is not a usage error`() throws {
            try withTempDir(prefix: "monolith-test-config-error") { _ in
                let error = #expect(throws: (any Error).self) {
                    let command = try NewAppCommand.parse(["--name", "Twins", "--no-interactive", "--dry-run", "--features", "swiftData,cloudKitSharing"])
                    try command.run()
                }
                #expect(!(error is ValidationError))
                #expect(NewAppCommand.message(for: error ?? CancellationError()).contains("CloudKit sharing requires coreData"))
                #expect(!NewAppCommand.fullMessage(for: error ?? CancellationError()).contains("Usage:"))
            }
        }

        /// Regression: `"primaryColor": "red"` silently became black.
        @Test
        func `load-config with a bad primary color fails`() throws {
            try withTempDir(prefix: "monolith-test-load-color") { tempDir in
                let path = "\(tempDir)/app.json"
                try writeConfig("""
                {"projectType": "app", "initGit": false, "app": {"name": "ColorApp", "bundleID": "com.example.colorapp",
                  "deploymentTarget": "18.0", "platforms": ["iPhone"], "projectSystem": "xcodeProj", "tabs": [],
                  "primaryColor": "red", "features": [], "author": "Test", "licenseType": "proprietary"}}
                """, to: path)
                let message = runMessage(NewAppCommand.self, ["--load-config", path])
                #expect(message?.contains("Invalid primary color 'red'") == true)
                #expect(!FileManager.default.fileExists(atPath: "\(tempDir)/ColorApp"))
            }
        }

        @Test
        func `load-config rejects a config for another project type`() throws {
            try withTempDir(prefix: "monolith-test-load-type") { tempDir in
                let path = "\(tempDir)/cli.json"
                try writeConfig("""
                {"projectType": "cli", "initGit": false, "cli": {"name": "tool", "features": [], "author": "Test"}}
                """, to: path)
                let message = runMessage(NewPackageCommand.self, ["--load-config", path])
                #expect(message?.contains("was saved for `monolith new cli`") == true)
            }
        }
    }
}
