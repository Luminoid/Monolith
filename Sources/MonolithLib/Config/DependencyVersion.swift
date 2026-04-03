/// Centralized dependency version strings used across generators.
enum DependencyVersion {
    static let snapKit = "5.7.0"
    static let lottie = "4.5.0"
    static let lookin = "1.2.8"
    static let lumiKit = "0.4.0"
    static let argumentParser = "1.7.0"
}

/// Centralized tool version strings used across generators.
enum ToolVersion {
    static let xcode = "16"
    static let swift = "6.2"
}

/// Centralized default values used across commands and generators.
enum Defaults {
    static let primaryColor = "#007AFF"
    static let deploymentTarget = "18.0"
    static let simulatorOS = "26.2"
    static let simulatorDevice = "iPhone 17"
    static let simulatorDestination = "platform=iOS Simulator,name=\(simulatorDevice),OS=\(simulatorOS)"
    static let defaultPlatform = "iPhone"
}
