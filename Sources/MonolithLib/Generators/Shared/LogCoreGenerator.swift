import Foundation

/// Renders the logging core that generated packages carry, and decides where it goes.
///
/// The core is one source file, `<Prefix>Log.swift`, plus its test file. Every copy is the same
/// text with three tokens filled in:
///
/// - `__PREFIX__`: the type prefix (`<Prefix>Log`, `<Prefix>LogLevel`, `<Prefix>LogEntry`).
/// - `__SUBSYSTEM__`: the unified-logging subsystem every line is written under.
/// - `__MODULE__`: the target that holds the core (header comments and the test's import).
///
/// The two templates at the bottom of this file are the reference copy. Each sits between
/// `// BEGIN ... TEMPLATE` / `// END ... TEMPLATE` marker lines so a script can extract it; the
/// literal content is the file verbatim, minus the final newline. Rendering is token
/// substitution plus that newline, nothing else. (The module import in the tests is the
/// `@testable` one, which SwiftFormat keeps last, so no module name can unsort the imports.)
///
/// The categories file is a starter that belongs to the package; it has no template.
enum LogCoreGenerator {
    /// The rendered files for one package.
    struct Files: Equatable {
        /// `<Prefix>Log.swift`.
        let source: String
        /// `<Prefix>LogTests.swift`.
        let tests: String
        /// `<Prefix>Log+Categories.swift`.
        let categories: String
    }

    /// Where a generated package carries the core.
    struct Placement: Equatable {
        /// The library target that holds the core.
        let module: String
        /// The type prefix.
        let prefix: String
        /// The unified-logging subsystem.
        let subsystem: String

        var sourcePath: String {
            "Sources/\(module)/Logging/\(prefix)Log.swift"
        }

        var categoriesPath: String {
            "Sources/\(module)/Logging/\(prefix)Log+Categories.swift"
        }

        var testsPath: String {
            "Tests/\(module)Tests/\(prefix)LogTests.swift"
        }

        /// Every file the core adds, in write order.
        var paths: [String] {
            [sourcePath, categoriesPath, testsPath]
        }
    }

    /// The lowest deployment targets the core builds for. `OSAllocatedUnfairLock` sets them.
    static let platformFloors: [PlatformVersion] = [
        PlatformVersion(platform: "iOS", version: "16.0"),
        PlatformVersion(platform: "macOS", version: "13.0"),
        PlatformVersion(platform: "macCatalyst", version: "16.0"),
        PlatformVersion(platform: "tvOS", version: "16.0"),
        PlatformVersion(platform: "watchOS", version: "9.0"),
        PlatformVersion(platform: "visionOS", version: "1.0"),
    ]

    // MARK: - Rendering

    /// Renders the core, its tests, and a starter categories file.
    static func render(prefix: String, subsystem: String, module: String) -> Files {
        Files(
            source: fill(coreTemplate, prefix: prefix, subsystem: subsystem, module: module),
            tests: fill(coreTestsTemplate, prefix: prefix, subsystem: subsystem, module: module),
            categories: renderCategories(prefix: prefix, subsystem: subsystem, module: module)
        )
    }

    /// The package's own categories, starting with `general`. `nonisolated` keeps the
    /// category usable from any isolation when the target defaults to `MainActor`; the
    /// `package` access sits on the extension, where SwiftFormat's `extensionAccessControl` puts it.
    static func renderCategories(prefix: String, subsystem: String, module: String) -> String {
        let placeholderNote = subsystem.hasPrefix("com.example.")
            ? "\n//  Lines go to subsystem \"\(subsystem)\", a placeholder: replace it in\n//  \(prefix)Log.swift with your own reverse-DNS identifier."
            : ""
        return """
        //
        //  \(prefix)Log+Categories.swift
        //  \(module)
        //
        //  This package's log categories. Add one per area of the package, e.g.
        //  `nonisolated static let network = \(prefix)Log.Category("Network")`.\(placeholderNote)
        //

        package extension \(prefix)Log.Category {
            /// Lines that don't belong to a narrower category.
            nonisolated static let general = \(prefix)Log.Category("General")
        }

        """
    }

    private static func fill(_ template: String, prefix: String, subsystem: String, module: String) -> String {
        template
            .replacingOccurrences(of: "__PREFIX__", with: prefix)
            .replacingOccurrences(of: "__SUBSYSTEM__", with: subsystem)
            .replacingOccurrences(of: "__MODULE__", with: module) + "\n"
    }

    // MARK: - Placement

    /// Where `config` carries the core, or `nil` when it has no library target to hold it or
    /// declares a platform below ``platformFloors``.
    static func placement(for config: PackageConfig) -> Placement? {
        guard let module = coreModule(for: config), platformsBelowFloor(config.platforms).isEmpty else { return nil }
        // The prefix comes from the package name. If the holding target is itself named like
        // one of the core's types, its placeholder enum would clash, so use the target name.
        let packagePrefix = config.name.upperCamelCased
        let coreTypes = ["Log", "LogLevel", "LogEntry"].map { packagePrefix + $0 }
        let prefix = coreTypes.contains(module) ? module : packagePrefix
        return Placement(module: module, prefix: prefix, subsystem: "com.example.\(config.name.lowercased())")
    }

    /// The library target that holds the core: one other targets can depend on (no in-package
    /// dependencies of its own), preferring the target named after the package. Executables and
    /// test-helper targets never hold it.
    static func coreModule(for config: PackageConfig) -> String? {
        let targetNames = Set(config.targets.map(\.name))
        let eligible = config.targets.filter { !$0.isExecutable && !config.testHelperTargets.contains($0.name) }
        let roots = eligible.filter { target in !target.dependencies.contains(where: targetNames.contains) }
        if let eponymous = roots.first(where: { $0.name == config.name }) {
            return eponymous.name
        }
        return (roots.first ?? eligible.first)?.name
    }

    /// Declared platforms whose deployment target is below the core's floor.
    static func platformsBelowFloor(_ platforms: [PlatformVersion]) -> [PlatformVersion] {
        platforms.filter { declared in
            guard let floor = platformFloors.first(where: { $0.platform.lowercased() == declared.platform.lowercased() }) else { return false }
            return PlatformVersion.higher(declared.version, floor.version) != declared.version
        }
    }

    /// `platforms` plus the macOS floor when macOS is not declared, so `swift build` on a Mac
    /// host (which builds for macOS at SwiftPM's much lower default) compiles the core.
    static func addingHostFloor(to platforms: [PlatformVersion]) -> [PlatformVersion] {
        guard !platforms.contains(where: { $0.platform.lowercased() == "macos" }) else { return platforms }
        return platforms + [PlatformVersion(platform: "macOS", version: "13.0")]
    }
}

// MARK: - Templates

// The literals below are the reference copy of the core. They sit at column 0 so their content
// is the files verbatim, so SwiftFormat's `indent` (which would shift them) and `docComments`
// (which would turn the marker lines into doc comments) are off around them.

extension LogCoreGenerator {
    // swiftformat:disable indent docComments
    // BEGIN LOG CORE TEMPLATE
    static let coreTemplate = #"""
//
//  __PREFIX__Log.swift
//  __MODULE__
//
//  Logging core: levels, entries, and the write functions over os.Logger.
//  Categories live in __PREFIX__Log+Categories.swift.
//

import Foundation
import os

// MARK: - __PREFIX__LogLevel

/// Log severity, lowest to highest. The names follow `os.Logger`'s methods.
public nonisolated enum __PREFIX__LogLevel: String, Sendable, CaseIterable, Comparable, Codable {
    /// Development detail. Never saved on device.
    case debug
    /// Helpful context. Kept in memory only, so usually missing from a sysdiagnose.
    case info
    /// A normal but significant event (configuration, lifecycle). Saved on device.
    case notice
    /// Something went wrong, but the operation recovered or degraded.
    case warning
    /// An operation failed.
    case error
    /// A bug: an invariant the package relies on is broken.
    case fault

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rank < rhs.rank
    }

    /// The unified-logging type this level is written at (`warning` matches `Logger.warning`).
    public var osLogType: OSLogType {
        switch self {
        case .debug: .debug
        case .info: .info
        case .notice: .default
        case .warning, .error: .error
        case .fault: .fault
        }
    }

    private var rank: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}

// MARK: - __PREFIX__LogEntry

/// One written log line, as ``__PREFIX__Log/handler`` receives it.
public nonisolated struct __PREFIX__LogEntry: Sendable, Hashable {
    /// When the line was written.
    public let timestamp: Date
    /// Severity.
    public let level: __PREFIX__LogLevel
    /// Category name, e.g. "Session".
    public let category: String
    /// The public text: the message, plus an attached error's summary in brackets.
    public let message: String
    /// User data and full error descriptions; redacted in field logs.
    public let privateDetail: String?
    /// The call site's file name.
    public let file: String
    /// The call site's line.
    public let line: Int

    public init(timestamp: Date = Date(), level: __PREFIX__LogLevel, category: String, message: String, privateDetail: String? = nil, file: String = "", line: Int = 0) {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.privateDetail = privateDetail
        self.file = file
        self.line = line
    }

    /// `[File.swift:12] message`, or the message alone when the call site is unknown.
    public var formattedMessage: String {
        file.isEmpty ? message : "[\(file):\(line)] \(message)"
    }
}

// MARK: - __PREFIX__Log

/// Logging on `os.Logger` under subsystem ``subsystem``.
///
/// - ``minimumLevel`` (default `.info`) sets how much is written. It is clamped at `.error`,
///   so errors and faults always reach the unified log and the handler.
/// - ``handler`` receives every written entry in addition to the unified log, for forwarding
///   to an app's own log store or crash reporter.
/// - Message text is public: keep it to static text, codes, ids, counts, and dimensions.
///   Pass user data (URLs, file paths, payloads) as `private:`.
///
/// Watch it live: `log stream --level debug --predicate 'subsystem == "__SUBSYSTEM__"'`
public nonisolated enum __PREFIX__Log {
    /// The unified-logging subsystem every line is written under.
    public static let subsystem = "__SUBSYSTEM__"

    /// A log category. The package declares its categories as static members.
    public struct Category: Sendable {
        /// The category name shown in Console.
        public let name: String
        fileprivate let logger: Logger

        package init(_ name: String) {
            self.name = name
            logger = Logger(subsystem: __PREFIX__Log.subsystem, category: name)
        }
    }

    private struct State {
        var minimumLevel: __PREFIX__LogLevel = .info
        var handler: (@Sendable (__PREFIX__LogEntry) -> Void)?
        var onceKeys: Set<String> = []
    }

    private static let state = OSAllocatedUnfairLock(initialState: State())

    /// A threshold and handler bound to the current task by `withScopedConfiguration`.
    private struct Scope: Sendable {
        let minimumLevel: __PREFIX__LogLevel
        let handler: (@Sendable (__PREFIX__LogEntry) -> Void)?
    }

    @TaskLocal private static var scope: Scope?

    // MARK: - Configuration

    /// Lines below this level are not written. Default `.info`; values above `.error` clamp to `.error`.
    public static var minimumLevel: __PREFIX__LogLevel {
        get { state.withLock { $0.minimumLevel } }
        set { state.withLock { $0.minimumLevel = min(newValue, .error) } }
    }

    /// Receives every written entry, after the unified log, on the logging thread.
    public static var handler: (@Sendable (__PREFIX__LogEntry) -> Void)? {
        get { state.withLock { $0.handler } }
        set { state.withLock { $0.handler = newValue } }
    }

    /// Runs `body` with a threshold and handler that apply only to the current task and its child tasks,
    /// leaving the process-wide ``minimumLevel`` and ``handler`` untouched. For tests, which run in parallel
    /// and share the process-wide settings. The threshold clamps at `.error` like ``minimumLevel``.
    package static func withScopedConfiguration<R>(
        minimumLevel: __PREFIX__LogLevel,
        handler: (@Sendable (__PREFIX__LogEntry) -> Void)?,
        _ body: () throws -> R
    ) rethrows -> R {
        try $scope.withValue(Scope(minimumLevel: min(minimumLevel, .error), handler: handler), operation: body)
    }

    /// The threshold and handler in effect: the task's scoped configuration, else the process-wide one.
    private static func effectiveConfiguration() -> (minimumLevel: __PREFIX__LogLevel, handler: (@Sendable (__PREFIX__LogEntry) -> Void)?) {
        if let scope {
            return (scope.minimumLevel, scope.handler)
        }
        return state.withLock { ($0.minimumLevel, $0.handler) }
    }

    // MARK: - Writing

    /// Whether a line at `level` would be written; use it to skip work that only feeds a log line.
    package static func isLogging(_ level: __PREFIX__LogLevel) -> Bool {
        level >= effectiveConfiguration().minimumLevel
    }

    package static func debug(
        _ category: Category,
        _ message: @autoclosure () -> String,
        private detail: @autoclosure () -> String? = nil,
        error: (any Error)? = nil,
        file: String = #fileID,
        line: Int = #line
    ) {
        log(.debug, category, message(), private: detail(), error: error, file: file, line: line)
    }

    package static func info(
        _ category: Category,
        _ message: @autoclosure () -> String,
        private detail: @autoclosure () -> String? = nil,
        error: (any Error)? = nil,
        file: String = #fileID,
        line: Int = #line
    ) {
        log(.info, category, message(), private: detail(), error: error, file: file, line: line)
    }

    package static func notice(
        _ category: Category,
        _ message: @autoclosure () -> String,
        private detail: @autoclosure () -> String? = nil,
        error: (any Error)? = nil,
        file: String = #fileID,
        line: Int = #line
    ) {
        log(.notice, category, message(), private: detail(), error: error, file: file, line: line)
    }

    package static func warning(
        _ category: Category,
        _ message: @autoclosure () -> String,
        private detail: @autoclosure () -> String? = nil,
        error: (any Error)? = nil,
        file: String = #fileID,
        line: Int = #line
    ) {
        log(.warning, category, message(), private: detail(), error: error, file: file, line: line)
    }

    package static func error(
        _ category: Category,
        _ message: @autoclosure () -> String,
        private detail: @autoclosure () -> String? = nil,
        error: (any Error)? = nil,
        file: String = #fileID,
        line: Int = #line
    ) {
        log(.error, category, message(), private: detail(), error: error, file: file, line: line)
    }

    package static func fault(
        _ category: Category,
        _ message: @autoclosure () -> String,
        private detail: @autoclosure () -> String? = nil,
        error: (any Error)? = nil,
        file: String = #fileID,
        line: Int = #line
    ) {
        log(.fault, category, message(), private: detail(), error: error, file: file, line: line)
    }

    /// Writes one line. The message and detail closures run only when the line is written.
    package static func log(
        _ level: __PREFIX__LogLevel,
        _ category: Category,
        _ message: @autoclosure () -> String,
        private detail: @autoclosure () -> String? = nil,
        error: (any Error)? = nil,
        file: String = #fileID,
        line: Int = #line
    ) {
        let configuration = effectiveConfiguration()
        guard level >= configuration.minimumLevel else { return }

        var publicText = message()
        var privateParts: [String] = []
        if let detail = detail() {
            privateParts.append(detail)
        }
        if let error {
            let described = describe(error)
            publicText += " [\(described.summary)]"
            if let errorDetail = described.detail {
                privateParts.append(errorDetail)
            }
        }
        let privateText = privateParts.isEmpty ? nil : privateParts.joined(separator: " | ")
        let fileName = file.split(separator: "/").last.map(String.init) ?? file
        let location = "[\(fileName):\(line)]"
        if let privateText {
            category.logger.log(level: level.osLogType, "\(location, privacy: .public) \(publicText, privacy: .public) | \(privateText, privacy: .private)")
        } else {
            category.logger.log(level: level.osLogType, "\(location, privacy: .public) \(publicText, privacy: .public)")
        }
        configuration.handler?(__PREFIX__LogEntry(level: level, category: category.name, message: publicText, privateDetail: privateText, file: fileName, line: line))
    }

    /// Writes a line once per `key` until ``resetOnce(_:)``, for failures on per-frame or polling paths.
    /// Keys should come from a small fixed set; each is remembered until reset.
    package static func once(
        _ key: String,
        _ level: __PREFIX__LogLevel,
        _ category: Category,
        _ message: @autoclosure () -> String,
        private detail: @autoclosure () -> String? = nil,
        error: (any Error)? = nil,
        file: String = #fileID,
        line: Int = #line
    ) {
        guard isLogging(level), state.withLock({ $0.onceKeys.insert(key).inserted }) else { return }
        log(level, category, message(), private: detail(), error: error, file: file, line: line)
    }

    /// Re-arms a ``once(_:_:_:_:private:error:file:line:)`` key, typically when the failing state clears.
    package static func resetOnce(_ key: String) {
        state.withLock { _ = $0.onceKeys.remove(key) }
    }

    // MARK: - Errors

    /// Splits an error into a public summary and a private detail.
    ///
    /// - Swift enum errors summarize as `Module.Type.case`, plus the summary of an error payload.
    /// - Other errors summarize as NSError domain and code, plus the underlying error's domain and code.
    /// - The detail is the full `String(describing:)`, which may carry user data; `nil` when the summary already says it all.
    public static func describe(_ error: any Error) -> (summary: String, detail: String?) {
        let full = String(describing: error)
        let summary: String
        let mirror = Mirror(reflecting: error)
        if mirror.displayStyle == .enum {
            let payload = mirror.children.first
            var text = "\(String(reflecting: type(of: error))).\(payload?.label ?? full)"
            if let inner = payload.flatMap({ firstError(in: $0.value) }) {
                text += " <- \(describe(inner).summary)"
            }
            summary = text
        } else {
            let nsError = error as NSError
            var text = "\(nsError.domain) \(nsError.code)"
            if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                text += " <- \(underlying.domain) \(underlying.code)"
            }
            summary = text
        }
        return (summary, summary.hasSuffix(full) ? nil : full)
    }

    /// An enum payload's error: the payload itself, or the first error among its (possibly labeled) tuple elements.
    private static func firstError(in payload: Any) -> (any Error)? {
        if let error = payload as? any Error {
            return error
        }
        return Mirror(reflecting: payload).children.lazy.compactMap { $0.value as? any Error }.first
    }
}
"""#
    // END LOG CORE TEMPLATE
    // swiftformat:enable indent docComments

    // swiftformat:disable indent docComments
    // BEGIN LOG CORE TESTS TEMPLATE
    static let coreTestsTemplate = #"""
//
//  __PREFIX__LogTests.swift
//  __MODULE__Tests
//
//  Tests for the logging core in __PREFIX__Log.swift.
//

import Foundation
import os
import Testing
@testable import __MODULE__

@Suite("__PREFIX__Log core", .serialized)
struct __PREFIX__LogTests {
    enum SampleError: Error {
        case timeout
        case failed(String)
        case wrapped(any Error)
        case labeled(underlying: any Error)
        case pair(String, underlying: any Error)
    }

    private final class Capture: Sendable {
        private let entries = OSAllocatedUnfairLock<[__PREFIX__LogEntry]>(initialState: [])

        func append(_ entry: __PREFIX__LogEntry) {
            entries.withLock { $0.append(entry) }
        }

        var all: [__PREFIX__LogEntry] {
            entries.withLock { $0 }.filter { $0.category == __PREFIX__LogTests.category.name }
        }
    }

    static let category = __PREFIX__Log.Category("LogCoreTests")

    /// Runs `body` with a capturing handler at `level`, scoped to this task. The process-wide
    /// configuration is never changed here: other suites log in parallel and rely on it.
    private func capturing(at level: __PREFIX__LogLevel = .info, _ body: () -> Void) -> [__PREFIX__LogEntry] {
        let capture = Capture()
        __PREFIX__Log.withScopedConfiguration(minimumLevel: level, handler: { capture.append($0) }, body)
        return capture.all
    }

    @Test
    func `levels are ordered and map to unified-logging types like os.Logger's methods`() {
        #expect(__PREFIX__LogLevel.allCases.sorted() == __PREFIX__LogLevel.allCases)
        #expect(__PREFIX__LogLevel.debug.osLogType == .debug)
        #expect(__PREFIX__LogLevel.info.osLogType == .info)
        #expect(__PREFIX__LogLevel.notice.osLogType == .default)
        #expect(__PREFIX__LogLevel.warning.osLogType == .error)
        #expect(__PREFIX__LogLevel.error.osLogType == .error)
        #expect(__PREFIX__LogLevel.fault.osLogType == .fault)
    }

    @Test
    func `the default threshold is info, and filtered lines are never built`() {
        #expect(__PREFIX__Log.minimumLevel == .info)
        var evaluated = false
        let entries = capturing {
            __PREFIX__Log.debug(Self.category, {
                evaluated = true
                return "hidden"
            }())
            __PREFIX__Log.info(Self.category, "shown")
        }
        #expect(!evaluated)
        #expect(entries.map(\.message) == ["shown"])
        #expect(entries.first?.file == "__PREFIX__LogTests.swift")
    }

    @Test
    func `the threshold clamps at error, so errors and faults always come through`() {
        let entries = capturing(at: .fault) {
            #expect(!__PREFIX__Log.isLogging(.warning))
            #expect(__PREFIX__Log.isLogging(.error))
            __PREFIX__Log.warning(Self.category, "dropped")
            __PREFIX__Log.error(Self.category, "kept")
            __PREFIX__Log.fault(Self.category, "kept too")
        }
        #expect(entries.map(\.level) == [.error, .fault])
    }

    @Test
    func `a scoped configuration leaves the process-wide settings alone`() {
        let entries = __PREFIX__Log.withScopedConfiguration(minimumLevel: .debug, handler: nil) {
            #expect(__PREFIX__Log.isLogging(.debug))
            #expect(__PREFIX__Log.minimumLevel == .info)
            return capturing(at: .warning) {
                __PREFIX__Log.notice(Self.category, "inner scope wins")
            }
        }
        #expect(entries.isEmpty)
        #expect(!__PREFIX__Log.isLogging(.debug))
    }

    @Test
    func `debug lines are written once the threshold is lowered`() {
        let entries = capturing(at: .debug) {
            __PREFIX__Log.debug(Self.category, "trace")
        }
        #expect(entries.map(\.level) == [.debug])
    }

    @Test
    func `private detail stays out of the public message`() {
        let entries = capturing {
            __PREFIX__Log.notice(Self.category, "Fetched page", private: "https://example.com/?token=secret")
        }
        #expect(entries.first?.message == "Fetched page")
        #expect(entries.first?.privateDetail == "https://example.com/?token=secret")
    }

    @Test
    func `an attached error adds its summary to the message and its description to the private detail`() {
        let underlying = NSError(domain: NSPOSIXErrorDomain, code: 60)
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: [NSUnderlyingErrorKey: underlying])
        let entries = capturing {
            __PREFIX__Log.error(Self.category, "Request failed", error: error)
        }
        #expect(entries.first?.message == "Request failed [NSURLErrorDomain -1001 <- NSPOSIXErrorDomain 60]")
        #expect(entries.first?.privateDetail?.contains("NSURLErrorDomain") == true)
    }

    @Test
    func `Swift enum errors summarize as type and case, keeping payloads private`() {
        let failed = __PREFIX__Log.describe(SampleError.failed("user text"))
        #expect(failed.summary.hasSuffix("SampleError.failed"))
        #expect(!failed.summary.contains("user text"))
        #expect(failed.detail?.contains("user text") == true)

        let timeout = __PREFIX__Log.describe(SampleError.timeout)
        #expect(timeout.summary.hasSuffix("SampleError.timeout"))
        #expect(timeout.detail == nil)

        let wrapped = __PREFIX__Log.describe(SampleError.wrapped(URLError(.timedOut)))
        #expect(wrapped.summary.hasSuffix("SampleError.wrapped <- NSURLErrorDomain -1001"))

        let labeled = __PREFIX__Log.describe(SampleError.labeled(underlying: URLError(.timedOut)))
        #expect(labeled.summary.hasSuffix("SampleError.labeled <- NSURLErrorDomain -1001"))

        let pair = __PREFIX__Log.describe(SampleError.pair("stage", underlying: URLError(.timedOut)))
        #expect(pair.summary.hasSuffix("SampleError.pair <- NSURLErrorDomain -1001"))
        #expect(!pair.summary.contains("stage"))
    }

    @Test
    func `once writes a key a single time until it is reset`() {
        let entries = capturing {
            for _ in 0 ..< 3 {
                __PREFIX__Log.once("test.flood", .error, Self.category, "Pool exhausted")
            }
            __PREFIX__Log.resetOnce("test.flood")
            __PREFIX__Log.once("test.flood", .error, Self.category, "Pool exhausted")
        }
        __PREFIX__Log.resetOnce("test.flood")
        #expect(entries.count == 2)
    }

    @Test
    func `formattedMessage prefixes the call site`() {
        let entry = __PREFIX__LogEntry(level: .info, category: "Test", message: "hello", file: "File.swift", line: 12)
        #expect(entry.formattedMessage == "[File.swift:12] hello")
        #expect(__PREFIX__LogEntry(level: .info, category: "Test", message: "hello").formattedMessage == "hello")
    }
}
"""#
    // END LOG CORE TESTS TEMPLATE
    // swiftformat:enable indent docComments
}
