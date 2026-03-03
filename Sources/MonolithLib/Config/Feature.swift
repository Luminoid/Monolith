// MARK: - Project Types

enum ProjectType: String, CaseIterable, Sendable {
    case app
    case package
    case cli
}

// MARK: - App Features

enum AppFeature: String, CaseIterable, Sendable {
    case swiftData
    case lumiKit
    case snapKit
    case lottie
    case darkMode
    case combine
    case devTooling
    case rSwift
    case fastlane
    case claudeMD
    case licenseChangelog
    case localization
    case tabs
    case macCatalyst

    var displayName: String {
        switch self {
        case .swiftData: "SwiftData"
        case .lumiKit: "LumiKit (theme + design system + logging)"
        case .snapKit: "SnapKit (Auto Layout DSL)"
        case .lottie: "Lottie (animations + pull-to-refresh)"
        case .darkMode: "Dark mode (adaptive colors)"
        case .combine: "Combine / async patterns"
        case .devTooling: "Dev tooling (SwiftLint + SwiftFormat + Makefile + Brewfile)"
        case .rSwift: "R.swift (+ Mintfile)"
        case .fastlane: "Fastlane (+ Gemfile)"
        case .claudeMD: "CLAUDE.md"
        case .licenseChangelog: "LICENSE + CHANGELOG"
        case .localization: "Localization (String Catalog)"
        case .tabs: "Tab bar navigation"
        case .macCatalyst: "Mac Catalyst support"
        }
    }

    /// Features shown in the interactive multi-select prompt.
    /// Some features (tabs, macCatalyst) are derived from other prompts.
    static var promptOptions: [Self] {
        [
            .swiftData, .lumiKit, .snapKit, .lottie, .darkMode, .combine,
            .localization, .devTooling, .claudeMD, .licenseChangelog, .rSwift, .fastlane,
        ]
    }
}

// MARK: - Package Features

enum PackageFeature: String, CaseIterable, Sendable {
    case strictConcurrency
    case defaultIsolation
    case devTooling
    case claudeMD
    case licenseChangelog

    var displayName: String {
        switch self {
        case .strictConcurrency: "Swift 6.2 strict concurrency"
        case .defaultIsolation: "defaultIsolation: MainActor (per target)"
        case .devTooling: "Dev tooling (SwiftLint + SwiftFormat + Makefile + Brewfile)"
        case .claudeMD: "CLAUDE.md"
        case .licenseChangelog: "LICENSE + CHANGELOG"
        }
    }
}

// MARK: - CLI Features

enum CLIFeature: String, CaseIterable, Sendable {
    case argumentParser
    case strictConcurrency
    case devTooling
    case claudeMD
    case licenseChangelog

    var displayName: String {
        switch self {
        case .argumentParser: "ArgumentParser"
        case .strictConcurrency: "Swift 6.2 strict concurrency"
        case .devTooling: "Dev tooling (SwiftLint + SwiftFormat + Makefile + Brewfile)"
        case .claudeMD: "CLAUDE.md"
        case .licenseChangelog: "LICENSE + CHANGELOG"
        }
    }
}

// MARK: - Platforms

enum Platform: String, CaseIterable, Sendable {
    case iPhone
    case iPad
    case macCatalyst
}

enum ProjectSystem: String, CaseIterable, Sendable {
    case xcodeGen
    case spm
}

// MARK: - Supporting Types

struct TabDefinition: Sendable {
    let name: String
    let icon: String
}

struct TargetDefinition: Sendable {
    let name: String
    let dependencies: [String]
}

struct PlatformVersion: Sendable {
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
