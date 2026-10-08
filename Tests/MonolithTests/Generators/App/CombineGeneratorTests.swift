import Foundation
import Testing
@testable import MonolithLib

struct CombineGeneratorTests {
    @Test
    func `AsyncService has task cancellation pattern`() {
        let output = CombineGenerator.generateAsyncService()
        #expect(output.contains("private var activeTasks: [UUID: Task<Void, Never>] = [:]"))
        #expect(output.contains("cancelAll()"))
        #expect(output.contains("deinit"))
    }

    @Test
    func `AsyncService tasks remove their own entry when they finish`() {
        // Finished tasks must not accumulate until the next cancelAll().
        let output = CombineGenerator.generateAsyncService()
        #expect(output.contains("""
                activeTasks[id] = Task { [weak self] in
                    await work()
                    self?.activeTasks[id] = nil
                }
        """))
    }

    @Test
    func `AsyncService loop bodies sit on their own lines`() {
        // SwiftFormat's wrapLoopBodies rewrites `for x in y { x.cancel() }`, so a
        // one-line loop fails `swiftformat --lint` in the generated project.
        let output = CombineGenerator.generateAsyncService()
        #expect(!output.contains("{ task.cancel() }"))
        #expect(output.components(separatedBy: "for task in activeTasks.values {\n            task.cancel()\n        }").count - 1 == 2)
    }

    @Test
    func `AsyncService is @MainActor`() {
        let output = CombineGenerator.generateAsyncService()
        #expect(output.contains("@MainActor"))
    }

    @Test
    func `AsyncService has Properties and Actions MARK sections`() {
        let service = CombineGenerator.generateAsyncService()
        #expect(service.contains("// MARK: - Properties"))
        #expect(service.contains("// MARK: - Actions"))
    }
}
