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
            features: [.swiftData, .lumiKit, .snapKit, .combine],
            author: "Test",
            licenseType: .proprietary
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
        #expect(output.contains("make build"))
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
        #expect(output.contains("make build"))
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
        #expect(output.contains("-scheme MyLib"))
        #expect(!output.contains("-scheme MyLib-Package"))
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
        // License footer with author attribution.
        #expect(output.contains("## License"))
        #expect(output.contains("MIT"))
        #expect(output.contains("© Author Name"))
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
    func `single-library MainActor package uses named scheme`() {
        // Only one isolation level, no execs, no test-helpers → the named
        // scheme builds the whole package; no need for the umbrella.
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
        #expect(output.contains("-scheme MyLib "))
        #expect(!output.contains("-scheme MyLib-Package"))
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
        #expect(output.contains("swift run mytool"))
    }
}
