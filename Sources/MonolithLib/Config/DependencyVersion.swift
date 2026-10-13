/// Centralized dependency version strings used across generators.
enum DependencyVersion {
    static let snapKit = "6.0.0"
    static let lottie = "4.6.1"
    static let lookin = "1.2.8"
    /// Emitted as `from:`, so it's the floor of a `>= x, < 2.0.0` range: any
    /// LumiKit 1.x release satisfies it.
    ///
    /// 1.0.0 is also the hard compile floor. The generated code uses the 1.0
    /// API throughout (the theme as an `LMKTheme` value applied with
    /// `LMKTheme.apply(_:)`, `LMKTabBarController` with `LMKTab`s,
    /// `LMKScene.configureMacWindow`), none of which exists in 0.x. Keep this
    /// at the current LumiKit release so fresh scaffolds resolve to it rather
    /// than to a version that's merely new enough.
    /// The `snapKit` floor above moves in lockstep with this pin, because
    /// LumiKit's own SnapKit requirement gates resolution (1.0.0 requires
    /// SnapKit `from: 6.0.0`, so a scaffold pinning an older SnapKit floor
    /// alongside it would be unresolvable). The `lottie` default satisfies
    /// LumiKit's `lottie-spm` requirement (`from: 4.4.0`), so an app linking
    /// both resolves to one Lottie.
    static let lumiKit = "1.0.0"
    static let argumentParser = "1.8.2"
}

/// Centralized tool version strings used across generators.
enum ToolVersion {
    /// Written to XcodeGen's `options.xcodeVersion`: the first Xcode release
    /// that ships the Swift 6.2 toolchain generated projects require.
    static let xcode = "26.0"
    static let swift = "6.2"

    /// Brewfile floor versions for the dev-tooling pins. Update when generated
    /// configs start using newer-than-floor features (e.g., a new SwiftLint
    /// rule or SwiftFormat option not present in the floor release).
    static let swiftlintFloor = "0.59"
    /// The first SwiftFormat release that knows every rule the generated
    /// `.swiftformat` enables or disables: `preferFinalClasses`, `redundantThrows`,
    /// and `redundantAsync` landed in 0.58.0, `redundantMemberwiseInit` in 0.59.0,
    /// `redundantVariable` took that name (renamed from `redundantProperty`)
    /// in 0.60.1, and `wrapIfStatementBodies` / `wrapIfExpressionBodies` split
    /// out of `wrapConditionalBodies` in 0.62.0. Older releases reject the
    /// config as an unknown rule.
    static let swiftformatFloor = "0.62.0"
    static let xcodegenFloor = "2.42"
}

/// Centralized default values used across commands and generators.
enum Defaults {
    static let primaryColor = "#007AFF"
    static let deploymentTarget = "18.0"
    static let simulatorOS = "26.2"
    static let simulatorDevice = "iPhone 17"
    static let simulatorDestination = "platform=iOS Simulator,name=\(simulatorDevice),OS=\(simulatorOS)"
    static let defaultPlatform = "iPhone,iPad"
}
