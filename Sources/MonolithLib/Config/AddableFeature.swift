/// Features that can be added to existing projects.
///
/// Two tiers:
///
/// **Tier 1 — pure additive (any project system)**
/// Writes files only, never edits existing files. Safe on `.xcodeproj`, XcodeGen,
/// and SPM projects alike.
///
/// **Tier 2 — XcodeGen-friendly (app projects only)**
/// Writes new source files AND edits `project.yml` to wire them in. On
/// `.xcodeproj` projects the source files are still written, but the user is
/// responsible for adding Target Membership / SPM dependencies manually
/// (the command prints the required steps).
enum AddableFeature: String, CaseIterable {
    // Tier 1
    case devTooling
    case gitHooks
    case claudeMD
    case licenseChangelog
    case privacyManifest
    case appIconValidation

    // Tier 2 (app-only)
    case localization
    case macCatalyst
    case lottie
    case snapKit
    case lookin
    case widget

    var displayName: String {
        switch self {
        case .devTooling: "Dev tooling (SwiftLint + SwiftFormat + Makefile + Brewfile)"
        case .gitHooks: "Git hooks (pre-commit lint + format)"
        case .claudeMD: "CLAUDE.md"
        case .licenseChangelog: "LICENSE + CHANGELOG"
        case .privacyManifest: "PrivacyInfo.xcprivacy (App Store requirement)"
        case .appIconValidation: "App icon alpha validation script"
        case .localization: "Localization (String Catalog + L10n.swift)"
        case .macCatalyst: "Mac Catalyst support"
        case .lottie: "Lottie (animations)"
        case .snapKit: "SnapKit (Auto Layout DSL)"
        case .lookin: "LookinServer (UI debugging, iOS only)"
        case .widget: "Widget extension (WidgetKit + App Group)"
        }
    }

    /// Whether this feature requires an app project (i.e. is not valid for
    /// Swift packages or CLIs).
    var requiresAppProject: Bool {
        switch self {
        case .devTooling, .gitHooks, .claudeMD, .licenseChangelog:
            false
        case .privacyManifest, .appIconValidation,
             .localization, .macCatalyst, .lottie, .snapKit, .lookin, .widget:
            true
        }
    }

    /// Whether this feature edits `project.yml` (XcodeGen) or `.pbxproj` to wire
    /// the new files into the build. Tier 2 features return `true`; Tier 1
    /// features return `false`.
    var needsProjectSystemEdit: Bool {
        switch self {
        case .devTooling, .gitHooks, .claudeMD, .licenseChangelog,
             .privacyManifest, .appIconValidation:
            false
        case .localization, .macCatalyst, .lottie, .snapKit, .lookin, .widget:
            true
        }
    }

    /// Files this feature writes (relative paths). Used for dry-run preview.
    /// `appName` is required for app-only features.
    func filePaths(projectType: ProjectType, appName: String?) -> [String] {
        let name = appName ?? "App"
        switch self {
        case .devTooling:
            return [".swiftlint.yml", ".swiftformat", "Makefile", "Brewfile"]
        case .gitHooks:
            return ["Scripts/git-hooks/pre-commit"]
        case .claudeMD:
            return [".claude/CLAUDE.md"]
        case .licenseChangelog:
            return ["LICENSE", "CHANGELOG.md"]
        case .privacyManifest:
            return ["\(name)/Resources/PrivacyInfo.xcprivacy"]
        case .appIconValidation:
            return ["Scripts/validate-app-icon.sh"]
        case .localization:
            return [
                "\(name)/Resources/Localizable.xcstrings",
                "\(name)/Core/L10n.swift",
                "Scripts/localization/audit_strings.py",
            ]
        case .macCatalyst:
            return ["\(name)/MacCatalyst/MacWindowConfig.swift"]
        case .lottie:
            return ["\(name)/Shared/Components/LottieHelper.swift"]
        case .snapKit, .lookin:
            // SPM-only dependency: no file write, just project.yml edit.
            return []
        case .widget:
            return [
                "\(name)Widget/Info.plist",
                "\(name)Widget/\(name)Widget.entitlements",
                "\(name)Widget/\(name)WidgetBundle.swift",
                "\(name)Widget/\(name)Widget.swift",
                "\(name)/Shared/AppGroup.swift",
            ]
        }
    }
}
