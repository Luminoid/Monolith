import ArgumentParser
import Foundation

struct NewCLICommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cli",
        abstract: "Create a new Swift CLI project.",
    )

    @Option(name: .long, help: "Project name")
    var name: String?

    @Option(name: .long, help: "Features (comma-separated): argumentParser, devTooling, claudeMD, licenseChangelog, strictConcurrency")
    var features: String?

    @Flag(name: .long, help: "Initialize git repository")
    var git = false

    @Flag(name: .long, help: "Skip git initialization")
    var noGit = false

    @Flag(name: .long, help: "Skip interactive prompts")
    var noInteractive = false

    func run() throws {
        let config: CLIConfig
        let initGit: Bool

        if noInteractive {
            guard let name else {
                throw ValidationError("--name is required in non-interactive mode")
            }
            guard Validators.validateProjectName(name) else {
                throw ValidationError("Invalid project name '\(name)'. Must start with a letter, contain only alphanumerics/hyphens/underscores, max 50 chars.")
            }
            let parsedFeatures: Set<CLIFeature> = PromptEngine.parseFeatures(features)
            let author = FileWriter.gitAuthorName() ?? "Author"
            config = CLIConfig(
                name: name,
                includeArgumentParser: parsedFeatures.contains(.argumentParser),
                features: parsedFeatures,
                author: author,
            )
            initGit = git
        } else {
            (config, initGit) = promptForConfig()
        }

        try CLIProjectGenerator.generate(config: config)

        if initGit {
            let basePath = FileWriter.resolveOutputPath(projectName: config.name)
            FileWriter.gitInit(at: basePath, hasGitHooks: config.hasGitHooks)
        }
    }

    private func promptForConfig() -> (CLIConfig, Bool) {
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
                hint: "Must start with a letter, alphanumeric/hyphens/underscores, max 50 chars",
                validator: Validators.validateProjectName,
            ),
            YesNoStep(id: "argumentParser", title: "ArgumentParser", prompt: "Include ArgumentParser?"),
            MultiSelectStep(
                id: "features",
                title: "Features",
                prompt: "Optional features",
                options: featureOptions.map(\.displayName),
            ),
            StringStep(
                id: "author",
                title: "Author",
                prompt: "Author name",
                staticDefault: "Author",
                isVisible: { $0.string("author") == nil },
            ),
            YesNoStep(
                id: "initGit",
                title: "Git repository",
                prompt: "Initialize git repository?",
                defaultValue: noGit ? false : true,
            ),
        ]

        WizardEngine.run(title: "Monolith \u{2014} New CLI Project", steps: steps, state: &state)

        // Assemble config
        let selectedIndices = state.intSet("features") ?? []
        var selectedFeatures = Set(selectedIndices.map { featureOptions[$0] })
        if state.bool("argumentParser") == true {
            selectedFeatures.insert(.argumentParser)
        }

        let config = CLIConfig(
            name: state.string("name") ?? "",
            includeArgumentParser: state.bool("argumentParser") ?? true,
            features: selectedFeatures,
            author: state.string("author") ?? "Author",
        )
        let initGit = state.bool("initGit") ?? false

        return (config, initGit)
    }
}
