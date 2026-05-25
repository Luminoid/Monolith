import Foundation
import Testing
@testable import MonolithLib

struct DesignSystemGeneratorTests {
    private func makeConfig(macCatalyst: Bool = false) -> AppConfig {
        AppConfig(
            name: "TestApp",
            bundleID: "com.test.app",
            deploymentTarget: "18.0",
            platforms: macCatalyst ? [.iPhone, .macCatalyst] : [.iPhone],
            projectSystem: .xcodeProj,
            tabs: [],
            primaryColor: "#007AFF",
            features: [],
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
