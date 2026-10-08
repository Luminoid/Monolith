import Foundation

/// Wizard pieces the three `new` commands share: the terminal check, the
/// preset step, the closing steps (license, author, git, open), and the
/// flags that answer them before the wizard starts.
enum NewCommandWizard {
    /// The wizard needs a terminal to read from.
    struct NotATerminalError: Error, CustomStringConvertible {
        var description: String {
            "stdin is not a terminal; pass --no-interactive or --load-config"
        }
    }

    /// What the closing steps answered.
    struct Ending {
        let licenseType: LicenseType
        let author: String
        let initGit: Bool
        let openProject: Bool
    }

    /// Throws `NotATerminalError` unless prompts can be answered.
    static func requireTerminal() throws {
        guard PromptEngine.isInteractiveTerminal else { throw NotATerminalError() }
    }

    // MARK: - Steps

    /// The preset step. Changing the answer drops the features chosen under
    /// the old preset, so the features step starts from the new one.
    static func presetStep(for type: ProjectType) -> SingleSelectStep {
        SingleSelectStep(
            id: "preset",
            title: "Preset",
            prompt: "Feature preset",
            options: Preset.allCases.map { optionLabel($0, for: type) },
            defaultIndex: Preset.allCases.firstIndex(of: .standard) ?? 0,
            onChange: { $0.values["features"] = nil }
        )
    }

    /// The preset the wizard's preset step (or `--preset`) chose.
    static func preset(in state: WizardState) -> Preset {
        state.int("preset").flatMap { Preset.allCases.indices.contains($0) ? Preset.allCases[$0] : nil } ?? .standard
    }

    /// The positions of `features` in `options`, for a multi-select step.
    static func indices<F: Equatable>(of features: Set<F>, in options: [F]) -> Set<Int> {
        Set(options.indices.filter { features.contains(options[$0]) })
    }

    /// The license, author, git, and open steps that end every wizard. The
    /// license step shows only when `licenseVisible` (LICENSE is generated).
    static func endingSteps(defaultLicense: LicenseType, licenseVisible: @escaping (WizardState) -> Bool) -> [any WizardStep] {
        [
            SingleSelectStep(
                id: "licenseType",
                title: "License type",
                prompt: "License type",
                options: LicenseType.allCases.map { "\($0.displayName): \($0.shortDescription)" },
                defaultIndex: LicenseType.allCases.firstIndex(of: defaultLicense) ?? 0,
                isVisible: licenseVisible
            ),
            StringStep(
                id: "author",
                title: "Author",
                prompt: "Author name",
                staticDefault: GitRunner.placeholderAuthor
            ),
            YesNoStep(
                id: "initGit",
                title: "Git repository",
                prompt: "Initialize git repository?"
            ),
            YesNoStep(
                id: "openProject",
                title: "Open in Xcode",
                prompt: "Open project in Xcode after generation?",
                defaultValue: false
            ),
        ]
    }

    /// Answers the steps the shared options set, and the author from git.
    /// `featuresGiven` (`--features` passed) also skips the preset step:
    /// the features are set, so a preset has nothing left to choose.
    static func prefill(_ state: inout WizardState, from options: NewCommandOptions, featuresGiven: Bool) {
        if let author = GitRunner.authorName() {
            state.fix("author", author)
        }
        if let preset = options.preset {
            state.fix("preset", Preset.allCases.firstIndex(of: preset))
        } else if featuresGiven {
            state.fix("preset", nil)
        }
        if let license = options.license {
            state.fix("licenseType", LicenseType.allCases.firstIndex(of: license))
        }
        if let git = options.git {
            state.fix("initGit", git)
        }
        if options.open {
            state.fix("openProject", true)
        }
    }

    /// What the closing steps answered, with `defaultLicense` when the
    /// license step didn't show.
    static func ending(from state: WizardState, defaultLicense: LicenseType) -> Ending {
        let licenseType = state.int("licenseType").flatMap { LicenseType.allCases.indices.contains($0) ? LicenseType.allCases[$0] : nil }
        return Ending(
            licenseType: licenseType ?? defaultLicense,
            author: state.string("author") ?? GitRunner.placeholderAuthor,
            initGit: state.bool("initGit") ?? true,
            openProject: state.bool("openProject") ?? false
        )
    }

    // MARK: - Helpers

    /// A preset as the wizard lists it for `type`. Apps keep `Preset`'s own
    /// labels; a package or CLI preset never selects the app-only features.
    private static func optionLabel(_ preset: Preset, for type: ProjectType) -> String {
        switch (preset, type) {
        case (.minimal, _), (_, .app):
            preset.displayName
        case (.standard, .package):
            "Standard (\(PackageFeature.allCases.filter(preset.packageFeatures().contains).map(\.rawValue).joined(separator: ", ")))"
        case (.standard, .cli):
            "Standard (\(CLIFeature.allCases.filter(preset.cliFeatures().contains).map(\.rawValue).joined(separator: ", ")))"
        case (.full, _):
            "Full (every feature)"
        }
    }
}
