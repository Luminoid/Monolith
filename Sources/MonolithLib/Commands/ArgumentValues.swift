import ArgumentParser

// Option values ArgumentParser parses itself: it rejects an unknown value
// with the valid ones listed, shows them in help, and completes them.

extension Preset: ExpressibleByArgument {}
extension LicenseType: ExpressibleByArgument {}
extension ProjectType: ExpressibleByArgument {}
extension AddableFeature: ExpressibleByArgument {}

extension AppFeature {
    /// What `new app --features` accepts: every feature but the ones derived
    /// from other options (`AppFeature.parseList` rejects those).
    static var flagValues: [Self] {
        allCases.filter { derivedFeatureReason($0.rawValue) == nil }
    }
}

/// `--features` help and completion for the `new` commands, built from the
/// feature enums so the list can't drift from what the parsers accept.
enum FeatureFlagHelp {
    static var app: ArgumentHelp {
        let derived = AppFeature.allCases.filter { AppFeature.derivedFeatureReason($0.rawValue) != nil }
        return ArgumentHelp("""
        Features (comma-separated): \(names(AppFeature.flagValues)). \
        rSwift and fastlane are legacy (XcodeGen only); strictConcurrency is a no-op. \
        \(names(derived)) follow from --tabs, --platforms, and other features. \
        For SnapKit or LookinServer, use --use-packages. Run 'monolith list features' for descriptions.
        """)
    }

    static var package: ArgumentHelp {
        ArgumentHelp("Features (comma-separated): \(names(PackageFeature.allCases)). strictConcurrency is a no-op.")
    }

    static var cli: ArgumentHelp {
        ArgumentHelp("Features (comma-separated): \(names(CLIFeature.allCases)). argumentParser is on unless --no-argument-parser; strictConcurrency is a no-op.")
    }

    static func completion(_ features: [some RawRepresentable<String>]) -> CompletionKind {
        .list(features.map(\.rawValue))
    }

    private static func names(_ features: [some RawRepresentable<String>]) -> String {
        features.map(\.rawValue).joined(separator: ", ")
    }
}
