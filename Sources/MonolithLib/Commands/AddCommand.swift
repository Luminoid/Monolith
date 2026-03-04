import ArgumentParser
import Foundation

struct AddCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add a feature to an existing project.",
        discussion: "Adds additive features (files only, no existing file modifications).\nSupported: devTooling, gitHooks, claudeMD, licenseChangelog",
    )

    @Argument(help: "Feature to add: devTooling, gitHooks, claudeMD, licenseChangelog")
    var feature: String

    @Option(name: .long, help: "Project directory (default: current directory)")
    var path: String?

    @Flag(name: .long, help: "Preview files without writing")
    var dryRun = false

    func run() throws {
        guard let addable = AddableFeature(rawValue: feature) else {
            let valid = AddableFeature.allCases.map(\.rawValue).joined(separator: ", ")
            throw ValidationError("Unknown feature '\(feature)'. Valid: \(valid)")
        }

        let projectDir = path ?? FileManager.default.currentDirectoryPath
        let detected = try ProjectDetector.detect(at: projectDir)

        print()
        print("  Detected: \(detected.type.rawValue) project '\(detected.name)'")
        print("  Adding: \(addable.displayName)")
        print()

        let filePaths = addable.filePaths(projectType: detected.type, appName: detected.name)

        if dryRun {
            print("  Dry run \u{2014} \(filePaths.count) files would be created:\n")
            for file in filePaths {
                print("    \(file)")
            }
            return
        }

        switch addable {
        case .devTooling:
            try FileWriter.writeToolingFiles(
                projectType: detected.type,
                appName: detected.name,
                hasGitHooks: FileManager.default.fileExists(
                    atPath: (projectDir as NSString).appendingPathComponent("Scripts/git-hooks/pre-commit"),
                ),
                projectSystem: detected.projectSystem,
                basePath: projectDir,
            )

        case .gitHooks:
            try FileWriter.writeGitHooks(basePath: projectDir)

        case .claudeMD:
            let content = generateClaudeMD(detected: detected)
            try FileWriter.writeFile(at: ".claude/CLAUDE.md", content: content, basePath: projectDir)

        case .licenseChangelog:
            let author = FileWriter.gitAuthorName() ?? "Author"
            try FileWriter.writeOptionalFiles(
                claudeMDContent: nil,
                licenseAuthor: author,
                basePath: projectDir,
            )
        }

        print()
        print("  Done!")
    }

    private func generateClaudeMD(detected: ProjectDetector.DetectedProject) -> String {
        switch detected.type {
        case .app:
            ClaudeMDGenerator.generateForApp(config: AppConfig(
                name: detected.name,
                bundleID: "com.example.\(detected.name.lowercased())",
                deploymentTarget: "18.0",
                platforms: [.iPhone],
                projectSystem: detected.projectSystem ?? .spm,
                tabs: [],
                primaryColor: "#007AFF",
                features: [],
                author: FileWriter.gitAuthorName() ?? "Author",
            ))
        case .package:
            ClaudeMDGenerator.generateForPackage(config: PackageConfig(
                name: detected.name,
                platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
                targets: [TargetDefinition(name: detected.name, dependencies: [])],
                features: [],
                mainActorTargets: [],
                author: FileWriter.gitAuthorName() ?? "Author",
            ))
        case .cli:
            ClaudeMDGenerator.generateForCLI(config: CLIConfig(
                name: detected.name,
                includeArgumentParser: true,
                features: [],
                author: FileWriter.gitAuthorName() ?? "Author",
            ))
        }
    }
}
