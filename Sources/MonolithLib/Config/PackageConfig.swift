struct PackageConfig: Codable {
    let name: String
    let platforms: [PlatformVersion]
    let targets: [TargetDefinition]
    let features: Set<PackageFeature>
    let mainActorTargets: Set<String>
    let author: String
    let licenseType: LicenseType
    /// Dependency names auto-merged into every target's `dependencies:` array.
    /// Useful for multi-target frameworks where every target depends on the
    /// same base library (e.g. all five targets of a framework depending on
    /// `LumiKitUI`). Names resolve through `KnownPackages.registry` /
    /// `externalPackages`, the same as `--target-deps`.
    let packageDeps: [String]
    /// Test-helper library targets — typically a `<Name>Testing` sibling
    /// consumed by adopter test targets. The generator emits a Swift Testing
    /// stub (`import Testing`, public expectations namespace) so the workspace
    /// standard is the default. No `linkerSettings`: Swift Testing is bundled
    /// with the toolchain, and XCTest interop is opt-in by adopters (add
    /// `import XCTest` to the source — `swift test` links it automatically).
    let testHelperTargets: Set<String>
    /// Per-target resource directories. Each target in the map gets
    /// `resources: [.process("<dir>"), ...]` emitted in Package.swift.
    let targetResources: [String: [String]]
    /// External SPM packages declared at the CLI, overriding the built-in
    /// `KnownPackages.registry` entries. See `ExternalPackage`.
    let externalPackages: [ExternalPackage]

    init(
        name: String,
        platforms: [PlatformVersion],
        targets: [TargetDefinition],
        features: Set<PackageFeature>,
        mainActorTargets: Set<String>,
        author: String,
        licenseType: LicenseType,
        packageDeps: [String] = [],
        testHelperTargets: Set<String> = [],
        targetResources: [String: [String]] = [:],
        externalPackages: [ExternalPackage] = []
    ) {
        self.name = name
        self.platforms = platforms
        self.targets = targets
        self.features = features
        self.mainActorTargets = mainActorTargets
        self.author = author
        self.licenseType = licenseType
        self.packageDeps = packageDeps
        self.testHelperTargets = testHelperTargets
        self.targetResources = targetResources
        self.externalPackages = externalPackages
    }

    /// Custom decoder so configs saved before these fields existed still load.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        platforms = try container.decode([PlatformVersion].self, forKey: .platforms)
        targets = try container.decode([TargetDefinition].self, forKey: .targets)
        features = try container.decode(Set<PackageFeature>.self, forKey: .features)
        mainActorTargets = try container.decode(Set<String>.self, forKey: .mainActorTargets)
        author = try container.decode(String.self, forKey: .author)
        licenseType = try container.decode(LicenseType.self, forKey: .licenseType)
        packageDeps = try container.decodeIfPresent([String].self, forKey: .packageDeps) ?? []
        testHelperTargets = try container.decodeIfPresent(Set<String>.self, forKey: .testHelperTargets) ?? []
        targetResources = try container.decodeIfPresent([String: [String]].self, forKey: .targetResources) ?? [:]
        externalPackages = try container.decodeIfPresent([ExternalPackage].self, forKey: .externalPackages) ?? []
    }

    /// Whether strict concurrency is enabled.
    var hasStrictConcurrency: Bool {
        features.contains(.strictConcurrency)
    }

    /// Whether any target uses defaultIsolation: MainActor.
    var hasDefaultIsolation: Bool {
        features.contains(.defaultIsolation) && !mainActorTargets.isEmpty
    }

    /// Whether the package has at least one executable sibling target.
    var hasExecutables: Bool {
        targets.contains(where: \.isExecutable)
    }

    /// The xcodebuild scheme that builds *everything* the package emits.
    ///
    /// Xcode auto-generates a `<Name>-Package` umbrella scheme that aggregates
    /// every target in the package. Use it when the package mixes target
    /// kinds (executables alongside libraries, or test-helper libs alongside
    /// MainActor libs) so one `xcodebuild build` covers them all. For
    /// single-purpose packages (one library, or all libs same isolation),
    /// the named `<Name>` scheme is the only product and that's what users
    /// know to reach for.
    var xcodeBuildScheme: String {
        let hasMixedKinds = hasExecutables || !testHelperTargets.isEmpty
        return hasMixedKinds ? "\(name)-Package" : name
    }

    /// Whether dev tooling is enabled.
    var hasDevTooling: Bool {
        features.contains(.devTooling)
    }

    /// Return a copy with platform floors required by wired external deps
    /// merged in. For each known external dep present in target deps or
    /// `packageDeps`, raise any matching declared platform to the dep's floor
    /// AND add any required platform missing from the declaration.
    ///
    /// The "add missing" step is the load-bearing one — a package that wires
    /// LumiKit but declares only iOS will fail `swift build` on macOS hosts
    /// (the default for `swift build` without `-destination`) because the
    /// implicit macOS floor is 10.13, but `LumiKitUI` requires macOS 15. The
    /// generated `xcodebuild -destination 'platform=iOS Simulator'` invocation
    /// happens to dodge this, but anyone who types `swift build` (or CI on a
    /// non-iOS host) hits the wall.
    ///
    /// Idempotent: re-applying produces the same result.
    func mergingRequiredPlatforms() -> Self {
        // Collect every external dep name wired anywhere in the package.
        var depNames: Set<String> = Set(packageDeps)
        for target in targets {
            for dep in target.dependencies {
                depNames.insert(dep)
            }
        }

        // Internal targets are not external — drop them from the set.
        let targetNameSet = Set(targets.map(\.name))
        depNames.subtract(targetNameSet)

        // Collect all requirements and pick the highest version per platform.
        var requiredByPlatform: [String: String] = [:]
        for depName in depNames {
            let floors = KnownPackages.entryOwning(product: depName)?.platformFloors ?? []
            for req in floors {
                let key = req.platform.lowercased()
                if let existing = requiredByPlatform[key] {
                    requiredByPlatform[key] = PlatformVersion.higher(existing, req.version)
                } else {
                    requiredByPlatform[key] = req.version
                }
            }
        }
        guard !requiredByPlatform.isEmpty else { return self }

        // Merge with the declared platforms. Existing entries raise to the
        // required floor; missing required platforms are appended.
        var merged: [PlatformVersion] = []
        var seen: Set<String> = []
        for declared in platforms {
            let key = declared.platform.lowercased()
            seen.insert(key)
            if let required = requiredByPlatform[key] {
                let chosen = PlatformVersion.higher(declared.version, required)
                merged.append(PlatformVersion(platform: declared.platform, version: chosen))
            } else {
                merged.append(declared)
            }
        }
        // Append missing required platforms — sorted for stable output.
        for (key, version) in requiredByPlatform.sorted(by: { $0.key < $1.key }) where !seen.contains(key) {
            // Find the canonical-cased platform name from the requirement list.
            // (`requiredByPlatform` keys are lowercased for matching.)
            let canonical = canonicalPlatformName(for: key)
            merged.append(PlatformVersion(platform: canonical, version: version))
        }

        return Self(
            name: name,
            platforms: merged,
            targets: targets,
            features: features,
            mainActorTargets: mainActorTargets,
            author: author,
            licenseType: licenseType,
            packageDeps: packageDeps,
            testHelperTargets: testHelperTargets,
            targetResources: targetResources,
            externalPackages: externalPackages
        )
    }

    private func canonicalPlatformName(for lowercased: String) -> String {
        switch lowercased {
        case "ios": "iOS"
        case "macos": "macOS"
        case "maccatalyst": "macCatalyst"
        case "watchos": "watchOS"
        case "tvos": "tvOS"
        case "visionos": "visionOS"
        default: lowercased
        }
    }

    /// Whether git hooks are enabled.
    var hasGitHooks: Bool {
        features.contains(.gitHooks)
    }

    /// Throws if the config is structurally invalid (unknown target references,
    /// dependency cycles). Catches typos and graph errors at config time rather
    /// than letting SPM parse-fail later.
    func validate() throws(PackageConfigError) {
        let targetNames = Set(targets.map(\.name))

        // 0. Every target name must be a valid Swift identifier (library) or
        //    kebab-cased identifier (executable). Without this, a typo like
        //    `--targets "Foo:lib:Bar"` (mistakenly using the wrong dep-syntax)
        //    silently creates `Sources/Foo:lib:Bar/Foo:lib:Bar.swift` — valid
        //    on macOS, broken on case-insensitive filesystems and many CI
        //    runners; the `:` also breaks `swift run` shell expansion. Catch
        //    here instead of inflicting it on the adopter at build time.
        for target in targets where !target.name.isValidTargetName(allowKebab: target.isExecutable) {
            throw PackageConfigError.invalidTargetName(target.name, isExecutable: target.isExecutable)
        }

        // 1. Every name in mainActorTargets must exist in targets.
        let unknownMainActor = mainActorTargets.subtracting(targetNames)
        if !unknownMainActor.isEmpty {
            throw PackageConfigError.unknownMainActorTargets(unknownMainActor.sorted())
        }

        // 2. Every name in testHelperTargets must exist in targets.
        let unknownHelpers = testHelperTargets.subtracting(targetNames)
        if !unknownHelpers.isEmpty {
            throw PackageConfigError.unknownTestHelperTargets(unknownHelpers.sorted())
        }

        // 3. Every key in targetResources must exist in targets.
        let unknownResources = Set(targetResources.keys).subtracting(targetNames)
        if !unknownResources.isEmpty {
            throw PackageConfigError.unknownResourceTargets(unknownResources.sorted())
        }

        // 3a. Test-helper targets must not also be MainActor-isolated. A
        //     test-helper that's MainActor-isolated is almost always a bug:
        //     it can't be called from `nonisolated` test contexts (which
        //     Swift Testing's `@Test` defaults to), forcing every adopter
        //     test that uses the helper into `@MainActor` whether or not the
        //     thing under test needs it. Catch at config time, since the
        //     generated source is otherwise valid Swift and the failure shows
        //     up much later in adopter-written tests.
        let mainActorHelpers = mainActorTargets.intersection(testHelperTargets)
        if !mainActorHelpers.isEmpty {
            throw PackageConfigError.testHelperIsMainActor(mainActorHelpers.sorted())
        }

        // 4. External package names must not collide with internal target names.
        for ext in externalPackages where targetNames.contains(ext.name) {
            throw PackageConfigError.externalPackageCollidesWithTarget(ext.name)
        }

        // 5. Every dependency in target.dependencies + packageDeps must resolve
        //    to either an internal target, a recognized external (SnapKit, LumiKit*),
        //    or a user-declared externalPackages entry. Typo heuristic kept.
        let externalPackageNames = Set(externalPackages.map(\.name))
        let builtInExternals: Set = [
            "SnapKit", "Lottie",
            "LumiKitCore", "LumiKitUI", "LumiKitLottie", "LumiKitNetwork",
            "ArgumentParser",
        ]
        var recognizedExternals = builtInExternals
        recognizedExternals.formUnion(externalPackageNames)

        for dep in packageDeps {
            try validateDependencyName(dep, targetNames: targetNames, recognizedExternals: recognizedExternals, builtInExternals: builtInExternals, context: "--package-deps")
        }
        for target in targets {
            for dep in target.dependencies {
                try validateDependencyName(dep, targetNames: targetNames, recognizedExternals: recognizedExternals, builtInExternals: builtInExternals, context: "target '\(target.name)'")
            }
        }

        // 6. Every entry in --external-packages must be consumed somewhere
        //    (some target's deps, or --package-deps). Unconsumed entries are
        //    silently dropped from the emitted Package.swift, which surfaces
        //    later as a cryptic SPM error (or worse, an "it built but doesn't
        //    link what I asked for" surprise). Catch at config time.
        let allConsumedNames: Set<String> = {
            var set = Set(packageDeps)
            for target in targets {
                set.formUnion(target.dependencies)
            }
            return set
        }()
        let unconsumed = externalPackages.map(\.name).filter { !allConsumedNames.contains($0) }
        if !unconsumed.isEmpty {
            throw PackageConfigError.externalPackageNotConsumed(unconsumed.sorted())
        }

        // 7. Detect dependency cycles among internal targets.
        try detectCycles(in: targetNames)
    }

    private func validateDependencyName(
        _ dep: String,
        targetNames: Set<String>,
        recognizedExternals: Set<String>,
        builtInExternals: Set<String>,
        context: String
    ) throws(PackageConfigError) {
        guard !targetNames.contains(dep), !recognizedExternals.contains(dep) else { return }
        // Unknown name. Heuristic: case-insensitive match against either a known
        // target OR a built-in external product (LumiKitUI / SnapKit / Lottie /
        // ArgumentParser) signals a typo. Otherwise allow (user wires it
        // manually post-gen via --external-packages).
        let lowerDep = dep.lowercased()
        if targetNames.contains(where: { $0.lowercased() == lowerDep }) {
            throw PackageConfigError.misspelledTargetDependency(target: context, dep: dep)
        }
        // "LumiKit" → LumiKitUI / LumiKitCore: the SPM package name is LumiKit
        // but it ships no product named LumiKit. Catch the bare name explicitly
        // since case-insensitive match against "LumiKitUI" / "LumiKitCore" /
        // etc. wouldn't fire — the strings genuinely differ.
        if dep == "LumiKit" {
            throw PackageConfigError.misspelledExternalProduct(target: context, dep: dep, suggestions: ["LumiKitUI", "LumiKitCore", "LumiKitLottie", "LumiKitNetwork"])
        }
        if let match = builtInExternals.first(where: { $0.lowercased() == lowerDep }) {
            throw PackageConfigError.misspelledExternalProduct(target: context, dep: dep, suggestions: [match])
        }
    }

    private func detectCycles(in targetNames: Set<String>) throws(PackageConfigError) {
        // Build adjacency restricted to internal edges.
        var adjacency: [String: [String]] = [:]
        for target in targets {
            adjacency[target.name] = target.dependencies.filter { targetNames.contains($0) }
        }

        // DFS with white/gray/black coloring.
        var color: [String: Int] = Dictionary(uniqueKeysWithValues: targets.map { ($0.name, 0) })
        var stack: [String] = []

        func visit(_ node: String) throws(PackageConfigError) {
            color[node] = 1
            stack.append(node)
            for next in adjacency[node] ?? [] {
                switch color[next] ?? 0 {
                case 1:
                    let cycleStart = stack.firstIndex(of: next) ?? 0
                    throw PackageConfigError.dependencyCycle(Array(stack[cycleStart...]) + [next])
                case 0:
                    try visit(next)
                default:
                    break
                }
            }
            color[node] = 2
            stack.removeLast()
        }

        for target in targets where color[target.name] == 0 {
            try visit(target.name)
        }
    }
}

enum PackageConfigError: Error, CustomStringConvertible {
    case invalidTargetName(String, isExecutable: Bool)
    case unknownMainActorTargets([String])
    case unknownTestHelperTargets([String])
    case unknownResourceTargets([String])
    case testHelperIsMainActor([String])
    case externalPackageCollidesWithTarget(String)
    case externalPackageNotConsumed([String])
    case misspelledTargetDependency(target: String, dep: String)
    case misspelledExternalProduct(target: String, dep: String, suggestions: [String])
    case dependencyCycle([String])

    var description: String {
        switch self {
        case let .invalidTargetName(name, isExecutable):
            Self.invalidTargetNameMessage(name: name, isExecutable: isExecutable)
        case let .unknownMainActorTargets(names):
            "--main-actor-targets references unknown target(s): \(names.joined(separator: ", ")). Targets must appear in --targets."
        case let .unknownTestHelperTargets(names):
            "--test-helper-targets references unknown target(s): \(names.joined(separator: ", ")). Targets must appear in --targets."
        case let .unknownResourceTargets(names):
            "--target-resources references unknown target(s): \(names.joined(separator: ", ")). Targets must appear in --targets."
        case let .testHelperIsMainActor(names):
            "Target(s) \(names.joined(separator: ", ")) are declared both --test-helper-targets and --main-actor-targets. "
                + "A MainActor-isolated test helper can't be called from nonisolated test contexts (the Swift Testing default), "
                + "which forces every adopter test that uses the helper into @MainActor. Drop the targets from one list or the other."
        case let .externalPackageCollidesWithTarget(name):
            "--external-packages declares '\(name)', which collides with an internal target name. External package names must not match any target."
        case let .externalPackageNotConsumed(names):
            Self.unconsumedExternalsMessage(names)
        case let .misspelledTargetDependency(target, dep):
            "\(target) depends on '\(dep)', which looks like a typo of an existing target name. Check spelling in --target-deps / --package-deps."
        case let .misspelledExternalProduct(target, dep, suggestions):
            Self.misspelledProductMessage(target: target, dep: dep, suggestions: suggestions)
        case let .dependencyCycle(cycle):
            "Inter-target dependency cycle detected: \(cycle.joined(separator: " -> ")). SPM does not allow cyclic target dependencies."
        }
    }

    private static func invalidTargetNameMessage(name: String, isExecutable: Bool) -> String {
        let allowed = isExecutable
            ? "letters, digits, '_', and '-' (executable targets may be kebab-cased; first character must be a letter or '_')"
            : "letters, digits, and '_' (library targets are Swift identifiers; first character must be a letter or '_')"
        return "Invalid target name '\(name)'. Target names must contain only \(allowed). "
            + "Common cause: passing dependency syntax to --targets (e.g., 'Foo:lib:Bar') instead of --target-deps. "
            + "Use --targets 'Foo,Bar' and --target-deps 'Bar:Foo'."
    }

    private static func unconsumedExternalsMessage(_ names: [String]) -> String {
        let quoted = names.map { "'\($0)'" }.joined(separator: ", ")
        let pronoun = names.count == 1 ? "it" : "them"
        let pronounIs = names.count == 1 ? "it is" : "they are"
        return "--external-packages declares \(quoted), but no target depends on \(pronoun) "
            + "(no --target-deps entry references \(pronoun), and \(pronounIs) not in --package-deps). "
            + "Unreferenced entries are silently dropped from the emitted Package.swift. "
            + "Add the name to a target's deps, add it to --package-deps, or remove the --external-packages entry."
    }

    private static func misspelledProductMessage(target: String, dep: String, suggestions: [String]) -> String {
        let suggestionList = suggestions.map { "'\($0)'" }.joined(separator: " or ")
        return "\(target) depends on '\(dep)', which is not a known SPM product. Did you mean \(suggestionList)? "
            + "Note: LumiKit's SPM package is 'LumiKit', but its products are "
            + "'LumiKitUI' / 'LumiKitCore' / 'LumiKitLottie' / 'LumiKitNetwork'. "
            + "Depend on a product, not the package name."
    }
}

private extension String {
    /// Whether this string is a valid target name.
    ///
    /// Library targets must be valid Swift identifiers: `[A-Za-z_][A-Za-z0-9_]*`.
    /// Executable targets additionally allow `-` (kebab-case is the convention
    /// for binary names like `swift-format` → struct `SwiftFormat`).
    ///
    /// SPM itself is more permissive (almost any path-safe string works), but
    /// the Swift type generated from the target name (`enum <Name> {}` for
    /// libraries, `struct <UpperCamelCased>: ParsableCommand` for executables)
    /// must be a valid identifier — otherwise generated source files fail to
    /// compile, which is a worse error to surface than rejecting at config
    /// time.
    func isValidTargetName(allowKebab: Bool) -> Bool {
        guard !isEmpty else { return false }
        let scalars = unicodeScalars
        guard let first = scalars.first else { return false }
        let isAlpha = { (s: Unicode.Scalar) in
            (s >= "a" && s <= "z") || (s >= "A" && s <= "Z")
        }
        let isDigit = { (s: Unicode.Scalar) in s >= "0" && s <= "9" }
        guard isAlpha(first) || first == "_" else { return false }
        for s in scalars.dropFirst() {
            if isAlpha(s) || isDigit(s) || s == "_" { continue }
            if allowKebab, s == "-" { continue }
            return false
        }
        return true
    }
}
