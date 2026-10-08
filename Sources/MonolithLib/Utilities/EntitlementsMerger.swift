import Foundation

/// Merges capability keys into an existing `.entitlements` plist instead of
/// replacing it, so `add` never drops what the project already declares
/// (an iCloud container, the CloudKit service, `aps-environment`, ...).
///
/// Merge rules: a key the file lacks is added; an array the file already has
/// gains the values it is missing (existing order kept, no duplicates); any
/// other key the file already has keeps its value.
enum EntitlementsMerger {
    static let appGroupsKey = "com.apple.security.application-groups"

    struct MergeError: Error, CustomStringConvertible {
        let description: String
    }

    /// The parsed dictionary of an entitlements plist.
    static func parse(_ plist: String, path: String) throws -> [String: Any] {
        let object: Any
        do {
            object = try PropertyListSerialization.propertyList(from: Data(plist.utf8), options: [], format: nil)
        } catch {
            throw MergeError(description: "\(path) is not a valid property list, so it was left unchanged: \(error.localizedDescription)")
        }
        guard let dictionary = object as? [String: Any] else {
            throw MergeError(description: "\(path) is not a dictionary property list, so it was left unchanged.")
        }
        return dictionary
    }

    /// `existing` with `additions` merged in, as an XML plist, and whether
    /// anything changed. `existing == nil` means there is no file yet.
    static func merge(
        _ additions: [String: Any],
        into existing: String?,
        path: String
    ) throws -> (content: String, changed: Bool) {
        var dictionary = try existing.map { try parse($0, path: path) } ?? [:]
        var changed = existing == nil
        for (key, value) in additions.sorted(by: { $0.key < $1.key }) {
            guard let current = dictionary[key] else {
                dictionary[key] = value
                changed = true
                continue
            }
            if let currentArray = current as? [Any], let newArray = value as? [Any] {
                var merged = currentArray
                for item in newArray where !merged.contains(where: { isEqual($0, item) }) {
                    merged.append(item)
                    changed = true
                }
                dictionary[key] = merged
            }
        }
        let data = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .xml, options: 0)
        guard let content = String(bytes: data, encoding: .utf8) else {
            throw MergeError(description: "\(path) could not be encoded as UTF-8, so it was left unchanged.")
        }
        return (content, changed)
    }

    /// Additions that put `appGroup` in the App Groups array.
    static func appGroupAdditions(_ appGroup: String) -> [String: Any] {
        [appGroupsKey: [appGroup]]
    }

    private static func isEqual(_ lhs: Any, _ rhs: Any) -> Bool {
        (lhs as? NSObject)?.isEqual(rhs) ?? false
    }
}
