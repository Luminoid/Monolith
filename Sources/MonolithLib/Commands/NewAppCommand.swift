import ArgumentParser
import Foundation

struct NewAppCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "app",
        abstract: "Create a new iOS app project."
    )

    @Option(name: .long, help: "App name")
    var name: String?

    @Option(name: .long, help: "Bundle ID (e.g., com.company.app)")
    var bundleID: String?

    @Option(name: .long, help: "Deployment target (e.g., 18.0)")
    var deploymentTarget: String?

    @Option(name: .long, help: "Platforms (comma-separated: iPhone, iPad, macCatalyst)")
    var platforms: String?

    @Option(name: .long, help: "Project system: spm or xcodegen")
    var projectSystem: String?

    @Option(name: .long, help: "Primary color hex (e.g., #007AFF)")
    var primaryColor: String?

    @Option(name: .long, help: "Features (comma-separated): swiftData, lumiKit, snapKit, lottie, darkMode, combine, devTooling, rSwift, fastlane, claudeMD, licenseChangelog")
    var features: String?

    @Option(name: .long, help: "Tabs (format: Name:icon,Name:icon)")
    var tabs: String?

    @Flag(name: .long, help: "Initialize git repository")
    var git = false

    @Flag(name: .long, help: "Skip git initialization")
    var noGit = false

    @Flag(name: .long, help: "Skip interactive prompts")
    var noInteractive = false

    func run() throws {
        let config: AppConfig
        let initGit: Bool

        if noInteractive {
            guard let name else {
                throw ValidationError("--name is required in non-interactive mode")
            }
            let parsedPlatforms = parsePlatforms(platforms ?? "iPhone")
            let parsedProjectSystem = parseProjectSystem(projectSystem ?? "spm")
            let parsedFeatures = parseFeatures(features)
            let parsedTabs = PromptEngine.parseTabs(tabs ?? "")
            let author = FileWriter.gitAuthorName() ?? "Author"

            config = AppConfig(
                name: name,
                bundleID: bundleID ?? Validators.defaultBundleID(for: name),
                deploymentTarget: deploymentTarget ?? "18.0",
                platforms: parsedPlatforms,
                projectSystem: parsedProjectSystem,
                tabs: parsedTabs,
                primaryColor: primaryColor ?? "#007AFF",
                features: parsedFeatures,
                author: author
            )
            initGit = git
        } else {
            config = promptForConfig()
            initGit = noGit ? false : PromptEngine.askYesNo(prompt: "Initialize git repository?")
        }

        try AppProjectGenerator.generate(config: config)

        if initGit {
            let basePath = FileWriter.resolveOutputPath(projectName: config.name)
            FileWriter.gitInit(at: basePath)
        }
    }

    private func promptForConfig() -> AppConfig {
        PromptEngine.printHeader(title: "Monolith \u{2014} New iOS App")

        let name = PromptEngine.askString(prompt: "App name")
        let bundleID = PromptEngine.askString(
            prompt: "Bundle ID",
            default: Validators.defaultBundleID(for: name)
        )
        let deploymentTarget = PromptEngine.askString(
            prompt: "Deployment target",
            default: "18.0"
        )
        let platformsStr = PromptEngine.askString(
            prompt: "Platforms (iPhone, iPad, macCatalyst)",
            default: "iPhone"
        )
        let parsedPlatforms = parsePlatforms(platformsStr)

        let projectSystemStr = PromptEngine.askString(
            prompt: "Project system (spm/xcodegen)",
            default: "spm"
        )
        let parsedProjectSystem = parseProjectSystem(projectSystemStr)

        let primaryColor = PromptEngine.askString(
            prompt: "Primary color hex",
            default: "#007AFF"
        )

        // Features
        let featureOptions = AppFeature.promptOptions
        let selectedIndices = PromptEngine.askMultiSelect(
            prompt: "Optional features",
            options: featureOptions.map(\.displayName)
        )
        let selectedFeatures = Set(selectedIndices.map { featureOptions[$0] })

        // Tabs
        var parsedTabs: [TabDefinition] = []
        let wantTabs = PromptEngine.askYesNo(prompt: "Add tab bar navigation?")
        if wantTabs {
            parsedTabs = PromptEngine.askTabs(prompt: "Tabs (Name:icon, Name:icon)")
        }

        let author = FileWriter.gitAuthorName() ?? PromptEngine.askString(
            prompt: "Author name",
            default: "Author"
        )

        return AppConfig(
            name: name,
            bundleID: bundleID,
            deploymentTarget: deploymentTarget,
            platforms: parsedPlatforms,
            projectSystem: parsedProjectSystem,
            tabs: parsedTabs,
            primaryColor: primaryColor,
            features: selectedFeatures,
            author: author
        )
    }

    // MARK: - Parsing

    private func parsePlatforms(_ input: String) -> Set<Platform> {
        let names = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        var result: Set<Platform> = []
        for name in names {
            switch name.lowercased() {
            case "iphone": result.insert(.iPhone)
            case "ipad": result.insert(.iPad)
            case "maccatalyst", "mac", "catalyst": result.insert(.macCatalyst)
            default: break
            }
        }
        if result.isEmpty { result.insert(.iPhone) }
        return result
    }

    private func parseProjectSystem(_ input: String) -> ProjectSystem {
        switch input.lowercased() {
        case "xcodegen": .xcodeGen
        default: .spm
        }
    }

    private func parseFeatures(_ input: String?) -> Set<AppFeature> {
        guard let input, !input.isEmpty else { return [] }
        let names = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return Set(names.compactMap { name in
            AppFeature.allCases.first { $0.rawValue == name }
        })
    }
}
