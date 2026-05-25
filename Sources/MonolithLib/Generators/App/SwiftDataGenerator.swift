import Foundation

enum SwiftDataGenerator {
    static func generateSampleModel(config: AppConfig) -> String {
        """
        import Foundation
        import SwiftData

        @Model
        final class SampleItem {
            var name: String
            var createdAt: Date

            init(name: String, createdAt: Date = .now) {
                self.name = name
                self.createdAt = createdAt
            }
        }

        """
    }

    static func generateTestContext(config: AppConfig) -> String {
        // `@testable import` is required because `SampleItem` is `internal`
        // (the default access level for `@Model` types). Without it the test
        // bundle fails to compile with "cannot find 'SampleItem' in scope" as
        // soon as anything in the test target actually consumes the helper.
        // The previous scaffold shipped without the import and compiled only
        // because the test bundle's actual suite was empty — adding the
        // persistence demo test (or any real test using these helpers)
        // exposed the latent bug.
        """
        import Foundation
        import SwiftData
        @testable import \(config.name)

        /// In-memory ModelContainer for tests.
        enum TestContext {
            @MainActor
            static func makeContainer() throws -> ModelContainer {
                let schema = Schema([
                    SampleItem.self,
                ])
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                return try ModelContainer(for: schema, configurations: [config])
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
