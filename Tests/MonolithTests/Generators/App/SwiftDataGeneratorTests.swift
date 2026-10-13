import Foundation
import Testing
@testable import MonolithLib

struct SwiftDataGeneratorTests {
    private let config = Self.makeConfig()

    private static func makeConfig(cloudKit: Bool = false) -> AppConfig {
        AppConfig(
            name: "TestApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .xcodeProj,
            tabs: [],
            primaryColor: "#007AFF",
            features: cloudKit ? [.swiftData, .cloudKit] : [.swiftData],
            author: "Test",
            licenseType: .proprietary
        )
    }

    @Test
    func `sample model has @Model and SwiftData import`() {
        let output = SwiftDataGenerator.generateSampleModel(config: config)
        #expect(output.contains("import SwiftData"))
        #expect(output.contains("@Model"))
        #expect(output.contains("final class SampleItem"))
        #expect(output.contains("var name: String"))
        #expect(output.contains("var createdAt: Date"))
    }

    /// The app's container and the test container register the same models
    /// through one list declared next to the sample model.
    @Test
    func `sample model file declares the shared AppSchema list`() {
        let output = SwiftDataGenerator.generateSampleModel(config: config)
        #expect(output.contains("""
        enum AppSchema {
            static var models: [any PersistentModel.Type] {
                [
                    SampleItem.self,
                ]
            }
        }
        """))
    }

    /// CloudKit needs every attribute optional or defaulted; the doc comment
    /// states the rest of CloudKit's schema rules.
    @Test
    func `CloudKit sample model defaults every attribute and states the rules`() {
        let output = SwiftDataGenerator.generateSampleModel(config: Self.makeConfig(cloudKit: true))
        #expect(output.contains("    var name: String = \"\"\n"))
        #expect(output.contains("    var createdAt: Date = Date.now\n"))
        #expect(output.contains("@Attribute(.unique)"))
        #expect(output.contains("removing or renaming"))
        let local = SwiftDataGenerator.generateSampleModel(config: config)
        #expect(local.contains("    var name: String\n"))
        #expect(!local.contains("@Attribute(.unique)"))
    }

    @Test
    func `context creates in-memory container`() {
        let output = SwiftDataGenerator.generateTestContext(config: config)
        #expect(output.contains("import SwiftData"))
        #expect(output.contains("enum TestContext"))
        #expect(output.contains("@MainActor"))
        #expect(output.contains("isStoredInMemoryOnly: true"))
        #expect(output.contains("let schema = Schema(AppSchema.models)"))
    }

    /// The default `.automatic` would mirror test data into the developer's
    /// iCloud on a signed run of a CloudKit app.
    @Test
    func `container never syncs`() {
        let output = SwiftDataGenerator.generateTestContext(config: config)
        #expect(output.contains("ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)"))
    }

    /// SwiftFormat's `linebreakAtEndOfFile` fails a file without a trailing newline.
    @Test
    func `every generated file ends with a newline`() {
        for output in [
            SwiftDataGenerator.generateSampleModel(config: config),
            SwiftDataGenerator.generateTestContext(config: config),
            SwiftDataGenerator.generateTestDataFactory(config: config),
        ] {
            #expect(output.hasSuffix("}\n"))
        }
    }

    @Test
    func `data factory is @MainActor`() {
        let output = SwiftDataGenerator.generateTestDataFactory(config: config)
        #expect(output.contains("@MainActor"))
        #expect(output.contains("enum TestDataFactory"))
        #expect(output.contains("makeSampleItem"))
        #expect(output.contains("context.insert(item)"))
    }

    @Test
    func `helpers @testable import the app module`() {
        // `SampleItem` is internal (default access for @Model types), so the
        // test bundle needs `@testable import <AppName>` to see it. Previous
        // generator omitted this, but the absent test suite hid the bug — once
        // the persistence demo test referenced the helper for real, the build
        // broke with "cannot find 'SampleItem' in scope".
        let context = SwiftDataGenerator.generateTestContext(config: config)
        let factory = SwiftDataGenerator.generateTestDataFactory(config: config)
        #expect(context.contains("@testable import TestApp"))
        #expect(factory.contains("@testable import TestApp"))
    }
}
