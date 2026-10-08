import Foundation

enum ToolChecker {
    struct ToolStatus {
        let name: String
        let available: Bool
        let version: String?
        let required: Bool
        /// Shown after the status instead of " (required)", for a tool only
        /// some projects need (e.g. "required for new app").
        var requirementNote: String?
        /// What uses the tool, shown at the end of the line.
        var usedBy: String?
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
        return versionLine(in: output)
    }

    /// The first line of `--version` output that carries a version number
    /// (`1.2` or longer) and isn't a path. Some tools print a banner first:
    /// fastlane opens with "fastlane installation at path:" and the install
    /// path, which holds a version of its own.
    static func versionLine(in output: String) -> String? {
        let lines = output.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        return lines.first { line in
            !line.contains("/") && line.range(of: #"\d+\.\d+"#, options: .regularExpression) != nil
        }
    }

    /// Format a ToolStatus for display.
    static func formatStatus(_ status: ToolStatus) -> String {
        let icon = status.available ? UISymbols.check : UISymbols.cross
        let label = status.required ? " (required)" : status.requirementNote.map { " (\($0))" } ?? ""
        let version = status.version.map { " (\($0))" } ?? ""
        let usedBy = status.usedBy.map { ": \($0)" } ?? ""
        return "  \(icon) \(status.name)\(label)\(version)\(usedBy)"
    }
}
