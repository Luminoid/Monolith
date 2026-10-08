import Foundation

/// What `monolith add` reads from an existing project before planning a
/// feature, so the files it writes match what `monolith new` would have
/// written for the same project (a Makefile that audits the string catalog
/// the project already has, a pre-commit hook with the Core Data reminder
/// when the model syncs through CloudKit, the widget under the app's real
/// bundle ID, and so on).
///
/// Built once per `add` by `scan(at:detected:)`. Everything is read from the
/// project's own files; nothing is inferred from the directory name.
struct ProjectState {
    let root: String
    let type: ProjectType
    let name: String
    let projectSystem: ProjectSystem?

    // MARK: - App

    /// The app target's `PRODUCT_BUNDLE_IDENTIFIER`, from project.yml or
    /// project.pbxproj; `nil` when unset or built from variables.
    var bundleID: String?
    var deploymentTarget: String?
    var platforms: Set<Platform> = [.iPhone, .iPad]
    var linksLumiKit = false
    var hasLottie = false
    var hasSnapKit = false
    /// A `Localizable.xcstrings` anywhere in the project, relative paths.
    var stringCatalogs: [String] = []
    /// `Scripts/localization/audit_strings.py`, the script the Makefile's
    /// `check` runs when localization is on.
    var hasLocalizationAudit = false
    var hasAppIconValidation = false
    /// The `AppIcon.appiconset` the icon validator should read, relative.
    var appIconSetPath: String?
    var hasFastlane = false
    var hasRSwift = false
    var hasCoreDataModel = false
    var hasSwiftDataModels = false
    var hasCombine = false
    var hasCloudKit = false
    var hasMacCatalyst = false
    var hasWidget = false
    var hasGitHooks = false
    var hasDevTooling = false
    var hasPrivacyManifest = false
    var hasCategory = false
    /// Tab names, when the app has a `MainTabBarController`.
    var tabs: [String] = []
    /// The app target's entitlements file, relative: its
    /// `CODE_SIGN_ENTITLEMENTS` when set, else `<App>/<App>.entitlements`.
    var appEntitlementsPath: String
    /// Whether the app target sets `CODE_SIGN_ENTITLEMENTS` at all.
    var setsAppEntitlements = false
    /// The Mac-only entitlements file: the target's
    /// `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]` when set, else
    /// `<App>/<App>-MacCatalyst.entitlements`.
    var catalystEntitlementsPath: String
    /// Whether `<App>/Core/AppConstants.swift` declares `enum MacWindow`.
    var definesMacWindowConstants = false
    /// Whether the scene delegate already sets up the Mac window
    /// (`MacWindowConfig.configure` or `LMKScene.configureMacWindow`).
    var configuresMacWindow = false

    // MARK: - Package

    var packageTargets: [TargetDefinition] = []
    var mainActorTargets: Set<String> = []
    var packagePlatforms: [PlatformVersion] = []
    var usesArgumentParser = false
    /// The logging core a package carries: a `Sources/<Target>/Logging/<Prefix>Log.swift`
    /// in one of its library targets, as `new package` writes it.
    var logCore: LogCoreGenerator.Placement?
    /// Whether a CLI keeps its command in a `Sources/<TypeName>Kit/` library,
    /// the layout `new cli` writes.
    var hasCLIKitLibrary = false

    init(root: String, type: ProjectType, name: String, projectSystem: ProjectSystem?) {
        self.root = root
        self.type = type
        self.name = name
        self.projectSystem = projectSystem
        appEntitlementsPath = EntitlementsGenerator.appPath(appName: name)
        catalystEntitlementsPath = EntitlementsGenerator.macCatalystPath(appName: name)
    }

    // MARK: - Derived

    /// The configs below feed generators that never print the author.
    private static let placeholderAuthor = GitRunner.placeholderAuthor

    /// Swift Testing's worker pool is pinned to one for a Core Data app (its
    /// suites share the stack singleton) and for a SwiftData app that syncs
    /// through CloudKit, as `new` does. Mirrors
    /// `TestGenerator.appTestsRunSerially(config:)`; keep the two in step.
    var disableTestParallelism: Bool {
        hasCoreDataModel || (hasSwiftDataModels && hasCloudKit)
    }

    /// A Core Data model that syncs through CloudKit gets the schema-audit reminder in the pre-commit hook.
    var needsCoreDataAuditHook: Bool {
        hasCoreDataModel && hasCloudKit
    }

    /// The package as `new package` would describe it: targets, MainActor
    /// isolation, and with them the xcodebuild scheme and whether `swift build`
    /// works on a Mac host.
    var packageConfig: PackageConfig {
        PackageConfig(
            name: name,
            platforms: packagePlatforms,
            targets: packageTargets,
            features: mainActorTargets.isEmpty ? [] : [.defaultIsolation],
            mainActorTargets: mainActorTargets,
            author: Self.placeholderAuthor,
            licenseType: .mit
        )
    }

    var packageRequiresXcodebuild: Bool {
        type == .package && packageConfig.requiresXcodebuild
    }

    var xcodeBuildScheme: String? {
        type == .package ? packageConfig.xcodeBuildScheme : nil
    }

    var cliConfig: CLIConfig {
        var features: Set<CLIFeature> = []
        if usesArgumentParser { features.insert(.argumentParser) }
        if hasDevTooling { features.insert(.devTooling) }
        if hasGitHooks { features.insert(.gitHooks) }
        return CLIConfig(
            name: name,
            includeArgumentParser: usesArgumentParser,
            features: features,
            author: Self.placeholderAuthor,
            licenseType: .apache2
        )
    }

    /// The app as `new app` would describe it, from what the project contains.
    /// `extraFeatures` and `locales` describe the feature being added.
    func appConfig(extraFeatures: Set<AppFeature> = [], locales: [String] = ["en"]) -> AppConfig {
        var features = extraFeatures
        let flags: [(Bool, AppFeature)] = [
            (hasSwiftDataModels, .swiftData), (hasCoreDataModel, .coreData), (hasCloudKit, .cloudKit),
            (linksLumiKit, .lumiKit), (hasLottie, .lottie), (hasCombine, .combine),
            (hasDevTooling, .devTooling), (hasGitHooks, .gitHooks), (!stringCatalogs.isEmpty, .localization),
            (hasWidget, .widget), (hasPrivacyManifest, .privacyManifest), (hasAppIconValidation, .appIconValidation),
            (hasFastlane, .fastlane), (hasRSwift, .rSwift),
        ]
        for (present, feature) in flags where present {
            features.insert(feature)
        }
        var appPlatforms = platforms
        if hasMacCatalyst { appPlatforms.insert(.macCatalyst) }
        // AppConfig knows SnapKit only as an external package; CLAUDE.md lists it.
        var externals: [ExternalPackage] = []
        if hasSnapKit, let entry = KnownPackages.registry["SnapKit"] {
            externals.append(ExternalPackage(name: entry.name, url: entry.url, requirement: "from: \"\(entry.defaultVersion)\"", packageName: nil))
        }
        return AppConfig(
            name: name,
            bundleID: bundleID ?? Validators.defaultBundleID(for: name),
            deploymentTarget: deploymentTarget ?? Defaults.deploymentTarget,
            platforms: appPlatforms,
            projectSystem: projectSystem ?? .xcodeProj,
            tabs: tabs.map { TabDefinition(name: $0, icon: "circle") },
            primaryColor: Defaults.primaryColor,
            features: features,
            author: Self.placeholderAuthor,
            licenseType: .proprietary,
            externalPackages: externals,
            locales: locales
        )
    }
}

// MARK: - Scanning

extension ProjectState {
    static func scan(at root: String, detected: ProjectDetector.DetectedProject) -> Self {
        var state = Self(root: root, type: detected.type, name: detected.name, projectSystem: detected.projectSystem)
        state.hasDevTooling = state.exists(".swiftlint.yml") && state.exists("Makefile")
        state.hasGitHooks = state.exists("Scripts/git-hooks/pre-commit")
        switch detected.type {
        case .app:
            state.scanApp()
        case .package, .cli:
            state.scanPackage()
        }
        return state
    }

    func exists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: (root as NSString).appendingPathComponent(relativePath))
    }

    func read(_ relativePath: String) -> String? {
        try? String(contentsOfFile: (root as NSString).appendingPathComponent(relativePath), encoding: .utf8)
    }

    private mutating func scanApp() {
        hasLocalizationAudit = exists("Scripts/localization/audit_strings.py")
        hasAppIconValidation = exists("Scripts/validate-app-icon.sh")
        hasFastlane = exists("Gemfile") || exists("fastlane")
        let mintfile = read("Mintfile")?.lowercased() ?? ""
        hasRSwift = mintfile.contains("rswift") || mintfile.contains("r.swift")
        hasPrivacyManifest = exists("\(name)/Resources/PrivacyInfo.xcprivacy")
        linksLumiKit = ProjectDetector.linksLumiKitUI(at: root)
        definesMacWindowConstants = read("\(name)/Core/AppConstants.swift")?.contains("enum MacWindow") == true
        let sceneDelegate = read("\(name)/App/SceneDelegate.swift") ?? ""
        configuresMacWindow = sceneDelegate.contains("MacWindowConfig.configure") || sceneDelegate.contains("configureMacWindow(")
        if exists("\(name)/App/MainTabBarController.swift") {
            tabs = Self.featureTabs(in: (root as NSString).appendingPathComponent("\(name)/Features"))
        }

        if projectSystem == .xcodeGen, let yaml = read("project.yml") {
            readProjectYaml(yaml)
        } else if let pbxproj = read("\(name).xcodeproj/project.pbxproj") {
            readPBXProject(pbxproj)
        }
        hasWidget = hasWidget || exists("\(name)Widget")
        let entitlements = read(appEntitlementsPath) ?? ""
        hasCloudKit = entitlements.contains("CloudKit")

        walkTree()
    }

    private mutating func readProjectYaml(_ yaml: String) {
        bundleID = Self.usableBundleID(ProjectYamlEditor.bundleIdentifier(ofTarget: name, in: yaml))
        if let path = ProjectYamlEditor.setting("CODE_SIGN_ENTITLEMENTS", ofTarget: name, in: yaml) {
            appEntitlementsPath = Self.projectRelative(path)
            setsAppEntitlements = true
        }
        if let path = ProjectYamlEditor.setting("CODE_SIGN_ENTITLEMENTS[sdk=macosx*]", ofTarget: name, in: yaml) {
            catalystEntitlementsPath = Self.projectRelative(path)
        }
        if let family = ProjectYamlEditor.setting("TARGETED_DEVICE_FAMILY", ofTarget: name, in: yaml) {
            platforms = Self.platforms(fromDeviceFamily: family)
        }
        hasCategory = ProjectYamlEditor.setting("INFOPLIST_KEY_LSApplicationCategoryType", ofTarget: name, in: yaml) != nil
        hasMacCatalyst = ProjectYamlEditor.targetSupportsMacCatalyst(name, in: yaml)
        hasWidget = ProjectYamlEditor.hasTarget("\(name)Widget", in: yaml)
        deploymentTarget = Self.firstMatch(#"(?m)^[ \t]+iOS:[ \t]*["']?([0-9.]+)"#, in: yaml)
        hasLottie = yaml.contains("lottie-spm")
        hasSnapKit = yaml.contains("SnapKit")
    }

    private mutating func readPBXProject(_ pbxproj: String) {
        let settings = PBXProjectReader(text: pbxproj).appBuildSettings(targetName: name)
        bundleID = Self.usableBundleID(settings["PRODUCT_BUNDLE_IDENTIFIER"])
        if let path = settings["CODE_SIGN_ENTITLEMENTS"] {
            appEntitlementsPath = Self.projectRelative(path)
            setsAppEntitlements = true
        }
        if let path = settings["CODE_SIGN_ENTITLEMENTS[sdk=macosx*]"] {
            catalystEntitlementsPath = Self.projectRelative(path)
        }
        if let family = settings["TARGETED_DEVICE_FAMILY"] {
            platforms = Self.platforms(fromDeviceFamily: family)
        }
        hasCategory = settings["INFOPLIST_KEY_LSApplicationCategoryType"] != nil
        hasMacCatalyst = settings["SUPPORTS_MACCATALYST"] == "YES"
        deploymentTarget = settings["IPHONEOS_DEPLOYMENT_TARGET"]
            ?? Self.firstMatch(#"IPHONEOS_DEPLOYMENT_TARGET = "?([0-9.]+)"?;"#, in: pbxproj)
        hasLottie = pbxproj.contains("lottie-spm")
        hasSnapKit = pbxproj.contains("SnapKit")
    }

    /// One pass over the project tree for the facts that live in files:
    /// string catalogs, the app icon set, Core Data models, R.swift output,
    /// and SwiftData `@Model` / `import Combine` in the app's sources.
    private mutating func walkTree() {
        let rootURL = URL(fileURLWithPath: root)
        let skipped: Set = ["build", "DerivedData", "Pods", "Carthage", "node_modules"]
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        let rootPrefix = rootURL.standardizedFileURL.path + "/"
        let sourcePrefix = rootPrefix + name + "/"

        for case let url as URL in enumerator {
            let path = url.standardizedFileURL.path
            let relative = path.hasPrefix(rootPrefix) ? String(path.dropFirst(rootPrefix.count)) : path
            let fileName = url.lastPathComponent
            switch url.pathExtension {
            case "xcodeproj", "xcworkspace":
                enumerator.skipDescendants()
            case "xcdatamodeld":
                hasCoreDataModel = true
                enumerator.skipDescendants()
            case "appiconset":
                if appIconSetPath == nil, fileName == "AppIcon.appiconset" { appIconSetPath = relative }
                enumerator.skipDescendants()
            case "xcstrings" where fileName == "Localizable.xcstrings":
                stringCatalogs.append(relative)
            case "swift":
                if fileName == "R.generated.swift" { hasRSwift = true }
                guard path.hasPrefix(sourcePrefix), let source = try? String(contentsOf: url, encoding: .utf8) else { continue }
                if source.contains("@Model") { hasSwiftDataModels = true }
                if source.contains("import Combine") { hasCombine = true }
            default:
                if skipped.contains(fileName) { enumerator.skipDescendants() }
            }
        }
        stringCatalogs.sort()
    }

    private mutating func scanPackage() {
        guard let manifest = read("Package.swift") else { return }
        let parsed = PackageManifestReader(manifest: manifest)
        packageTargets = parsed.targets
        mainActorTargets = parsed.mainActorTargets
        packagePlatforms = parsed.platforms
        usesArgumentParser = manifest.contains("swift-argument-parser")
        logCore = findLogCore()
        hasCLIKitLibrary = exists("Sources/\(cliConfig.libraryName)")
    }

    /// The first library target with a `Logging/<Prefix>Log.swift`, read
    /// back into the placement `LogCoreGenerator` would describe it with.
    private func findLogCore() -> LogCoreGenerator.Placement? {
        for target in packageTargets where !target.isExecutable {
            let directory = "Sources/\(target.name)/Logging"
            let entries = (try? FileManager.default.contentsOfDirectory(atPath: (root as NSString).appendingPathComponent(directory))) ?? []
            for entry in entries.sorted() where entry.hasSuffix("Log.swift") {
                let prefix = String(entry.dropLast("Log.swift".count))
                guard !prefix.isEmpty, !prefix.contains("+"),
                      let source = read("\(directory)/\(entry)"),
                      let subsystem = Self.firstMatch(#"static let subsystem = "([^"]+)""#, in: source)
                else { continue }
                return LogCoreGenerator.Placement(module: target.name, prefix: prefix, subsystem: subsystem)
            }
        }
        return nil
    }

    // MARK: Helpers

    /// A build-setting path relative to the project root: a leading
    /// `$(SRCROOT)/` or `$(PROJECT_DIR)/` is dropped.
    static func projectRelative(_ path: String) -> String {
        for prefix in ["$(SRCROOT)/", "${SRCROOT}/", "$(PROJECT_DIR)/", "${PROJECT_DIR}/"] where path.hasPrefix(prefix) {
            return String(path.dropFirst(prefix.count))
        }
        return path
    }

    /// A bundle ID usable as the widget's prefix: set, and not built from build-setting variables.
    private static func usableBundleID(_ value: String?) -> String? {
        guard let value, !value.isEmpty, !value.contains("$") else { return nil }
        return value
    }

    /// `TARGETED_DEVICE_FAMILY` (`1` iPhone, `2` iPad) to platforms.
    static func platforms(fromDeviceFamily family: String) -> Set<Platform> {
        let ids = family.trimmingCharacters(in: CharacterSet(charactersIn: "\"' ")).split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        var result: Set<Platform> = []
        if ids.contains("1") { result.insert(.iPhone) }
        if ids.contains("2") { result.insert(.iPad) }
        return result.isEmpty ? [.iPhone, .iPad] : result
    }

    /// The tab names of a tab-bar app: each `Features/<Tab>/` holding a `<Tab>ViewController.swift`.
    private static func featureTabs(in featuresDir: String) -> [String] {
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: featuresDir)) ?? []
        return entries.sorted().filter { entry in
            FileManager.default.fileExists(atPath: "\(featuresDir)/\(entry)/\(entry)ViewController.swift")
        }
    }

    static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[range])
    }
}

// MARK: - project.pbxproj

/// Reads one target's build settings out of a `project.pbxproj`: the native
/// application target with the given name, through its configuration list,
/// to its first build configuration's single-line settings.
struct PBXProjectReader {
    let text: String

    func appBuildSettings(targetName: String) -> [String: String] {
        let objects = objects()
        let isApp = { (body: String) in
            body.contains("isa = PBXNativeTarget;")
                && body.contains("productType = \"com.apple.product-type.application\";")
                && (body.contains("\tname = \(targetName);") || body.contains("\tname = \"\(targetName)\";"))
        }
        guard let target = objects.first(where: { isApp($0.body) }),
              let listID = ProjectState.firstMatch(#"buildConfigurationList = ([0-9A-Za-z]+)"#, in: target.body),
              let list = objects.first(where: { $0.id == listID }),
              let configID = ProjectState.firstMatch(#"buildConfigurations = \(\s*([0-9A-Za-z]+)"#, in: list.body),
              let config = objects.first(where: { $0.id == configID })
        else {
            return [:]
        }
        var settings: [String: String] = [:]
        for line in config.body.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasSuffix(";"), let equals = trimmed.range(of: " = ") else { continue }
            let key = unquoted(String(trimmed[..<equals.lowerBound]))
            let value = unquoted(String(trimmed[equals.upperBound...].dropLast()))
            if settings[key] == nil { settings[key] = value }
        }
        return settings
    }

    /// The multi-line objects of the file (`\t\t<ID> /* … */ = {` through
    /// `\t\t};`), by ID. One-line objects such as build files are skipped.
    private func objects() -> [(id: String, body: String)] {
        var result: [(id: String, body: String)] = []
        var currentID: String?
        var body: [Substring] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if let id = currentID {
                if line == "\t\t};" {
                    result.append((id, body.joined(separator: "\n")))
                    currentID = nil
                    body = []
                } else {
                    body.append(line)
                }
            } else if line.hasPrefix("\t\t"), !line.hasPrefix("\t\t\t"), line.hasSuffix("= {") {
                currentID = String(line.dropFirst(2).prefix { !$0.isWhitespace })
            }
        }
        return result
    }

    private func unquoted(_ value: String) -> String {
        guard value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") else { return value }
        return String(value.dropFirst().dropLast())
    }
}

// MARK: - Package.swift

/// Reads the target list of a `Package.swift` well enough to describe the
/// package: each library and executable target's name, its dependencies,
/// and whether it sets `defaultIsolation(MainActor.self)`. Test targets are
/// left out.
struct PackageManifestReader {
    private(set) var targets: [TargetDefinition] = []
    private(set) var mainActorTargets: Set<String> = []
    private(set) var platforms: [PlatformVersion] = []

    init(manifest: String) {
        let scanner = SwiftArgumentScanner(text: manifest)
        guard let packageArgs = scanner.callArguments(after: "Package(") else { return }
        for argument in packageArgs {
            if argument.hasPrefix("targets:"), let list = SwiftArgumentScanner(text: argument).listElements() {
                for element in list {
                    readTarget(element)
                }
            } else if argument.hasPrefix("platforms:"), let list = SwiftArgumentScanner(text: argument).listElements() {
                platforms = list.compactMap(Self.platformVersion)
            }
        }
    }

    private mutating func readTarget(_ element: String) {
        let isExecutable = element.hasPrefix(".executableTarget(")
        guard isExecutable || element.hasPrefix(".target("),
              let args = SwiftArgumentScanner(text: element).callArguments(after: "("),
              let nameArg = args.first(where: { $0.hasPrefix("name:") }),
              let name = ProjectState.firstMatch(#"name:\s*"([^"]+)""#, in: nameArg)
        else { return }
        var dependencies: [String] = []
        if let depsArg = args.first(where: { $0.hasPrefix("dependencies:") }),
           let items = SwiftArgumentScanner(text: depsArg).listElements() {
            dependencies = items.compactMap { item in
                ProjectState.firstMatch(#"^"([^"]+)"$"#, in: item) ?? ProjectState.firstMatch(#"name:\s*"([^"]+)""#, in: item)
            }
        }
        targets.append(TargetDefinition(name: name, dependencies: dependencies, isExecutable: isExecutable))
        if element.contains("defaultIsolation(MainActor.self)") {
            mainActorTargets.insert(name)
        }
    }

    /// `.iOS(.v18)` → iOS 18.0, `.macOS(.v15_4)` → macOS 15.4.
    private static func platformVersion(_ element: String) -> PlatformVersion? {
        guard let regex = try? NSRegularExpression(pattern: #"^\.(\w+)\(\.v(\d+)(?:_(\d+))?\)"#),
              let match = regex.firstMatch(in: element, range: NSRange(element.startIndex..., in: element)),
              let platform = Range(match.range(at: 1), in: element).map({ String(element[$0]) }),
              let major = Range(match.range(at: 2), in: element).map({ String(element[$0]) })
        else { return nil }
        let minor = Range(match.range(at: 3), in: element).map { String(element[$0]) } ?? "0"
        return PlatformVersion(platform: platform, version: "\(major).\(minor)")
    }
}

/// Splits Swift source into top-level call arguments and list elements,
/// skipping string literals and comments, which is enough to read a package
/// manifest's declarative shape without a Swift parser.
struct SwiftArgumentScanner {
    let text: String

    /// The comma-separated arguments of the call whose opening `marker`
    /// (ending in `(`) appears first, trimmed.
    func callArguments(after marker: String) -> [String]? {
        guard let start = text.range(of: marker) else { return nil }
        return elements(from: text.index(before: start.upperBound), close: ")")
    }

    /// The elements of the first `[...]` list in the text, trimmed.
    func listElements() -> [String]? {
        guard let open = text.firstIndex(of: "[") else { return nil }
        return elements(from: open, close: "]")
    }

    /// Elements between the bracket at `openIndex` and its matching `close`,
    /// split on the commas at that level.
    private func elements(from openIndex: String.Index, close: Character) -> [String]? {
        var depth = 0
        var current = ""
        var result: [String] = []
        var index = openIndex
        var inString = false
        while index < text.endIndex {
            let char = text[index]
            let next = text.index(after: index)
            if inString {
                current.append(char)
                if char == "\\", next < text.endIndex {
                    current.append(text[next])
                    index = text.index(after: next)
                    continue
                }
                if char == "\"" { inString = false }
                index = next
                continue
            }
            if char == "/", next < text.endIndex, text[next] == "/" {
                index = text[index...].firstIndex(of: "\n") ?? text.endIndex
                continue
            }
            switch char {
            case "\"":
                inString = true
                current.append(char)
            case "(", "[", "{":
                depth += 1
                if depth > 1 { current.append(char) }
            case ")", "]", "}":
                depth -= 1
                if depth == 0 {
                    let last = current.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !last.isEmpty { result.append(last) }
                    return char == close ? result : nil
                }
                current.append(char)
            case "," where depth == 1:
                result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            default:
                if depth >= 1 { current.append(char) }
            }
            index = next
        }
        return nil
    }
}
