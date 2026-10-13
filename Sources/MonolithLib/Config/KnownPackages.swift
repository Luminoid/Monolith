/// Registry of every SPM package Monolith knows about.
///
/// Each `Entry` is the **single source of truth** for one package: URL,
/// default version, SPM package name, exposed products, platform floors, and
/// optional iOS-only conditional. Every generator emitting `.package(...)`,
/// `.product(name:, package:)`, or platform-conditional dep lines reads from
/// `KnownPackages.registry` — no hardcoded URLs or product lists in
/// `PackageSwiftGenerator`, `XcodeGenGenerator`, or `CLIPackageSwiftGenerator`.
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
///   where adopters genuinely benefit from `--use-packages SnapKit:6.0.0`.
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
        /// any of `resolvedProducts` as a target dep — each declared platform
        /// must be at least the dependency's floor or `swift build` fails with
        /// "library X requires macos N, but depends on Y which requires macos
        /// M". Copy these from the pinned release's manifest when bumping the
        /// default version. Empty array means no floor above SwiftPM's defaults.
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
            // From SnapKit 6.0.0's manifest, which declares iOS, macOS, and tvOS.
            platformFloors: [
                PlatformVersion(platform: "iOS", version: "14.0"),
                PlatformVersion(platform: "macOS", version: "12.0"),
                PlatformVersion(platform: "tvOS", version: "14.0"),
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
            // From lottie-spm 4.6.1's manifest.
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
            products: ["LumiKitCore", "LumiKitUI", "LumiKitPhoto", "LumiKitDebug", "LumiKitLottie"],
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
    /// messages. Filters out internal entries (LumiKit, ArgumentParser) so
    /// the user-facing surface stays small.
    static var allIdentifiers: [String] {
        registry.filter(\.value.exposeViaUsePackages).keys.sorted()
    }

    /// Every product the registry knows, across all entries.
    static var allProducts: Set<String> {
        Set(registry.values.flatMap(\.resolvedProducts))
    }

    /// Products that import UIKit unconditionally. A package target depending
    /// on one can't build with `swift build` / `swift test` on a Mac host, so
    /// such packages build and test through xcodebuild on an iOS Simulator.
    static let uikitOnlyProducts: Set<String> = ["LumiKitUI", "LumiKitPhoto", "LumiKitLottie"]

    /// Look up the registry entry that owns `productName`. Handles both
    /// single-product packages (`SnapKit` → SnapKit entry) and multi-product
    /// packages (`LumiKitCore` → LumiKit entry).
    static func entryOwning(product productName: String) -> Entry? {
        if let direct = registry[productName] { return direct }
        return registry.values.first { $0.resolvedProducts.contains(productName) }
    }

    /// Suggestions for a dependency name that matched nothing exactly: the
    /// products of the registry entry whose package name `dep` is (a bare
    /// `LumiKit` names the package, which ships no product of that name),
    /// otherwise the `candidates` equal to `dep` ignoring case. Empty when
    /// `dep` looks like no known name. Shared by the app and package
    /// validators so both catch the same typos.
    static func productSuggestions(for dep: String, candidates: some Sequence<String>) -> [String] {
        if let entry = registry[dep], !entry.resolvedProducts.contains(dep) {
            return entry.resolvedProducts
        }
        let lowered = dep.lowercased()
        return Set(candidates.filter { $0 != dep && $0.lowercased() == lowered }).sorted()
    }

    /// The error text for a dependency that names no product, with the
    /// suggestions from `productSuggestions(for:candidates:)`.
    static func misspelledProductMessage(context: String, dep: String, suggestions: [String]) -> String {
        let suggestionList = suggestions.map { "'\($0)'" }.joined(separator: " or ")
        var message = "\(context) depends on '\(dep)', which is not a known SPM product. Did you mean \(suggestionList)?"
        if let entry = registry[dep], !entry.resolvedProducts.contains(dep) {
            message += " '\(dep)' is the SPM package name, but its products are "
                + entry.resolvedProducts.map { "'\($0)'" }.joined(separator: " / ")
                + ". Depend on a product, not the package name."
        }
        return message
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
