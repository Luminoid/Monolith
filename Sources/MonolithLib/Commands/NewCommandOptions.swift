import ArgumentParser

/// The options every `new` command takes. Each command adds its own
/// config options next to these.
struct NewCommandOptions: ParsableArguments {
    @Option(name: .long, help: "Project name")
    var name: String?

    @Option(name: .long, help: "Feature preset; its features are added to --features (the wizard's default: standard)")
    var preset: Preset?

    @Option(name: .long, help: "License type (default: proprietary for apps, mit for packages, apache2 for CLIs)")
    var license: LicenseType?

    @Flag(
        inversion: .prefixedNo,
        exclusivity: .exclusive,
        help: "Initialize a git repository with an initial commit (the wizard asks; with --no-interactive, off unless --git)"
    )
    var git: Bool?

    @Option(name: .long, help: "Output directory (default: current directory)")
    var output: String?

    @Flag(name: .long, help: "Preview generated files without writing")
    var dryRun = false

    @Flag(name: .long, help: "Skip interactive prompts")
    var noInteractive = false

    @Flag(name: .long, help: "Overwrite existing directory without prompting")
    var force = false

    @Flag(name: .long, help: "Open the project in Xcode after generation")
    var open = false

    @Flag(
        name: .long,
        help: "Resolve package dependencies after generation (swift package resolve; xcodebuild -resolvePackageDependencies for apps)"
    )
    var resolve = false

    @Flag(name: .long, help: "Stream output from xcodegen, git, package resolution, and open as they run")
    var verbose = false

    @Option(name: .long, help: "Save the resolved config to a JSON file (skipped with --dry-run)")
    var saveConfig: String?

    @Option(name: .long, help: "Load the config from a JSON file: no wizard, and no options that set the config")
    var loadConfig: String?

    /// The options in this group that set the config, as passed.
    private var configFlags: [(flag: String, passed: Bool)] {
        [("--name", name != nil), ("--preset", preset != nil), ("--license", license != nil), (git == false ? "--no-git" : "--git", git != nil)]
    }

    /// With `--load-config`, the file is the whole config: throws when an
    /// option that sets part of it was passed too. `commandFlags` are the
    /// command's own config options. Operational options (`--output`,
    /// `--force`, `--dry-run`, `--open`, `--resolve`, `--verbose`,
    /// `--save-config`, `--no-interactive`) are allowed.
    func validateLoadConfig(commandFlags: [(flag: String, passed: Bool)]) throws {
        guard loadConfig != nil else { return }
        let passed = (configFlags + commandFlags).filter(\.passed).map(\.flag)
        guard !passed.isEmpty else { return }
        throw ValidationError(
            "--load-config sets the whole config, so it can't be combined with \(passed.joined(separator: ", ")). "
                + "Edit the config file instead, or drop --load-config."
        )
    }

    /// `--name`, required with `--no-interactive`.
    func requiredName(kind: ProjectType) throws -> String {
        guard let name else {
            throw ValidationError("--name is required in non-interactive mode")
        }
        try Self.checkName(name, kind: kind)
        return name
    }

    /// Throws when `name` can't name a `kind` project.
    static func checkName(_ name: String, kind: ProjectType) throws {
        if let problem = Validators.projectNameProblem(name, kind: kind) {
            throw ValidationError(problem)
        }
    }

    /// The config `--load-config` names, with its `initGit`, or nil without the option.
    func loadedConfig<Config>(
        _ type: ProjectType,
        section: KeyPath<ConfigFile.MonolithConfig, Config?>
    ) throws -> ResolvedConfig<Config>? {
        guard let loadConfig else { return nil }
        let loaded = try ConfigFile.load(from: loadConfig, expecting: type)
        guard let config = loaded[keyPath: section] else {
            throw ConfigFile.LoadError(description: "Config file '\(loadConfig)' has no '\(type.rawValue)' section.")
        }
        return ResolvedConfig(config: config, initGit: loaded.initGit, openProject: false, interactive: false)
    }
}

/// A `new` command's config and the choices around it, from `--load-config`,
/// the flags, or the wizard.
struct ResolvedConfig<Config> {
    let config: Config
    let initGit: Bool
    /// The wizard's "Open in Xcode" answer (`--open` is added on top).
    let openProject: Bool
    /// Whether the wizard ran, so the overwrite check may prompt too.
    let interactive: Bool
}
