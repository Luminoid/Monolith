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

    @Option(name: .long, help: "Features (comma-separated): strictConcurrency, defaultIsolation, devTooling, claudeMD, licenseChangelog")
    var features: String?

    @Option(name: .long, help: "Targets with defaultIsolation: MainActor (comma-separated)")
    var mainActorTargets: String?

    @Flag(name: .long, help: "Initialize git repository")
    var git = false

    @Flag(name: .long, help: "Skip git initialization")
    var noGit = false

    @Flag(name: .long, help: "Skip interactive prompts")
    var noInteractive = false

    func run() throws {
        let config: PackageConfig
        let initGit: Bool

        if noInteractive {
            guard let name else {
                throw ValidationError("--name is required in non-interactive mode")
            }
            guard Validators.validateProjectName(name) else {
                throw ValidationError("Invalid package name '\(name)'. Must start with a letter, contain only alphanumerics/hyphens/underscores, max 50 chars.")
            }

            let parsedTargets = parseTargets(targets ?? name, deps: targetDeps)
            let parsedPlatforms = parsePlatforms(platforms ?? "iOS 18.0")
            let parsedFeatures: Set<PackageFeature> = PromptEngine.parseFeatures(features)
            let parsedMainActorTargets = parseCommaSeparated(mainActorTargets)
            let author = FileWriter.gitAuthorName() ?? "Author"

            config = PackageConfig(
                name: name,
                platforms: parsedPlatforms,
                targets: parsedTargets,
                features: parsedFeatures,
                mainActorTargets: parsedMainActorTargets,
                author: author,
            )
            initGit = git
        } else {
            (config, initGit) = promptForConfig()
        }

        try PackageProjectGenerator.generate(config: config)

        if initGit {
            let basePath = FileWriter.resolveOutputPath(projectName: config.name)
            FileWriter.gitInit(at: basePath, hasGitHooks: config.hasGitHooks)
        }
    }

    private func promptForConfig() -> (PackageConfig, Bool) {
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
                hint: "Must start with a letter, alphanumeric/hyphens/underscores, max 50 chars",
                validator: Validators.validateProjectName,
            ),
            StringStep(
                id: "platforms",
                title: "Platforms",
                prompt: "Platforms (e.g., iOS 18.0, macOS 15.0, macCatalyst 18.0)",
                staticDefault: "iOS 18.0",
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
        ]

        WizardEngine.run(title: "Monolith \u{2014} New Swift Package", steps: steps, state: &state)

        // Assemble config
        let parsedPlatforms = parsePlatforms(state.string("platforms") ?? "iOS 18.0")

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

        return (config, initGit)
    }

    // MARK: - Parsing

    private func parseTargets(_ input: String, deps: String?) -> [TargetDefinition] {
        let names = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        // Parse deps format: "TargetB:TargetA,SnapKit;TargetC:TargetA"
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
