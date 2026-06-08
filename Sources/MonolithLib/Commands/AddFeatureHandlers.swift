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

    // MARK: - Tier 2 — SPM packages (Lottie)

    struct PackageSpec {
        let name: String
        let url: String
        let from: String
        let platforms: [String]?
        let writesFile: (basePath: String, relativePath: String, content: String)?

        /// Construct a `PackageSpec` from a `KnownPackages.registry` entry.
        /// Adding a new `monolith add <feature>` route for a registered
        /// package is one static constructor like `lottie` below — URL,
        /// version, and platform conditional come from the registry.
        static func fromRegistry(_ identifier: String) -> Self? {
            guard let entry = KnownPackages.registry[identifier] else { return nil }
            return Self(
                name: entry.name,
                url: entry.url,
                from: entry.defaultVersion,
                platforms: entry.platforms,
                writesFile: nil
            )
        }

        /// `Self` is a value type, so this is a stable identity for the
        /// `lottie` case across calls. A `static var` with a non-`Sendable`
        /// body would warn under Swift 6 strict concurrency — `static let`
        /// with a `??` fallback to the literal data is total and inline.
        static let lottie = Self.fromRegistry("Lottie") ?? Self(
            name: "Lottie",
            url: "https://github.com/airbnb/lottie-spm.git",
            from: DependencyVersion.lottie,
            platforms: nil,
            writesFile: nil
        )
    }

    static func addSPMPackage(
        projectDir: String,
        detected: ProjectDetector.DetectedProject,
        spec: PackageSpec
    ) throws {
        // Lottie also writes a helper file.
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
        try FileWriter.writeFile(
            at: "Scripts/localization/audit_strings.py",
            content: LocalizationAuditGenerator.generate(appName: detected.name),
            basePath: projectDir,
            executable: true
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
            at: "\(appName)/\(appName).entitlements",
            content: WidgetExtensionGenerator.generateAppEntitlements(appGroup: appGroup),
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
                let widgetResult = ProjectYamlEditor.addWidgetTarget(yaml: &yaml, appName: appName, bundleID: resolvedBundleID)
                if case .failed = widgetResult { return widgetResult }
                let appResult = ProjectYamlEditor.wireAppForWidget(yaml: &yaml, appName: appName)
                if case .failed = appResult { return appResult }
                if case .applied = widgetResult { return .applied }
                if case .applied = appResult { return .applied }
                return .alreadyPresent
            },
            xcodeProjSteps: [
                "Add a new Widget Extension target named `\(appName)Widget`.",
                "Point its Info.plist at \(widgetDir)/Info.plist and entitlements at \(widgetDir)/\(appName)Widget.entitlements.",
                "Set CODE_SIGN_ENTITLEMENTS on the app target to \(appName)/\(appName).entitlements.",
                "Add the App Group `\(appGroup)` to both the app and widget entitlements (Signing & Capabilities).",
                "Move the generated Swift files into the widget target's Compile Sources phase.",
                "Add AppGroup.swift to BOTH the app target's and the widget target's Compile Sources phases (so neither hardcodes the App Group id).",
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
                print("  \(UISymbols.check) project.yml updated (\(featureName))")
                print()
                print("  Re-run `xcodegen generate` to apply.")
            case .alreadyPresent:
                print("  \(UISymbols.cycle) project.yml already declares \(featureName); no change")
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
