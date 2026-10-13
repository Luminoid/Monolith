/// Features that can be added to existing projects.
///
/// Two tiers:
///
/// **Tier 1: new files only (any project system)**
/// Writes files and never edits existing ones: a file that is already there
/// is kept unless `add --force`. Safe on `.xcodeproj`, XcodeGen, and SPM
/// projects alike.
///
/// **Tier 2: XcodeGen-friendly (app projects only)**
/// Writes new source files (same keep-unless-`--force` rule), merges keys
/// into the app's entitlements (never replacing them), and edits
/// `project.yml` to wire it all in. On `.xcodeproj` projects the files are
/// still written, but the user adds Target Membership / SPM dependencies by
/// hand (the command prints the required steps).
///
/// `AddFeatureHandlers.plan` lists exactly what each feature writes, for both
/// the real run and `--dry-run`.
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
             .localization, .macCatalyst, .lottie, .widget:
            true
        }
    }

    /// Whether this feature edits `project.yml` (XcodeGen) or needs manual
    /// `.xcodeproj` steps to wire the new files into the build. Tier 2
    /// features return `true`; Tier 1 features return `false`.
    var needsProjectSystemEdit: Bool {
        switch self {
        case .devTooling, .gitHooks, .claudeMD, .licenseChangelog,
             .privacyManifest, .appIconValidation:
            false
        case .localization, .macCatalyst, .lottie, .widget:
            true
        }
    }

    /// The raw values, comma-separated, for help text and error messages.
    static var allNames: String {
        allCases.map(\.rawValue).joined(separator: ", ")
    }
}
