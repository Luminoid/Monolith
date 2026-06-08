import Foundation
import Testing
@testable import MonolithLib

struct CoreDataGeneratorTests {
    private func makeConfig(name: String = "TestApp") -> AppConfig {
        AppConfig(
            name: name,
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .xcodeProj,
            tabs: [],
            primaryColor: "#007AFF",
            features: [.coreData],
            author: "Test",
            licenseType: .proprietary
        )
    }

    // MARK: - Model

    @Test
    func `model contents declares SampleItem entity`() {
        let output = CoreDataGenerator.generateModelContents(options: .init())
        #expect(output.contains("<entity name=\"SampleItem\""))
        #expect(output.contains("attributeType=\"UUID\""))
        #expect(output.contains("attributeType=\"String\""))
        #expect(output.contains("attributeType=\"Date\""))
    }

    @Test
    func `model flags entity as CloudKit-synced when cloudKit enabled`() {
        let withCK = CoreDataGenerator.generateModelContents(options: .init(cloudKit: true))
        #expect(withCK.contains("usedWithCloudKit=\"YES\""))

        let withoutCK = CoreDataGenerator.generateModelContents(options: .init(cloudKit: false))
        #expect(withoutCK.contains("usedWithCloudKit=\"NO\""))
    }

    @Test
    func `xccurrentversion points at named model`() {
        let output = CoreDataGenerator.generateCurrentVersion(modelName: "MyApp")
        #expect(output.contains("<string>MyApp.xcdatamodel</string>"))
    }

    // MARK: - Stack

    @Test
    func `stack uses NSPersistentContainer without CloudKit`() {
        let output = CoreDataGenerator.generateStack(config: makeConfig(), options: .init(cloudKit: false))
        #expect(output.contains("NSPersistentContainer"))
        #expect(!output.contains("NSPersistentCloudKitContainer"))
    }

    @Test
    func `stack uses NSPersistentCloudKitContainer with CloudKit`() {
        let output = CoreDataGenerator.generateStack(config: makeConfig(), options: .init(cloudKit: true))
        #expect(output.contains("NSPersistentCloudKitContainer"))
        // CloudKit requires history tracking + remote change notifications
        #expect(output.contains("NSPersistentHistoryTrackingKey"))
        #expect(output.contains("NSPersistentStoreRemoteChangeNotificationPostOptionKey"))
    }

    @Test
    func `non-sharing CloudKit stack stays single-store`() {
        let output = CoreDataGenerator.generateStack(config: makeConfig(), options: .init(cloudKit: true, sharing: false))
        // No shared store, no scope routing, no merge policy, no CloudKit import.
        #expect(!output.contains("databaseScope"))
        #expect(!output.contains("import CloudKit"))
        #expect(!output.contains("mergePolicy"))
    }

    @Test
    func `sharing stack emits private and shared dual-store with scope routing`() {
        let output = CoreDataGenerator.generateStack(config: makeConfig(), options: .init(cloudKit: true, sharing: true))
        // CloudKit must be imported so CKDatabase.Scope (.private/.shared) resolves.
        #expect(output.contains("import CloudKit"))
        // Both database scopes are configured on their own descriptions.
        #expect(output.contains("NSPersistentCloudKitContainerOptions(containerIdentifier: \"iCloud.com.test.app\")"))
        #expect(output.contains("privateOptions.databaseScope = .private"))
        #expect(output.contains("sharedOptions.databaseScope = .shared"))
        #expect(output.contains("container.persistentStoreDescriptions = [privateDescription, sharedDescription]"))
        // Conflict resolution is property-level object trump.
        #expect(output.contains("NSMergePolicy.mergeByPropertyObjectTrump"))
        // In-memory test path disables CloudKit on the single store.
        #expect(output.contains("privateDescription.cloudKitContainerOptions = nil"))
        // No force-unwrap / force-cast — guards instead (workspace lint rule).
        #expect(!output.contains("as! NSPersistentStoreDescription"))
        #expect(!output.contains(".url!"))
    }

    @Test
    func `stack name is derived from app name`() {
        let output = CoreDataGenerator.generateStack(config: makeConfig(name: "Petfolio"), options: .init())
        #expect(output.contains("class PetfolioCoreDataStack"))
        #expect(output.contains("static let shared = PetfolioCoreDataStack"))
    }

    @Test
    func `stack provides in-memory variant for tests`() {
        let output = CoreDataGenerator.generateStack(config: makeConfig(), options: .init())
        #expect(output.contains("static func inMemory()"))
        #expect(output.contains("/dev/null"))
    }

    @Test
    func `load failure is fatal per Apple guidance`() {
        let output = CoreDataGenerator.generateStack(config: makeConfig(), options: .init())
        #expect(output.contains("fatalError"))
    }

    // MARK: - Test helpers

    @Test
    func `context wraps the in-memory stack`() {
        let output = CoreDataGenerator.generateTestContext(config: makeConfig(name: "MyApp"))
        #expect(output.contains("MyAppCoreDataStack.inMemory()"))
    }

    @Test
    func `data factory inserts SampleItem`() {
        let output = CoreDataGenerator.generateTestDataFactory(config: makeConfig())
        #expect(output.contains("SampleItem(context: context)"))
        #expect(output.contains("item.id = UUID()"))
    }
}
