import Foundation
import Testing
@testable import MonolithLib

/// Tests for `ProjectYamlEditor`'s text-based YAML surgery. Each editor is
/// idempotent — applying twice should produce the same file as applying once.
///
/// Fixtures come from `XcodeGenGenerator.generate`, so they end with the
/// `schemes:` block a real project.yml has. Assertions are structural: an
/// inserted line must sit under the right column-0 parent and target, not
/// merely appear somewhere in the file.
struct ProjectYamlEditorTests {
    // MARK: - Fixtures

    private static func generatedYaml(
        features: Set<AppFeature> = [],
        platforms: Set<Platform> = [.iPhone, .iPad]
    ) -> String {
        XcodeGenGenerator.generate(config: AppConfig(
            name: "MyApp",
            bundleID: "com.example.myapp",
            deploymentTarget: "18.0",
            platforms: platforms,
            projectSystem: .xcodeGen,
            tabs: [],
            primaryColor: "#007AFF",
            features: features,
            author: "Test",
            licenseType: .proprietary
        ))
    }

    /// A plain app: no `packages:` block.
    private static let plainYaml = generatedYaml()
    /// A LumiKit app: `packages:` followed by `schemes:`.
    private static let lumiKitYaml = generatedYaml(features: [.lumiKit])

    /// The keys enclosing the first line equal to `line` (after trimming
    /// trailing spaces), outermost first: `["targets", "MyApp", "dependencies"]`
    /// for a dependency item of the app target.
    private func parents(of line: String, in yaml: String) -> [String]? {
        let lines = yaml.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        guard let index = lines.firstIndex(where: { $0.trimmingTrailingSpaces == line }) else { return nil }
        var parents: [String] = []
        var indent = lines[index].leadingSpaces
        for candidate in lines[..<index].reversed() {
            let trimmed = candidate.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), candidate.leadingSpaces < indent else { continue }
            guard !trimmed.hasPrefix("-"), let colon = trimmed.firstIndex(of: ":") else { continue }
            parents.insert(String(trimmed[..<colon]), at: 0)
            indent = candidate.leadingSpaces
            if indent == 0 { break }
        }
        return parents
    }

    private func count(_ needle: String, in yaml: String) -> Int {
        yaml.components(separatedBy: needle).count - 1
    }

    // MARK: - topLevelBlockRange

    @Test
    func `topLevelBlockRange spans a block up to the next column-0 key`() throws {
        let yaml = Self.lumiKitYaml
        let packages = try #require(ProjectYamlEditor.topLevelBlockRange("packages", in: yaml))
        let block = String(yaml[packages])
        #expect(block.hasPrefix("packages:\n"))
        #expect(block.contains("  LumiKit:"))
        #expect(!block.contains("schemes:"))
        #expect(ProjectYamlEditor.topLevelBlockRange("packages", in: Self.plainYaml) == nil)
    }

    @Test
    func `topLevelBlockRange accepts a trailing comment and spaces after the key`() throws {
        let yaml = "name: X\npackages:   # deps\n  A:\n    url: u\nschemes:\n  X: {}\n"
        let range = try #require(ProjectYamlEditor.topLevelBlockRange("packages", in: yaml))
        #expect(String(yaml[range]) == "packages:   # deps\n  A:\n    url: u\n")
    }

    // MARK: - addPackage

    @Test
    func `addPackage creates the packages block before schemes when absent`() throws {
        var yaml = Self.plainYaml
        let result = ProjectYamlEditor.addPackage(
            yaml: &yaml,
            name: "SnapKit",
            url: "https://github.com/SnapKit/SnapKit.git",
            from: "6.0.0"
        )

        #expect(result == .applied)
        #expect(parents(of: "  SnapKit:", in: yaml) == ["packages"])
        #expect(parents(of: "    url: https://github.com/SnapKit/SnapKit.git", in: yaml) == ["packages", "SnapKit"])
        let packages = try #require(yaml.range(of: "\npackages:\n")?.lowerBound)
        let schemes = try #require(yaml.range(of: "\nschemes:\n")?.lowerBound)
        #expect(packages < schemes)
    }

    @Test
    func `addPackage appends to an existing packages block that precedes schemes`() {
        var yaml = Self.lumiKitYaml
        let result = ProjectYamlEditor.addPackage(
            yaml: &yaml,
            name: "Lottie",
            url: "https://github.com/airbnb/lottie-spm.git",
            from: "4.6.1"
        )

        #expect(result == .applied)
        #expect(parents(of: "  LumiKit:", in: yaml) == ["packages"])
        #expect(parents(of: "  Lottie:", in: yaml) == ["packages"], "not under schemes:")
        #expect(parents(of: "    from: 4.6.1", in: yaml) == ["packages", "Lottie"])
        #expect(count("packages:", in: yaml) == 1)
    }

    @Test
    func `addPackage is idempotent`() {
        var yaml = Self.plainYaml
        _ = ProjectYamlEditor.addPackage(yaml: &yaml, name: "SnapKit", url: "x", from: "5")
        let snapshot = yaml

        let result = ProjectYamlEditor.addPackage(yaml: &yaml, name: "SnapKit", url: "x", from: "5")
        #expect(result == .alreadyPresent)
        #expect(yaml == snapshot)
    }

    @Test
    func `addPackage does not mistake a target of the same name for a package`() {
        var yaml = Self.plainYaml
        let result = ProjectYamlEditor.addPackage(yaml: &yaml, name: "MyApp", url: "x", from: "1")
        #expect(result == .applied)
        #expect(parents(of: "  MyApp:", in: yaml) == ["targets"])
    }

    @Test
    func `addPackage finds a packages header with a trailing comment`() {
        var yaml = Self.lumiKitYaml.replacingOccurrences(of: "packages:\n", with: "packages:  # SPM deps\n")
        let result = ProjectYamlEditor.addPackage(yaml: &yaml, name: "Lottie", url: "x", from: "1")
        #expect(result == .applied)
        #expect(count("packages:", in: yaml) == 1)
        #expect(parents(of: "  Lottie:", in: yaml) == ["packages"])
    }

    @Test
    func `addPackage keeps CRLF line endings`() {
        var yaml = Self.lumiKitYaml.replacingOccurrences(of: "\n", with: "\r\n")
        let result = ProjectYamlEditor.addPackage(yaml: &yaml, name: "Lottie", url: "x", from: "1")
        #expect(result == .applied)
        #expect(count("packages:", in: yaml) == 1)
        #expect(!yaml.replacingOccurrences(of: "\r\n", with: "").contains("\n"), "every line ends in CRLF")
        #expect(parents(of: "  Lottie:", in: yaml) == ["packages"])
    }

    // MARK: - addTargetDependency

    @Test
    func `addTargetDependency creates dependencies block when absent`() {
        var yaml = Self.plainYaml
        let result = ProjectYamlEditor.addTargetDependency(
            yaml: &yaml,
            targetName: "MyApp",
            packageName: "SnapKit"
        )

        #expect(result == .applied)
        #expect(parents(of: "      - package: SnapKit", in: yaml) == ["targets", "MyApp", "dependencies"])
    }

    @Test
    func `addTargetDependency inserts under existing dependencies block`() {
        var yaml = Self.lumiKitYaml
        let result = ProjectYamlEditor.addTargetDependency(yaml: &yaml, targetName: "MyApp", packageName: "Lottie")

        #expect(result == .applied)
        #expect(parents(of: "      - package: Lottie", in: yaml) == ["targets", "MyApp", "dependencies"])
        #expect(parents(of: "      - package: LumiKit", in: yaml) == ["targets", "MyApp", "dependencies"])
        let appBlock = yaml.components(separatedBy: "\n  MyAppTests:\n")[0]
        #expect(count("    dependencies:", in: appBlock) == 1)
    }

    @Test
    func `addTargetDependency is idempotent`() {
        var yaml = Self.plainYaml
        _ = ProjectYamlEditor.addTargetDependency(yaml: &yaml, targetName: "MyApp", packageName: "SnapKit")
        let snapshot = yaml

        let result = ProjectYamlEditor.addTargetDependency(yaml: &yaml, targetName: "MyApp", packageName: "SnapKit")
        #expect(result == .alreadyPresent)
        #expect(yaml == snapshot)
    }

    @Test
    func `addTargetDependency recognizes an entry at the end of the file`() {
        // No trailing newline after the existing entry: the idempotency check
        // must not depend on a following "\n".
        var yaml = "targets:\n  MyApp:\n    platform: iOS\n    dependencies:\n      - package: SnapKit"
        let result = ProjectYamlEditor.addTargetDependency(yaml: &yaml, targetName: "MyApp", packageName: "SnapKit")
        #expect(result == .alreadyPresent)
    }

    @Test
    func `addTargetDependency with platforms emits a platforms line`() {
        var yaml = Self.plainYaml
        let result = ProjectYamlEditor.addTargetDependency(
            yaml: &yaml,
            targetName: "MyApp",
            packageName: "LookinServer",
            platforms: ["iOS"]
        )

        #expect(result == .applied)
        #expect(parents(of: "        platforms: [iOS]", in: yaml) == ["targets", "MyApp", "dependencies"])
    }

    @Test
    func `addTargetDependency fails for unknown target`() {
        var yaml = Self.plainYaml
        let result = ProjectYamlEditor.addTargetDependency(
            yaml: &yaml,
            targetName: "DoesNotExist",
            packageName: "SnapKit"
        )

        if case let .failed(reason) = result {
            #expect(reason.contains("DoesNotExist"))
        } else {
            Issue.record("expected .failed, got \(result)")
        }
        #expect(yaml == Self.plainYaml)
    }

    @Test
    func `a comment line inside a target does not end its block`() {
        var yaml = Self.plainYaml.replacingOccurrences(
            of: "    sources:\n      - MyApp\n",
            with: "    sources:\n      - MyApp\n  # app settings follow\n"
        )
        let result = ProjectYamlEditor.addTargetDependency(yaml: &yaml, targetName: "MyApp", packageName: "SnapKit")
        #expect(result == .applied)
        #expect(parents(of: "      - package: SnapKit", in: yaml) == ["targets", "MyApp", "dependencies"])
        let appBlock = yaml.components(separatedBy: "\n  MyAppTests:\n")[0]
        #expect(appBlock.contains("- package: SnapKit"), "added to the app target, after its settings")
    }

    // MARK: - addPackageDependency (combined)

    @Test
    func `addPackageDependency adds both package and target dependency`() {
        var yaml = Self.lumiKitYaml
        let result = ProjectYamlEditor.addPackageDependency(
            yaml: &yaml,
            targetName: "MyApp",
            packageName: "Lottie",
            url: "https://github.com/airbnb/lottie-spm.git",
            from: "4.6.1"
        )

        #expect(result == .applied)
        #expect(parents(of: "  Lottie:", in: yaml) == ["packages"])
        #expect(parents(of: "      - package: Lottie", in: yaml) == ["targets", "MyApp", "dependencies"])
    }

    @Test
    func `addPackageDependency is idempotent`() {
        var yaml = Self.plainYaml
        _ = ProjectYamlEditor.addPackageDependency(
            yaml: &yaml,
            targetName: "MyApp",
            packageName: "SnapKit",
            url: "x",
            from: "5"
        )
        let snapshot = yaml

        let result = ProjectYamlEditor.addPackageDependency(
            yaml: &yaml,
            targetName: "MyApp",
            packageName: "SnapKit",
            url: "x",
            from: "5"
        )
        #expect(result == .alreadyPresent)
        #expect(yaml == snapshot)
    }

    @Test
    func `addPackageDependency leaves the file untouched when the target is missing`() {
        var yaml = Self.plainYaml
        let result = ProjectYamlEditor.addPackageDependency(yaml: &yaml, targetName: "Nope", packageName: "SnapKit", url: "x", from: "5")
        #expect(result != .applied)
        #expect(yaml == Self.plainYaml)
    }

    // MARK: - enableMacCatalyst

    @Test
    func `enableMacCatalyst adds deployment target, destinations, and Mac entitlements`() {
        var yaml = Self.plainYaml
        let result = ProjectYamlEditor.enableMacCatalyst(
            yaml: &yaml,
            targetName: "MyApp",
            catalystEntitlements: "MyApp/MyApp-MacCatalyst.entitlements"
        )

        #expect(result == .applied)
        #expect(parents(of: "    macCatalyst: 18.0", in: yaml) == ["options", "deploymentTarget"])
        #expect(parents(of: "    supportedDestinations: [iOS, macCatalyst]", in: yaml) == ["targets", "MyApp"])
        #expect(
            parents(of: "        \"CODE_SIGN_ENTITLEMENTS[sdk=macosx*]\": MyApp/MyApp-MacCatalyst.entitlements", in: yaml)
                == ["targets", "MyApp", "settings", "base"]
        )
        #expect(count("INFOPLIST_KEY_LSApplicationCategoryType", in: yaml) == 1, "the generated target already has a category")
    }

    @Test
    func `enableMacCatalyst adds an App Category when the target has none`() {
        var yaml = Self.plainYaml.replacingOccurrences(of: "        INFOPLIST_KEY_LSApplicationCategoryType: public.app-category.utilities\n", with: "")
        _ = ProjectYamlEditor.enableMacCatalyst(yaml: &yaml, targetName: "MyApp")
        #expect(
            parents(of: "        INFOPLIST_KEY_LSApplicationCategoryType: public.app-category.utilities", in: yaml)
                == ["targets", "MyApp", "settings", "base"]
        )
    }

    @Test
    func `enableMacCatalyst adds iPad to an iPhone-only device family`() {
        var yaml = Self.generatedYaml(platforms: [.iPhone])
        let result = ProjectYamlEditor.enableMacCatalyst(yaml: &yaml, targetName: "MyApp")

        #expect(result == .applied)
        #expect(ProjectYamlEditor.setting("TARGETED_DEVICE_FAMILY", ofTarget: "MyApp", in: yaml) == "1,2")
        #expect(parents(of: "        TARGETED_DEVICE_FAMILY: \"1,2\"", in: yaml) == ["targets", "MyApp", "settings", "base"])
    }

    @Test
    func `enableMacCatalyst is idempotent`() {
        var yaml = Self.plainYaml
        _ = ProjectYamlEditor.enableMacCatalyst(yaml: &yaml, targetName: "MyApp", catalystEntitlements: "MyApp/MyApp-MacCatalyst.entitlements")
        let snapshot = yaml

        let result = ProjectYamlEditor.enableMacCatalyst(yaml: &yaml, targetName: "MyApp", catalystEntitlements: "MyApp/MyApp-MacCatalyst.entitlements")
        #expect(result == .alreadyPresent)
        #expect(yaml == snapshot)
    }

    @Test
    func `enableMacCatalyst keeps the deployment-target edit when destinations already exist`() {
        // `supportedDestinations: [iOS]` without a macCatalyst deployment
        // target: both steps must land, and the result must be `.applied`.
        var yaml = Self.plainYaml.replacingOccurrences(
            of: "    platform: iOS\n    sources:\n      - MyApp\n",
            with: "    platform: iOS\n    supportedDestinations: [iOS]\n    sources:\n      - MyApp\n"
        )
        let result = ProjectYamlEditor.enableMacCatalyst(yaml: &yaml, targetName: "MyApp")

        #expect(result == .applied)
        #expect(parents(of: "    macCatalyst: 18.0", in: yaml) == ["options", "deploymentTarget"])
        #expect(parents(of: "    supportedDestinations: [iOS, macCatalyst]", in: yaml) == ["targets", "MyApp"])
        #expect(count("supportedDestinations:", in: yaml) == 1)
    }

    @Test
    func `enableMacCatalyst ignores another target's destinations`() {
        // A test target listing macCatalyst must not make the app target look enabled.
        var yaml = Self.plainYaml.replacingOccurrences(
            of: "    type: bundle.unit-test\n    platform: iOS\n",
            with: "    type: bundle.unit-test\n    platform: iOS\n    supportedDestinations: [iOS, macCatalyst]\n"
        )
        let result = ProjectYamlEditor.enableMacCatalyst(yaml: &yaml, targetName: "MyApp")
        #expect(result == .applied)
        #expect(ProjectYamlEditor.targetSupportsMacCatalyst("MyApp", in: yaml))
        #expect(count("supportedDestinations: [iOS, macCatalyst]", in: yaml) == 2)
    }

    @Test
    func `enableMacCatalyst filters an embedded widget to iOS`() {
        var yaml = Self.generatedYaml(features: [.widget])
        let result = ProjectYamlEditor.enableMacCatalyst(yaml: &yaml, targetName: "MyApp")

        #expect(result == .applied)
        #expect(parents(of: "        destinationFilters: [iOS]", in: yaml) == ["targets", "MyApp", "dependencies"])
        let lines = yaml.components(separatedBy: "\n")
        let widgetDep = lines.firstIndex(of: "      - target: MyAppWidget")
        #expect(widgetDep.map { lines[$0 + 1] } == "        destinationFilters: [iOS]")
    }

    @Test
    func `enableMacCatalyst fails for missing target`() {
        var yaml = Self.plainYaml
        let result = ProjectYamlEditor.enableMacCatalyst(yaml: &yaml, targetName: "Nope")

        if case let .failed(reason) = result {
            #expect(reason.contains("Nope") || reason.contains("not found"))
        } else {
            Issue.record("expected .failed, got \(result)")
        }
        #expect(yaml == Self.plainYaml)
    }

    // MARK: - addWidgetTarget

    @Test
    func `addWidgetTarget appends a new widget extension target`() {
        var yaml = Self.plainYaml
        let result = ProjectYamlEditor.addWidgetTarget(
            yaml: &yaml,
            appName: "MyApp",
            bundleID: "com.example.myapp"
        )

        #expect(result == .applied)
        #expect(parents(of: "  MyAppWidget:", in: yaml) == ["targets"], "not under schemes:")
        #expect(parents(of: "    type: app-extension", in: yaml) == ["targets", "MyAppWidget"])
        #expect(parents(of: "        PRODUCT_BUNDLE_IDENTIFIER: com.example.myapp.Widget", in: yaml) == ["targets", "MyAppWidget", "settings", "base"])
        #expect(parents(of: "      - sdk: WidgetKit.framework", in: yaml) == ["targets", "MyAppWidget", "dependencies"])
    }

    @Test
    func `addWidgetTarget stays inside targets when packages follow`() {
        var yaml = Self.lumiKitYaml
        let result = ProjectYamlEditor.addWidgetTarget(yaml: &yaml, appName: "MyApp", bundleID: "com.example.myapp")

        #expect(result == .applied)
        #expect(parents(of: "  MyAppWidget:", in: yaml) == ["targets"])
        #expect(parents(of: "  LumiKit:", in: yaml) == ["packages"])
    }

    @Test
    func `addWidgetTarget is idempotent`() {
        var yaml = Self.plainYaml
        _ = ProjectYamlEditor.addWidgetTarget(yaml: &yaml, appName: "MyApp", bundleID: "com.example.myapp")
        let snapshot = yaml

        let result = ProjectYamlEditor.addWidgetTarget(yaml: &yaml, appName: "MyApp", bundleID: "com.example.myapp")
        #expect(result == .alreadyPresent)
        #expect(yaml == snapshot)
    }

    // MARK: - wireAppForWidget

    @Test
    func `wireAppForWidget injects entitlements and widget dependency`() {
        var yaml = Self.plainYaml
        let result = ProjectYamlEditor.wireAppForWidget(yaml: &yaml, appName: "MyApp")

        #expect(result == .applied)
        #expect(parents(of: "        CODE_SIGN_ENTITLEMENTS: MyApp/MyApp.entitlements", in: yaml) == ["targets", "MyApp", "settings", "base"])
        #expect(parents(of: "      - target: MyAppWidget", in: yaml) == ["targets", "MyApp", "dependencies"])
        #expect(!yaml.contains("destinationFilters"), "an iOS-only app embeds the widget everywhere")
    }

    @Test
    func `wireAppForWidget keeps an existing entitlements path`() {
        var yaml = Self.generatedYaml(features: [.cloudKit])
        _ = ProjectYamlEditor.wireAppForWidget(yaml: &yaml, appName: "MyApp", entitlementsPath: "Other/Path.entitlements")
        #expect(count("CODE_SIGN_ENTITLEMENTS:", in: yaml) == 1)
        #expect(ProjectYamlEditor.setting("CODE_SIGN_ENTITLEMENTS", ofTarget: "MyApp", in: yaml) == "MyApp/MyApp.entitlements")
    }

    @Test
    func `wireAppForWidget filters the widget to iOS on a Mac Catalyst app`() {
        var yaml = Self.generatedYaml(platforms: [.iPhone, .iPad, .macCatalyst])
        let result = ProjectYamlEditor.wireAppForWidget(yaml: &yaml, appName: "MyApp")

        #expect(result == .applied)
        let lines = yaml.components(separatedBy: "\n")
        let widgetDep = lines.firstIndex(of: "      - target: MyAppWidget")
        #expect(widgetDep.map { lines[$0 + 1] } == "        destinationFilters: [iOS]")
    }

    @Test
    func `wireAppForWidget is idempotent`() {
        for platforms: Set<Platform> in [[.iPhone], [.iPhone, .macCatalyst]] {
            var yaml = Self.generatedYaml(platforms: platforms)
            _ = ProjectYamlEditor.wireAppForWidget(yaml: &yaml, appName: "MyApp")
            let snapshot = yaml

            let result = ProjectYamlEditor.wireAppForWidget(yaml: &yaml, appName: "MyApp")
            #expect(result == .alreadyPresent)
            #expect(yaml == snapshot)
        }
    }

    @Test
    func `wireAppForWidget fails when target is missing`() {
        var yaml = Self.plainYaml
        let result = ProjectYamlEditor.wireAppForWidget(yaml: &yaml, appName: "Nope")

        if case let .failed(reason) = result {
            #expect(reason.contains("Nope") || reason.contains("not found"))
        } else {
            Issue.record("expected .failed, got \(result)")
        }
    }

    // MARK: - Reading

    @Test
    func `reads the app target's bundle ID and settings`() {
        let yaml = Self.generatedYaml(features: [.widget])
        #expect(ProjectYamlEditor.bundleIdentifier(ofTarget: "MyApp", in: yaml) == "com.example.myapp")
        #expect(ProjectYamlEditor.bundleIdentifier(ofTarget: "MyAppWidget", in: yaml) == "com.example.myapp.Widget")
        #expect(ProjectYamlEditor.setting("TARGETED_DEVICE_FAMILY", ofTarget: "MyApp", in: yaml) == "1,2")
        #expect(ProjectYamlEditor.hasTarget("MyAppWidget", in: yaml))
        #expect(!ProjectYamlEditor.hasTarget("MyAppWidget", in: Self.plainYaml))
    }

    // MARK: - End-to-end widget flow

    @Test
    func `widget end to end emits both target and app wiring`() {
        var yaml = Self.plainYaml
        let widgetResult = ProjectYamlEditor.addWidgetTarget(
            yaml: &yaml,
            appName: "MyApp",
            bundleID: "com.example.myapp"
        )
        let wireResult = ProjectYamlEditor.wireAppForWidget(yaml: &yaml, appName: "MyApp")

        #expect(widgetResult == .applied)
        #expect(wireResult == .applied)
        #expect(parents(of: "  MyAppWidget:", in: yaml) == ["targets"])
        #expect(parents(of: "        CODE_SIGN_ENTITLEMENTS: MyApp/MyApp.entitlements", in: yaml) == ["targets", "MyApp", "settings", "base"])
        #expect(parents(of: "      - target: MyAppWidget", in: yaml) == ["targets", "MyApp", "dependencies"])

        // Re-running both should be idempotent.
        let widgetAgain = ProjectYamlEditor.addWidgetTarget(yaml: &yaml, appName: "MyApp", bundleID: "com.example.myapp")
        let wireAgain = ProjectYamlEditor.wireAppForWidget(yaml: &yaml, appName: "MyApp")
        #expect(widgetAgain == .alreadyPresent)
        #expect(wireAgain == .alreadyPresent)
    }
}

private extension String {
    var leadingSpaces: Int {
        prefix { $0 == " " }.count
    }

    var trimmingTrailingSpaces: String {
        var copy = self
        while copy.last == " " || copy.last == "\r" {
            copy.removeLast()
        }
        return copy
    }
}
