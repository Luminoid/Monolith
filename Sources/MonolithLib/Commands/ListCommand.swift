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

    @Option(name: .long, help: "Filter by project type: app, package, cli")
    var type: String?

    func run() throws {
        let types: [ProjectType]
        if let type {
            guard let parsed = ProjectType(rawValue: type) else {
                throw ValidationError("Unknown project type '\(type)'. Valid: app, package, cli")
            }
            types = [parsed]
        } else {
            types = ProjectType.allCases
        }

        for projectType in types {
            printFeatures(for: projectType)
        }
    }

    private func printFeatures(for type: ProjectType) {
        print("  \(type.rawValue.capitalized) Features:")
        print()

        switch type {
        case .app:
            for feature in AppFeature.allCases {
                let auto = (feature == .tabs || feature == .macCatalyst) ? " (auto-derived)" : ""
                print("    \(feature.rawValue.padding(toLength: 18, withPad: " ", startingAt: 0)) \(feature.displayName)\(auto)")
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
