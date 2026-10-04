import Foundation

enum ProjectDetector {
    struct DetectedProject {
        let type: ProjectType
        let name: String
        let projectSystem: ProjectSystem?
    }

    /// Detect project type by examining the directory contents.
    static func detect(at path: String) throws -> DetectedProject {
        let fm = FileManager.default
        let hasProjectYml = fm.fileExists(atPath: (path as NSString).appendingPathComponent("project.yml"))
        let hasPackageSwift = fm.fileExists(atPath: (path as NSString).appendingPathComponent("Package.swift"))
        let hasXcodeproj = detectXcodeproj(at: path, fm: fm)

        guard hasProjectYml || hasPackageSwift || hasXcodeproj else {
            throw DetectionError.noProjectFound
        }

        // Xcode project (committed .xcodeproj, no project.yml)
        if hasXcodeproj, !hasProjectYml {
            let name = detectProjectName(at: path) ?? (path as NSString).lastPathComponent
            return DetectedProject(type: .app, name: name, projectSystem: .xcodeProj)
        }

        // XcodeGen app (project.yml present)
        if hasProjectYml {
            let name = detectProjectName(at: path) ?? (path as NSString).lastPathComponent
            return DetectedProject(type: .app, name: name, projectSystem: .xcodeGen)
        }

        // Read Package.swift to distinguish app/cli/package. An unreadable
        // manifest is an unknown project, not a library package: guessing
        // "package" would let `add` write files into a project it can't see.
        let packagePath = (path as NSString).appendingPathComponent("Package.swift")
        let content: String
        do {
            content = try String(contentsOfFile: packagePath, encoding: .utf8)
        } catch {
            throw DetectionError.unreadableManifest(packagePath, error.localizedDescription)
        }

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

    /// Check if the directory contains a .xcodeproj bundle.
    private static func detectXcodeproj(at path: String, fm: FileManager) -> Bool {
        guard let entries = try? fm.contentsOfDirectory(atPath: path) else { return false }
        return entries.contains { $0.hasSuffix(".xcodeproj") }
    }

    /// Whether the app links LumiKit's UI product, read from its manifest: `project.yml`,
    /// `Package.swift`, or a committed `.xcodeproj`'s `project.pbxproj`. Matches the product
    /// name, so a LumiKit dependency by URL or by local path both count.
    static func linksLumiKitUI(at path: String) -> Bool {
        var manifests = ["project.yml", "Package.swift"].map { (path as NSString).appendingPathComponent($0) }
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
        manifests += entries.filter { $0.hasSuffix(".xcodeproj") }.map {
            (path as NSString).appendingPathComponent("\($0)/project.pbxproj")
        }
        return manifests.contains { manifest in
            (try? String(contentsOfFile: manifest, encoding: .utf8))?.contains("LumiKitUI") == true
        }
    }

    enum DetectionError: Error, CustomStringConvertible {
        case noProjectFound
        case unreadableManifest(String, String)

        var description: String {
            switch self {
            case .noProjectFound:
                "No .xcodeproj, Package.swift, or project.yml found in current directory."
            case let .unreadableManifest(path, reason):
                "Could not read \(path) (\(reason)), so the project type is unknown."
            }
        }
    }
}
