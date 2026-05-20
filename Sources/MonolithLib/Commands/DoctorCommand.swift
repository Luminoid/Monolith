import ArgumentParser

struct DoctorCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check tool availability for Monolith features."
    )

    func run() {
        print()
        print("  Monolith Doctor")
        print("  \(String(repeating: "\u{2500}", count: 40))")
        print()

        let tools: [(name: String, versionFlag: String, required: Bool, usedBy: String, installHint: String?)] = [
            ("swift", "--version", true, "Build & test", "Install Xcode from the App Store or https://swift.org/download/."),
            ("git", "--version", false, "Version control", "Install Xcode Command Line Tools: `xcode-select --install`."),
            ("swiftlint", "version", false, "devTooling feature", "brew install swiftlint"),
            ("swiftformat", "--version", false, "devTooling feature", "brew install swiftformat"),
            ("xcodegen", "--version", false, "xcodeGen project system", "brew install xcodegen"),
            ("mint", "version", false, "rSwift feature (XcodeGen only)", "brew install mint"),
            ("fastlane", "--version", false, "fastlane feature (XcodeGen only)", "brew install fastlane"),
        ]

        var allRequired = true
        var missingHints: [(name: String, hint: String)] = []

        for tool in tools {
            let status = ToolChecker.check(
                name: tool.name,
                versionFlag: tool.versionFlag,
                required: tool.required
            )
            print(ToolChecker.formatStatus(status))

            if !status.available, let hint = tool.installHint {
                missingHints.append((tool.name, hint))
            }
            if tool.required, !status.available {
                allRequired = false
            }
        }

        print()
        if allRequired {
            print("  All required tools available.")
        } else {
            print("  \u{26A0} Some required tools are missing.")
        }

        if !missingHints.isEmpty {
            print()
            print("  Install hints:")
            for (name, hint) in missingHints {
                print("    \(name): \(hint)")
            }
        }

        print()
    }
}
