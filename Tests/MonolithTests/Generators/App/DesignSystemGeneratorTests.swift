import Foundation
import Testing
@testable import MonolithLib

struct DesignSystemGeneratorTests {
    private func makeConfig(macCatalyst: Bool = false, lumiKit: Bool = false) -> AppConfig {
        AppConfig(
            name: "TestApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: macCatalyst ? [.iPhone, .macCatalyst] : [.iPhone],
            projectSystem: .xcodeProj,
            tabs: [],
            primaryColor: "#007AFF",
            features: lumiKit ? [.lumiKit] : [],
            author: "Test",
            licenseType: .proprietary
        )
    }

    @Test
    func `generates DesignSystem enum`() {
        let output = DesignSystemGenerator.generate(config: makeConfig())
        #expect(output.contains("enum DesignSystem"))
        #expect(output.contains("import UIKit"))
    }

    @Test
    func `has Cell sub-enum with heights`() {
        let output = DesignSystemGenerator.generate(config: makeConfig())
        #expect(output.contains("enum Cell"))
        #expect(output.contains("defaultHeight"))
        #expect(output.contains("compactHeight"))
        #expect(output.contains("comfortableHeight"))
        #expect(output.contains("thumbnailSize"))
    }

    @Test
    func `standalone Layout defines cardPadding`() {
        // Non-LumiKit view controllers pad their content with `DesignSystem.Layout.cardPadding`.
        let output = DesignSystemGenerator.generate(config: makeConfig())
        #expect(output.contains("        static let cardPadding: CGFloat = 16"))
    }

    @Test
    func `LumiKit companion leaves row heights to LMKLayout`() {
        // LMKLayout.rowHeight / .rowHeightCompact / .rowHeightComfortable are
        // 60 / 44 / 72; a second copy here would drift from LumiKit's.
        let output = DesignSystemGenerator.generate(config: makeConfig(lumiKit: true))
        for duplicate in ["defaultHeight", "compactHeight", "comfortableHeight", "LumiKit doesn't"] {
            #expect(!output.contains(duplicate), "Duplicated LumiKit token: \(duplicate)")
        }
        #expect(output.contains("Row heights → `LMKLayout.rowHeight` / `.rowHeightCompact` / `.rowHeightComfortable`"))
        // Tokens LumiKit has no equivalent for stay.
        #expect(output.contains("static let thumbnailSize: CGFloat = 44"))
        #expect(output.contains("static let largeThumbnailSize: CGFloat = 56"))
        #expect(output.contains("static let separatorInset: CGFloat = 16"))
        #expect(output.contains("enum List {"))
        // Layout tokens come from LumiKit, so the companion has no Layout enum.
        #expect(!output.contains("enum Layout"))
    }

    @Test
    func `has Layout sub-enum with corner radii`() {
        let output = DesignSystemGenerator.generate(config: makeConfig())
        #expect(output.contains("enum Layout"))
        #expect(output.contains("cardCornerRadius"))
        #expect(output.contains("buttonCornerRadius"))
        #expect(output.contains("sheetCornerRadius"))
    }

    @Test
    func `has Icon sub-enum with size scale`() {
        let output = DesignSystemGenerator.generate(config: makeConfig())
        #expect(output.contains("enum Icon"))
        #expect(output.contains("static let small"))
        #expect(output.contains("static let medium"))
        #expect(output.contains("static let large"))
    }

    @Test
    func `has Button sub-enum with HIG-compliant min height`() {
        let output = DesignSystemGenerator.generate(config: makeConfig())
        #expect(output.contains("enum Button"))
        #expect(output.contains("minHeight: CGFloat = 44"))
    }

    @Test
    func `has Touch enum enforcing HIG minimum`() {
        let output = DesignSystemGenerator.generate(config: makeConfig())
        #expect(output.contains("enum Touch"))
        #expect(output.contains("minimumTargetSize: CGFloat = 44"))
    }

    @Test
    func `has Animation enum`() {
        let output = DesignSystemGenerator.generate(config: makeConfig())
        #expect(output.contains("enum Animation"))
        #expect(output.contains("shortDuration"))
        #expect(output.contains("springDamping"))
    }

    @Test
    func `MARK sections present`() {
        let output = DesignSystemGenerator.generate(config: makeConfig())
        #expect(output.contains("// MARK: - Cell"))
        #expect(output.contains("// MARK: - Layout"))
        #expect(output.contains("// MARK: - Icon"))
        #expect(output.contains("// MARK: - Touch"))
    }

    @Test
    func `DesignSystem does not duplicate AppConstants MacWindow`() {
        // Mac Catalyst window bounds live ONLY in `AppConstants.MacWindow`
        // (canonical) — never re-emitted as `DesignSystem.MacWindow`. The
        // previous behavior created two sources of truth that adopters could
        // read from inconsistently; the rule is that there is exactly one
        // canonical home for window-bound constants, and it's `AppConstants`.
        let withMac = DesignSystemGenerator.generate(config: makeConfig(macCatalyst: true))
        let withoutMac = DesignSystemGenerator.generate(config: makeConfig(macCatalyst: false))
        #expect(!withMac.contains("enum MacWindow"))
        #expect(!withoutMac.contains("enum MacWindow"))
        #expect(!withMac.contains("static let toolbarHeight"))
    }
}
