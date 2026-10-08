import Foundation

/// A resolved project config that a `new` command can generate.
///
/// `NewCommandRunner` calls `validateForGeneration()` once, before the dry
/// run, so a config built from flags, from the wizard, or from
/// `--load-config` passes the same checks. A config file is decoded straight
/// from JSON and never meets the flag parsers, so these checks restate every
/// rule a flag parser enforces.
protocol GeneratableConfig {
    /// The project name, which is also the output directory name.
    var name: String { get }

    /// The `projectType` recorded when the config is saved with `--save-config`.
    static var projectType: ProjectType { get }

    /// Throws when the config would generate a project that doesn't build, or
    /// writes outside the output directory. Errors are `CustomStringConvertible`.
    func validateForGeneration() throws

    /// The config wrapped for `ConfigFile.save`.
    func monolithConfig(initGit: Bool) -> ConfigFile.MonolithConfig
}

/// A config or flag value that fails validation. `description` is the whole
/// message, ready for `ValidationError`.
struct ConfigValidationError: Error, CustomStringConvertible, Equatable {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

// MARK: - Suggestions

/// "Did you mean" lookup shared by the flag parsers.
enum Suggestion {
    /// The candidate closest to `input`: an exact case-insensitive match
    /// first, then the nearest by edit distance when it is small next to the
    /// input's length. `nil` when nothing is close.
    static func closest(to input: String, in candidates: some Sequence<String>) -> String? {
        let lowered = input.lowercased()
        let pool = Array(candidates)
        if let exact = pool.first(where: { $0.lowercased() == lowered }) {
            return exact
        }
        let threshold = max(1, min(3, lowered.count / 3))
        let scored = pool.map { ($0, editDistance(lowered, $0.lowercased())) }
        guard let best = scored.min(by: { $0.1 < $1.1 }), best.1 <= threshold else { return nil }
        return best.0
    }

    /// `" Did you mean 'x'?"` (with the leading space), or an empty string.
    static func didYouMean(_ input: String, in candidates: some Sequence<String>) -> String {
        closest(to: input, in: candidates).map { " Did you mean '\($0)'?" } ?? ""
    }

    /// Levenshtein distance over Unicode scalars.
    static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs.unicodeScalars)
        let b = Array(rhs.unicodeScalars)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0 ... b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1 ... a.count {
            current[0] = i
            for j in 1 ... b.count {
                let substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)
                current[j] = min(previous[j] + 1, current[j - 1] + 1, substitution)
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }
}

// MARK: - Duplicates

enum DuplicateNames {
    /// The names that occur more than once in `names`, sorted. With
    /// `ignoringCase`, names that differ only in case count as the same name
    /// and every spelling is reported.
    static func find(in names: [String], ignoringCase: Bool) -> [String] {
        let groups = Dictionary(grouping: names) { ignoringCase ? $0.lowercased() : $0 }
        return Set(groups.values.filter { $0.count > 1 }.flatMap(\.self)).sorted()
    }
}

// MARK: - Lists

enum CommaList {
    /// The trimmed, non-empty tokens of a comma-separated flag value.
    static func tokens(_ input: String?) -> [String] {
        guard let input else { return [] }
        return input
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

/// Parses a comma-separated `--features` value into one feature enum,
/// rejecting unknown tokens instead of dropping them.
enum FeatureListParser {
    /// `selectable` is the list an unknown-token error offers; it defaults to
    /// every case.
    static func parse<F: RawRepresentable & CaseIterable & Hashable>(
        _ input: String?,
        as _: F.Type = F.self,
        selectable: [String]? = nil
    ) throws(ConfigValidationError) -> Set<F> where F.RawValue == String {
        var result = Set<F>()
        for token in CommaList.tokens(input) {
            guard let feature = F(rawValue: token) else {
                throw unknownFeature(token, valid: selectable ?? F.allCases.map(\.rawValue))
            }
            result.insert(feature)
        }
        return result
    }

    static func unknownFeature(_ token: String, valid: [String]) -> ConfigValidationError {
        ConfigValidationError(
            "Unknown feature '\(token)'.\(Suggestion.didYouMean(token, in: valid)) "
                + "Valid features: \(valid.joined(separator: ", ")). Run 'monolith list features' for descriptions."
        )
    }
}

// MARK: - Decoding Helpers

extension KeyedDecodingContainer {
    /// Decodes a feature list stored as raw strings, so an unknown or removed
    /// feature fails with a readable message (wrapped by `ConfigFile.load`
    /// with the key path) instead of a bare enum `DecodingError`. A missing
    /// key decodes as no features.
    func decodeFeatures<F: RawRepresentable & CaseIterable & Hashable>(
        _: F.Type,
        forKey key: Key,
        migration: ([String]) -> String? = { _ in nil }
    ) throws -> Set<F> where F.RawValue == String {
        let tokens = try decodeIfPresent([String].self, forKey: key) ?? []
        if let message = migration(tokens) {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: message)
        }
        var result = Set<F>()
        for token in tokens {
            guard let feature = F(rawValue: token) else {
                let message = FeatureListParser.unknownFeature(token, valid: F.allCases.map(\.rawValue)).description
                throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: message)
            }
            result.insert(feature)
        }
        return result
    }
}

extension Set where Element: RawRepresentable, Element.RawValue == String {
    /// Raw values in sorted order, so encoded configs are byte-for-byte
    /// stable (a `Set` encodes in hash order, which changes between runs).
    var sortedRawValues: [String] {
        map(\.rawValue).sorted()
    }
}
