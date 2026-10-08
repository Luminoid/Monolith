import Foundation
import Testing
@testable import MonolithLib

struct ReadmeGeneratorTests {
    // MARK: - App README

    @Test
    func `app README has title and Monolith attribution`() {
        let config = AppConfig(
            name: "MyApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .xcodeProj,
            tabs: [],
            primaryColor: "#007AFF",
            features: [],
            author: "Test",
            licenseType: .proprietary
        )
        let output = ReadmeGenerator.generateForApp(config: config)
        #expect(output.contains("# MyApp"))
        #expect(output.contains("Monolith"))
    }

    // Regression: the Core Data path seeds a SampleItem ENTITY in the
    // .xcdatamodeld (codegen=class, no Swift file), so the next-steps must not
    // tell adopters to edit a `SampleItem.swift` that doesn't exist. SwiftData
    // genuinely writes that file, so its wording stays.
    @Test
    func `next steps point at the model the persistence layer generates`() {
        func config(_ features: Set<AppFeature>) -> AppConfig {
            AppConfig(
                name: "MyApp",
                bundleID: "com.test.app",
                deploymentTarget: "18.0",
                platforms: [.iPhone],
                projectSystem: .xcodeProj,
                tabs: [],
                primaryColor: "#007AFF",
                features: features,
                author: "Test",
                licenseType: .proprietary
            )
        }

        let coreData = ReadmeGenerator.generateForApp(config: config([.coreData]))
        #expect(coreData.contains("MyApp.xcdatamodeld"))
        #expect(!coreData.contains("SampleItem.swift"))

        let swiftData = ReadmeGenerator.generateForApp(config: config([.swiftData]))
        #expect(swiftData.contains("SampleItem.swift"))
        // The schema is `AppSchema.models` in the model file, not a list in
        // AppDelegate.swift.
        #expect(swiftData.contains("register each `@Model` type in `AppSchema.models`"))
        #expect(!swiftData.contains("AppDelegate.swift"))
    }

    @Test
    func `app README shows tech stack based on features`() {
        let config = AppConfig(
            name: "TestApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .xcodeProj,
            tabs: [],
            primaryColor: "#007AFF",
            features: [.swiftData, .lumiKit, .combine],
            author: "Test",
            licenseType: .proprietary,
            externalPackages: [ExternalPackage(name: "SnapKit", url: "https://github.com/SnapKit/SnapKit.git", requirement: "from: \"6.0.0\"", packageName: nil)],
            targetDependencies: ["SnapKit"]
        )
        let output = ReadmeGenerator.generateForApp(config: config)
        #expect(output.contains("SwiftData"))
        #expect(output.contains("LumiKit"))
        #expect(output.contains("SnapKit"))
        #expect(output.contains("Combine"))
    }

    @Test
    func `app README shows XcodeGen commands for xcodegen project system`() {
        let config = AppConfig(
            name: "TestApp",
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
        let output = ReadmeGenerator.generateForApp(config: config)
        #expect(output.contains("xcodegen generate"))
        // No devTooling, no Makefile.
        #expect(output.contains("xcodebuild build -project TestApp.xcodeproj -scheme TestApp -destination '\(Defaults.simulatorDestination)' -quiet"))
        #expect(!output.contains("make build"))
    }

    @Test
    func `app README shows open xcodeproj for xcodeProj project system`() {
        let config = AppConfig(
            name: "TestApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .xcodeProj,
            tabs: [],
            primaryColor: "#007AFF",
            features: [],
            author: "Test",
            licenseType: .proprietary
        )
        let output = ReadmeGenerator.generateForApp(config: config)
        #expect(output.contains("open TestApp.xcodeproj"))
        #expect(output.contains("xcodebuild test -project TestApp.xcodeproj -scheme TestApp"))
        #expect(!output.contains("xcodegen"))
    }

    private func appConfig(features: Set<AppFeature>, author: String = "Test") -> AppConfig {
        AppConfig(
            name: "TestApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .xcodeGen,
            tabs: [],
            primaryColor: "#007AFF",
            features: features,
            author: author,
            licenseType: .proprietary
        )
    }

    @Test
    func `app README uses make targets with dev tooling`() {
        let output = ReadmeGenerator.generateForApp(config: appConfig(features: [.devTooling, .localization]))
        #expect(output.contains("make build"))
        #expect(output.contains("make test"))
        #expect(output.contains("make check  # SwiftLint + SwiftFormat + strings audit"))
        #expect(!output.contains("xcodebuild build"))
    }

    @Test
    func `app README lists setup once`() {
        // Setup used to appear under both Getting Started and Next Steps.
        let output = ReadmeGenerator.generateForApp(config: appConfig(features: [.devTooling, .gitHooks]))
        #expect(output.components(separatedBy: "brew bundle").count - 1 == 1)
        #expect(output.components(separatedBy: "make setup-hooks").count - 1 == 1)
        let hooksOnly = ReadmeGenerator.generateForApp(config: appConfig(features: [.gitHooks]))
        #expect(hooksOnly.components(separatedBy: "git config core.hooksPath Scripts/git-hooks").count - 1 == 1)
        #expect(!hooksOnly.contains("make setup-hooks"))
    }

    @Test
    func `app README has a License section with licenseChangelog`() {
        let output = ReadmeGenerator.generateForApp(config: appConfig(features: [.licenseChangelog], author: "Jane Doe"))
        #expect(output.contains("## License\n\nProprietary (All Rights Reserved). © Jane Doe. See [LICENSE](LICENSE) and [CHANGELOG](CHANGELOG.md)."))
        #expect(!ReadmeGenerator.generateForApp(config: appConfig(features: [], author: "Jane Doe")).contains("## License"))
    }

    @Test
    func `app README notes the CloudKit schema rule`() {
        let output = ReadmeGenerator.generateForApp(config: appConfig(features: [.coreData, .cloudKit, .claudeMD]))
        #expect(output.contains("## CloudKit"))
        #expect(output.contains("deploy it to Production"))
        #expect(output.contains("`.claude/CLAUDE.md` lists the safe schema changes"))
        // Without CLAUDE.md, the note doesn't point at a missing file.
        let noGuide = ReadmeGenerator.generateForApp(config: appConfig(features: [.coreData, .cloudKit]))
        #expect(noGuide.contains("## CloudKit"))
        #expect(!noGuide.contains("CLAUDE.md"))
        #expect(!ReadmeGenerator.generateForApp(config: appConfig(features: [.coreData])).contains("## CloudKit"))
    }

    @Test
    func `READMEs avoid em dashes as sentence separators`() {
        let outputs = [
            ReadmeGenerator.generateForApp(config: appConfig(features: [.devTooling, .gitHooks, .coreData, .cloudKit, .licenseChangelog], author: "Jane Doe")),
            ReadmeGenerator.generateForCLI(config: CLIConfig(
                name: "my-tool", includeArgumentParser: true, features: [.devTooling, .gitHooks, .licenseChangelog],
                author: "Jane Doe", licenseType: .apache2
            )),
        ]
        for output in outputs {
            #expect(!output.contains(" — "))
        }
    }

    // MARK: - Package README

    @Test
    func `package README has target table`() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
            targets: [
                TargetDefinition(name: "Core", dependencies: []),
                TargetDefinition(name: "UI", dependencies: ["Core"]),
            ],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let output = ReadmeGenerator.generateForPackage(config: config)
        #expect(output.contains("# MyLib"))
        #expect(output.contains("| Core |"))
        #expect(output.contains("| UI | Core |"))
    }

    @Test
    func `package README uses xcodebuild when defaultIsolation enabled`() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [PlatformVersion(platform: "iOS", version: "18.0")],
            targets: [
                TargetDefinition(name: "Core", dependencies: []),
                TargetDefinition(name: "UI", dependencies: ["Core"]),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["UI"],
            author: "Test",
            licenseType: .mit
        )
        let output = ReadmeGenerator.generateForPackage(config: config)
        #expect(output.contains("xcodebuild build"))
        // No target is named "MyLib" (they're "Core" / "UI"), so Xcode emits
        // no `MyLib` scheme — only the `MyLib-Package` umbrella plus one per
        // target. See PackageConfig.xcodeBuildScheme.
        #expect(output.contains("-scheme MyLib-Package"))
        #expect(!output.contains("-scheme MyLib "))
        #expect(!output.contains("swift build"))
    }

    @Test
    func `package README includes Installation snippet for MIT-licensed packages`() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLib", dependencies: [])],
            features: [.licenseChangelog],
            mainActorTargets: [],
            author: "Author Name",
            licenseType: .mit
        )
        let output = ReadmeGenerator.generateForPackage(config: config)
        // Downstream-consumer snippet, not just "how to build locally".
        #expect(output.contains("## Installation"))
        #expect(output.contains(".package(url:"))
        #expect(output.contains("MyLib.git"))
        // License footer with author attribution. Both LICENSE and CHANGELOG
        // are written by the licenseChangelog feature, so the footer links
        // both (drives discovery of the changelog from the README).
        #expect(output.contains("## License"))
        #expect(output.contains("MIT"))
        #expect(output.contains("© Author Name"))
        #expect(output.contains("[LICENSE](LICENSE)"))
        #expect(output.contains("[CHANGELOG](CHANGELOG.md)"))
    }

    @Test
    func `package README omits Installation snippet for proprietary packages`() {
        // Proprietary packages aren't meant for external consumption.
        let config = PackageConfig(
            name: "InternalLib",
            platforms: [],
            targets: [TargetDefinition(name: "InternalLib", dependencies: [])],
            features: [.licenseChangelog],
            mainActorTargets: [],
            author: "Author Name",
            licenseType: .proprietary
        )
        let output = ReadmeGenerator.generateForPackage(config: config)
        #expect(!output.contains("## Installation"))
        #expect(!output.contains(".package(url:"))
    }

    @Test
    func `package README has no duplicate Getting Started or Next Steps sections`() {
        // Regression: the prior template listed "brew bundle / make setup-hooks"
        // under both `## Getting Started` and `## Next Steps`. We collapsed to a
        // single `## Development` section.
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLib", dependencies: [])],
            features: [.devTooling, .gitHooks, .licenseChangelog],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit
        )
        let output = ReadmeGenerator.generateForPackage(config: config)
        #expect(!output.contains("## Getting Started"))
        #expect(!output.contains("## Next Steps"))
        #expect(output.contains("## Development"))
        // `brew bundle` appears exactly once (not twice as in the old layout).
        #expect(output.components(separatedBy: "brew bundle").count - 1 == 1)
    }

    @Test
    func `package README xcodebuild includes -skipPackagePluginValidation`() {
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLibUI", dependencies: [])],
            features: [.defaultIsolation],
            mainActorTargets: ["MyLibUI"],
            author: "Test",
            licenseType: .mit
        )
        let output = ReadmeGenerator.generateForPackage(config: config)
        #expect(output.components(separatedBy: "-skipPackagePluginValidation").count - 1 == 2)
    }

    // MARK: - #3 — Umbrella scheme

    @Test
    func `single-library package with an eponymous target uses the named scheme`() {
        // One library named exactly like the package, no execs, no
        // test-helpers → Xcode emits a `MyLib` scheme and it builds
        // everything; no need for the umbrella.
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLib", dependencies: [])],
            features: [.defaultIsolation],
            mainActorTargets: ["MyLib"],
            author: "Test",
            licenseType: .mit
        )
        let output = ReadmeGenerator.generateForPackage(config: config)
        #expect(output.contains("-scheme MyLib "))
        #expect(!output.contains("-scheme MyLib-Package"))
    }

    @Test
    func `single-library package without an eponymous target uses the umbrella scheme`() {
        // The package is "MyLib" but its only target is "MyLibUI", so no
        // `MyLib` scheme exists — `xcodebuild -scheme MyLib` would fail with
        // "does not contain a scheme named MyLib". Multi-target frameworks
        // commonly have this shape.
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLibUI", dependencies: [])],
            features: [.defaultIsolation],
            mainActorTargets: ["MyLibUI"],
            author: "Test",
            licenseType: .mit
        )
        let output = ReadmeGenerator.generateForPackage(config: config)
        #expect(output.contains("-scheme MyLib-Package"))
        #expect(!output.contains("-scheme MyLib "))
    }

    @Test
    func `package with executable target uses <Name>-Package umbrella scheme`() {
        // Mixed kinds → umbrella scheme covers libs + executable in one
        // xcodebuild invocation.
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
        let output = ReadmeGenerator.generateForPackage(config: config)
        #expect(output.contains("-scheme MultiLib-Package"))
        // The bare "MultiLib" scheme must NOT appear as a build target (only
        // as a section header or library row).
        #expect(!output.contains("-scheme MultiLib "))
    }

    @Test
    func `package with test-helper lib uses umbrella scheme`() {
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
        let output = ReadmeGenerator.generateForPackage(config: config)
        #expect(output.contains("-scheme MultiLib-Package"))
    }

    // MARK: - #8 — README org slug from author

    @Test
    func `Installation snippet derives github org from author name`() {
        // Author "Luminoid" → case-preserved slug "Luminoid". GitHub is
        // case-insensitive on lookup but case-preserving on display, so
        // emitting the lowercased form would produce a working URL that
        // 301-redirects on first clone — jarring in published docs.
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLib", dependencies: [])],
            features: [.licenseChangelog],
            mainActorTargets: [],
            author: "Luminoid",
            licenseType: .mit
        )
        let output = ReadmeGenerator.generateForPackage(config: config)
        #expect(output.contains("github.com/Luminoid/MyLib.git"))
        #expect(!output.contains("<your-org>"))
    }

    @Test
    func `Installation snippet hyphenates multi-word author names`() {
        // Author "Jane Doe" → "Jane-Doe" (GitHub-style, case preserved).
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLib", dependencies: [])],
            features: [.licenseChangelog],
            mainActorTargets: [],
            author: "Jane Doe",
            licenseType: .mit
        )
        let output = ReadmeGenerator.generateForPackage(config: config)
        #expect(output.contains("github.com/Jane-Doe/MyLib.git"))
    }

    @Test
    func `Installation snippet keeps placeholder for default author`() {
        // The literal "Author" is the SPM-default fallback when git can't
        // resolve a name. Don't slug it — keep the placeholder so adopters
        // know to fill it in.
        let config = PackageConfig(
            name: "MyLib",
            platforms: [],
            targets: [TargetDefinition(name: "MyLib", dependencies: [])],
            features: [.licenseChangelog],
            mainActorTargets: [],
            author: "Author",
            licenseType: .mit
        )
        let output = ReadmeGenerator.generateForPackage(config: config)
        #expect(output.contains("<your-org>"))
    }

    @Test
    func `org slug strips disallowed characters and collapses hyphens`() {
        // Edge case: author "  --Foo  Bar--  " → "Foo-Bar" (trim + collapse,
        // case preserved).
        #expect(ReadmeGenerator.githubOrgSlug(author: "  --Foo  Bar--  ") == "Foo-Bar")
        // Inputs that contain nothing in [A-Za-z0-9-] (punctuation-only, or any
        // script outside ASCII) slug to empty after filtering. Fall back to
        // the placeholder rather than emit a broken URL like `github.com//X.git`.
        #expect(ReadmeGenerator.githubOrgSlug(author: "~~~") == "<your-org>")
        #expect(ReadmeGenerator.githubOrgSlug(author: "") == "<your-org>")
    }

    @Test
    func `org slug falls back for a name with non-ASCII letters`() {
        // Dropping the letters would leave a different, real-looking handle
        // ("Zoë" → "Zo"), so these get the placeholder instead.
        #expect(ReadmeGenerator.githubOrgSlug(author: "Zoë Example") == "<your-org>")
        #expect(ReadmeGenerator.githubOrgSlug(author: "李纯厚") == "<your-org>")
        #expect(LicenseChangelogGenerator.unreleasedURL(author: "Zoë", name: "MyTool", licenseType: .mit) == nil)
    }

    @Test
    func `package README splits libraries from executables`() throws {
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
        let output = ReadmeGenerator.generateForPackage(config: config)
        #expect(output.contains("## Libraries"))
        #expect(output.contains("## Executables"))
        #expect(output.contains("swift run multi-tool"))

        // Exec must not appear in the libraries section.
        let libsRange = try #require(output.range(of: "## Libraries"))
        let execsRange = try #require(output.range(of: "## Executables"))
        let librariesSection = output[libsRange.upperBound ..< execsRange.lowerBound]
        #expect(!librariesSection.contains("multi-tool"))
    }

    // MARK: - CLI README

    @Test
    func `CLI README has run command`() {
        let config = CLIConfig(
            name: "mytool",
            includeArgumentParser: true,
            features: [],
            author: "Test",
            licenseType: .apache2
        )
        let output = ReadmeGenerator.generateForCLI(config: config)
        #expect(output.contains("# mytool"))
        #expect(output.contains("swift run mytool --help"))
        #expect(output.contains("\nswift build\nswift test\n"))
    }

    @Test
    func `CLI README mirrors the package sections`() {
        let config = CLIConfig(
            name: "my-tool",
            includeArgumentParser: false,
            features: [.devTooling, .gitHooks, .licenseChangelog],
            author: "Jane Doe",
            licenseType: .apache2
        )
        let output = ReadmeGenerator.generateForCLI(config: config)
        #expect(output.contains("## Usage"))
        #expect(output.contains("swift run my-tool\n"))
        #expect(output.contains("## Development"))
        #expect(output.contains("make test   # swift test"))
        #expect(output.contains("make check  # SwiftLint + SwiftFormat"))
        #expect(output.contains("## License\n\nApache 2.0. © Jane Doe."))
        #expect(!output.contains("## Next Steps"))
        #expect(!output.contains("## Getting Started"))
        #expect(output.components(separatedBy: "brew bundle").count - 1 == 1)
        #expect(output.components(separatedBy: "make setup-hooks").count - 1 == 1)
    }

    @Test
    func `package README keeps raw xcodebuild quiet and adds make check`() {
        let raw = ReadmeGenerator.generateForPackage(config: PackageConfig(
            name: "MyLib", platforms: [], targets: [TargetDefinition(name: "MyLibUI", dependencies: ["LumiKitUI"])],
            features: [], mainActorTargets: [], author: "Test", licenseType: .mit
        ))
        let xcodebuildLines = raw.split(separator: "\n").filter { $0.hasPrefix("xcodebuild ") }
        #expect(xcodebuildLines.count == 2)
        #expect(xcodebuildLines.allSatisfy { $0.contains(" -quiet ") })
        #expect(!raw.contains("swift build"))

        let make = ReadmeGenerator.generateForPackage(config: PackageConfig(
            name: "MyLib", platforms: [], targets: [TargetDefinition(name: "MyLib", dependencies: [])],
            features: [.devTooling], mainActorTargets: [], author: "Test", licenseType: .mit
        ))
        #expect(make.contains("make build  # swift build\nmake test   # swift test\nmake check  # SwiftLint + SwiftFormat"))
    }

    @Test
    func `README and CLAUDE_md render the same target tables`() {
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
        let readme = ReadmeGenerator.generateForPackage(config: config)
        let claudeMD = ClaudeMDGenerator.generateForPackage(config: config)
        for table in ProjectDocs.targetTables(config: config) {
            #expect(readme.contains(table))
            #expect(claudeMD.contains(table))
        }
        #expect(readme.contains("| Target | Kind | Dependencies | Default isolation |"))
    }

    @Test
    func `GitHub repository URL needs a real org`() {
        #expect(ReadmeGenerator.githubRepositoryURL(author: "Jane Doe", name: "MyLib") == "https://github.com/Jane-Doe/MyLib")
        #expect(ReadmeGenerator.githubRepositoryURL(author: "Author", name: "MyLib") == nil)
        #expect(ReadmeGenerator.githubRepositoryURL(author: "~~~", name: "MyLib") == nil)
    }
}
