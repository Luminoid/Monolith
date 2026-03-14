import Foundation
import Testing
@testable import MonolithLib

@Suite("SwiftDataGenerator")
struct SwiftDataGeneratorTests {
    private let config = AppConfig(
        name: "TestApp",
        bundleID: "com.test.app",
        deploymentTarget: "18.0",
        platforms: [.iPhone],
        projectSystem: .spm,
        tabs: [],
        primaryColor: "#007AFF",
        features: [.swiftData],
        author: "Test"
    )

    @Test("sample model has @Model and SwiftData import")
    func sampleModel() {
        let output = SwiftDataGenerator.generateSampleModel(config: config)
        #expect(output.contains("import SwiftData"))
        #expect(output.contains("@Model"))
        #expect(output.contains("final class SampleItem"))
        #expect(output.contains("var name: String"))
        #expect(output.contains("var createdAt: Date"))
    }

    @Test("test context creates in-memory container")
    func contextGenerator() {
        let output = SwiftDataGenerator.generateTestContext(config: config)
        #expect(output.contains("import SwiftData"))
        #expect(output.contains("enum TestContext"))
        #expect(output.contains("@MainActor"))
        #expect(output.contains("isStoredInMemoryOnly: true"))
        #expect(output.contains("SampleItem.self"))
    }

    @Test("test data factory is @MainActor")
    func dataFactory() {
        let output = SwiftDataGenerator.generateTestDataFactory(config: config)
        #expect(output.contains("@MainActor"))
        #expect(output.contains("enum TestDataFactory"))
        #expect(output.contains("makeSampleItem"))
        #expect(output.contains("context.insert(item)"))
    }
}
