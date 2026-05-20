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

/// Centralized default values used across commands and generators.
enum Defaults {
    static let primaryColor = "#007AFF"
    static let deploymentTarget = "18.0"
    static let simulatorOS = "26.2"
    static let simulatorDevice = "iPhone 17"
    static let simulatorDestination = "platform=iOS Simulator,name=\(simulatorDevice),OS=\(simulatorOS)"
    static let defaultPlatform = "iPhone"
}
