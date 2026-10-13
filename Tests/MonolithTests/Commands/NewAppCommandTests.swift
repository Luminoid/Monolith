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
                // Rejected while parsing (the command's `validate()`), so the
                // error carries `new app`'s own usage line.
                var message = ""
                #expect(throws: (any Error).self) {
                    do {
                        _ = try NewAppCommand.parse([
                            "--name", "SpmRejected",
                            "--bundle-id", "com.example.spmrejected",
                            "--no-interactive",
                            "--project-system", "spm",
                        ])
                    } catch {
                        message = NewAppCommand.message(for: error)
                        throw error
                    }
                }

                #expect(message.contains("not supported for apps"))
                #expect(message.contains("code signing"))
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
                #expect(command.common.name == "Accepted")
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

                let command = try NewAppCommand.parse(["--load-config", configPath])

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

        // MARK: - Flags

        /// `--git` and `--no-git` used to both be accepted, and non-interactive
        /// git was off anyway, so `--no-git` did nothing.
        @Test
        func `--git and --no-git are exclusive`() throws {
            #expect(throws: (any Error).self) {
                try NewAppCommand.parse(["--name", "GitApp", "--no-interactive", "--git", "--no-git"])
            }
            #expect(try NewAppCommand.parse(["--name", "GitApp", "--no-interactive"]).common.git == nil)
            #expect(try NewAppCommand.parse(["--name", "GitApp", "--no-interactive", "--no-git"]).common.git == false)
            #expect(try NewAppCommand.parse(["--name", "GitApp", "--no-interactive", "--git"]).common.git == true)
        }

        /// The config file used to win silently over flags like `--name`.
        @Test
        func `--load-config refuses options that set the config`() {
            for extra in [["--name", "Other"], ["--features", "lumiKit"], ["--no-git"], ["--preset", "full"], ["--locales", "en"]] {
                let error = #expect(throws: (any Error).self) {
                    try NewAppCommand.parse(["--load-config", "app.json"] + extra)
                }
                #expect("\(String(describing: error))".contains("--load-config sets the whole config"), "\(extra)")
            }
            for operational in [["--output", "/tmp"], ["--force"], ["--dry-run"], ["--open"], ["--resolve"], ["--verbose"], ["--save-config", "x.json"]] {
                #expect(throws: Never.self) { try NewAppCommand.parse(["--load-config", "app.json"] + operational) }
            }
        }

        @Test
        func `preset and license values are checked by the parser`() {
            #expect(throws: (any Error).self) { try NewAppCommand.parse(["--preset", "huge"]) }
            #expect(throws: (any Error).self) { try NewAppCommand.parse(["--license", "gpl"]) }
            #expect(throws: Never.self) { try NewAppCommand.parse(["--preset", "full", "--license", "apache2"]) }
        }

        @Test
        func `the features help lists exactly what --features accepts`() {
            let help = NewAppCommand.helpMessage()
            #expect(!help.contains("coreDataAuditHook, claudeMD"))
            for feature in AppFeature.flagValues {
                #expect(help.contains(feature.rawValue), "\(feature)")
            }
            #expect(throws: Never.self) { try AppFeature.parseList(AppFeature.flagValues.map(\.rawValue).joined(separator: ",")) }
        }

        @Test
        func `--locales parses like add localization`() throws {
            let config = try NewAppCommand.parse(["--name", "LocApp", "--no-interactive", "--locales", " en , zh-Hans"]).resolveConfig().config
            #expect(config.locales == ["en", "zh-Hans"])
            for bad in ["", "en,EN", "english!"] {
                #expect(throws: (any Error).self) {
                    try NewAppCommand.parse(["--name", "LocApp", "--no-interactive", "--locales", bad]).resolveConfig()
                }
            }
        }

        @Test
        func `the default platforms are iPhone and iPad`() throws {
            let config = try NewAppCommand.parse(["--name", "PlatApp", "--no-interactive"]).resolveConfig().config
            #expect(config.platforms == [.iPhone, .iPad])
        }

        // MARK: - Wizard

        /// Answers the app wizard: `answers` by question, Enter for the rest.
        private func wizard(
            _ arguments: [String] = [],
            answers: KeyValuePairs<String, [String]>
        ) throws -> (config: ResolvedConfig<AppConfig>, script: PromptScript) {
            let command = try NewAppCommand.parse(arguments)
            let script = PromptScript(answers: answers)
            let resolved = try PromptEngine.$script.withValue(script) { try command.resolveConfig() }
            return (resolved, script)
        }

        /// Regression: "Full" + Enter on the features page gave "Features: None".
        @Test
        func `the features step starts from the preset`() throws {
            let (resolved, _) = try wizard(answers: ["App name": ["FullApp"], "Feature preset": ["3"]])
            #expect(resolved.config.features == Preset.full.appFeatures())
            #expect(resolved.config.platforms == [.iPhone, .iPad])
            #expect(resolved.interactive)

            let (standard, _) = try wizard(answers: ["App name": ["StdApp"]])
            #expect(standard.config.features == Preset.standard.appFeatures())
        }

        /// The wizard used to accept both persistence layers and fail after the summary.
        @Test
        func `the wizard asks again for two persistence layers`() throws {
            let (resolved, script) = try wizard(answers: [
                "App name": ["DataApp"], "Feature preset": ["1"], "Optional features": ["1,2", "2"],
            ])
            #expect(resolved.config.features == [.coreData])
            #expect(script.transcript.contains("choose one persistence layer"))
        }

        /// Flags answer their steps: the wizard skips them and the summary shows them.
        @Test
        func `flags answer their wizard steps`() throws {
            let (resolved, script) = try wizard(
                [
                    "--name", "FlagApp", "--platforms", "iPhone", "--project-system", "xcodegen", "--preset", "minimal",
                    "--license", "mit", "--no-git", "--tabs", "Home:house", "--locales", "en,es", "--category", "public.app-category.games",
                ],
                answers: [:]
            )
            let config = resolved.config
            #expect(config.name == "FlagApp")
            #expect(config.platforms == [.iPhone])
            #expect(config.projectSystem == .xcodeGen)
            #expect(config.features.isEmpty)
            #expect(config.licenseType == .mit)
            #expect(config.tabs.map(\.name) == ["Home"])
            #expect(config.locales == ["en", "es"])
            #expect(config.applicationCategory == "public.app-category.games")
            #expect(!resolved.initGit)
            for skipped in ["App name", "Target platforms", "Project system", "Feature preset", "Add tab bar", "Initialize git"] {
                #expect(!script.questions.contains { $0.hasPrefix(skipped) }, "\(skipped) was asked")
            }
            #expect(script.questions.contains { $0.hasPrefix("Optional features") })
            for shown in ["FlagApp", "Minimal (no features)", "Home:house", "en, es", "public.app-category.games"] {
                #expect(script.transcript.contains(shown), "\(shown) missing from the summary")
            }
        }

        @Test
        func `the wizard checks flag values before it starts`() {
            // A bad flag value fails while parsing, before `run()` could start
            // the wizard.
            let script = PromptScript(lines: [])
            PromptEngine.$script.withValue(script) {
                #expect(throws: (any Error).self) { try NewAppCommand.parse(["--name", "my-app"]) }
            }
            #expect(script.questions.isEmpty)
        }

        @Test
        func `the wizard needs a terminal`() throws {
            try withTempDir(prefix: "monolith-test-app-tty") { tempDir in
                let command = try NewAppCommand.parse(["--name", "TTYApp"])
                PromptEngine.$terminalOverride.withValue(false) {
                    let error = #expect(throws: NewCommandWizard.NotATerminalError.self) { try command.run() }
                    #expect(error?.description == "stdin is not a terminal; pass --no-interactive or --load-config")
                }
                #expect(!FileManager.default.fileExists(atPath: "\(tempDir)/TTYApp"))
            }
        }
    }
}
