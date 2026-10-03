import Foundation

enum OverwriteProtection {
    enum Result {
        case proceed
        case abort
    }

    /// What is at the output path before generation.
    enum DirectoryState: Equatable {
        /// Nothing there, an empty directory, or a file (generation fails on the file later).
        case absentOrEmpty
        case nonEmpty
        /// A directory whose contents could not be listed. Treated as non-empty.
        case unreadable(String)
    }

    /// Non-interactive generation into a non-empty directory without `--force`.
    struct RefusedError: Error, CustomStringConvertible {
        let description: String
    }

    /// Check if the output directory exists and is non-empty.
    /// Returns `.proceed` if safe to continue, `.abort` if the user declines
    /// the interactive prompt. Throws `RefusedError` when the directory is not
    /// empty (or can't be read) and there is neither `--force` nor a prompt.
    static func check(
        projectName: String,
        outputDir: String?,
        force: Bool,
        interactive: Bool
    ) throws -> Result {
        let basePath = FileWriter.resolveOutputPath(projectName: projectName, outputDir: outputDir)

        let problem: String
        switch directoryState(at: basePath) {
        case .absentOrEmpty:
            return .proceed
        case .nonEmpty:
            problem = "Directory '\(basePath)' already exists and is not empty."
        case let .unreadable(reason):
            problem = "Directory '\(basePath)' exists but could not be read (\(reason)), so it is treated as not empty."
        }

        if force {
            Console.warn("\(problem) Overwriting (--force).")
            return .proceed
        }

        if interactive {
            Console.warn(problem)
            let overwrite = PromptEngine.askYesNo(prompt: "Overwrite?", default: false)
            return overwrite ? .proceed : .abort
        }

        throw RefusedError(description: "\(problem) Use --force to overwrite.")
    }

    /// Check if a directory exists and contains at least one item. A directory
    /// that can't be listed counts as non-empty, so overwrite protection still
    /// prompts or refuses instead of writing into it.
    static func directoryExistsAndNonEmpty(at path: String) -> Bool {
        directoryState(at: path) != .absentOrEmpty
    }

    static func directoryState(at path: String) -> DirectoryState {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return .absentOrEmpty
        }
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: path)
            return contents.isEmpty ? .absentOrEmpty : .nonEmpty
        } catch {
            return .unreadable(error.localizedDescription)
        }
    }
}
