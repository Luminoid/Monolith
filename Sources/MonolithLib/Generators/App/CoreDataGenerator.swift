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
        if options.sharing {
            lines.append("")
            lines.append("    /// UserDefaults key gating CloudKit sync. Sync is opt-in: the scaffold")
            lines.append("    /// ships with it off so the app launches (and `make test` passes) without")
            lines.append("    /// a CloudKit entitlement or a signed-in iCloud account.")
            lines.append("    /// NSPersistentCloudKitContainer traps during async mirroring setup when")
            lines.append("    /// it cannot reach the container, so forcing CloudKit on at first launch")
            lines.append("    /// crashes every unsigned or CI run. Flip this from a Settings toggle,")
            lines.append("    /// then call exit(0) so the stack reconfigures on next launch; the")
            lines.append("    /// container cannot switch CloudKit on or off at runtime.")
            lines.append("    static let cloudKitEnabledKey = \"cloudKitSyncEnabled\"")
        }
        lines.append("")
        lines.append("    let container: \(containerType)")
        if options.sharing {
            lines.append("    let isCloudKitEnabled: Bool")
        }
        lines.append("")
        lines.append("    var viewContext: NSManagedObjectContext { container.viewContext }")
        lines.append("")
        if options.sharing {
            // The destination store for `acceptShareInvitations(from:into:)`.
            // Matched by filename rather than by databaseScope: NSPersistentStore
            // doesn't expose its scope, and capturing it in the loadPersistentStores
            // completion would mutate MainActor state from a possibly-background
            // callback. The "shared.sqlite" name is emitted just above.
            lines.append("    /// The CloudKit shared-database store. Destination for")
            lines.append("    /// `acceptShareInvitations(from:into:)` when a user accepts a CKShare.")
            lines.append("    var sharedStore: NSPersistentStore? {")
            lines.append("        container.persistentStoreCoordinator.persistentStores.first {")
            lines.append("            $0.url?.lastPathComponent == \"shared.sqlite\"")
            lines.append("        }")
            lines.append("    }")
            lines.append("")
        }
        lines.append("    /// One process-wide NSManagedObjectModel passed to every container")
        lines.append("    /// instance. \(containerType)(name:) loads a fresh model from the")
        lines.append("    /// bundle on each call, so the app's `.shared` stack plus a test's")
        lines.append("    /// `.inMemory()` stack would register two copies of every entity against")
        lines.append("    /// the same NSManagedObject subclasses, and CoreData can no longer")
        lines.append("    /// resolve `+[SampleItem entity]` (\"Failed to find a unique match for an")
        lines.append("    /// NSEntityDescription\"). Loading once and sharing it avoids that.")
        lines.append("    private static let managedObjectModel: NSManagedObjectModel = {")
        lines.append("        guard let url = Bundle.main.url(forResource: \"\(modelName)\", withExtension: \"momd\"),")
        lines.append("              let model = NSManagedObjectModel(contentsOf: url)")
        lines.append("        else {")
        lines.append("            fatalError(\"Failed to load Core Data model '\(modelName).momd'\")")
        lines.append("        }")
        lines.append("        return model")
        lines.append("    }()")
        lines.append("")
        lines.append("    private init(inMemory: Bool = false) {")
        if options.sharing {
            lines.append("        // CloudKit sync is opt-in (see cloudKitEnabledKey); in-memory test")
            lines.append("        // stacks never sync.")
            lines.append("        isCloudKitEnabled = !inMemory && UserDefaults.standard.bool(forKey: Self.cloudKitEnabledKey)")
        }
        lines.append("        container = \(containerType)(name: \"\(modelName)\", managedObjectModel: Self.managedObjectModel)")
        lines.append("")
        if options.sharing {
            let containerID = "iCloud.\(config.bundleID)"
            lines.append("        guard let privateDescription = container.persistentStoreDescriptions.first else {")
            lines.append("            fatalError(\"No persistent store description found\")")
            lines.append("        }")
            lines.append("")
            lines.append("        if isCloudKitEnabled {")
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
            lines.append("        } else {")
            lines.append("            // CloudKit off (or in-memory tests): a single local store with no")
            lines.append("            // mirroring. An NSPersistentCloudKitContainer with no")
            lines.append("            // cloudKitContainerOptions behaves like a plain local container, so")
            lines.append("            // the app runs without a CloudKit entitlement.")
            lines.append("            if inMemory {")
            lines.append("                privateDescription.url = URL(fileURLWithPath: \"/dev/null\")")
            lines.append("            }")
            lines.append("            privateDescription.cloudKitContainerOptions = nil")
            lines.append("            container.persistentStoreDescriptions = [privateDescription]")
            lines.append("        }")
            lines.append("")
            lines.append("        // Enable history tracking + remote-change notifications (required for CloudKit;")
            lines.append("        // harmless and forward-compatible when sync is off).")
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
        @testable import \(config.name)

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
        @testable import \(config.name)

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
