/// Generates Combine publisher/subscriber boilerplate and async Task patterns.
enum CombineGenerator {
    /// Generate a sample DataPublisher service.
    static func generateDataPublisher() -> String {
        """
        import Combine
        import Foundation

        /// Sample Combine publisher service for data updates.
        final class DataPublisher {

            // MARK: - Properties

            static let shared = DataPublisher()

            /// Publishes data change notifications.
            let dataChanged = PassthroughSubject<Void, Never>()

            /// Current loading state.
            @Published var isLoading = false

            // MARK: - Initialization

            private init() {}

            // MARK: - Actions

            func notifyDataChanged() {
                dataChanged.send()
            }
        }

        """
    }

    /// Generate async service template with Task cancellation pattern.
    static func generateAsyncService() -> String {
        """
        import Foundation

        /// Async service template with proper Task cancellation.
        @MainActor
        final class AsyncService {

            // MARK: - Properties

            /// Store task handles for cancellation in deinit.
            private var activeTasks: [Task<Void, Never>] = []

            // MARK: - Actions

            /// Perform an async operation with tracked cancellation.
            func performAsync(_ work: @escaping @Sendable () async -> Void) {
                let task = Task<Void, Never> {
                    await work()
                }
                activeTasks.append(task)
            }

            /// Cancel all active tasks.
            func cancelAll() {
                activeTasks.forEach { $0.cancel() }
                activeTasks.removeAll()
            }

            deinit {
                activeTasks.forEach { $0.cancel() }
            }
        }

        """
    }
}
