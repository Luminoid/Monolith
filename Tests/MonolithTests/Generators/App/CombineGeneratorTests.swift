import Foundation
import Testing
@testable import MonolithLib

@Suite("CombineGenerator")
struct CombineGeneratorTests {
    @Test("DataPublisher uses Combine imports")
    func dataPublisherImports() {
        let output = CombineGenerator.generateDataPublisher()
        #expect(output.contains("import Combine"))
        #expect(output.contains("import Foundation"))
    }

    @Test("DataPublisher is a singleton")
    func dataPublisherSingleton() {
        let output = CombineGenerator.generateDataPublisher()
        #expect(output.contains("static let shared"))
        #expect(output.contains("private init()"))
    }

    @Test("DataPublisher has PassthroughSubject and @Published")
    func dataPublisherProperties() {
        let output = CombineGenerator.generateDataPublisher()
        #expect(output.contains("PassthroughSubject<Void, Never>"))
        #expect(output.contains("@Published var isLoading"))
    }

    @Test("AsyncService has task cancellation pattern")
    func asyncServiceCancellation() {
        let output = CombineGenerator.generateAsyncService()
        #expect(output.contains("[Task<Void, Never>]"))
        #expect(output.contains("cancelAll()"))
        #expect(output.contains("deinit"))
    }

    @Test("AsyncService is @MainActor")
    func asyncServiceMainActor() {
        let output = CombineGenerator.generateAsyncService()
        #expect(output.contains("@MainActor"))
    }

    @Test("MARK sections in both files")
    func markSections() {
        let publisher = CombineGenerator.generateDataPublisher()
        #expect(publisher.contains("// MARK: - Properties"))
        #expect(publisher.contains("// MARK: - Actions"))

        let service = CombineGenerator.generateAsyncService()
        #expect(service.contains("// MARK: - Properties"))
        #expect(service.contains("// MARK: - Actions"))
    }
}
