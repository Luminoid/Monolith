import Foundation

/// Generates Combine publisher/subscriber boilerplate and async Task patterns.
enum CombineGenerator {

    /// Generate a sample DataPublisher service.
    static func generateDataPublisher(config: AppConfig) -> String {
        var lines: [String] = []

        lines.append("import Combine")
        lines.append("import Foundation")
        lines.append("")
        lines.append("/// Sample Combine publisher service for data updates.")
        lines.append("final class DataPublisher {")
        lines.append("")
        lines.append("    // MARK: - Properties")
        lines.append("")
        lines.append("    static let shared = DataPublisher()")
        lines.append("")
        lines.append("    /// Publishes data change notifications.")
        lines.append("    let dataChanged = PassthroughSubject<Void, Never>()")
        lines.append("")
        lines.append("    /// Current loading state.")
        lines.append("    @Published var isLoading = false")
        lines.append("")
        lines.append("    // MARK: - Initialization")
        lines.append("")
        lines.append("    private init() {}")
        lines.append("")
        lines.append("    // MARK: - Actions")
        lines.append("")
        lines.append("    func notifyDataChanged() {")
        lines.append("        dataChanged.send()")
        lines.append("    }")
        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    /// Generate async service template with Task cancellation pattern.
    static func generateAsyncService(config: AppConfig) -> String {
        var lines: [String] = []

        lines.append("import Foundation")
        lines.append("")
        lines.append("/// Async service template with proper Task cancellation.")
        lines.append("@MainActor")
        lines.append("final class AsyncService {")
        lines.append("")
        lines.append("    // MARK: - Properties")
        lines.append("")
        lines.append("    /// Store task handles for cancellation in deinit.")
        lines.append("    private var activeTasks: [Task<Void, Never>] = []")
        lines.append("")
        lines.append("    // MARK: - Actions")
        lines.append("")
        lines.append("    /// Perform an async operation with tracked cancellation.")
        lines.append("    func performAsync(_ work: @escaping @Sendable () async -> Void) {")
        lines.append("        let task = Task<Void, Never> {")
        lines.append("            await work()")
        lines.append("        }")
        lines.append("        activeTasks.append(task)")
        lines.append("    }")
        lines.append("")
        lines.append("    /// Cancel all active tasks.")
        lines.append("    func cancelAll() {")
        lines.append("        activeTasks.forEach { $0.cancel() }")
        lines.append("        activeTasks.removeAll()")
        lines.append("    }")
        lines.append("")
        lines.append("    deinit {")
        lines.append("        activeTasks.forEach { $0.cancel() }")
        lines.append("    }")
        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }
}
