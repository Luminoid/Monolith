/// Centralized dependency version strings used across generators.
enum DependencyVersion {
    static let snapKit = "5.7.0"
    static let lottie = "4.5.0"
    static let lookin = "1.2.8"
    /// LumiKit 0.9.0 ships `UIColor(lmk_hex: UInt32)` + `UIColor.lmk_dynamic(...)`,
    /// the compact-theme initializer the `ThemeGenerator` emits. Older versions
    /// don't have these helpers, so generated themes fail to compile.
    static let lumiKit = "0.9.0"
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

/// Registry of every SPM package Monolith knows about.
///
/// Each `Entry` is the **single source of truth** for one package: URL,
/// default version, SPM package name, exposed products, platform floors, and
/// optional iOS-only conditional. Every generator emitting `.package(...)`,
/// `.product(name:, package:)`, or platform-conditional dep lines reads from
/// `KnownPackages.registry` — no hardcoded URLs or product lists in
/// `PackageSwiftGenerator`, `SPMAppGenerator`, `XcodeGenGenerator`, or
/// `CLIPackageSwiftGenerator`.
///
/// **Adding a well-known package** is a registry entry, not a generator
/// change. Set `exposeViaUsePackages: true` to make the identifier accepted
/// by the `--use-packages` CLI flag (the user-friendly direct-wiring flow);
/// leave it `false` for packages that are wired through feature flags or
/// auto-generated edges (LumiKit, ArgumentParser).
///
/// **Why the split**:
/// - `lumiKit` stays an `AppFeature` because it shapes generated code
///   (ThemeGenerator, LMKNavigationController, LMKLogger) — not just a dep
///   wire. Its registry entry exists for data reuse only.
/// - `ArgumentParser` is auto-added to every executable target in
///   `new package`/`new cli`; users don't pass `--use-packages ArgumentParser`.
///   Its entry exists for data reuse only.
/// - `SnapKit`, `Lottie`, `LookinServer` are the "just wire the dep" cases
///   where adopters genuinely benefit from `--use-packages SnapKit:5.7.0`.
enum KnownPackages {
    struct Entry {
        /// Stable identifier the user types into `--use-packages` /
        /// `--target-deps`. For single-product packages, equals the SPM
        /// package + sole product name.
        let name: String
        /// Repo URL emitted into `packages:` / `dependencies:`.
        let url: String
        /// Version emitted when the user doesn't supply an override.
        /// Centralized so a security patch lands once.
        let defaultVersion: String
        /// SPM package name (the `package:` arg in `.product(name:package:)`).
        /// Differs from `name` when the repo slug doesn't match the product
        /// (`lottie-spm` ships `Lottie`) or when a single repo exposes
        /// multiple products (`LumiKit` ships `LumiKitCore`, `LumiKitUI`, ...).
        /// When `nil`, defaults to `name`.
        let spmPackageName: String?
        /// All product names this package exposes. `--target-deps` references
        /// individual products from this list. Defaults to `[name]` for
        /// single-product packages.
        let products: [String]?
        /// Optional platform conditional emitted as `platforms: [iOS]` in
        /// XcodeGen YAML and `.when(platforms: [.iOS])` in `Package.swift`.
        /// `nil` for cross-platform packages.
        let platforms: [String]?
        /// Platform floors this package's own `Package.swift` requires. Used
        /// by `PackageConfig.mergingRequiredPlatforms` when an adopter wires
        /// any of `resolvedProducts` as a target dep — the adopter package's
        /// `platforms:` declaration must include each floor or `swift build`
        /// fails with "library X requires macos N, but depends on Y which
        /// requires macos M". Empty array means Foundation-only.
        let platformFloors: [PlatformVersion]
        /// True iff this identifier is accepted by `--use-packages`. Internal
        /// entries (LumiKit, ArgumentParser) wire automatically via feature
        /// flags / executable-target inference and aren't user-typed.
        let exposeViaUsePackages: Bool

        /// SPM package name, resolved to `name` when the entry leaves it nil.
        var resolvedPackageName: String { spmPackageName ?? name }

        /// Products this package exposes, resolved to `[name]` for single-
        /// product entries.
        var resolvedProducts: [String] { products ?? [name] }
    }

    static let registry: [String: Entry] = [
        "SnapKit": Entry(
            name: "SnapKit",
            url: "https://github.com/SnapKit/SnapKit.git",
            defaultVersion: DependencyVersion.snapKit,
            spmPackageName: nil,
            products: nil,
            platforms: nil,
            platformFloors: [
                PlatformVersion(platform: "iOS", version: "13.0"),
                PlatformVersion(platform: "macOS", version: "10.13"),
                PlatformVersion(platform: "tvOS", version: "13.0"),
                PlatformVersion(platform: "visionOS", version: "1.0"),
                PlatformVersion(platform: "watchOS", version: "6.0"),
            ],
            exposeViaUsePackages: true
        ),
        "Lottie": Entry(
            name: "Lottie",
            url: "https://github.com/airbnb/lottie-spm.git",
            defaultVersion: DependencyVersion.lottie,
            spmPackageName: "lottie-spm",
            products: nil,
            platforms: nil,
            platformFloors: [
                PlatformVersion(platform: "iOS", version: "13.0"),
                PlatformVersion(platform: "macOS", version: "10.15"),
                PlatformVersion(platform: "tvOS", version: "13.0"),
                PlatformVersion(platform: "visionOS", version: "1.0"),
            ],
            exposeViaUsePackages: true
        ),
        "LookinServer": Entry(
            name: "LookinServer",
            url: "https://github.com/QMUI/LookinServer.git",
            defaultVersion: DependencyVersion.lookin,
            spmPackageName: nil,
            products: nil,
            platforms: ["iOS"],
            platformFloors: [],
            exposeViaUsePackages: true
        ),
        "LumiKit": Entry(
            name: "LumiKit",
            url: "https://github.com/Luminoid/LumiKit.git",
            defaultVersion: DependencyVersion.lumiKit,
            spmPackageName: nil,
            products: ["LumiKitCore", "LumiKitUI", "LumiKitLottie", "LumiKitNetwork"],
            platforms: nil,
            platformFloors: [
                PlatformVersion(platform: "iOS", version: "18.0"),
                PlatformVersion(platform: "macCatalyst", version: "18.0"),
                PlatformVersion(platform: "macOS", version: "15.0"),
            ],
            exposeViaUsePackages: false
        ),
        "ArgumentParser": Entry(
            name: "ArgumentParser",
            url: "https://github.com/apple/swift-argument-parser.git",
            defaultVersion: DependencyVersion.argumentParser,
            spmPackageName: "swift-argument-parser",
            products: nil,
            platforms: nil,
            platformFloors: [],
            exposeViaUsePackages: false
        ),
    ]

    /// Sorted list of `--use-packages`-exposed identifiers. Used by error
    /// messages and `monolith list packages`. Filters out internal entries
    /// (LumiKit, ArgumentParser) so the user-facing surface stays small.
    static var allIdentifiers: [String] {
        registry.filter(\.value.exposeViaUsePackages).keys.sorted()
    }

    /// Look up the registry entry that owns `productName`. Handles both
    /// single-product packages (`SnapKit` → SnapKit entry) and multi-product
    /// packages (`LumiKitCore` → LumiKit entry).
    static func entryOwning(product productName: String) -> Entry? {
        if let direct = registry[productName] { return direct }
        return registry.values.first { $0.resolvedProducts.contains(productName) }
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
