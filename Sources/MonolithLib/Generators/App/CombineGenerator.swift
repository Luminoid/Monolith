/// Generates async Task pattern templates for the `combine` feature.
///
/// Historical note: this generator used to also emit a `DataPublisher.swift`
/// sample singleton (a `static let shared` `PassthroughSubject` wrapper). It
/// was removed because every scaffolded project ended up deleting it on the
/// first commit — the singleton had no consumers and shipped only as a
/// "here's how Combine looks" demonstration. `AsyncService.swift` survives as
/// the Task-cancellation reference template; adopters introduce their own
/// publishers as real features call for them.
enum CombineGenerator {
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
                for task in activeTasks { task.cancel() }
                activeTasks.removeAll()
            }

            deinit {
                for task in activeTasks { task.cancel() }
            }
        }

        """
    }
}
