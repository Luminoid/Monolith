import Foundation

enum ProjectDetector {
    struct DetectedProject: Sendable {
        let type: ProjectType
        let name: String
        let projectSystem: ProjectSystem?
    }

    /// Detect project type by examining the directory contents.
    static func detect(at path: String) throws -> DetectedProject {
        let fm = FileManager.default
        let hasProjectYml = fm.fileExists(atPath: (path as NSString).appendingPathComponent("project.yml"))
        let hasPackageSwift = fm.fileExists(atPath: (path as NSString).appendingPathComponent("Package.swift"))

        guard hasProjectYml || hasPackageSwift else {
            throw DetectionError.noProjectFound
        }

        // XcodeGen app
        if hasProjectYml {
            let name = detectProjectName(at: path) ?? (path as NSString).lastPathComponent
            return DetectedProject(type: .app, name: name, projectSystem: .xcodeGen)
        }

        // Read Package.swift to distinguish app/cli/package
        let packagePath = (path as NSString).appendingPathComponent("Package.swift")
        let content = (try? String(contentsOfFile: packagePath, encoding: .utf8)) ?? ""

        let hasExecutableTarget = content.contains(".executableTarget(")
        let hasAppDir = fm.fileExists(atPath: (path as NSString).appendingPathComponent("Sources"))
            && directoryContainsAppStructure(at: path)

        let name = detectProjectName(at: path) ?? (path as NSString).lastPathComponent

        if hasExecutableTarget, hasAppDir {
            return DetectedProject(type: .app, name: name, projectSystem: .spm)
        } else if hasExecutableTarget {
            return DetectedProject(type: .cli, name: name, projectSystem: nil)
        } else {
            return DetectedProject(type: .package, name: name, projectSystem: nil)
        }
    }

    /// Check if the Sources/ directory contains app-like structure (App/AppDelegate.swift).
    private static func directoryContainsAppStructure(at path: String) -> Bool {
        let fm = FileManager.default
        let sourcesPath = (path as NSString).appendingPathComponent("Sources")
        guard let entries = try? fm.contentsOfDirectory(atPath: sourcesPath) else { return false }

        for entry in entries {
            let appDir = (sourcesPath as NSString).appendingPathComponent(entry)
            let appDelegate = (appDir as NSString).appendingPathComponent("App/AppDelegate.swift")
            if fm.fileExists(atPath: appDelegate) { return true }
        }
        return false
    }

    /// Try to extract the project name from Package.swift or directory name.
    private static func detectProjectName(at path: String) -> String? {
        let packagePath = (path as NSString).appendingPathComponent("Package.swift")
        guard let content = try? String(contentsOfFile: packagePath, encoding: .utf8) else { return nil }

        // Look for: name: "ProjectName"
        let pattern = #"name:\s*"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range(at: 1), in: content)
        else {
            return nil
        }
        return String(content[range])
    }

    enum DetectionError: Error, CustomStringConvertible {
        case noProjectFound

        var description: String {
            switch self {
            case .noProjectFound:
                "No Package.swift or project.yml found in current directory."
            }
        }
    }
}
