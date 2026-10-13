import Foundation

// MARK: - Project Types

enum ProjectType: String, CaseIterable, Codable {
    case app
    case package
    case cli
}

// MARK: - App Features

enum AppFeature: String, CaseIterable, Codable {
    case swiftData
    case coreData
    case cloudKit
    case cloudKitSharing
    case lumiKit
    case lottie
    case darkMode
    case combine
    case devTooling
    case gitHooks
    case coreDataAuditHook
    case rSwift
    case fastlane
    case claudeMD
    case licenseChangelog
    case localization
    case tabs
    case macCatalyst
    case notifications
    case deepLinks
    case spotlight
    case deferredLaunchWork
    case widget
    case privacyManifest
    case appIconValidation
    /// Accepted as a no-op for source compatibility with PackageFeature /
    /// CLIFeature. App targets at swift-tools-version 6.2 already get strict
    /// concurrency as the language default; the flag's only purpose is to
    /// avoid an "unrecognized feature" error for users who pass it out of
    /// habit (since `new package` and `new cli` both accept it). When set on
    /// `new app`, NewAppCommand emits a stderr warning explaining the no-op.
    case strictConcurrency

    var displayName: String {
        switch self {
        case .swiftData: "SwiftData"
        case .coreData: "Core Data"
        case .cloudKit: "CloudKit sync (with Core Data or SwiftData)"
        case .cloudKitSharing: "CloudKit Sharing (CKShare acceptance)"
        case .lumiKit: "LumiKit (theme + design system + logging)"
        case .lottie: "Lottie (animations + LottieHelper view factory)"
        case .darkMode: "Dark mode (adaptive colors)"
        case .combine: "Async service template (Task cancellation)"
        case .devTooling: "Dev tooling (SwiftLint + SwiftFormat + Makefile + Brewfile)"
        case .gitHooks: "Git hooks (pre-commit lint + format)"
        case .coreDataAuditHook: "Git hook: Core Data model change reminder"
        case .rSwift: "R.swift (legacy: Xcode 15+ has native resources)"
        case .fastlane: "Fastlane (legacy: prefer Makefile or Xcode Cloud)"
        case .claudeMD: "CLAUDE.md"
        case .licenseChangelog: "LICENSE + CHANGELOG"
        case .localization: "Localization (String Catalog)"
        case .tabs: "Tab bar navigation"
        case .macCatalyst: "Mac Catalyst support"
        case .notifications: "User notifications (UNUserNotificationCenter)"
        case .deepLinks: "Deep links (URL scheme handler)"
        case .spotlight: "Spotlight (CSSearchable item handler)"
        case .deferredLaunchWork: "Deferred launch work (post-activation hook)"
        case .widget: "Widget extension (WidgetKit + App Group)"
        case .privacyManifest: "PrivacyInfo.xcprivacy (App Store requirement)"
        case .appIconValidation: "App icon alpha validation (build-phase script)"
        case .strictConcurrency: "Strict concurrency (no-op at Swift 6.2: language default)"
        }
    }

    /// Features shown in the interactive multi-select prompt.
    /// Some features (tabs, macCatalyst) are derived from other prompts.
    /// `coreDataAuditHook` only makes sense when both `coreData`/`swiftData` and
    /// `cloudKit` are enabled, so it's auto-derived rather than prompted.
    static var promptOptions: [Self] {
        [
            .swiftData, .coreData, .cloudKit, .cloudKitSharing,
            .lumiKit, .lottie, .darkMode, .combine,
            .notifications, .deepLinks, .spotlight, .deferredLaunchWork, .widget,
            .localization, .privacyManifest, .appIconValidation,
            .devTooling, .gitHooks, .claudeMD, .licenseChangelog,
            .rSwift, .fastlane,
        ]
    }

    /// Parses a comma-separated `--features` value. Throws on an unknown
    /// token, on a feature that moved to `--use-packages`, and on a feature
    /// that is derived from other input rather than selected.
    static func parseList(_ input: String?) throws(ConfigValidationError) -> Set<Self> {
        let tokens = CommaList.tokens(input)
        if let migration = removedAliasMigration(tokens) {
            throw ConfigValidationError(migration)
        }
        for token in tokens {
            if let reason = derivedFeatureReason(token) {
                throw ConfigValidationError(reason)
            }
        }
        // The derived features would fail above, so the error doesn't offer them.
        let selectable = allCases.map(\.rawValue).filter { derivedFeatureReason($0) == nil }
        return try FeatureListParser.parse(input, selectable: selectable)
    }

    /// The migration error for tokens that were promoted to the
    /// `--use-packages` registry, or `nil` when `tokens` has none.
    static func removedAliasMigration(_ tokens: [String]) -> String? {
        let removed = tokens.filter { KnownPackages.removedFeatureAliases.keys.contains($0) }
        guard !removed.isEmpty else { return nil }
        let migrations = removed
            .compactMap { token in KnownPackages.removedFeatureAliases[token].map { "\(token) → --use-packages \($0)" } }
            .joined(separator: ", ")
        return "--features \(removed.joined(separator: ", ")) was removed in v0.4. "
            + "These packages moved to the --use-packages registry. Migrate: \(migrations)."
    }

    /// Why `token` can't be selected in `--features`, when it names a feature
    /// Monolith derives from other input.
    static func derivedFeatureReason(_ token: String) -> String? {
        switch Self(rawValue: token) {
        case .tabs:
            "--features tabs is derived from --tabs. Pass --tabs 'Home:house,Settings:gearshape' instead."
        case .macCatalyst:
            "--features macCatalyst is derived from --platforms. Pass --platforms iPhone,iPad,macCatalyst instead."
        case .coreDataAuditHook:
            "--features coreDataAuditHook is auto-derived from gitHooks + persistence (coreData or swiftData) + cloudKit. "
                + "Select those features instead."
        default:
            nil
        }
    }
}

// MARK: - Package Features

enum PackageFeature: String, CaseIterable, Codable {
    case strictConcurrency
    case defaultIsolation
    case devTooling
    case gitHooks
    case claudeMD
    case licenseChangelog

    var displayName: String {
        switch self {
        case .strictConcurrency: "Strict concurrency (no-op at Swift 6.2: language default)"
        case .defaultIsolation: "defaultIsolation: MainActor (per target)"
        case .devTooling: "Dev tooling (SwiftLint + SwiftFormat + Makefile + Brewfile)"
        case .gitHooks: "Git hooks (pre-commit lint + format)"
        case .claudeMD: "CLAUDE.md"
        case .licenseChangelog: "LICENSE + CHANGELOG"
        }
    }

    /// Parses a comma-separated `--features` value, throwing on an unknown token.
    static func parseList(_ input: String?) throws(ConfigValidationError) -> Set<Self> {
        try FeatureListParser.parse(input)
    }
}

// MARK: - CLI Features

enum CLIFeature: String, CaseIterable, Codable {
    case argumentParser
    case strictConcurrency
    case devTooling
    case gitHooks
    case claudeMD
    case licenseChangelog

    var displayName: String {
        switch self {
        case .argumentParser: "ArgumentParser"
        case .strictConcurrency: "Strict concurrency (no-op at Swift 6.2: language default)"
        case .devTooling: "Dev tooling (SwiftLint + SwiftFormat + Makefile + Brewfile)"
        case .gitHooks: "Git hooks (pre-commit lint + format)"
        case .claudeMD: "CLAUDE.md"
        case .licenseChangelog: "LICENSE + CHANGELOG"
        }
    }

    /// Parses a comma-separated `--features` value, throwing on an unknown token.
    static func parseList(_ input: String?) throws(ConfigValidationError) -> Set<Self> {
        try FeatureListParser.parse(input)
    }
}

// MARK: - Platforms

enum Platform: String, CaseIterable, Codable {
    case iPhone
    case iPad
    case macCatalyst

    var displayName: String {
        switch self {
        case .iPhone: "iPhone"
        case .iPad: "iPad"
        case .macCatalyst: "Mac Catalyst"
        }
    }

    /// Parse a comma-separated platform list from CLI input ("iPhone,iPad").
    /// Case-insensitive; `mac` and `catalyst` are aliases for `macCatalyst`.
    /// Throws on an unknown token, and when no platform is named, since an
    /// app needs at least one.
    static func parseList(_ input: String) throws(ConfigValidationError) -> Set<Self> {
        var result: Set<Self> = []
        for name in CommaList.tokens(input) {
            switch name.lowercased() {
            case "iphone": result.insert(.iPhone)
            case "ipad": result.insert(.iPad)
            case "maccatalyst", "mac", "catalyst": result.insert(.macCatalyst)
            default:
                let valid = allCases.map(\.rawValue)
                throw ConfigValidationError(
                    "Unknown platform '\(name)'.\(Suggestion.didYouMean(name, in: valid)) Valid platforms: \(valid.joined(separator: ", "))."
                )
            }
        }
        guard !result.isEmpty else {
            throw ConfigValidationError("--platforms names no platform. Pass at least one of: \(allCases.map(\.rawValue).joined(separator: ", ")).")
        }
        return result
    }
}

enum ProjectSystem: String, CaseIterable, Codable {
    case xcodeProj
    case xcodeGen
    case spm

    var displayName: String {
        switch self {
        case .xcodeProj: "Xcode Project (recommended)"
        case .xcodeGen: "XcodeGen (keeps project.yml)"
        case .spm: "SPM (Swift Package Manager)"
        }
    }

    /// Project systems available for iOS app generation.
    /// SPM is excluded because executableTarget can't handle signing, entitlements, or capabilities.
    static var appOptions: [Self] {
        [.xcodeProj, .xcodeGen]
    }

    /// Whether this system can back a generated **app** target. `.spm` is still
    /// a first-class system for `new package` / `new cli` — it just can't carry
    /// an app, so every app entry point rejects it rather than silently
    /// substituting `.xcodeProj` and generating a project the user didn't ask for.
    var isSupportedForApps: Bool { Self.appOptions.contains(self) }

    /// Shared rejection text, so the `--project-system` flag and the
    /// `--load-config` path explain the same constraint the same way.
    static var unsupportedForAppsReason: String {
        "an SPM executable target can't carry code signing, entitlements, or capabilities. "
            + "Valid for apps: \(appOptions.map { $0.rawValue.lowercased() }.joined(separator: ", ")). "
            + "For a library or command-line tool, use 'monolith new package' or 'monolith new cli'."
    }

    /// Parses `--project-system` for `new app` (case-insensitive; `xcode` is
    /// an alias for `xcodeproj`). Throws for `spm` and for unknown values.
    static func parseForApps(_ input: String) throws(ConfigValidationError) -> Self {
        switch input.lowercased() {
        case "xcodeproj", "xcode":
            return .xcodeProj
        case "xcodegen":
            return .xcodeGen
        case "spm":
            throw ConfigValidationError("--project-system spm is not supported for apps: \(unsupportedForAppsReason)")
        default:
            let valid = appOptions.map { $0.rawValue.lowercased() }
            throw ConfigValidationError(
                "Unknown project system '\(input)'.\(Suggestion.didYouMean(input, in: valid)) Valid for apps: \(valid.joined(separator: ", "))."
            )
        }
    }
}

enum PackagePlatform: String, CaseIterable, Codable {
    case iOS
    case macOS
    case macCatalyst
    case watchOS
    case tvOS
    case visionOS

    var displayName: String {
        switch self {
        case .iOS: "iOS"
        case .macOS: "macOS"
        case .macCatalyst: "Mac Catalyst"
        case .watchOS: "watchOS"
        case .tvOS: "tvOS"
        case .visionOS: "visionOS"
        }
    }

    var defaultVersion: String {
        switch self {
        case .iOS, .macCatalyst, .tvOS: Defaults.deploymentTarget
        case .macOS: "15.0"
        case .watchOS: "11.0"
        case .visionOS: "2.0"
        }
    }

    /// The platform name used in PlatformVersion (matches SPM declaration parsing).
    var platformName: String {
        rawValue
    }

    /// Matches `name` case-insensitively against the raw values (`ios` → `.iOS`).
    init?(caseInsensitive name: String) {
        guard let match = Self.allCases.first(where: { $0.rawValue.lowercased() == name.lowercased() }) else { return nil }
        self = match
    }

    /// The `PackageDescription` version constant (`v18`, `v10_15`) for a
    /// `major.minor` version, or `nil` when swift-tools-version 6.2 has no
    /// such constant and the manifest must use the string form (`"18.4"`).
    ///
    /// The table lists the constants tools-version 6.2 offers without a
    /// deprecation warning. Constants exist only for `.0` releases (and the
    /// macOS 10.x minors), the versions after 18 jump to 26, and anything
    /// newer than 26 needs a later tools-version.
    func spmVersionConstant(for version: String) -> String? {
        let parts = version.split(separator: ".").map(String.init)
        guard parts.count == 2, let major = Int(parts[0]), let minor = Int(parts[1]) else { return nil }
        if self == .macOS, major == 10 {
            return (13 ... 15).contains(minor) ? "v10_\(minor)" : nil
        }
        guard minor == 0, Self.majorConstants[self, default: []].contains(major) else { return nil }
        return "v\(major)"
    }

    /// Major versions with a `.vN` constant at swift-tools-version 6.2.
    private static let majorConstants: [Self: Set<Int>] = [
        .iOS: Set(12 ... 18).union([26]),
        .macOS: Set(11 ... 15).union([26]),
        .macCatalyst: Set(13 ... 18).union([26]),
        .tvOS: Set(12 ... 18).union([26]),
        .watchOS: Set(5 ... 11).union([26]),
        .visionOS: [1, 2, 26],
    ]
}

// MARK: - License Types

enum LicenseType: String, CaseIterable, Codable {
    case mit
    case apache2
    case proprietary

    var displayName: String {
        switch self {
        case .mit: "MIT"
        case .apache2: "Apache 2.0"
        case .proprietary: "Proprietary (All Rights Reserved)"
        }
    }

    var shortDescription: String {
        switch self {
        case .mit: "Permissive, minimal restrictions"
        case .apache2: "Permissive with patent grant"
        case .proprietary: "All rights reserved, no open-source"
        }
    }

    static func defaultFor(_ projectType: ProjectType) -> Self {
        switch projectType {
        case .app: .proprietary
        case .package: .mit
        case .cli: .apache2
        }
    }
}

// MARK: - Supporting Types

struct TabDefinition: Codable {
    let name: String
    let icon: String

    /// Parses `--tabs "Home:house,Settings:gearshape"`. Every entry needs a
    /// name and an SF Symbol icon; an entry missing either throws instead of
    /// being dropped. Names are checked by `AppConfig.validateForGeneration`.
    static func parseList(_ input: String?) throws(ConfigValidationError) -> [Self] {
        try CommaList.tokens(input).map { entry throws(ConfigValidationError) in
            let parts = entry.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
                throw ConfigValidationError(
                    "Invalid --tabs entry '\(entry)'. Each tab is 'Name:icon' with an SF Symbol name, e.g. 'Home:house,Settings:gearshape'."
                )
            }
            return Self(name: parts[0], icon: parts[1])
        }
    }
}

struct TargetDefinition: Codable {
    let name: String
    let dependencies: [String]
    /// `true` if this target should be emitted as `.executableTarget(...)` — a CLI
    /// sibling alongside the package's libraries (e.g. a `*-tools` codegen binary).
    /// Declared at the CLI via `name:exec` in `--targets`. Auto-adds
    /// ArgumentParser as a dependency and skips its `Tests/<name>Tests/` fixture
    /// (executable test scaffolds are rarely useful for sibling tool CLIs).
    let isExecutable: Bool

    init(name: String, dependencies: [String], isExecutable: Bool = false) {
        self.name = name
        self.dependencies = dependencies
        self.isExecutable = isExecutable
    }

    /// Custom decoder so configs saved before `isExecutable` existed still load.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        dependencies = try container.decode([String].self, forKey: .dependencies)
        isExecutable = try container.decodeIfPresent(Bool.self, forKey: .isExecutable) ?? false
    }

    /// Parses `--targets` and `--target-deps` into target definitions.
    ///
    /// `targets` is comma-separated; an entry is `Name` or `Name:exec` (an
    /// `.executableTarget` sibling). `deps` is `Target:dep1,dep2;Target2:dep`.
    /// A deps entry without `:`, or naming a target that isn't in `targets`,
    /// throws instead of being dropped. A target listed twice in `deps` gets
    /// the union of its lists. Duplicate and malformed target names are left
    /// to `PackageConfig.validate()`.
    static func parseList(targets: String, deps: String?) throws(ConfigValidationError) -> [Self] {
        let parsedNames: [(name: String, isExecutable: Bool)] = CommaList.tokens(targets).map { entry in
            let parts = entry.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, parts[1].lowercased() == "exec" {
                return (parts[0], true)
            }
            return (entry, false)
        }
        let names = parsedNames.map(\.name)

        var depMap: [String: [String]] = [:]
        for rawEntry in (deps ?? "").split(separator: ";") {
            let entry = rawEntry.trimmingCharacters(in: .whitespaces)
            guard !entry.isEmpty else { continue }
            let parts = entry.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else {
                throw ConfigValidationError(
                    "Invalid --target-deps entry '\(entry)'. Expected 'Target:dep1,dep2', with entries separated by ';' (e.g. 'MyLibUI:MyLibCore,SnapKit')."
                )
            }
            let target = parts[0].trimmingCharacters(in: .whitespaces)
            guard names.contains(target) else {
                throw ConfigValidationError(
                    "--target-deps names target '\(target)', which is not in --targets.\(Suggestion.didYouMean(target, in: names)) "
                        + "Targets: \(names.joined(separator: ", "))."
                )
            }
            for dep in CommaList.tokens(String(parts[1])) where !depMap[target, default: []].contains(dep) {
                depMap[target, default: []].append(dep)
            }
        }

        return parsedNames.map { entry in
            Self(name: entry.name, dependencies: depMap[entry.name] ?? [], isExecutable: entry.isExecutable)
        }
    }
}

struct PlatformVersion: Codable {
    let platform: String
    let version: String

    /// Formats as SPM platform declaration: `.iOS(.v18)` when PackageDescription
    /// has a constant for the version, `.iOS("18.4")` otherwise. Truncating to
    /// the major would silently lower the floor (18.4 → 18) or name a constant
    /// that doesn't exist (`.macOS(.v10)`).
    var spmDeclaration: String {
        guard let known = PackagePlatform(caseInsensitive: platform) else {
            return ".\(platform)(\"\(version)\")"
        }
        if let constant = known.spmVersionConstant(for: version) {
            return ".\(known.rawValue)(.\(constant))"
        }
        return ".\(known.rawValue)(\"\(version)\")"
    }

    /// Parses `--platforms "iOS 18.0,macOS 15.0"` for `new package`. Platform
    /// names match `PackagePlatform` case-insensitively and are stored in its
    /// canonical spelling; versions are `major.minor`. Throws on an unknown
    /// platform, a malformed version, or a platform listed twice.
    static func parseList(_ input: String) throws(ConfigValidationError) -> [Self] {
        var result: [Self] = []
        for segment in CommaList.tokens(input) {
            let parts = segment.split(separator: " ", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else {
                throw ConfigValidationError("Invalid platform '\(segment)'. Expected format: 'iOS 18.0' (platform name + space + version).")
            }
            let platform = try canonicalPlatform(parts[0])
            guard Validators.validatePlatformVersion(parts[1]) else {
                throw ConfigValidationError("Invalid platform version '\(parts[1])' for '\(parts[0])'. Must be major.minor numeric format (e.g., 18.0).")
            }
            guard !result.contains(where: { $0.platform == platform.rawValue }) else {
                throw ConfigValidationError("--platforms lists \(platform.rawValue) more than once.")
            }
            result.append(Self(platform: platform.rawValue, version: parts[1]))
        }
        return result
    }

    /// The `PackagePlatform` named by `name` (case-insensitive), or a thrown
    /// error listing the valid names.
    static func canonicalPlatform(_ name: String) throws(ConfigValidationError) -> PackagePlatform {
        guard let platform = PackagePlatform(caseInsensitive: name) else {
            let valid = PackagePlatform.allCases.map(\.rawValue)
            throw ConfigValidationError(
                "Unknown package platform '\(name)'.\(Suggestion.didYouMean(name, in: valid)) Valid platforms: \(valid.joined(separator: ", "))."
            )
        }
        return platform
    }

    /// Compare two `major.minor[.patch]` version strings and return the higher
    /// one. Used when merging required platform floors from external deps with
    /// the user's declared platforms — we keep whichever is higher.
    ///
    /// Comparison is numeric, component-wise. Non-numeric segments compare as
    /// 0 so unexpected input never crashes.
    static func higher(_ a: String, _ b: String) -> String {
        let lhs = a.split(separator: ".").map { Int($0) ?? 0 }
        let rhs = b.split(separator: ".").map { Int($0) ?? 0 }
        let length = max(lhs.count, rhs.count)
        for i in 0 ..< length {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l != r { return l > r ? a : b }
        }
        return a // equal — pick either
    }
}
