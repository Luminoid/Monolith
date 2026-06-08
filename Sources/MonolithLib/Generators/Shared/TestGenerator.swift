import Foundation

enum TestGenerator {
    /// Generate a Swift Testing test file with @testable import.
    ///
    /// Emits an empty `@Suite` struct rather than a `placeholder()` test that
    /// asserts `Bool(true) == true` — content-free tests inflate the test
    /// count without contributing signal and trick adopters into thinking
    /// coverage exists. The empty body is itself the prompt to write the
    /// first real test; no reminder-comment line is needed (SwiftLint's
    /// `todo` rule is on by default in the generated config, so any such
    /// comment would fail `make check` on the first run of a freshly
    /// scaffolded package).
    static func generate(suiteName: String, targetName: String) -> String {
        """
        import Foundation
        import Testing
        @testable import \(targetName)

        @Suite("\(suiteName)")
        struct \(suiteName)Tests {}

        """
    }

    /// Which persistence helpers the app-test demo should exercise.
    ///
    /// The SwiftData and Core Data scaffolds generate different `TestContext` /
    /// `TestDataFactory` shapes (`ModelContainer` vs `NSPersistentContainer`),
    /// so the demo body must match the chosen layer. `.none` emits an empty
    /// suite (non-persistence apps).
    enum PersistenceDemo {
        case none
        case swiftData
        case coreData
    }

    /// Generate the app test target's suite file.
    ///
    /// When `persistence` is `.swiftData` or `.coreData`, emits one example test
    /// that exercises the generated `TestContext` + `TestDataFactory` helpers.
    /// This gives the scaffold a green test signal out of the box and tells
    /// adopters how the helpers are intended to compose. Without a demo,
    /// `make test` runs an empty suite and the helpers exist as unreferenced
    /// dead code waiting for a future first test.
    ///
    /// Both demo variants add `@testable import <AppName>` so `SampleItem` (and
    /// adopters' future internal model types) resolve in the test bundle.
    static func generateAppTest(suiteName: String, persistence: PersistenceDemo = .none) -> String {
        switch persistence {
        case .swiftData:
            """
            import Foundation
            import SwiftData
            import Testing
            @testable import \(suiteName)

            @MainActor
            @Suite("\(suiteName)")
            struct \(suiteName)Tests {
                /// Demonstrates the in-memory `ModelContainer` test pattern. Replace
                /// `SampleItem` with your real domain model and delete this test once
                /// you've written your first real one — the helper APIs are the part
                /// to keep.
                @Test
                func `SampleItem can be inserted and fetched`() throws {
                    let container = try TestContext.makeContainer()
                    let context = ModelContext(container)
                    _ = TestDataFactory.makeSampleItem(name: "Demo", in: context)
                    try context.save()

                    let fetched = try context.fetch(FetchDescriptor<SampleItem>())
                    #expect(fetched.count == 1)
                    #expect(fetched.first?.name == "Demo")
                }
            }

            """
        case .coreData:
            """
            import CoreData
            import Testing
            @testable import \(suiteName)

            @MainActor
            @Suite("\(suiteName)")
            struct \(suiteName)Tests {
                /// Demonstrates the in-memory Core Data stack test pattern. Replace
                /// `SampleItem` with your real domain model and delete this test once
                /// you've written your first real one — the helper APIs are the part
                /// to keep.
                @Test
                func `SampleItem can be inserted and fetched`() throws {
                    let stack = TestContext.makeStack()
                    let context = stack.viewContext
                    _ = TestDataFactory.makeSampleItem(name: "Demo", in: context)
                    try stack.save()

                    let request = NSFetchRequest<SampleItem>(entityName: "SampleItem")
                    let fetched = try context.fetch(request)
                    #expect(fetched.count == 1)
                    #expect(fetched.first?.name == "Demo")
                }
            }

            """
        case .none:
            """
            import Foundation
            import Testing

            @Suite("\(suiteName)")
            struct \(suiteName)Tests {}

            """
        }
    }
}
