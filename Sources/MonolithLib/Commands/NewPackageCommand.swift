import ArgumentParser
import Foundation

struct NewPackageCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "package",
        abstract: "Create a new Swift Package.",
    )

    @Option(name: .long, help: "Package name")
    var name: String?

    @Option(name: .long, help: "Targets (comma-separated)")
    var targets: String?

    @Option(name: .long, help: "Target dependencies (target:dep1,dep2 format, semicolon-separated)")
    var targetDeps: String?

    @Option(name: .long, help: "Platforms (e.g., 'iOS 18.0,macOS 15.0')")
    var platforms: String?

    @Option(name: .long, help: "Features (comma-separated): strictConcurrency, defaultIsolation, devTooling, gitHooks, claudeMD, licenseChangelog")
    var features: String?

    @Option(name: .long, help: "Targets with defaultIsolation: MainActor (comma-separated)")
    var mainActorTargets: String?

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
        var config: PackageConfig
        var initGit: Bool
        var shouldOpen = open
        var shouldResolve = resolve

        if let loadConfig {
            let loaded = try ConfigFile.load(from: loadConfig)
            guard let pkgConfig = loaded.package else {
                throw ValidationError("Config file does not contain a package config.")
            }
            config = pkgConfig
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
                ConfigFile.MonolithConfig(projectType: .package, app: nil, package: config, cli: nil, initGit: initGit),
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

        try PackageProjectGenerator.generate(config: config, outputDir: output)

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

    private func buildNonInteractiveConfig() throws -> (PackageConfig, Bool) {
        guard let name else {
            throw ValidationError("--name is required in non-interactive mode")
        }
        guard Validators.validateProjectName(name) else {
            throw ValidationError("Invalid package name '\(name)'. Must start with a letter, contain only alphanumerics/hyphens/underscores, max \(Validators.maxProjectNameLength) chars.")
        }

        let parsedTargets = parseTargets(targets ?? name, deps: targetDeps)
        let parsedPlatforms = parsePlatforms(platforms ?? "iOS 18.0")
        var parsedFeatures: Set<PackageFeature> = PromptEngine.parseFeatures(features)

        if let preset {
            guard let resolvedPreset = Preset(rawValue: preset) else {
                throw ValidationError("Unknown preset '\(preset)'. Valid: minimal, standard, full")
            }
            parsedFeatures = parsedFeatures.union(resolvedPreset.packageFeatures())
        }

        let parsedMainActorTargets = parseCommaSeparated(mainActorTargets)
        let author = FileWriter.gitAuthorName() ?? "Author"

        let config = PackageConfig(
            name: name,
            platforms: parsedPlatforms,
            targets: parsedTargets,
            features: parsedFeatures,
            mainActorTargets: parsedMainActorTargets,
            author: author,
        )
        return (config, git)
    }

    // MARK: - Interactive Config

    private func promptForConfig() -> (config: PackageConfig, initGit: Bool, openProject: Bool, resolvePackages: Bool) {
        var state = WizardState()

        // Pre-fill author from git
        if let gitAuthor = FileWriter.gitAuthorName() {
            state.values["author"] = gitAuthor
        }

        let featureOptions = PackageFeature.allCases

        let steps: [any WizardStep] = [
            ValidatedStringStep(
                id: "name",
                title: "Package name",
                prompt: "Package name (e.g., MyPackage)",
                hint: "Must start with a letter, alphanumeric/hyphens/underscores, max \(Validators.maxProjectNameLength) chars",
                validator: Validators.validateProjectName,
            ),
            CustomStep(
                id: "platforms",
                title: "Platforms",
                execute: { state in
                    let allPlatforms = PackagePlatform.allCases

                    let selectResult = PromptEngine.wizardMultiSelect(
                        prompt: "Target platforms (select at least one, or press Enter for iOS)",
                        options: allPlatforms.map(\.displayName),
                    )

                    switch selectResult {
                    case .back:
                        return .back
                    case let .value(indices):
                        let selected: [PackagePlatform] = if indices.isEmpty {
                            [.iOS]
                        } else {
                            indices.sorted().compactMap { idx in
                                idx < allPlatforms.count ? allPlatforms[idx] : nil
                            }
                        }

                        var platformVersions: [PlatformVersion] = []
                        for platform in selected {
                            let versionResult = PromptEngine.wizardValidatedString(
                                prompt: "\(platform.displayName) version",
                                default: platform.defaultVersion,
                                hint: "Must be major.minor format (e.g., 18.0)",
                                validator: Validators.validatePlatformVersion,
                            )
                            switch versionResult {
                            case .back:
                                return .back
                            case let .value(version):
                                platformVersions.append(PlatformVersion(
                                    platform: platform.platformName,
                                    version: version,
                                ))
                            }
                        }

                        state.values["platforms"] = platformVersions
                        return .next
                    }
                },
                summaryValue: { state in
                    guard let pvs = state.platformVersions("platforms") else { return nil }
                    if pvs.isEmpty { return "iOS 18.0" }
                    return pvs.map { "\($0.platform) \($0.version)" }.joined(separator: ", ")
                },
            ),
            StringStep(
                id: "targets",
                title: "Targets",
                prompt: "Targets (comma-separated, e.g., MyCore, MyUI)",
                defaultValue: { $0.string("name") ?? "" },
            ),
            CustomStep(
                id: "targetDeps",
                title: "Target dependencies",
                isVisible: { state in
                    let targets = state.string("targets") ?? ""
                    let names = targets.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    return names.count > 1
                },
                execute: { state in
                    let targets = state.string("targets") ?? ""
                    let names = targets.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

                    print("  Target dependencies (e.g., OtherTarget, SnapKit):")
                    var defs: [TargetDefinition] = []
                    for name in names {
                        let result = PromptEngine.wizardString(prompt: "  \(name) deps", default: "")
                        switch result {
                        case .back:
                            return .back
                        case let .value(depsStr):
                            let deps = depsStr.isEmpty ? [] : depsStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                            defs.append(TargetDefinition(name: name, dependencies: deps))
                        }
                    }
                    state.values["targetDeps"] = defs
                    return .next
                },
                summaryValue: { state in
                    guard let defs = state.targetDefinitions("targetDeps") else { return nil }
                    let withDeps = defs.filter { !$0.dependencies.isEmpty }
                    if withDeps.isEmpty { return "None" }
                    return withDeps.map { "\($0.name): \($0.dependencies.joined(separator: ", "))" }.joined(separator: "; ")
                },
            ),
            MultiSelectStep(
                id: "features",
                title: "Features",
                prompt: "Optional features",
                options: featureOptions.map(\.displayName),
            ),
            StringStep(
                id: "mainActorTargets",
                title: "MainActor targets",
                prompt: "MainActor targets (comma-separated)",
                defaultValue: { state in
                    let targets = state.string("targets") ?? ""
                    let names = targets.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    return names.last ?? "MyUI"
                },
                isVisible: { state in
                    let selectedIndices = state.intSet("features") ?? []
                    let selectedFeatures = Set(selectedIndices.map { featureOptions[$0] })
                    let targets = state.string("targets") ?? ""
                    let names = targets.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    return selectedFeatures.contains(.defaultIsolation) && names.count > 1
                },
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

        WizardEngine.run(title: "Monolith \u{2014} New Swift Package", steps: steps, state: &state)

        // Assemble config
        let parsedPlatforms = state.platformVersions("platforms")
            ?? [PlatformVersion(platform: "iOS", version: "18.0")]

        let targetStr = state.string("targets") ?? state.string("name") ?? ""
        let targetNames = targetStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        let targetDefs: [TargetDefinition] = if targetNames.count > 1, let customDefs = state.targetDefinitions("targetDeps") {
            customDefs
        } else {
            targetNames.map { TargetDefinition(name: $0, dependencies: []) }
        }

        let selectedIndices = state.intSet("features") ?? []
        let selectedFeatures = Set(selectedIndices.map { featureOptions[$0] })

        var mainActorTargetSet = Set<String>()
        if selectedFeatures.contains(.defaultIsolation) {
            if targetNames.count > 1 {
                mainActorTargetSet = parseCommaSeparated(state.string("mainActorTargets"))
            } else {
                mainActorTargetSet = Set(targetNames)
            }
        }

        let config = PackageConfig(
            name: state.string("name") ?? "",
            platforms: parsedPlatforms,
            targets: targetDefs,
            features: selectedFeatures,
            mainActorTargets: mainActorTargetSet,
            author: state.string("author") ?? "Author",
        )
        let initGit = state.bool("initGit") ?? false
        let openProject = state.bool("openProject") ?? false

        return (config, initGit, openProject, false)
    }

    // MARK: - Parsing

    private func parseTargets(_ input: String, deps: String?) -> [TargetDefinition] {
        let names = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        var depMap: [String: [String]] = [:]
        if let deps {
            for entry in deps.split(separator: ";") {
                let parts = entry.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let target = parts[0].trimmingCharacters(in: .whitespaces)
                    let targetDeps = parts[1].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    depMap[target] = targetDeps
                }
            }
        }

        return names.map { name in
            TargetDefinition(name: name, dependencies: depMap[name] ?? [])
        }
    }

    private func parsePlatforms(_ input: String) -> [PlatformVersion] {
        input.split(separator: ",").compactMap { segment in
            let parts = segment.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            return PlatformVersion(
                platform: String(parts[0]),
                version: String(parts[1]),
            )
        }
    }

    private func parseCommaSeparated(_ input: String?) -> Set<String> {
        guard let input, !input.isEmpty else { return [] }
        return Set(input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
    }
}
