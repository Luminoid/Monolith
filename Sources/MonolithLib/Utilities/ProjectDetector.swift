import Foundation

enum ProjectDetector {
    struct DetectedProject {
        let type: ProjectType
        let name: String
        let projectSystem: ProjectSystem?
    }

    /// Detect project type by examining the directory contents.
    ///
    /// Apps are XcodeGen (`project.yml`) or Xcode (`.xcodeproj`) projects;
    /// a `Package.swift` on its own is a library package or a command-line
    /// tool. The name comes from the project's own manifest, so a checkout in
    /// a differently named directory still resolves to its real target name.
    static func detect(at path: String) throws -> DetectedProject {
        let fm = FileManager.default
        let hasProjectYml = fm.fileExists(atPath: (path as NSString).appendingPathComponent("project.yml"))
        let hasPackageSwift = fm.fileExists(atPath: (path as NSString).appendingPathComponent("Package.swift"))
        let xcodeprojNames = xcodeprojNames(at: path, fm: fm)

        guard hasProjectYml || hasPackageSwift || !xcodeprojNames.isEmpty else {
            throw DetectionError.noProjectFound(path)
        }

        let directoryName = (path as NSString).lastPathComponent

        // XcodeGen app (project.yml present, with or without a generated .xcodeproj)
        if hasProjectYml {
            let name = projectYamlName(at: path) ?? xcodeprojName(xcodeprojNames, at: path) ?? directoryName
            return DetectedProject(type: .app, name: name, projectSystem: .xcodeGen)
        }

        // Xcode project (committed .xcodeproj, no project.yml)
        if !xcodeprojNames.isEmpty {
            let name = xcodeprojName(xcodeprojNames, at: path) ?? directoryName
            return DetectedProject(type: .app, name: name, projectSystem: .xcodeProj)
        }

        // Read Package.swift to tell a package from a CLI. An unreadable
        // manifest is an unknown project, not a library package: guessing
        // "package" would let `add` write files into a project it can't see.
        let packagePath = (path as NSString).appendingPathComponent("Package.swift")
        let content: String
        do {
            content = try String(contentsOfFile: packagePath, encoding: .utf8)
        } catch {
            throw DetectionError.unreadableManifest(packagePath, error.localizedDescription)
        }

        let name = packageName(in: content) ?? directoryName
        let type: ProjectType = isCommandLineTool(manifest: content) ? .cli : .package
        return DetectedProject(type: type, name: name, projectSystem: nil)
    }

    /// A manifest is a command-line tool when it has an executable target and
    /// no library product of its own. A package that ships an executable next
    /// to its libraries (a codegen tool, say) is still a package. The one
    /// library a CLI may export is its executable's `<TypeName>Kit` (the
    /// command types, kept in a library so tests can import them).
    static func isCommandLineTool(manifest: String) -> Bool {
        let executables = allMatches(#"\.executableTarget\(\s*name:\s*"([^"]+)""#, in: manifest)
        guard !executables.isEmpty else { return false }
        let kitNames = Set(executables.map { "\($0.upperCamelCased)Kit" })
        let libraries = allMatches(#"\.library\(\s*name:\s*"([^"]+)""#, in: manifest)
        return libraries.allSatisfy(kitNames.contains)
    }

    /// The `name:` at the top of a project.yml.
    static func projectYamlName(at path: String) -> String? {
        let yamlPath = (path as NSString).appendingPathComponent("project.yml")
        guard let content = try? String(contentsOfFile: yamlPath, encoding: .utf8) else { return nil }
        guard let raw = firstMatch(#"(?m)^name:[ \t]*(\S+)"#, in: content) else { return nil }
        return raw.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }

    /// The package name declared by `Package(name: "…")`.
    static func packageName(in manifest: String) -> String? {
        firstMatch(#"Package\s*\(\s*name:\s*"([^"]+)""#, in: manifest)
            ?? firstMatch(#"name:\s*"([^"]+)""#, in: manifest)
    }

    /// The basename of the project's `.xcodeproj`: the only one, or among
    /// several the one with a source directory of the same name.
    private static func xcodeprojName(_ names: [String], at path: String) -> String? {
        if names.count == 1 { return names[0] }
        return names.first { name in
            var isDirectory: ObjCBool = false
            let source = (path as NSString).appendingPathComponent(name)
            return FileManager.default.fileExists(atPath: source, isDirectory: &isDirectory) && isDirectory.boolValue
        }
    }

    /// Basenames (without extension) of the `.xcodeproj` bundles in the directory, sorted.
    private static func xcodeprojNames(at path: String, fm: FileManager) -> [String] {
        guard let entries = try? fm.contentsOfDirectory(atPath: path) else { return [] }
        return entries.filter { $0.hasSuffix(".xcodeproj") }
            .map { ($0 as NSString).deletingPathExtension }
            .sorted()
    }

    private static func allMatches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            Range($0.range(at: 1), in: text).map { String(text[$0]) }
        }
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[range])
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
        case noProjectFound(String)
        case unreadableManifest(String, String)

        var description: String {
            switch self {
            case let .noProjectFound(path):
                "No .xcodeproj, Package.swift, or project.yml found in \(path)."
            case let .unreadableManifest(path, reason):
                "Could not read \(path) (\(reason)), so the project type is unknown."
            }
        }
    }
}
