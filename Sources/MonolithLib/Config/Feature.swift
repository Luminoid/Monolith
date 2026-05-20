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
    case snapKit
    case lottie
    case lookin
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

    var displayName: String {
        switch self {
        case .swiftData: "SwiftData"
        case .coreData: "Core Data"
        case .cloudKit: "CloudKit sync (with Core Data or SwiftData)"
        case .cloudKitSharing: "CloudKit Sharing (CKShare acceptance)"
        case .lumiKit: "LumiKit (theme + design system + logging)"
        case .snapKit: "SnapKit (Auto Layout DSL)"
        case .lottie: "Lottie (animations + pull-to-refresh)"
        case .lookin: "LookinServer (UI debugging, iOS only)"
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
        }
    }

    /// Features shown in the interactive multi-select prompt.
    /// Some features (tabs, macCatalyst) are derived from other prompts.
    /// `coreDataAuditHook` only makes sense when both `coreData`/`swiftData` and
    /// `cloudKit` are enabled, so it's auto-derived rather than prompted.
    static var promptOptions: [Self] {
        [
            .swiftData, .coreData, .cloudKit, .cloudKitSharing,
            .lumiKit, .snapKit, .lottie, .lookin, .darkMode, .combine,
            .notifications, .deepLinks, .spotlight, .deferredLaunchWork, .widget,
            .localization, .privacyManifest, .appIconValidation,
            .devTooling, .gitHooks, .claudeMD, .licenseChangelog,
            .rSwift, .fastlane,
        ]
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
/// `knownPackageDependency` table — used when a package depends on a SPM repo
/// Monolith doesn't ship a built-in entry for (typically a private or
/// in-development library that hasn't yet earned a slot in the registry).
struct ExternalPackage: Codable {
    /// Product name as referenced from `--target-deps` and `.product(name:)`.
    let name: String
    /// Repo URL, e.g. `https://github.com/yourorg/YourLib`.
    let url: String
    /// Version requirement, e.g. `"from: \"0.1.0\""` or `"branch: \"main\""`.
    /// Emitted verbatim after the URL.
    let requirement: String
    /// SPM package name (the `package:` arg in `.product(name:package:)`).
    /// Defaults to `name` if not specified — usually correct.
    let packageName: String?

    /// Inferred SPM package name (defaults to `name`).
    var spmPackageName: String { packageName ?? name }
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
}
