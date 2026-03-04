import Foundation

enum ToolChecker {
    struct ToolStatus: Sendable {
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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return path?.isEmpty == true ? nil : path
        } catch {
            return nil
        }
    }

    /// Get the version string from a tool.
    private static func toolVersion(at path: String, flag: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = [flag]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            // Extract first line, trim common prefixes
            let firstLine = output.components(separatedBy: .newlines).first ?? output
            return firstLine.isEmpty ? nil : firstLine
        } catch {
            return nil
        }
    }

    /// Format a ToolStatus for display.
    static func formatStatus(_ status: ToolStatus) -> String {
        let icon = status.available ? "\u{2713}" : "\u{2717}"
        let label = status.required ? " (required)" : ""
        let version = status.version.map { " — \($0)" } ?? ""
        return "  \(icon) \(status.name)\(label)\(version)"
    }
}
