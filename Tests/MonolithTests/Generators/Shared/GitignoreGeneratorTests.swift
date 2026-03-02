import Foundation
import Testing
@testable import MonolithLib

@Suite("GitignoreGenerator")
struct GitignoreGeneratorTests {

    @Test("base sections present for all project types")
    func baseSections() {
        for projectType in ProjectType.allCases {
            let output = GitignoreGenerator.generate(options: .init(projectType: projectType))
            #expect(output.contains("xcuserdata/"))
            #expect(output.contains(".build/"))
            #expect(output.contains(".DS_Store"))
            #expect(output.contains(".claude/settings.local.json"))
        }
    }

    @Test("app type includes Xcode specifics")
    func appSpecifics() {
        let output = GitignoreGenerator.generate(options: .init(projectType: .app))
        #expect(output.contains("timeline.xctimeline"))
        #expect(output.contains("playground.xcworkspace"))
    }

    @Test("package type includes SPM specifics")
    func packageSpecifics() {
        let output = GitignoreGenerator.generate(options: .init(projectType: .package))
        #expect(output.contains(".swiftpm/"))
        #expect(output.contains("*.xcscmblueprint"))
    }

    @Test("cli type has no extra sections")
    func cliNoExtras() {
        let output = GitignoreGenerator.generate(options: .init(projectType: .cli))
        #expect(!output.contains("timeline.xctimeline"))
        #expect(!output.contains(".swiftpm/"))
    }

    @Test("R.swift section included when enabled")
    func rSwiftSection() {
        let options = GitignoreGenerator.Options(projectType: .app, hasRSwift: true, appName: "MyApp")
        let output = GitignoreGenerator.generate(options: options)
        #expect(output.contains("MyApp/Generated/R.generated.swift"))
    }

    @Test("R.swift section absent when disabled")
    func noRSwiftSection() {
        let options = GitignoreGenerator.Options(projectType: .app, hasRSwift: false)
        let output = GitignoreGenerator.generate(options: options)
        #expect(!output.contains("R.generated.swift"))
    }

    @Test("Fastlane section included when enabled")
    func fastlaneSection() {
        let options = GitignoreGenerator.Options(projectType: .app, hasFastlane: true)
        let output = GitignoreGenerator.generate(options: options)
        #expect(output.contains("fastlane/report.xml"))
        #expect(output.contains("vendor/bundle/"))
    }

    @Test("Fastlane section absent when disabled")
    func noFastlaneSection() {
        let options = GitignoreGenerator.Options(projectType: .app, hasFastlane: false)
        let output = GitignoreGenerator.generate(options: options)
        #expect(!output.contains("fastlane/report.xml"))
    }

    @Test("both R.swift and Fastlane sections")
    func bothOptionalSections() {
        let options = GitignoreGenerator.Options(projectType: .app, hasRSwift: true, hasFastlane: true, appName: "TestApp")
        let output = GitignoreGenerator.generate(options: options)
        #expect(output.contains("TestApp/Generated/R.generated.swift"))
        #expect(output.contains("fastlane/report.xml"))
        #expect(output.contains("vendor/bundle/"))
    }
}
