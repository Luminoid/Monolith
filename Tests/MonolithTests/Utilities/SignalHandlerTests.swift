import Foundation
import Testing
@testable import MonolithLib

/// Nested under `MonolithIntegrationSuite` so `.serialized` keeps these
/// apart from `NewCommandRunnerTests`: both touch the process-wide SIGINT
/// action. A raised SIGINT only sets the handler's flag, which other suites
/// never read: `FileWriter.writeFile` checks it only inside
/// `SignalHandler.$guardsWrites`.
extension MonolithIntegrationSuite {
    struct SignalHandlerTests {
        /// The handler value SIGINT has now, as a number (0 default, 1 ignore).
        private func currentAction() -> Int {
            var action = sigaction()
            sigaction(SIGINT, nil, &action)
            return unsafeBitCast(action.__sigaction_u.__sa_handler, to: Int.self)
        }

        @Test
        func `removePartialOutput deletes existing directory`() throws {
            let path = NSTemporaryDirectory() + "monolith-test-cleanup-\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            try "x".write(toFile: path + "/file.txt", atomically: true, encoding: .utf8)
            #expect(FileManager.default.fileExists(atPath: path))

            SignalHandler.removePartialOutput(at: path)

            #expect(!FileManager.default.fileExists(atPath: path))
        }

        @Test
        func `removePartialOutput is a no-op when directory is absent`() {
            let path = "/tmp/monolith-test-nonexistent-\(UUID().uuidString)"
            // Should not crash, should not print anything alarming.
            SignalHandler.removePartialOutput(at: path)
            #expect(!FileManager.default.fileExists(atPath: path))
        }

        /// A second install keeps the first one's saved action, so a single
        /// uninstall restores what was there before either.
        @Test
        func `install is idempotent`() {
            SignalHandler.uninstall()
            let original = currentAction()
            defer { SignalHandler.uninstall() }

            SignalHandler.install()
            let installed = currentAction()
            SignalHandler.install()
            guard original != 1 else { return } // SIGINT ignored in this environment

            #expect(SignalHandler.isArmed)
            #expect(installed != original)
            #expect(currentAction() == installed)
            SignalHandler.uninstall()
            #expect(!SignalHandler.isArmed)
            #expect(currentAction() == original)
        }

        /// The handler only records the interrupt and restores the default
        /// action, so a second Ctrl-C ends the process. The signal goes to the
        /// process, not this thread: test threads block SIGINT, so `raise`
        /// would leave it pending. The kernel delivers it to a thread that
        /// doesn't block it, so wait for the flag.
        @Test
        func `a SIGINT sets the flag and restores the default action`() {
            SignalHandler.uninstall()
            defer { SignalHandler.uninstall() }
            SignalHandler.install()
            guard SignalHandler.isArmed else { return } // SIGINT ignored in this environment
            #expect(!SignalHandler.wasInterrupted)
            #expect(currentAction() == unsafeBitCast(SignalHandler.handler, to: Int.self))

            kill(getpid(), SIGINT)
            let deadline = Date().addingTimeInterval(5)
            while !SignalHandler.wasInterrupted, Date() < deadline {
                usleep(1000)
            }

            #expect(SignalHandler.wasInterrupted)
            #expect(currentAction() == 0)
            #expect(throws: SignalHandler.InterruptedError.self) { try SignalHandler.throwIfInterrupted() }
            SignalHandler.uninstall()
            #expect(!SignalHandler.wasInterrupted)
        }

        /// A SIGINT the parent ignored (`nohup`, a background job) stays ignored.
        @Test
        func `install leaves an ignored SIGINT ignored`() {
            SignalHandler.uninstall()
            var saved = sigaction()
            sigaction(SIGINT, nil, &saved)
            signal(SIGINT, SIG_IGN)
            defer {
                SignalHandler.uninstall()
                sigaction(SIGINT, &saved, nil)
            }

            SignalHandler.install()

            #expect(!SignalHandler.isArmed)
            #expect(currentAction() == 1)
        }
    }
}
