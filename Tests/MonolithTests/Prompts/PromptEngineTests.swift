import Foundation
import Testing
@testable import MonolithLib

/// Tests for the pure-logic surfaces of `PromptEngine`. The raw-terminal
/// readline (`wizardReadLine`) is excluded because it requires a TTY and
/// can't be exercised under `swift test`. The Feature parsing, tab parsing,
/// and back-command detection are pure and trivially testable.
struct PromptEngineTests {
    // MARK: - parseFeatures

    @Test
    func `parseFeatures returns empty set for nil input`() {
        let result: Set<AppFeature> = PromptEngine.parseFeatures(nil)
        #expect(result.isEmpty)
    }

    @Test
    func `parseFeatures returns empty set for empty string`() {
        let result: Set<AppFeature> = PromptEngine.parseFeatures("")
        #expect(result.isEmpty)
    }

    @Test
    func `parseFeatures parses comma-separated names`() {
        let result: Set<AppFeature> = PromptEngine.parseFeatures("swiftData,lumiKit")
        #expect(result == [.swiftData, .lumiKit])
    }

    @Test
    func `parseFeatures trims whitespace`() {
        let result: Set<AppFeature> = PromptEngine.parseFeatures(" swiftData , lumiKit ")
        #expect(result == [.swiftData, .lumiKit])
    }

    @Test
    func `parseFeatures ignores unknown names`() {
        let result: Set<AppFeature> = PromptEngine.parseFeatures("swiftData,unknownFeature,lumiKit")
        #expect(result == [.swiftData, .lumiKit])
    }

    @Test
    func `parseFeatures works for PackageFeature too`() {
        let result: Set<PackageFeature> = PromptEngine.parseFeatures("strictConcurrency,devTooling")
        #expect(result == [.strictConcurrency, .devTooling])
    }

    @Test
    func `parseFeatures works for CLIFeature too`() {
        let result: Set<CLIFeature> = PromptEngine.parseFeatures("argumentParser,gitHooks")
        #expect(result == [.argumentParser, .gitHooks])
    }

    @Test
    func `parseFeatures is case-sensitive`() {
        // Feature raw values use camelCase; uppercased variants should not match.
        let result: Set<AppFeature> = PromptEngine.parseFeatures("SwiftData")
        #expect(result.isEmpty)
    }

    // MARK: - parseTabs

    @Test
    func `parseTabs parses Name:icon pairs`() {
        let tabs = PromptEngine.parseTabs("Home:house,Settings:gearshape")
        #expect(tabs.count == 2)
        #expect(tabs[0].name == "Home")
        #expect(tabs[0].icon == "house")
        #expect(tabs[1].name == "Settings")
        #expect(tabs[1].icon == "gearshape")
    }

    @Test
    func `parseTabs tolerates surrounding whitespace`() {
        let tabs = PromptEngine.parseTabs("  Home : house , Settings : gearshape  ")
        #expect(tabs.count == 2)
        #expect(tabs[0].name == "Home")
        #expect(tabs[0].icon == "house")
        #expect(tabs[1].name == "Settings")
        #expect(tabs[1].icon == "gearshape")
    }

    @Test
    func `parseTabs returns empty for empty input`() {
        #expect(PromptEngine.parseTabs("").isEmpty)
    }

    @Test
    func `parseTabs skips malformed segments`() {
        // "NoColon" has no colon — must be dropped, not silently parsed.
        let tabs = PromptEngine.parseTabs("Home:house,NoColon,Settings:gearshape")
        #expect(tabs.count == 2)
        #expect(tabs.map(\.name) == ["Home", "Settings"])
    }

    @Test
    func `parseTabs skips segments with empty name or icon`() {
        let tabs = PromptEngine.parseTabs(":icon,Name:,Home:house")
        #expect(tabs.count == 1)
        #expect(tabs[0].name == "Home")
    }

    // MARK: - isBackCommand

    @Test
    func `isBackCommand recognizes literal angle bracket`() {
        #expect(PromptEngine.isBackCommand("<"))
        #expect(PromptEngine.isBackCommand("  <  "))
    }

    @Test
    func `isBackCommand recognizes back word`() {
        #expect(PromptEngine.isBackCommand("back"))
        #expect(PromptEngine.isBackCommand("BACK"))
        #expect(PromptEngine.isBackCommand("  back  "))
    }

    @Test
    func `isBackCommand rejects unrelated input`() {
        #expect(!PromptEngine.isBackCommand(""))
        #expect(!PromptEngine.isBackCommand("backward"))
        #expect(!PromptEngine.isBackCommand("yes"))
        #expect(!PromptEngine.isBackCommand(">"))
    }
}
