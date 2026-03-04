import ArgumentParser

struct DoctorCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check tool availability for Monolith features.",
    )

    func run() {
        print()
        print("  Monolith Doctor")
        print("  \(String(repeating: "\u{2500}", count: 40))")
        print()

        let tools: [(name: String, versionFlag: String, required: Bool, usedBy: String)] = [
            ("swift", "--version", true, "Build & test"),
            ("git", "--version", false, "Version control"),
            ("swiftlint", "version", false, "devTooling feature"),
            ("swiftformat", "--version", false, "devTooling feature"),
            ("xcodegen", "--version", false, "xcodeGen project system"),
            ("mint", "version", false, "rSwift feature"),
            ("fastlane", "--version", false, "fastlane feature"),
        ]

        var allRequired = true

        for tool in tools {
            let status = ToolChecker.check(
                name: tool.name,
                versionFlag: tool.versionFlag,
                required: tool.required,
            )
            print(ToolChecker.formatStatus(status))

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
        print()
    }
}
