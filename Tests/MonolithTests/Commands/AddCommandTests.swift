import Foundation
import Testing
@testable import MonolithLib

@Suite(.serialized)
struct AddCommandTests {
    /// Generate a scaffold project of the requested system into a temp dir.
    /// Returns the absolute path to the generated project root (e.g. `<tmp>/<App>`).
    private func makeScaffold(
        projectSystem: ProjectSystem,
        features: Set<AppFeature> = [],
        appName: String = "Scaffold",
        bundleID: String = "com.test.scaffold"
    ) throws -> String {
        let raw = NSTemporaryDirectory() + "monolith-add-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: raw, withIntermediateDirectories: true)

        let config = AppConfig(
            name: appName,
            bundleID: bundleID,
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: projectSystem,
            tabs: [],
            primaryColor: "#007AFF",
            features: features,
            author: "Test",
            licenseType: .proprietary
        )
        try AppProjectGenerator.generate(config: config, outputDir: raw)

        // For xcodeProj scaffolds, AppProjectGenerator still writes a project.yml in test envs
        // (xcodegen isn't run). To exercise the xcodeProj branch in `add`, we need to drop the
        // project.yml and create a fake .xcodeproj so ProjectDetector classifies it correctly.
        return "\(raw)/\(appName)"
    }

    private func makeXcodeProjScaffold(appName: String = "Scaffold") throws -> String {
        let projectRoot = try makeScaffold(projectSystem: .xcodeProj, appName: appName)
        // ProjectDetector treats project.yml as XcodeGen even if .xcodeproj is present.
        // Remove the YAML and create a placeholder .xcodeproj directory.
        try? FileManager.default.removeItem(atPath: "\(projectRoot)/project.yml")
        try FileManager.default.createDirectory(
            atPath: "\(projectRoot)/\(appName).xcodeproj",
            withIntermediateDirectories: true
        )
        return projectRoot
    }

    private func makeXcodeGenScaffold(appName: String = "Scaffold") throws -> String {
        try makeScaffold(projectSystem: .xcodeGen, appName: appName)
    }

    private func cleanup(_ projectRoot: String) {
        // Project root sits under `<tmp>/<App>`; remove the parent tmp.
        let parent = (projectRoot as NSString).deletingLastPathComponent
        try? FileManager.default.removeItem(atPath: parent)
    }

    /// Run `AddCommand` with the given args and return without throwing.
    private func runAdd(args: [String]) throws {
        var cmd = try AddCommand.parse(args)
        try cmd.run()
    }

    // MARK: - Tier 1

    @Test
    func `add privacyManifest writes app manifest`() throws {
        let project = try makeXcodeGenScaffold()
        defer { cleanup(project) }

        try runAdd(args: ["privacyManifest", "--path", project])

        let manifest = "\(project)/Scaffold/Resources/PrivacyInfo.xcprivacy"
        #expect(FileManager.default.fileExists(atPath: manifest))
        let content = try String(contentsOfFile: manifest, encoding: .utf8)
        #expect(content.contains("NSPrivacyTracking"))
        #expect(content.contains("NSPrivacyAccessedAPICategoryUserDefaults"))
    }

    @Test
    func `add privacyManifest also writes widget manifest when widget dir exists`() throws {
        let project = try makeXcodeGenScaffold()
        defer { cleanup(project) }

        // Simulate a pre-existing widget extension.
        try FileManager.default.createDirectory(
            atPath: "\(project)/ScaffoldWidget",
            withIntermediateDirectories: true
        )

        try runAdd(args: ["privacyManifest", "--path", project])

        #expect(FileManager.default.fileExists(atPath: "\(project)/Scaffold/Resources/PrivacyInfo.xcprivacy"))
        #expect(FileManager.default.fileExists(atPath: "\(project)/ScaffoldWidget/PrivacyInfo.xcprivacy"))
    }

    @Test
    func `add appIconValidation writes executable script`() throws {
        let project = try makeXcodeGenScaffold()
        defer { cleanup(project) }

        try runAdd(args: ["appIconValidation", "--path", project])

        let script = "\(project)/Scripts/validate-app-icon.sh"
        #expect(FileManager.default.fileExists(atPath: script))
        let attrs = try FileManager.default.attributesOfItem(atPath: script)
        let permissions = attrs[.posixPermissions] as? Int
        #expect(permissions == 0o755)
        let content = try String(contentsOfFile: script, encoding: .utf8)
        #expect(content.contains("App Store Connect"))
        #expect(content.contains("Scaffold/Resources/Assets.xcassets/AppIcon.appiconset"))
    }

    @Test
    func `add dry-run does not write files`() throws {
        let project = try makeXcodeGenScaffold()
        defer { cleanup(project) }

        try runAdd(args: ["privacyManifest", "--path", project, "--dry-run"])

        #expect(!FileManager.default.fileExists(atPath: "\(project)/Scaffold/Resources/PrivacyInfo.xcprivacy"))
    }

    @Test
    func `add unknown feature throws ValidationError`() throws {
        let project = try makeXcodeGenScaffold()
        defer { cleanup(project) }

        #expect(throws: (any Error).self) {
            try runAdd(args: ["notAFeature", "--path", project])
        }
    }

    // MARK: - Tier 2 — Localization

    @Test
    func `add localization writes string catalog and L10n on xcodegen`() throws {
        let project = try makeXcodeGenScaffold()
        defer { cleanup(project) }

        try runAdd(args: ["localization", "--path", project])

        #expect(FileManager.default.fileExists(atPath: "\(project)/Scaffold/Resources/Localizable.xcstrings"))
        #expect(FileManager.default.fileExists(atPath: "\(project)/Scaffold/Core/L10n.swift"))
    }

    @Test
    func `add localization writes files on xcodeproj projects too`() throws {
        let project = try makeXcodeProjScaffold()
        defer { cleanup(project) }

        try runAdd(args: ["localization", "--path", project])

        #expect(FileManager.default.fileExists(atPath: "\(project)/Scaffold/Resources/Localizable.xcstrings"))
        #expect(FileManager.default.fileExists(atPath: "\(project)/Scaffold/Core/L10n.swift"))
    }

    // MARK: - Tier 2 — Mac Catalyst

    @Test
    func `add macCatalyst writes MacWindowConfig and edits project.yml on xcodegen`() throws {
        let project = try makeXcodeGenScaffold()
        defer { cleanup(project) }

        try runAdd(args: ["macCatalyst", "--path", project])

        #expect(FileManager.default.fileExists(atPath: "\(project)/Scaffold/MacCatalyst/MacWindowConfig.swift"))

        let yaml = try String(contentsOfFile: "\(project)/project.yml", encoding: .utf8)
        #expect(yaml.contains("macCatalyst: 18.0"))
        #expect(yaml.contains("supportedDestinations: [iOS, macCatalyst]"))
    }

    @Test
    func `add macCatalyst is idempotent`() throws {
        let project = try makeXcodeGenScaffold()
        defer { cleanup(project) }

        try runAdd(args: ["macCatalyst", "--path", project])
        try runAdd(args: ["macCatalyst", "--path", project])

        let yaml = try String(contentsOfFile: "\(project)/project.yml", encoding: .utf8)
        // Exactly one supportedDestinations line.
        let occurrences = yaml.components(separatedBy: "supportedDestinations:").count - 1
        #expect(occurrences == 1)
    }

    // MARK: - Tier 2 — Lottie / SnapKit / Lookin

    @Test
    func `add lottie writes helper and edits project.yml`() throws {
        let project = try makeXcodeGenScaffold()
        defer { cleanup(project) }

        try runAdd(args: ["lottie", "--path", project])

        #expect(FileManager.default.fileExists(atPath: "\(project)/Scaffold/Shared/Components/LottieHelper.swift"))

        let yaml = try String(contentsOfFile: "\(project)/project.yml", encoding: .utf8)
        #expect(yaml.contains("Lottie:"))
        #expect(yaml.contains("lottie-spm.git"))
        #expect(yaml.contains("- package: Lottie"))
    }

    @Test
    func `add snapKit and add lookin were removed in v0_4`() {
        // SnapKit and LookinServer left AddableFeature in v0.4. Existing
        // projects retrofit them via Xcode's native Add Package flow against
        // the URLs in KnownPackages.registry.
        #expect(!AddableFeature.allCases.contains(where: { $0.rawValue == "snapKit" }))
        #expect(!AddableFeature.allCases.contains(where: { $0.rawValue == "lookin" }))
    }

    @Test
    func `add lottie twice is idempotent`() throws {
        let project = try makeXcodeGenScaffold()
        defer { cleanup(project) }

        try runAdd(args: ["lottie", "--path", project])
        try runAdd(args: ["lottie", "--path", project])

        let yaml = try String(contentsOfFile: "\(project)/project.yml", encoding: .utf8)
        let packageOccurrences = yaml.components(separatedBy: "  Lottie:\n").count - 1
        let depOccurrences = yaml.components(separatedBy: "- package: Lottie").count - 1
        #expect(packageOccurrences == 1)
        #expect(depOccurrences == 1)
    }

    // MARK: - Tier 2 — Widget

    @Test
    func `add widget writes extension files and edits project.yml`() throws {
        let project = try makeXcodeGenScaffold()
        defer { cleanup(project) }

        try runAdd(args: ["widget", "--path", project, "--bundle-id", "com.test.scaffold"])

        #expect(FileManager.default.fileExists(atPath: "\(project)/ScaffoldWidget/Info.plist"))
        #expect(FileManager.default.fileExists(atPath: "\(project)/ScaffoldWidget/ScaffoldWidget.entitlements"))
        #expect(FileManager.default.fileExists(atPath: "\(project)/ScaffoldWidget/ScaffoldWidgetBundle.swift"))
        #expect(FileManager.default.fileExists(atPath: "\(project)/ScaffoldWidget/ScaffoldWidget.swift"))
        #expect(FileManager.default.fileExists(atPath: "\(project)/Scaffold/Shared/AppGroup.swift"))

        let yaml = try String(contentsOfFile: "\(project)/project.yml", encoding: .utf8)
        #expect(yaml.contains("ScaffoldWidget:"))
        #expect(yaml.contains("type: app-extension"))
        #expect(yaml.contains("WidgetKit.framework"))

        let entitlements = try String(
            contentsOfFile: "\(project)/ScaffoldWidget/ScaffoldWidget.entitlements",
            encoding: .utf8
        )
        #expect(entitlements.contains("group.com.test.scaffold"))
    }

    // MARK: - Validation

    @Test
    func `Tier 2 feature on package project throws`() throws {
        // Build a minimal package scaffold.
        let raw = NSTemporaryDirectory() + "monolith-add-pkg-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: raw) }
        try FileManager.default.createDirectory(atPath: raw, withIntermediateDirectories: true)
        let config = PackageConfig(
            name: "Pkg",
            platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
            targets: [TargetDefinition(name: "Pkg", dependencies: [])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        try PackageProjectGenerator.generate(config: config, outputDir: raw)

        let projectRoot = "\(raw)/Pkg"
        #expect(throws: (any Error).self) {
            try runAdd(args: ["widget", "--path", projectRoot])
        }
    }
}
