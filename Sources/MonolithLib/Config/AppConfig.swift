struct AppConfig: Codable {
    let name: String
    let bundleID: String
    let deploymentTarget: String
    let platforms: Set<Platform>
    let projectSystem: ProjectSystem
    let tabs: [TabDefinition]
    let primaryColor: String
    let features: Set<AppFeature>
    let author: String
    let licenseType: LicenseType
    /// Third-party SPM packages declared via `--external-packages` (matches the
    /// `monolith new package` surface). Empty by default; entries are wired into
    /// the generated `project.yml` (`packages:` block) or `Package.swift`
    /// (`dependencies:` list) depending on `projectSystem`.
    let externalPackages: [ExternalPackage]
    /// Product names to link into the app's main target via `--target-deps`.
    /// Each must resolve to an `externalPackages` entry (by name, by longest
    /// name prefix, or as the only external), or to a product a feature wires
    /// (LumiKit products with `lumiKit`, Lottie with `lottie`); `validate()`
    /// rejects anything else. The app generator emits one `- package:` /
    /// `.product(...)` entry per dep, de-duplicated against the feature wiring.
    let targetDependencies: [String]
    /// Locale identifiers for the generated `Localizable.xcstrings` catalog
    /// (e.g. `["en", "zh-Hans", "es"]`). First entry is the source language.
    /// Defaults to `["en"]`; apps that ship more languages pass them with
    /// `--locales`. Ignored when `hasLocalization` is false.
    let locales: [String]
    /// LSApplicationCategoryType (App Store category). Required for Mac App
    /// Store distribution. Defaults to `public.app-category.utilities` when
    /// the platform set includes `macCatalyst`; nil otherwise. Adopters
    /// should pick the appropriate `public.app-category.<X>` value before
    /// release (see Apple's LSApplicationCategoryType documentation).
    let applicationCategory: String?

    /// Memberwise init with defaults for the new external-package fields so
    /// existing call sites (and ~60 test fixtures) stay compiling.
    init(
        name: String,
        bundleID: String,
        deploymentTarget: String,
        platforms: Set<Platform>,
        projectSystem: ProjectSystem,
        tabs: [TabDefinition],
        primaryColor: String,
        features: Set<AppFeature>,
        author: String,
        licenseType: LicenseType,
        externalPackages: [ExternalPackage] = [],
        targetDependencies: [String] = [],
        locales: [String] = ["en"],
        applicationCategory: String? = nil
    ) {
        self.name = name
        self.bundleID = bundleID
        self.deploymentTarget = deploymentTarget
        self.platforms = platforms
        self.projectSystem = projectSystem
        self.tabs = tabs
        self.primaryColor = primaryColor
        self.features = features
        self.author = author
        self.licenseType = licenseType
        self.externalPackages = externalPackages
        self.targetDependencies = targetDependencies
        self.locales = locales
        self.applicationCategory = applicationCategory
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case name, bundleID, deploymentTarget, platforms, projectSystem, tabs, primaryColor
        case features, author, licenseType, externalPackages, targetDependencies, locales, applicationCategory
    }

    /// Custom Codable so older saved configs decode cleanly: fields added
    /// after 0.1.0 (including `licenseType`) fall back to their defaults, and
    /// a removed or unknown feature name fails with the same message the
    /// `--features` flag gives.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.bundleID = try container.decode(String.self, forKey: .bundleID)
        self.deploymentTarget = try container.decode(String.self, forKey: .deploymentTarget)
        self.platforms = try container.decode(Set<Platform>.self, forKey: .platforms)
        self.projectSystem = try container.decode(ProjectSystem.self, forKey: .projectSystem)
        self.tabs = try container.decodeIfPresent([TabDefinition].self, forKey: .tabs) ?? []
        self.primaryColor = try container.decode(String.self, forKey: .primaryColor)
        self.features = try container.decodeFeatures(AppFeature.self, forKey: .features, migration: AppFeature.removedAliasMigration)
        self.author = try container.decode(String.self, forKey: .author)
        self.licenseType = try container.decodeIfPresent(LicenseType.self, forKey: .licenseType) ?? LicenseType.defaultFor(.app)
        self.externalPackages = try container.decodeIfPresent([ExternalPackage].self, forKey: .externalPackages) ?? []
        self.targetDependencies = try container.decodeIfPresent([String].self, forKey: .targetDependencies) ?? []
        self.locales = try container.decodeIfPresent([String].self, forKey: .locales) ?? ["en"]
        self.applicationCategory = try container.decodeIfPresent(String.self, forKey: .applicationCategory)
    }

    /// Sets encode as sorted arrays so a saved config is deterministic.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(bundleID, forKey: .bundleID)
        try container.encode(deploymentTarget, forKey: .deploymentTarget)
        try container.encode(platforms.sortedRawValues, forKey: .platforms)
        try container.encode(projectSystem, forKey: .projectSystem)
        try container.encode(tabs, forKey: .tabs)
        try container.encode(primaryColor, forKey: .primaryColor)
        try container.encode(features.sortedRawValues, forKey: .features)
        try container.encode(author, forKey: .author)
        try container.encode(licenseType, forKey: .licenseType)
        try container.encode(externalPackages, forKey: .externalPackages)
        try container.encode(targetDependencies, forKey: .targetDependencies)
        try container.encode(locales, forKey: .locales)
        try container.encodeIfPresent(applicationCategory, forKey: .applicationCategory)
    }

    /// Resolved features including auto-derived ones.
    var resolvedFeatures: Set<AppFeature> {
        var resolved = features

        // Tabs feature is derived from non-empty tabs array
        if !tabs.isEmpty {
            resolved.insert(.tabs)
        }

        // Mac Catalyst feature is auto-enabled when platform is selected
        if platforms.contains(.macCatalyst) {
            resolved.insert(.macCatalyst)
        }

        // Dark mode is auto-enabled when LumiKit is selected
        // (LumiKit includes full theme support which supersedes standalone dark mode)
        if resolved.contains(.lumiKit) {
            resolved.insert(.darkMode)
        }

        // CloudKit sharing implies CloudKit
        if resolved.contains(.cloudKitSharing) {
            resolved.insert(.cloudKit)
        }

        // CloudKit requires either Core Data or SwiftData. If neither is selected,
        // default to Core Data (the more stable CloudKit-backed persistence layer).
        if resolved.contains(.cloudKit), !resolved.contains(.swiftData), !resolved.contains(.coreData) {
            resolved.insert(.coreData)
        }

        // Auto-derive the Core Data audit hook when both persistence + CloudKit are active.
        if resolved.contains(.cloudKit), resolved.contains(.gitHooks),
           resolved.contains(.coreData) || resolved.contains(.swiftData) {
            resolved.insert(.coreDataAuditHook)
        }

        return resolved
    }

    /// Whether the app uses SwiftData.
    var hasSwiftData: Bool {
        resolvedFeatures.contains(.swiftData)
    }

    /// Whether the app uses LumiKit.
    var hasLumiKit: Bool {
        resolvedFeatures.contains(.lumiKit)
    }

    /// Whether the app pulls in SnapKit. Sourced from `--use-packages SnapKit`,
    /// `--external-packages`, OR the `lumiKit` feature — `LumiKitUI` declares
    /// SnapKit as a direct dependency, so any app linking `LumiKitUI`
    /// transitively links SnapKit and can `import SnapKit` without an extra
    /// package wire. Without this transitive check, a LumiKit app without an
    /// explicit `--use-packages SnapKit` would emit a `ViewController` built
    /// on bare `NSLayoutConstraint` even though SnapKit is available, while
    /// the generated layout code uses SnapKit whenever it can.
    var hasSnapKit: Bool {
        if externalPackages.contains(where: { $0.spmPackageName == "SnapKit" }) {
            return true
        }
        return hasLumiKit
    }

    /// Whether the app uses Lottie. Still a feature because Monolith emits
    /// a `LottieHelper.swift` starter template (not just a dep wire).
    var hasLottie: Bool {
        resolvedFeatures.contains(.lottie)
    }

    /// Whether the app pulls in LookinServer (iOS-only debug overlay).
    /// Sourced from `--use-packages LookinServer` or `--external-packages`.
    var hasLookin: Bool {
        externalPackages.contains(where: { $0.spmPackageName == "LookinServer" })
    }

    /// Whether the app supports dark mode (standalone or via LumiKit).
    var hasDarkMode: Bool {
        resolvedFeatures.contains(.darkMode)
    }

    /// Whether the app includes Combine/async patterns.
    var hasCombine: Bool {
        resolvedFeatures.contains(.combine)
    }

    /// Whether the app uses dev tooling.
    var hasDevTooling: Bool {
        resolvedFeatures.contains(.devTooling)
    }

    /// Whether the app uses git hooks.
    var hasGitHooks: Bool {
        resolvedFeatures.contains(.gitHooks)
    }

    /// Whether the app includes localization support.
    var hasLocalization: Bool {
        resolvedFeatures.contains(.localization)
    }

    /// Whether the app has tabs.
    var hasTabs: Bool {
        !tabs.isEmpty
    }

    /// Whether the app targets Mac Catalyst.
    var hasMacCatalyst: Bool {
        platforms.contains(.macCatalyst)
    }

    /// `TARGETED_DEVICE_FAMILY` for the app target: `1` for iPhone, `2` for
    /// iPad. Mac Catalyst runs the iPad idiom, so it needs `2` as well.
    var targetedDeviceFamily: String {
        var families: [String] = []
        if platforms.contains(.iPhone) { families.append("1") }
        if platforms.contains(.iPad) || platforms.contains(.macCatalyst) { families.append("2") }
        return families.isEmpty ? "1,2" : families.joined(separator: ",")
    }

    /// Whether the app uses Core Data for persistence.
    var hasCoreData: Bool {
        resolvedFeatures.contains(.coreData)
    }

    /// Whether the app syncs persistence through CloudKit.
    var hasCloudKit: Bool {
        resolvedFeatures.contains(.cloudKit)
    }

    /// Whether the app accepts CloudKit shares (Family Sharing-style).
    var hasCloudKitSharing: Bool {
        resolvedFeatures.contains(.cloudKitSharing)
    }

    /// Whether the app registers for CloudKit silent push notifications.
    /// Auto-enabled with CloudKit; the AppDelegate calls
    /// `registerForRemoteNotifications()` and the Info.plist declares
    /// `UIBackgroundModes: remote-notification`.
    var hasCloudKitNotifications: Bool {
        hasCloudKit
    }

    /// Whether the app uses UNUserNotificationCenter (foreground notifications).
    var hasNotifications: Bool {
        resolvedFeatures.contains(.notifications)
    }

    /// Whether the app handles deep links via URL scheme.
    var hasDeepLinks: Bool {
        resolvedFeatures.contains(.deepLinks)
    }

    /// Whether the app handles Spotlight CSSearchable item activations.
    var hasSpotlight: Bool {
        resolvedFeatures.contains(.spotlight)
    }

    /// Whether the SceneDelegate emits a `deferLaunchWork()` helper.
    var hasDeferredLaunchWork: Bool {
        resolvedFeatures.contains(.deferredLaunchWork)
    }

    /// Whether the app generates a WidgetKit extension target.
    var hasWidget: Bool {
        resolvedFeatures.contains(.widget)
    }

    /// Whether to emit `PrivacyInfo.xcprivacy` files (app + every extension).
    /// Strongly recommended for App Store submissions.
    var hasPrivacyManifest: Bool {
        resolvedFeatures.contains(.privacyManifest)
    }

    /// Whether to emit the app icon alpha-channel validator script.
    var hasAppIconValidation: Bool {
        resolvedFeatures.contains(.appIconValidation)
    }

    /// Whether the pre-commit hook includes the Core Data audit reminder.
    var hasCoreDataAuditHook: Bool {
        resolvedFeatures.contains(.coreDataAuditHook)
    }

    /// Whether the project emits a CLAUDE.md guide for Claude Code.
    var hasClaudeMD: Bool {
        resolvedFeatures.contains(.claudeMD)
    }

    /// Whether the project emits LICENSE + CHANGELOG.md.
    var hasLicenseChangelog: Bool {
        resolvedFeatures.contains(.licenseChangelog)
    }

    /// Whether the project emits legacy Fastlane infrastructure
    /// (Gemfile + fastlane/Appfile + fastlane/Fastfile). Discouraged for new
    /// projects; surfaces a deprecation warning at config time.
    var hasFastlane: Bool {
        resolvedFeatures.contains(.fastlane)
    }

    /// Whether the project emits legacy R.swift infrastructure (Mintfile).
    /// Discouraged for new projects; Xcode 15+ ships native type-safe asset
    /// accessors that supersede it.
    var hasRSwift: Bool {
        resolvedFeatures.contains(.rSwift)
    }

    /// App Group identifier for sharing data with extensions (widget, share).
    /// Derived from the bundle ID with a `group.` prefix.
    var appGroupIdentifier: String {
        "group.\(bundleID)"
    }

    /// Warnings about deprecated or legacy features. `new app` prints them
    /// with `Console.warn`, which adds the warning marker.
    var deprecationWarnings: [String] {
        var warnings: [String] = []
        if features.contains(.rSwift) {
            warnings.append(
                "rSwift is supported for legacy projects only. Xcode 15+ has native type-safe resource accessors that supersede it. Consider omitting --features rSwift."
            )
        }
        if features.contains(.fastlane) {
            warnings.append(
                "fastlane is supported for legacy projects only. Prefer the generated Makefile targets or Xcode Cloud for new projects. Consider omitting --features fastlane."
            )
        }
        return warnings
    }

    /// Every check an app config must pass before generation: the name,
    /// bundle ID, deployment target, primary color, project system,
    /// platforms, tabs, locales, external packages, and the rules in
    /// `validate()`. Run on every config, including one loaded with
    /// `--load-config`, which never meets the flag parsers.
    func validateForGeneration() throws {
        if let problem = Validators.projectNameProblem(name, kind: .app) {
            throw ConfigValidationError(problem)
        }
        guard Validators.validateBundleID(bundleID) else {
            throw ConfigValidationError(
                "Invalid bundle ID '\(bundleID)'. Must be reverse-DNS format with ASCII letters, digits, and hyphens, each segment starting with a letter (e.g., com.company.app)."
            )
        }
        guard Validators.validateDeploymentTarget(deploymentTarget) else {
            throw ConfigValidationError(
                "Invalid deployment target '\(deploymentTarget)'. Must be major.minor format >= \(Validators.minimumDeploymentMajor).0."
            )
        }
        guard Validators.validateHexColor(primaryColor) else {
            throw ConfigValidationError("Invalid primary color '\(primaryColor)'. Must be #RRGGBB format.")
        }
        guard projectSystem.isSupportedForApps else {
            throw ConfigValidationError(
                "projectSystem '\(projectSystem.rawValue.lowercased())' is not supported for apps: \(ProjectSystem.unsupportedForAppsReason)"
            )
        }
        guard !platforms.isEmpty else {
            throw ConfigValidationError("An app needs at least one platform: \(Platform.allCases.map(\.rawValue).joined(separator: ", ")).")
        }
        try validateTabs()
        try validateLocales()
        for ext in externalPackages {
            if let problem = ext.validationProblem {
                throw ConfigValidationError(problem)
            }
        }
        try validate()
    }

    /// Tab names become type names (`<Name>ViewController`) and lowerCamel
    /// case names (`case home`), so each must be a Swift identifier whose
    /// lowerCamel form isn't a keyword, unique ignoring case (the
    /// localization key lowercases it). Icons are SF Symbol names.
    private func validateTabs() throws(ConfigValidationError) {
        for tab in tabs {
            let caseName = tab.name.prefix(1).lowercased() + tab.name.dropFirst()
            guard Validators.isASCIIIdentifier(tab.name),
                  !Validators.reservedNames.contains(tab.name),
                  !Validators.reservedNames.contains(caseName)
            else {
                throw ConfigValidationError(
                    "Invalid tab name '\(tab.name)'. Tab names become Swift type names: an ASCII letter, then letters, digits, or underscores, and not a Swift keyword (e.g. Home)."
                )
            }
            guard !tab.icon.trimmingCharacters(in: .whitespaces).isEmpty, !tab.icon.contains("\"") else {
                throw ConfigValidationError("Tab '\(tab.name)' needs an SF Symbol icon name (e.g. 'Home:house').")
            }
        }
        let duplicates = DuplicateNames.find(in: tabs.map(\.name), ignoringCase: true)
        guard duplicates.isEmpty else {
            throw ConfigValidationError("--tabs lists \(duplicates.map { "'\($0)'" }.joined(separator: ", ")) more than once (ignoring case).")
        }
    }

    private func validateLocales() throws(ConfigValidationError) {
        for locale in locales where !Validators.validateLocale(locale) {
            throw ConfigValidationError("Invalid locale '\(locale)'. Use a language code with optional subtags, e.g. en, zh-Hans, pt-BR.")
        }
        let duplicates = DuplicateNames.find(in: locales, ignoringCase: true)
        guard duplicates.isEmpty else {
            throw ConfigValidationError("--locales lists \(duplicates.map { "'\($0)'" }.joined(separator: ", ")) more than once.")
        }
    }

    /// Validates the persistence features, `externalPackages`, and
    /// `targetDependencies`.
    ///
    /// Rules:
    /// 1. One persistence layer: `swiftData` and `coreData` both generate a
    ///    `SampleItem` model, and CloudKit sharing needs Core Data's shared
    ///    store, which SwiftData lacks.
    /// 2. External package names are unique and don't collide with the app
    ///    target name.
    /// 3. Every target-dep resolves: to an external (direct name match,
    ///    longest-prefix match, or the only external, through
    ///    `XcodeGenGenerator.routeProductToPackage`), or to a product a
    ///    feature wires (LumiKit products with `lumiKit`, Lottie with
    ///    `lottie`). A case-insensitive match or a bare package name is
    ///    reported as a typo; a registry product nothing wires names the flag
    ///    that wires it.
    /// 4. Every external is linked: some target-dep routes to it, or a
    ///    feature links its package (an external overriding LumiKit or
    ///    Lottie). An unlinked external is still declared in the project but
    ///    no target uses it.
    func validate() throws(AppConfigError) {
        // 1. Persistence.
        if features.contains(.swiftData), features.contains(.coreData) {
            throw .conflictingPersistence
        }
        if features.contains(.swiftData), features.contains(.cloudKitSharing) {
            throw .sharingRequiresCoreData
        }

        if externalPackages.isEmpty, targetDependencies.isEmpty {
            return
        }

        // 2. Unique names, no collision with the app target.
        let duplicates = DuplicateNames.find(in: externalPackages.map(\.name), ignoringCase: false)
        if !duplicates.isEmpty {
            throw .duplicateExternalPackageNames(duplicates)
        }
        for ext in externalPackages where ext.name == name {
            throw .externalPackageCollidesWithTarget(ext.name)
        }

        // 3. Every target-dep resolves.
        for dep in targetDependencies {
            try validateTargetDependency(dep)
        }

        // 4. Every external is linked.
        var linkedPackages = Set(targetDependencies.map { XcodeGenGenerator.routeProductToPackage($0, externals: externalPackages) })
        for (feature, entryName) in [(AppFeature.lumiKit, "LumiKit"), (.lottie, "Lottie")] where resolvedFeatures.contains(feature) {
            linkedPackages.insert(entryName)
        }
        let unlinked = externalPackages
            .filter { !linkedPackages.contains($0.spmPackageName) && !linkedPackages.contains($0.name) }
            .map(\.name)
        if !unlinked.isEmpty {
            throw .externalPackageNotConsumed(unlinked.sorted())
        }
    }

    /// Products the enabled features link into the app target.
    private var featureWiredProducts: Set<String> {
        var products: Set<String> = []
        if hasLumiKit { products.formUnion(KnownPackages.registry["LumiKit"]?.resolvedProducts ?? []) }
        if hasLottie { products.insert("Lottie") }
        return products
    }

    private func validateTargetDependency(_ dep: String) throws(AppConfigError) {
        let externalNames = Set(externalPackages.map(\.name))
        let wired = featureWiredProducts
        if externalNames.contains(dep) || wired.contains(dep) {
            return
        }

        // A typo of a known name, or a bare package name, before routing:
        // the single-external fallback would otherwise swallow it.
        let suggestions = KnownPackages.productSuggestions(for: dep, candidates: externalNames.union(KnownPackages.allProducts))
        if !suggestions.isEmpty {
            throw .misspelledProduct(dep: dep, suggestions: suggestions)
        }

        // Routed to a declared external (longest prefix, or the only one).
        let routed = XcodeGenGenerator.routeProductToPackage(dep, externals: externalPackages)
        if externalPackages.contains(where: { $0.spmPackageName == routed }) {
            return
        }

        if let entry = KnownPackages.entryOwning(product: dep) {
            throw .unwiredKnownProduct(dep: dep, hint: Self.wiringHint(for: entry, product: dep))
        }
        throw .unknownTargetDependency(dep)
    }

    /// How to wire a registry product that nothing in the config links.
    private static func wiringHint(for entry: KnownPackages.Entry, product: String) -> String {
        switch entry.name {
        case "LumiKit":
            "add --features lumiKit, or declare LumiKit with --external-packages"
        case "Lottie":
            "add --features lottie (adds the LottieHelper template) or --use-packages Lottie"
        case _ where entry.exposeViaUsePackages:
            "add --use-packages \(entry.name)"
        default:
            "declare the package that provides '\(product)' with --external-packages"
        }
    }
}

extension AppConfig: GeneratableConfig {
    static var projectType: ProjectType { .app }

    func monolithConfig(initGit: Bool) -> ConfigFile.MonolithConfig {
        ConfigFile.MonolithConfig(projectType: .app, app: self, package: nil, cli: nil, initGit: initGit)
    }
}

enum AppConfigError: Error, CustomStringConvertible {
    case conflictingPersistence
    case sharingRequiresCoreData
    case duplicateExternalPackageNames([String])
    case externalPackageCollidesWithTarget(String)
    case externalPackageNotConsumed([String])
    case misspelledProduct(dep: String, suggestions: [String])
    case unwiredKnownProduct(dep: String, hint: String)
    case unknownTargetDependency(String)

    var description: String {
        switch self {
        case .conflictingPersistence:
            return "--features swiftData and coreData can't be combined: choose one persistence layer."
        case .sharingRequiresCoreData:
            return "CloudKit sharing requires coreData; SwiftData has no shared-database support. "
                + "Replace swiftData with coreData, or drop cloudKitSharing."
        case let .duplicateExternalPackageNames(names):
            return "--external-packages / --use-packages declare \(names.map { "'\($0)'" }.joined(separator: ", ")) more than once. Each package needs a unique name."
        case let .externalPackageCollidesWithTarget(name):
            return "--external-packages declares '\(name)', which collides with the app target name. External package names must not match the app target."
        case let .externalPackageNotConsumed(names):
            let quoted = names.map { "'\($0)'" }.joined(separator: ", ")
            let pronoun = names.count == 1 ? "it" : "them"
            return "--external-packages declares \(quoted), but no --target-deps entry links \(pronoun). "
                + "The package would be declared in the generated project with no target using it. "
                + "Add one of its products to --target-deps, or remove the --external-packages entry."
        case let .misspelledProduct(dep, suggestions):
            return KnownPackages.misspelledProductMessage(context: "The app target", dep: dep, suggestions: suggestions)
        case let .unwiredKnownProduct(dep, hint):
            return "--target-deps names '\(dep)', but nothing adds its package to the project: \(hint)."
        case let .unknownTargetDependency(dep):
            return "--target-deps names '\(dep)', which no declared package provides. "
                + "Declare its package with --external-packages 'Name=url:requirement', "
                + "or use --use-packages for \(KnownPackages.allIdentifiers.joined(separator: ", "))."
        }
    }
}
