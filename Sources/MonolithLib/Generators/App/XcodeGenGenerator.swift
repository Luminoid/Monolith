import Foundation

enum XcodeGenGenerator {
    /// Generate the XcodeGen `project.yml`. `projectRoot` is the absolute path
    /// the project will be written to; used to normalize external-package
    /// paths so they're stored relative to the project root in `project.yml`
    /// (and therefore as portable relative paths in the resulting pbxproj).
    /// Pass `nil` for tests / pure-string regeneration where the caller will
    /// resolve paths themselves; the generator falls back to verbatim path
    /// emission.
    static func generate(config: AppConfig, projectRoot: String? = nil) -> String {
        var lines: [String] = []

        lines.append("name: \(config.name)")
        lines.append("")

        // Options
        lines.append("options:")
        lines.append("  bundleIdPrefix: \(bundlePrefix(config.bundleID))")
        lines.append("  deploymentTarget:")
        lines.append("    iOS: \(config.deploymentTarget)")
        if config.hasMacCatalyst {
            lines.append("    macCatalyst: \(config.deploymentTarget)")
        }
        lines.append("  xcodeVersion: \"\(ToolVersion.xcode)\"")
        // Note: xcodegen 2.44+ does NOT expose a way to override the pbxproj
        // `compatibilityVersion = "Xcode 14.0"` literal. The functional
        // value Xcode actually reads is `objectVersion`, which xcodegen
        // already emits as `77` (Xcode 16+) on modern toolchains — that's
        // correct and forward-compatible. The hardcoded "Xcode 14.0" string
        // is a cosmetic relic in the Xcode "Project compatible with" UI and
        // does not affect build behavior. File:
        // https://github.com/yonaskolb/XcodeGen/issues for the upstream knob.
        lines.append("  generateEmptyDirectories: true")
        lines.append("")

        // Settings
        // `CODE_SIGN_IDENTITY` defaults in xcodegen-emitted pbxproj are the
        // deprecated `"iPhone Developer"` name (renamed to `"Apple Development"`
        // by Apple in 2018). Override at project level. Either value resolves
        // to the same cert today; the deprecated form is a relic that
        // shouldn't ship in 2026+ scaffolds.
        lines.append("""
        settings:
          base:
            SWIFT_VERSION: "6.2"
            SWIFT_APPROACHABLE_CONCURRENCY: "YES"
            SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY: "YES"
            MARKETING_VERSION: "1.0.0"
            CURRENT_PROJECT_VERSION: "1"
            DEVELOPMENT_TEAM: ""
            CODE_SIGN_IDENTITY: "Apple Development"
        """)
        lines.append("")

        // Targets
        lines.append("targets:")

        // App target
        lines.append("  \(config.name):")
        lines.append("    type: application")
        lines.append("    platform: iOS")
        if config.hasMacCatalyst {
            lines.append("    supportedDestinations: [iOS, macCatalyst]")
        }
        lines.append("    sources:")
        lines.append("      - \(config.name)")
        lines.append("    settings:")
        lines.append("      base:")
        lines.append("        PRODUCT_BUNDLE_IDENTIFIER: \(config.bundleID)")
        lines.append("        GENERATE_INFOPLIST_FILE: YES")
        lines.append("        INFOPLIST_FILE: \(config.name)/Info.plist")
        lines.append("        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon")
        // xcodegen's per-target default for `CODE_SIGN_IDENTITY` is the
        // deprecated `"iPhone Developer"` value, which overrides the
        // project-level base setting. Pin it at the target level too so the
        // modern `"Apple Development"` name lands in the final pbxproj.
        lines.append("        CODE_SIGN_IDENTITY: \"Apple Development\"")
        // Required for Mac App Store distribution. Without it, `xcodebuild
        // archive` emits a warning (not error) and App Store Connect rejects
        // the upload silently. iOS-only submissions tolerate the omission, but
        // the cost of declaring it is zero and it removes a release-time
        // surprise. Adopters should pick the real category before submission
        // (https://developer.apple.com/documentation/bundleresources/information_property_list/lsapplicationcategorytype).
        lines.append("        INFOPLIST_KEY_LSApplicationCategoryType: public.app-category.utilities")
        if config.hasWidget {
            // Required so Xcode resolves the App Group capability on the host
            // app — otherwise containerURL(forSecurityApplicationGroupIdentifier:)
            // returns nil at runtime.
            lines.append("        CODE_SIGN_ENTITLEMENTS: \(config.name)/\(config.name).entitlements")
        }

        // Build phase scripts (SwiftFormat before compile, SwiftLint after compile).
        // Emit each line explicitly so the YAML indentation lands under the
        // target (4 spaces). Multi-line heredocs strip-align to the closing
        // """, which would place these keys at column 0 — invalid YAML, and
        // xcodegen rejects the spec with a `parser: ... did not find expected
        // '-' indicator` error on the next target.
        if config.hasDevTooling {
            lines.append("    preBuildScripts:")
            lines.append("      - name: SwiftFormat")
            lines.append("        basedOnDependencyAnalysis: false")
            lines.append("        script: |")
            lines.append("          if [[ \"$(uname -m)\" == arm64 ]]; then")
            lines.append("            export PATH=\"/opt/homebrew/bin:$PATH\"")
            lines.append("          fi")
            lines.append("          if which swiftformat >/dev/null; then")
            lines.append("            swiftformat \"${SRCROOT}\"")
            lines.append("          else")
            lines.append("            echo \"warning: SwiftFormat not installed\"")
            lines.append("          fi")
            lines.append("    postCompileScripts:")
            lines.append("      - name: SwiftLint")
            lines.append("        basedOnDependencyAnalysis: false")
            lines.append("        script: |")
            lines.append("          if [[ \"$(uname -m)\" == arm64 ]]; then")
            lines.append("            export PATH=\"/opt/homebrew/bin:$PATH\"")
            lines.append("          fi")
            lines.append("          if command -v swiftlint >/dev/null 2>&1; then")
            lines.append("            swiftlint")
            lines.append("          else")
            lines.append("            echo \"warning: swiftlint command not found\"")
            lines.append("          fi")
        }

        // Dependencies
        struct TargetDep {
            /// The package name as declared under `packages:` in this YAML.
            let package: String
            /// The library product to link. When `nil`, xcodegen defaults to a
            /// product whose name matches `package`. Required when the package
            /// exposes multiple products (LumiKit → LumiKitUI / LumiKitCore /
            /// LumiKitLottie / LumiKitNetwork), otherwise xcodebuild fails
            /// with "Missing package product '<package>'".
            let product: String?
            let platforms: [String]?
        }

        var deps: [TargetDep] = []
        if config.hasLumiKit {
            // LumiKit exposes LumiKitCore / LumiKitUI / LumiKitLottie /
            // LumiKitNetwork as separate products. The generated theme file
            // imports LumiKitUI, which transitively re-exports LumiKitCore.
            deps.append(TargetDep(package: "LumiKit", product: "LumiKitUI", platforms: nil))
        }
        if config.hasLottie { deps.append(TargetDep(package: "Lottie", product: nil, platforms: nil)) }
        // SnapKit + LookinServer are sourced from --use-packages or
        // --external-packages, then wired into the app target via
        // --target-deps. The --target-deps loop below handles them generically.

        // --target-deps + --external-packages: emit one TargetDep per requested
        // product. Four lookup tiers for the `package:` field:
        //   1. Direct match — target-dep equals an external's `name`.
        //   2. Prefix match — target-dep starts with an external's name (the
        //      SPM convention for multi-product packages: `PrismCore` /
        //      `PrismUI` are products of the `Prism` package). Picks the
        //      longest matching prefix so `LumiKitNetwork` resolves to
        //      `LumiKit`, not a hypothetical `Lumi` package.
        //   3. Single-external fallback — only one external declared, so
        //      ambiguous products belong to it.
        //   4. Final fallback — assume product and package share a name.
        for productName in config.targetDependencies {
            // Skip products already wired via a built-in feature flag — these
            // are auto-added above (LumiKitUI, Lottie) and duplicating them
            // produces a YAML key clash + xcodebuild "duplicate dependency"
            // warning.
            if deps.contains(where: { $0.product == productName || ($0.product == nil && $0.package == productName) }) {
                continue
            }
            let packageName = routeProductToPackage(productName, externals: config.externalPackages)
            // Platform conditional from the KnownPackages registry (e.g.
            // LookinServer is iOS-only). External-packages declared by URL
            // have no platform conditional — that's a user responsibility.
            let platforms = KnownPackages.registry[productName]?.platforms
            deps.append(TargetDep(package: packageName, product: productName, platforms: platforms))
        }

        let widgetTargetName = "\(config.name)Widget"

        if !deps.isEmpty || config.hasWidget {
            lines.append("    dependencies:")
            for dep in deps {
                lines.append("      - package: \(dep.package)")
                if let product = dep.product {
                    lines.append("        product: \(product)")
                }
                if let platforms = dep.platforms {
                    lines.append("        platforms: [\(platforms.joined(separator: ", "))]")
                }
            }
            if config.hasWidget {
                lines.append("      - target: \(widgetTargetName)")
            }
        }

        lines.append("")

        // Widget extension target (must be declared before the test target so
        // the app's `- target: <name>Widget` dependency resolves cleanly).
        if config.hasWidget {
            lines.append("  \(widgetTargetName):")
            lines.append("    type: app-extension")
            lines.append("    platform: iOS")
            lines.append("    sources:")
            lines.append("      - \(widgetTargetName)")
            lines.append("    settings:")
            lines.append("      base:")
            lines.append("        PRODUCT_BUNDLE_IDENTIFIER: \(config.bundleID).Widget")
            lines.append("        INFOPLIST_FILE: \(widgetTargetName)/Info.plist")
            lines.append("        CODE_SIGN_ENTITLEMENTS: \(widgetTargetName)/\(widgetTargetName).entitlements")
            lines.append("        GENERATE_INFOPLIST_FILE: NO")
            lines.append("    dependencies:")
            lines.append("      - sdk: SwiftUI.framework")
            lines.append("      - sdk: WidgetKit.framework")
            lines.append("")
        }

        // Test target. `GENERATE_INFOPLIST_FILE: YES` is set explicitly so the
        // generated test target has a synthesized Info.plist instead of
        // relying on xcodegen's defaults (which can vary across versions).
        lines.append("  \(config.name)Tests:")
        lines.append("    type: bundle.unit-test")
        lines.append("    platform: iOS")
        lines.append("    sources:")
        lines.append("      - \(config.name)Tests")
        lines.append("    settings:")
        lines.append("      base:")
        lines.append("        GENERATE_INFOPLIST_FILE: YES")
        lines.append("    dependencies:")
        lines.append("      - target: \(config.name)")
        lines.append("")

        // Packages
        struct PackageDep {
            let name: String
            let url: String
            let from: String
        }

        // Externals override built-ins: if the user explicitly declared
        // `--external-packages LumiKit=...`, they want the local-path / pinned
        // override, not Monolith's default GitHub URL. So compute external
        // package names first and skip built-ins that collide.
        let externalPackageNames = Set(config.externalPackages.map(\.spmPackageName))

        var packages: [PackageDep] = []
        if config.hasLumiKit, !externalPackageNames.contains("LumiKit") {
            packages.append(PackageDep(name: "LumiKit", url: "https://github.com/Luminoid/LumiKit.git", from: DependencyVersion.lumiKit))
        }
        if config.hasLottie, !externalPackageNames.contains("Lottie") {
            packages.append(PackageDep(name: "Lottie", url: "https://github.com/airbnb/lottie-spm.git", from: DependencyVersion.lottie))
        }
        // SnapKit + LookinServer: see commentary near the `deps:` list above.
        // The `--use-packages` synthesis adds them into config.externalPackages,
        // and the external-packages emit loop below handles the `packages:`
        // block entry — including platform conditionals from KnownPackages.

        // External packages declared via --external-packages.
        // URL form emits `url:` + a verbatim SPM requirement key (`from:`,
        // `branch:`, `revision:`, `exactVersion:`, etc.). XcodeGen's YAML accepts
        // the same keys at this nesting level.
        // Path form emits a single `path:` line. XcodeGen resolves relative
        // paths against the project root.
        let externalsToEmit = config.externalPackages

        if !packages.isEmpty || !externalsToEmit.isEmpty {
            lines.append("packages:")
            for pkg in packages {
                lines.append("  \(pkg.name):")
                lines.append("    url: \(pkg.url)")
                lines.append("    from: \(pkg.from)")
            }
            for ext in externalsToEmit {
                lines.append("  \(ext.spmPackageName):")
                if ext.isLocalPath {
                    // Normalize absolute paths to project-root-relative so the
                    // generated `project.yml` (and the pbxproj xcodegen
                    // produces from it) is portable across machines. Without
                    // this, an absolute `path: /Users/luminoid/...` ends up
                    // in the navigator as a deeply-prefixed relative path
                    // computed from the run directory (`../../../Users/...`),
                    // which breaks the moment the project moves to a
                    // different home directory or directory depth.
                    let path = normalizePath(ext.url, projectRoot: projectRoot)
                    lines.append("    path: \(path)")
                } else {
                    lines.append("    url: \(ext.url)")
                    lines.append("    \(ext.requirement)")
                }
            }
            lines.append("")
        }

        // Shared scheme. Without an explicit declaration, xcodegen emits an
        // unshared (per-user) scheme in `xcuserdata/`, which is gitignored —
        // so fresh checkouts on a different machine get an auto-generated
        // scheme with different GUIDs and CI's `xcodebuild -scheme <Name>`
        // becomes non-deterministic. Declaring the scheme here writes it into
        // `xcshareddata/xcschemes/<Name>.xcscheme` (committed).
        lines.append("schemes:")
        lines.append("  \(config.name):")
        lines.append("    build:")
        lines.append("      targets:")
        lines.append("        \(config.name): all")
        lines.append("        \(config.name)Tests: [test]")
        lines.append("    test:")
        lines.append("      targets:")
        lines.append("        - \(config.name)Tests")
        lines.append("    run:")
        lines.append("      config: Debug")
        lines.append("    archive:")
        lines.append("      config: Release")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    private static func bundlePrefix(_ bundleID: String) -> String {
        let parts = bundleID.split(separator: ".")
        if parts.count >= 2 {
            return parts.dropLast().joined(separator: ".")
        }
        return bundleID
    }

    /// Normalize a local-package path so xcodegen emits a portable pbxproj.
    ///
    /// **Why**: xcodegen takes the path verbatim from `project.yml` and
    /// stores it (often as a relative-from-project-root path) in the
    /// resulting pbxproj. Without normalization here, an absolute
    /// `/Users/luminoid/Projects/Prism` ends up in the navigator as a
    /// directory-depth-dependent relative path (`../../../Users/luminoid/...`)
    /// computed against the run directory. That works on the original
    /// machine but breaks the moment the project moves to a directory at a
    /// different depth or onto a different user's home directory.
    ///
    /// **Behavior**:
    /// - Already-relative paths pass through verbatim. The user wrote them
    ///   expecting a specific anchor (project root), and second-guessing is
    ///   worse than respecting their intent.
    /// - Absolute paths are converted to project-root-relative form. The
    ///   resulting `../<sibling>` (or longer `../../...`) is portable as long
    ///   as the project keeps the same relative position to the package. The
    ///   common case (`/Users/<user>/Projects/Metamer` referencing
    ///   `/Users/<user>/Projects/Prism`) becomes `../Prism`, which works
    ///   anywhere the workspace layout is preserved.
    /// - When `projectRoot` is nil (test path), emit verbatim.
    static func normalizePath(_ path: String, projectRoot: String?) -> String {
        guard let projectRoot, path.hasPrefix("/") else { return path }

        // Use NSString rather than URL because both inputs may be paths that
        // don't yet exist on disk (the project root hasn't been created when
        // this runs in some code paths). `standardizingPath` collapses `..`
        // and resolves `/tmp` symlinks but doesn't require the file to exist.
        let absPath = (path as NSString).standardizingPath
        let absRoot = (projectRoot as NSString).standardizingPath

        let pathComponents = (absPath as NSString).pathComponents
        let rootComponents = (absRoot as NSString).pathComponents

        // Find common prefix length.
        var common = 0
        while common < min(pathComponents.count, rootComponents.count),
              pathComponents[common] == rootComponents[common] {
            common += 1
        }

        let upSteps = rootComponents.count - common
        let downComponents = Array(pathComponents[common...])
        let relative = Array(repeating: "..", count: upSteps) + downComponents
        return relative.joined(separator: "/")
    }

    /// Routes a target-dep product name to its declared external package.
    /// Shared with `SPMAppGenerator`. See lookup tiers in the call site comment.
    static func routeProductToPackage(_ productName: String, externals: [ExternalPackage]) -> String {
        // Tier 1: direct match.
        if let direct = externals.first(where: { $0.name == productName }) {
            return direct.spmPackageName
        }
        // Tier 2: longest-prefix match. Sort externals by name length descending
        // so `LumiKit` beats a hypothetical `Lumi` for `LumiKitUI`.
        let prefixSorted = externals.sorted { $0.name.count > $1.name.count }
        if let prefix = prefixSorted.first(where: { productName.hasPrefix($0.name) }) {
            return prefix.spmPackageName
        }
        // Tier 3: single-external fallback.
        if externals.count == 1 {
            return externals[0].spmPackageName
        }
        // Tier 4: final fallback — product and package share a name.
        return productName
    }
}
