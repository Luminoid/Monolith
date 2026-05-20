import Foundation
import Testing
@testable import MonolithLib

/// Tests for `ProjectYamlEditor`'s text-based YAML surgery. Each editor is
/// idempotent — applying twice should produce the same file as applying once.
///
/// Fixtures mirror the shape `XcodeGenGenerator` actually emits, so that drift
/// in the generator (which the editor consumes) is caught by these tests
/// rather than at runtime against a real user's project.
struct ProjectYamlEditorTests {
    // MARK: - Fixtures

    /// Minimal but realistic project.yml — matches the structure
    /// `XcodeGenGenerator.generate` produces for a no-feature app named "MyApp".
    private static let baselineYaml = """
    name: MyApp

    options:
      bundleIdPrefix: com.example
      deploymentTarget:
        iOS: 18.0
      xcodeVersion: "16.0"
      generateEmptyDirectories: true

    settings:
      base:
        SWIFT_VERSION: "6.2"
        MARKETING_VERSION: "1.0.0"

    targets:
      MyApp:
        type: application
        platform: iOS
        sources:
          - MyApp
        settings:
          base:
            PRODUCT_BUNDLE_IDENTIFIER: com.example.myapp
            GENERATE_INFOPLIST_FILE: YES

      MyAppTests:
        type: bundle.unit-test
        platform: iOS
        sources:
          - MyAppTests
        dependencies:
          - target: MyApp

    """

    // MARK: - addPackage

    @Test
    func `addPackage creates packages block when absent`() {
        var yaml = Self.baselineYaml
        let result = ProjectYamlEditor.addPackage(
            yaml: &yaml,
            name: "SnapKit",
            url: "https://github.com/SnapKit/SnapKit.git",
            from: "5.7.0"
        )

        #expect(result == .applied)
        #expect(yaml.contains("packages:\n"))
        #expect(yaml.contains("  SnapKit:\n"))
        #expect(yaml.contains("    url: https://github.com/SnapKit/SnapKit.git"))
        #expect(yaml.contains("    from: 5.7.0"))
    }

    @Test
    func `addPackage appends to existing packages block`() {
        var yaml = Self.baselineYaml + """
        packages:
          Lottie:
            url: https://github.com/airbnb/lottie-spm.git
            from: 4.5.0

        """

        let result = ProjectYamlEditor.addPackage(
            yaml: &yaml,
            name: "SnapKit",
            url: "https://github.com/SnapKit/SnapKit.git",
            from: "5.7.0"
        )

        #expect(result == .applied)
        // Both packages should be present.
        #expect(yaml.contains("  Lottie:"))
        #expect(yaml.contains("  SnapKit:"))
        // Only ONE packages: line — not duplicated.
        #expect(yaml.components(separatedBy: "packages:\n").count == 2)
    }

    @Test
    func `addPackage is idempotent`() {
        var yaml = Self.baselineYaml
        _ = ProjectYamlEditor.addPackage(yaml: &yaml, name: "SnapKit", url: "x", from: "5")
        let snapshot = yaml

        let result = ProjectYamlEditor.addPackage(yaml: &yaml, name: "SnapKit", url: "x", from: "5")
        #expect(result == .alreadyPresent)
        #expect(yaml == snapshot)
    }

    // MARK: - addTargetDependency

    @Test
    func `addTargetDependency creates dependencies block when absent`() throws {
        var yaml = Self.baselineYaml
        let result = ProjectYamlEditor.addTargetDependency(
            yaml: &yaml,
            targetName: "MyApp",
            packageName: "SnapKit"
        )

        #expect(result == .applied)
        // Should appear in MyApp's block, not MyAppTests's.
        let myAppRange = try #require(yaml.range(of: "  MyApp:\n"))
        let myAppTestsRange = try #require(yaml.range(of: "  MyAppTests:\n"))
        let myAppBlock = String(yaml[myAppRange.lowerBound ..< myAppTestsRange.lowerBound])
        #expect(myAppBlock.contains("- package: SnapKit"))
    }

    @Test
    func `addTargetDependency inserts under existing dependencies block`() throws {
        var yaml = Self.baselineYaml
        _ = ProjectYamlEditor.addTargetDependency(yaml: &yaml, targetName: "MyApp", packageName: "Lottie")
        let result = ProjectYamlEditor.addTargetDependency(yaml: &yaml, targetName: "MyApp", packageName: "SnapKit")

        #expect(result == .applied)
        #expect(yaml.contains("- package: Lottie"))
        #expect(yaml.contains("- package: SnapKit"))
        // Only one dependencies: line in the MyApp block.
        let myAppRange = try #require(yaml.range(of: "  MyApp:\n"))
        let myAppTestsRange = try #require(yaml.range(of: "  MyAppTests:\n"))
        let myAppBlock = String(yaml[myAppRange.lowerBound ..< myAppTestsRange.lowerBound])
        #expect(myAppBlock.components(separatedBy: "dependencies:\n").count == 2)
    }

    @Test
    func `addTargetDependency is idempotent`() {
        var yaml = Self.baselineYaml
        _ = ProjectYamlEditor.addTargetDependency(yaml: &yaml, targetName: "MyApp", packageName: "SnapKit")
        let snapshot = yaml

        let result = ProjectYamlEditor.addTargetDependency(yaml: &yaml, targetName: "MyApp", packageName: "SnapKit")
        #expect(result == .alreadyPresent)
        #expect(yaml == snapshot)
    }

    @Test
    func `addTargetDependency with platforms emits a platforms line`() {
        var yaml = Self.baselineYaml
        let result = ProjectYamlEditor.addTargetDependency(
            yaml: &yaml,
            targetName: "MyApp",
            packageName: "LookinServer",
            platforms: ["iOS"]
        )

        #expect(result == .applied)
        #expect(yaml.contains("- package: LookinServer"))
        #expect(yaml.contains("        platforms: [iOS]"))
    }

    @Test
    func `addTargetDependency fails for unknown target`() {
        var yaml = Self.baselineYaml
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
    }

    // MARK: - addPackageDependency (combined)

    @Test
    func `addPackageDependency adds both package and target dependency`() {
        var yaml = Self.baselineYaml
        let result = ProjectYamlEditor.addPackageDependency(
            yaml: &yaml,
            targetName: "MyApp",
            packageName: "SnapKit",
            url: "https://github.com/SnapKit/SnapKit.git",
            from: "5.7.0"
        )

        #expect(result == .applied)
        #expect(yaml.contains("- package: SnapKit"))
        #expect(yaml.contains("  SnapKit:\n"))
    }

    @Test
    func `addPackageDependency is idempotent`() {
        var yaml = Self.baselineYaml
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

    // MARK: - enableMacCatalyst

    @Test
    func `enableMacCatalyst adds deployment target and supportedDestinations`() {
        var yaml = Self.baselineYaml
        let result = ProjectYamlEditor.enableMacCatalyst(yaml: &yaml, targetName: "MyApp")

        #expect(result == .applied)
        #expect(yaml.contains("    macCatalyst: 18.0"))
        #expect(yaml.contains("    supportedDestinations: [iOS, macCatalyst]"))
    }

    @Test
    func `enableMacCatalyst is idempotent`() {
        var yaml = Self.baselineYaml
        _ = ProjectYamlEditor.enableMacCatalyst(yaml: &yaml, targetName: "MyApp")
        let snapshot = yaml

        let result = ProjectYamlEditor.enableMacCatalyst(yaml: &yaml, targetName: "MyApp")
        #expect(result == .alreadyPresent)
        #expect(yaml == snapshot)
    }

    @Test
    func `enableMacCatalyst fails for missing target`() {
        var yaml = Self.baselineYaml
        let result = ProjectYamlEditor.enableMacCatalyst(yaml: &yaml, targetName: "Nope")

        if case let .failed(reason) = result {
            #expect(reason.contains("Nope") || reason.contains("not found"))
        } else {
            Issue.record("expected .failed, got \(result)")
        }
    }

    // MARK: - addWidgetTarget

    @Test
    func `addWidgetTarget appends a new widget extension target`() {
        var yaml = Self.baselineYaml
        let result = ProjectYamlEditor.addWidgetTarget(
            yaml: &yaml,
            appName: "MyApp",
            bundleID: "com.example.myapp"
        )

        #expect(result == .applied)
        #expect(yaml.contains("  MyAppWidget:"))
        #expect(yaml.contains("    type: app-extension"))
        #expect(yaml.contains("PRODUCT_BUNDLE_IDENTIFIER: com.example.myapp.Widget"))
        #expect(yaml.contains("    dependencies:"))
        #expect(yaml.contains("- sdk: SwiftUI.framework"))
        #expect(yaml.contains("- sdk: WidgetKit.framework"))
    }

    @Test
    func `addWidgetTarget inserts before packages block when present`() throws {
        var yaml = Self.baselineYaml + """
        packages:
          Lottie:
            url: https://github.com/airbnb/lottie-spm.git
            from: 4.5.0

        """

        let result = ProjectYamlEditor.addWidgetTarget(
            yaml: &yaml,
            appName: "MyApp",
            bundleID: "com.example.myapp"
        )

        #expect(result == .applied)
        let widgetIdx = try #require(yaml.range(of: "  MyAppWidget:")?.lowerBound)
        let packagesIdx = try #require(yaml.range(of: "\npackages:\n")?.lowerBound)
        #expect(widgetIdx < packagesIdx)
    }

    @Test
    func `addWidgetTarget is idempotent`() {
        var yaml = Self.baselineYaml
        _ = ProjectYamlEditor.addWidgetTarget(yaml: &yaml, appName: "MyApp", bundleID: "com.example.myapp")
        let snapshot = yaml

        let result = ProjectYamlEditor.addWidgetTarget(yaml: &yaml, appName: "MyApp", bundleID: "com.example.myapp")
        #expect(result == .alreadyPresent)
        #expect(yaml == snapshot)
    }

    // MARK: - wireAppForWidget

    @Test
    func `wireAppForWidget injects entitlements and widget dependency`() {
        var yaml = Self.baselineYaml
        let result = ProjectYamlEditor.wireAppForWidget(yaml: &yaml, appName: "MyApp")

        #expect(result == .applied)
        #expect(yaml.contains("CODE_SIGN_ENTITLEMENTS: MyApp/MyApp.entitlements"))
        #expect(yaml.contains("- target: MyAppWidget"))
    }

    @Test
    func `wireAppForWidget is idempotent`() {
        var yaml = Self.baselineYaml
        _ = ProjectYamlEditor.wireAppForWidget(yaml: &yaml, appName: "MyApp")
        let snapshot = yaml

        let result = ProjectYamlEditor.wireAppForWidget(yaml: &yaml, appName: "MyApp")
        #expect(result == .alreadyPresent)
        #expect(yaml == snapshot)
    }

    @Test
    func `wireAppForWidget fails when target is missing`() {
        var yaml = Self.baselineYaml
        let result = ProjectYamlEditor.wireAppForWidget(yaml: &yaml, appName: "Nope")

        if case let .failed(reason) = result {
            #expect(reason.contains("Nope") || reason.contains("not found"))
        } else {
            Issue.record("expected .failed, got \(result)")
        }
    }

    // MARK: - End-to-end widget flow

    @Test
    func `widget end to end emits both target and app wiring`() {
        var yaml = Self.baselineYaml
        let widgetResult = ProjectYamlEditor.addWidgetTarget(
            yaml: &yaml,
            appName: "MyApp",
            bundleID: "com.example.myapp"
        )
        let wireResult = ProjectYamlEditor.wireAppForWidget(yaml: &yaml, appName: "MyApp")

        #expect(widgetResult == .applied)
        #expect(wireResult == .applied)
        #expect(yaml.contains("  MyAppWidget:"))
        #expect(yaml.contains("CODE_SIGN_ENTITLEMENTS: MyApp/MyApp.entitlements"))
        #expect(yaml.contains("- target: MyAppWidget"))

        // Re-running both should be idempotent.
        let widgetAgain = ProjectYamlEditor.addWidgetTarget(yaml: &yaml, appName: "MyApp", bundleID: "com.example.myapp")
        let wireAgain = ProjectYamlEditor.wireAppForWidget(yaml: &yaml, appName: "MyApp")
        #expect(widgetAgain == .alreadyPresent)
        #expect(wireAgain == .alreadyPresent)
    }
}
