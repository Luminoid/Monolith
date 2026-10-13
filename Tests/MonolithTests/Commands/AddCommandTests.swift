import Foundation
import Testing
@testable import MonolithLib

@Suite(.serialized)
struct AddCommandTests {
    /// Generate a scaffold project of the requested system into a temp dir.
    /// Returns the absolute path to the generated project root (e.g. `<tmp>/<App>`).
    /// `.xcodeProj` runs xcodegen, so only tests gated on `xcodegenAvailable` use it.
    private func makeScaffold(
        projectSystem: ProjectSystem = .xcodeGen,
        features: Set<AppFeature> = [],
        platforms: Set<Platform> = [.iPhone],
        appName: String = "Scaffold",
        bundleID: String = "com.test.scaffold"
    ) throws -> String {
        let raw = NSTemporaryDirectory() + "monolith-add-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: raw, withIntermediateDirectories: true)

        let config = AppConfig(
            name: appName,
            bundleID: bundleID,
            deploymentTarget: "18.0",
            platforms: platforms,
            projectSystem: projectSystem,
            tabs: [],
            primaryColor: "#007AFF",
            features: features,
            author: "Test",
            licenseType: .proprietary
        )
        try AppProjectGenerator.generate(config: config, outputDir: raw)
        return "\(raw)/\(appName)"
    }

    /// An app that `add` sees as a `.xcodeproj` project without running
    /// xcodegen: an XcodeGen scaffold whose project.yml is swapped for a
    /// placeholder `.xcodeproj` directory. Enough for tests that only look
    /// at the files `add` writes.
    private func makeXcodeProjLikeScaffold(appName: String = "Scaffold") throws -> String {
        let projectRoot = try makeScaffold(appName: appName)
        try FileManager.default.removeItem(atPath: "\(projectRoot)/project.yml")
        try FileManager.default.createDirectory(
            atPath: "\(projectRoot)/\(appName).xcodeproj",
            withIntermediateDirectories: true
        )
        return projectRoot
    }

    private func cleanup(_ projectRoot: String) {
        // Project root sits under `<tmp>/<App>`; remove the parent tmp.
        let parent = (projectRoot as NSString).deletingLastPathComponent
        try? FileManager.default.removeItem(atPath: parent)
    }

    /// Run `AddCommand` with the given args.
    private func runAdd(args: [String]) throws {
        let cmd = try AddCommand.parse(args)
        try cmd.run()
    }

    private func read(_ path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }

    private func plist(_ path: String) throws -> [String: Any] {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    /// The column-0 key whose block contains the first line equal to `line`.
    private func topLevelParent(of line: String, in yaml: String) -> String? {
        let lines = yaml.components(separatedBy: "\n")
        guard let index = lines.firstIndex(of: line) else { return nil }
        return lines[...index].last { $0.first.map { !$0.isWhitespace && $0 != "#" } == true }
            .map { String($0.prefix { $0 != ":" }) }
    }

    // MARK: - Tier 1

    @Test
    func `add privacyManifest writes app manifest`() throws {
        let project = try makeScaffold()
        defer { cleanup(project) }

        try runAdd(args: ["privacyManifest", "--path", project])

        let manifest = "\(project)/Scaffold/Resources/PrivacyInfo.xcprivacy"
        #expect(FileManager.default.fileExists(atPath: manifest))
        let content = try read(manifest)
        #expect(content.contains("NSPrivacyTracking"))
        #expect(content.contains("NSPrivacyAccessedAPICategoryUserDefaults"))
    }

    @Test
    func `add privacyManifest also writes widget manifest when widget dir exists`() throws {
        let project = try makeScaffold()
        defer { cleanup(project) }

        // Simulate a pre-existing widget extension.
        try FileManager.default.createDirectory(
            atPath: "\(project)/ScaffoldWidget",
            withIntermediateDirectories: true
        )

        try runAdd(args: ["privacyManifest", "--path", project])

        #expect(FileManager.default.fileExists(atPath: "\(project)/Scaffold/Resources/PrivacyInfo.xcprivacy"))
        #expect(FileManager.default.fileExists(atPath: "\(project)/ScaffoldWidget/PrivacyInfo.xcprivacy"))
    }

    @Test
    func `add appIconValidation writes executable script`() throws {
        let project = try makeScaffold()
        defer { cleanup(project) }

        try runAdd(args: ["appIconValidation", "--path", project])

        let script = "\(project)/Scripts/validate-app-icon.sh"
        #expect(FileManager.default.fileExists(atPath: script))
        let attrs = try FileManager.default.attributesOfItem(atPath: script)
        let permissions = attrs[.posixPermissions] as? Int
        #expect(permissions == 0o755)
        let content = try read(script)
        #expect(content.contains("App Store Connect"))
        #expect(content.contains("Scaffold/Resources/Assets.xcassets/AppIcon.appiconset"))
    }

    @Test
    func `add dry-run does not write files`() throws {
        let project = try makeScaffold()
        defer { cleanup(project) }

        try runAdd(args: ["privacyManifest", "--path", project, "--dry-run"])
        try runAdd(args: ["widget", "--path", project, "--dry-run"])

        #expect(!FileManager.default.fileExists(atPath: "\(project)/Scaffold/Resources/PrivacyInfo.xcprivacy"))
        #expect(!FileManager.default.fileExists(atPath: "\(project)/ScaffoldWidget"))
        #expect(!FileManager.default.fileExists(atPath: "\(project)/Scaffold/Scaffold.entitlements"))
        #expect(try !read("\(project)/project.yml").contains("ScaffoldWidget"))
    }

    @Test
    func `add unknown feature throws ValidationError`() throws {
        let project = try makeScaffold()
        defer { cleanup(project) }

        #expect(throws: (any Error).self) {
            try runAdd(args: ["notAFeature", "--path", project])
        }
    }

    @Test
    func `the feature argument's help lists the addable features`() {
        let help = AddCommand.helpMessage()
        for feature in AddableFeature.allCases {
            #expect(help.contains(feature.rawValue))
        }
        #expect(!help.contains("monolith list features"))
    }

    // MARK: - Existing files

    @Test
    func `add keeps an existing LICENSE and CHANGELOG`() throws {
        let project = try makeScaffold()
        defer { cleanup(project) }
        let changelog = "# Changelog\n\n## 1.2.0\n- Shipped things.\n"
        let license = "Custom license text.\n"
        try changelog.write(toFile: "\(project)/CHANGELOG.md", atomically: true, encoding: .utf8)
        try license.write(toFile: "\(project)/LICENSE", atomically: true, encoding: .utf8)

        try runAdd(args: ["licenseChangelog", "--path", project])

        #expect(try read("\(project)/CHANGELOG.md") == changelog)
        #expect(try read("\(project)/LICENSE") == license)
    }

    @Test
    func `add --force overwrites existing files`() throws {
        let project = try makeScaffold()
        defer { cleanup(project) }
        try "Custom license text.\n".write(toFile: "\(project)/LICENSE", atomically: true, encoding: .utf8)

        try runAdd(args: ["licenseChangelog", "--path", project, "--force", "--license", "mit"])

        #expect(try read("\(project)/LICENSE").contains("MIT License"))
    }

    @Test
    func `add localization keeps a translated catalog`() throws {
        let project = try makeScaffold(features: [.localization])
        defer { cleanup(project) }
        let catalogPath = "\(project)/Scaffold/Resources/Localizable.xcstrings"
        let translated = try read(catalogPath).replacingOccurrences(of: "\"sourceLanguage\"", with: "\"sourceLanguage\" ")
        try translated.write(toFile: catalogPath, atomically: true, encoding: .utf8)

        try runAdd(args: ["localization", "--path", project, "--locales", "en,zh-Hans,es"])

        #expect(try read(catalogPath) == translated)
    }

    @Test
    func `add localization does not add a second catalog`() throws {
        let project = try makeScaffold()
        defer { cleanup(project) }
        try "{}".write(toFile: "\(project)/Scaffold/Localizable.xcstrings", atomically: true, encoding: .utf8)

        try runAdd(args: ["localization", "--path", project])

        #expect(!FileManager.default.fileExists(atPath: "\(project)/Scaffold/Resources/Localizable.xcstrings"))
        #expect(FileManager.default.fileExists(atPath: "\(project)/Scaffold/Core/L10n.swift"))
    }

    // MARK: - Tier 2: Localization

    @Test
    func `add localization writes string catalog and L10n on xcodegen`() throws {
        let project = try makeScaffold()
        defer { cleanup(project) }

        try runAdd(args: ["localization", "--path", project, "--locales", "en,zh-Hans"])

        let catalog = try read("\(project)/Scaffold/Resources/Localizable.xcstrings")
        #expect(catalog.contains("\"zh-Hans\""))
        #expect(FileManager.default.fileExists(atPath: "\(project)/Scaffold/Core/L10n.swift"))
    }

    @Test
    func `add localization writes files on xcodeproj projects too`() throws {
        let project = try makeXcodeProjLikeScaffold()
        defer { cleanup(project) }

        try runAdd(args: ["localization", "--path", project])

        #expect(FileManager.default.fileExists(atPath: "\(project)/Scaffold/Resources/Localizable.xcstrings"))
        #expect(FileManager.default.fileExists(atPath: "\(project)/Scaffold/Core/L10n.swift"))
    }

    @Test
    func `add localization rejects malformed locales`() throws {
        let project = try makeScaffold()
        defer { cleanup(project) }

        for locales in ["", " , ", "english!", "en,en"] {
            #expect(throws: (any Error).self) {
                try runAdd(args: ["localization", "--path", project, "--locales", locales])
            }
        }
        #expect(try LocaleList.parse(" en , zh-Hans,pt-BR ") == ["en", "zh-Hans", "pt-BR"])
    }

    // MARK: - Tier 2: Mac Catalyst

    @Test
    func `add macCatalyst writes MacWindowConfig, Mac entitlements, and edits project.yml`() throws {
        let project = try makeScaffold()
        defer { cleanup(project) }

        try runAdd(args: ["macCatalyst", "--path", project])

        // A plain iPhone app has no AppConstants.MacWindow: the config carries its own size.
        let windowConfig = try read("\(project)/Scaffold/MacCatalyst/MacWindowConfig.swift")
        #expect(!windowConfig.contains("AppConstants"))
        #expect(windowConfig.contains("@MainActor"))

        let entitlements = try plist("\(project)/Scaffold/Scaffold-MacCatalyst.entitlements")
        #expect(entitlements["com.apple.security.app-sandbox"] as? Bool == true)
        #expect(entitlements["com.apple.security.network.client"] as? Bool == true)

        let yaml = try read("\(project)/project.yml")
        #expect(ProjectYamlEditor.targetSupportsMacCatalyst("Scaffold", in: yaml))
        #expect(yaml.contains("    macCatalyst: 18.0"))
        #expect(ProjectYamlEditor.setting("CODE_SIGN_ENTITLEMENTS[sdk=macosx*]", ofTarget: "Scaffold", in: yaml) == "Scaffold/Scaffold-MacCatalyst.entitlements")
    }

    @Test
    func `add macCatalyst copies the iOS entitlements into the Mac ones`() throws {
        let project = try makeScaffold(features: [.cloudKit])
        defer { cleanup(project) }

        try runAdd(args: ["macCatalyst", "--path", project])

        let mac = try plist("\(project)/Scaffold/Scaffold-MacCatalyst.entitlements")
        #expect(mac["com.apple.developer.icloud-services"] as? [String] == ["CloudKit"])
        #expect(mac["aps-environment"] as? String == "development")
        #expect(mac["com.apple.security.app-sandbox"] as? Bool == true)
    }

    /// A failed project.yml edit happens before any write, so the project is left as it was.
    @Test
    func `add fails without writing anything when project.yml cannot be edited`() throws {
        let project = try makeScaffold()
        defer { cleanup(project) }
        try "name: Scaffold\ntargets: {}\n".write(toFile: "\(project)/project.yml", atomically: true, encoding: .utf8)

        let error = #expect(throws: ProjectYamlEditError.self) {
            try runAdd(args: ["macCatalyst", "--path", project])
        }
        #expect(error?.description.contains("project.yml could not be updated") == true)
        #expect(!FileManager.default.fileExists(atPath: "\(project)/Scaffold/MacCatalyst/MacWindowConfig.swift"))
        #expect(!FileManager.default.fileExists(atPath: "\(project)/Scaffold/Scaffold-MacCatalyst.entitlements"))
        #expect(try read("\(project)/project.yml") == "name: Scaffold\ntargets: {}\n")
    }

    @Test
    func `add macCatalyst on a LumiKit app leaves the window setup to LMKScene`() throws {
        let project = try makeScaffold(features: [.lumiKit])
        defer { cleanup(project) }

        try runAdd(args: ["macCatalyst", "--path", project])

        #expect(!FileManager.default.fileExists(atPath: "\(project)/Scaffold/MacCatalyst/MacWindowConfig.swift"))
        let yaml = try read("\(project)/project.yml")
        #expect(yaml.contains("supportedDestinations: [iOS, macCatalyst]"), "the target still gains Mac Catalyst")
    }

    @Test
    func `add macCatalyst is idempotent`() throws {
        let project = try makeScaffold()
        defer { cleanup(project) }

        try runAdd(args: ["macCatalyst", "--path", project])
        let first = try read("\(project)/project.yml")
        try runAdd(args: ["macCatalyst", "--path", project])

        let yaml = try read("\(project)/project.yml")
        #expect(yaml == first)
        #expect(yaml.components(separatedBy: "supportedDestinations:").count - 1 == 1)
    }

    // MARK: - Tier 2: Lottie

    @Test
    func `add lottie writes helper and edits project.yml`() throws {
        let project = try makeScaffold()
        defer { cleanup(project) }

        try runAdd(args: ["lottie", "--path", project])

        #expect(FileManager.default.fileExists(atPath: "\(project)/Scaffold/Shared/Components/LottieHelper.swift"))

        let yaml = try read("\(project)/project.yml")
        #expect(topLevelParent(of: "  Lottie:", in: yaml) == "packages")
        #expect(topLevelParent(of: "      - package: Lottie", in: yaml) == "targets")
        #expect(yaml.contains("lottie-spm.git"))
    }

    @Test
    func `add lottie on a LumiKit app lands under packages, not schemes`() throws {
        let project = try makeScaffold(features: [.lumiKit])
        defer { cleanup(project) }

        try runAdd(args: ["lottie", "--path", project])

        let yaml = try read("\(project)/project.yml")
        #expect(topLevelParent(of: "  Lottie:", in: yaml) == "packages")
        #expect(topLevelParent(of: "  LumiKit:", in: yaml) == "packages")
        #expect(yaml.components(separatedBy: "\npackages:").count - 1 == 1)
    }

    @Test
    func `add snapKit and add lookin were removed in v0_4`() {
        // SnapKit and LookinServer left AddableFeature in v0.4. Existing
        // projects retrofit them via Xcode's native Add Package flow against
        // the URLs in KnownPackages.registry.
        #expect(!AddableFeature.allCases.contains(where: { $0.rawValue == "snapKit" }))
        #expect(!AddableFeature.allCases.contains(where: { $0.rawValue == "lookin" }))
    }

    @Test
    func `add lottie twice is idempotent`() throws {
        let project = try makeScaffold()
        defer { cleanup(project) }

        try runAdd(args: ["lottie", "--path", project])
        try runAdd(args: ["lottie", "--path", project])

        let yaml = try read("\(project)/project.yml")
        let packageOccurrences = yaml.components(separatedBy: "  Lottie:\n").count - 1
        let depOccurrences = yaml.components(separatedBy: "- package: Lottie").count - 1
        #expect(packageOccurrences == 1)
        #expect(depOccurrences == 1)
    }

    // MARK: - Tier 2: Widget

    @Test
    func `add widget writes extension files and edits project.yml`() throws {
        let project = try makeScaffold()
        defer { cleanup(project) }

        try runAdd(args: ["widget", "--path", project])

        for path in WidgetExtensionGenerator.files(appName: "Scaffold", appGroup: "group.x").map(\.path) {
            #expect(FileManager.default.fileExists(atPath: "\(project)/\(path)"), "\(path)")
        }

        let yaml = try read("\(project)/project.yml")
        #expect(topLevelParent(of: "  ScaffoldWidget:", in: yaml) == "targets")
        #expect(ProjectYamlEditor.setting("CODE_SIGN_ENTITLEMENTS", ofTarget: "Scaffold", in: yaml) == "Scaffold/Scaffold.entitlements")
        #expect(yaml.contains("WidgetKit.framework"))

        let widgetEntitlements = try plist("\(project)/ScaffoldWidget/ScaffoldWidget.entitlements")
        #expect(widgetEntitlements["com.apple.security.application-groups"] as? [String] == ["group.com.test.scaffold"])
        let appEntitlements = try plist("\(project)/Scaffold/Scaffold.entitlements")
        #expect(appEntitlements["com.apple.security.application-groups"] as? [String] == ["group.com.test.scaffold"])
    }

    @Test
    func `add widget merges the App Group into iCloud entitlements`() throws {
        let project = try makeScaffold(features: [.cloudKit])
        defer { cleanup(project) }

        try runAdd(args: ["widget", "--path", project])

        let entitlements = try plist("\(project)/Scaffold/Scaffold.entitlements")
        #expect(entitlements["com.apple.security.application-groups"] as? [String] == ["group.com.test.scaffold"])
        #expect(entitlements["com.apple.developer.icloud-container-identifiers"] as? [String] == ["iCloud.com.test.scaffold"])
        #expect(entitlements["com.apple.developer.icloud-services"] as? [String] == ["CloudKit"])
        #expect(entitlements["aps-environment"] as? String == "development")
    }

    @Test
    func `add widget refuses an entitlements path outside the project`() throws {
        let project = try makeScaffold()
        defer { cleanup(project) }
        let yamlPath = "\(project)/project.yml"
        let yaml = try read(yamlPath).replacingOccurrences(
            of: "        PRODUCT_BUNDLE_IDENTIFIER: com.test.scaffold\n",
            with: "        PRODUCT_BUNDLE_IDENTIFIER: com.test.scaffold\n        CODE_SIGN_ENTITLEMENTS: ../Shared/App.entitlements\n"
        )
        try yaml.write(toFile: yamlPath, atomically: true, encoding: .utf8)

        #expect(throws: EntitlementsMerger.MergeError.self) {
            try runAdd(args: ["widget", "--path", project])
        }
        #expect(!FileManager.default.fileExists(atPath: "\(project)/ScaffoldWidget"))
        #expect(try read(yamlPath) == yaml)
    }

    @Test
    func `add widget uses the app's bundle ID from project.yml`() throws {
        let project = try makeScaffold(bundleID: "com.acme.addw3")
        defer { cleanup(project) }

        try runAdd(args: ["widget", "--path", project])

        let yaml = try read("\(project)/project.yml")
        #expect(ProjectYamlEditor.bundleIdentifier(ofTarget: "ScaffoldWidget", in: yaml) == "com.acme.addw3.Widget")
        let appGroup = try read("\(project)/Scaffold/Shared/AppGroup.swift")
        #expect(appGroup.contains("\"group.com.acme.addw3\""))
    }

    @Test
    func `--bundle-id applies only when the project names no bundle ID`() throws {
        let project = try makeScaffold(bundleID: "com.acme.real")
        defer { cleanup(project) }

        try runAdd(args: ["widget", "--path", project, "--bundle-id", "com.other.app"])

        let yaml = try read("\(project)/project.yml")
        #expect(ProjectYamlEditor.bundleIdentifier(ofTarget: "ScaffoldWidget", in: yaml) == "com.acme.real.Widget")

        var state = ProjectState(root: project, type: .app, name: "Scaffold", projectSystem: .xcodeGen)
        #expect(AddFeatureHandlers.widgetBundleID(state: state, flag: "com.other.app") == "com.other.app")
        #expect(AddFeatureHandlers.widgetBundleID(state: state, flag: nil) == "com.example.scaffold")
        state.bundleID = "com.acme.real"
        #expect(AddFeatureHandlers.widgetBundleID(state: state, flag: "com.other.app") == "com.acme.real")
    }

    @Test
    func `add widget rejects an invalid --bundle-id`() throws {
        let project = try makeScaffold()
        defer { cleanup(project) }

        #expect(throws: (any Error).self) {
            try runAdd(args: ["widget", "--path", project, "--bundle-id", "not a bundle id"])
        }
        #expect(!FileManager.default.fileExists(atPath: "\(project)/ScaffoldWidget"))
    }

    @Test
    func `add widget on a Mac Catalyst app filters the widget to iOS`() throws {
        let project = try makeScaffold(platforms: [.iPhone, .iPad, .macCatalyst])
        defer { cleanup(project) }

        try runAdd(args: ["widget", "--path", project])

        let lines = try read("\(project)/project.yml").components(separatedBy: "\n")
        let dependency = try #require(lines.firstIndex(of: "      - target: ScaffoldWidget"))
        #expect(lines[dependency + 1] == "        destinationFilters: [iOS]")
    }

    @Test
    func `the widget plan lists the app entitlements and the widget privacy manifest`() throws {
        let project = try makeScaffold()
        defer { cleanup(project) }
        let state = try ProjectState.scan(at: project, detected: ProjectDetector.detect(at: project))

        let paths = try AddFeatureHandlers.plan(.widget, state: state, options: .init()).paths
        #expect(paths.contains("Scaffold/Scaffold.entitlements"))
        #expect(paths.contains("ScaffoldWidget/PrivacyInfo.xcprivacy"))
        #expect(Set(WidgetExtensionGenerator.files(appName: "Scaffold", appGroup: "g").map(\.path)).isSubset(of: Set(paths)))
    }

    // MARK: - Project detection

    @Test
    func `the app name comes from project.yml when the directory is named differently`() throws {
        let project = try makeScaffold()
        defer { cleanup(project) }
        let renamed = ((project as NSString).deletingLastPathComponent as NSString).appendingPathComponent("scaffold-repo")
        try FileManager.default.moveItem(atPath: project, toPath: renamed)

        try runAdd(args: ["lottie", "--path", renamed])

        #expect(FileManager.default.fileExists(atPath: "\(renamed)/Scaffold/Shared/Components/LottieHelper.swift"))
        #expect(!FileManager.default.fileExists(atPath: "\(renamed)/scaffold-repo"))
    }

    @Test
    func `the path is standardized before detection`() throws {
        let project = try makeScaffold()
        defer { cleanup(project) }

        try runAdd(args: ["privacyManifest", "--path", "\(project)/Scaffold/.."])

        #expect(FileManager.default.fileExists(atPath: "\(project)/Scaffold/Resources/PrivacyInfo.xcprivacy"))
    }

    // MARK: - Parity with `new`

    @Test
    func `add devTooling writes the Makefile new writes for the same app`() throws {
        let features: Set<AppFeature> = [.coreData, .cloudKit, .localization, .appIconValidation]
        let withTooling = try makeScaffold(features: features.union([.devTooling]))
        let without = try makeScaffold(features: features)
        defer {
            cleanup(withTooling)
            cleanup(without)
        }

        try runAdd(args: ["devTooling", "--path", without])

        #expect(try read("\(without)/Makefile") == read("\(withTooling)/Makefile"))
        #expect(try read("\(without)/.swiftlint.yml") == read("\(withTooling)/.swiftlint.yml"))
    }

    @Test
    func `add gitHooks includes the Core Data audit for a CloudKit model`() throws {
        let withHooks = try makeScaffold(features: [.coreData, .cloudKit, .gitHooks])
        let without = try makeScaffold(features: [.coreData, .cloudKit])
        defer {
            cleanup(withHooks)
            cleanup(without)
        }

        try runAdd(args: ["gitHooks", "--path", without])

        let hook = "Scripts/git-hooks/pre-commit"
        #expect(try read("\(without)/\(hook)") == read("\(withHooks)/\(hook)"))
        #expect(try read("\(without)/\(hook)").contains("Core Data model change"))
    }

    @Test
    func `add claudeMD describes the app new would describe`() throws {
        let withDoc = try makeScaffold(features: [.lumiKit, .swiftData, .claudeMD])
        let without = try makeScaffold(features: [.lumiKit, .swiftData])
        defer {
            cleanup(withDoc)
            cleanup(without)
        }

        try runAdd(args: ["claudeMD", "--path", without])

        #expect(try read("\(without)/.claude/CLAUDE.md") == read("\(withDoc)/.claude/CLAUDE.md"))
    }

    /// The SwiftLint `included` paths list the widget, and the Makefile has
    /// the Catalyst targets, as `new` writes them.
    @Test
    func `add devTooling matches new for a widget and Mac Catalyst app`() throws {
        let features: Set<AppFeature> = [.widget, .lumiKit]
        let platforms: Set<Platform> = [.iPhone, .iPad, .macCatalyst]
        let withTooling = try makeScaffold(features: features.union([.devTooling]), platforms: platforms)
        let without = try makeScaffold(features: features, platforms: platforms)
        defer {
            cleanup(withTooling)
            cleanup(without)
        }

        try runAdd(args: ["devTooling", "--path", without])

        let lint = try read("\(without)/.swiftlint.yml")
        #expect(lint.contains("  - ScaffoldWidget\n"))
        #expect(try read("\(without)/Makefile").contains("build-catalyst:"))
        for file in ["Makefile", ".swiftlint.yml", ".swiftformat", "Brewfile"] {
            #expect(try read("\(without)/\(file)") == read("\(withTooling)/\(file)"), "\(file)")
        }
    }

    @Test
    func `add privacyManifest declares what new declares`() throws {
        for features: Set<AppFeature> in [[], [.cloudKit], [.lumiKit]] {
            let withManifest = try makeScaffold(features: features.union([.privacyManifest]))
            let without = try makeScaffold(features: features)
            defer {
                cleanup(withManifest)
                cleanup(without)
            }

            try runAdd(args: ["privacyManifest", "--path", without])

            let manifest = "Scaffold/Resources/PrivacyInfo.xcprivacy"
            #expect(try read("\(without)/\(manifest)") == read("\(withManifest)/\(manifest)"), "\(features)")
        }
    }

    @Test
    func `add macCatalyst writes the Mac entitlements new writes`() throws {
        let withCatalyst = try makeScaffold(features: [.cloudKit, .widget], platforms: [.iPhone, .iPad, .macCatalyst])
        let without = try makeScaffold(features: [.cloudKit, .widget], platforms: [.iPhone, .iPad])
        defer {
            cleanup(withCatalyst)
            cleanup(without)
        }

        try runAdd(args: ["macCatalyst", "--path", without])

        let path = EntitlementsGenerator.macCatalystPath(appName: "Scaffold")
        let added = try plist("\(without)/\(path)")
        let generated = try plist("\(withCatalyst)/\(path)")
        #expect(NSDictionary(dictionary: added).isEqual(to: generated))
    }

    @Test
    func `add claudeMD describes the package and CLI new would describe`() throws {
        let raw = NSTemporaryDirectory() + "monolith-add-docs-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: raw) }
        for (directory, withDoc) in [("plain", false), ("doc", true)] {
            let output = "\(raw)/\(directory)"
            try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
            try PackageProjectGenerator.generate(config: PackageConfig(
                name: "MultiLib",
                platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
                targets: [TargetDefinition(name: "MultiLib", dependencies: [])],
                features: withDoc ? [.claudeMD] : [],
                mainActorTargets: [],
                author: "Test",
                licenseType: .mit
            ), outputDir: output)
            try CLIProjectGenerator.generate(
                config: CLIConfig(name: "multi-tool", features: withDoc ? [.argumentParser, .claudeMD] : [.argumentParser], author: "Test", licenseType: .apache2),
                outputDir: output
            )
        }

        try runAdd(args: ["claudeMD", "--path", "\(raw)/plain/MultiLib"])
        try runAdd(args: ["claudeMD", "--path", "\(raw)/plain/multi-tool"])

        let packageDoc = try read("\(raw)/plain/MultiLib/.claude/CLAUDE.md")
        #expect(packageDoc.contains("## Logging"))
        #expect(try packageDoc == read("\(raw)/doc/MultiLib/.claude/CLAUDE.md"))
        let cliDoc = try read("\(raw)/plain/multi-tool/.claude/CLAUDE.md")
        #expect(cliDoc.contains("## Layout"))
        #expect(try cliDoc == read("\(raw)/doc/multi-tool/.claude/CLAUDE.md"))
    }

    @Test
    func `a package with an executable target gets package docs and an MIT license`() throws {
        let raw = NSTemporaryDirectory() + "monolith-add-pkg-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: raw) }
        try FileManager.default.createDirectory(atPath: raw, withIntermediateDirectories: true)
        try PackageProjectGenerator.generate(config: PackageConfig(
            name: "MultiLib",
            platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
            targets: [
                TargetDefinition(name: "MultiLibCore", dependencies: []),
                TargetDefinition(name: "multilib-tool", dependencies: ["MultiLibCore"], isExecutable: true),
            ],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        ), outputDir: raw)
        let root = "\(raw)/MultiLib"

        try runAdd(args: ["claudeMD", "--path", root])
        try runAdd(args: ["licenseChangelog", "--path", root])

        let doc = try read("\(root)/.claude/CLAUDE.md")
        #expect(doc.contains("Swift Package with targets: MultiLibCore, multilib-tool"))
        #expect(doc.contains("## Executables"))
        #expect(try read("\(root)/LICENSE").contains("MIT License"))
    }

    // MARK: - Validation

    @Test
    func `Tier 2 feature on package project throws`() throws {
        // Build a minimal package scaffold.
        let raw = NSTemporaryDirectory() + "monolith-add-pkg-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: raw) }
        try FileManager.default.createDirectory(atPath: raw, withIntermediateDirectories: true)
        let config = PackageConfig(
            name: "Pkg",
            platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
            targets: [TargetDefinition(name: "Pkg", dependencies: [])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        try PackageProjectGenerator.generate(config: config, outputDir: raw)

        let projectRoot = "\(raw)/Pkg"
        #expect(throws: (any Error).self) {
            try runAdd(args: ["widget", "--path", projectRoot])
        }
    }

    // MARK: - xcodegen accepts the edited project.yml

    @Test(.enabled(if: xcodegenAvailable))
    func `xcodegen accepts project.yml after add widget on a LumiKit CloudKit Mac Catalyst app`() throws {
        let project = try makeScaffold(features: [.lumiKit, .cloudKit], platforms: [.iPhone, .iPad, .macCatalyst])
        defer { cleanup(project) }

        try runAdd(args: ["widget", "--path", project])

        #expect(XcodeGenRunner.generate(at: project))
        let entitlements = try plist("\(project)/Scaffold/Scaffold.entitlements")
        #expect(entitlements["com.apple.developer.icloud-services"] as? [String] == ["CloudKit"])
        #expect(entitlements["com.apple.security.application-groups"] as? [String] == ["group.com.test.scaffold"])
    }

    @Test(.enabled(if: xcodegenAvailable))
    func `xcodegen accepts project.yml after add lottie and add macCatalyst`() throws {
        for features: Set<AppFeature> in [[], [.lumiKit]] {
            let project = try makeScaffold(features: features)
            defer { cleanup(project) }

            try runAdd(args: ["lottie", "--path", project])
            try runAdd(args: ["macCatalyst", "--path", project])
            try runAdd(args: ["widget", "--path", project])

            #expect(XcodeGenRunner.generate(at: project), "features: \(features)")
        }
    }

    @Test(.enabled(if: xcodegenAvailable))
    func `an xcodeproj app's bundle ID is read from project.pbxproj`() throws {
        let project = try makeScaffold(projectSystem: .xcodeProj, bundleID: "com.acme.pbx")
        defer { cleanup(project) }

        try runAdd(args: ["widget", "--path", project])

        let appGroup = try read("\(project)/Scaffold/Shared/AppGroup.swift")
        #expect(appGroup.contains("\"group.com.acme.pbx\""))
    }
}
