import ArgumentParser

/// Bridges the typed errors of the flag parsers (`ExternalPackage.parse`,
/// `AppFeature.parseList`, and so on) into `ArgumentParser.ValidationError`,
/// so a bad flag value ends with ArgumentParser's message and usage line.
///
/// Only flag parsing goes through here. A config that fails
/// `validateForGeneration()` (from flags, the wizard, or `--load-config`)
/// throws its own error, which ArgumentParser prints without the usage
/// line, since the problem is the config, not the command line.
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
