import ArgumentParser
import Foundation

struct NewCLICommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cli",
        abstract: "Create a new Swift CLI project."
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
            let parsedFeatures = parseFeatures(features)
            let author = FileWriter.gitAuthorName() ?? "Author"
            config = CLIConfig(
                name: name,
                includeArgumentParser: parsedFeatures.contains(.argumentParser),
                features: parsedFeatures,
                author: author
            )
            initGit = git
        } else {
            config = promptForConfig()
            initGit = noGit ? false : PromptEngine.askYesNo(prompt: "Initialize git repository?")
        }

        try CLIProjectGenerator.generate(config: config)

        if initGit {
            let basePath = FileWriter.resolveOutputPath(projectName: config.name)
            FileWriter.gitInit(at: basePath)
        }
    }

    private func promptForConfig() -> CLIConfig {
        PromptEngine.printHeader(title: "Monolith \u{2014} New CLI Project")

        let name = PromptEngine.askString(prompt: "CLI name")
        let includeAP = PromptEngine.askYesNo(prompt: "Include ArgumentParser?")

        let featureOptions = CLIFeature.allCases.filter { $0 != .argumentParser }
        let selectedIndices = PromptEngine.askMultiSelect(
            prompt: "Optional features",
            options: featureOptions.map(\.displayName)
        )

        var selectedFeatures = Set(selectedIndices.map { featureOptions[$0] })
        if includeAP {
            selectedFeatures.insert(.argumentParser)
        }

        let author = FileWriter.gitAuthorName() ?? PromptEngine.askString(prompt: "Author name", default: "Author")

        return CLIConfig(
            name: name,
            includeArgumentParser: includeAP,
            features: selectedFeatures,
            author: author
        )
    }

    private func parseFeatures(_ input: String?) -> Set<CLIFeature> {
        guard let input, !input.isEmpty else { return [] }
        let names = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return Set(names.compactMap { name in
            CLIFeature.allCases.first { $0.rawValue == name }
        })
    }
}
