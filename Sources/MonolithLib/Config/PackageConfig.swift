struct PackageConfig: Codable {
    let name: String
    let platforms: [PlatformVersion]
    let targets: [TargetDefinition]
    let features: Set<PackageFeature>
    let mainActorTargets: Set<String>
    let author: String
    let licenseType: LicenseType
    /// Dependency names auto-merged into every target's `dependencies:` array.
    /// Useful for packages where every target depends on the same base library
    /// (e.g. Causeway's five targets all depend on `LumiKitUI`). Names go
    /// through the same `knownPackageDependency` / `externalPackages` resolution
    /// as `--target-deps`.
    let packageDeps: [String]
    /// Targets that should link XCTest as a system framework — for test-utility
    /// libraries (e.g. Causeway's `CausewayTesting`) that are imported by
    /// adopter projects' test targets and need `import XCTest` themselves.
    let xctestTargets: Set<String>
    /// Per-target resource directories. Each target in the map gets
    /// `resources: [.process("<dir>"), ...]` emitted in Package.swift.
    let targetResources: [String: [String]]
    /// External SPM packages declared at the CLI, overriding the hardcoded
    /// `knownPackageDependency` registry. See `ExternalPackage`.
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
        xctestTargets: Set<String> = [],
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
        self.xctestTargets = xctestTargets
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
        xctestTargets = try container.decodeIfPresent(Set<String>.self, forKey: .xctestTargets) ?? []
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

    /// Whether dev tooling is enabled.
    var hasDevTooling: Bool {
        features.contains(.devTooling)
    }

    /// Whether git hooks are enabled.
    var hasGitHooks: Bool {
        features.contains(.gitHooks)
    }

    /// Throws if the config is structurally invalid (unknown target references,
    /// dependency cycles). Catches typos and graph errors at config time rather
    /// than letting SPM parse-fail later.
    func validate() throws {
        let targetNames = Set(targets.map(\.name))

        // 1. Every name in mainActorTargets must exist in targets.
        let unknownMainActor = mainActorTargets.subtracting(targetNames)
        if !unknownMainActor.isEmpty {
            throw PackageConfigError.unknownMainActorTargets(unknownMainActor.sorted())
        }

        // 2. Every name in xctestTargets must exist in targets.
        let unknownXCTest = xctestTargets.subtracting(targetNames)
        if !unknownXCTest.isEmpty {
            throw PackageConfigError.unknownXCTestTargets(unknownXCTest.sorted())
        }

        // 3. Every key in targetResources must exist in targets.
        let unknownResources = Set(targetResources.keys).subtracting(targetNames)
        if !unknownResources.isEmpty {
            throw PackageConfigError.unknownResourceTargets(unknownResources.sorted())
        }

        // 4. External package names must not collide with internal target names.
        for ext in externalPackages where targetNames.contains(ext.name) {
            throw PackageConfigError.externalPackageCollidesWithTarget(ext.name)
        }

        // 5. Every dependency in target.dependencies + packageDeps must resolve
        //    to either an internal target, a recognized external (SnapKit, LumiKit*),
        //    or a user-declared externalPackages entry. Typo heuristic kept.
        let externalPackageNames = Set(externalPackages.map(\.name))
        var recognizedExternals: Set = [
            "SnapKit", "Lottie",
            "LumiKitCore", "LumiKitUI", "LumiKitLottie", "LumiKitNetwork",
        ]
        recognizedExternals.formUnion(externalPackageNames)

        for dep in packageDeps {
            try validateDependencyName(dep, targetNames: targetNames, recognizedExternals: recognizedExternals, context: "--package-deps")
        }
        for target in targets {
            for dep in target.dependencies {
                try validateDependencyName(dep, targetNames: targetNames, recognizedExternals: recognizedExternals, context: "target '\(target.name)'")
            }
        }

        // 6. Detect dependency cycles among internal targets.
        try detectCycles(in: targetNames)
    }

    private func validateDependencyName(
        _ dep: String,
        targetNames: Set<String>,
        recognizedExternals: Set<String>,
        context: String
    ) throws {
        guard !targetNames.contains(dep), !recognizedExternals.contains(dep) else { return }
        // Unknown name. Heuristic: case-insensitive match against a known target
        // signals a typo; otherwise allow (user wires it manually post-gen).
        let lowerDep = dep.lowercased()
        if targetNames.contains(where: { $0.lowercased() == lowerDep }) {
            throw PackageConfigError.misspelledTargetDependency(target: context, dep: dep)
        }
    }

    private func detectCycles(in targetNames: Set<String>) throws {
        // Build adjacency restricted to internal edges.
        var adjacency: [String: [String]] = [:]
        for target in targets {
            adjacency[target.name] = target.dependencies.filter { targetNames.contains($0) }
        }

        // DFS with white/gray/black coloring.
        var color: [String: Int] = Dictionary(uniqueKeysWithValues: targets.map { ($0.name, 0) })
        var stack: [String] = []

        func visit(_ node: String) throws {
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
    case unknownMainActorTargets([String])
    case unknownXCTestTargets([String])
    case unknownResourceTargets([String])
    case externalPackageCollidesWithTarget(String)
    case misspelledTargetDependency(target: String, dep: String)
    case dependencyCycle([String])

    var description: String {
        switch self {
        case let .unknownMainActorTargets(names):
            "--main-actor-targets references unknown target(s): \(names.joined(separator: ", ")). Targets must appear in --targets."
        case let .unknownXCTestTargets(names):
            "--xctest-targets references unknown target(s): \(names.joined(separator: ", ")). Targets must appear in --targets."
        case let .unknownResourceTargets(names):
            "--target-resources references unknown target(s): \(names.joined(separator: ", ")). Targets must appear in --targets."
        case let .externalPackageCollidesWithTarget(name):
            "--external-packages declares '\(name)', which collides with an internal target name. External package names must not match any target."
        case let .misspelledTargetDependency(target, dep):
            "\(target) depends on '\(dep)', which looks like a typo of an existing target name. Check spelling in --target-deps / --package-deps."
        case let .dependencyCycle(cycle):
            "Inter-target dependency cycle detected: \(cycle.joined(separator: " -> ")). SPM does not allow cyclic target dependencies."
        }
    }
}
