import Foundation

/// A package dep declared via `--external-packages`. Bypasses
/// `KnownPackages.registry` — used when a package or app depends on a SPM
/// repo Monolith doesn't ship a built-in entry for (typically a private or
/// in-development library that hasn't yet earned a registry slot).
struct ExternalPackage: Codable {
    /// Product name as referenced from `--target-deps` and `.product(name:)`.
    let name: String
    /// Source location. Either a remote URL (`https://...`, `ssh://...`, or
    /// the scp-style `git@host:owner/repo.git`) or a filesystem path
    /// (absolute or relative to the generated project root, e.g.
    /// `../ExtPkg`). See `isLocalPath`.
    let url: String
    /// Version requirement for URL-form packages, e.g. `"from: \"0.1.0\""`
    /// or `"branch: \"main\""`. Emitted verbatim after the URL in both
    /// `Package.swift` and XcodeGen YAML. Empty string for path-form
    /// packages (paths have no SPM version requirement).
    let requirement: String
    /// SPM package name (the `package:` arg in `.product(name:package:)`).
    /// Defaults to `name` if not specified — usually correct.
    let packageName: String?

    /// Inferred SPM package name (defaults to `name`).
    var spmPackageName: String { packageName ?? name }

    /// True when `url` is a filesystem path, not a remote URL. Path-form
    /// entries are emitted as `.package(name:, path:)` in Package.swift and
    /// `path:` in XcodeGen YAML.
    var isLocalPath: Bool { !Self.isRemoteURL(url) }

    /// Matches the scp-style git remote `user@host:` prefix (`git@github.com:`).
    private static let scpStylePrefix = #"^[\w.-]+@[\w.-]+:"#

    /// Whether `location` is a remote URL: it has a `scheme://`, or it is an
    /// scp-style `user@host:path` git remote.
    static func isRemoteURL(_ location: String) -> Bool {
        location.contains("://") || location.range(of: scpStylePrefix, options: .regularExpression) != nil
    }

    /// Parses the `--external-packages` syntax used by both `monolith new
    /// package` and `monolith new app`. Two forms:
    ///
    /// **URL form** (network packages): `Name=url:requirement[:packageName]`
    /// where `requirement` is verbatim SPM (`from: "0.1.0"`, `branch: "main"`,
    /// `exact: "1.0.0"`, etc.). The URL is recognized by its `://` separator
    /// or its scp-style `user@host:` prefix (`git@github.com:owner/repo.git`);
    /// the requirement starts at the first `:` after that.
    ///
    /// **Path form** (local packages — useful for dev workflows where the
    /// adopting project sits alongside the library): `Name=path[:packageName]`.
    /// The path is not a URL and has no requirement segment (paths don't take
    /// versions). Absolute paths and relative paths (resolved against the
    /// generated project root) both work — e.g. `ExtPkg=../ExtPkg` or
    /// `ExtPkg=/Users/me/Projects/ExtPkg`.
    ///
    /// Optional `packageName` overrides the default (which equals the product name).
    /// Throws `ParseError` on malformed input — callers convert to whatever error
    /// type their command surface expects (typically `ArgumentParser.ValidationError`).
    static func parse(_ input: String?) throws(ParseError) -> [Self] {
        guard let input, !input.isEmpty else { return [] }
        var out: [Self] = []
        for entry in input.split(separator: ";") {
            let nameSplit = entry.split(separator: "=", maxSplits: 1)
            guard nameSplit.count == 2 else {
                throw .malformedEntry(String(entry))
            }
            let name = nameSplit[0].trimmingCharacters(in: .whitespaces)
            let rest = nameSplit[1].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else {
                throw .malformedEntry(String(entry))
            }

            // The optional trailing `:packageName` is a `:Identifier` segment at
            // the very end (after any quotes in the requirement). Match it first
            // so we can strip it off before disambiguating URL vs path form.
            let (body, packageName): (String, String?) = if let tailMatch = rest.range(of: #":[A-Za-z_][A-Za-z0-9_-]*$"#, options: .regularExpression) {
                (
                    String(rest[rest.startIndex ..< tailMatch.lowerBound]).trimmingCharacters(in: .whitespaces),
                    String(rest[rest.index(after: tailMatch.lowerBound)...]).trimmingCharacters(in: .whitespaces)
                )
            } else {
                (rest, nil)
            }

            // Form discrimination: a URL has `://` or an scp-style prefix;
            // anything else is a path. The requirement starts at the first
            // `:` after the scheme separator or the scp-style host colon.
            let urlStart: String.Index? = if let schemeRange = body.range(of: "://") {
                schemeRange.upperBound
            } else if let prefix = body.range(of: scpStylePrefix, options: .regularExpression) {
                prefix.upperBound
            } else {
                nil
            }
            if let urlStart {
                guard let urlEnd = body[urlStart...].firstIndex(of: ":") else {
                    throw .missingRequirement(String(entry))
                }
                let url = String(body[body.startIndex ..< urlEnd])
                let requirement = body[body.index(after: urlEnd)...].trimmingCharacters(in: .whitespaces)
                guard !requirement.isEmpty else {
                    throw .missingRequirement(String(entry))
                }
                out.append(Self(name: name, url: url, requirement: String(requirement), packageName: packageName))
            } else {
                // Path form: no requirement. Whole body is the path.
                guard !body.isEmpty else {
                    throw .malformedURL(String(entry))
                }
                out.append(Self(name: name, url: body, requirement: "", packageName: packageName))
            }
        }
        return out
    }

    enum ParseError: Error, CustomStringConvertible {
        case malformedEntry(String)
        case malformedURL(String)
        case missingRequirement(String)

        var description: String {
            switch self {
            case let .malformedEntry(entry):
                "Invalid --external-packages entry '\(entry)'. Expected 'Name=url:requirement[:packageName]'."
            case let .malformedURL(entry):
                "Invalid --external-packages URL in '\(entry)'. Expected fully qualified URL."
            case let .missingRequirement(entry):
                "Invalid --external-packages entry '\(entry)'. Missing ':requirement' after URL."
            }
        }
    }

    /// Why this entry can't be emitted into a manifest or `project.yml`, or
    /// `nil` when it can. Catches what the parser can't see in a config file:
    /// an empty or malformed name, a URL entry without a requirement, and
    /// characters that would break the emitted string literal.
    var validationProblem: String? {
        let identifier = #"^[A-Za-z0-9_][A-Za-z0-9_.-]*$"#
        guard name.range(of: identifier, options: .regularExpression) != nil else {
            return "External package name '\(name)' is not a valid SPM product name (letters, digits, '_', '.', '-')."
        }
        if let packageName, packageName.range(of: identifier, options: .regularExpression) == nil {
            return "External package '\(name)' has an invalid package name '\(packageName)'."
        }
        guard !url.trimmingCharacters(in: .whitespaces).isEmpty, !url.contains("\""), !url.contains("\n") else {
            return "External package '\(name)' has an invalid location '\(url)'."
        }
        if !isLocalPath, requirement.trimmingCharacters(in: .whitespaces).isEmpty {
            return "External package '\(name)' has a URL but no version requirement (e.g. from: \"1.0.0\")."
        }
        return nil
    }

    /// Parses `--use-packages "Name[:version],Name[:version],..."` syntax.
    ///
    /// Each entry is either a bare identifier (uses registry's defaultVersion)
    /// or `Identifier:version` to override the version. Looks up each
    /// identifier in `KnownPackages.registry` and synthesizes an
    /// `ExternalPackage` entry (URL form, `from:` requirement, optional
    /// platform conditional preserved in the registry — generators consult
    /// the registry when emitting platform-conditional deps).
    ///
    /// Throws `UsePackagesParseError` for unknown identifiers (with a
    /// helpful "Did you mean…?" suggestion), for registry entries that are
    /// wired some other way, and for an empty identifier or version, so
    /// typos are caught at config time, not at xcodebuild time.
    static func parseUsePackages(_ input: String?) throws(UsePackagesParseError) -> [Self] {
        guard let input, !input.isEmpty else { return [] }
        var out: [Self] = []
        for entry in input.split(separator: ",") {
            let trimmed = entry.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard let first = parts.first, !first.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw .malformedEntry(trimmed)
            }
            let identifier = first.trimmingCharacters(in: .whitespaces)
            let versionOverride = parts.count == 2 ? parts[1].trimmingCharacters(in: .whitespaces) : nil
            if versionOverride?.isEmpty == true {
                throw .malformedEntry(trimmed)
            }

            guard let registryEntry = KnownPackages.registry[identifier], registryEntry.exposeViaUsePackages else {
                throw .unknownPackage(identifier: identifier, known: KnownPackages.allIdentifiers)
            }
            let version = versionOverride ?? registryEntry.defaultVersion
            out.append(Self(
                name: registryEntry.name,
                url: registryEntry.url,
                requirement: "from: \"\(version)\"",
                packageName: nil
            ))
        }
        return out
    }

    enum UsePackagesParseError: Error, CustomStringConvertible {
        case unknownPackage(identifier: String, known: [String])
        case malformedEntry(String)

        var description: String {
            switch self {
            case let .unknownPackage(identifier, known):
                Self.unknownPackageMessage(identifier: identifier, known: known)
            case let .malformedEntry(entry):
                "Invalid --use-packages entry '\(entry)'. Expected 'Name' or 'Name:version' (e.g. 'SnapKit' or 'LookinServer:1.3.0')."
            }
        }

        private static func unknownPackageMessage(identifier: String, known: [String]) -> String {
            let builtIns = "Built-in packages: \(known.joined(separator: ", "))."
            switch identifier {
            case "LumiKit":
                return "--use-packages doesn't wire LumiKit. Use --features lumiKit (theme, navigation, logging), "
                    + "or declare it with --external-packages and link products with --target-deps (e.g. LumiKitUI). \(builtIns)"
            case "ArgumentParser":
                return "--use-packages doesn't wire ArgumentParser: executable targets get it automatically. \(builtIns)"
            default:
                return "Unknown --use-packages identifier '\(identifier)'.\(Suggestion.didYouMean(identifier, in: known)) "
                    + "\(builtIns) Use --external-packages for packages outside the built-in registry."
            }
        }
    }
}
