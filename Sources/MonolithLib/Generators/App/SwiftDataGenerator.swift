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
        """
        import Foundation
        import SwiftData

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
