import Foundation

enum ProjectOpener {
    /// Open the appropriate project file after generation.
    @discardableResult
    static func open(at basePath: String, projectSystem: ProjectSystem) -> Bool {
        let path = target(at: basePath, projectSystem: projectSystem)
        let lastComponent = (path as NSString).lastPathComponent
        return ShellRunner.runDiscardingOutput(
            executable: "/usr/bin/open",
            arguments: [path],
            successLabel: "Opened \(lastComponent)",
            failureLabel: "Could not open \(lastComponent)"
        )
    }

    /// The file `open(at:projectSystem:)` opens: `Package.swift` for SPM, the
    /// `.xcodeproj` for an app, or the app's `project.yml` when xcodegen
    /// hasn't produced the `.xcodeproj` yet.
    static func target(at basePath: String, projectSystem: ProjectSystem) -> String {
        let projectName = (basePath as NSString).lastPathComponent
        let fileToOpen = switch projectSystem {
        case .xcodeProj, .xcodeGen: "\(projectName).xcodeproj"
        case .spm: "Package.swift"
        }
        let fullPath = (basePath as NSString).appendingPathComponent(fileToOpen)
        guard projectSystem != .spm, !FileManager.default.fileExists(atPath: fullPath) else { return fullPath }
        let ymlPath = (basePath as NSString).appendingPathComponent("project.yml")
        return FileManager.default.fileExists(atPath: ymlPath) ? ymlPath : fullPath
    }
}
