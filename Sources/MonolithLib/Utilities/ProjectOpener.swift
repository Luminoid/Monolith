import Foundation

enum ProjectOpener {
    /// Open the appropriate project file after generation.
    @discardableResult
    static func open(at basePath: String, projectSystem: ProjectSystem) -> Bool {
        let projectName = (basePath as NSString).lastPathComponent

        let fileToOpen = switch projectSystem {
        case .xcodeProj, .xcodeGen: "\(projectName).xcodeproj"
        case .spm: "Package.swift"
        }

        let fullPath = (basePath as NSString).appendingPathComponent(fileToOpen)

        // Fallback: xcodeproj may not exist yet if xcodegen hasn't run
        let resolvedPath: String
        if projectSystem != .spm, !FileManager.default.fileExists(atPath: fullPath) {
            let ymlPath = (basePath as NSString).appendingPathComponent("project.yml")
            resolvedPath = FileManager.default.fileExists(atPath: ymlPath) ? ymlPath : fullPath
        } else {
            resolvedPath = fullPath
        }

        let lastComponent = (resolvedPath as NSString).lastPathComponent
        return ShellRunner.runDiscardingOutput(
            executable: "/usr/bin/open",
            arguments: [resolvedPath],
            successLabel: "Opened \(lastComponent)",
            failureLabel: "Could not open \(lastComponent)"
        )
    }
}
