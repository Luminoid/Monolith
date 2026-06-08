import Foundation

/// Generates Core Data scaffolding: `.xcdatamodeld` model bundle, a singleton
/// `CoreDataStack` (with optional `NSPersistentCloudKitContainer`), a sample
/// `NSManagedObject` subclass, and in-memory test helpers.
///
/// The CloudKit-backed variant follows Apple's recommended setup:
/// - shared singleton with private+shared databases when `cloudKit` is enabled
/// - `viewContext.automaticallyMergesChangesFromParent = true`
/// - silent push notifications enabled (caller must also register for remote
///   notifications and add `remote-notification` to `UIBackgroundModes`).
///
/// Apps that go to App Store must also audit their CloudKit Production schema
/// after every model change — see the optional Core Data audit reminder in
/// `GitHooksGenerator`.
enum CoreDataGenerator {
    struct Options {
        var cloudKit: Bool = false
        /// Emit the private + shared dual-store stack required for CKShare-based
        /// collaboration. Implies `cloudKit`. When false, a CloudKit stack syncs
        /// the private database only.
        var sharing: Bool = false
    }

    // MARK: - Model Bundle

    /// `.xcdatamodel/contents` XML — a minimal model with a single `SampleItem`
    /// entity. CloudKit-aware when `options.cloudKit` is true (entity flagged
    /// `usedWithCloudKit="YES"`).
    static func generateModelContents(options: Options) -> String {
        let cloudKitAttr = options.cloudKit ? " usedWithCloudKit=\"YES\"" : ""
        let modelFlag = options.cloudKit ? "YES" : "NO"
        let modelAttrs = "type=\"com.apple.IDECoreDataModeler.DataModel\""
            + " documentVersion=\"1.0\" lastSavedToolsVersion=\"22222\""
            + " systemVersion=\"24A335\" minimumToolsVersion=\"Automatic\""
            + " sourceLanguage=\"Swift\" usedWithCloudKit=\"\(modelFlag)\""
            + " userDefinedModelVersionIdentifier=\"\""
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <model \(modelAttrs)>
            <entity name="SampleItem" representedClassName="SampleItem" syncable="YES" codeGenerationType="class"\(cloudKitAttr)>
                <attribute name="id" optional="YES" attributeType="UUID" usesScalarValueType="NO"/>
                <attribute name="name" optional="YES" attributeType="String"/>
                <attribute name="createdAt" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
            </entity>
        </model>

        """
    }

    /// `.xccurrentversion` plist pointing at the initial model version.
    static func generateCurrentVersion(modelName: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>_XCCurrentVersionName</key>
            <string>\(modelName).xcdatamodel</string>
        </dict>
        </plist>

        """
    }

    // MARK: - Core Data Stack

    static func generateStack(config: AppConfig, options: Options) -> String {
        let stackName = "\(config.name)CoreDataStack"
        let modelName = config.name
        let containerType = options.cloudKit ? "NSPersistentCloudKitContainer" : "NSPersistentContainer"

        var lines: [String] = []
        // The shared-store path references CKDatabase.Scope (.private / .shared)
        // via NSPersistentCloudKitContainerOptions.databaseScope, which is only
        // visible with CloudKit imported. Kept alphabetical for SwiftFormat.
        if options.sharing {
            lines.append("import CloudKit")
        }
        lines.append("import CoreData")
        lines.append("import Foundation")
        lines.append("")
        lines.append("/// Core Data stack singleton.")
        if options.sharing {
            lines.append("/// CloudKit sync uses a private + shared database pair: the private store holds")
            lines.append("/// this user's own records; the shared store receives records others share via")
            lines.append("/// CKShare. The scene delegate's userDidAcceptCloudKitShareWith hook routes an")
            lines.append("/// accepted share into the shared store.")
        } else if options.cloudKit {
            lines.append("/// CloudKit sync uses the user's private database. Add a shared store description")
            lines.append("/// here if your app supports CKShare-based collaboration.")
        }
        // @MainActor is the lightest Swift 6.2 fix for the "static property
        // 'shared' is not concurrency-safe" diagnostic: a MainActor-isolated
        // class is implicitly Sendable, so its static let is concurrency-safe.
        // Matches Petfolio's PetCoreDataStack convention. NSManagedObjectContext
        // operations are already main-thread by default for the viewContext,
        // so this aligns the type's isolation with how it's actually used.
        lines.append("@MainActor")
        lines.append("final class \(stackName) {")
        lines.append("    static let shared = \(stackName)()")
        lines.append("")
        lines.append("    let container: \(containerType)")
        lines.append("")
        lines.append("    var viewContext: NSManagedObjectContext { container.viewContext }")
        lines.append("")
        lines.append("    private init(inMemory: Bool = false) {")
        lines.append("        container = \(containerType)(name: \"\(modelName)\")")
        lines.append("")
        if options.sharing {
            let containerID = "iCloud.\(config.bundleID)"
            lines.append("        guard let privateDescription = container.persistentStoreDescriptions.first else {")
            lines.append("            fatalError(\"No persistent store description found\")")
            lines.append("        }")
            lines.append("")
            lines.append("        if inMemory {")
            lines.append("            privateDescription.url = URL(fileURLWithPath: \"/dev/null\")")
            lines.append("            privateDescription.cloudKitContainerOptions = nil")
            lines.append("            container.persistentStoreDescriptions = [privateDescription]")
            lines.append("        } else {")
            lines.append("            // Private database: this user's own records.")
            lines.append("            let privateOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: \"\(containerID)\")")
            lines.append("            privateOptions.databaseScope = .private")
            lines.append("            privateDescription.cloudKitContainerOptions = privateOptions")
            lines.append("")
            lines.append("            // Shared database: records other users share with this user via CKShare.")
            lines.append("            guard let storeURL = privateDescription.url else {")
            lines.append("                fatalError(\"Private store description has no URL\")")
            lines.append("            }")
            lines.append("            let sharedURL = storeURL.deletingLastPathComponent().appendingPathComponent(\"shared.sqlite\")")
            lines.append("            let sharedDescription = NSPersistentStoreDescription(url: sharedURL)")
            lines.append("            let sharedOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: \"\(containerID)\")")
            lines.append("            sharedOptions.databaseScope = .shared")
            lines.append("            sharedDescription.cloudKitContainerOptions = sharedOptions")
            lines.append("")
            lines.append("            container.persistentStoreDescriptions = [privateDescription, sharedDescription]")
            lines.append("        }")
            lines.append("")
            lines.append("        // Enable history tracking + remote-change notifications (required for CloudKit).")
            lines.append("        for description in container.persistentStoreDescriptions {")
            lines.append("            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)")
            lines.append("            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)")
            lines.append("        }")
        } else {
            lines.append("        if inMemory, let description = container.persistentStoreDescriptions.first {")
            lines.append("            description.url = URL(fileURLWithPath: \"/dev/null\")")
            lines.append("        }")

            if options.cloudKit {
                lines.append("")
                lines.append("        // Enable history tracking + remote-change notifications (required for CloudKit).")
                lines.append("        for description in container.persistentStoreDescriptions {")
                lines.append("            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)")
                lines.append("            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)")
                lines.append("        }")
            }
        }

        lines.append("")
        lines.append("        container.loadPersistentStores { _, error in")
        lines.append("            if let error {")
        lines.append("                // Apple's sample code uses fatalError here. Crashing at load surfaces the")
        lines.append("                // real cause in crash reports; a silently-ignored load failure leaves the")
        lines.append("                // coordinator with zero stores, and every later save aborts far from the cause.")
        lines.append("                fatalError(\"Failed to load persistent store: \\(error)\")")
        lines.append("            }")
        lines.append("        }")
        lines.append("")
        lines.append("        container.viewContext.automaticallyMergesChangesFromParent = true")
        if options.sharing {
            lines.append("        // CloudKit sync is last-writer-wins; property-level object-trump keeps the")
            lines.append("        // most recent change per property when local and remote edits collide.")
            lines.append("        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump")
        }
        lines.append("    }")
        lines.append("")
        lines.append("    /// In-memory variant for tests.")
        lines.append("    static func inMemory() -> \(stackName) {")
        lines.append("        \(stackName)(inMemory: true)")
        lines.append("    }")
        lines.append("")
        lines.append("    func save() throws {")
        lines.append("        guard viewContext.hasChanges else { return }")
        lines.append("        try viewContext.save()")
        lines.append("    }")
        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    // MARK: - Test Helpers

    static func generateTestContext(config: AppConfig) -> String {
        let stackName = "\(config.name)CoreDataStack"
        // `inMemory()` is MainActor-isolated (its enclosing class is @MainActor),
        // so callers must be MainActor-isolated too. Mark the helper enum
        // @MainActor and tests will inherit the isolation — Swift Testing's
        // @Test methods that touch this stack should be @MainActor as well.
        return """
        import CoreData
        import Foundation

        /// In-memory Core Data stack for tests.
        @MainActor
        enum TestContext {
            static func makeStack() -> \(stackName) {
                \(stackName).inMemory()
            }
        }

        """
    }

    static func generateTestDataFactory(config: AppConfig) -> String {
        """
        import CoreData
        import Foundation

        /// Factory for creating test data.
        enum TestDataFactory {
            static func makeSampleItem(
                name: String = "Test Item",
                in context: NSManagedObjectContext
            ) -> SampleItem {
                let item = SampleItem(context: context)
                item.id = UUID()
                item.name = name
                item.createdAt = Date()
                return item
            }
        }

        """
    }
}
