import Foundation

/// Generates the SwiftData sample model (with `AppSchema`, the one list of
/// persisted model types) and the in-memory test helpers.
enum SwiftDataGenerator {
    /// `Core/Models/SampleItem.swift`: `AppSchema` plus the sample `@Model`.
    /// The app's container and the test container both build their schema
    /// from `AppSchema.models`, so registering a model is a one-line change.
    /// A CloudKit app's sample model follows CloudKit's schema rules (every
    /// attribute defaulted or optional), stated in its doc comment.
    static func generateSampleModel(config: AppConfig) -> String {
        let modelDoc = config.hasCloudKit
            ? """
            /// A placeholder model; replace it with your own.
            ///
            /// CloudKit sync puts rules on every synced model: each attribute is optional or
            /// has a default value, nothing is `@Attribute(.unique)`, every relationship is
            /// optional, and once the schema is deployed to Production, removing or renaming
            /// a stored property is unsafe (CloudKit keeps the old field).
            """
            : "/// A placeholder model; replace it with your own."
        let properties = config.hasCloudKit
            ? """
                var name: String = ""
                var createdAt: Date = Date.now
            """
            : """
                var name: String
                var createdAt: Date
            """
        return """
        import Foundation
        import SwiftData

        /// Every `@Model` type the app persists. The app's container and the test
        /// container both build their schema from this list.
        enum AppSchema {
            static var models: [any PersistentModel.Type] {
                [
                    SampleItem.self,
                ]
            }
        }

        \(modelDoc)
        @Model
        final class SampleItem {
        \(properties)

            init(name: String, createdAt: Date = .now) {
                self.name = name
                self.createdAt = createdAt
            }
        }

        """
    }

    static func generateTestContext(config: AppConfig) -> String {
        // `@testable import` is required because `SampleItem` and `AppSchema`
        // are `internal` (the default access level). Without it the test
        // bundle fails to compile with "cannot find 'SampleItem' in scope" as
        // soon as anything in the test target consumes the helper.
        """
        import Foundation
        import SwiftData
        @testable import \(config.name)

        /// In-memory ModelContainer for tests.
        enum TestContext {
            @MainActor
            static func makeContainer() throws -> ModelContainer {
                let schema = Schema(AppSchema.models)
                // Never synced: the default `.automatic` would mirror test data into the
                // developer's iCloud account on a signed run of a CloudKit app.
                let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
                return try ModelContainer(for: schema, configurations: [configuration])
            }
        }

        """
    }

    static func generateTestDataFactory(config: AppConfig) -> String {
        """
        import Foundation
        import SwiftData
        @testable import \(config.name)

        /// Factory for creating test data.
        @MainActor
        enum TestDataFactory {
            static func makeSampleItem(
                name: String = "Test Item",
                in context: ModelContext
            ) -> SampleItem {
                let item = SampleItem(name: name)
                context.insert(item)
                return item
            }
        }

        """
    }
}
