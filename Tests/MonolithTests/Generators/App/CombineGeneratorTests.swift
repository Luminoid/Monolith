import Foundation
import Testing
@testable import MonolithLib

struct CombineGeneratorTests {
    @Test
    func `AsyncService has task cancellation pattern`() {
        let output = CombineGenerator.generateAsyncService()
        #expect(output.contains("[Task<Void, Never>]"))
        #expect(output.contains("cancelAll()"))
        #expect(output.contains("deinit"))
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
