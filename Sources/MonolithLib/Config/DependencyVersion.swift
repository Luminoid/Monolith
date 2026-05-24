/// Centralized dependency version strings used across generators.
enum DependencyVersion {
    static let snapKit = "5.7.0"
    static let lottie = "4.5.0"
    static let lookin = "1.2.8"
    static let lumiKit = "0.8.0"
    static let argumentParser = "1.7.0"
}

/// Centralized tool version strings used across generators.
enum ToolVersion {
    static let xcode = "16"
    static let swift = "6.2"

    /// Brewfile floor versions for the dev-tooling pins. Update when generated
    /// configs start using newer-than-floor features (e.g., a new SwiftLint
    /// rule or SwiftFormat option not present in the floor release).
    static let swiftlintFloor = "0.59"
    static let swiftformatFloor = "0.54"
    static let xcodegenFloor = "2.42"
}

/// Platform floors required by known external SPM dependencies. When a package
/// wires any of these as a target dep (or via `--package-deps`), the package's
/// `platforms:` declaration must include each floor or `swift build` fails
/// with "library X requires macos N, but depends on Y which requires macos M".
///
/// Empty array means the dep has no platform floor (Foundation-only).
enum KnownDependencyPlatforms {
    private static let lumiKit: [PlatformVersion] = [
        PlatformVersion(platform: "iOS", version: "18.0"),
        PlatformVersion(platform: "macCatalyst", version: "18.0"),
        PlatformVersion(platform: "macOS", version: "15.0"),
    ]

    private static let snapKit: [PlatformVersion] = [
        PlatformVersion(platform: "iOS", version: "13.0"),
        PlatformVersion(platform: "macOS", version: "10.13"),
        PlatformVersion(platform: "tvOS", version: "13.0"),
        PlatformVersion(platform: "visionOS", version: "1.0"),
        PlatformVersion(platform: "watchOS", version: "6.0"),
    ]

    private static let lottie: [PlatformVersion] = [
        PlatformVersion(platform: "iOS", version: "13.0"),
        PlatformVersion(platform: "macOS", version: "10.15"),
        PlatformVersion(platform: "tvOS", version: "13.0"),
        PlatformVersion(platform: "visionOS", version: "1.0"),
    ]

    /// Lookup table. Names match the strings used in `--target-deps` and
    /// `PackageSwiftGenerator.knownPackageDependency`.
    static func requirements(for depName: String) -> [PlatformVersion] {
        switch depName {
        case "LumiKitCore", "LumiKitUI", "LumiKitLottie", "LumiKitNetwork":
            lumiKit
        case "SnapKit":
            snapKit
        case "Lottie":
            lottie
        default:
            []
        }
    }
}

/// Registry of well-known SPM packages users can reference via the
/// `--use-packages` CLI flag without typing the full URL + requirement.
///
/// Each entry maps a short identifier (e.g. `"SnapKit"`) to its repo URL,
/// default version, and optional platform conditional. `--use-packages`
/// turns `"SnapKit"` into a synthesized `ExternalPackage` entry, which then
/// flows through the same emit path as user-declared externals.
///
/// **Why this exists**: before v0.3.0, `snapKit`, `lottie`, and `lookin`
/// were individual `AppFeature` enum cases with hardcoded `if hasSnapKit
/// { packages.append(...) }` branches in both `XcodeGenGenerator` and
/// `SPMAppGenerator`. That worked for the workspace's four favorite libs but
/// didn't scale (every new third-party lib would tempt adding another flag).
/// Lifting them into a data-driven registry makes the CLI surface
/// extensible — adding a new well-known package is a registry entry, not
/// a generator change.
///
/// **Stays as an `AppFeature`**: `lumiKit`. It has deep cross-cutting
/// integration (ThemeGenerator, dark-mode auto-derive, LMKNavigationController
/// in SceneDelegate, LMKLogger throughout) — a feature flag activates a
/// whole *style* of generated code, not just a dep wire. The registry is
/// for the "just wire the dep" case.
enum KnownPackages {
    struct Entry {
        /// SPM package + single-product name. Identifier the user types into
        /// `--use-packages` and `--target-deps`.
        let name: String
        /// Repo URL emitted into `packages:` / `dependencies:`.
        let url: String
        /// Version emitted when the user doesn't supply an override.
        /// Centralized so a security patch lands once.
        let defaultVersion: String
        /// Optional platform conditional emitted as `platforms: [iOS]` in
        /// XcodeGen YAML and `.when(platforms: [.iOS])` in `Package.swift`.
        /// `nil` for cross-platform packages.
        let platforms: [String]?
    }

    static let registry: [String: Entry] = [
        "SnapKit": Entry(
            name: "SnapKit",
            url: "https://github.com/SnapKit/SnapKit.git",
            defaultVersion: DependencyVersion.snapKit,
            platforms: nil
        ),
        "Lottie": Entry(
            name: "Lottie",
            url: "https://github.com/airbnb/lottie-spm.git",
            defaultVersion: DependencyVersion.lottie,
            platforms: nil
        ),
        "LookinServer": Entry(
            name: "LookinServer",
            url: "https://github.com/QMUI/LookinServer.git",
            defaultVersion: DependencyVersion.lookin,
            platforms: ["iOS"]
        ),
    ]

    /// Sorted list of registered identifiers. Used by error messages and
    /// `monolith list packages`.
    static var allIdentifiers: [String] {
        registry.keys.sorted()
    }

    /// `--features` tokens that existed in v0.2 and earlier but were promoted
    /// into the `KnownPackages` registry in v0.3. Removed in v0.4. The CLI
    /// uses this to produce an actionable error when an old script still
    /// passes `--features snapKit`, pointing the user at the v0.3+
    /// `--use-packages` flow.
    static let removedFeatureAliases: [String: String] = [
        "snapKit": "SnapKit",
        "lookin": "LookinServer",
    ]
}

/// Centralized default values used across commands and generators.
enum Defaults {
    static let primaryColor = "#007AFF"
    static let deploymentTarget = "18.0"
    static let simulatorOS = "26.2"
    static let simulatorDevice = "iPhone 17"
    static let simulatorDestination = "platform=iOS Simulator,name=\(simulatorDevice),OS=\(simulatorOS)"
    static let defaultPlatform = "iPhone"
}
