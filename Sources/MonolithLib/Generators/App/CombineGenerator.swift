/// Generates the `combine` feature's one file, `AsyncService.swift`: a
/// Swift Concurrency template that tracks independent `Task`s and cancels them
/// together. It emits no Combine code; adopters add publishers as real
/// features call for them.
///
/// Historical note: this generator used to also emit a `DataPublisher.swift`
/// sample singleton (a `static let shared` `PassthroughSubject` wrapper). It
/// was removed because every scaffolded project ended up deleting it on the
/// first commit: the singleton had no consumers and shipped only as a
/// "here's how Combine looks" demonstration.
enum CombineGenerator {
    /// Generate the async service template with the Task cancellation pattern.
    static func generateAsyncService() -> String {
        """
        import Foundation

        /// Runs independent async jobs and cancels them together. Each job's task
        /// handle is kept until the job finishes; `cancelAll()` and `deinit` cancel
        /// the ones still running.
        @MainActor
        final class AsyncService {
            // MARK: - Properties

            /// Running tasks by id. Each task removes its own entry when it finishes.
            private var activeTasks: [UUID: Task<Void, Never>] = [:]

            // MARK: - Lifecycle

            deinit {
                for task in activeTasks.values {
                    task.cancel()
                }
            }

            // MARK: - Actions

            /// Perform an async operation with tracked cancellation.
            func performAsync(_ work: @escaping @Sendable () async -> Void) {
                let id = UUID()
                // The task starts after this method returns (both run on the main
                // actor), so the handle is stored before the task can remove it.
                activeTasks[id] = Task { [weak self] in
                    await work()
                    self?.activeTasks[id] = nil
                }
            }

            /// Cancel all active tasks.
            func cancelAll() {
                for task in activeTasks.values {
                    task.cancel()
                }
                activeTasks.removeAll()
            }
        }

        """
    }
}
