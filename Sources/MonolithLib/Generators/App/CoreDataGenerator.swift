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
        let containerType = options.cloudKit ? "NSPersistentCloudKitContainer" : "NSPersistentContainer"

        var lines: [String] = []
        // The shared-store path references CKDatabase.Scope (.private / .shared)
        // via NSPersistentCloudKitContainerOptions.databaseScope, which is only
        // visible with CloudKit imported. The CloudKit fallback logs through
        // LMKLogger (LumiKitCore) or `Logger.app` (os). Sorted the way
        // SwiftFormat's case-insensitive `sortImports` orders them.
        if options.sharing {
            lines.append("import CloudKit")
        }
        lines.append("import CoreData")
        lines.append("import Foundation")
        if options.cloudKit {
            lines.append(config.hasLumiKit ? "import LumiKitCore" : "import os")
        }
        lines.append("")
        lines.append("/// Core Data stack singleton.")
        if options.sharing {
            lines.append("/// CloudKit sync uses a private + shared database pair: the private store holds")
            lines.append("/// this user's own records; the shared store receives records others share via")
            lines.append("/// CKShare. The scene delegate's share-acceptance path routes an accepted share")
            lines.append("/// into the shared store.")
        } else if options.cloudKit {
            lines.append("/// CloudKit sync uses the user's private database. Add a shared store description")
            lines.append("/// in `makeContainer` if your app supports CKShare-based collaboration.")
        }
        // @MainActor is the lightest Swift 6.2 fix for the "static property
        // 'shared' is not concurrency-safe" diagnostic: a MainActor-isolated
        // class is implicitly Sendable, so its static let is concurrency-safe.
        // NSManagedObjectContext operations are already main-thread by default
        // for the viewContext, so this aligns the type's isolation with how
        // it's actually used.
        lines.append("@MainActor")
        lines.append("final class \(stackName) {")
        lines.append("    static let shared = \(stackName)()")
        if options.cloudKit {
            lines.append("""

                /// UserDefaults key gating CloudKit sync. Sync is opt-in: the scaffold
                /// ships with it off so the app launches (and `make test` passes) without
                /// a CloudKit entitlement or a signed-in iCloud account.
                /// NSPersistentCloudKitContainer traps during async mirroring setup when
                /// it cannot reach the container, so forcing CloudKit on at first launch
                /// crashes every unsigned or CI run. Flip this from a Settings toggle,
                /// then call exit(0) so the stack reconfigures on next launch; the
                /// container cannot switch CloudKit on or off at runtime.
                static let cloudKitEnabledKey = "cloudKitSyncEnabled"
            """)
        }
        lines.append("")
        lines.append("    let container: \(containerType)")
        if options.cloudKit {
            lines.append("    /// Whether this launch syncs: the preference, except in-memory stacks, app-hosted")
            lines.append("    /// test runs, and a launch whose CloudKit store failed to load.")
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
            // callback. The "shared.sqlite" name is emitted in `makeContainer`.
            lines.append("    /// The CloudKit shared-database store, present only while sync is on. Destination")
            lines.append("    /// for `acceptShareInvitations(from:into:)` when a user accepts a CKShare.")
            lines.append("    var sharedStore: NSPersistentStore? {")
            lines.append("        container.persistentStoreCoordinator.persistentStores.first {")
            lines.append("            $0.url?.lastPathComponent == \"shared.sqlite\"")
            lines.append("        }")
            lines.append("    }")
            lines.append("")
        }
        lines.append(managedObjectModel(modelName: config.name, containerType: containerType))
        lines.append("")
        if options.cloudKit {
            lines.append(cloudKitInit)
        } else {
            lines.append(localInit(modelName: config.name))
        }
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
        if options.cloudKit {
            lines.addMark("Loading")
            lines.append(cloudKitLoading(config: config, options: options))
        }
        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    /// One process-wide model, shared by every container the stack builds.
    private static func managedObjectModel(modelName: String, containerType: String) -> String {
        """
            /// One process-wide NSManagedObjectModel passed to every container
            /// instance. \(containerType)(name:) loads a fresh model from the
            /// bundle on each call, so the app's `.shared` stack plus a test's
            /// `.inMemory()` stack would register two copies of every entity against
            /// the same NSManagedObject subclasses, and CoreData can no longer
            /// resolve `+[SampleItem entity]` ("Failed to find a unique match for an
            /// NSEntityDescription"). Loading once and sharing it avoids that.
            private static let managedObjectModel: NSManagedObjectModel = {
                guard let url = Bundle.main.url(forResource: "\(modelName)", withExtension: "momd"),
                      let model = NSManagedObjectModel(contentsOf: url)
                else {
                    fatalError("Failed to load Core Data model '\(modelName).momd'")
                }
                return model
            }()
        """
    }

    /// The local-only stack's initializer: one store, fatal on a load failure.
    private static func localInit(modelName: String) -> String {
        """
            private init(inMemory: Bool = false) {
                container = NSPersistentContainer(name: "\(modelName)", managedObjectModel: Self.managedObjectModel)

                if inMemory, let description = container.persistentStoreDescriptions.first {
                    description.url = URL(fileURLWithPath: "/dev/null")
                }

                container.loadPersistentStores { _, error in
                    if let error {
                        // Apple's sample code uses fatalError here. Crashing at load surfaces the
                        // real cause in crash reports; a silently-ignored load failure leaves the
                        // coordinator with zero stores, and every later save aborts far from the cause.
                        fatalError("Failed to load persistent store: \\(error)")
                    }
                }

                container.viewContext.automaticallyMergesChangesFromParent = true
            }
        """
    }

    /// The CloudKit stack's initializer. Sync is opt-in, never on for an
    /// in-memory stack or an app-hosted test run, and a merge policy resolves
    /// a save that races a CloudKit import (without one that save throws
    /// `NSManagedObjectMergeError` and the edit is lost).
    private static let cloudKitInit = """
        private init(inMemory: Bool = false) {
            // CloudKit sync is opt-in (see cloudKitEnabledKey). In-memory stacks and
            // app-hosted test runs never sync: an unsigned test host has no CloudKit
            // entitlement (mirroring setup traps when it can't reach the container),
            // and a signed one would mirror test data into the developer's iCloud.
            let wantsCloudKit = !inMemory
                && UserDefaults.standard.bool(forKey: Self.cloudKitEnabledKey)
                && ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
            let (container, loadedWithCloudKit) = Self.makeLoadedContainer(inMemory: inMemory, isCloudKitEnabled: wantsCloudKit)
            self.container = container
            isCloudKitEnabled = loadedWithCloudKit

            container.viewContext.automaticallyMergesChangesFromParent = true
            container.viewContext.name = "viewContext"
            // CloudKit sync is last-writer-wins; property-level object-trump keeps the
            // most recent change per property when a local save races an import.
            container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        }
    """

    /// `makeLoadedContainer`, `makeContainer`, and `loadStores`: the CloudKit
    /// stack's construction, with a local-only fallback for a failed CloudKit
    /// load.
    private static func cloudKitLoading(config: AppConfig, options: Options) -> String {
        let containerID = "iCloud.\(config.bundleID)"
        let fallbackLog = AppDelegateGenerator.logError(
            "CloudKit store failed to load; running local-only this launch",
            category: .data,
            config: config
        )
        let cloudKitStores = options.sharing
            ? """
                        // Private database: this user's own records.
                        let privateOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "\(containerID)")
                        privateOptions.databaseScope = .private
                        privateDescription.cloudKitContainerOptions = privateOptions

                        // Shared database: records other users share with this user via CKShare.
                        guard let storeURL = privateDescription.url else {
                            fatalError("Private store description has no URL")
                        }
                        let sharedURL = storeURL.deletingLastPathComponent().appendingPathComponent("shared.sqlite")
                        let sharedDescription = NSPersistentStoreDescription(url: sharedURL)
                        sharedDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                        sharedDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                        let sharedOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "\(containerID)")
                        sharedOptions.databaseScope = .shared
                        sharedDescription.cloudKitContainerOptions = sharedOptions

                        container.persistentStoreDescriptions = [privateDescription, sharedDescription]
            """
            : """
                        // Private database: this user's own records.
                        privateDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "\(containerID)")
            """
        let localStores = options.sharing
            ? """
                        privateDescription.cloudKitContainerOptions = nil
                        container.persistentStoreDescriptions = [privateDescription]
            """
            : """
                        privateDescription.cloudKitContainerOptions = nil
            """
        return """
            /// Builds and loads the container. When the CloudKit-configured load fails, the
            /// stack logs it and runs local-only for this launch (same model, no
            /// `cloudKitContainerOptions`): a crash there would repeat on every launch, before
            /// the user could reach the sync setting. The preference stays on, so the next
            /// launch retries. A local load failure is fatal: Apple's sample code uses
            /// fatalError, and a silently-ignored failure leaves the coordinator with zero
            /// stores, so every later save aborts far from the cause.
            private static func makeLoadedContainer(inMemory: Bool, isCloudKitEnabled: Bool) -> (NSPersistentCloudKitContainer, Bool) {
                if isCloudKitEnabled {
                    let container = makeContainer(inMemory: inMemory, isCloudKitEnabled: true)
                    if let error = loadStores(in: container) {
                        \(fallbackLog)
                    } else {
                        return (container, true)
                    }
                }
                let container = makeContainer(inMemory: inMemory, isCloudKitEnabled: false)
                if let error = loadStores(in: container) {
                    fatalError("Failed to load persistent store: \\(error)")
                }
                return (container, false)
            }

            private static func makeContainer(inMemory: Bool, isCloudKitEnabled: Bool) -> NSPersistentCloudKitContainer {
                let container = NSPersistentCloudKitContainer(name: "\(config.name)", managedObjectModel: managedObjectModel)
                guard let privateDescription = container.persistentStoreDescriptions.first else {
                    fatalError("No persistent store description found")
                }
                if inMemory {
                    privateDescription.url = URL(fileURLWithPath: "/dev/null")
                }
                // History tracking + remote-change notifications: required for CloudKit, and
                // set with sync off too so the store is ready when sync is turned on.
                privateDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                privateDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

                if isCloudKitEnabled {
        \(cloudKitStores)
                } else {
                    // Sync off (or in-memory): a local store with no mirroring. Clearing the
                    // options matters: an entitled app's container otherwise derives them from
                    // the entitlement and syncs anyway.
        \(localStores)
                }
                return container
            }

            /// Loads every configured store and returns the first failure (the handler runs
            /// once per store, synchronously for SQLite stores).
            private static func loadStores(in container: NSPersistentCloudKitContainer) -> (any Error)? {
                var failure: (any Error)?
                container.loadPersistentStores { _, error in
                    if let error, failure == nil {
                        failure = error
                    }
                }
                return failure
            }
        """
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
