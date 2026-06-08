import Foundation

/// Surgical, text-based edits to a XcodeGen `project.yml`.
///
/// Monolith doesn't depend on a YAML parser — these edits target the small
/// number of known shapes Monolith itself generates (see `XcodeGenGenerator`):
/// a top-level `name:`, an `options:` block, a `targets:` map keyed by the app
/// name, and an optional top-level `packages:` map.
///
/// Each editor is idempotent: applying twice produces the same file as
/// applying once. Each editor returns `Result` so the caller can distinguish
/// `applied` (file changed), `alreadyPresent` (no-op, idempotent skip), and
/// `failed` (couldn't locate the anchor — surface the reason to the user).
enum ProjectYamlEditor {
    enum Result: Equatable {
        case applied
        case alreadyPresent
        case failed(String)
    }

    // MARK: - SPM package + dependency

    /// Add an SPM package + per-target dependency entry. If either is already
    /// present it is left alone (idempotent).
    static func addPackageDependency(
        yaml: inout String,
        targetName: String,
        packageName: String,
        url: String,
        from: String,
        targetPlatforms: [String]? = nil
    ) -> Result {
        let packageAdded = addPackage(yaml: &yaml, name: packageName, url: url, from: from)
        let depAdded = addTargetDependency(
            yaml: &yaml,
            targetName: targetName,
            packageName: packageName,
            platforms: targetPlatforms
        )

        switch (packageAdded, depAdded) {
        case let (.failed(msg), _), let (_, .failed(msg)): return .failed(msg)
        case (.alreadyPresent, .alreadyPresent): return .alreadyPresent
        default: return .applied
        }
    }

    /// Append a `packages:` entry. Creates the top-level `packages:` block if
    /// it doesn't exist yet.
    static func addPackage(yaml: inout String, name: String, url: String, from: String) -> Result {
        if yaml.contains("\n  \(name):\n") || yaml.hasSuffix("\n  \(name):\n") {
            return .alreadyPresent
        }

        let entry = """
          \(name):
            url: \(url)
            from: \(from)
        """

        if yaml.range(of: "\npackages:\n") != nil || yaml.hasPrefix("packages:\n") {
            // Append to existing block (end of file is fine since packages is the last block).
            if !yaml.hasSuffix("\n") { yaml.append("\n") }
            yaml.append(entry)
            yaml.append("\n")
            return .applied
        }

        // Create new top-level block at end of file.
        if !yaml.hasSuffix("\n") { yaml.append("\n") }
        yaml.append("\n")
        yaml.append("packages:\n")
        yaml.append(entry)
        yaml.append("\n")
        return .applied
    }

    /// Add an entry under `targets.<name>.dependencies`. Creates the
    /// `dependencies:` sub-block if absent.
    static func addTargetDependency(
        yaml: inout String,
        targetName: String,
        packageName: String,
        platforms: [String]? = nil
    ) -> Result {
        guard let targetRange = findTargetBlock(in: yaml, name: targetName) else {
            return .failed("target '\(targetName)' not found in project.yml")
        }
        let targetBlock = String(yaml[targetRange])

        // Already present?
        if targetBlock.contains("- package: \(packageName)\n")
            || targetBlock.contains("- package: \(packageName)$") {
            return .alreadyPresent
        }

        // Build new dependency line(s).
        var entry = "      - package: \(packageName)\n"
        if let platforms, !platforms.isEmpty {
            entry += "        platforms: [\(platforms.joined(separator: ", "))]\n"
        }

        // Find or insert `    dependencies:` line under this target.
        if let depRange = targetBlock.range(of: "\n    dependencies:\n") {
            // Insert immediately after `    dependencies:` line, before any existing entries.
            let absoluteIdx = yaml.index(targetRange.lowerBound, offsetBy: targetBlock.distance(from: targetBlock.startIndex, to: depRange.upperBound))
            yaml.insert(contentsOf: entry, at: absoluteIdx)
            return .applied
        }

        // No dependencies block — insert before the next target / end of targets.
        let appendIdx = targetRange.upperBound
        let block = "    dependencies:\n" + entry
        yaml.insert(contentsOf: block, at: appendIdx)
        return .applied
    }

    // MARK: - Mac Catalyst

    /// Toggle Mac Catalyst on for the given app target:
    /// - Adds `macCatalyst: <iOSVersion>` under `options.deploymentTarget`.
    /// - Adds `supportedDestinations: [iOS, macCatalyst]` under the target.
    static func enableMacCatalyst(yaml: inout String, targetName: String) -> Result {
        // 1. deploymentTarget.macCatalyst
        if yaml.contains("    macCatalyst:") {
            // Already configured at the options level. Continue to step 2 only.
        } else {
            // Find `    iOS: <version>` under `  deploymentTarget:` and inject below it.
            let pattern = #"(?m)^( {4})iOS: ([0-9.]+)$"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return .failed("could not parse deploymentTarget block")
            }
            let nsYaml = yaml as NSString
            guard let match = regex.firstMatch(in: yaml, range: NSRange(location: 0, length: nsYaml.length)) else {
                return .failed("deploymentTarget.iOS not found")
            }
            let version = nsYaml.substring(with: match.range(at: 2))
            let lineEnd = nsYaml.range(of: "\n", range: NSRange(location: match.range.upperBound, length: nsYaml.length - match.range.upperBound))
            let insertLoc = lineEnd.location == NSNotFound ? nsYaml.length : lineEnd.location
            let insertion = "\n    macCatalyst: \(version)"
            yaml = nsYaml.replacingCharacters(in: NSRange(location: insertLoc, length: 0), with: insertion)
        }

        // 2. supportedDestinations under the target.
        if yaml.contains("    supportedDestinations:") {
            return .alreadyPresent
        }
        guard let targetRange = findTargetBlock(in: yaml, name: targetName) else {
            return .failed("target '\(targetName)' not found in project.yml")
        }
        let targetBlock = String(yaml[targetRange])
        // Insert after the `    platform: iOS` line.
        guard let platformRange = targetBlock.range(of: "\n    platform: iOS\n") else {
            return .failed("target '\(targetName)' has no `platform: iOS` line")
        }
        let absoluteIdx = yaml.index(targetRange.lowerBound, offsetBy: targetBlock.distance(from: targetBlock.startIndex, to: platformRange.upperBound))
        yaml.insert(contentsOf: "    supportedDestinations: [iOS, macCatalyst]\n", at: absoluteIdx)
        return .applied
    }

    // MARK: - Widget extension target

    /// Wire the App-Group entitlements file + widget-target dependency edge
    /// onto an existing app target. Idempotent. Caller is responsible for
    /// writing the entitlements file on disk and for adding the widget target
    /// itself via `addWidgetTarget`.
    static func wireAppForWidget(yaml: inout String, appName: String) -> Result {
        guard let targetRange = findTargetBlock(in: yaml, name: appName) else {
            return .failed("target '\(appName)' not found in project.yml")
        }
        let targetBlock = String(yaml[targetRange])
        let entitlementsLine = "        CODE_SIGN_ENTITLEMENTS: \(appName)/\(appName).entitlements\n"
        let widgetDepLine = "      - target: \(appName)Widget\n"

        var anyChange = false

        // 1. Inject CODE_SIGN_ENTITLEMENTS into the app target's `settings.base`
        //    block. The XcodeGenGenerator always emits a `      base:` line
        //    immediately after `    settings:`, so we anchor on that.
        if !targetBlock.contains("CODE_SIGN_ENTITLEMENTS:") {
            guard let baseRange = targetBlock.range(of: "\n      base:\n") else {
                return .failed("target '\(appName)' has no `settings.base` block")
            }
            let absoluteIdx = yaml.index(
                targetRange.lowerBound,
                offsetBy: targetBlock.distance(from: targetBlock.startIndex, to: baseRange.upperBound)
            )
            yaml.insert(contentsOf: entitlementsLine, at: absoluteIdx)
            anyChange = true
        }

        // 2. Add `- target: <name>Widget` to the app's dependencies. Re-scan
        //    because the previous insertion shifted offsets.
        guard let refreshedRange = findTargetBlock(in: yaml, name: appName) else {
            return .failed("target '\(appName)' moved unexpectedly during edit")
        }
        let refreshedBlock = String(yaml[refreshedRange])
        if !refreshedBlock.contains("- target: \(appName)Widget") {
            if let depsRange = refreshedBlock.range(of: "\n    dependencies:\n") {
                let absoluteIdx = yaml.index(
                    refreshedRange.lowerBound,
                    offsetBy: refreshedBlock.distance(from: refreshedBlock.startIndex, to: depsRange.upperBound)
                )
                yaml.insert(contentsOf: widgetDepLine, at: absoluteIdx)
            } else {
                let block = "    dependencies:\n" + widgetDepLine
                yaml.insert(contentsOf: block, at: refreshedRange.upperBound)
            }
            anyChange = true
        }

        return anyChange ? .applied : .alreadyPresent
    }

    /// Append a widget extension target to the `targets:` map. Idempotent.
    static func addWidgetTarget(yaml: inout String, appName: String, bundleID: String) -> Result {
        let widgetTargetName = "\(appName)Widget"
        if yaml.contains("\n  \(widgetTargetName):\n") {
            return .alreadyPresent
        }
        guard yaml.range(of: "\ntargets:\n") != nil || yaml.hasPrefix("targets:\n") else {
            return .failed("`targets:` block not found in project.yml")
        }

        let widgetBlock = """

          \(widgetTargetName):
            type: app-extension
            platform: iOS
            sources:
              - \(widgetTargetName)
              - path: \(appName)/Shared/AppGroup.swift
            settings:
              base:
                PRODUCT_BUNDLE_IDENTIFIER: \(bundleID).Widget
                INFOPLIST_FILE: \(widgetTargetName)/Info.plist
                CODE_SIGN_ENTITLEMENTS: \(widgetTargetName)/\(widgetTargetName).entitlements
                GENERATE_INFOPLIST_FILE: NO
            dependencies:
              - sdk: SwiftUI.framework
              - sdk: WidgetKit.framework

        """

        // Insert before `packages:` if it exists, else append to file.
        if let pkgRange = yaml.range(of: "\npackages:\n") {
            yaml.insert(contentsOf: widgetBlock, at: pkgRange.lowerBound)
        } else {
            if !yaml.hasSuffix("\n") { yaml.append("\n") }
            yaml.append(widgetBlock)
        }
        return .applied
    }

    // MARK: - Helpers

    /// Locate `  <name>:\n` at indent level 2 (target map entry) and return the
    /// range of the whole target's block (up to the next sibling target or end
    /// of `targets:` section / end of file).
    private static func findTargetBlock(in yaml: String, name: String) -> Range<String.Index>? {
        let header = "\n  \(name):\n"
        guard let headerRange = yaml.range(of: header) else { return nil }
        let blockStart = yaml.index(after: headerRange.lowerBound) // skip the leading \n so block begins at "  name:"

        // Block ends at: next indent-2 line that starts a new key (`^  [A-Za-z]`)
        // OR at start of next top-level block (`^[A-Za-z]`) OR end of file.
        let searchStart = headerRange.upperBound
        let nsRest = yaml[searchStart...]
        var idx = nsRest.startIndex
        while idx < nsRest.endIndex {
            // Find next line start.
            guard let lineEnd = nsRest[idx...].firstIndex(of: "\n") else { break }
            let nextLineStart = nsRest.index(after: lineEnd)
            if nextLineStart >= nsRest.endIndex { break }
            // Check the next line's first non-space chars.
            let line = nsRest[nextLineStart...]
            if line.hasPrefix("  "), !line.hasPrefix("    "), !line.hasPrefix("   ") {
                // Indent-2 line — sibling target, block ends here.
                let yamlIndex = yaml.index(searchStart, offsetBy: nsRest.distance(from: nsRest.startIndex, to: nextLineStart))
                return blockStart ..< yamlIndex
            }
            if let first = line.first, !first.isWhitespace {
                // Indent-0 line — new top-level block, targets section ends.
                let yamlIndex = yaml.index(searchStart, offsetBy: nsRest.distance(from: nsRest.startIndex, to: nextLineStart))
                return blockStart ..< yamlIndex
            }
            idx = nextLineStart
        }
        return blockStart ..< yaml.endIndex
    }
}
