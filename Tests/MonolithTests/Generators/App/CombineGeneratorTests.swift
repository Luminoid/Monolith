import Foundation
import Testing
@testable import MonolithLib

struct CombineGeneratorTests {
    @Test
    func `DataPublisher uses Combine imports`() {
        let output = CombineGenerator.generateDataPublisher()
        #expect(output.contains("import Combine"))
        #expect(output.contains("import Foundation"))
    }

    @Test
    func `DataPublisher is a singleton`() {
        let output = CombineGenerator.generateDataPublisher()
        #expect(output.contains("static let shared"))
        #expect(output.contains("private init()"))
    }

    @Test
    func `DataPublisher has PassthroughSubject and @Published`() {
        let output = CombineGenerator.generateDataPublisher()
        #expect(output.contains("PassthroughSubject<Void, Never>"))
        #expect(output.contains("@Published var isLoading"))
    }

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
    func `MARK sections in both files`() {
        let publisher = CombineGenerator.generateDataPublisher()
        #expect(publisher.contains("// MARK: - Properties"))
        #expect(publisher.contains("// MARK: - Actions"))

        let service = CombineGenerator.generateAsyncService()
        #expect(service.contains("// MARK: - Properties"))
        #expect(service.contains("// MARK: - Actions"))
    }
}
