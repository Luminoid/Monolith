import Foundation

/// Surgical, line-based edits to a XcodeGen `project.yml`.
///
/// Monolith doesn't depend on a YAML parser. These edits target the shapes
/// `XcodeGenGenerator` emits: column-0 top-level keys (`name:`, `options:`,
/// `settings:`, `targets:`, `packages:`, `schemes:`), block-style maps below
/// them, and a `targets:` map keyed by target name. Every edit first locates
/// the block it belongs to and inserts inside it, so the order of the
/// top-level blocks doesn't matter (a generated project.yml ends with
/// `schemes:`, after `packages:`). A trailing comment or trailing spaces after
/// a key don't hide it, comment lines never end a block, and a CRLF file keeps
/// its line endings.
///
/// Each editor is idempotent: applying twice produces the same file as
/// applying once. Each editor returns `Result` so the caller can distinguish
/// `applied` (file changed), `alreadyPresent` (no-op, idempotent skip), and
/// `failed` (couldn't locate the anchor; surface the reason to the user). On
/// `failed` the YAML is left unchanged.
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
        edit(&yaml) { lines in
            // Check the target first so a missing target leaves the file untouched.
            guard targetBlock(named: targetName, in: lines) != nil else {
                return .failed(targetNotFound(targetName))
            }
            let packageAdded = addPackage(lines: &lines, name: packageName, url: url, from: from)
            if case .failed = packageAdded { return packageAdded }
            let depAdded = addTargetDependency(lines: &lines, targetName: targetName, packageName: packageName, platforms: targetPlatforms)
            return combine(packageAdded, depAdded)
        }
    }

    /// Add a `packages:` entry at the end of the top-level `packages:` block,
    /// creating the block (before `schemes:`, else at the end of the file) when
    /// the project has none yet.
    static func addPackage(yaml: inout String, name: String, url: String, from: String) -> Result {
        edit(&yaml) { lines in
            addPackage(lines: &lines, name: name, url: url, from: from)
        }
    }

    /// Add an entry under `targets.<name>.dependencies`. Creates the
    /// `dependencies:` sub-block if absent.
    static func addTargetDependency(
        yaml: inout String,
        targetName: String,
        packageName: String,
        platforms: [String]? = nil
    ) -> Result {
        edit(&yaml) { lines in
            addTargetDependency(lines: &lines, targetName: targetName, packageName: packageName, platforms: platforms)
        }
    }

    // MARK: - Mac Catalyst

    /// Turn Mac Catalyst on for the given app target:
    /// - `macCatalyst: <iOS version>` under `options.deploymentTarget`;
    /// - `macCatalyst` in the target's `supportedDestinations` (added to an
    ///   existing list, such as `[iOS]`);
    /// - iPad (`2`) in a `TARGETED_DEVICE_FAMILY` the target sets without it,
    ///   since Mac Catalyst runs the iPad idiom;
    /// - `INFOPLIST_KEY_LSApplicationCategoryType` on the target when neither
    ///   it nor the project sets one (App Store Connect rejects a Mac upload
    ///   without a category);
    /// - when `catalystEntitlements` is given, a Mac-only
    ///   `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]` setting pointing at it;
    /// - `destinationFilters: [iOS]` on an embedded `<App>Widget` dependency,
    ///   since the iOS widget extension can't be embedded in a Mac build.
    static func enableMacCatalyst(yaml: inout String, targetName: String, catalystEntitlements: String? = nil) -> Result {
        edit(&yaml) { lines in
            guard targetBlock(named: targetName, in: lines) != nil else {
                return .failed(targetNotFound(targetName))
            }
            var steps = [addMacCatalystDeploymentTarget(lines: &lines)]
            steps.append(addMacCatalystDestination(lines: &lines, targetName: targetName))
            steps.append(addIPadDeviceFamily(lines: &lines, targetName: targetName))
            if !hasSetting(categoryKey, targetName: targetName, in: lines) {
                steps.append(addTargetSetting(categoryKey, value: defaultCategory, lines: &lines, targetName: targetName))
            }
            if let catalystEntitlements, !hasSetting(catalystEntitlementsKey, targetName: targetName, in: lines) {
                steps.append(addTargetSetting(catalystEntitlementsKey, value: catalystEntitlements, lines: &lines, targetName: targetName))
            }
            steps.append(filterWidgetDependencyToIOS(lines: &lines, targetName: targetName))
            return steps.reduce(.alreadyPresent, combine)
        }
    }

    // MARK: - Widget extension target

    /// Wire the entitlements file + widget-target dependency edge onto an
    /// existing app target. Idempotent. Caller is responsible for writing the
    /// entitlements file on disk and for adding the widget target itself via
    /// `addWidgetTarget`. An existing `CODE_SIGN_ENTITLEMENTS` setting is kept
    /// (the caller merges the App Group into the file it names). When the app
    /// also builds for Mac Catalyst, the widget dependency gets
    /// `destinationFilters: [iOS]`.
    static func wireAppForWidget(yaml: inout String, appName: String, entitlementsPath: String? = nil) -> Result {
        edit(&yaml) { lines in
            guard targetBlock(named: appName, in: lines) != nil else {
                return .failed(targetNotFound(appName))
            }
            var steps: [Result] = []
            if !hasSetting("CODE_SIGN_ENTITLEMENTS", targetName: appName, in: lines) {
                let path = entitlementsPath ?? "\(appName)/\(appName).entitlements"
                steps.append(addTargetSetting("CODE_SIGN_ENTITLEMENTS", value: path, lines: &lines, targetName: appName))
            }
            steps.append(addWidgetDependency(lines: &lines, appName: appName))
            return steps.reduce(.alreadyPresent, combine)
        }
    }

    /// Add a widget extension target at the end of the `targets:` map. Idempotent.
    static func addWidgetTarget(yaml: inout String, appName: String, bundleID: String) -> Result {
        edit(&yaml) { lines in
            let widgetTargetName = "\(appName)Widget"
            guard let targets = topLevelBlock("targets", in: lines), inlineValue(of: lines[targets.header]).isEmpty else {
                return .failed("`targets:` block not found in project.yml")
            }
            if targetBlock(named: widgetTargetName, in: lines) != nil {
                return .alreadyPresent
            }
            let entry = childIndent(of: targets, in: lines) ?? 2
            let body = [
                "\(widgetTargetName):",
                "  type: app-extension",
                "  platform: iOS",
                "  sources:",
                "    - \(widgetTargetName)",
                "    - path: \(appName)/Shared/AppGroup.swift",
                "  settings:",
                "    base:",
                "      PRODUCT_BUNDLE_IDENTIFIER: \(bundleID).Widget",
                "      INFOPLIST_FILE: \(widgetTargetName)/Info.plist",
                "      CODE_SIGN_ENTITLEMENTS: \(widgetTargetName)/\(widgetTargetName).entitlements",
                "      GENERATE_INFOPLIST_FILE: NO",
                "  dependencies:",
                "    - sdk: SwiftUI.framework",
                "    - sdk: WidgetKit.framework",
            ]
            lines.insert(contentsOf: [""] + body.map { pad(entry) + $0 }, at: targets.contentEnd)
            return .applied
        }
    }

    // MARK: - Reading

    /// The column-0 `key:` block of a project.yml: its header line through the
    /// line before the next column-0 key (or the end of the file). `nil` when
    /// the key is absent. Comment lines and blank lines never end a block, and
    /// a trailing comment after the header (`packages:  # deps`) still counts.
    static func topLevelBlockRange(_ key: String, in yaml: String) -> Range<String.Index>? {
        let rawLines = yaml.split(separator: "\n", omittingEmptySubsequences: false)
        let lines = rawLines.map { $0.hasSuffix("\r") ? String($0.dropLast()) : String($0) }
        guard let block = topLevelBlock(key, in: lines) else { return nil }
        let next = (block.header + 1 ..< lines.count).first { isTopLevelBoundary(lines[$0]) }
        let upper = next.map { rawLines[$0].startIndex } ?? yaml.endIndex
        return rawLines[block.header].startIndex ..< upper
    }

    /// The `PRODUCT_BUNDLE_IDENTIFIER` set on the named target, if any.
    static func bundleIdentifier(ofTarget targetName: String, in yaml: String) -> String? {
        setting("PRODUCT_BUNDLE_IDENTIFIER", ofTarget: targetName, in: yaml)
    }

    /// The value of a build setting on the named target (`settings.base`, or
    /// `settings` directly), unquoted, or `nil` when the target doesn't set it.
    static func setting(_ key: String, ofTarget targetName: String, in yaml: String) -> String? {
        let lines = Document(yaml).lines
        guard let target = targetBlock(named: targetName, in: lines) else { return nil }
        for index in target.header + 1 ..< target.contentEnd where Self.key(of: lines[index]) == key {
            let value = unquoted(inlineValue(of: lines[index]))
            return value.isEmpty ? nil : value
        }
        return nil
    }

    /// Whether the named target lists `macCatalyst` in `supportedDestinations`.
    static func targetSupportsMacCatalyst(_ targetName: String, in yaml: String) -> Bool {
        supportsMacCatalyst(targetName: targetName, in: Document(yaml).lines)
    }

    /// Whether `targets:` declares a target with this name.
    static func hasTarget(_ targetName: String, in yaml: String) -> Bool {
        targetBlock(named: targetName, in: Document(yaml).lines) != nil
    }
}

// MARK: - Edits on lines

private extension ProjectYamlEditor {
    static let categoryKey = "INFOPLIST_KEY_LSApplicationCategoryType"
    static let defaultCategory = "public.app-category.utilities"
    static let catalystEntitlementsKey = "CODE_SIGN_ENTITLEMENTS[sdk=macosx*]"

    static func targetNotFound(_ name: String) -> String {
        "target '\(name)' not found in project.yml"
    }

    /// Run `body` over the YAML's lines (CRLF normalized) and write the result
    /// back, restoring the line ending, only when it reports `.applied`.
    static func edit(_ yaml: inout String, _ body: (inout [String]) -> Result) -> Result {
        var document = Document(yaml)
        let result = body(&document.lines)
        if result == .applied {
            yaml = document.text
        }
        return result
    }

    /// `.failed` wins, then `.applied`; two no-ops stay a no-op.
    static func combine(_ lhs: Result, _ rhs: Result) -> Result {
        switch (lhs, rhs) {
        case (.failed, _): lhs
        case (_, .failed): rhs
        case (.applied, _), (_, .applied): .applied
        default: .alreadyPresent
        }
    }

    static func addPackage(lines: inout [String], name: String, url: String, from: String) -> Result {
        let entry = ["\(name):", "  url: \(url)", "  from: \(from)"]

        if let block = topLevelBlock("packages", in: lines) {
            let value = inlineValue(of: lines[block.header])
            if value == "{}" {
                lines[block.header] = "packages:"
            } else if !value.isEmpty {
                return .failed("the `packages:` block uses flow style; add \(name) to it by hand")
            }
            if childLine(name, of: block, in: lines) != nil {
                return .alreadyPresent
            }
            let indent = childIndent(of: block, in: lines) ?? 2
            lines.insert(contentsOf: entry.map { pad(indent) + $0 }, at: block.contentEnd)
            return .applied
        }

        let newBlock = ["packages:"] + entry.map { pad(2) + $0 }
        if let schemes = topLevelBlock("schemes", in: lines) {
            // Keep the comment lines that introduce `schemes:` attached to it.
            var insertAt = schemes.header
            while insertAt > 0, lines[insertAt - 1].hasPrefix("#") {
                insertAt -= 1
            }
            lines.insert(contentsOf: newBlock + [""], at: insertAt)
        } else {
            appendAtEnd(newBlock, to: &lines)
        }
        return .applied
    }

    static func addTargetDependency(lines: inout [String], targetName: String, packageName: String, platforms: [String]?) -> Result {
        guard let target = targetBlock(named: targetName, in: lines) else {
            return .failed(targetNotFound(targetName))
        }
        var item = ["- package: \(packageName)"]
        if let platforms, !platforms.isEmpty {
            item.append("  platforms: [\(platforms.joined(separator: ", "))]")
        }
        let isPackage = { (line: String) in listItem(line, key: "package") == packageName }
        return addDependencyItem(item, unlessAny: isPackage, lines: &lines, target: target)
    }

    /// Append a list item under the target's `dependencies:` (created when
    /// absent), unless a line already in that list satisfies `isPresent`.
    static func addDependencyItem(
        _ item: [String],
        unlessAny isPresent: (String) -> Bool,
        lines: inout [String],
        target: Block
    ) -> Result {
        let propertyIndent = childIndent(of: target, in: lines) ?? indent(of: lines[target.header]).map { $0 + 2 } ?? 4

        guard let dependencies = childLine("dependencies", of: target, in: lines) else {
            let newLines = [pad(propertyIndent) + "dependencies:"] + item.map { pad(propertyIndent + 2) + $0 }
            lines.insert(contentsOf: newLines, at: target.contentEnd)
            return .applied
        }

        let value = inlineValue(of: lines[dependencies])
        if value == "[]" {
            lines[dependencies] = pad(propertyIndent) + "dependencies:"
        } else if !value.isEmpty {
            return .failed("the target's `dependencies:` uses flow style; edit it by hand")
        }
        let list = block(at: dependencies, limit: target.contentEnd, in: lines)
        if (list.header + 1 ..< list.contentEnd).contains(where: { isPresent(lines[$0]) }) {
            return .alreadyPresent
        }
        let firstItem = (list.header + 1 ..< list.contentEnd).first { isListItem(lines[$0]) }
        let itemIndent = firstItem.flatMap { indent(of: lines[$0]) } ?? propertyIndent + 2
        lines.insert(contentsOf: item.map { pad(itemIndent) + $0 }, at: list.contentEnd)
        return .applied
    }

    static func addMacCatalystDeploymentTarget(lines: inout [String]) -> Result {
        guard let options = topLevelBlock("options", in: lines),
              let deploymentLine = childLine("deploymentTarget", of: options, in: lines)
        else {
            return .failed("options.deploymentTarget not found in project.yml")
        }
        let deployment = block(at: deploymentLine, limit: options.contentEnd, in: lines)
        if childLine("macCatalyst", of: deployment, in: lines) != nil {
            return .alreadyPresent
        }
        guard let iOSLine = childLine("iOS", of: deployment, in: lines) else {
            return .failed("options.deploymentTarget.iOS not found in project.yml")
        }
        let version = unquoted(inlineValue(of: lines[iOSLine]))
        lines.insert(pad(indent(of: lines[iOSLine]) ?? 4) + "macCatalyst: \(version)", at: iOSLine + 1)
        return .applied
    }

    static func addMacCatalystDestination(lines: inout [String], targetName: String) -> Result {
        guard let target = targetBlock(named: targetName, in: lines) else {
            return .failed(targetNotFound(targetName))
        }
        if let destinations = childLine("supportedDestinations", of: target, in: lines) {
            let value = inlineValue(of: lines[destinations])
            if value.hasPrefix("[") {
                let items = flowListItems(value)
                if items.contains("macCatalyst") { return .alreadyPresent }
                let key = lines[destinations].prefix { $0 != ":" }
                lines[destinations] = "\(key): [\((items + ["macCatalyst"]).joined(separator: ", "))]"
                return .applied
            }
            let list = block(at: destinations, limit: target.contentEnd, in: lines)
            let items = (list.header + 1 ..< list.contentEnd).compactMap { listItemValue(lines[$0]) }
            if items.contains("macCatalyst") { return .alreadyPresent }
            let itemIndent = (list.header + 1 ..< list.contentEnd).first { listItemValue(lines[$0]) != nil }
                .flatMap { indent(of: lines[$0]) } ?? (indent(of: lines[destinations]) ?? 4) + 2
            lines.insert(pad(itemIndent) + "- macCatalyst", at: list.contentEnd)
            return .applied
        }
        guard let platform = childLine("platform", of: target, in: lines),
              unquoted(inlineValue(of: lines[platform])) == "iOS"
        else {
            return .failed("target '\(targetName)' has no `platform: iOS` line")
        }
        lines.insert(pad(indent(of: lines[platform]) ?? 4) + "supportedDestinations: [iOS, macCatalyst]", at: platform + 1)
        return .applied
    }

    /// `TARGETED_DEVICE_FAMILY: "1"` → `"1,2"`. A target that doesn't set the
    /// key gets XcodeGen's default, which already includes iPad.
    static func addIPadDeviceFamily(lines: inout [String], targetName: String) -> Result {
        guard let target = targetBlock(named: targetName, in: lines),
              let line = (target.header + 1 ..< target.contentEnd).first(where: { key(of: lines[$0]) == "TARGETED_DEVICE_FAMILY" })
        else { return .alreadyPresent }
        let families = unquoted(inlineValue(of: lines[line])).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if families.contains("2") { return .alreadyPresent }
        let value = (families + ["2"]).sorted().joined(separator: ",")
        lines[line] = pad(indent(of: lines[line]) ?? 8) + "TARGETED_DEVICE_FAMILY: \"\(value)\""
        return .applied
    }

    /// Whether the target (or the project-level `settings:`) already sets `key`.
    static func hasSetting(_ key: String, targetName: String, in lines: [String]) -> Bool {
        var ranges: [Range<Int>] = []
        if let target = targetBlock(named: targetName, in: lines) {
            ranges.append(target.header + 1 ..< target.contentEnd)
        }
        if key != "CODE_SIGN_ENTITLEMENTS", key != catalystEntitlementsKey, let settings = topLevelBlock("settings", in: lines) {
            ranges.append(settings.header + 1 ..< settings.contentEnd)
        }
        return ranges.contains { range in range.contains { Self.key(of: lines[$0]) == key } }
    }

    /// Add `key: value` to the target's `settings.base` (or to `settings`
    /// itself when it lists build settings directly), creating `settings:` /
    /// `base:` when absent. Keys containing YAML indicator characters are quoted.
    static func addTargetSetting(_ key: String, value: String, lines: inout [String], targetName: String) -> Result {
        guard let target = targetBlock(named: targetName, in: lines) else {
            return .failed(targetNotFound(targetName))
        }
        let yamlKey = key.contains(where: { "[]{}*:#,".contains($0) }) ? "\"\(key)\"" : key
        let line = "\(yamlKey): \(value)"
        let propertyIndent = childIndent(of: target, in: lines) ?? (indent(of: lines[target.header]) ?? 2) + 2

        guard let settingsLine = childLine("settings", of: target, in: lines) else {
            let newLines = [pad(propertyIndent) + "settings:", pad(propertyIndent + 2) + "base:", pad(propertyIndent + 4) + line]
            lines.insert(contentsOf: newLines, at: target.contentEnd)
            return .applied
        }
        if inlineValue(of: lines[settingsLine]) == "{}" {
            lines[settingsLine] = pad(propertyIndent) + "settings:"
        } else if !inlineValue(of: lines[settingsLine]).isEmpty {
            return .failed("the target's `settings:` uses flow style; add \(key) by hand")
        }
        let settings = block(at: settingsLine, limit: target.contentEnd, in: lines)
        let settingIndent = childIndent(of: settings, in: lines) ?? propertyIndent + 2

        if let baseLine = childLine("base", of: settings, in: lines) {
            if inlineValue(of: lines[baseLine]) == "{}" {
                lines[baseLine] = pad(settingIndent) + "base:"
            }
            let base = block(at: baseLine, limit: settings.contentEnd, in: lines)
            let indent = childIndent(of: base, in: lines) ?? settingIndent + 2
            lines.insert(pad(indent) + line, at: base.contentEnd)
            return .applied
        }
        let groupingKeys: Set = ["configs", "groups", "configFiles"]
        let hasGrouping = (settings.header + 1 ..< settings.contentEnd).contains {
            Self.indent(of: lines[$0]) == settingIndent && groupingKeys.contains(Self.key(of: lines[$0]) ?? "")
        }
        if hasGrouping {
            // `configs:` / `groups:` alongside a missing `base:`: add one.
            lines.insert(contentsOf: [pad(settingIndent) + "base:", pad(settingIndent + 2) + line], at: settings.header + 1)
        } else {
            // Build settings listed directly under `settings:`.
            lines.insert(pad(settingIndent) + line, at: settings.contentEnd)
        }
        return .applied
    }

    /// Add `- target: <App>Widget` to the app's dependencies, filtered to iOS
    /// when the app also builds for Mac Catalyst.
    static func addWidgetDependency(lines: inout [String], appName: String) -> Result {
        guard let target = targetBlock(named: appName, in: lines) else {
            return .failed(targetNotFound(appName))
        }
        let widgetName = "\(appName)Widget"
        var item = ["- target: \(widgetName)"]
        let catalyst = supportsMacCatalyst(targetName: appName, in: lines)
        if catalyst {
            item.append("  destinationFilters: [iOS]")
        }
        let isWidget = { (line: String) in listItem(line, key: "target") == widgetName }
        let added = addDependencyItem(item, unlessAny: isWidget, lines: &lines, target: target)
        guard added == .alreadyPresent, catalyst else { return added }
        return filterWidgetDependencyToIOS(lines: &lines, targetName: appName)
    }

    /// Give an existing `- target: <App>Widget` dependency a
    /// `destinationFilters: [iOS]` line when the app builds for Mac Catalyst
    /// and the entry has no destination or platform filter yet.
    static func filterWidgetDependencyToIOS(lines: inout [String], targetName: String) -> Result {
        guard supportsMacCatalyst(targetName: targetName, in: lines),
              let target = targetBlock(named: targetName, in: lines),
              let dependencies = childLine("dependencies", of: target, in: lines)
        else { return .alreadyPresent }
        let list = block(at: dependencies, limit: target.contentEnd, in: lines)
        let widgetName = "\(targetName)Widget"
        guard let itemLine = (list.header + 1 ..< list.contentEnd).first(where: { listItem(lines[$0], key: "target") == widgetName }),
              let itemIndent = indent(of: lines[itemLine])
        else { return .alreadyPresent }

        // The item's own properties: following lines indented deeper than its `-`.
        var end = itemLine + 1
        var index = itemLine + 1
        while index < list.contentEnd {
            if let lineIndent = indent(of: lines[index]) {
                if lineIndent <= itemIndent { break }
                end = index + 1
            }
            index += 1
        }
        let filterKeys: Set = ["destinationFilters", "platformFilter", "platformFilters", "platforms"]
        let properties = (itemLine + 1 ..< end).compactMap { key(of: lines[$0]) }
        if properties.contains(where: filterKeys.contains) {
            return .alreadyPresent
        }
        lines.insert(pad(itemIndent + 2) + "destinationFilters: [iOS]", at: end)
        return .applied
    }

    static func supportsMacCatalyst(targetName: String, in lines: [String]) -> Bool {
        guard let target = targetBlock(named: targetName, in: lines),
              let destinations = childLine("supportedDestinations", of: target, in: lines)
        else { return false }
        let value = inlineValue(of: lines[destinations])
        if value.hasPrefix("[") {
            return flowListItems(value).contains("macCatalyst")
        }
        let list = block(at: destinations, limit: target.contentEnd, in: lines)
        return (list.header + 1 ..< list.contentEnd).contains { listItemValue(lines[$0]) == "macCatalyst" }
    }

    /// Append `newLines` after the last non-blank line, separated by a blank
    /// line, keeping the file's final newline.
    static func appendAtEnd(_ newLines: [String], to lines: inout [String]) {
        let lastContent = lines.lastIndex { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let insertAt = lastContent.map { $0 + 1 } ?? 0
        let separator = insertAt > 0 ? [""] : []
        lines.insert(contentsOf: separator + newLines, at: insertAt)
        if lines.last != "" {
            lines.append("")
        }
    }
}

// MARK: - Line structure

private extension ProjectYamlEditor {
    /// A project.yml split into lines, remembering its line ending.
    struct Document {
        var lines: [String]
        let lineEnding: String

        init(_ text: String) {
            lineEnding = text.contains("\r\n") ? "\r\n" : "\n"
            lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        }

        var text: String {
            lines.joined(separator: lineEnding)
        }
    }

    /// A mapping key's line (`header`) and the exclusive end of its content:
    /// the line after its last non-blank, non-comment child. Inserting at
    /// `contentEnd` appends to the block without swallowing the blank line or
    /// comments that introduce the next block.
    struct Block {
        let header: Int
        let contentEnd: Int
    }

    static func pad(_ count: Int) -> String {
        String(repeating: " ", count: count)
    }

    /// Leading spaces of a content line; `nil` for a blank or comment-only
    /// line, which neither opens nor closes a block.
    static func indent(of line: String) -> Int? {
        let rest = line.drop { $0 == " " }
        if rest.isEmpty || rest.hasPrefix("#") || rest.allSatisfy(\.isWhitespace) {
            return nil
        }
        return line.count - rest.count
    }

    /// The key of a `key:` or `key: value` line, quotes removed; `nil` for list
    /// items, blank lines, and comments.
    static func key(of line: String) -> String? {
        let rest = line.drop { $0 == " " }
        guard let first = rest.first, first != "-", first != "#" else { return nil }
        if first == "\"" || first == "'" {
            let body = rest.dropFirst()
            guard let close = body.firstIndex(of: first) else { return nil }
            let after = body[body.index(after: close)...].drop { $0 == " " }
            return after.hasPrefix(":") ? String(body[..<close]) : nil
        }
        guard let colon = colonIndex(in: rest) else { return nil }
        return String(rest[..<colon]).trimmingCharacters(in: .whitespaces)
    }

    /// The first `:` that ends a plain key (followed by a space or the end of the line).
    static func colonIndex(in text: Substring) -> Substring.Index? {
        var index = text.startIndex
        while index < text.endIndex {
            if text[index] == "#" { return nil }
            if text[index] == ":" {
                let next = text.index(after: index)
                if next == text.endIndex || text[next] == " " || text[next] == "\t" {
                    return index
                }
            }
            index = text.index(after: index)
        }
        return nil
    }

    /// What follows `key:` on its own line, trailing comment and spaces removed.
    static func inlineValue(of line: String) -> String {
        let rest = line.drop { $0 == " " }
        var valueStart: Substring.Index?
        if let first = rest.first, first == "\"" || first == "'" {
            let body = rest.dropFirst()
            if let close = body.firstIndex(of: first),
               let colon = body[body.index(after: close)...].firstIndex(of: ":") {
                valueStart = body.index(after: colon)
            }
        } else if let colon = colonIndex(in: rest) {
            valueStart = rest.index(after: colon)
        }
        guard let valueStart else { return "" }
        var value = String(rest[valueStart...])
        if let comment = value.range(of: " #") {
            value = String(value[..<comment.lowerBound])
        }
        return value.trimmingCharacters(in: .whitespaces)
    }

    static func unquoted(_ value: String) -> String {
        guard value.count >= 2, let first = value.first, first == "\"" || first == "'", value.last == first else {
            return value
        }
        return String(value.dropFirst().dropLast())
    }

    /// `[iOS, macCatalyst]` → `["iOS", "macCatalyst"]`.
    static func flowListItems(_ value: String) -> [String] {
        value.trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
            .split(separator: ",")
            .map { unquoted($0.trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.isEmpty }
    }

    /// The scalar of a `- value` list item line, or `nil`.
    static func listItemValue(_ line: String) -> String? {
        let rest = line.drop { $0 == " " }
        guard rest.hasPrefix("-") else { return nil }
        var value = String(rest.dropFirst())
        if let comment = value.range(of: " #") {
            value = String(value[..<comment.lowerBound])
        }
        return unquoted(value.trimmingCharacters(in: .whitespaces))
    }

    /// The value of `- key: value` (`- package: Lottie`), or `nil` when the
    /// line is not a list item opening with that key.
    static func listItem(_ line: String, key wanted: String) -> String? {
        let rest = line.drop { $0 == " " }
        guard rest.hasPrefix("-") else { return nil }
        let item = " " + rest.dropFirst()
        guard key(of: item) == wanted else { return nil }
        return unquoted(inlineValue(of: item))
    }

    /// A column-0 line that starts the next top-level key.
    static func isTopLevelBoundary(_ line: String) -> Bool {
        indent(of: line) == 0 && !isListItem(line)
    }

    static func isListItem(_ line: String) -> Bool {
        line.drop { $0 == " " }.hasPrefix("-")
    }

    static func topLevelBlock(_ key: String, in lines: [String]) -> Block? {
        guard let header = lines.indices.first(where: { indent(of: lines[$0]) == 0 && Self.key(of: lines[$0]) == key }) else {
            return nil
        }
        return block(at: header, limit: lines.count, in: lines)
    }

    /// The block opened by the key at `header`: every following line indented
    /// deeper than it, up to `limit`. A list written at the key's own indent
    /// (`deps:` then `- a` at the same column) belongs to the key too.
    static func block(at header: Int, limit: Int, in lines: [String]) -> Block {
        let headerIndent = indent(of: lines[header]) ?? 0
        let allowsSameIndentList = inlineValue(of: lines[header]).isEmpty
        var contentEnd = header + 1
        var index = header + 1
        while index < limit {
            if let lineIndent = indent(of: lines[index]) {
                let isSameIndentItem = allowsSameIndentList && lineIndent == headerIndent && isListItem(lines[index])
                if lineIndent <= headerIndent, !isSameIndentItem { break }
                contentEnd = index + 1
            }
            index += 1
        }
        return Block(header: header, contentEnd: contentEnd)
    }

    /// Indent of the block's first child line, or `nil` for an empty block.
    static func childIndent(of block: Block, in lines: [String]) -> Int? {
        (block.header + 1 ..< block.contentEnd).lazy.compactMap { indent(of: lines[$0]) }.first
    }

    /// The line of the block's direct child `key:`.
    static func childLine(_ key: String, of block: Block, in lines: [String]) -> Int? {
        guard let indent = childIndent(of: block, in: lines) else { return nil }
        return (block.header + 1 ..< block.contentEnd).first {
            Self.indent(of: lines[$0]) == indent && Self.key(of: lines[$0]) == key
        }
    }

    /// The named target's block inside the top-level `targets:` map.
    static func targetBlock(named name: String, in lines: [String]) -> Block? {
        guard let targets = topLevelBlock("targets", in: lines),
              let header = childLine(name, of: targets, in: lines)
        else { return nil }
        return block(at: header, limit: targets.contentEnd, in: lines)
    }
}
