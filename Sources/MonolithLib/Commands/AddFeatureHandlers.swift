import Foundation

/// Handlers for `monolith add <feature>` beyond the four original additive
/// features (devTooling, gitHooks, claudeMD, licenseChangelog).
///
/// Each handler:
/// 1. Writes new files (always).
/// 2. If project.yml is present, edits it via `ProjectYamlEditor`.
/// 3. Otherwise prints manual integration steps the user should perform in
///    Xcode (Target Membership, Add Package, etc.).
enum AddFeatureHandlers {
    // MARK: - Tier 1

    static func addPrivacyManifest(projectDir: String, appName: String) throws {
        let relativePath = "\(appName)/Resources/PrivacyInfo.xcprivacy"
        try FileWriter.writeFile(
            at: relativePath,
            content: PrivacyInfoGenerator.generate(role: .app),
            basePath: projectDir
        )

        let hasWidget = FileManager.default.fileExists(
            atPath: (projectDir as NSString).appendingPathComponent("\(appName)Widget")
        )
        if hasWidget {
            try FileWriter.writeFile(
                at: "\(appName)Widget/PrivacyInfo.xcprivacy",
                content: PrivacyInfoGenerator.generate(role: .extensionTarget),
                basePath: projectDir
            )
        }

        print()
        print("  Edit before submission if you actually track users or collect data.")
        print("  Reference: https://developer.apple.com/documentation/bundleresources/privacy_manifest_files")
    }

    static func addAppIconValidation(projectDir: String, appName: String) throws {
        let iconsetPath = "\(appName)/Resources/Assets.xcassets/AppIcon.appiconset"
        try FileWriter.writeFile(
            at: "Scripts/validate-app-icon.sh",
            content: AppIconValidationGenerator.generate(iconsetRelativePath: iconsetPath),
            basePath: projectDir,
            executable: true
        )

        print()
        print("  Wire into Xcode as a Run Script build phase, or call from CI.")
        print("  Script path: Scripts/validate-app-icon.sh")
    }

    // MARK: - Tier 2 — SPM packages (Lottie / SnapKit / Lookin)

    struct PackageSpec {
        let name: String
        let url: String
        let from: String
        let platforms: [String]?
        let writesFile: (basePath: String, relativePath: String, content: String)?

        static let lottie = Self(
            name: "Lottie",
            url: "https://github.com/airbnb/lottie-spm.git",
            from: DependencyVersion.lottie,
            platforms: nil,
            writesFile: nil
        )

        static let snapKit = Self(
            name: "SnapKit",
            url: "https://github.com/SnapKit/SnapKit.git",
            from: DependencyVersion.snapKit,
            platforms: nil,
            writesFile: nil
        )

        static let lookin = Self(
            name: "LookinServer",
            url: "https://github.com/QMUI/LookinServer.git",
            from: DependencyVersion.lookin,
            platforms: ["iOS"],
            writesFile: nil
        )
    }

    static func addSPMPackage(
        projectDir: String,
        detected: ProjectDetector.DetectedProject,
        spec: PackageSpec
    ) throws {
        // Lottie adds a helper file; SnapKit/Lookin are dependency-only.
        if spec.name == "Lottie" {
            try FileWriter.writeFile(
                at: "\(detected.name)/Shared/Components/LottieHelper.swift",
                content: LottieGenerator.generateHelper(),
                basePath: projectDir
            )
        }

        try editProjectYamlOrPrintSteps(
            projectDir: projectDir,
            projectSystem: detected.projectSystem,
            featureName: spec.name,
            xcodeGenEdit: { yaml in
                ProjectYamlEditor.addPackageDependency(
                    yaml: &yaml,
                    targetName: detected.name,
                    packageName: spec.name,
                    url: spec.url,
                    from: spec.from,
                    targetPlatforms: spec.platforms
                )
            },
            xcodeProjSteps: [
                "Open the project in Xcode.",
                "File → Add Package Dependencies… → \(spec.url) → Up to Next Major from \(spec.from).",
                "Add the resolved product to \(detected.name)'s target.",
            ]
        )
    }

    // MARK: - Tier 2 — Localization

    static func addLocalization(
        projectDir: String,
        detected: ProjectDetector.DetectedProject
    ) throws {
        let stubConfig = AppConfig(
            name: detected.name,
            bundleID: "com.example.\(detected.name.lowercased())",
            deploymentTarget: Defaults.deploymentTarget,
            platforms: [.iPhone],
            projectSystem: detected.projectSystem ?? .xcodeProj,
            tabs: [],
            primaryColor: Defaults.primaryColor,
            features: [.localization],
            author: "Author",
            licenseType: .proprietary
        )

        try FileWriter.writeFile(
            at: "\(detected.name)/Resources/Localizable.xcstrings",
            content: LocalizationGenerator.generateStringCatalog(config: stubConfig),
            basePath: projectDir
        )
        try FileWriter.writeFile(
            at: "\(detected.name)/Core/L10n.swift",
            content: LocalizationGenerator.generateL10n(config: stubConfig),
            basePath: projectDir
        )

        // No project.yml edit needed — XcodeGen scans `sources: [<name>]` recursively.
        if detected.projectSystem == .xcodeProj {
            print()
            print("  Manual integration (.xcodeproj):")
            print("    1. Add Localizable.xcstrings to the app target's Resources phase.")
            print("    2. Add L10n.swift to the app target's Compile Sources phase.")
        } else {
            print()
            print("  Re-run `xcodegen generate` to pick up the new files.")
        }
    }

    // MARK: - Tier 2 — Mac Catalyst

    static func addMacCatalyst(
        projectDir: String,
        detected: ProjectDetector.DetectedProject
    ) throws {
        try FileWriter.writeFile(
            at: "\(detected.name)/MacCatalyst/MacWindowConfig.swift",
            content: MacCatalystGenerator.generateWindowConfig(),
            basePath: projectDir
        )

        // The generated MacWindowConfig references AppConstants.MacWindow.{min,max}{Width,Height}.
        // Check whether those exist and warn if not.
        let constantsPath = (projectDir as NSString)
            .appendingPathComponent("\(detected.name)/Core/AppConstants.swift")
        let constants = (try? String(contentsOfFile: constantsPath, encoding: .utf8)) ?? ""
        if !constants.contains("MacWindow") {
            print()
            print("  warning: \(detected.name)/Core/AppConstants.swift does not appear to define `MacWindow`.")
            print("  Add a block like:")
            print()
            print("      enum MacWindow {")
            print("          static let minWidth: CGFloat = 800")
            print("          static let minHeight: CGFloat = 600")
            print("          static let maxWidth: CGFloat = 1600")
            print("          static let maxHeight: CGFloat = 1200")
            print("      }")
        }

        try editProjectYamlOrPrintSteps(
            projectDir: projectDir,
            projectSystem: detected.projectSystem,
            featureName: "Mac Catalyst",
            xcodeGenEdit: { yaml in
                ProjectYamlEditor.enableMacCatalyst(yaml: &yaml, targetName: detected.name)
            },
            xcodeProjSteps: [
                "Select the app target → General → Supported Destinations → add `Mac (Mac Catalyst)`.",
                "Build the project to validate against Mac Catalyst SDK.",
            ]
        )
    }

    // MARK: - Tier 2 — Widget

    static func addWidget(
        projectDir: String,
        detected: ProjectDetector.DetectedProject,
        bundleIDOverride: String?
    ) throws {
        let appName = detected.name
        let widgetDir = "\(appName)Widget"
        let resolvedBundleID = bundleIDOverride ?? "com.example.\(appName.lowercased())"
        let appGroup = "group.\(resolvedBundleID)"

        try FileWriter.writeFile(
            at: "\(widgetDir)/Info.plist",
            content: WidgetExtensionGenerator.generateInfoPlist(),
            basePath: projectDir
        )
        try FileWriter.writeFile(
            at: "\(widgetDir)/\(appName)Widget.entitlements",
            content: WidgetExtensionGenerator.generateEntitlements(appGroup: appGroup),
            basePath: projectDir
        )
        try FileWriter.writeFile(
            at: "\(widgetDir)/\(appName)WidgetBundle.swift",
            content: WidgetExtensionGenerator.generateBundle(appName: appName),
            basePath: projectDir
        )
        try FileWriter.writeFile(
            at: "\(widgetDir)/\(appName)Widget.swift",
            content: WidgetExtensionGenerator.generateWidget(appName: appName, appGroup: appGroup),
            basePath: projectDir
        )
        try FileWriter.writeFile(
            at: "\(appName)/Shared/AppGroup.swift",
            content: WidgetExtensionGenerator.generateAppGroupConstants(appGroup: appGroup),
            basePath: projectDir
        )

        try editProjectYamlOrPrintSteps(
            projectDir: projectDir,
            projectSystem: detected.projectSystem,
            featureName: "Widget extension",
            xcodeGenEdit: { yaml in
                ProjectYamlEditor.addWidgetTarget(yaml: &yaml, appName: appName, bundleID: resolvedBundleID)
            },
            xcodeProjSteps: [
                "Add a new Widget Extension target named `\(appName)Widget`.",
                "Point its Info.plist at \(widgetDir)/Info.plist and entitlements at \(widgetDir)/\(appName)Widget.entitlements.",
                "Add the App Group `\(appGroup)` to both the app and widget entitlements (Signing & Capabilities).",
                "Move the generated Swift files into the widget target's Compile Sources phase.",
                "Add AppGroup.swift to the app target's Compile Sources phase.",
            ]
        )
    }

    // MARK: - Shared dispatch helper

    /// Either edit the existing `project.yml` (XcodeGen) or print manual
    /// integration steps for `.xcodeproj` users. The closure-based shape keeps
    /// the call sites readable.
    private static func editProjectYamlOrPrintSteps(
        projectDir: String,
        projectSystem: ProjectSystem?,
        featureName: String,
        xcodeGenEdit: (inout String) -> ProjectYamlEditor.Result,
        xcodeProjSteps: [String]
    ) throws {
        let yamlPath = (projectDir as NSString).appendingPathComponent("project.yml")
        let hasYaml = FileManager.default.fileExists(atPath: yamlPath)

        if hasYaml, projectSystem == .xcodeGen {
            var yaml = try String(contentsOfFile: yamlPath, encoding: .utf8)
            let result = xcodeGenEdit(&yaml)
            switch result {
            case .applied:
                try yaml.write(toFile: yamlPath, atomically: true, encoding: .utf8)
                print("  ✓ project.yml updated (\(featureName))")
                print()
                print("  Re-run `xcodegen generate` to apply.")
            case .alreadyPresent:
                print("  ↻ project.yml already declares \(featureName) — no change")
            case let .failed(reason):
                print("  warning: could not update project.yml for \(featureName): \(reason)")
                print("  Edit project.yml manually, then re-run `xcodegen generate`.")
            }
            return
        }

        // .xcodeproj path — print manual steps.
        print()
        print("  Manual integration steps for \(featureName) (.xcodeproj):")
        for (index, step) in xcodeProjSteps.enumerated() {
            print("    \(index + 1). \(step)")
        }
    }
}
