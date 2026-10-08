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

    /// Whether an app's tests run one at a time: Core Data, whose stack is a
    /// process-wide `.shared` singleton in every variant, or SwiftData that
    /// syncs through CloudKit. One rule for both switches, so they never
    /// disagree: the generated test file's `.serialized` parent suite and the
    /// Makefile's `-parallel-testing-enabled NO`. Plain SwiftData gives each
    /// test its own in-memory `ModelContainer`, so it keeps the parallel run.
    static func appTestsRunSerially(config: AppConfig) -> Bool {
        config.hasCoreData || (config.hasSwiftData && config.hasCloudKit)
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
    ///
    /// With `serialized` (default: Core Data, whose stack is a `.shared`
    /// singleton in every variant; the app generator passes
    /// `appTestsRunSerially(config:)`), the demo suite nests under a parent
    /// `@Suite(.serialized) enum <App>TestSuite`. `.serialized` orders only the
    /// suite it is attached to and the suites nested inside it, so top-level
    /// suites would still run in parallel and race on the singleton; nesting
    /// every suite under one parent runs them one at a time.
    static func generateAppTest(suiteName: String, persistence: PersistenceDemo = .none, serialized: Bool? = nil) -> String {
        let demo: (imports: String, body: String)
        switch persistence {
        case .swiftData:
            demo = (
                "import Foundation\nimport SwiftData",
                """
                /// Demonstrates the in-memory `ModelContainer` test pattern. Replace
                /// `SampleItem` with your real domain model and delete this test once
                /// you've written your first real one; the helper APIs are the part
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
                """
            )
        case .coreData:
            demo = (
                "import CoreData",
                """
                /// Demonstrates the in-memory Core Data stack test pattern. Replace
                /// `SampleItem` with your real domain model and delete this test once
                /// you've written your first real one; the helper APIs are the part
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
                """
            )
        case .none:
            return """
            import Foundation
            import Testing

            @Suite("\(suiteName)")
            struct \(suiteName)Tests {}

            """
        }

        let isSerialized = serialized ?? (persistence == .coreData)
        guard isSerialized else {
            return """
            \(demo.imports)
            import Testing
            @testable import \(suiteName)

            @MainActor
            @Suite("\(suiteName)")
            struct \(suiteName)Tests {
            \(indented(demo.body, by: 4))
            }

            """
        }
        return """
        \(demo.imports)
        import Testing
        @testable import \(suiteName)

        /// Every app test suite nests under this one, which runs them one at a time: the
        /// suites share the app's persistence state, and suites running in parallel would
        /// race on it. Add a suite as `extension \(suiteName)TestSuite { @MainActor struct
        /// FeatureTests { ... } }`; `.serialized` reaches every suite nested here.
        @Suite(.serialized)
        enum \(suiteName)TestSuite {}

        extension \(suiteName)TestSuite {
            @MainActor
            @Suite("\(suiteName)")
            struct \(suiteName)Tests {
        \(indented(demo.body, by: 8))
            }
        }

        """
    }

    /// `text` with every non-empty line indented by `spaces`.
    private static func indented(_ text: String, by spaces: Int) -> String {
        let prefix = String(repeating: " ", count: spaces)
        return text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.isEmpty ? "" : prefix + $0 }
            .joined(separator: "\n")
    }
}
