// MARK: - Project Types

enum ProjectType: String, CaseIterable, Codable {
    case app
    case package
    case cli
}

// MARK: - App Features

enum AppFeature: String, CaseIterable, Codable {
    case swiftData
    case lumiKit
    case snapKit
    case lottie
    case darkMode
    case combine
    case devTooling
    case gitHooks
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
        case .gitHooks: "Git hooks (pre-commit lint + format)"
        case .rSwift: "R.swift (prefer Xcode native resources)"
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
            .localization, .devTooling, .gitHooks, .claudeMD, .licenseChangelog, .rSwift, .fastlane,
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
        case .iOS, .macCatalyst, .tvOS: "18.0"
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
