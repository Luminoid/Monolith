import Foundation
import Testing
@testable import MonolithLib

struct ProjectDocsTests {
    @Test
    func `bash block aligns comments past the widest commented command`() {
        let block = ProjectDocs.bashBlock([
            ProjectDocs.Command("make build", "swift build"),
            ProjectDocs.Command("make check", "SwiftLint + SwiftFormat"),
            ProjectDocs.Command("a-much-longer-uncommented-command --flag"),
        ])
        #expect(block == [
            "```bash",
            "make build  # swift build",
            "make check  # SwiftLint + SwiftFormat",
            "a-much-longer-uncommented-command --flag",
            "```",
        ])
    }

    @Test
    func `check blurb follows the Makefile's check recipe`() {
        #expect(ProjectDocs.checkBlurb() == "SwiftLint + SwiftFormat")
        #expect(ProjectDocs.checkBlurb(hasLocalization: true) == "SwiftLint + SwiftFormat + strings audit")
        #expect(ProjectDocs.checkBlurb(hasAppIconValidation: true) == "SwiftLint + SwiftFormat + app icon validation")
    }

    @Test
    func `UIKit reaches dependents through internal edges and packageDeps`() {
        let config = PackageConfig(
            name: "MultiLib",
            platforms: [],
            targets: [
                TargetDefinition(name: "MultiLibCore", dependencies: []),
                TargetDefinition(name: "MultiLibUI", dependencies: ["MultiLibCore", "LumiKitUI"]),
                TargetDefinition(name: "MultiLibKit", dependencies: ["MultiLibUI"]),
                TargetDefinition(name: "MultiLibIso", dependencies: []),
            ],
            features: [.defaultIsolation],
            mainActorTargets: ["MultiLibIso"],
            author: "Test",
            licenseType: .mit
        )
        #expect(ProjectDocs.uikitTargets(config: config) == ["MultiLibUI", "MultiLibKit", "MultiLibIso"])
        #expect(ProjectDocs.uikitReason(config: config) == "MainActor-isolated target `MultiLibIso`; UIKit-only dependency `LumiKitUI`")

        let packageWide = PackageConfig(
            name: "MultiLib",
            platforms: [],
            targets: [TargetDefinition(name: "MultiLibCore", dependencies: [])],
            features: [],
            mainActorTargets: [],
            author: "Test",
            licenseType: .mit,
            packageDeps: ["LumiKitPhoto"]
        )
        #expect(ProjectDocs.uikitTargets(config: packageWide) == ["MultiLibCore"])
        #expect(ProjectDocs.xcodebuildScheme(for: packageWide) == "MultiLib-Package")
    }

    /// Without a Makefile, the raw `xcodebuild test` line runs serially by the
    /// same rule as the Makefile's test recipe and the test file's parent suite.
    @Test
    func `raw app test command serializes by the shared rule`() {
        func testCommand(_ features: Set<AppFeature>) -> String {
            let config = AppConfig(
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
            return ProjectDocs.appBuildCommands(config: config).last?.command ?? ""
        }
        #expect(testCommand([.coreData]).hasSuffix(" -quiet -parallel-testing-enabled NO"))
        #expect(testCommand([.swiftData, .cloudKit]).hasSuffix(" -quiet -parallel-testing-enabled NO"))
        #expect(testCommand([.swiftData]).hasSuffix(" -quiet"))
    }

    @Test
    func `SwiftPM commands follow dev tooling and the build system`() {
        #expect(ProjectDocs.swiftPMBuildCommands(hasDevTooling: false, xcodebuildScheme: nil).map(\.command) == ["swift build", "swift test"])
        #expect(ProjectDocs.swiftPMBuildCommands(hasDevTooling: true, xcodebuildScheme: "Pkg").map(\.command) == ["make build", "make test", "make check"])
        let raw = ProjectDocs.swiftPMBuildCommands(hasDevTooling: false, xcodebuildScheme: "Pkg").map(\.command)
        #expect(raw == ProjectDocs.xcodebuildCommands(scheme: "Pkg"))
        #expect(raw.allSatisfy { $0.contains("-scheme Pkg ") && $0.contains(" -quiet ") })
    }
}
