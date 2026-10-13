import Foundation
import Testing
@testable import MonolithLib

struct CoreDataGeneratorTests {
    private func makeConfig(name: String = "TestApp", lumiKit: Bool = false) -> AppConfig {
        AppConfig(
            name: name,
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: [.iPhone],
            projectSystem: .xcodeProj,
            tabs: [],
            primaryColor: "#007AFF",
            features: lumiKit ? [.coreData, .lumiKit] : [.coreData],
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
        // No shared store, no scope routing, no CloudKit import.
        #expect(!output.contains("databaseScope"))
        #expect(!output.contains("import CloudKit"))
        #expect(!output.contains("sharedDescription"))
        #expect(output.contains("privateDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: \"iCloud.com.test.app\")"))
    }

    /// Every CloudKit variant gets the opt-in gate, not only sharing: without
    /// it a signed test run mirrors test data into the developer's iCloud and
    /// an entitled container syncs from the first launch.
    @Test(arguments: [false, true])
    func `CloudKit stack gates sync behind an opt-in flag and the test host`(sharing: Bool) {
        let output = CoreDataGenerator.generateStack(config: makeConfig(), options: .init(cloudKit: true, sharing: sharing))
        #expect(output.contains("static let cloudKitEnabledKey = \"cloudKitSyncEnabled\""))
        #expect(output.contains("let isCloudKitEnabled: Bool"))
        #expect(output.contains("""
                let wantsCloudKit = !inMemory
                    && UserDefaults.standard.bool(forKey: Self.cloudKitEnabledKey)
                    && ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        """))
        // Sync off (or in-memory) clears the entitlement-derived options.
        #expect(output.contains("privateDescription.cloudKitContainerOptions = nil"))
        guard let gate = output.range(of: "if isCloudKitEnabled {"),
              let off = output.range(of: "privateDescription.cloudKitContainerOptions = nil")
        else {
            Issue.record("missing CloudKit gate")
            return
        }
        #expect(gate.lowerBound < off.lowerBound)
    }

    /// A save that races a CloudKit import throws NSManagedObjectMergeError
    /// without a merge policy, and the edit is lost.
    @Test(arguments: [false, true])
    func `CloudKit stack sets a merge policy and names the view context`(sharing: Bool) {
        let output = CoreDataGenerator.generateStack(config: makeConfig(), options: .init(cloudKit: true, sharing: sharing))
        #expect(output.contains("container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump"))
        #expect(output.contains("container.viewContext.name = \"viewContext\""))
        let local = CoreDataGenerator.generateStack(config: makeConfig(), options: .init())
        #expect(!local.contains("mergePolicy"))
        #expect(!local.contains("cloudKitEnabledKey"))
    }

    /// A failed CloudKit load must not crash-loop the app before the user can
    /// reach the sync setting: it logs and reloads local-only (same model, no
    /// options). Only the local load is fatal.
    @Test(arguments: [false, true])
    func `CloudKit load failure falls back to a local store`(lumiKit: Bool) {
        let output = CoreDataGenerator.generateStack(config: makeConfig(lumiKit: lumiKit), options: .init(cloudKit: true))
        #expect(output.contains("private static func makeLoadedContainer(inMemory: Bool, isCloudKitEnabled: Bool) -> (NSPersistentCloudKitContainer, Bool) {"))
        #expect(output.contains("let container = makeContainer(inMemory: inMemory, isCloudKitEnabled: true)"))
        #expect(output.contains("let container = makeContainer(inMemory: inMemory, isCloudKitEnabled: false)"))
        #expect(output.contains("fatalError(\"Failed to load persistent store: \\(error)\")"))
        if lumiKit {
            #expect(output.contains("import LumiKitCore"))
            #expect(output.contains("LMKLogger.error(\"CloudKit store failed to load; running local-only this launch\", error: error, category: LMKLogger.LogCategory.data)"))
        } else {
            #expect(output.contains("import os"))
            #expect(output.contains("Logger.app.error(\"CloudKit store failed to load; running local-only this launch: \\(String(describing: error), privacy: .private)\")"))
        }
        // The CloudKit attempt comes first; the local fallback after it.
        guard let attempt = output.range(of: "isCloudKitEnabled: true)"),
              let fallback = output.range(of: "isCloudKitEnabled: false)")
        else {
            Issue.record("missing fallback structure")
            return
        }
        #expect(attempt.lowerBound < fallback.lowerBound)
        // The load closure only records the failure; the caller picks fallback or crash.
        #expect(!output.contains("loadPersistentStores { _, error in\n            if let error {\n                fatalError"))
    }

    @Test
    func `local stack imports no logger`() {
        let output = CoreDataGenerator.generateStack(config: makeConfig(), options: .init())
        #expect(!output.contains("import os"))
        #expect(!output.contains("import LumiKitCore"))
        let imports = CoreDataGenerator.generateStack(config: makeConfig(), options: .init(cloudKit: true, sharing: true))
            .split(separator: "\n").filter { $0.hasPrefix("import ") }
        #expect(imports == imports.sorted { $0.lowercased() < $1.lowercased() })
    }

    // Regression: the dual-store stack must NOT force CloudKit on at launch.
    // NSPersistentCloudKitContainer traps in async NSCloudKitMirroringDelegate
    // setup when it can't reach the container (no entitlement under
    // CODE_SIGNING_ALLOWED=NO), so an always-on stack crashes the app host the
    // moment `make test` boots it. Sync is therefore gated behind an opt-in
    // UserDefaults flag that defaults off.
    @Test
    func `sharing stack gates CloudKit behind an opt-in UserDefaults flag`() {
        let output = CoreDataGenerator.generateStack(config: makeConfig(), options: .init(cloudKit: true, sharing: true))
        #expect(output.contains("static let cloudKitEnabledKey = \"cloudKitSyncEnabled\""))
        #expect(output.contains("let isCloudKitEnabled: Bool"))
        // CloudKit stores attach only inside the enabled branch; the disabled
        // branch is a single local store with options nil'd out.
        #expect(output.contains("if isCloudKitEnabled {"))
        #expect(output.contains("container.persistentStoreDescriptions = [privateDescription]"))
        // The dual-store assignment must live AFTER the gate, never before it.
        let gateIndex = output.range(of: "if isCloudKitEnabled {")?.lowerBound
        let dualStoreIndex = output.range(of: "[privateDescription, sharedDescription]")?.lowerBound
        #expect(gateIndex != nil && dualStoreIndex != nil)
        if let gateIndex, let dualStoreIndex {
            #expect(gateIndex < dualStoreIndex)
        }
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
        // No force-unwrap / force-cast: guards instead (the generated lint config warns on both).
        #expect(!output.contains("as! NSPersistentStoreDescription"))
        #expect(!output.contains(".url!"))
    }

    @Test
    func `stack name is derived from app name`() {
        let output = CoreDataGenerator.generateStack(config: makeConfig(name: "MyApp"), options: .init())
        #expect(output.contains("class MyAppCoreDataStack"))
        #expect(output.contains("static let shared = MyAppCoreDataStack"))
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

    // Regression: the app eagerly builds `.shared` at launch and tests build
    // `.inMemory()`, so two `NSPersistent*Container(name:)` calls would each load
    // a fresh NSManagedObjectModel and CoreData could no longer disambiguate
    // `+[SampleItem entity]` ("Failed to find a unique match"). Caching one model
    // and passing it to every container collapses that to a single model.
    @Test
    func `stack shares one cached managed object model across instances`() {
        for options in [CoreDataGenerator.Options(), .init(cloudKit: true), .init(cloudKit: true, sharing: true)] {
            let output = CoreDataGenerator.generateStack(config: makeConfig(name: "MyApp"), options: options)
            #expect(output.contains("private static let managedObjectModel: NSManagedObjectModel = {"))
            #expect(output.contains("Bundle.main.url(forResource: \"MyApp\", withExtension: \"momd\")"))
            // `Self.` is redundant inside the CloudKit stack's static factory.
            let sharesModel = output.contains("(name: \"MyApp\", managedObjectModel: Self.managedObjectModel)")
                || output.contains("(name: \"MyApp\", managedObjectModel: managedObjectModel)")
            #expect(sharesModel)
            // The bare no-model initializer must be gone (it's what double-loads).
            #expect(!output.contains("(name: \"MyApp\")"))
        }
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

    // Regression: the helpers reference the app module's internal `SampleItem`
    // and `<Name>CoreDataStack`, so they MUST `@testable import` the app or the
    // test target won't compile. The SwiftData generator does this; Core Data
    // had diverged and shipped without it (the empty default suite masked it).
    @Test
    func `helpers testable-import the app module`() {
        #expect(CoreDataGenerator.generateTestContext(config: makeConfig(name: "MyApp")).contains("@testable import MyApp"))
        #expect(CoreDataGenerator.generateTestDataFactory(config: makeConfig(name: "MyApp")).contains("@testable import MyApp"))
    }

    // MARK: - Shared store (CKShare)

    @Test
    func `sharing stack exposes a sharedStore accessor`() {
        let output = CoreDataGenerator.generateStack(config: makeConfig(), options: .init(cloudKit: true, sharing: true))
        #expect(output.contains("var sharedStore: NSPersistentStore?"))
        #expect(output.contains("\"shared.sqlite\""))
    }

    @Test
    func `non-sharing stack omits the sharedStore accessor`() {
        let plain = CoreDataGenerator.generateStack(config: makeConfig(), options: .init())
        let cloudOnly = CoreDataGenerator.generateStack(config: makeConfig(), options: .init(cloudKit: true, sharing: false))
        #expect(!plain.contains("var sharedStore"))
        #expect(!cloudOnly.contains("var sharedStore"))
    }
}
