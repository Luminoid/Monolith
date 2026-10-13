import ArgumentParser
import Foundation

struct NewPackageCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "package",
        abstract: "Create a new Swift Package."
    )

    @OptionGroup var common: NewCommandOptions

    @Option(
        name: .long,
        help: """
        Targets (comma-separated). Suffix a name with ':exec' to emit it as an \
        executable sibling instead of a library (e.g. 'MyLib,MyLibCore,my-tool:exec'). \
        Executable targets auto-depend on swift-argument-parser and skip the auto-generated Tests/ fixture.
        """
    )
    var targets: String?

    @Option(
        name: .long,
        help: "Target deps (target:dep1,dep2, semicolon-separated). Recognized externals: SnapKit, Lottie, LumiKit{Core,UI,Photo,Debug,Lottie}; declare others via --external-packages."
    )
    var targetDeps: String?

    @Option(name: .long, help: "Platforms (e.g., 'iOS 18.0,macOS 15.0')")
    var platforms: String?

    @Option(name: .long, help: FeatureFlagHelp.package, completion: FeatureFlagHelp.completion(PackageFeature.allCases))
    var features: String?

    @Option(
        name: .long,
        help: "Targets with defaultIsolation: MainActor (comma-separated; turns on the defaultIsolation feature, which alone picks the only library target)"
    )
    var mainActorTargets: String?

    @Option(
        name: .long,
        help: "Cross-cutting deps auto-merged into every target's dependencies (comma-separated). Resolves like --target-deps."
    )
    var packageDeps: String?

    @Option(
        name: .long,
        help: """
        Test-helper library targets (comma-separated). Generates a Swift Testing stub instead of the plain library placeholder, \
        and skips the auto-generated Tests/ fixture for the target. \
        For shared assertions / fixtures consumed by adopter test targets.
        """
    )
    var testHelperTargets: String?

    @Option(
        name: .long,
        help: "Per-target resource directories: 'Target:dir1,dir2;Target2:Resources'. Each listed target gets resources: [.process(\"dir\"), ...]."
    )
    var targetResources: String?

    @Option(
        name: .long,
        help: "External SPM packages: 'Name=url:requirement[:package];Name2=...'. requirement is verbatim, e.g. 'from: \"0.1.0\"' or 'branch: \"main\"'."
    )
    var externalPackages: String?

    func validate() throws {
        try common.validateLoadConfig(commandFlags: [
            ("--targets", targets != nil), ("--target-deps", targetDeps != nil), ("--platforms", platforms != nil),
            ("--features", features != nil), ("--main-actor-targets", mainActorTargets != nil), ("--package-deps", packageDeps != nil),
            ("--test-helper-targets", testHelperTargets != nil), ("--target-resources", targetResources != nil),
            ("--external-packages", externalPackages != nil),
        ])
        // Parsed here as well as in `run()`, so a bad value fails with this
        // subcommand's usage line instead of the root command's.
        if let name = common.name {
            try NewCommandOptions.checkName(name, kind: .package)
        }
        // The wizard asks for targets itself, so without --targets only a
        // non-interactive run knows the list `--target-deps` must match.
        if let targetList = targets ?? (common.noInteractive ? common.name : nil) {
            _ = try ValidationBridge.bridge { try TargetDefinition.parseList(targets: targetList, deps: targetDeps) }
        }
        _ = try parsedPlatformList()
        _ = try parsedFeatures()
        _ = try Self.parseTargetResources(targetResources)
        _ = try ValidationBridge.bridge { try ExternalPackage.parse(externalPackages) }
    }

    func run() throws {
        ShellRunner.isVerbose = common.verbose
        let resolved = try resolveConfig()
        let config = resolved.config

        var warnings: [String] = []
        if config.features.contains(.defaultIsolation), config.mainActorTargets.isEmpty {
            warnings.append("--features defaultIsolation was set but --main-actor-targets is empty; no target will get defaultIsolation(MainActor.self).")
        }

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
            warnings: warnings,
            projectSystem: .spm,
            printDryRun: { DryRunPlanner.printDryRun(config: config, outputDir: common.output) },
            generate: { try PackageProjectGenerator.generate(config: config, outputDir: common.output) }
        )
    }

    /// The config from `--load-config`, the flags (`--no-interactive`), or the wizard.
    func resolveConfig() throws -> ResolvedConfig<PackageConfig> {
        if let loaded = try common.loadedConfig(.package, section: \.package) {
            return loaded
        }
        if common.noInteractive {
            return try ResolvedConfig(config: buildNonInteractiveConfig(), initGit: common.git ?? false, openProject: false, interactive: false)
        }
        try NewCommandWizard.requireTerminal()
        return try promptForConfig()
    }

    // MARK: - Non-Interactive Config

    private func buildNonInteractiveConfig() throws -> PackageConfig {
        let name = try common.requiredName(kind: .package)
        let parsedTargets = try ValidationBridge.bridge { try TargetDefinition.parseList(targets: targets ?? name, deps: targetDeps) }
        let parsedPlatforms = try parsedPlatformList() ?? [PlatformVersion(platform: "iOS", version: Defaults.deploymentTarget)]
        var parsedFeatures = try parsedFeatures() ?? []
        if let preset = common.preset {
            parsedFeatures.formUnion(preset.packageFeatures())
        }
        let parsedTestHelperTargets = Set(CommaList.tokens(testHelperTargets))

        // defaultIsolation with no --main-actor-targets isolates the only
        // library target, as the wizard does, so `--preset full` needs no
        // extra flag. With several libraries there is no safe guess.
        var parsedMainActorTargets = Set(CommaList.tokens(mainActorTargets))
        if parsedFeatures.contains(.defaultIsolation), parsedMainActorTargets.isEmpty {
            parsedMainActorTargets = Self.defaultMainActorTargets(parsedTargets, testHelperTargets: parsedTestHelperTargets)
        }

        return try PackageConfig(
            name: name,
            platforms: parsedPlatforms,
            targets: parsedTargets,
            features: parsedFeatures,
            mainActorTargets: parsedMainActorTargets,
            author: GitRunner.authorNameOrPlaceholder(),
            licenseType: common.license ?? .defaultFor(.package),
            packageDeps: CommaList.tokens(packageDeps),
            testHelperTargets: parsedTestHelperTargets,
            targetResources: Self.parseTargetResources(targetResources),
            externalPackages: ValidationBridge.bridge { try ExternalPackage.parse(externalPackages) }
        )
    }

    /// `--platforms`, or nil when it wasn't passed.
    private func parsedPlatformList() throws -> [PlatformVersion]? {
        guard let platforms else { return nil }
        return try ValidationBridge.bridge { try PlatformVersion.parseList(platforms) }
    }

    /// `--features`, or nil when it wasn't passed.
    private func parsedFeatures() throws -> Set<PackageFeature>? {
        guard let features else { return nil }
        return try ValidationBridge.bridge { try PackageFeature.parseList(features) }
    }

    /// The library targets (not executables, not test helpers).
    static func libraryTargets(_ targets: [TargetDefinition], testHelperTargets: Set<String>) -> [TargetDefinition] {
        targets.filter { !$0.isExecutable && !testHelperTargets.contains($0.name) }
    }

    /// The MainActor targets defaultIsolation gets without an explicit list:
    /// the only library target, or none when there are several.
    static func defaultMainActorTargets(_ targets: [TargetDefinition], testHelperTargets: Set<String>) -> Set<String> {
        let libraries = libraryTargets(targets, testHelperTargets: testHelperTargets)
        return libraries.count == 1 ? [libraries[0].name] : []
    }

    // MARK: - Interactive Config

    /// The wizard. Steps a flag answers are skipped and shown on the summary.
    func promptForConfig() throws -> ResolvedConfig<PackageConfig> {
        let flagFeatures = try parsedFeatures().map { $0.union(common.preset?.packageFeatures() ?? []) }
        let featureOptions = PackageFeature.allCases.filter { $0 != .strictConcurrency }
        let selected = { (state: WizardState) in Set((state.intSet("features") ?? []).map { featureOptions[$0] }) }
        let testHelpers = Set(CommaList.tokens(testHelperTargets))
        let libraries = { (state: WizardState) in Self.libraryTargets(Self.wizardTargets(state), testHelperTargets: testHelpers) }

        var state = WizardState()
        try prefill(&state, featureOptions: featureOptions, flagFeatures: flagFeatures)

        let steps: [any WizardStep] = [
            ValidatedStringStep(
                id: "name",
                title: "Package name",
                prompt: "Package name (e.g., MyPackage)",
                hint: Validators.projectNameRule(for: .package),
                validator: { Validators.validateProjectName($0, kind: .package) }
            ),
            Self.platformsStep(),
            StringStep(
                id: "targets",
                title: "Targets",
                prompt: "Targets (comma-separated, e.g., MyCore, MyUI, my-tool:exec)",
                defaultValue: { $0.string("name") ?? "" }
            ),
            Self.targetDepsStep(),
            NewCommandWizard.presetStep(for: .package),
            MultiSelectStep(
                id: "features",
                title: "Features",
                prompt: "Optional features (preset applied, modify as needed)",
                options: featureOptions.map(\.displayName),
                preselected: { NewCommandWizard.indices(of: NewCommandWizard.preset(in: $0).packageFeatures(), in: featureOptions) }
            ),
            StringStep(
                id: "mainActorTargets",
                title: "MainActor targets",
                prompt: "MainActor targets (comma-separated)",
                defaultValue: { libraries($0).last?.name ?? "" },
                isVisible: { selected($0).contains(.defaultIsolation) && libraries($0).count > 1 }
            ),
        ] + NewCommandWizard.endingSteps(defaultLicense: .defaultFor(.package)) { selected($0).contains(.licenseChangelog) } + [
            InfoStep(id: "packageDeps", title: "Package deps"),
            InfoStep(id: "testHelperTargets", title: "Test-helper targets"),
            InfoStep(id: "targetResources", title: "Target resources"),
            InfoStep(id: "externalPackages", title: "External packages"),
        ]

        try WizardEngine.run(title: "Monolith — New Swift Package", steps: steps, state: &state)

        let features = flagFeatures ?? selected(state)
        let targetDefinitions = Self.wizardTargets(state)
        var mainActor = Set(CommaList.tokens(mainActorTargets ?? state.string("mainActorTargets")))
        if mainActorTargets == nil {
            if !features.contains(.defaultIsolation) {
                mainActor = []
            } else if libraries(state).count <= 1 {
                mainActor = Self.defaultMainActorTargets(targetDefinitions, testHelperTargets: testHelpers)
            }
        }

        let ending = NewCommandWizard.ending(from: state, defaultLicense: .defaultFor(.package))
        let config = try PackageConfig(
            name: state.string("name") ?? "",
            platforms: state.platformVersions("platforms") ?? [PlatformVersion(platform: "iOS", version: Defaults.deploymentTarget)],
            targets: targetDefinitions,
            features: features,
            mainActorTargets: mainActor,
            author: ending.author,
            licenseType: ending.licenseType,
            packageDeps: CommaList.tokens(packageDeps),
            testHelperTargets: testHelpers,
            targetResources: Self.parseTargetResources(targetResources),
            externalPackages: ValidationBridge.bridge { try ExternalPackage.parse(externalPackages) }
        )
        return ResolvedConfig(config: config, initGit: ending.initGit, openProject: ending.openProject, interactive: true)
    }

    /// Answers the steps the flags set, after checking every flag value.
    private func prefill(_ state: inout WizardState, featureOptions: [PackageFeature], flagFeatures: Set<PackageFeature>?) throws {
        if let name = common.name {
            try NewCommandOptions.checkName(name, kind: .package)
            state.fix("name", name)
        }
        NewCommandWizard.prefill(&state, from: common, featuresGiven: flagFeatures != nil)
        if let platforms = try parsedPlatformList() {
            state.fix("platforms", platforms)
        }
        if let targets {
            state.fix("targets", targets)
            if let targetDeps {
                try state.fix("targetDeps", ValidationBridge.bridge { try TargetDefinition.parseList(targets: targets, deps: targetDeps) })
            }
        } else if targetDeps != nil {
            throw ValidationError("--target-deps needs --targets in the wizard, which asks for the targets otherwise. Pass both, or neither.")
        }
        if let flagFeatures {
            state.fix("features", NewCommandWizard.indices(of: flagFeatures, in: featureOptions))
        }
        if let mainActorTargets {
            state.fix("mainActorTargets", mainActorTargets)
        }
        // Checked now, so a bad value fails before the wizard instead of after it.
        _ = try Self.parseTargetResources(targetResources)
        _ = try ValidationBridge.bridge { try ExternalPackage.parse(externalPackages) }
        let infoFlags: [(id: String, value: String?)] = [
            ("packageDeps", packageDeps), ("testHelperTargets", testHelperTargets),
            ("targetResources", targetResources), ("externalPackages", externalPackages),
        ]
        for flag in infoFlags {
            if let value = flag.value { state.fix(flag.id, value) }
        }
    }

    /// The targets the wizard's targets step names (`:exec` marks an
    /// executable), with the dependencies its target-deps step gave them.
    static func wizardTargets(_ state: WizardState) -> [TargetDefinition] {
        let targets = (try? TargetDefinition.parseList(targets: state.string("targets") ?? state.string("name") ?? "", deps: nil)) ?? []
        let deps = Dictionary((state.targetDefinitions("targetDeps") ?? []).map { ($0.name, $0.dependencies) }) { first, _ in first }
        return targets.map { TargetDefinition(name: $0.name, dependencies: deps[$0.name] ?? [], isExecutable: $0.isExecutable) }
    }

    /// Choose platforms (Enter keeps the marked ones, iOS at first), then a
    /// version for each.
    private static func platformsStep() -> CustomStep {
        CustomStep(
            id: "platforms",
            title: "Platforms",
            execute: { state in
                let allPlatforms = PackagePlatform.allCases
                let previous = state.platformVersions("platforms") ?? []
                var current = Set(previous.compactMap { version in allPlatforms.firstIndex { $0.platformName == version.platform } })
                if current.isEmpty, let iOS = allPlatforms.firstIndex(of: .iOS) {
                    current = [iOS]
                }

                let selection = try PromptEngine.wizardMultiSelect(
                    prompt: "Target platforms",
                    options: allPlatforms.map(\.displayName),
                    current: current,
                    allowsEmpty: false
                )
                guard case let .value(indices) = selection else { return .back }

                var platformVersions: [PlatformVersion] = []
                for platform in indices.sorted().map({ allPlatforms[$0] }) {
                    let versionResult = try PromptEngine.wizardValidatedString(
                        prompt: "\(platform.displayName) version",
                        default: previous.first { $0.platform == platform.platformName }?.version ?? platform.defaultVersion,
                        hint: "Must be major.minor format (e.g., 18.0)",
                        validator: Validators.validatePlatformVersion
                    )
                    guard case let .value(version) = versionResult else { return .back }
                    platformVersions.append(PlatformVersion(platform: platform.platformName, version: version))
                }

                state.values["platforms"] = platformVersions
                return .next
            },
            summaryValue: { state in
                state.platformVersions("platforms")?.map { "\($0.platform) \($0.version)" }.joined(separator: ", ")
            }
        )
    }

    /// Each target's dependencies, asked one target at a time when there are several.
    private static func targetDepsStep() -> CustomStep {
        CustomStep(
            id: "targetDeps",
            title: "Target dependencies",
            isVisible: { wizardTargets($0).count > 1 },
            execute: { state in
                let targets = wizardTargets(state)
                PromptEngine.line("  Target dependencies (e.g., OtherTarget, SnapKit):")
                var definitions: [TargetDefinition] = []
                for target in targets {
                    let current = target.dependencies.joined(separator: ", ")
                    let result = try PromptEngine.wizardString(prompt: "  \(target.name) deps", default: current.isEmpty ? nil : current)
                    guard case let .value(answer) = result else { return .back }
                    definitions.append(TargetDefinition(name: target.name, dependencies: CommaList.tokens(answer)))
                }
                state.values["targetDeps"] = definitions
                return .next
            },
            summaryValue: { state in
                guard let definitions = state.targetDefinitions("targetDeps") else { return nil }
                let withDeps = definitions.filter { !$0.dependencies.isEmpty }
                if withDeps.isEmpty { return "None" }
                return withDeps.map { "\($0.name): \($0.dependencies.joined(separator: ", "))" }.joined(separator: "; ")
            }
        )
    }

    // MARK: - Parsing

    /// Parse `--target-resources "Target:dir1,dir2;Target2:Resources"`.
    static func parseTargetResources(_ input: String?) throws -> [String: [String]] {
        guard let input, !input.isEmpty else { return [:] }
        var out: [String: [String]] = [:]
        for entry in input.split(separator: ";") {
            let parts = entry.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else {
                throw ValidationError("Invalid --target-resources entry '\(entry)'. Expected 'Target:dir1,dir2'.")
            }
            let target = parts[0].trimmingCharacters(in: .whitespaces)
            out[target] = CommaList.tokens(String(parts[1]))
        }
        return out
    }
}
