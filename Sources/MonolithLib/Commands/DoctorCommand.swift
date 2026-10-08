import ArgumentParser

struct DoctorCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check tool availability for Monolith features."
    )

    /// When a tool is needed.
    enum Requirement {
        /// Every command; a missing one fails `doctor`.
        case always
        /// Only some projects; a missing one is a warning.
        case forProjects(String)
        case optional

        var failsWhenMissing: Bool {
            if case .always = self { true } else { false }
        }
    }

    struct Tool {
        let name: String
        let versionFlag: String
        let requirement: Requirement
        let usedBy: String
        let installHint: String
    }

    static let tools: [Tool] = [
        Tool(name: "swift", versionFlag: "--version", requirement: .always, usedBy: "build and test",
             installHint: "Install Xcode from the App Store or https://swift.org/download/."),
        Tool(name: "git", versionFlag: "--version", requirement: .optional, usedBy: "version control (--git)",
             installHint: "Install Xcode Command Line Tools: `xcode-select --install`."),
        Tool(name: "xcodegen", versionFlag: "--version", requirement: .forProjects("new app"),
             usedBy: "new app (both project systems)", installHint: "brew install xcodegen"),
        Tool(name: "swiftlint", versionFlag: "version", requirement: .optional, usedBy: "devTooling feature", installHint: "brew install swiftlint"),
        Tool(name: "swiftformat", versionFlag: "--version", requirement: .optional, usedBy: "devTooling feature", installHint: "brew install swiftformat"),
        Tool(name: "mint", versionFlag: "version", requirement: .optional, usedBy: "rSwift feature (XcodeGen only)", installHint: "brew install mint"),
        Tool(name: "fastlane", versionFlag: "--version", requirement: .optional, usedBy: "fastlane feature (XcodeGen only)", installHint: "brew install fastlane"),
    ]

    /// Exits non-zero when a tool every command needs is missing, so scripts and CI can gate on it.
    func run() throws {
        print()
        print("  Monolith Doctor")
        print("  \(String(repeating: UISymbols.hRule, count: 40))")
        print()

        var allRequired = true
        var missingHints: [(name: String, hint: String)] = []
        var missingForProjects: [String] = []

        for tool in Self.tools {
            var status = ToolChecker.check(
                name: tool.name,
                versionFlag: tool.versionFlag,
                required: tool.requirement.failsWhenMissing
            )
            if case let .forProjects(projects) = tool.requirement {
                status.requirementNote = "required for \(projects)"
                if !status.available {
                    missingForProjects.append("\(tool.name) is missing, so \(projects) can't finish a project.")
                }
            }
            status.usedBy = tool.usedBy
            print(ToolChecker.formatStatus(status))

            if !status.available {
                missingHints.append((tool.name, tool.installHint))
                if status.required {
                    allRequired = false
                }
            }
        }

        if allRequired {
            print()
            print("  All required tools available.")
        }

        if !missingHints.isEmpty {
            print()
            print("  Install hints:")
            for (name, hint) in missingHints {
                print("    \(name): \(hint)")
            }
        }

        print()
        for warning in missingForProjects {
            Console.warn(warning)
        }
        guard allRequired else {
            Console.warn("Some required tools are missing.")
            throw ExitCode.failure
        }
    }
}
