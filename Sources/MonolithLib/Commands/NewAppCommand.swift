import ArgumentParser
import Foundation

struct NewAppCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "app",
        abstract: "Create a new iOS app project.",
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
                author: author,
            )
            initGit = git
        } else {
            (config, initGit) = promptForConfig()
        }

        try AppProjectGenerator.generate(config: config)

        if initGit {
            let basePath = FileWriter.resolveOutputPath(projectName: config.name)
            FileWriter.gitInit(at: basePath, hasGitHooks: config.hasGitHooks)
        }
    }

    private func promptForConfig() -> (AppConfig, Bool) {
        var state = WizardState()

        // Pre-fill author from git
        if let gitAuthor = FileWriter.gitAuthorName() {
            state.values["author"] = gitAuthor
        }

        let featureOptions = AppFeature.promptOptions

        let steps: [any WizardStep] = [
            ValidatedStringStep(
                id: "name",
                title: "App name",
                prompt: "App name (e.g., MyApp)",
                hint: "Must start with a letter, alphanumeric/hyphens/underscores, max 50 chars",
                validator: Validators.validateProjectName,
            ),
            ValidatedStringStep(
                id: "bundleID",
                title: "Bundle ID",
                prompt: "Bundle ID (e.g., com.company.app)",
                defaultValue: { Validators.defaultBundleID(for: $0.string("name") ?? "") },
                hint: "Must be reverse-DNS format (e.g., com.company.app)",
                validator: Validators.validateBundleID,
            ),
            ValidatedStringStep(
                id: "deploymentTarget",
                title: "Deployment target",
                prompt: "Deployment target (e.g., 18.0, 19.0)",
                staticDefault: "18.0",
                hint: "Must be major.minor format >= 18.0 (e.g., 18.0)",
                validator: Validators.validateDeploymentTarget,
            ),
            StringStep(
                id: "platforms",
                title: "Platforms",
                prompt: "Platforms (e.g., iPhone, iPad, macCatalyst)",
                staticDefault: "iPhone",
            ),
            StringStep(
                id: "projectSystem",
                title: "Project system",
                prompt: "Project system (spm / xcodegen)",
                staticDefault: "spm",
            ),
            ValidatedStringStep(
                id: "primaryColor",
                title: "Primary color",
                prompt: "Primary color hex (e.g., #4CAF7D, #FF6B35)",
                staticDefault: "#007AFF",
                hint: "Must be #RRGGBB format",
                validator: Validators.validateHexColor,
            ),
            MultiSelectStep(
                id: "features",
                title: "Features",
                prompt: "Optional features",
                options: featureOptions.map(\.displayName),
            ),
            YesNoStep(
                id: "wantTabs",
                title: "Tab bar",
                prompt: "Add tab bar navigation?",
                defaultValue: false,
            ),
            TabsStep(
                id: "tabs",
                title: "Tabs",
                prompt: "Tabs (e.g., Home:house, Settings:gearshape)",
                isVisible: { $0.bool("wantTabs") == true },
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

        WizardEngine.run(title: "Monolith \u{2014} New iOS App", steps: steps, state: &state)

        // Assemble config
        let parsedPlatforms = parsePlatforms(state.string("platforms") ?? "iPhone")
        let parsedProjectSystem = parseProjectSystem(state.string("projectSystem") ?? "spm")

        let selectedIndices = state.intSet("features") ?? []
        let selectedFeatures = Set(selectedIndices.map { featureOptions[$0] })

        let parsedTabs = state.tabDefinitions("tabs") ?? []

        let config = AppConfig(
            name: state.string("name") ?? "",
            bundleID: state.string("bundleID") ?? "",
            deploymentTarget: state.string("deploymentTarget") ?? "18.0",
            platforms: parsedPlatforms,
            projectSystem: parsedProjectSystem,
            tabs: parsedTabs,
            primaryColor: state.string("primaryColor") ?? "#007AFF",
            features: selectedFeatures,
            author: state.string("author") ?? "Author",
        )
        let initGit = state.bool("initGit") ?? false

        return (config, initGit)
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
