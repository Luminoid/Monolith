import ArgumentParser
import Foundation

struct AddCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add a feature to an existing project.",
        discussion: """
        Two tiers of features:

        Tier 1 (any project system, pure file writes):
          devTooling, gitHooks, claudeMD, licenseChangelog,
          privacyManifest, appIconValidation

        Tier 2 (app projects only — XcodeGen edits project.yml automatically;
                .xcodeproj writes files and prints manual integration steps):
          localization, macCatalyst, lottie, widget
        """
    )

    @Argument(help: "Feature to add (run `monolith list features` for the full list)")
    var feature: String

    @Option(name: .long, help: "Project directory (default: current directory)")
    var path: String?

    @Option(name: .long, help: "License type: mit, apache2, proprietary (default: based on project type)")
    var license: String?

    @Option(name: .long, help: "Bundle ID prefix for the widget extension (default: derived from existing target)")
    var bundleID: String?

    @Flag(name: .long, help: "Preview files without writing")
    var dryRun = false

    func run() throws {
        guard let addable = AddableFeature(rawValue: feature) else {
            let valid = AddableFeature.allCases.map(\.rawValue).joined(separator: ", ")
            throw ValidationError("Unknown feature '\(feature)'. Valid: \(valid)")
        }

        let projectDir = path ?? FileManager.default.currentDirectoryPath
        let detected = try ProjectDetector.detect(at: projectDir)

        if addable.requiresAppProject, detected.type != .app {
            let availableForType = AddableFeature.allCases
                .filter { !$0.requiresAppProject }
                .map(\.rawValue)
                .joined(separator: ", ")
            throw ValidationError("""
            Feature '\(feature)' applies to app projects only (detected \(detected.type.rawValue) project).
            Features available for \(detected.type.rawValue) projects: \(availableForType)
            """)
        }

        print()
        print("  Detected: \(detected.type.rawValue) project '\(detected.name)'")
        if let system = detected.projectSystem {
            print("  System: \(system.rawValue)")
        }
        print("  Adding: \(addable.displayName)")
        print()

        let filePaths = addable.filePaths(projectType: detected.type, appName: detected.name)

        if dryRun {
            print("  Dry run — \(filePaths.count) file\(filePaths.count == 1 ? "" : "s") would be created:")
            for file in filePaths {
                print("    \(file)")
            }
            if addable.needsProjectSystemEdit {
                print()
                print("  Would also edit: project.yml (XcodeGen) or print manual steps (.xcodeproj)")
            }
            return
        }

        try dispatch(addable: addable, projectDir: projectDir, detected: detected)

        print()
        print("  Done!")
    }

    // MARK: - Dispatch

    private func dispatch(
        addable: AddableFeature,
        projectDir: String,
        detected: ProjectDetector.DetectedProject
    ) throws {
        switch addable {
        // Tier 1 (original additive)
        case .devTooling:
            try FileWriter.writeToolingFiles(
                projectType: detected.type,
                appName: detected.name,
                hasGitHooks: FileManager.default.fileExists(
                    atPath: (projectDir as NSString).appendingPathComponent("Scripts/git-hooks/pre-commit")
                ),
                projectSystem: detected.projectSystem,
                basePath: projectDir
            )

        case .gitHooks:
            try FileWriter.writeGitHooks(basePath: projectDir)

        case .claudeMD:
            let content = generateClaudeMD(detected: detected)
            try FileWriter.writeFile(at: ".claude/CLAUDE.md", content: content, basePath: projectDir)

        case .licenseChangelog:
            var licenseType = LicenseType.defaultFor(detected.type)
            if let license {
                guard let lt = LicenseType(rawValue: license) else {
                    throw ValidationError("Unknown license '\(license)'. Valid: \(LicenseType.allCases.map(\.rawValue).joined(separator: ", "))")
                }
                licenseType = lt
            }
            let author = FileWriter.gitAuthorName() ?? "Author"
            try FileWriter.writeOptionalFiles(
                claudeMDContent: nil,
                licenseAuthor: author,
                licenseType: licenseType,
                basePath: projectDir
            )

        // Tier 1 (new — pure file writes, no project.yml edits)
        case .privacyManifest:
            try AddFeatureHandlers.addPrivacyManifest(
                projectDir: projectDir,
                appName: detected.name
            )

        case .appIconValidation:
            try AddFeatureHandlers.addAppIconValidation(
                projectDir: projectDir,
                appName: detected.name
            )

        // Tier 2 (XcodeGen edits project.yml; .xcodeproj prints steps)
        case .localization:
            try AddFeatureHandlers.addLocalization(
                projectDir: projectDir,
                detected: detected
            )

        case .macCatalyst:
            try AddFeatureHandlers.addMacCatalyst(
                projectDir: projectDir,
                detected: detected
            )

        case .lottie:
            try AddFeatureHandlers.addSPMPackage(
                projectDir: projectDir,
                detected: detected,
                spec: .lottie
            )

        case .widget:
            try AddFeatureHandlers.addWidget(
                projectDir: projectDir,
                detected: detected,
                bundleIDOverride: bundleID
            )
        }
    }

    // MARK: - CLAUDE.md generation (Tier 1 dispatch helper)

    private func generateClaudeMD(detected: ProjectDetector.DetectedProject) -> String {
        switch detected.type {
        case .app:
            ClaudeMDGenerator.generateForApp(config: AppConfig(
                name: detected.name,
                bundleID: "com.example.\(detected.name.lowercased())",
                deploymentTarget: Defaults.deploymentTarget,
                platforms: [.iPhone],
                projectSystem: detected.projectSystem ?? .spm,
                tabs: [],
                primaryColor: Defaults.primaryColor,
                features: [],
                author: FileWriter.gitAuthorName() ?? "Author",
                licenseType: .proprietary
            ))
        case .package:
            ClaudeMDGenerator.generateForPackage(config: PackageConfig(
                name: detected.name,
                platforms: [PlatformVersion(platform: "iOS", version: Defaults.deploymentTarget)],
                targets: [TargetDefinition(name: detected.name, dependencies: [])],
                features: [],
                mainActorTargets: [],
                author: FileWriter.gitAuthorName() ?? "Author",
                licenseType: .mit
            ))
        case .cli:
            ClaudeMDGenerator.generateForCLI(config: CLIConfig(
                name: detected.name,
                includeArgumentParser: true,
                features: [],
                author: FileWriter.gitAuthorName() ?? "Author",
                licenseType: .apache2
            ))
        }
    }
}
