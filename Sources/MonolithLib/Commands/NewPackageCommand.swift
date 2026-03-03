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
            config = promptForConfig()
            initGit = noGit ? false : PromptEngine.askYesNo(prompt: "Initialize git repository?")
        }

        try PackageProjectGenerator.generate(config: config)

        if initGit {
            let basePath = FileWriter.resolveOutputPath(projectName: config.name)
            FileWriter.gitInit(at: basePath)
        }
    }

    private func promptForConfig() -> PackageConfig {
        PromptEngine.printHeader(title: "Monolith \u{2014} New Swift Package")

        let name = PromptEngine.askValidatedString(
            prompt: "Package name",
            hint: "Must start with a letter, alphanumeric/hyphens/underscores, max 50 chars",
            validator: Validators.validateProjectName,
        )
        let platformsStr = PromptEngine.askString(prompt: "Platforms", default: "iOS 18.0")
        let parsedPlatforms = parsePlatforms(platformsStr)

        let targetsStr = PromptEngine.askString(prompt: "Targets (comma-separated)", default: name)
        let targetNames = targetsStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        // Ask for dependencies for each target
        var targetDefs: [TargetDefinition] = []
        if targetNames.count > 1 {
            print("  Target dependencies (target:dep1,dep2):")
            for targetName in targetNames {
                let depsStr = PromptEngine.askString(prompt: "  \(targetName) deps", default: "")
                let deps = depsStr.isEmpty ? [] : depsStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                targetDefs.append(TargetDefinition(name: targetName, dependencies: deps))
            }
        } else {
            targetDefs = targetNames.map { TargetDefinition(name: $0, dependencies: []) }
        }

        let featureOptions = PackageFeature.allCases
        let selectedIndices = PromptEngine.askMultiSelect(
            prompt: "Optional features",
            options: featureOptions.map(\.displayName),
        )
        let selectedFeatures = Set(selectedIndices.map { featureOptions[$0] })

        // Ask which targets get MainActor (if defaultIsolation selected)
        var mainActorTargetSet = Set<String>()
        if selectedFeatures.contains(.defaultIsolation), targetNames.count > 1 {
            let maStr = PromptEngine.askString(prompt: "defaultIsolation: MainActor targets (comma-separated)")
            mainActorTargetSet = parseCommaSeparated(maStr)
        } else if selectedFeatures.contains(.defaultIsolation) {
            mainActorTargetSet = Set(targetNames)
        }

        let author = FileWriter.gitAuthorName() ?? PromptEngine.askString(prompt: "Author name", default: "Author")

        return PackageConfig(
            name: name,
            platforms: parsedPlatforms,
            targets: targetDefs,
            features: selectedFeatures,
            mainActorTargets: mainActorTargetSet,
            author: author,
        )
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
