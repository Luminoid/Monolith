import ArgumentParser
import Foundation

struct AddCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add a feature to an existing project.",
        discussion: """
        Two tiers of features:

        Tier 1 (any project system; writes new files only):
          devTooling, gitHooks, claudeMD, licenseChangelog,
          privacyManifest, appIconValidation

        Tier 2 (app projects only; XcodeGen edits project.yml automatically,
                .xcodeproj writes files and prints manual integration steps):
          localization, macCatalyst, lottie, widget

        A file that already exists is kept unless --force is passed.
        Entitlements are merged, never replaced.
        """
    )

    @Argument(help: "Feature to add")
    var feature: AddableFeature

    @Option(name: .long, help: "Project directory (default: current directory)")
    var path: String?

    @Option(name: .long, help: "License type (default: proprietary for apps, mit for packages, apache2 for CLIs)")
    var license: LicenseType?

    @Option(
        name: .long,
        help: "App bundle ID used for the widget (<id>.Widget) and App Group (group.<id>) when the project doesn't set one (default: read from the project)"
    )
    var bundleID: String?

    @Option(name: .long, help: "Locales for `add localization` (comma-separated; the first is the source language; default: en)")
    var locales: String?

    @Flag(name: .long, help: "Overwrite files that already exist (entitlements are still merged)")
    var force = false

    @Flag(name: .long, help: "Show what would be written, kept, or edited, without changing anything")
    var dryRun = false

    func run() throws {
        let options = try resolvedOptions()

        let projectDir = URL(fileURLWithPath: ((path ?? FileManager.default.currentDirectoryPath) as NSString).expandingTildeInPath)
            .standardizedFileURL.path
        let detected = try ProjectDetector.detect(at: projectDir)

        if feature.requiresAppProject, detected.type != .app {
            let availableForType = AddableFeature.allCases
                .filter { !$0.requiresAppProject }
                .map(\.rawValue)
                .joined(separator: ", ")
            throw ValidationError("""
            Feature '\(feature.rawValue)' applies to app projects only (detected \(detected.type.rawValue) project).
            Features available for \(detected.type.rawValue) projects: \(availableForType)
            """)
        }

        print()
        print("  Detected: \(detected.type.rawValue) project '\(detected.name)'")
        if let system = detected.projectSystem {
            print("  System: \(system.rawValue)")
        }
        print("  Adding: \(feature.displayName)")
        print()

        let state = ProjectState.scan(at: projectDir, detected: detected)
        let plan = try AddFeatureHandlers.plan(feature, state: state, options: options)

        if dryRun {
            try plan.printDryRun(in: projectDir, projectSystem: detected.projectSystem, force: force)
            return
        }

        try plan.execute(in: projectDir, projectSystem: detected.projectSystem, policy: force ? .overwrite : .skip)

        print()
        print("  Done!")
    }

    // MARK: - Options

    private func resolvedOptions() throws -> AddFeatureHandlers.Options {
        var options = AddFeatureHandlers.Options()
        options.license = license
        if let bundleID {
            guard Validators.validateBundleID(bundleID) else {
                throw ValidationError("Invalid --bundle-id '\(bundleID)'. Use reverse-DNS form, e.g. com.example.myapp.")
            }
            options.bundleID = bundleID
        }
        if let locales {
            options.locales = try LocaleList.parse(locales)
        }
        return options
    }
}
