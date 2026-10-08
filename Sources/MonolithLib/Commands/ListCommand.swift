import ArgumentParser

struct ListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List available options.",
        subcommands: [ListFeaturesCommand.self],
        defaultSubcommand: ListFeaturesCommand.self
    )
}

struct ListFeaturesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "features",
        abstract: "Print available features for each project type."
    )

    @Option(name: .long, help: "Only this project type")
    var type: ProjectType?

    func run() {
        for projectType in type.map({ [$0] }) ?? ProjectType.allCases {
            printFeatures(for: projectType)
        }
    }

    /// "App", "Package", "CLI".
    static func heading(for type: ProjectType) -> String {
        switch type {
        case .app: "App"
        case .package: "Package"
        case .cli: "CLI"
        }
    }

    /// The listing's note for an app feature: the ones Monolith derives from
    /// other options can't be passed to `--features`.
    static func note(for feature: AppFeature) -> String {
        AppFeature.derivedFeatureReason(feature.rawValue) == nil ? "" : " (auto-derived)"
    }

    private func printFeatures(for type: ProjectType) {
        print("  \(Self.heading(for: type)) Features:")
        print()

        switch type {
        case .app:
            for feature in AppFeature.allCases {
                print("    \(feature.rawValue.padding(toLength: 18, withPad: " ", startingAt: 0)) \(feature.displayName)\(Self.note(for: feature))")
            }
        case .package:
            for feature in PackageFeature.allCases {
                print("    \(feature.rawValue.padding(toLength: 18, withPad: " ", startingAt: 0)) \(feature.displayName)")
            }
        case .cli:
            for feature in CLIFeature.allCases {
                print("    \(feature.rawValue.padding(toLength: 18, withPad: " ", startingAt: 0)) \(feature.displayName)")
            }
        }

        print()
    }
}
