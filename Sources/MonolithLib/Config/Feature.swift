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
        case .lottie: "Lottie (animations + pull-to-refresh)"
        case .darkMode: "Dark mode (adaptive colors)"
        case .combine: "Combine / async patterns"
        case .devTooling: "Dev tooling (SwiftLint + SwiftFormat + Makefile + Brewfile)"
        case .gitHooks: "Git hooks (pre-commit lint + format)"
        case .coreDataAuditHook: "Git hook: Core Data model change reminder"
        case .rSwift: "R.swift (legacy — Xcode 15+ has native resources)"
        case .fastlane: "Fastlane (legacy — prefer Makefile or Xcode Cloud)"
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
        case .strictConcurrency: "Strict concurrency (no-op at Swift 6.2 — language default)"
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

    /// Identifiers that used to be `AppFeature` cases but are now in
    /// `KnownPackages.registry` and consumed via `--use-packages`. The CLI
    /// keeps accepting them in `--features` for one minor version and prints
    /// a deprecation warning + auto-translates to `--use-packages`. Removed
    /// in v0.4.
    static let deprecatedPackageFeatureNames: Set<String> = ["snapKit", "lookin"]
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
        case .strictConcurrency: "Swift 6.2 strict concurrency"
        case .defaultIsolation: "defaultIsolation: MainActor (per target)"
        case .devTooling: "Dev tooling (SwiftLint + SwiftFormat + Makefile + Brewfile)"
        case .gitHooks: "Git hooks (pre-commit lint + format)"
        case .claudeMD: "CLAUDE.md"
        case .licenseChangelog: "LICENSE + CHANGELOG"
        }
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
        case .strictConcurrency: "Swift 6.2 strict concurrency"
        case .devTooling: "Dev tooling (SwiftLint + SwiftFormat + Makefile + Brewfile)"
        case .gitHooks: "Git hooks (pre-commit lint + format)"
        case .claudeMD: "CLAUDE.md"
        case .licenseChangelog: "LICENSE + CHANGELOG"
        }
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
}

/// A package dep declared via `--external-packages`. Bypasses the hardcoded
/// `knownPackageDependency` table — used when a package or app depends on a SPM
/// repo Monolith doesn't ship a built-in entry for (typically a private or
/// in-development library that hasn't yet earned a slot in the registry).
struct ExternalPackage: Codable {
    /// Product name as referenced from `--target-deps` and `.product(name:)`.
    let name: String
    /// Source location. Either a fully-qualified URL (`https://...`,
    /// `git@...`) or a filesystem path (absolute or relative to the
    /// generated project root, e.g. `../Prism`). The presence of `://`
    /// distinguishes the two — see `isLocalPath`.
    let url: String
    /// Version requirement for URL-form packages, e.g. `"from: \"0.1.0\""`
    /// or `"branch: \"main\""`. Emitted verbatim after the URL in both
    /// `Package.swift` and XcodeGen YAML. Empty string for path-form
    /// packages (paths have no SPM version requirement).
    let requirement: String
    /// SPM package name (the `package:` arg in `.product(name:package:)`).
    /// Defaults to `name` if not specified — usually correct.
    let packageName: String?

    /// Inferred SPM package name (defaults to `name`).
    var spmPackageName: String { packageName ?? name }

    /// True when `url` is a filesystem path, not a network URL. Detected by
    /// the absence of `://`. Path-form entries are emitted as
    /// `.package(name:, path:)` in Package.swift and `path:` in XcodeGen YAML.
    var isLocalPath: Bool { !url.contains("://") }

    /// Parses the `--external-packages` syntax used by both `monolith new
    /// package` and `monolith new app`. Two forms:
    ///
    /// **URL form** (network packages): `Name=url:requirement[:packageName]`
    /// where `requirement` is verbatim SPM (`from: "0.1.0"`, `branch: "main"`,
    /// `exact: "1.0.0"`, etc.). The URL is recognized by the `://` separator.
    ///
    /// **Path form** (local packages — useful for dev workflows where the
    /// adopting project sits alongside the library): `Name=path[:packageName]`.
    /// The path has no `://` and no requirement segment (paths don't take
    /// versions). Absolute paths and relative paths (resolved against the
    /// generated project root) both work — e.g. `Prism=../Prism` or
    /// `Prism=/Users/me/Projects/Prism`.
    ///
    /// Optional `packageName` overrides the default (which equals the product name).
    /// Throws `ParseError` on malformed input — callers convert to whatever error
    /// type their command surface expects (typically `ArgumentParser.ValidationError`).
    static func parse(_ input: String?) throws(ParseError) -> [Self] {
        guard let input, !input.isEmpty else { return [] }
        var out: [Self] = []
        for entry in input.split(separator: ";") {
            let nameSplit = entry.split(separator: "=", maxSplits: 1)
            guard nameSplit.count == 2 else {
                throw .malformedEntry(String(entry))
            }
            let name = nameSplit[0].trimmingCharacters(in: .whitespaces)
            let rest = nameSplit[1].trimmingCharacters(in: .whitespaces)

            // The optional trailing `:packageName` is a `:Identifier` segment at
            // the very end (after any quotes in the requirement). Match it first
            // so we can strip it off before disambiguating URL vs path form.
            let (body, packageName): (String, String?) = if let tailMatch = rest.range(of: #":[A-Za-z_][A-Za-z0-9_-]*$"#, options: .regularExpression) {
                (
                    String(rest[rest.startIndex ..< tailMatch.lowerBound]).trimmingCharacters(in: .whitespaces),
                    String(rest[rest.index(after: tailMatch.lowerBound)...]).trimmingCharacters(in: .whitespaces)
                )
            } else {
                (rest, nil)
            }

            // Form discrimination: URL form contains `://`; path form does not.
            if let schemeRange = body.range(of: "://") {
                // URL form: split body into url + requirement on the first ':'
                // after the scheme.
                let afterScheme = body[schemeRange.upperBound...]
                guard let urlEnd = afterScheme.firstIndex(of: ":") else {
                    throw .missingRequirement(String(entry))
                }
                let url = String(body[body.startIndex ..< urlEnd])
                let requirement = body[body.index(after: urlEnd)...].trimmingCharacters(in: .whitespaces)
                out.append(Self(name: name, url: url, requirement: String(requirement), packageName: packageName))
            } else {
                // Path form: no requirement. Whole body is the path.
                guard !body.isEmpty else {
                    throw .malformedURL(String(entry))
                }
                out.append(Self(name: name, url: body, requirement: "", packageName: packageName))
            }
        }
        return out
    }

    enum ParseError: Error, CustomStringConvertible {
        case malformedEntry(String)
        case malformedURL(String)
        case missingRequirement(String)

        var description: String {
            switch self {
            case let .malformedEntry(entry):
                "Invalid --external-packages entry '\(entry)'. Expected 'Name=url:requirement[:packageName]'."
            case let .malformedURL(entry):
                "Invalid --external-packages URL in '\(entry)'. Expected fully qualified URL."
            case let .missingRequirement(entry):
                "Invalid --external-packages entry '\(entry)'. Missing ':requirement' after URL."
            }
        }
    }

    /// Parses `--use-packages "Name[:version],Name[:version],..."` syntax.
    ///
    /// Each entry is either a bare identifier (uses registry's defaultVersion)
    /// or `Identifier:version` to override the version. Looks up each
    /// identifier in `KnownPackages.registry` and synthesizes an
    /// `ExternalPackage` entry (URL form, `from:` requirement, optional
    /// platform conditional preserved in the registry — generators consult
    /// the registry when emitting platform-conditional deps).
    ///
    /// Throws `UsePackagesParseError` for unknown identifiers (with a
    /// helpful "Did you mean…?" suggestion) so typos are caught at config
    /// time, not at xcodebuild time.
    static func parseUsePackages(_ input: String?) throws(UsePackagesParseError) -> [Self] {
        guard let input, !input.isEmpty else { return [] }
        var out: [Self] = []
        for entry in input.split(separator: ",") {
            let trimmed = entry.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(separator: ":", maxSplits: 1)
            let identifier = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let versionOverride = parts.count == 2 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : nil

            guard let registryEntry = KnownPackages.registry[identifier] else {
                throw .unknownPackage(identifier: identifier, known: KnownPackages.allIdentifiers)
            }
            let version = versionOverride ?? registryEntry.defaultVersion
            out.append(Self(
                name: registryEntry.name,
                url: registryEntry.url,
                requirement: "from: \"\(version)\"",
                packageName: nil
            ))
        }
        return out
    }

    enum UsePackagesParseError: Error, CustomStringConvertible {
        case unknownPackage(identifier: String, known: [String])

        var description: String {
            switch self {
            case let .unknownPackage(identifier, known):
                "Unknown --use-packages identifier '\(identifier)'. Built-in packages: \(known.joined(separator: ", ")). Use --external-packages for packages outside the built-in registry."
            }
        }
    }
}

struct PlatformVersion: Codable {
    let platform: String
    let version: String

    /// Formats as SPM platform declaration, e.g. `.iOS(.v18)`
    var spmDeclaration: String {
        let platformName = switch platform.lowercased() {
        case "ios": ".iOS"
        case "macos": ".macOS"
        case "maccatalyst": ".macCatalyst"
        case "watchos": ".watchOS"
        case "tvos": ".tvOS"
        case "visionos": ".visionOS"
        default: ".\(platform)"
        }

        let versionComponents = version.split(separator: ".")
        let major = versionComponents.first.map(String.init) ?? version

        return "\(platformName)(.v\(major))"
    }

    /// Compare two `major.minor[.patch]` version strings and return the higher
    /// one. Used when merging required platform floors from external deps with
    /// the user's declared platforms — we keep whichever is higher.
    ///
    /// Comparison is numeric, component-wise. Non-numeric segments fall back
    /// to lexicographic compare so we don't crash on unexpected input.
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
