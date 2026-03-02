import Foundation

enum FileWriter {

    /// Write a file at the given relative path under the base directory.
    /// Creates intermediate directories as needed. Prints a checkmark on success.
    static func writeFile(at relativePath: String, content: String, basePath: String) throws {
        let fullPath = (basePath as NSString).appendingPathComponent(relativePath)
        let directory = (fullPath as NSString).deletingLastPathComponent

        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        try content.write(toFile: fullPath, atomically: true, encoding: .utf8)
        print("  \u{2713} \(relativePath)")
    }

    /// Create a directory at the given relative path under the base directory.
    static func createDirectory(at relativePath: String, basePath: String) throws {
        let fullPath = (basePath as NSString).appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            atPath: fullPath,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    /// Check if a path exists.
    static func exists(at relativePath: String, basePath: String) -> Bool {
        let fullPath = (basePath as NSString).appendingPathComponent(relativePath)
        return FileManager.default.fileExists(atPath: fullPath)
    }

    /// Resolve the output base path: currentDirectory/projectName.
    static func resolveOutputPath(projectName: String, outputDir: String? = nil) -> String {
        let base = outputDir ?? FileManager.default.currentDirectoryPath
        return (base as NSString).appendingPathComponent(projectName)
    }

    /// Get the git author name, or nil if not configured.
    static func gitAuthorName() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["config", "user.name"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let name = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return name?.isEmpty == true ? nil : name
        } catch {
            return nil
        }
    }

    /// Initialize a git repository and create an initial commit.
    @discardableResult
    static func gitInit(at path: String) -> Bool {
        let commands: [(args: [String], label: String)] = [
            (["init"], "git init"),
            (["add", "."], "git add"),
            (["commit", "-m", "Initial commit"], "git commit"),
        ]

        for command in commands {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = command.args
            process.currentDirectoryURL = URL(fileURLWithPath: path)
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else { return false }
            } catch {
                return false
            }
        }

        print("  \u{2713} git repository initialized")
        return true
    }
}
