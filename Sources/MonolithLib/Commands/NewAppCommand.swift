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

    @Option(name: .long, help: "Features (comma-separated): swiftData, lumiKit, snapKit, lottie, darkMode, combine, localization, devTooling, rSwift, fastlane, claudeMD, licenseChangelog")
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
            guard Validators.validateProjectName(name) else {
                throw ValidationError("Invalid project name '\(name)'. Must start with a letter, contain only alphanumerics/hyphens/underscores, max 50 chars.")
            }
            let resolvedBundleID = bundleID ?? Validators.defaultBundleID(for: name)
            guard Validators.validateBundleID(resolvedBundleID) else {
                throw ValidationError("Invalid bundle ID '\(resolvedBundleID)'. Must be reverse-DNS format (e.g., com.company.app).")
            }
            let resolvedTarget = deploymentTarget ?? "18.0"
            guard Validators.validateDeploymentTarget(resolvedTarget) else {
                throw ValidationError("Invalid deployment target '\(resolvedTarget)'. Must be major.minor format >= 18.0.")
            }
            let resolvedColor = primaryColor ?? "#007AFF"
            guard Validators.validateHexColor(resolvedColor) else {
                throw ValidationError("Invalid hex color '\(resolvedColor)'. Must be #RRGGBB format.")
            }

            let parsedPlatforms = parsePlatforms(platforms ?? "iPhone")
            let parsedProjectSystem = parseProjectSystem(projectSystem ?? "spm")
            let parsedFeatures: Set<AppFeature> = PromptEngine.parseFeatures(features)
            let parsedTabs = PromptEngine.parseTabs(tabs ?? "")
            let author = FileWriter.gitAuthorName() ?? "Author"

            config = AppConfig(
                name: name,
                bundleID: resolvedBundleID,
                deploymentTarget: resolvedTarget,
                platforms: parsedPlatforms,
                projectSystem: parsedProjectSystem,
                tabs: parsedTabs,
                primaryColor: resolvedColor,
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

        let name = PromptEngine.askValidatedString(
            prompt: "App name",
            hint: "Must start with a letter, alphanumeric/hyphens/underscores, max 50 chars",
            validator: Validators.validateProjectName
        )
        let bundleID = PromptEngine.askValidatedString(
            prompt: "Bundle ID",
            default: Validators.defaultBundleID(for: name),
            hint: "Must be reverse-DNS format (e.g., com.company.app)",
            validator: Validators.validateBundleID
        )
        let deploymentTarget = PromptEngine.askValidatedString(
            prompt: "Deployment target",
            default: "18.0",
            hint: "Must be major.minor format >= 18.0 (e.g., 18.0)",
            validator: Validators.validateDeploymentTarget
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

        let primaryColor = PromptEngine.askValidatedString(
            prompt: "Primary color hex",
            default: "#007AFF",
            hint: "Must be #RRGGBB format",
            validator: Validators.validateHexColor
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

}
