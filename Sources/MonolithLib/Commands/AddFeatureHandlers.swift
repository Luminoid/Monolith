import ArgumentParser
import Foundation

/// Plans for `monolith add <feature>`: what each feature writes, merges, and
/// edits, read from the detected `ProjectState` so the output matches what
/// `monolith new` writes for the same project. `AddPlan` runs or previews
/// the result.
///
/// A plan:
/// 1. Lists the new files (kept when they exist, unless `--force`).
/// 2. Lists entitlements keys to merge (never a replacement).
/// 3. For XcodeGen projects, carries the project.yml edit; for `.xcodeproj`
///    projects, the manual steps to print instead.
enum AddFeatureHandlers {
    /// The `add` flags that shape a plan.
    struct Options {
        var license: LicenseType?
        /// `--bundle-id`, used for the widget when the project doesn't name one.
        var bundleID: String?
        var locales = ["en"]
    }

    static func plan(_ feature: AddableFeature, state: ProjectState, options: Options) throws -> AddPlan {
        switch feature {
        case .devTooling: devToolingPlan(state: state)
        case .gitHooks: gitHooksPlan(state: state)
        case .claudeMD: claudeMDPlan(state: state)
        case .licenseChangelog: licenseChangelogPlan(state: state, license: options.license)
        case .privacyManifest: privacyManifestPlan(state: state)
        case .appIconValidation: appIconValidationPlan(state: state)
        case .localization: localizationPlan(state: state, locales: options.locales)
        case .macCatalyst: try macCatalystPlan(state: state)
        case .lottie: try lottiePlan(state: state)
        case .widget: widgetPlan(state: state, bundleIDFlag: options.bundleID)
        }
    }

    /// The bundle ID the widget is built under: the app target's own (the
    /// widget's must extend it), else `--bundle-id`, else the default
    /// `new app` would pick.
    static func widgetBundleID(state: ProjectState, flag: String?) -> String {
        state.bundleID ?? flag ?? Validators.defaultBundleID(for: state.name)
    }

    // MARK: - Tier 1

    private static func devToolingPlan(state: ProjectState) -> AddPlan {
        var plan = AddPlan(featureName: AddableFeature.devTooling.displayName)
        plan.writes.append(.group(paths: [".swiftlint.yml", ".swiftformat", "Makefile", "Brewfile"]) { policy in
            try FileWriter.writeToolingFiles(
                projectType: state.type,
                appName: state.name,
                hasRSwift: state.hasRSwift,
                hasFastlane: state.hasFastlane,
                hasGitHooks: state.hasGitHooks,
                hasDefaultIsolation: state.packageRequiresXcodebuild,
                hasLocalization: state.hasLocalizationAudit,
                hasAppIconValidation: state.hasAppIconValidation,
                projectSystem: state.projectSystem,
                basePath: state.root,
                xcodeBuildScheme: state.xcodeBuildScheme,
                disableTestParallelism: state.disableTestParallelism,
                hasMacCatalyst: state.hasMacCatalyst,
                hasWidget: state.hasWidget,
                ifExists: policy
            )
        })
        return plan
    }

    private static func gitHooksPlan(state: ProjectState) -> AddPlan {
        var plan = AddPlan(featureName: AddableFeature.gitHooks.displayName)
        let options: GitHooksGenerator.Options = state.needsCoreDataAuditHook ? .withCoreDataAudit : .basic
        plan.writes.append(.group(paths: ["Scripts/git-hooks/pre-commit"]) { policy in
            try FileWriter.writeGitHooks(basePath: state.root, options: options, ifExists: policy)
        })
        plan.notes = ["Activate the hook with: git config core.hooksPath Scripts/git-hooks"]
        return plan
    }

    private static func claudeMDPlan(state: ProjectState) -> AddPlan {
        var plan = AddPlan(featureName: AddableFeature.claudeMD.displayName)
        // The logging section and the CLI layout section describe files
        // `new` writes; they appear only when the project has those files.
        let content = switch state.type {
        case .app: ClaudeMDGenerator.generateForApp(config: state.appConfig())
        case .package: ClaudeMDGenerator.generateForPackage(config: state.packageConfig, logCore: state.logCore)
        case .cli: ClaudeMDGenerator.generateForCLI(config: state.cliConfig, includeLayout: state.hasCLIKitLibrary)
        }
        plan.writes = [.file(path: ".claude/CLAUDE.md", content: content, executable: false)]
        return plan
    }

    private static func licenseChangelogPlan(state: ProjectState, license: LicenseType?) -> AddPlan {
        var plan = AddPlan(featureName: AddableFeature.licenseChangelog.displayName)
        let licenseType = license ?? LicenseType.defaultFor(state.type)
        let author = GitRunner.authorNameOrPlaceholder()
        plan.writes.append(.group(paths: ["LICENSE", "CHANGELOG.md"]) { policy in
            try FileWriter.writeOptionalFiles(
                claudeMDContent: nil,
                licenseAuthor: author,
                licenseType: licenseType,
                projectName: state.name,
                basePath: state.root,
                ifExists: policy
            )
        })
        return plan
    }

    private static func privacyManifestPlan(state: ProjectState) -> AddPlan {
        var plan = AddPlan(featureName: AddableFeature.privacyManifest.displayName)
        let appManifest = "\(state.name)/Resources/PrivacyInfo.xcprivacy"
        // The same required-reason categories `new` declares for the app's own code.
        let categories = PrivacyInfoGenerator.appCategories(hasCloudKit: state.hasCloudKit, hasLumiKit: state.linksLumiKit)
        plan.writes = [.file(path: appManifest, content: PrivacyInfoGenerator.generate(role: .app, categories: categories), executable: false)]
        if state.hasWidget {
            plan.writes.append(.file(
                path: "\(state.name)Widget/PrivacyInfo.xcprivacy",
                content: PrivacyInfoGenerator.generate(role: .extensionTarget),
                executable: false
            ))
        }
        if state.projectSystem == .xcodeProj {
            plan.notes.append("Add \(appManifest) to the app target's Copy Bundle Resources phase.")
        }
        plan.notes += [
            "Edit before submission if you actually track users or collect data.",
            "Reference: https://developer.apple.com/documentation/bundleresources/privacy_manifest_files",
        ]
        return plan
    }

    private static func appIconValidationPlan(state: ProjectState) -> AddPlan {
        var plan = AddPlan(featureName: AddableFeature.appIconValidation.displayName)
        let iconset = state.appIconSetPath ?? "\(state.name)/Resources/Assets.xcassets/AppIcon.appiconset"
        plan.writes.append(.file(
            path: "Scripts/validate-app-icon.sh",
            content: AppIconValidationGenerator.generate(iconsetRelativePath: iconset),
            executable: true
        ))
        plan.notes = [
            "Wire into Xcode as a Run Script build phase, or call from CI.",
            "Script path: Scripts/validate-app-icon.sh",
        ] + makefileNote(state: state, targets: "`validate-icon` target and `make check` doesn't run the icon check")
        return plan
    }

    /// `add` keeps an existing Makefile, so a feature with its own make
    /// targets says how to get them.
    private static func makefileNote(state: ProjectState, targets: String) -> [String] {
        guard state.hasDevTooling else { return [] }
        return ["The existing Makefile is kept, so it has no \(targets). Run `monolith add devTooling --force` to regenerate it (this replaces Makefile edits)."]
    }

    // MARK: - Tier 2: Localization

    private static func localizationPlan(state: ProjectState, locales: [String]) -> AddPlan {
        var plan = AddPlan(featureName: AddableFeature.localization.displayName)
        let config = state.appConfig(extraFeatures: [.localization], locales: locales)
        let catalog = "\(state.name)/Resources/Localizable.xcstrings"

        // A second Localizable.xcstrings elsewhere in the target would make
        // two build outputs of the same name, so an existing catalog stays the
        // only one (at its own path, written by `--force` only).
        if let existing = state.stringCatalogs.first, existing != catalog {
            plan.notes.append("Kept the existing string catalog at \(existing).")
        } else {
            plan.writes.append(.file(path: catalog, content: LocalizationGenerator.generateStringCatalog(config: config), executable: false))
        }
        plan.writes += [
            .file(path: "\(state.name)/Core/L10n.swift", content: LocalizationGenerator.generateL10n(config: config), executable: false),
            .file(
                path: "Scripts/localization/audit_strings.py",
                content: LocalizationAuditGenerator.generate(appName: state.name),
                executable: true
            ),
        ]

        // XcodeGen scans `sources: [<App>]` recursively, so project.yml needs no edit.
        if state.projectSystem == .xcodeProj {
            plan.manualSteps = [
                "Add Localizable.xcstrings to the app target's Resources phase.",
                "Add L10n.swift to the app target's Compile Sources phase.",
            ]
        } else {
            plan.notes.append("Re-run `xcodegen generate` to pick up the new files.")
        }
        plan.notes += makefileNote(state: state, targets: "`audit-strings` target and `make check` doesn't audit the catalog")
        return plan
    }

    // MARK: - Tier 2: Mac Catalyst

    private static func macCatalystPlan(state: ProjectState) throws -> AddPlan {
        var plan = AddPlan(featureName: AddableFeature.macCatalyst.displayName)
        let name = state.name
        let width = MacCatalystGenerator.minimumWindowWidth
        let height = MacCatalystGenerator.minimumWindowHeight

        if state.linksLumiKit {
            // A LumiKit app sets up its window with `LMKScene.configureMacWindow`, as the
            // scene delegate of a new LumiKit app does; a MacWindowConfig would duplicate it.
            if !state.configuresMacWindow {
                plan.notes += [
                    "LumiKit app: no MacWindowConfig.swift. In `scene(_:willConnectTo:options:)`, call:",
                    "",
                    "    LMKScene.configureMacWindow(",
                    "        for: windowScene,",
                    "        minimumSize: CGSize(width: AppConstants.MacWindow.minWidth, height: AppConstants.MacWindow.minHeight),",
                    "        hidesTitleBar: true // false under the Mac idiom, where navigation bars live in the window toolbar",
                    "    )",
                ]
                if !state.definesMacWindowConstants {
                    plan.warnings.append("""
                    \(name)/Core/AppConstants.swift has no `MacWindow`. Add to `AppConstants`: \
                    enum MacWindow { static let minWidth: CGFloat = \(width); static let minHeight: CGFloat = \(height) }
                    """)
                }
            }
        } else {
            plan.writes.append(.file(
                path: "\(name)/MacCatalyst/MacWindowConfig.swift",
                content: MacCatalystGenerator.generateWindowConfig(inlineConstants: !state.definesMacWindowConstants),
                executable: false
            ))
            if !state.configuresMacWindow {
                plan.notes += [
                    "In SceneDelegate's `scene(_:willConnectTo:options:)`, after unwrapping `windowScene`, call:",
                    "",
                    "    #if targetEnvironment(macCatalyst)",
                    "        MacWindowConfig.configure(windowScene)",
                    "    #endif",
                ]
            }
        }

        // The Mac build signs with its own entitlements: the iOS keys plus
        // what `new` writes for every Catalyst app (the App Sandbox and
        // outgoing network access a Mac App Store app needs).
        let catalystBase = try EntitlementsMerger.parse(
            EntitlementsGenerator.macCatalystEntitlements(appGroup: nil, cloudKitContainer: nil, apsEnvironment: nil),
            path: state.catalystEntitlementsPath
        )
        let additions = try iOSEntitlements(state: state).merging(catalystBase) { _, catalyst in catalyst }
        plan.writes.append(.entitlements(
            path: state.catalystEntitlementsPath,
            additions: additions,
            summary: "App Sandbox, outgoing network, and the iOS entitlements"
        ))

        let catalystEntitlements = state.catalystEntitlementsPath
        plan.yamlEdit = { yaml in
            ProjectYamlEditor.enableMacCatalyst(yaml: &yaml, targetName: name, catalystEntitlements: catalystEntitlements)
        }
        plan.manualSteps = [
            "Select the app target → General → Supported Destinations → add `Mac (Mac Catalyst)`.",
            "Build Settings → Code Signing Entitlements: add a macOS SDK condition (`CODE_SIGN_ENTITLEMENTS[sdk=macosx*]`) set to \(catalystEntitlements).",
        ]
        if !state.hasCategory {
            plan.manualSteps.append("Set the App Category (`INFOPLIST_KEY_LSApplicationCategoryType`), e.g. public.app-category.utilities.")
        }
        if !state.platforms.contains(.iPad) {
            plan.manualSteps.append("Add iPad to Targeted Device Families (`TARGETED_DEVICE_FAMILY` = 1,2): Mac Catalyst runs the iPad idiom.")
        }
        if state.hasWidget {
            plan.manualSteps.append("Build Phases → Embed Foundation Extensions: filter the widget to iOS (it can't be embedded in the Mac build).")
        }
        plan.manualSteps.append("Build the project against the Mac Catalyst SDK to validate.")
        if state.projectSystem != .xcodeProj, !state.platforms.contains(.iPad) {
            plan.notes.append("Adds iPad to TARGETED_DEVICE_FAMILY in project.yml: Mac Catalyst runs the iPad idiom.")
        }
        plan.notes += makefileNote(state: state, targets: "`build-catalyst`, `archive-mac`, or `release-mac` targets")
        return plan
    }

    /// The app's iOS entitlements, or none when it has no file yet.
    private static func iOSEntitlements(state: ProjectState) throws -> [String: Any] {
        guard let plist = state.read(state.appEntitlementsPath) else { return [:] }
        return try EntitlementsMerger.parse(plist, path: state.appEntitlementsPath)
    }

    // MARK: - Tier 2: Lottie

    private static func lottiePlan(state: ProjectState) throws -> AddPlan {
        guard let lottie = KnownPackages.registry["Lottie"] else {
            throw ValidationError("Lottie is missing from the package registry.")
        }
        var plan = AddPlan(featureName: lottie.name)
        let name = state.name
        plan.writes.append(.file(
            path: "\(name)/Shared/Components/LottieHelper.swift",
            content: LottieGenerator.generateHelper(),
            executable: false
        ))
        plan.yamlEdit = { yaml in
            ProjectYamlEditor.addPackageDependency(
                yaml: &yaml,
                targetName: name,
                packageName: lottie.name,
                url: lottie.url,
                from: lottie.defaultVersion,
                targetPlatforms: lottie.platforms
            )
        }
        plan.manualSteps = [
            "Open the project in Xcode.",
            "File → Add Package Dependencies… → \(lottie.url) → Up to Next Major from \(lottie.defaultVersion).",
            "Add the resolved product to \(name)'s target.",
        ]
        return plan
    }

    // MARK: - Tier 2: Widget

    private static func widgetPlan(state: ProjectState, bundleIDFlag: String?) -> AddPlan {
        var plan = AddPlan(featureName: "Widget extension")
        let appName = state.name
        let bundleID = widgetBundleID(state: state, flag: bundleIDFlag)
        let appGroup = "group.\(bundleID)"
        if let bundleIDFlag, let projectBundleID = state.bundleID, bundleIDFlag != projectBundleID {
            plan.warnings.append("Ignored --bundle-id \(bundleIDFlag): the widget must extend the app's bundle ID, \(projectBundleID).")
        }

        plan.writes = WidgetExtensionGenerator.files(appName: appName, appGroup: appGroup).map {
            .file(path: $0.path, content: $0.content, executable: false)
        }
        let groupAdditions = EntitlementsMerger.appGroupAdditions(appGroup)
        plan.writes.append(.entitlements(path: state.appEntitlementsPath, additions: groupAdditions, summary: "App Group \(appGroup)"))
        if state.hasMacCatalyst, state.exists(state.catalystEntitlementsPath) {
            plan.writes.append(.entitlements(path: state.catalystEntitlementsPath, additions: groupAdditions, summary: "App Group \(appGroup)"))
        }

        let entitlementsPath = state.appEntitlementsPath
        plan.yamlEdit = { yaml in
            let widgetResult = ProjectYamlEditor.addWidgetTarget(yaml: &yaml, appName: appName, bundleID: bundleID)
            if case .failed = widgetResult { return widgetResult }
            let appResult = ProjectYamlEditor.wireAppForWidget(yaml: &yaml, appName: appName, entitlementsPath: entitlementsPath)
            if case .failed = appResult { return appResult }
            return widgetResult == .applied || appResult == .applied ? .applied : .alreadyPresent
        }
        let widgetDir = "\(appName)Widget"
        plan.manualSteps = [
            "Add a new Widget Extension target named `\(widgetDir)` with bundle ID \(bundleID).Widget.",
            "Point its Info.plist at \(widgetDir)/Info.plist and its entitlements at \(widgetDir)/\(widgetDir).entitlements.",
        ]
        if !state.setsAppEntitlements {
            plan.manualSteps.append("Set CODE_SIGN_ENTITLEMENTS on the app target to \(entitlementsPath).")
        }
        plan.manualSteps += [
            "Turn on the App Group `\(appGroup)` for both targets (Signing & Capabilities).",
            "Move the generated Swift files and PrivacyInfo.xcprivacy into the widget target.",
            "Add AppGroup.swift to BOTH the app target's and the widget target's Compile Sources phases (so neither hardcodes the App Group id).",
        ]
        if state.hasMacCatalyst {
            plan.manualSteps.append("Filter the widget's embed to iOS (Build Phases → Embed Foundation Extensions); it can't be embedded in the Mac build.")
        }
        return plan
    }
}
