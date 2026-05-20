import Foundation
import Testing

/// Parent suite for every integration test in this package.
///
/// All child suites mutate `currentDirectoryPath` via `withTempDir`, so they
/// MUST run serially. Swift Testing's `.serialized` is per-suite — sibling
/// top-level suites still race. Nesting child suites under this enum lets
/// `.serialized` propagate downward, giving true cross-suite serialization.
/// Same pattern Petfolio uses for `PetfolioTestSuite` to serialize singleton
/// access across its 40+ test suites.
@Suite(.serialized)
enum MonolithIntegrationSuite {}

/// Run a generator inside a temp dir (changing cwd), then restore.
/// The body receives the real (symlink-resolved) temp dir path from `currentDirectoryPath`.
///
/// Each call gets a fresh, unique temp dir so suites running serially under
/// `.serialized` cannot collide.
func withTempDir(prefix: String, body: (String) throws -> Void) throws {
    let raw = NSTemporaryDirectory() + "\(prefix)-\(UUID().uuidString)"
    try FileManager.default.createDirectory(atPath: raw, withIntermediateDirectories: true)
    let originalDir = FileManager.default.currentDirectoryPath
    FileManager.default.changeCurrentDirectoryPath(raw)
    // currentDirectoryPath resolves symlinks, giving us /private/var/... on macOS
    let resolved = FileManager.default.currentDirectoryPath
    defer {
        FileManager.default.changeCurrentDirectoryPath(originalDir)
        try? FileManager.default.removeItem(atPath: raw)
    }
    try body(resolved)
}
