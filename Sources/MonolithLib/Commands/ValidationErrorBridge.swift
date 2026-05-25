import ArgumentParser

/// Bridges typed-throwing config / parser errors into `ArgumentParser.ValidationError`,
/// which is the surface every `Commands/*Command.swift` ultimately propagates
/// out of `run()` so ArgumentParser can pretty-print the message and exit
/// non-zero without a stack trace.
///
/// Without this helper, every catch site reads the same way:
/// ```swift
/// do {
///     value = try ExternalPackage.parse(input)
/// } catch {
///     throw ValidationError(error.description)
/// }
/// ```
/// which is what `NewAppCommand` had three of and `NewPackageCommand` had
/// factored into a one-liner private helper of its own. The four catches now
/// route through `bridge(_:)` so the conversion lives in one place — adding a
/// new throwing parser doesn't tempt a fifth copy.
///
/// **Why untyped `throws`** on the closure parameter: typed-throws inference
/// through a generic closure parameter would force every call site to spell
/// out the error type (`{ () throws(ExternalPackage.ParseError) -> _ in ... }`),
/// erasing the readability win. The catch path picks up the error's
/// `CustomStringConvertible.description` when it conforms (every config-layer
/// error type does), with a `localizedDescription` fallback for anything else.
enum ValidationBridge {
    /// Runs `body`, returning its value on success. On thrown error, wraps the
    /// error's `description` (when it conforms to `CustomStringConvertible`)
    /// or `localizedDescription` in a fresh `ValidationError` and re-throws.
    static func bridge<T>(_ body: () throws -> T) throws -> T {
        do {
            return try body()
        } catch let error as CustomStringConvertible {
            throw ValidationError(error.description)
        } catch {
            throw ValidationError(error.localizedDescription)
        }
    }
}
