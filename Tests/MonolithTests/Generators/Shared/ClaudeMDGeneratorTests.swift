import Foundation
import Testing
@testable import MonolithLib

struct ClaudeMDGeneratorTests {
    // MARK: - App

    @Test
    func `app CLAUDE.md has app name and tech stack`() {
        let config = AppConfig(
            name: "MyApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .xcodeProj,
            tabs: [],
            primaryColor: "#007AFF",
            features: [.swiftData, .lumiKit],
            author: "Test",
            licenseType: .proprietary
        )
        let output = ClaudeMDGenerator.generateForApp(config: config)
        #expect(output.contains("# MyApp"))
        #expect(output.contains("SwiftData"))
        #expect(output.contains("LumiKit"))
        // No devTooling, so no Makefile: the raw xcodebuild commands instead.
        #expect(output.contains("xcodebuild build -project MyApp.xcodeproj -scheme MyApp"))
        #expect(!output.contains("make build"))
    }

    @Test
    func `app CLAUDE.md shows tab navigation when tabs present`() {
        let config = AppConfig(
            name: "MyApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .xcodeProj,
            tabs: [TabDefinition(name: "Home", icon: "house")],
            primaryColor: "#007AFF",
            features: [],
            author: "Test",
            licenseType: .proprietary
        )
        let output = ClaudeMDGenerator.generateForApp(config: config)
        #expect(output.contains("UITabBarController"))
    }

    @Test
    func `app CLAUDE.md names the LumiKit 1 theme value and tab bar`() {
        let config = AppConfig(
            name: "MyApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .xcodeProj,
            tabs: [TabDefinition(name: "Home", icon: "house")],
            primaryColor: "#007AFF",
            features: [.lumiKit],
            author: "Test",
            licenseType: .proprietary
        )
        let output = ClaudeMDGenerator.generateForApp(config: config)
        #expect(output.contains("- **Design System**: LumiKit 1.x"))
        #expect(output.contains("- **Navigation**: LMKTabBarController (tabs declared as `LMKTab`s) + LMKNavigationController per tab"))
        #expect(output.contains("- **Theme**: `LMKTheme.myApp` in `Shared/Design/MyAppTheme.swift`, applied in AppDelegate with `LMKTheme.apply(.myApp)`"))
        #expect(!output.contains("LMKThemeManager"))
    }

    @Test
    func `app CLAUDE.md shows xcodebuild for XcodeGen`() {
        let config = AppConfig(
            name: "MyApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .xcodeGen,
            tabs: [],
            primaryColor: "#007AFF",
            features: [],
            author: "Test",
            licenseType: .proprietary
        )
        let output = ClaudeMDGenerator.generateForApp(config: config)
        #expect(output.contains("xcodegen generate"))
        #expect(output.contains("xcodebuild build -project MyApp.xcodeproj -scheme MyApp -destination '\(Defaults.simulatorDestination)' -quiet"))
        #expect(output.contains("xcodebuild test -project MyApp.xcodeproj -scheme MyApp -destination '\(Defaults.simulatorDestination)' -quiet"))
        #expect(!output.contains("make "))
    }

    private func appConfig(
        features: Set<AppFeature>,
        projectSystem: ProjectSystem = .xcodeGen
    ) -> AppConfig {
        AppConfig(
            name: "MyApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: projectSystem,
            tabs: [],
            primaryColor: "#007AFF",
            features: features,
            author: "Test",
            licenseType: .proprietary
        )
    }

    @Test
    func `app CLAUDE.md uses make targets when dev tooling wrote a Makefile`() {
        let output = ClaudeMDGenerator.generateForApp(config: appConfig(features: [.devTooling]))
        #expect(output.contains("make build"))
        #expect(output.contains("make test"))
        #expect(output.contains("make check            # SwiftLint + SwiftFormat\n"))
        #expect(!output.contains("xcodebuild build"))
    }

    @Test
    func `app make check blurb lists every gate the Makefile chains`() {
        let output = ClaudeMDGenerator.generateForApp(config: appConfig(features: [.devTooling, .localization, .appIconValidation]))
        #expect(output.contains("# SwiftLint + SwiftFormat + strings audit + app icon validation"))
        let xcodeProj = ClaudeMDGenerator.generateForApp(config: appConfig(features: [.devTooling, .appIconValidation], projectSystem: .xcodeProj))
        #expect(xcodeProj.contains("# SwiftLint + SwiftFormat + app icon validation"))
    }

    @Test
    func `app raw test command runs serially for CloudKit persistence`() {
        // Matches the Makefile's -parallel-testing-enabled NO for CloudKit apps.
        let output = ClaudeMDGenerator.generateForApp(config: appConfig(features: [.coreData, .cloudKit]))
        #expect(output.contains("-quiet -parallel-testing-enabled NO"))
    }

    @Test
    func `guides are self-contained`() {
        // The old header linked ../../.claude/CLAUDE.md, a dead link outside
        // the author's own folder layout.
        let app = ClaudeMDGenerator.generateForApp(config: appConfig(features: [.devTooling]))
        let package = ClaudeMDGenerator.generateForPackage(config: PackageConfig(
            name: "MyLib", platforms: [], targets: [TargetDefinition(name: "MyLib", dependencies: [])],
            features: [], mainActorTargets: [], author: "Test", licenseType: .mit
        ))
        let cli = ClaudeMDGenerator.generateForCLI(config: CLIConfig(
            name: "mytool", includeArgumentParser: true, features: [.devTooling], author: "Test", licenseType: .apache2
        ))
        for output in [app, package, cli] {
            #expect(!output.contains("../../"))
            #expect(!output.lowercased().contains("workspace"))
        }
        #expect(app.contains("> General Swift conventions are enforced by `.swiftlint.yml` and `.swiftformat`; this file holds MyApp-specific rules."))
        // No devTooling: the lint configs don't exist, so they aren't named.
        #expect(package.contains("> This file holds MyLib-specific rules."))
        #expect(!package.contains(".swiftlint.yml"))
    }

    @Test
    func `app CLAUDE.md carries the CloudKit schema checklist`() {
        let coreData = ClaudeMDGenerator.generateForApp(config: appConfig(features: [.coreData, .cloudKit]))
        #expect(coreData.contains("## CloudKit Schema"))
        #expect(coreData.contains("add a new model version before removing or renaming"))
        #expect(coreData.contains("deploy it to Production"))
        #expect(coreData.contains("initializeCloudKitSchema()"))
        #expect(coreData.contains("#if DEBUG"))
        #expect(!coreData.contains("**SwiftData**"))

        let swiftData = ClaudeMDGenerator.generateForApp(config: appConfig(features: [.swiftData, .cloudKit]))
        #expect(swiftData.contains("**SwiftData**: removing or renaming a property or `@Model` type is unsafe"))
        #expect(!swiftData.contains("initializeCloudKitSchema"))

        let local = ClaudeMDGenerator.generateForApp(config: appConfig(features: [.coreData]))
        #expect(!local.contains("CloudKit"))
    }

    // MARK: - Package

    @Test
    func `package CLAUDE.md has target table`() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "Core", dependencies: []),
                TargetDefinition(name: "UI", dependencies: ["Core"]),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["UI"],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(output.contains("# MyLib"))
        #expect(output.contains("| Core |"))
        #expect(output.contains("| UI |"))
        #expect(output.contains("xcodebuild"))
        // Targets are "Core" / "UI", so no `MyLib` scheme exists — only the
        // `MyLib-Package` umbrella. See PackageConfig.xcodeBuildScheme.
        #expect(output.contains("-scheme MyLib-Package"))
        #expect(!output.contains("-scheme MyLib "))
    }

    @Test
    func `package CLAUDE.md uses literal bullet, not Swift escape syntax`() {
        // Regression: an earlier version emitted "\\u{2022}" (literal backslash-u
        // sequence) into the rendered markdown footer because the Swift string
        // literal was double-escaped. The output must be the actual bullet glyph.
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLib", dependencies: [])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(output.contains("•"))
        #expect(!output.contains("\\u{2022}"))
    }

    @Test
    func `package CLAUDE.md xcodebuild includes -skipPackagePluginValidation`() {
        // Without the flag, any
        // package that later adds an SPM build tool plugin triggers an Xcode
        // plugin-trust prompt that breaks unattended xcodebuild invocations.
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLibUI", dependencies: [])],
            features: [.defaultIsolation],
            mainActorTargets: ["MyLibUI"],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        // Flag present on both build and test invocations.
        #expect(output.components(separatedBy: "-skipPackagePluginValidation").count - 1 == 2)
    }

    // MARK: - #3 — Umbrella scheme

    @Test
    func `package CLAUDE.md uses umbrella scheme when package has executable targets`() {
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MultiLib", dependencies: []),
                TargetDefinition(name: "multi-tool", dependencies: ["MultiLib"], isExecutable: true),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["MultiLib"],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(output.contains("-scheme MultiLib-Package"))
        // Bare scheme must not appear as a build target — the umbrella
        // covers everything.
        #expect(!output.contains("-scheme MultiLib "))
    }

    @Test
    func `package CLAUDE.md uses umbrella scheme when package has test-helper targets`() {
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MultiLib", dependencies: []),
                TargetDefinition(name: "MultiLibTesting", dependencies: ["MultiLib"]),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["MultiLib"],
            author: "Test",
            licenseType: .mit,
            testHelperTargets: ["MultiLibTesting"]
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(output.contains("-scheme MultiLib-Package"))
    }

    @Test
    func `package CLAUDE.md keeps named scheme when a target is named like the package`() {
        // No executables, no test-helpers, and a target named exactly like the
        // package → Xcode emits a `MyLib` scheme and it builds everything.
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLib", dependencies: [])],
            features: [.defaultIsolation],
            mainActorTargets: ["MyLib"],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(output.contains("-scheme MyLib "))
        #expect(!output.contains("-scheme MyLib-Package"))
    }

    @Test
    func `package CLAUDE.md uses umbrella scheme when no target is named like the package`() {
        // Package "MyLib" whose only target is "MyLibUI", a common multi-target
        // framework shape. `xcodebuild -scheme MyLib` would fail outright.
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLibUI", dependencies: [])],
            features: [.defaultIsolation],
            mainActorTargets: ["MyLibUI"],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(output.contains("-scheme MyLib-Package"))
        #expect(!output.contains("-scheme MyLib "))
    }

    @Test
    func `package CLAUDE.md documents why umbrella scheme is used`() {
        // The umbrella scheme is auto-generated by Xcode; future readers may
        // "simplify" Package.swift in ways that drop it. Document the reason
        // so the build command stays load-bearing.
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MultiLib", dependencies: []),
                TargetDefinition(name: "MultiLibTesting", dependencies: ["MultiLib"]),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["MultiLib"],
            author: "Test",
            licenseType: .mit,
            testHelperTargets: ["MultiLibTesting"]
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(output.contains("MultiLib-Package` umbrella scheme is required"))
        // Tailored explainer: this package has a test-helper but no exec.
        #expect(output.contains("test-helper library that needs to build"))
        #expect(!output.contains("executable sibling targets"))
        #expect(!output.contains("mixes target kinds")) // generic fallback should not appear
    }

    @Test
    func `package CLAUDE.md umbrella explainer mentions executables when only execs are present`() {
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MultiLib", dependencies: []),
                TargetDefinition(name: "multi-tool", dependencies: ["MultiLib"], isExecutable: true),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["MultiLib"],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(output.contains("executable sibling targets alongside libraries"))
        #expect(!output.contains("test-helper library that needs to build"))
    }

    @Test
    func `package CLAUDE.md umbrella explainer mentions both kinds when both are present`() {
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MultiLib", dependencies: []),
                TargetDefinition(name: "MultiLibTesting", dependencies: ["MultiLib"]),
                TargetDefinition(name: "multi-tool", dependencies: ["MultiLib"], isExecutable: true),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["MultiLib"],
            author: "Test",
            licenseType: .mit,
            testHelperTargets: ["MultiLibTesting"]
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(output.contains("mixes executables, test-helper libs, and MainActor libs"))
    }

    @Test
    func `package CLAUDE.md umbrella explainer avoids inline em dashes`() {
        // Generated text uses no inline em dashes as parenthetical separators
        // (`key — explanation` mid-sentence). The umbrella blockquote used to
        // contain ` scheme — that only builds...`; replaced with a comma.
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MultiLib", dependencies: []),
                TargetDefinition(name: "MultiLibTesting", dependencies: ["MultiLib"]),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["MultiLib"],
            author: "Test",
            licenseType: .mit,
            testHelperTargets: ["MultiLibTesting"]
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        // The specific banned form: ` scheme — that only builds...`
        #expect(!output.contains("scheme — that"))
        // The replacement form: ` scheme, which only builds the main library.`
        #expect(output.contains("scheme, which only builds the main library"))
    }

    @Test
    func `package CLAUDE.md omits umbrella explainer when the named scheme is used`() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLib", dependencies: [])],
            features: [.defaultIsolation],
            mainActorTargets: ["MyLib"],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(!output.contains("umbrella scheme is required"))
    }

    @Test
    func `package CLAUDE.md scopes swift build to Foundation-only targets`() {
        // Bare `swift build` compiles every target, so a package with a
        // MainActor (UIKit) target fails on a macOS host. The doc must point
        // at `--target` for the Foundation-only libs and say plainly that the
        // bare invocations don't work, rather than implying they do.
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MyLibCore", dependencies: []),
                TargetDefinition(name: "MyLibNet", dependencies: ["MyLibCore"]),
                TargetDefinition(name: "MyLibUI", dependencies: ["MyLibCore"]),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["MyLibUI"],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(output.contains("swift build --target MyLibCore"))
        #expect(output.contains("`MyLibCore`, `MyLibNet`"))
        #expect(!output.contains("`MyLibUI`) build standalone"))
        #expect(output.contains("fail on a macOS host"))
        #expect(!output.contains("Foundation-only targets can use `swift build`"))
    }

    @Test
    func `package CLAUDE.md omits the standalone build snippet when every target is MainActor`() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLibUI", dependencies: [])],
            features: [.defaultIsolation],
            mainActorTargets: ["MyLibUI"],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(!output.contains("swift build --target"))
        #expect(output.contains("fail on a macOS host"))
    }

    @Test
    func `package CLAUDE.md explains the umbrella by naming the missing scheme`() {
        // No execs, no test-helpers — the umbrella is required purely because
        // no target carries the package name. The explainer must say that
        // rather than claiming the package "mixes target kinds", and must not
        // point readers at a named scheme that does not exist.
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MyLibCore", dependencies: []),
                TargetDefinition(name: "MyLibUI", dependencies: ["MyLibCore"]),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["MyLibUI"],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(output.contains("no target is named `MyLib`, so Xcode generates no `MyLib` scheme"))
        #expect(output.contains("does not contain a scheme named MyLib"))
        #expect(!output.contains("mixes target kinds"))
        #expect(!output.contains("which only builds the main library"))
    }

    @Test
    func `package CLAUDE.md splits libraries from executables in tables`() throws {
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MultiLib", dependencies: []),
                TargetDefinition(name: "multi-tool", dependencies: ["MultiLib"], isExecutable: true),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["MultiLib"],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)

        // Two separate sections — not one mixed table.
        #expect(output.contains("## Libraries"))
        #expect(output.contains("## Executables"))

        // Library table column header is "Default isolation" (wording matters —
        // the prior "MainActor" column header was misleading because a library
        // that depends on a MainActor lib isn't itself MainActor-isolated).
        // The cell VALUE can still be the string "MainActor" — that's the
        // accurate name of the isolation level for targets that opt in.
        #expect(output.contains("| Target | Dependencies | Default isolation |"))
        #expect(!output.contains("| Target | Dependencies | MainActor |"))
        #expect(output.contains("| MultiLib | — | MainActor |"))

        // Executable table row formats the binary as backticked code + run command.
        #expect(output.contains("| `multi-tool` |"))
        #expect(output.contains("swift run multi-tool"))

        // The exec must NOT appear in the libraries table.
        let libsHeader = try #require(output.range(of: "## Libraries"))
        let execsHeader = try #require(output.range(of: "## Executables"))
        let librariesSection = output[libsHeader.upperBound ..< execsHeader.lowerBound]
        #expect(!librariesSection.contains("multi-tool"))
    }

    @Test
    func `package CLAUDE.md adds swift run snippet for executable targets`() {
        // When a package has executable sibling target(s), the Build & Test
        // section should also show how to run them. Without this, the only
        // mention of the executable is the Executables table — adopters have
        // to infer that `swift run <name>` is the entry point.
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MultiLib", dependencies: []),
                TargetDefinition(name: "multi-tool", dependencies: ["MultiLib"], isExecutable: true),
                TargetDefinition(name: "multi-codegen", dependencies: ["MultiLib"], isExecutable: true),
            ],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(output.contains("swift run multi-tool"))
        #expect(output.contains("swift run multi-codegen"))
        // Plural form for ≥2 executables.
        #expect(output.contains("Run executable sibling targets:"))
    }

    @Test
    func `package CLAUDE.md omits swift run snippet for lib-only packages`() {
        // No executables = no run snippet (the table is the only mention).
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLib", dependencies: [])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(!output.contains("Run executable"))
        #expect(!output.contains("swift run "))
    }

    @Test
    func `package CLAUDE.md run snippet uses singular phrasing for one executable`() {
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MultiLib", dependencies: []),
                TargetDefinition(name: "multi-tool", dependencies: ["MultiLib"], isExecutable: true),
            ],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(output.contains("Run executable sibling target:"))
        #expect(!output.contains("Run executable sibling targets:"))
    }

    @Test
    func `package CLAUDE.md leads with make targets and keeps raw xcodebuild quiet`() throws {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLib", dependencies: [])],
            features: [.defaultIsolation, .devTooling],
            mainActorTargets: ["MyLib"],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        let make = try #require(output.range(of: "make build  # xcodebuild build, iOS Simulator"))
        let raw = try #require(output.range(of: "xcodebuild build -scheme MyLib "))
        #expect(make.lowerBound < raw.lowerBound)
        #expect(output.contains("make check  # SwiftLint + SwiftFormat"))
        // Every raw xcodebuild line is quiet.
        let xcodebuildLines = output.split(separator: "\n").filter { $0.hasPrefix("xcodebuild ") }
        #expect(xcodebuildLines.count == 2)
        #expect(xcodebuildLines.allSatisfy { $0.contains(" -quiet ") })
    }

    @Test
    func `package CLAUDE.md swaps to xcodebuild for a UIKit-only dependency`() {
        // No MainActor target, but LumiKitUI imports UIKit, so `swift build`
        // fails on a Mac host all the same.
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MyLibCore", dependencies: []),
                TargetDefinition(name: "MyLibUI", dependencies: ["MyLibCore", "LumiKitUI"]),
                TargetDefinition(name: "MyLibExtras", dependencies: ["MyLibUI"]),
            ],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let output = ClaudeMDGenerator.generateForPackage(config: config)
        #expect(output.contains("This package needs UIKit (UIKit-only dependency `LumiKitUI`)"))
        #expect(output.contains("xcodebuild build -scheme MyLib-Package"))
        // MyLibExtras reaches UIKit through MyLibUI, so only MyLibCore builds standalone.
        #expect(output.contains("Foundation-only targets (`MyLibCore`) build standalone:"))
        #expect(!output.contains("\nswift test\n"))
    }

    @Test
    func `package CLAUDE.md documents the logging core when the package carries it`() throws {
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
            targets: [TargetDefinition(name: "MultiLibCore", dependencies: [])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let placement = try #require(LogCoreGenerator.placement(for: config))
        let output = ClaudeMDGenerator.generateForPackage(config: config, logCore: placement)
        #expect(output.contains("## Logging"))
        #expect(output.contains("`MultiLibLog` (`Sources/MultiLibCore/Logging/MultiLibLog.swift`) is the package's logging core"))
        #expect(!output.contains("by hand"))
        #expect(output.contains("Add categories in `MultiLibLog+Categories.swift`"))
        #expect(output.contains("Replace the placeholder subsystem `com.example.multilib`"))
        #expect(output.contains("`private:`"))
        #expect(output.contains("`error:`"))
        #expect(output.contains("`MultiLibLog.once(key, …)`"))
        #expect(output.contains("`MultiLibLog.withScopedConfiguration(minimumLevel:handler:)`"))
        // The API names in the section exist in the rendered core.
        let core = LogCoreGenerator.render(prefix: placement.prefix, subsystem: placement.subsystem, module: placement.module).source
        for api in ["static func withScopedConfiguration", "static func once(", "public static var minimumLevel", "public static var handler"] {
            #expect(core.contains(api), "core lacks \(api)")
        }

        // Without a placement (e.g. `monolith add claudeMD`), no claim.
        #expect(!ClaudeMDGenerator.generateForPackage(config: config).contains("## Logging"))
    }

    // MARK: - CLI

    @Test
    func `CLI CLAUDE.md has run command`() {
        let config = CLIConfig(
            name: "mytool",
            includeArgumentParser: true,
            features: [],
            author: "Test",
            licenseType: .apache2
        )
        let output = ClaudeMDGenerator.generateForCLI(config: config)
        #expect(output.contains("# mytool"))
        #expect(output.contains("swift run mytool --help"))
        #expect(output.contains("\nswift build\nswift test\n"))
        #expect(!output.contains("make check"))
    }

    @Test
    func `CLI CLAUDE.md describes the library layout and make check`() {
        let config = CLIConfig(
            name: "my-tool",
            includeArgumentParser: true,
            features: [.devTooling],
            author: "Test",
            licenseType: .apache2
        )
        let output = ClaudeMDGenerator.generateForCLI(config: config, includeLayout: true)
        #expect(output.contains("- `Sources/MyToolKit/MyTool.swift`: the `MyTool` ArgumentParser command"))
        #expect(output.contains("- `Sources/my-tool/main.swift`: the `my-tool` executable's entry point; it only calls `MyTool.main()`."))
        #expect(output.contains("`Tests/MyToolKitTests/`"))
        #expect(output.contains("make test   # swift test"))
        #expect(output.contains("make check  # SwiftLint + SwiftFormat"))

        // `monolith add claudeMD` doesn't know an existing CLI's layout.
        #expect(!ClaudeMDGenerator.generateForCLI(config: config).contains("## Layout"))
    }
}
