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

    @Option(name: .long, help: "Project system: xcodeproj (default) or xcodegen")
    var projectSystem: String?

    @Option(name: .long, help: "Primary color hex (e.g., #007AFF)")
    var primaryColor: String?

    // swiftformat:disable all
    // swiftlint:disable:next line_length
    @Option(name: .long, help: "Features (comma-separated): swiftData, lumiKit, snapKit, lottie, lookin (iOS only), darkMode, combine, localization, devTooling, gitHooks, claudeMD, licenseChangelog, rSwift (XcodeGen only), fastlane (XcodeGen only)")
    var features: String?
    // swiftformat:enable all

    @Option(name: .long, help: "Tabs (format: Name:icon,Name:icon)")
    var tabs: String?

    @Option(name: .long, help: "Feature preset: minimal, standard, full")
    var preset: String?

    @Option(name: .long, help: "License type: mit, apache2, proprietary (default: proprietary for apps)")
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

    // swiftformat:disable all
    // swiftlint:disable:next line_length
    @Option(name: .long, help: "Built-in third-party packages (comma-separated). Identifiers come from the KnownPackages registry. Optional `:version` overrides the registry default. Example: --use-packages 'SnapKit,LookinServer:1.3.0'")
    var usePackages: String?

    // swiftlint:disable:next line_length
    @Option(name: .long, help: "Third-party SPM packages outside the built-in registry (format: \"Name=url:requirement[:packageName];...\"). Each declared entry MUST also appear in --target-deps. Example: --external-packages 'Prism=https://github.com/luminoid/Prism:from \"0.3.0\"'")
    var externalPackages: String?

    // swiftlint:disable:next line_length
    @Option(name: .long, help: "Products to link into the app target (comma-separated). Each name must resolve to a built-in (auto-added when --features or --use-packages requests it) or an --external-packages entry. Example: --target-deps 'PrismCore,PrismUI'")
    var targetDeps: String?
    // swiftformat:enable all

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
                to: saveConfig
            )
        }

        for warning in config.deprecationWarnings {
            FileHandle.standardError.write(Data("\(warning)\n".utf8))
        }

        // `strictConcurrency` is accepted in AppFeature for symmetry with the
        // package/cli surfaces, but at swift-tools-version 6.2 strict
        // concurrency is the language default — the flag has no effect on
        // generated output. Warn so the user knows the flag was acknowledged
        // (vs. silently dropped) and stops passing it.
        if config.features.contains(.strictConcurrency) {
            FileHandle.standardError
                .write(
                    Data("warning: --features strictConcurrency is a no-op at swift-tools-version 6.2 (strict concurrency is the language default).\n"
                        .utf8)
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

        let basePath = FileWriter.resolveOutputPath(projectName: config.name, outputDir: output)
        // If the directory didn't exist before generation, a Ctrl-C mid-write
        // should remove the partial output. If it existed and we got here via
        // --force, leave it alone to avoid blowing away unrelated content.
        let preexisting = FileManager.default.fileExists(atPath: basePath)
        if !preexisting {
            SignalHandler.install(cleanup: { SignalHandler.removePartialOutput(at: basePath) })
        }

        try AppProjectGenerator.generate(config: config, outputDir: output)

        if initGit {
            FileWriter.gitInit(at: basePath, hasGitHooks: config.hasGitHooks)
        }

        if shouldResolve {
            PackageResolver.resolve(at: basePath, projectSystem: config.projectSystem)
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
            if Validators.reservedNames.contains(name) {
                throw ValidationError("Invalid project name '\(name)' — '\(name)' is a Swift reserved word and would produce code that doesn't compile.")
            }
            throw ValidationError("Invalid project name '\(name)'. Must start with a letter, contain only alphanumerics/hyphens/underscores, max \(Validators.maxProjectNameLength) chars.")
        }
        let resolvedBundleID = bundleID ?? Validators.defaultBundleID(for: name)
        guard Validators.validateBundleID(resolvedBundleID) else {
            throw ValidationError("Invalid bundle ID '\(resolvedBundleID)'. Must be reverse-DNS format (e.g., com.company.app).")
        }
        let resolvedTarget = deploymentTarget ?? Defaults.deploymentTarget
        guard Validators.validateDeploymentTarget(resolvedTarget) else {
            throw ValidationError("Invalid deployment target '\(resolvedTarget)'. Must be major.minor format >= 18.0.")
        }
        let resolvedColor = primaryColor ?? Defaults.primaryColor
        guard Validators.validateHexColor(resolvedColor) else {
            throw ValidationError("Invalid hex color '\(resolvedColor)'. Must be #RRGGBB format.")
        }

        let parsedPlatforms = parsePlatforms(platforms ?? Defaults.defaultPlatform)
        let parsedProjectSystem = parseProjectSystem(projectSystem ?? "xcodeproj")
        // Backwards-compat shim (detection): identify any `--features` tokens
        // that used to be AppFeature cases but moved into the KnownPackages
        // registry. Filter them OUT of the string passed to parseFeatures so
        // the "unrecognized feature" warning doesn't fire for them — they're
        // not unrecognized, they're moved. Removed in v0.4.
        let rawFeatureTokens = (features ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let deprecatedFeatures = rawFeatureTokens.filter { AppFeature.deprecatedPackageFeatureNames.contains($0) }
        let cleanedFeaturesInput: String? = if deprecatedFeatures.isEmpty {
            features
        } else {
            rawFeatureTokens.filter { !AppFeature.deprecatedPackageFeatureNames.contains($0) }.joined(separator: ",")
        }
        var parsedFeatures: Set<AppFeature> = PromptEngine.parseFeatures(cleanedFeaturesInput)

        if let preset {
            guard let resolvedPreset = Preset(rawValue: preset) else {
                throw ValidationError("Unknown preset '\(preset)'. Valid: minimal, standard, full")
            }
            parsedFeatures = parsedFeatures.union(resolvedPreset.appFeatures(projectSystem: parsedProjectSystem))
        }

        let parsedTabs = PromptEngine.parseTabs(tabs ?? "")
        let author = FileWriter.gitAuthorName() ?? "Author"

        var parsedLicenseType: LicenseType = .proprietary
        if let license {
            guard let lt = LicenseType(rawValue: license) else {
                throw ValidationError("Unknown license '\(license)'. Valid: \(LicenseType.allCases.map(\.rawValue).joined(separator: ", "))")
            }
            parsedLicenseType = lt
        }

        // Backwards-compat shim (translation): emit the deprecation warning
        // and synthesize the equivalent --use-packages identifiers so the
        // downstream parseUsePackages call picks them up.
        var deprecationUsePackagesAddition = ""
        if !deprecatedFeatures.isEmpty {
            // Map known feature aliases to registry identifiers.
            let aliasMap: [String: String] = ["snapKit": "SnapKit", "lookin": "LookinServer"]
            let registryIdentifiers = deprecatedFeatures.compactMap { aliasMap[$0] }
            deprecationUsePackagesAddition = registryIdentifiers.joined(separator: ",")
            FileHandle.standardError.write(Data("""
            warning: --features \(deprecatedFeatures.joined(separator: ", ")) is deprecated. \
            These packages moved out of --features into the --use-packages registry. \
            Use: --use-packages '\(registryIdentifiers.joined(separator: ","))'. \
            Continuing with auto-translated equivalent. Will be removed in v0.4.

            """.utf8))
        }

        // Parse --use-packages, merging in any deprecation-shimmed identifiers.
        let usePackagesInput = [usePackages, deprecationUsePackagesAddition.isEmpty ? nil : deprecationUsePackagesAddition]
            .compactMap(\.self)
            .filter { !$0.isEmpty }
            .joined(separator: ",")
        let registryExternals: [ExternalPackage]
        do {
            registryExternals = try ExternalPackage.parseUsePackages(usePackagesInput.isEmpty ? nil : usePackagesInput)
        } catch {
            throw ValidationError(error.description)
        }

        // Parse --external-packages (URL-form / path-form entries outside the registry).
        let rawExternalPackages: [ExternalPackage]
        do {
            rawExternalPackages = try ExternalPackage.parse(externalPackages)
        } catch {
            throw ValidationError(error.description)
        }
        let parsedExternalPackages = registryExternals + rawExternalPackages

        // Compute target-deps. The deprecation shim also auto-appends the
        // product names so the user doesn't need to also pass --target-deps.
        var parsedTargetDeps: [String] = (targetDeps ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        for ext in registryExternals where !parsedTargetDeps.contains(ext.name) {
            parsedTargetDeps.append(ext.name)
        }

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
            licenseType: parsedLicenseType,
            externalPackages: parsedExternalPackages,
            targetDependencies: parsedTargetDeps
        )

        do {
            try config.validate()
        } catch {
            throw ValidationError(error.description)
        }

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
                hint: "Must start with a letter, alphanumeric/hyphens/underscores, max \(Validators.maxProjectNameLength) chars",
                validator: Validators.validateProjectName
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
                prompt: "Target platforms (select at least one, or press Enter for iPhone)",
                options: Platform.allCases.map(\.displayName)
            ),
            SingleSelectStep(
                id: "projectSystem",
                title: "Project system",
                prompt: "Project system",
                options: ProjectSystem.appOptions.map(\.displayName),
                defaultIndex: ProjectSystem.appOptions.firstIndex(of: .xcodeProj) ?? 0
            ),
            ValidatedStringStep(
                id: "primaryColor",
                title: "Primary color",
                prompt: "Primary color hex (e.g., #4CAF7D, #FF6B35)",
                staticDefault: Defaults.primaryColor,
                hint: "Must be #RRGGBB format",
                validator: Validators.validateHexColor
            ),
            SingleSelectStep(
                id: "preset",
                title: "Preset",
                prompt: "Feature preset",
                options: Preset.allCases.map(\.displayName),
                defaultIndex: 1
            ),
            MultiSelectStep(
                id: "features",
                title: "Features",
                prompt: "Optional features (preset applied, modify as needed)",
                options: featureOptions.map(\.displayName),
                preselected: { state in
                    let presetIndex = state.int("preset") ?? 1
                    let presetCase = presetIndex < Preset.allCases.count ? Preset.allCases[presetIndex] : .standard
                    let appSystems = ProjectSystem.appOptions
                    let systemIndex = state.int("projectSystem") ?? 0
                    let system = systemIndex < appSystems.count ? appSystems[systemIndex] : .xcodeProj
                    let presetFeatures = presetCase.appFeatures(projectSystem: system)
                    return Set(featureOptions.enumerated().compactMap { index, feature in
                        presetFeatures.contains(feature) ? index : nil
                    })
                }
            ),
            SingleSelectStep(
                id: "licenseType",
                title: "License type",
                prompt: "License type",
                options: LicenseType.allCases.map { "\($0.displayName) \u{2014} \($0.shortDescription)" },
                defaultIndex: LicenseType.allCases.firstIndex(of: .proprietary) ?? 2,
                isVisible: { state in
                    let selectedIndices = state.intSet("features") ?? []
                    let selectedFeatures = Set(selectedIndices.map { featureOptions[$0] })
                    return selectedFeatures.contains(.licenseChangelog)
                }
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

        let appSystems = ProjectSystem.appOptions
        let projectSystemIndex = state.int("projectSystem") ?? 0
        let parsedProjectSystem = projectSystemIndex < appSystems.count
            ? appSystems[projectSystemIndex]
            : .xcodeProj

        let selectedIndices = state.intSet("features") ?? []
        let selectedFeatures = Set(selectedIndices.map { featureOptions[$0] })

        let parsedTabs = state.tabDefinitions("tabs") ?? []

        let licenseTypeIndex = state.int("licenseType") ?? LicenseType.allCases.firstIndex(of: .proprietary) ?? 2
        let licenseType = licenseTypeIndex < LicenseType.allCases.count
            ? LicenseType.allCases[licenseTypeIndex]
            : .proprietary

        let config = AppConfig(
            name: state.string("name") ?? "",
            bundleID: state.string("bundleID") ?? "",
            deploymentTarget: state.string("deploymentTarget") ?? Defaults.deploymentTarget,
            platforms: parsedPlatforms,
            projectSystem: parsedProjectSystem,
            tabs: parsedTabs,
            primaryColor: state.string("primaryColor") ?? Defaults.primaryColor,
            features: selectedFeatures,
            author: state.string("author") ?? "Author",
            licenseType: licenseType
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
                    Data("warning: unrecognized platform '\(name)' (valid: iPhone, iPad, macCatalyst)\n".utf8)
                )
            }
        }
        if result.isEmpty { result.insert(.iPhone) }
        return result
    }

    private func parseProjectSystem(_ input: String) -> ProjectSystem {
        switch input.lowercased() {
        case "xcodeproj", "xcode":
            return .xcodeProj
        case "xcodegen":
            return .xcodeGen
        case "spm":
            // Backward compatibility: treat spm as xcodeproj
            return .xcodeProj
        default:
            FileHandle.standardError.write(
                Data("warning: unrecognized project system '\(input)' (valid: xcodeproj, xcodegen), defaulting to xcodeproj\n".utf8)
            )
            return .xcodeProj
        }
    }
}
