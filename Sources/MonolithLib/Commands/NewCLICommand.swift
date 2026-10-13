import ArgumentParser
import Foundation

struct NewCLICommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cli",
        abstract: "Create a new Swift CLI project."
    )

    @OptionGroup var common: NewCommandOptions

    @Option(name: .long, help: FeatureFlagHelp.cli, completion: FeatureFlagHelp.completion(CLIFeature.allCases))
    var features: String?

    @Flag(name: .long, help: "Build the CLI without swift-argument-parser (a plain main.swift)")
    var noArgumentParser = false

    func validate() throws {
        try common.validateLoadConfig(commandFlags: [("--features", features != nil), ("--no-argument-parser", noArgumentParser)])
        // Parsed here as well as in `run()`, so a bad value fails with this
        // subcommand's usage line instead of the root command's.
        if let name = common.name {
            try NewCommandOptions.checkName(name, kind: .cli)
        }
        _ = try parsedFeatures()
    }

    func run() throws {
        ShellRunner.isVerbose = common.verbose
        let resolved = try resolveConfig()
        let config = resolved.config

        try NewCommandRunner.run(
            config: config,
            saveConfigPath: common.saveConfig,
            outputDir: common.output,
            force: common.force,
            interactive: resolved.interactive,
            dryRun: common.dryRun,
            shouldInitGit: resolved.initGit,
            shouldResolve: common.resolve,
            shouldOpen: common.open || resolved.openProject,
            hasGitHooks: config.hasGitHooks,
            hasDevTooling: config.hasDevTooling,
            requestsStrictConcurrency: config.features.contains(.strictConcurrency),
            projectSystem: .spm,
            printDryRun: { DryRunPlanner.printDryRun(config: config, outputDir: common.output) },
            generate: { try CLIProjectGenerator.generate(config: config, outputDir: common.output) },
            summary: { _ in NewCommandRunner.Summary(headline: "Done! Run with: swift run \(config.name)") }
        )
    }

    /// The config from `--load-config`, the flags (`--no-interactive`), or the wizard.
    func resolveConfig() throws -> ResolvedConfig<CLIConfig> {
        if let loaded = try common.loadedConfig(.cli, section: \.cli) {
            return loaded
        }
        if common.noInteractive {
            return try ResolvedConfig(config: buildNonInteractiveConfig(), initGit: common.git ?? false, openProject: false, interactive: false)
        }
        try NewCommandWizard.requireTerminal()
        return try promptForConfig()
    }

    // MARK: - Non-Interactive Config

    private func buildNonInteractiveConfig() throws -> CLIConfig {
        let name = try common.requiredName(kind: .cli)
        var features = try parsedFeatures() ?? []
        if let preset = common.preset {
            features.formUnion(preset.cliFeatures())
        }
        // ArgumentParser is on by default, as in the wizard;
        // --no-argument-parser turns it off, including a preset's.
        return CLIConfig(
            name: name,
            includeArgumentParser: !noArgumentParser,
            features: features,
            author: GitRunner.authorNameOrPlaceholder(),
            licenseType: common.license ?? .defaultFor(.cli)
        )
    }

    /// `--features`, or nil when it wasn't passed.
    private func parsedFeatures() throws -> Set<CLIFeature>? {
        guard let features else { return nil }
        let parsed = try ValidationBridge.bridge { try CLIFeature.parseList(features) }
        if noArgumentParser, parsed.contains(.argumentParser) {
            throw ValidationError("--no-argument-parser contradicts --features argumentParser. Drop one of them.")
        }
        return parsed
    }

    // MARK: - Interactive Config

    /// The wizard. Steps a flag answers are skipped and shown on the summary.
    func promptForConfig() throws -> ResolvedConfig<CLIConfig> {
        let flagFeatures = try parsedFeatures().map { $0.union(common.preset?.cliFeatures() ?? []) }
        let featureOptions = CLIFeature.allCases.filter { $0 != .argumentParser && $0 != .strictConcurrency }
        let selected = { (state: WizardState) in Set((state.intSet("features") ?? []).map { featureOptions[$0] }) }

        var state = WizardState()
        if let name = common.name {
            try NewCommandOptions.checkName(name, kind: .cli)
            state.fix("name", name)
        }
        NewCommandWizard.prefill(&state, from: common, featuresGiven: flagFeatures != nil)
        if noArgumentParser {
            state.fix("argumentParser", false)
        } else if flagFeatures?.contains(.argumentParser) == true {
            state.fix("argumentParser", true)
        }
        if let flagFeatures {
            state.fix("features", NewCommandWizard.indices(of: flagFeatures, in: featureOptions))
        }

        let steps: [any WizardStep] = [
            ValidatedStringStep(
                id: "name",
                title: "CLI name",
                prompt: "CLI name (e.g., my-tool)",
                hint: Validators.projectNameRule(for: .cli),
                validator: { Validators.validateProjectName($0, kind: .cli) }
            ),
            YesNoStep(id: "argumentParser", title: "ArgumentParser", prompt: "Include ArgumentParser?"),
            NewCommandWizard.presetStep(for: .cli),
            MultiSelectStep(
                id: "features",
                title: "Features",
                prompt: "Optional features (preset applied, modify as needed)",
                options: featureOptions.map(\.displayName),
                preselected: { NewCommandWizard.indices(of: NewCommandWizard.preset(in: $0).cliFeatures(), in: featureOptions) }
            ),
        ] + NewCommandWizard.endingSteps(defaultLicense: .defaultFor(.cli)) { selected($0).contains(.licenseChangelog) }

        try WizardEngine.run(title: "Monolith — New CLI Project", steps: steps, state: &state)

        let ending = NewCommandWizard.ending(from: state, defaultLicense: .defaultFor(.cli))
        let config = CLIConfig(
            name: state.string("name") ?? "",
            includeArgumentParser: state.bool("argumentParser") ?? true,
            features: flagFeatures ?? selected(state),
            author: ending.author,
            licenseType: ending.licenseType
        )
        return ResolvedConfig(config: config, initGit: ending.initGit, openProject: ending.openProject, interactive: true)
    }
}
