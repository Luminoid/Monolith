import ArgumentParser
import Foundation

struct NewAppCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "app",
        abstract: "Create a new iOS app project."
    )

    @OptionGroup var common: NewCommandOptions

    @Option(name: .long, help: "Bundle ID (e.g., com.company.app)")
    var bundleID: String?

    @Option(name: .long, help: "Deployment target (e.g., 18.0)")
    var deploymentTarget: String?

    @Option(name: .long, help: "Platforms (comma-separated: iPhone, iPad, macCatalyst; default: iPhone,iPad)")
    var platforms: String?

    @Option(name: .long, help: "Project system: xcodeproj (default) or xcodegen")
    var projectSystem: String?

    @Option(name: .long, help: "Primary color hex (e.g., #007AFF)")
    var primaryColor: String?

    @Option(name: .long, help: FeatureFlagHelp.app, completion: FeatureFlagHelp.completion(AppFeature.flagValues))
    var features: String?

    @Option(name: .long, help: "Tabs (format: Name:icon,Name:icon)")
    var tabs: String?

    // swiftformat:disable all
    // swiftlint:disable:next line_length
    @Option(name: .long, help: "Built-in third-party packages (comma-separated). Identifiers come from the KnownPackages registry. Optional `:version` overrides the registry default. Example: --use-packages 'SnapKit,LookinServer:1.2.8'")
    var usePackages: String?

    // swiftlint:disable:next line_length
    @Option(name: .long, help: "Third-party SPM packages outside the built-in registry (format: \"Name=url:requirement[:packageName];...\"). Each declared entry MUST also appear in --target-deps. Example: --external-packages 'ExtPkg=https://github.com/example/ExtPkg.git:from: \"1.0.0\"' (URL form) or 'ExtPkg=../ExtPkg' (local path)")
    var externalPackages: String?

    // swiftlint:disable:next line_length
    @Option(name: .long, help: "Products to link into the app target (comma-separated). Each name must resolve to a built-in (auto-added when --features or --use-packages requests it) or an --external-packages entry. Example: --target-deps 'ExtPkgCore,ExtPkgUI'")
    var targetDeps: String?

    // swiftlint:disable:next line_length
    @Option(name: .long, help: "Locales for the Localizable.xcstrings catalog (comma-separated; the first is the source language; default: en). Example: 'en,zh-Hans,es'. Ignored when --features doesn't include localization.")
    var locales: String?

    @Option(name: .long, help: "App Store category (e.g., public.app-category.productivity). Required for Mac App Store distribution. Default: public.app-category.utilities.")
    var category: String?
    // swiftformat:enable all

    /// The flags that set the config, parsed and checked. `nil` means not passed.
    private struct Flags {
        var bundleID: String?
        var deploymentTarget: String?
        var platforms: Set<Platform>?
        var projectSystem: ProjectSystem?
        var primaryColor: String?
        var features: Set<AppFeature>?
        var tabs: [TabDefinition]?
        /// `--use-packages` entries, then `--external-packages` entries.
        var externalPackages: [ExternalPackage]?
        /// `--target-deps`, plus every `--use-packages` entry.
        var targetDependencies: [String]?
        var locales: [String]?
    }

    func validate() throws {
        try common.validateLoadConfig(commandFlags: [
            ("--bundle-id", bundleID != nil), ("--deployment-target", deploymentTarget != nil), ("--platforms", platforms != nil),
            ("--project-system", projectSystem != nil), ("--primary-color", primaryColor != nil), ("--features", features != nil),
            ("--tabs", tabs != nil), ("--use-packages", usePackages != nil), ("--external-packages", externalPackages != nil),
            ("--target-deps", targetDeps != nil), ("--locales", locales != nil), ("--category", category != nil),
        ])
        // Parsed here as well as in `run()`, so a bad value fails with this
        // subcommand's usage line instead of the root command's.
        if let name = common.name {
            try NewCommandOptions.checkName(name, kind: .app)
        }
        _ = try parsedFlags()
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
            // `strictConcurrency` is accepted on apps for symmetry with the
            // package and CLI commands, and acts on none of them.
            requestsStrictConcurrency: config.features.contains(.strictConcurrency),
            warnings: config.deprecationWarnings,
            projectSystem: config.projectSystem,
            printDryRun: { DryRunPlanner.printDryRun(config: config, outputDir: common.output) },
            generate: { try AppProjectGenerator.generate(config: config, outputDir: common.output) },
            summary: { basePath in
                NewCommandRunner.Summary(headline: "\(config.name) app created at \(basePath)", steps: AppProjectGenerator.nextSteps(config: config))
            }
        )
    }

    /// The config from `--load-config`, the flags (`--no-interactive`), or the wizard.
    func resolveConfig() throws -> ResolvedConfig<AppConfig> {
        // `NewCommandRunner` validates a loaded config (name, project
        // system, and the rest) before anything is written.
        if let loaded = try common.loadedConfig(.app, section: \.app) {
            return loaded
        }
        if common.noInteractive {
            return try ResolvedConfig(config: buildNonInteractiveConfig(), initGit: common.git ?? false, openProject: false, interactive: false)
        }
        try NewCommandWizard.requireTerminal()
        return try promptForConfig()
    }

    /// The platforms an app gets without `--platforms`: iPhone and iPad.
    static var defaultPlatforms: Set<Platform> {
        (try? Platform.parseList(Defaults.defaultPlatform)) ?? [.iPhone, .iPad]
    }

    // MARK: - Flags

    private func parsedFlags() throws -> Flags {
        var flags = Flags()
        if let bundleID {
            guard Validators.validateBundleID(bundleID) else {
                throw ValidationError("Invalid bundle ID '\(bundleID)'. Must be reverse-DNS format (e.g., com.company.app).")
            }
            flags.bundleID = bundleID
        }
        if let deploymentTarget {
            guard Validators.validateDeploymentTarget(deploymentTarget) else {
                throw ValidationError("Invalid deployment target '\(deploymentTarget)'. Must be major.minor format >= \(Validators.minimumDeploymentMajor).0.")
            }
            flags.deploymentTarget = deploymentTarget
        }
        if let primaryColor {
            guard Validators.validateHexColor(primaryColor) else {
                throw ValidationError("Invalid hex color '\(primaryColor)'. Must be #RRGGBB format.")
            }
            flags.primaryColor = primaryColor
        }
        if let platforms {
            flags.platforms = try ValidationBridge.bridge { try Platform.parseList(platforms) }
        }
        if let projectSystem {
            flags.projectSystem = try ValidationBridge.bridge { try ProjectSystem.parseForApps(projectSystem) }
        }
        if let features {
            flags.features = try ValidationBridge.bridge { try AppFeature.parseList(features) }
        }
        if let tabs {
            flags.tabs = try ValidationBridge.bridge { try TabDefinition.parseList(tabs) }
        }

        // --use-packages entries auto-link into the app target, so the user
        // doesn't need to repeat them in --target-deps.
        let registryExternals = try ValidationBridge.bridge { try ExternalPackage.parseUsePackages(usePackages) }
        let rawExternals = try ValidationBridge.bridge { try ExternalPackage.parse(externalPackages) }
        if usePackages != nil || externalPackages != nil {
            flags.externalPackages = registryExternals + rawExternals
        }
        if targetDeps != nil || !registryExternals.isEmpty {
            var dependencies = CommaList.tokens(targetDeps)
            for ext in registryExternals where !dependencies.contains(ext.name) {
                dependencies.append(ext.name)
            }
            flags.targetDependencies = dependencies
        }

        if let locales {
            flags.locales = try LocaleList.parse(locales)
        }
        return flags
    }

    // MARK: - Non-Interactive Config

    private func buildNonInteractiveConfig() throws -> AppConfig {
        let name = try common.requiredName(kind: .app)
        let flags = try parsedFlags()
        var features = flags.features ?? []
        if let preset = common.preset {
            features.formUnion(preset.appFeatures())
        }

        return AppConfig(
            name: name,
            bundleID: flags.bundleID ?? Validators.defaultBundleID(for: name),
            deploymentTarget: flags.deploymentTarget ?? Defaults.deploymentTarget,
            platforms: flags.platforms ?? Self.defaultPlatforms,
            projectSystem: flags.projectSystem ?? .xcodeProj,
            tabs: flags.tabs ?? [],
            primaryColor: flags.primaryColor ?? Defaults.primaryColor,
            features: features,
            author: GitRunner.authorNameOrPlaceholder(),
            licenseType: common.license ?? .defaultFor(.app),
            externalPackages: flags.externalPackages ?? [],
            targetDependencies: flags.targetDependencies ?? [],
            locales: flags.locales ?? ["en"],
            applicationCategory: category
        )
    }

    // MARK: - Interactive Config

    /// The wizard. Steps a flag answers are skipped and shown on the summary.
    func promptForConfig() throws -> ResolvedConfig<AppConfig> {
        let flags = try parsedFlags()
        let flagFeatures = flags.features.map { $0.union(common.preset?.appFeatures() ?? []) }
        let featureOptions = AppFeature.promptOptions
        let platformOptions = Platform.allCases
        let systems = ProjectSystem.appOptions
        let selected = { (state: WizardState) in Set((state.intSet("features") ?? []).map { featureOptions[$0] }) }

        var state = WizardState()
        try prefill(&state, flags: flags, flagFeatures: flagFeatures, featureOptions: featureOptions)

        let steps: [any WizardStep] = [
            ValidatedStringStep(
                id: "name",
                title: "App name",
                prompt: "App name (e.g., MyApp)",
                hint: Validators.projectNameRule(for: .app),
                validator: { Validators.validateProjectName($0, kind: .app) }
            ),
            ValidatedStringStep(
                id: "bundleID",
                title: "Bundle ID",
                prompt: "Bundle ID (e.g., com.company.app)",
                defaultValue: { Validators.defaultBundleID(for: $0.string("name") ?? "") },
                hint: "Must be reverse-DNS format (e.g., com.company.app)",
                validator: Validators.validateBundleID
            ),
            ValidatedStringStep(
                id: "deploymentTarget",
                title: "Deployment target",
                prompt: "Deployment target (e.g., 18.0, 19.0)",
                staticDefault: Defaults.deploymentTarget,
                hint: "Must be major.minor format >= \(Defaults.deploymentTarget) (e.g., \(Defaults.deploymentTarget))",
                validator: Validators.validateDeploymentTarget
            ),
            MultiSelectStep(
                id: "platforms",
                title: "Platforms",
                prompt: "Target platforms",
                options: platformOptions.map(\.displayName),
                preselected: { _ in NewCommandWizard.indices(of: Self.defaultPlatforms, in: platformOptions) },
                allowsEmpty: false
            ),
            SingleSelectStep(
                id: "projectSystem",
                title: "Project system",
                prompt: "Project system",
                options: systems.map(\.displayName),
                defaultIndex: systems.firstIndex(of: .xcodeProj) ?? 0
            ),
            ValidatedStringStep(
                id: "primaryColor",
                title: "Primary color",
                prompt: "Primary color hex (e.g., #4CAF7D, #FF6B35)",
                staticDefault: Defaults.primaryColor,
                hint: "Must be #RRGGBB format",
                validator: Validators.validateHexColor
            ),
            NewCommandWizard.presetStep(for: .app),
            MultiSelectStep(
                id: "features",
                title: "Features",
                prompt: "Optional features (preset applied, modify as needed)",
                options: featureOptions.map(\.displayName),
                preselected: { NewCommandWizard.indices(of: NewCommandWizard.preset(in: $0).appFeatures(), in: featureOptions) },
                validate: { Self.persistenceProblem(Set($0.map { featureOptions[$0] })) }
            ),
            YesNoStep(
                id: "wantTabs",
                title: "Tab bar",
                prompt: "Add tab bar navigation?",
                defaultValue: false
            ),
            TabsStep(
                id: "tabs",
                title: "Tabs",
                prompt: "Tabs (e.g., Home:house, Settings:gearshape)",
                isVisible: { $0.bool("wantTabs") == true }
            ),
        ] + NewCommandWizard.endingSteps(defaultLicense: .defaultFor(.app)) { selected($0).contains(.licenseChangelog) } + [
            InfoStep(id: "usePackages", title: "Packages"),
            InfoStep(id: "externalPackages", title: "External packages"),
            InfoStep(id: "targetDeps", title: "Target dependencies"),
            InfoStep(id: "locales", title: "Locales"),
            InfoStep(id: "category", title: "App Store category"),
        ]

        try WizardEngine.run(title: "Monolith — New iOS App", steps: steps, state: &state)

        let platformIndices = state.intSet("platforms") ?? []
        let projectSystemIndex = state.int("projectSystem") ?? 0
        let ending = NewCommandWizard.ending(from: state, defaultLicense: .defaultFor(.app))
        let config = AppConfig(
            name: state.string("name") ?? "",
            bundleID: state.string("bundleID") ?? "",
            deploymentTarget: state.string("deploymentTarget") ?? Defaults.deploymentTarget,
            platforms: platformIndices.isEmpty ? Self.defaultPlatforms : Set(platformIndices.map { platformOptions[$0] }),
            projectSystem: systems.indices.contains(projectSystemIndex) ? systems[projectSystemIndex] : .xcodeProj,
            tabs: state.bool("wantTabs") == true ? state.tabDefinitions("tabs") ?? [] : [],
            primaryColor: state.string("primaryColor") ?? Defaults.primaryColor,
            features: flagFeatures ?? selected(state),
            author: ending.author,
            licenseType: ending.licenseType,
            externalPackages: flags.externalPackages ?? [],
            targetDependencies: flags.targetDependencies ?? [],
            locales: flags.locales ?? ["en"],
            applicationCategory: category
        )
        return ResolvedConfig(config: config, initGit: ending.initGit, openProject: ending.openProject, interactive: true)
    }

    /// Answers the steps the flags set.
    private func prefill(_ state: inout WizardState, flags: Flags, flagFeatures: Set<AppFeature>?, featureOptions: [AppFeature]) throws {
        if let name = common.name {
            try NewCommandOptions.checkName(name, kind: .app)
            state.fix("name", name)
        }
        NewCommandWizard.prefill(&state, from: common, featuresGiven: flagFeatures != nil)
        if let bundleID = flags.bundleID { state.fix("bundleID", bundleID) }
        if let target = flags.deploymentTarget { state.fix("deploymentTarget", target) }
        if let platforms = flags.platforms { state.fix("platforms", NewCommandWizard.indices(of: platforms, in: Platform.allCases)) }
        if let system = flags.projectSystem { state.fix("projectSystem", ProjectSystem.appOptions.firstIndex(of: system)) }
        if let color = flags.primaryColor { state.fix("primaryColor", color) }
        if let flagFeatures {
            if let problem = Self.persistenceProblem(flagFeatures) {
                throw ValidationError(problem)
            }
            state.fix("features", NewCommandWizard.indices(of: flagFeatures, in: featureOptions))
        }
        if let tabs = flags.tabs {
            state.fix("wantTabs", !tabs.isEmpty)
            state.fix("tabs", tabs)
        }
        let infoFlags: [(id: String, value: String?)] = [
            ("usePackages", usePackages), ("externalPackages", externalPackages), ("targetDeps", targetDeps),
            ("locales", flags.locales?.joined(separator: ", ")), ("category", category),
        ]
        for flag in infoFlags {
            if let value = flag.value { state.fix(flag.id, value) }
        }
    }

    /// Why `features` can't share one app, or nil: the wizard asks again
    /// instead of failing after the summary.
    static func persistenceProblem(_ features: Set<AppFeature>) -> String? {
        if features.contains(.swiftData), features.contains(.coreData) {
            return "SwiftData and Core Data can't both be selected: choose one persistence layer."
        }
        if features.contains(.swiftData), features.contains(.cloudKitSharing) {
            return "CloudKit Sharing needs Core Data; SwiftData has no shared-database support. Choose Core Data, or drop CloudKit Sharing."
        }
        return nil
    }
}
