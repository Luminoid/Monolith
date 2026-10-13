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
    /// stub (`import Testing`, public expectations namespace) so Swift
    /// Testing is the default. No `linkerSettings`: Swift Testing is bundled
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
        self.features = Self.features(features, mainActorTargets: mainActorTargets)
        self.mainActorTargets = mainActorTargets
        self.author = author
        self.licenseType = licenseType
        self.packageDeps = packageDeps
        self.testHelperTargets = testHelperTargets
        self.targetResources = targetResources
        self.externalPackages = externalPackages
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case name, platforms, targets, features, mainActorTargets, author, licenseType
        case packageDeps, testHelperTargets, targetResources, externalPackages
    }

    /// Custom decoder so configs saved before these fields existed still load
    /// (`licenseType` falls back to the package default), and an unknown
    /// feature name fails with a readable message.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        platforms = try container.decode([PlatformVersion].self, forKey: .platforms)
        targets = try container.decode([TargetDefinition].self, forKey: .targets)
        mainActorTargets = try container.decodeIfPresent(Set<String>.self, forKey: .mainActorTargets) ?? []
        features = try Self.features(container.decodeFeatures(PackageFeature.self, forKey: .features), mainActorTargets: mainActorTargets)
        author = try container.decode(String.self, forKey: .author)
        licenseType = try container.decodeIfPresent(LicenseType.self, forKey: .licenseType) ?? LicenseType.defaultFor(.package)
        packageDeps = try container.decodeIfPresent([String].self, forKey: .packageDeps) ?? []
        testHelperTargets = try container.decodeIfPresent(Set<String>.self, forKey: .testHelperTargets) ?? []
        targetResources = try container.decodeIfPresent([String: [String]].self, forKey: .targetResources) ?? [:]
        externalPackages = try container.decodeIfPresent([ExternalPackage].self, forKey: .externalPackages) ?? []
    }

    /// Sets encode as sorted arrays so a saved config is deterministic.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(platforms, forKey: .platforms)
        try container.encode(targets, forKey: .targets)
        try container.encode(features.sortedRawValues, forKey: .features)
        try container.encode(mainActorTargets.sorted(), forKey: .mainActorTargets)
        try container.encode(author, forKey: .author)
        try container.encode(licenseType, forKey: .licenseType)
        try container.encode(packageDeps, forKey: .packageDeps)
        try container.encode(testHelperTargets.sorted(), forKey: .testHelperTargets)
        try container.encode(targetResources, forKey: .targetResources)
        try container.encode(externalPackages, forKey: .externalPackages)
    }

    /// `features` with `defaultIsolation` added when any target is MainActor-isolated. The
    /// targets are what Package.swift isolates; the feature is what switches the Makefile and
    /// docs to xcodebuild, so `--main-actor-targets` alone must turn it on too.
    private static func features(_ features: Set<PackageFeature>, mainActorTargets: Set<String>) -> Set<PackageFeature> {
        mainActorTargets.isEmpty ? features : features.union([.defaultIsolation])
    }

    /// Whether any target uses defaultIsolation: MainActor.
    var hasDefaultIsolation: Bool {
        features.contains(.defaultIsolation) && !mainActorTargets.isEmpty
    }

    /// Whether the package must build and test through xcodebuild on an iOS
    /// Simulator rather than `swift build` / `swift test`: a MainActor UI
    /// target, or any dependency on a UIKit-only product, fails on a Mac host.
    var requiresXcodebuild: Bool {
        if hasDefaultIsolation { return true }
        let wired = targets.flatMap(\.dependencies) + packageDeps
        return wired.contains { KnownPackages.uikitOnlyProducts.contains($0) }
    }

    /// Whether the package has at least one executable sibling target.
    var hasExecutables: Bool {
        targets.contains(where: \.isExecutable)
    }

    /// The xcodebuild scheme that builds *everything* the package emits.
    ///
    /// Xcode auto-generates one scheme per target plus a `<Name>-Package`
    /// umbrella that aggregates them all. There is **no** `<Name>` scheme
    /// unless some target is literally named `<Name>` — a package named
    /// `MultiLib` whose targets are `MultiLibCore` / `MultiLibUI` / … yields
    /// schemes `MultiLib-Package`, `MultiLibCore`, `MultiLibUI`, …, and
    /// `xcodebuild -scheme MultiLib` fails with "does not contain a scheme
    /// named MultiLib". So the umbrella is required whenever no target carries
    /// the package name, the usual shape for a multi-target framework.
    ///
    /// The umbrella is also required when the package mixes target kinds
    /// (executables alongside libraries, or test-helper libs alongside
    /// MainActor libs) so one `xcodebuild build` covers them all.
    ///
    /// Only a package with an eponymous target and no mixed kinds gets the
    /// bare `<Name>` scheme, which is what adopters of a single-library
    /// package reach for.
    var xcodeBuildScheme: String {
        let hasMixedKinds = hasExecutables || !testHelperTargets.isEmpty
        let hasEponymousTarget = targets.contains { $0.name == name }
        return (hasMixedKinds || !hasEponymousTarget) ? "\(name)-Package" : name
    }

    /// Whether dev tooling is enabled.
    var hasDevTooling: Bool {
        features.contains(.devTooling)
    }

    /// Return a copy with platform floors required by wired external deps
    /// merged in. For each known external dep present in target deps or
    /// `packageDeps`, raise every **declared** platform to the dep's floor
    /// for that platform. Platforms the user didn't declare are never added,
    /// with one exception: macOS.
    ///
    /// `swift build` on a Mac host builds for macOS even when the package
    /// doesn't declare it, at SwiftPM's default floor, which is below what
    /// most dependencies require (LumiKitUI needs macOS 15, SnapKit macOS 12),
    /// so the build fails with "requires macos N". When a wired dep has a
    /// macOS floor and macOS isn't declared, macOS is added at the higher of
    /// that floor and the logging core's macOS floor, so the core is never
    /// skipped because of a macOS entry the user didn't write.
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

        // Raise declared platforms to the required floor.
        var merged: [PlatformVersion] = platforms.map { declared in
            guard let required = requiredByPlatform[declared.platform.lowercased()] else { return declared }
            return PlatformVersion(platform: declared.platform, version: PlatformVersion.higher(declared.version, required))
        }
        // Add macOS for host builds when a dep needs it and it isn't declared.
        let declaresMacOS = platforms.contains { $0.platform.lowercased() == "macos" }
        if !declaresMacOS, let depFloor = requiredByPlatform["macos"] {
            let coreFloor = LogCoreGenerator.platformFloors.first { $0.platform.lowercased() == "macos" }?.version ?? depFloor
            merged.append(PlatformVersion(platform: PackagePlatform.macOS.rawValue, version: PlatformVersion.higher(depFloor, coreFloor)))
        }

        return withPlatforms(merged)
    }

    /// A copy with `platforms` replaced.
    func withPlatforms(_ platforms: [PlatformVersion]) -> Self {
        Self(
            name: name,
            platforms: platforms,
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

    /// Whether git hooks are enabled.
    var hasGitHooks: Bool {
        features.contains(.gitHooks)
    }

    /// Every check a package config must pass before generation: the
    /// project name, at least one target, known platforms with valid
    /// versions (each once), well-formed external packages, and the
    /// structural rules in `validate()`. Run on every config, including one
    /// loaded with `--load-config`, which never meets the flag parsers.
    func validateForGeneration() throws {
        if let problem = Validators.projectNameProblem(name, kind: .package) {
            throw ConfigValidationError(problem)
        }
        guard !targets.isEmpty else {
            throw ConfigValidationError("A package needs at least one target (--targets).")
        }
        var seenPlatforms: Set<PackagePlatform> = []
        for declared in platforms {
            let platform = try PlatformVersion.canonicalPlatform(declared.platform)
            guard Validators.validatePlatformVersion(declared.version) else {
                throw ConfigValidationError(
                    "Invalid platform version '\(declared.version)' for '\(declared.platform)'. Must be major.minor numeric format (e.g., 18.0)."
                )
            }
            guard seenPlatforms.insert(platform).inserted else {
                throw ConfigValidationError("Platform \(platform.rawValue) is declared more than once.")
            }
        }
        for ext in externalPackages {
            if let problem = ext.validationProblem {
                throw ConfigValidationError(problem)
            }
        }
        try validate()
    }

    /// Throws if the config is structurally invalid (duplicate or malformed
    /// names, unknown target references, dependency cycles). Catches typos
    /// and graph errors at config time rather than letting SPM parse-fail later.
    func validate() throws(PackageConfigError) {
        // 0. Target names must be unique, also ignoring case: two targets
        //    named alike collide in `Sources/` on a case-insensitive file
        //    system, and SPM rejects exact duplicates outright.
        let duplicateTargets = DuplicateNames.find(in: targets.map(\.name), ignoringCase: true)
        if !duplicateTargets.isEmpty {
            throw PackageConfigError.duplicateTargetNames(duplicateTargets)
        }
        let duplicateExternals = DuplicateNames.find(in: externalPackages.map(\.name), ignoringCase: false)
        if !duplicateExternals.isEmpty {
            throw PackageConfigError.duplicateExternalPackageNames(duplicateExternals)
        }

        let targetNames = Set(targets.map(\.name))

        // 0a. Every target name must be a valid Swift identifier (library) or
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
        //    to either an internal target, a registry product, or a
        //    user-declared externalPackages entry. Typo heuristic kept; other
        //    unknown names pass (the adopter wires them by hand).
        let builtInExternals = KnownPackages.allProducts
        let recognizedExternals = builtInExternals.union(externalPackages.map(\.name))

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
        // Unknown name. Heuristic: case-insensitive match against a known
        // target signals a typo of an internal edge.
        let lowerDep = dep.lowercased()
        if targetNames.contains(where: { $0.lowercased() == lowerDep }) {
            throw PackageConfigError.misspelledTargetDependency(target: context, dep: dep)
        }
        // A bare registry package name (`LumiKit`) or a case-insensitive
        // match against a registry product signals a misspelled product.
        let suggestions = KnownPackages.productSuggestions(for: dep, candidates: builtInExternals)
        if !suggestions.isEmpty {
            throw PackageConfigError.misspelledExternalProduct(target: context, dep: dep, suggestions: suggestions)
        }
    }

    private func detectCycles(in targetNames: Set<String>) throws(PackageConfigError) {
        // Build adjacency restricted to internal edges.
        var adjacency: [String: [String]] = [:]
        for target in targets {
            adjacency[target.name, default: []].append(contentsOf: target.dependencies.filter { targetNames.contains($0) })
        }

        // DFS with white/gray/black coloring. `validate()` rejects duplicate
        // target names first; keeping the first entry here means a duplicate
        // can never trap.
        var color: [String: Int] = Dictionary(targets.map { ($0.name, 0) }, uniquingKeysWith: { first, _ in first })
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

extension PackageConfig: GeneratableConfig {
    static var projectType: ProjectType { .package }

    func monolithConfig(initGit: Bool) -> ConfigFile.MonolithConfig {
        ConfigFile.MonolithConfig(projectType: .package, app: nil, package: self, cli: nil, initGit: initGit)
    }
}

enum PackageConfigError: Error, CustomStringConvertible {
    case duplicateTargetNames([String])
    case duplicateExternalPackageNames([String])
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
        case let .duplicateTargetNames(names):
            "--targets lists \(names.map { "'\($0)'" }.joined(separator: ", ")) more than once (names that differ only in case also collide). Each target needs a unique name."
        case let .duplicateExternalPackageNames(names):
            "--external-packages declares \(names.map { "'\($0)'" }.joined(separator: ", ")) more than once. Each external package needs a unique name."
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
            KnownPackages.misspelledProductMessage(context: target, dep: dep, suggestions: suggestions)
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
