import ArgumentParser
import Foundation

struct NewCLICommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cli",
        abstract: "Create a new Swift CLI project."
    )

    @Option(name: .long, help: "Project name")
    var name: String?

    @Option(name: .long, help: "Features (comma-separated): argumentParser, strictConcurrency, devTooling, gitHooks, claudeMD, licenseChangelog")
    var features: String?

    @Option(name: .long, help: "Feature preset: minimal, standard, full")
    var preset: String?

    @Option(name: .long, help: "License type: mit, apache2, proprietary (default: apache2 for CLIs)")
    var license: String?

    @Flag(name: .long, help: "Initialize git repository")
    var git = false

    @Flag(name: .long, help: "Skip git initialization")
    var noGit = false

    @Option(name: .long, help: "Output directory (default: current directory)")
    var output: String?

    @Flag(name: .long, help: "Preview generated files without writing")
    var dryRun = false

    @Flag(name: .long, help: "Skip interactive prompts")
    var noInteractive = false

    @Flag(name: .long, help: "Overwrite existing directory without prompting")
    var force = false

    @Flag(name: .long, help: "Open project in Xcode after generation")
    var open = false

    @Flag(name: .long, help: "Run swift package resolve after generation")
    var resolve = false

    @Option(name: .long, help: "Save resolved config to JSON file")
    var saveConfig: String?

    @Option(name: .long, help: "Load config from JSON file (skips wizard)")
    var loadConfig: String?

    func run() throws {
        var config: CLIConfig
        var initGit: Bool
        var shouldOpen = open
        var shouldResolve = resolve

        if let loadConfig {
            let loaded = try ConfigFile.load(from: loadConfig)
            guard let cliConfig = loaded.cli else {
                throw ValidationError("Config file does not contain a CLI config.")
            }
            config = cliConfig
            initGit = loaded.initGit
        } else if noInteractive {
            (config, initGit) = try buildNonInteractiveConfig()
        } else {
            let result = promptForConfig()
            config = result.config
            initGit = result.initGit
            shouldOpen = shouldOpen || result.openProject
            shouldResolve = shouldResolve || result.resolvePackages
        }

        if let saveConfig {
            try ConfigFile.save(
                ConfigFile.MonolithConfig(projectType: .cli, app: nil, package: nil, cli: config, initGit: initGit),
                to: saveConfig
            )
        }

        if dryRun {
            FileWriter.printDryRun(config: config, outputDir: output)
            return
        }

        let overwriteResult = OverwriteProtection.check(
            projectName: config.name,
            outputDir: output,
            force: force,
            interactive: !noInteractive
        )
        if overwriteResult == .abort { return }

        try CLIProjectGenerator.generate(config: config, outputDir: output)

        let basePath = FileWriter.resolveOutputPath(projectName: config.name, outputDir: output)

        if initGit {
            FileWriter.gitInit(at: basePath, hasGitHooks: config.hasGitHooks)
        }

        if shouldResolve {
            PackageResolver.resolve(at: basePath)
        }

        if shouldOpen {
            ProjectOpener.open(at: basePath, projectSystem: .spm)
        }
    }

    // MARK: - Non-Interactive Config

    private func buildNonInteractiveConfig() throws -> (CLIConfig, Bool) {
        guard let name else {
            throw ValidationError("--name is required in non-interactive mode")
        }
        guard Validators.validateProjectName(name) else {
            throw ValidationError("Invalid project name '\(name)'. Must start with a letter, contain only alphanumerics/hyphens/underscores, max \(Validators.maxProjectNameLength) chars.")
        }
        var parsedFeatures: Set<CLIFeature> = PromptEngine.parseFeatures(features)

        if let preset {
            guard let resolvedPreset = Preset(rawValue: preset) else {
                throw ValidationError("Unknown preset '\(preset)'. Valid: minimal, standard, full")
            }
            parsedFeatures = parsedFeatures.union(resolvedPreset.cliFeatures())
        }

        let author = FileWriter.gitAuthorName() ?? "Author"

        var parsedLicenseType: LicenseType = .apache2
        if let license {
            guard let lt = LicenseType(rawValue: license) else {
                throw ValidationError("Unknown license '\(license)'. Valid: \(LicenseType.allCases.map(\.rawValue).joined(separator: ", "))")
            }
            parsedLicenseType = lt
        }

        let config = CLIConfig(
            name: name,
            includeArgumentParser: parsedFeatures.contains(.argumentParser),
            features: parsedFeatures,
            author: author,
            licenseType: parsedLicenseType
        )
        return (config, git)
    }

    // MARK: - Interactive Config

    private func promptForConfig() -> (config: CLIConfig, initGit: Bool, openProject: Bool, resolvePackages: Bool) {
        var state = WizardState()

        // Pre-fill author from git
        if let gitAuthor = FileWriter.gitAuthorName() {
            state.values["author"] = gitAuthor
        }

        let featureOptions = CLIFeature.allCases.filter { $0 != .argumentParser }

        let steps: [any WizardStep] = [
            ValidatedStringStep(
                id: "name",
                title: "CLI name",
                prompt: "CLI name (e.g., my-tool)",
                hint: "Must start with a letter, alphanumeric/hyphens/underscores, max \(Validators.maxProjectNameLength) chars",
                validator: Validators.validateProjectName
            ),
            YesNoStep(id: "argumentParser", title: "ArgumentParser", prompt: "Include ArgumentParser?"),
            MultiSelectStep(
                id: "features",
                title: "Features",
                prompt: "Optional features",
                options: featureOptions.map(\.displayName)
            ),
            SingleSelectStep(
                id: "licenseType",
                title: "License type",
                prompt: "License type",
                options: LicenseType.allCases.map { "\($0.displayName) \u{2014} \($0.shortDescription)" },
                defaultIndex: LicenseType.allCases.firstIndex(of: .apache2) ?? 1,
                isVisible: { state in
                    let selectedIndices = state.intSet("features") ?? []
                    let selectedFeatures = Set(selectedIndices.map { featureOptions[$0] })
                    return selectedFeatures.contains(.licenseChangelog)
                }
            ),
            StringStep(
                id: "author",
                title: "Author",
                prompt: "Author name",
                staticDefault: "Author",
                isVisible: { $0.string("author") == nil }
            ),
            YesNoStep(
                id: "initGit",
                title: "Git repository",
                prompt: "Initialize git repository?",
                defaultValue: noGit ? false : true
            ),
            YesNoStep(
                id: "openProject",
                title: "Open in Xcode",
                prompt: "Open project in Xcode after generation?",
                defaultValue: false
            ),
        ]

        WizardEngine.run(title: "Monolith \u{2014} New CLI Project", steps: steps, state: &state)

        // Assemble config
        let selectedIndices = state.intSet("features") ?? []
        var selectedFeatures = Set(selectedIndices.map { featureOptions[$0] })
        if state.bool("argumentParser") == true {
            selectedFeatures.insert(.argumentParser)
        }

        let licenseTypeIndex = state.int("licenseType") ?? LicenseType.allCases.firstIndex(of: .apache2) ?? 1
        let licenseType = licenseTypeIndex < LicenseType.allCases.count
            ? LicenseType.allCases[licenseTypeIndex]
            : .apache2

        let config = CLIConfig(
            name: state.string("name") ?? "",
            includeArgumentParser: state.bool("argumentParser") ?? true,
            features: selectedFeatures,
            author: state.string("author") ?? "Author",
            licenseType: licenseType
        )
        let initGit = state.bool("initGit") ?? false
        let openProject = state.bool("openProject") ?? false

        return (config, initGit, openProject, false)
    }
}
