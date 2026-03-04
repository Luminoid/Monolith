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

    @Option(name: .long, help: "Features (comma-separated): swiftData, lumiKit, snapKit, lottie, darkMode, combine, localization, devTooling, gitHooks, rSwift, fastlane, claudeMD, licenseChangelog")
    var features: String?

    @Option(name: .long, help: "Tabs (format: Name:icon,Name:icon)")
    var tabs: String?

    @Option(name: .long, help: "Feature preset: minimal, standard, full")
    var preset: String?

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
        var config: AppConfig
        var initGit: Bool
        var shouldOpen = open
        var shouldResolve = resolve

        if let loadConfig {
            let loaded = try ConfigFile.load(from: loadConfig)
            guard let appConfig = loaded.app else {
                throw ValidationError("Config file does not contain an app config.")
            }
            config = appConfig
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
                ConfigFile.MonolithConfig(projectType: .app, app: config, package: nil, cli: nil, initGit: initGit),
                to: saveConfig,
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
            interactive: !noInteractive,
        )
        if overwriteResult == .abort { return }

        try AppProjectGenerator.generate(config: config, outputDir: output)

        let basePath = FileWriter.resolveOutputPath(projectName: config.name, outputDir: output)

        if initGit {
            FileWriter.gitInit(at: basePath, hasGitHooks: config.hasGitHooks)
        }

        if shouldResolve, config.projectSystem == .spm {
            PackageResolver.resolve(at: basePath)
        }

        if shouldOpen {
            ProjectOpener.open(at: basePath, projectSystem: config.projectSystem)
        }
    }

    // MARK: - Non-Interactive Config

    private func buildNonInteractiveConfig() throws -> (AppConfig, Bool) {
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
        var parsedFeatures: Set<AppFeature> = PromptEngine.parseFeatures(features)

        if let preset {
            guard let resolvedPreset = Preset(rawValue: preset) else {
                throw ValidationError("Unknown preset '\(preset)'. Valid: minimal, standard, full")
            }
            parsedFeatures = parsedFeatures.union(resolvedPreset.appFeatures(projectSystem: parsedProjectSystem))
        }

        let parsedTabs = PromptEngine.parseTabs(tabs ?? "")
        let author = FileWriter.gitAuthorName() ?? "Author"

        let config = AppConfig(
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
        return (config, git)
    }

    // MARK: - Interactive Config

    private func promptForConfig() -> (config: AppConfig, initGit: Bool, openProject: Bool, resolvePackages: Bool) {
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
            MultiSelectStep(
                id: "platforms",
                title: "Platforms",
                prompt: "Target platforms (select at least one, or press Enter for iPhone)",
                options: Platform.allCases.map(\.displayName),
            ),
            SingleSelectStep(
                id: "projectSystem",
                title: "Project system",
                prompt: "Project system",
                options: ProjectSystem.allCases.map(\.displayName),
                defaultIndex: ProjectSystem.allCases.firstIndex(of: .spm) ?? 0,
            ),
            ValidatedStringStep(
                id: "primaryColor",
                title: "Primary color",
                prompt: "Primary color hex (e.g., #4CAF7D, #FF6B35)",
                staticDefault: "#007AFF",
                hint: "Must be #RRGGBB format",
                validator: Validators.validateHexColor,
            ),
            SingleSelectStep(
                id: "preset",
                title: "Preset",
                prompt: "Feature preset",
                options: Preset.allCases.map(\.displayName),
                defaultIndex: 1,
            ),
            MultiSelectStep(
                id: "features",
                title: "Features",
                prompt: "Optional features (preset applied, modify as needed)",
                options: featureOptions.map(\.displayName),
                preselected: { state in
                    let presetIndex = state.int("preset") ?? 1
                    let presetCase = presetIndex < Preset.allCases.count ? Preset.allCases[presetIndex] : .standard
                    let allSystems = ProjectSystem.allCases
                    let systemIndex = state.int("projectSystem") ?? 0
                    let system = systemIndex < allSystems.count ? allSystems[systemIndex] : .spm
                    let presetFeatures = presetCase.appFeatures(projectSystem: system)
                    return Set(featureOptions.enumerated().compactMap { index, feature in
                        presetFeatures.contains(feature) ? index : nil
                    })
                },
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
            YesNoStep(
                id: "openProject",
                title: "Open in Xcode",
                prompt: "Open project in Xcode after generation?",
                defaultValue: false,
            ),
        ]

        WizardEngine.run(title: "Monolith \u{2014} New iOS App", steps: steps, state: &state)

        // Assemble config
        let platformIndices = state.intSet("platforms") ?? []
        let parsedPlatforms: Set<Platform> = if platformIndices.isEmpty {
            [.iPhone]
        } else {
            Set(platformIndices.compactMap { idx in
                idx < Platform.allCases.count ? Platform.allCases[idx] : nil
            })
        }

        let allSystems = ProjectSystem.allCases
        let projectSystemIndex = state.int("projectSystem") ?? 0
        let parsedProjectSystem = projectSystemIndex < allSystems.count
            ? allSystems[projectSystemIndex]
            : .spm

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
        let openProject = state.bool("openProject") ?? false

        return (config, initGit, openProject, false)
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
            default:
                FileHandle.standardError.write(
                    Data("warning: unrecognized platform '\(name)' (valid: iPhone, iPad, macCatalyst)\n".utf8),
                )
            }
        }
        if result.isEmpty { result.insert(.iPhone) }
        return result
    }

    private func parseProjectSystem(_ input: String) -> ProjectSystem {
        switch input.lowercased() {
        case "xcodegen":
            return .xcodeGen
        case "spm":
            return .spm
        default:
            FileHandle.standardError.write(
                Data("warning: unrecognized project system '\(input)' (valid: spm, xcodegen), defaulting to spm\n".utf8),
            )
            return .spm
        }
    }
}
