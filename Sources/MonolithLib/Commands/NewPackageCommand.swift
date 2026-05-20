import ArgumentParser
import Foundation

struct NewPackageCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "package",
        abstract: "Create a new Swift Package."
    )

    @Option(name: .long, help: "Package name")
    var name: String?

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
        help: "Target deps (target:dep1,dep2, semicolon-separated). Recognized externals: SnapKit, Lottie, LumiKit{Core,UI,Lottie,Network}; declare others via --external-packages."
    )
    var targetDeps: String?

    @Option(name: .long, help: "Platforms (e.g., 'iOS 18.0,macOS 15.0')")
    var platforms: String?

    @Option(name: .long, help: "Features (comma-separated): strictConcurrency, defaultIsolation, devTooling, gitHooks, claudeMD, licenseChangelog")
    var features: String?

    @Option(name: .long, help: "Targets with defaultIsolation: MainActor (comma-separated)")
    var mainActorTargets: String?

    @Option(
        name: .long,
        help: "Cross-cutting deps auto-merged into every target's dependencies (comma-separated). Resolves like --target-deps."
    )
    var packageDeps: String?

    @Option(
        name: .long,
        help: "Targets that should link XCTest as a system framework (comma-separated). For test-utility libraries imported by adopter test targets."
    )
    var xctestTargets: String?

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

    @Option(name: .long, help: "Feature preset: minimal, standard, full")
    var preset: String?

    @Option(name: .long, help: "License type: mit, apache2, proprietary (default: mit for packages)")
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

        do {
            try config.validate()
        } catch let error as PackageConfigError {
            throw ValidationError(error.description)
        }

        if config.features.contains(.defaultIsolation), config.mainActorTargets.isEmpty {
            FileHandle.standardError.write(Data("warning: --features defaultIsolation was set but --main-actor-targets is empty; no target will get defaultIsolation(MainActor.self).\n".utf8))
        }

        if config.features.contains(.strictConcurrency) {
            FileHandle.standardError
                .write(
                    Data("warning: --features strictConcurrency is a no-op at swift-tools-version 6.2 (strict concurrency is the language default).\n"
                        .utf8)
                )
        }

        if let saveConfig {
            try ConfigFile.save(
                ConfigFile.MonolithConfig(projectType: .package, app: nil, package: config, cli: nil, initGit: initGit),
                to: saveConfig
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
        let preexisting = FileManager.default.fileExists(atPath: basePath)
        if !preexisting {
            SignalHandler.install(cleanup: { SignalHandler.removePartialOutput(at: basePath) })
        }

        try PackageProjectGenerator.generate(config: config, outputDir: output)

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
            if Validators.reservedNames.contains(name) {
                throw ValidationError("Invalid package name '\(name)' — '\(name)' is a Swift reserved word and would produce code that doesn't compile.")
            }
            throw ValidationError("Invalid package name '\(name)'. Must start with a letter, contain only alphanumerics/hyphens/underscores, max \(Validators.maxProjectNameLength) chars.")
        }

        let parsedTargets = parseTargets(targets ?? name, deps: targetDeps)
        let parsedPlatforms = try parsePlatforms(platforms ?? "iOS \(Defaults.deploymentTarget)")
        var parsedFeatures: Set<PackageFeature> = PromptEngine.parseFeatures(features)

        if let preset {
            guard let resolvedPreset = Preset(rawValue: preset) else {
                throw ValidationError("Unknown preset '\(preset)'. Valid: minimal, standard, full")
            }
            parsedFeatures = parsedFeatures.union(resolvedPreset.packageFeatures())
        }

        let parsedMainActorTargets = parseCommaSeparated(mainActorTargets)
        let parsedPackageDeps = packageDeps.map { $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } } ?? []
        let parsedXCTestTargets = parseCommaSeparated(xctestTargets)
        let parsedTargetResources = try parseTargetResources(targetResources)
        let parsedExternalPackages = try parseExternalPackages(externalPackages)
        let author = FileWriter.gitAuthorName() ?? "Author"

        var parsedLicenseType: LicenseType = .mit
        if let license {
            guard let lt = LicenseType(rawValue: license) else {
                throw ValidationError("Unknown license '\(license)'. Valid: \(LicenseType.allCases.map(\.rawValue).joined(separator: ", "))")
            }
            parsedLicenseType = lt
        }

        let config = PackageConfig(
            name: name,
            platforms: parsedPlatforms,
            targets: parsedTargets,
            features: parsedFeatures,
            mainActorTargets: parsedMainActorTargets,
            author: author,
            licenseType: parsedLicenseType,
            packageDeps: parsedPackageDeps,
            xctestTargets: parsedXCTestTargets,
            targetResources: parsedTargetResources,
            externalPackages: parsedExternalPackages
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
                validator: Validators.validateProjectName
            ),
            CustomStep(
                id: "platforms",
                title: "Platforms",
                execute: { state in
                    let allPlatforms = PackagePlatform.allCases

                    let selectResult = PromptEngine.wizardMultiSelect(
                        prompt: "Target platforms (select at least one, or press Enter for iOS)",
                        options: allPlatforms.map(\.displayName)
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
                                validator: Validators.validatePlatformVersion
                            )
                            switch versionResult {
                            case .back:
                                return .back
                            case let .value(version):
                                platformVersions.append(PlatformVersion(
                                    platform: platform.platformName,
                                    version: version
                                ))
                            }
                        }

                        state.values["platforms"] = platformVersions
                        return .next
                    }
                },
                summaryValue: { state in
                    guard let pvs = state.platformVersions("platforms") else { return nil }
                    if pvs.isEmpty { return "iOS \(Defaults.deploymentTarget)" }
                    return pvs.map { "\($0.platform) \($0.version)" }.joined(separator: ", ")
                }
            ),
            StringStep(
                id: "targets",
                title: "Targets",
                prompt: "Targets (comma-separated, e.g., MyCore, MyUI)",
                defaultValue: { $0.string("name") ?? "" }
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
                }
            ),
            MultiSelectStep(
                id: "features",
                title: "Features",
                prompt: "Optional features",
                options: featureOptions.map(\.displayName)
            ),
            SingleSelectStep(
                id: "licenseType",
                title: "License type",
                prompt: "License type",
                options: LicenseType.allCases.map { "\($0.displayName) \u{2014} \($0.shortDescription)" },
                defaultIndex: LicenseType.allCases.firstIndex(of: .mit) ?? 0,
                isVisible: { state in
                    let selectedIndices = state.intSet("features") ?? []
                    let selectedFeatures = Set(selectedIndices.map { featureOptions[$0] })
                    return selectedFeatures.contains(.licenseChangelog)
                }
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
                }
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

        WizardEngine.run(title: "Monolith \u{2014} New Swift Package", steps: steps, state: &state)

        // Assemble config
        let parsedPlatforms = state.platformVersions("platforms")
            ?? [PlatformVersion(platform: "iOS", version: Defaults.deploymentTarget)]

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

        let licenseTypeIndex = state.int("licenseType") ?? LicenseType.allCases.firstIndex(of: .mit) ?? 0
        let licenseType = licenseTypeIndex < LicenseType.allCases.count
            ? LicenseType.allCases[licenseTypeIndex]
            : .mit

        let config = PackageConfig(
            name: state.string("name") ?? "",
            platforms: parsedPlatforms,
            targets: targetDefs,
            features: selectedFeatures,
            mainActorTargets: mainActorTargetSet,
            author: state.string("author") ?? "Author",
            licenseType: licenseType
        )
        let initGit = state.bool("initGit") ?? false
        let openProject = state.bool("openProject") ?? false

        return (config, initGit, openProject, false)
    }

    // MARK: - Parsing

    private func parseTargets(_ input: String, deps: String?) -> [TargetDefinition] {
        // Each --targets entry is `Name` or `Name:exec`. The `:exec` suffix marks
        // an `.executableTarget(...)` sibling (CLI tool alongside the libraries).
        let rawEntries = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let parsedNames: [(name: String, isExecutable: Bool)] = rawEntries.map { entry in
            let parts = entry.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, parts[1].lowercased() == "exec" {
                return (parts[0], true)
            }
            return (entry, false)
        }

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

        return parsedNames.map { entry in
            TargetDefinition(
                name: entry.name,
                dependencies: depMap[entry.name] ?? [],
                isExecutable: entry.isExecutable
            )
        }
    }

    private func parsePlatforms(_ input: String) throws -> [PlatformVersion] {
        try input.split(separator: ",").map { segment in
            let trimmed = segment.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: " ", maxSplits: 1)
            guard parts.count == 2 else {
                throw ValidationError("Invalid platform '\(trimmed)'. Expected format: 'iOS 18.0' (platform name + space + version).")
            }
            let version = String(parts[1])
            guard Validators.validatePlatformVersion(version) else {
                throw ValidationError("Invalid platform version '\(version)' for '\(parts[0])'. Must be major.minor numeric format (e.g., 18.0).")
            }
            return PlatformVersion(
                platform: String(parts[0]),
                version: version
            )
        }
    }

    private func parseCommaSeparated(_ input: String?) -> Set<String> {
        guard let input, !input.isEmpty else { return [] }
        return Set(input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
    }

    /// Parse `--target-resources "Target:dir1,dir2;Target2:Resources"`.
    private func parseTargetResources(_ input: String?) throws -> [String: [String]] {
        guard let input, !input.isEmpty else { return [:] }
        var out: [String: [String]] = [:]
        for entry in input.split(separator: ";") {
            let parts = entry.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else {
                throw ValidationError("Invalid --target-resources entry '\(entry)'. Expected 'Target:dir1,dir2'.")
            }
            let target = parts[0].trimmingCharacters(in: .whitespaces)
            let dirs = parts[1].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            out[target] = dirs
        }
        return out
    }

    /// Parse `--external-packages "Name=url:requirement[:packageName];..."`.
    /// `requirement` is verbatim SPM, e.g. `from: "0.1.0"` or `branch: "main"`.
    /// Optional `packageName` overrides the default (which equals the product name).
    private func parseExternalPackages(_ input: String?) throws -> [ExternalPackage] {
        guard let input, !input.isEmpty else { return [] }
        var out: [ExternalPackage] = []
        for entry in input.split(separator: ";") {
            let nameSplit = entry.split(separator: "=", maxSplits: 1)
            guard nameSplit.count == 2 else {
                throw ValidationError("Invalid --external-packages entry '\(entry)'. Expected 'Name=url:requirement[:packageName]'.")
            }
            let name = nameSplit[0].trimmingCharacters(in: .whitespaces)
            let rest = nameSplit[1].trimmingCharacters(in: .whitespaces)

            // Split on ':' but only on top-level colons (not inside quotes), since
            // requirement strings contain colons (e.g. `from: "0.1.0"`). The url
            // contains exactly one colon (`https://...`), so heuristic: find the
            // first ':' AFTER the schema's '//' which separates url from requirement.
            // Optional trailing `:packageName` is the last segment with no quotes.
            guard let schemeRange = rest.range(of: "://") else {
                throw ValidationError("Invalid --external-packages URL in '\(entry)'. Expected fully qualified URL.")
            }
            let afterScheme = rest[schemeRange.upperBound...]
            guard let urlEnd = afterScheme.firstIndex(of: ":") else {
                throw ValidationError("Invalid --external-packages entry '\(entry)'. Missing ':requirement' after URL.")
            }
            let url = String(rest[rest.startIndex ..< urlEnd])
            let afterURL = rest[rest.index(after: urlEnd)...].trimmingCharacters(in: .whitespaces)

            // Heuristic for optional :packageName at the end — match `:Identifier` after
            // a closing quote. If absent, the whole remainder is the requirement.
            let (requirement, packageName): (String, String?) = if let tailMatch = afterURL.range(of: #":[A-Za-z_][A-Za-z0-9_-]*$"#, options: .regularExpression) {
                (
                    String(afterURL[afterURL.startIndex ..< tailMatch.lowerBound]).trimmingCharacters(in: .whitespaces),
                    String(afterURL[afterURL.index(after: tailMatch.lowerBound)...]).trimmingCharacters(in: .whitespaces)
                )
            } else {
                (afterURL, nil)
            }

            out.append(ExternalPackage(name: name, url: url, requirement: requirement, packageName: packageName))
        }
        return out
    }
}
