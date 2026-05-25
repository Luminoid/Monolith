import Foundation

enum ToolChecker {
    struct ToolStatus {
        let name: String
        let available: Bool
        let version: String?
        let required: Bool
    }

    /// Check if a tool is available and get its version.
    static func check(name: String, versionFlag: String = "--version", required: Bool = false) -> ToolStatus {
        guard let path = whichPath(for: name) else {
            return ToolStatus(name: name, available: false, version: nil, required: required)
        }

        let version = toolVersion(at: path, flag: versionFlag)
        return ToolStatus(name: name, available: true, version: version, required: required)
    }

    /// Find the full path of a command using /usr/bin/which.
    static func whichPath(for command: String) -> String? {
        ShellRunner.runCapturingStdout(
            executable: "/usr/bin/which",
            arguments: [command]
        )
    }

    /// Get the version string from a tool.
    private static func toolVersion(at path: String, flag: String) -> String? {
        guard let output = ShellRunner.runCapturingStdout(
            executable: path,
            arguments: [flag],
            mergeStderr: true
        ) else {
            return nil
        }
        // Some tools (e.g. xcodegen) emit a banner above the version on the
        // first line — but the contract is "first non-empty line."
        let firstLine = output.components(separatedBy: .newlines).first ?? output
        return firstLine.isEmpty ? nil : firstLine
    }

    /// Format a ToolStatus for display.
    static func formatStatus(_ status: ToolStatus) -> String {
        let icon = status.available ? UISymbols.check : UISymbols.cross
        let label = status.required ? " (required)" : ""
        let version = status.version.map { " (\($0))" } ?? ""
        return "  \(icon) \(status.name)\(label)\(version)"
    }
}
