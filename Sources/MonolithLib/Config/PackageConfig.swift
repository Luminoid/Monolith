struct PackageConfig: Codable {
    let name: String
    let platforms: [PlatformVersion]
    let targets: [TargetDefinition]
    let features: Set<PackageFeature>
    let mainActorTargets: Set<String>
    let author: String
    let licenseType: LicenseType

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

        // 2. Every internal target dependency must reference an existing target.
        //    External names (SnapKit, LumiKit*, etc.) are intentionally untyped here;
        //    PackageSwiftGenerator passes them through as raw target dependency strings.
        let recognizedExternals: Set = [
            "SnapKit", "Lottie",
            "LumiKitCore", "LumiKitUI", "LumiKitLottie", "LumiKitNetwork",
        ]
        for target in targets {
            for dep in target.dependencies {
                if !targetNames.contains(dep), !recognizedExternals.contains(dep) {
                    // Unknown name. Could be a typoed internal target OR a third-party
                    // dep the user plans to add manually. Heuristic: if it case-insensitively
                    // matches a known target, treat as a typo; otherwise allow.
                    let lowerDep = dep.lowercased()
                    if targetNames.contains(where: { $0.lowercased() == lowerDep }) {
                        throw PackageConfigError.misspelledTargetDependency(target: target.name, dep: dep)
                    }
                }
            }
        }

        // 3. Detect dependency cycles among internal targets.
        try detectCycles(in: targetNames)
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
    case misspelledTargetDependency(target: String, dep: String)
    case dependencyCycle([String])

    var description: String {
        switch self {
        case let .unknownMainActorTargets(names):
            "--main-actor-targets references unknown target(s): \(names.joined(separator: ", ")). Targets must appear in --targets."
        case let .misspelledTargetDependency(target, dep):
            "Target '\(target)' depends on '\(dep)', which looks like a typo of an existing target name. Check spelling in --target-deps."
        case let .dependencyCycle(cycle):
            "Inter-target dependency cycle detected: \(cycle.joined(separator: " -> ")). SPM does not allow cyclic target dependencies."
        }
    }
}
