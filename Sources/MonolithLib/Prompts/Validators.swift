import Foundation

enum Validators {
    /// Maximum allowed length for a project name.
    static let maxProjectNameLength = 50

    // MARK: - Project Name

    /// Swift keywords and built-in type names that cannot serve as project /
    /// target / module names. Using one of these produces source files that
    /// don't compile (`import Self`, `struct Type {}`, etc.) — better to
    /// catch at config time than at first build. Case-sensitive match: Swift
    /// distinguishes `class` (keyword) from `Class` (legal identifier), so
    /// only the actual conflicts get rejected.
    static let reservedNames: Set<String> = [
        // Declaration keywords
        "associatedtype", "class", "deinit", "enum", "extension", "fileprivate",
        "func", "import", "init", "inout", "internal", "let", "open", "operator",
        "private", "precedencegroup", "protocol", "public", "rethrows", "static",
        "struct", "subscript", "typealias", "var",
        // Statement keywords
        "break", "case", "catch", "continue", "default", "defer", "do", "else",
        "fallthrough", "for", "guard", "if", "in", "repeat", "return", "throw",
        "switch", "where", "while",
        // Expression / type keywords
        "Any", "as", "false", "is", "nil", "self", "Self", "super", "throws",
        "true", "try", "Type", "Protocol",
        // Contextual / concurrency keywords commonly used in types
        "actor", "async", "await", "Sendable", "any", "some", "each",
        // Built-in stdlib types that would shadow themselves
        "String", "Int", "Double", "Bool", "Array", "Dictionary", "Set",
        "Optional", "Result", "Void", "Never", "Error",
    ]

    /// Validate a project name for `kind`. See `projectNameProblem(_:kind:)`.
    static func validateProjectName(_ name: String, kind: ProjectType) -> Bool {
        projectNameProblem(name, kind: kind) == nil
    }

    /// Why `name` can't name a `kind` project, or `nil` when it can.
    ///
    /// An app name becomes Swift type and module names (`<Name>CoreDataStack`,
    /// `@testable import <Name>`), so it must be a Swift identifier:
    /// `[A-Za-z][A-Za-z0-9_]*`. Package and CLI names are also SwiftPM product
    /// and executable names, where `-` is conventional, so they allow it; the
    /// generators derive UpperCamelCase type names from them. All kinds are
    /// ASCII only, at most `maxProjectNameLength` characters, never a Swift
    /// reserved word, and never contain a path separator.
    static func projectNameProblem(_ name: String, kind: ProjectType) -> String? {
        let label = kind == .cli ? "CLI" : kind.rawValue
        guard !name.isEmpty else {
            return "The \(label) name is empty. \(projectNameRule(for: kind))"
        }
        if reservedNames.contains(name) {
            return "Invalid \(label) name '\(name)': '\(name)' is a Swift reserved word and would produce code that doesn't compile."
        }
        let allowsHyphen = kind != .app
        guard name.count <= maxProjectNameLength, isASCIIIdentifier(name, allowHyphen: allowsHyphen) else {
            return "Invalid \(label) name '\(name)'. \(projectNameRule(for: kind))"
        }
        return nil
    }

    /// The naming rule for `kind`, phrased for error messages and wizard hints.
    static func projectNameRule(for kind: ProjectType) -> String {
        switch kind {
        case .app:
            "App names must be Swift identifiers: an ASCII letter, then letters, digits, or underscores, "
                + "at most \(maxProjectNameLength) characters (e.g. MyApp)."
        case .package:
            "Package names start with an ASCII letter, then letters, digits, underscores, or hyphens, "
                + "at most \(maxProjectNameLength) characters (e.g. MyPackage)."
        case .cli:
            "CLI names start with an ASCII letter, then letters, digits, underscores, or hyphens, "
                + "at most \(maxProjectNameLength) characters (e.g. my-tool)."
        }
    }

    /// Whether `string` is `[A-Za-z][A-Za-z0-9_]*`, with `-` also allowed
    /// after the first character when `allowHyphen` is set.
    static func isASCIIIdentifier(_ string: String, allowHyphen: Bool = false) -> Bool {
        guard let first = string.unicodeScalars.first, isASCIILetter(first) else { return false }
        return string.unicodeScalars.dropFirst().allSatisfy { scalar in
            isASCIILetter(scalar) || isASCIIDigit(scalar) || scalar == "_" || (allowHyphen && scalar == "-")
        }
    }

    private static func isASCIILetter(_ scalar: Unicode.Scalar) -> Bool {
        (scalar >= "a" && scalar <= "z") || (scalar >= "A" && scalar <= "Z")
    }

    private static func isASCIIDigit(_ scalar: Unicode.Scalar) -> Bool {
        scalar >= "0" && scalar <= "9"
    }

    // MARK: - Bundle ID

    /// Validate a bundle identifier.
    /// Rules: reverse-DNS, 2+ segments separated by dots, each segment starts
    /// with an ASCII letter and contains only ASCII letters, digits, and hyphens.
    static func validateBundleID(_ id: String) -> Bool {
        let segments = id.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count >= 2 else { return false }
        return segments.allSatisfy { isASCIIIdentifier(String($0), allowHyphen: true) && !$0.contains("_") }
    }

    // MARK: - Hex Color

    /// Validate a hex color string.
    /// Rules: starts with #, followed by exactly 6 hex digits (case-insensitive).
    static func validateHexColor(_ hex: String) -> Bool {
        guard hex.hasPrefix("#"), hex.count == 7 else { return false }

        let digits = hex.dropFirst()
        let hexChars = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        return digits.unicodeScalars.allSatisfy { hexChars.contains($0) }
    }

    // MARK: - Deployment Target

    /// The lowest iOS major version a generated app may target: the major of
    /// `Defaults.deploymentTarget`.
    static var minimumDeploymentMajor: Int {
        Defaults.deploymentTarget.split(separator: ".").first.flatMap { Int($0) } ?? 18
    }

    /// Validate a deployment target version string.
    /// Rules: major.minor format, major at least `minimumDeploymentMajor`.
    static func validateDeploymentTarget(_ target: String) -> Bool {
        let parts = target.split(separator: ".")
        guard parts.count == 2,
              let major = Int(parts[0]),
              Int(parts[1]) != nil
        else { return false }

        return major >= minimumDeploymentMajor
    }

    // MARK: - Platform Version

    /// Validate a platform version string (major.minor numeric format).
    static func validatePlatformVersion(_ version: String) -> Bool {
        let parts = version.split(separator: ".")
        guard parts.count == 2,
              Int(parts[0]) != nil,
              Int(parts[1]) != nil
        else { return false }
        return true
    }

    // MARK: - Locale

    /// Validate a locale identifier for the String Catalog: a 2–3 letter
    /// language code, then optional `-` or `_` separated script, region, or
    /// variant subtags (`en`, `zh-Hans`, `pt_BR`, `es-419`).
    static func validateLocale(_ locale: String) -> Bool {
        let subtags = locale.split(separator: "-", omittingEmptySubsequences: false)
            .flatMap { $0.split(separator: "_", omittingEmptySubsequences: false) }
        guard let language = subtags.first,
              (2 ... 3).contains(language.count),
              language.unicodeScalars.allSatisfy(isASCIILetter)
        else { return false }
        return subtags.dropFirst().allSatisfy { subtag in
            (2 ... 8).contains(subtag.count) && subtag.unicodeScalars.allSatisfy { isASCIILetter($0) || isASCIIDigit($0) }
        }
    }

    // MARK: - Default Bundle ID

    /// Generate a default bundle ID from a project name.
    static func defaultBundleID(for projectName: String) -> String {
        let sanitized = projectName.lowercased().replacingOccurrences(of: "_", with: "-")
        return "com.example.\(sanitized)"
    }
}
