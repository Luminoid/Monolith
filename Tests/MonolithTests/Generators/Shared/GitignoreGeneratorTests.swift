import Foundation
import Testing
@testable import MonolithLib

struct GitignoreGeneratorTests {
    @Test
    func `base sections present for all project types`() {
        for projectType in ProjectType.allCases {
            let output = GitignoreGenerator.generate(options: .init(projectType: projectType))
            #expect(output.contains("xcuserdata/"))
            #expect(output.contains(".build/"))
            #expect(output.contains(".DS_Store"))
            #expect(output.contains(".claude/settings.local.json"))
        }
    }

    @Test
    func `editor and IDE artifacts ignored for all project types`() {
        // Adopters increasingly use non-Xcode editors (VSCode/SweetPad,
        // JetBrains AppCode, Cursor). The default should tolerate them.
        for projectType in ProjectType.allCases {
            let output = GitignoreGenerator.generate(options: .init(projectType: projectType))
            #expect(output.contains(".vscode/"))
            #expect(output.contains(".idea/"))
            #expect(output.contains("*.iml"))
            // SweetPad / xcode-build-server config file.
            #expect(output.contains("buildServer.json"))
        }
    }

    @Test
    func `coverage and log artifacts ignored for all project types`() {
        for projectType in ProjectType.allCases {
            let output = GitignoreGenerator.generate(options: .init(projectType: projectType))
            #expect(output.contains("*.profraw"))
            #expect(output.contains("*.profdata"))
            #expect(output.contains("*.log"))
        }
    }

    @Test
    func `app type includes Xcode specifics`() {
        let output = GitignoreGenerator.generate(options: .init(projectType: .app))
        #expect(output.contains("timeline.xctimeline"))
        #expect(output.contains("playground.xcworkspace"))
    }

    @Test
    func `package type includes SPM specifics`() {
        let output = GitignoreGenerator.generate(options: .init(projectType: .package))
        #expect(output.contains(".swiftpm/"))
        #expect(output.contains("*.xcscmblueprint"))
        #expect(output.contains("Package.resolved"))
    }

    @Test
    func `package type has no duplicate section headers`() {
        let output = GitignoreGenerator.generate(options: .init(projectType: .package))
        let lines = output.components(separatedBy: "\n")
        let xcodeHeaders = lines.filter { $0.hasPrefix("# Xcode") }
        let spmHeaders = lines.filter { $0.hasPrefix("# Swift Package Manager") }
        #expect(xcodeHeaders.count == 1)
        #expect(spmHeaders.count == 1)
    }

    @Test
    func `cli type has no extra sections`() {
        // `.swiftpm/` is now in every gitignore (Xcode 16's local-package
        // configuration lands there regardless of project type — even CLIs
        // open in Xcode for debugging). `Package.resolved` is still package-
        // only (apps commit it for reproducible CI; CLIs / libraries leave
        // resolution to consumers).
        let output = GitignoreGenerator.generate(options: .init(projectType: .cli))
        #expect(!output.contains("timeline.xctimeline"))
        #expect(!output.contains("Package.resolved"))
    }

    @Test
    func `swiftpm directory is gitignored across all project types`() {
        for type in [ProjectType.app, .package, .cli] {
            let output = GitignoreGenerator.generate(options: .init(projectType: type))
            #expect(output.contains(".swiftpm/"), "expected .swiftpm/ in \(type) gitignore")
        }
    }

    @Test
    func `R.swift section included when enabled`() {
        let options = GitignoreGenerator.Options(projectType: .app, hasRSwift: true, appName: "MyApp")
        let output = GitignoreGenerator.generate(options: options)
        #expect(output.contains("MyApp/Generated/R.generated.swift"))
    }

    @Test
    func `R.swift section absent when disabled`() {
        let options = GitignoreGenerator.Options(projectType: .app, hasRSwift: false)
        let output = GitignoreGenerator.generate(options: options)
        #expect(!output.contains("R.generated.swift"))
    }

    @Test
    func `Fastlane section included when enabled`() {
        let options = GitignoreGenerator.Options(projectType: .app, hasFastlane: true)
        let output = GitignoreGenerator.generate(options: options)
        #expect(output.contains("fastlane/report.xml"))
        #expect(output.contains("vendor/bundle/"))
    }

    @Test
    func `Fastlane section absent when disabled`() {
        let options = GitignoreGenerator.Options(projectType: .app, hasFastlane: false)
        let output = GitignoreGenerator.generate(options: options)
        #expect(!output.contains("fastlane/report.xml"))
    }

    @Test
    func `both R.swift and Fastlane sections`() {
        let options = GitignoreGenerator.Options(projectType: .app, hasRSwift: true, hasFastlane: true, appName: "TestApp")
        let output = GitignoreGenerator.generate(options: options)
        #expect(output.contains("TestApp/Generated/R.generated.swift"))
        #expect(output.contains("fastlane/report.xml"))
        #expect(output.contains("vendor/bundle/"))
    }
}
