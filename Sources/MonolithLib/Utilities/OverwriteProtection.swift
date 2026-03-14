import Foundation

enum OverwriteProtection {
    enum Result {
        case proceed
        case abort
    }

    /// Check if the output directory exists and is non-empty.
    /// Returns `.proceed` if safe to continue, `.abort` if user declines.
    static func check(
        projectName: String,
        outputDir: String?,
        force: Bool,
        interactive: Bool
    ) -> Result {
        let basePath = FileWriter.resolveOutputPath(projectName: projectName, outputDir: outputDir)

        guard directoryExistsAndNonEmpty(at: basePath) else {
            return .proceed
        }

        if force {
            print("  \u{26A0} Directory '\(basePath)' exists — overwriting (--force).")
            return .proceed
        }

        if interactive {
            print("  \u{26A0} Directory '\(basePath)' already exists and is non-empty.")
            let overwrite = PromptEngine.askYesNo(prompt: "Overwrite?", default: false)
            return overwrite ? .proceed : .abort
        }

        print("  Error: Directory '\(basePath)' already exists. Use --force to overwrite.")
        return .abort
    }

    /// Check if a directory exists and contains at least one item.
    static func directoryExistsAndNonEmpty(at path: String) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
        return !contents.isEmpty
    }
}
