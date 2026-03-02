import Foundation

enum Validators {

    // MARK: - Project Name

    /// Validate a project name.
    /// Rules: non-empty, starts with letter, alphanumeric + hyphens/underscores, max 50 chars.
    static func validateProjectName(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 50 else { return false }
        guard let first = name.first, first.isLetter else { return false }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return name.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    /// Sanitize a string into a valid project name.
    /// Strips invalid characters, ensures starts with letter, trims to 50 chars.
    static func sanitizeProjectName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        var sanitized = String(name.unicodeScalars.filter { allowed.contains($0) })

        // Ensure starts with a letter
        while let first = sanitized.first, !first.isLetter {
            sanitized.removeFirst()
        }

        // Trim to max length
        if sanitized.count > 50 {
            sanitized = String(sanitized.prefix(50))
        }

        return sanitized
    }

    // MARK: - Bundle ID

    /// Validate a bundle identifier.
    /// Rules: reverse-DNS, 2+ segments separated by dots, each segment starts with letter,
    /// segments contain only alphanumerics and hyphens.
    static func validateBundleID(_ id: String) -> Bool {
        let segments = id.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count >= 2 else { return false }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))

        for segment in segments {
            guard !segment.isEmpty else { return false }
            guard let first = segment.first, first.isLetter else { return false }
            guard segment.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        }

        return true
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

    /// Validate a deployment target version string.
    /// Rules: major.minor format, >= 18.0.
    static func validateDeploymentTarget(_ target: String) -> Bool {
        let parts = target.split(separator: ".")
        guard parts.count == 2,
              let major = Int(parts[0]),
              Int(parts[1]) != nil
        else { return false }

        return major >= 18
    }

    // MARK: - Default Bundle ID

    /// Generate a default bundle ID from a project name.
    static func defaultBundleID(for projectName: String) -> String {
        let sanitized = projectName.lowercased().replacingOccurrences(of: "_", with: "-")
        return "com.example.\(sanitized)"
    }
}
