import Foundation
import Testing
@testable import MonolithLib

struct AssetGeneratorTests {
    @Test
    func `AccentColor contents emits hex RGB triple`() {
        let output = AssetGenerator.generateAccentColorContents(hex: "#7C5CFF")
        #expect(output.contains("\"red\" : \"0x7C\""))
        #expect(output.contains("\"green\" : \"0x5C\""))
        #expect(output.contains("\"blue\" : \"0xFF\""))
        #expect(output.contains("\"color-space\" : \"srgb\""))
    }

    @Test
    func `AccentColor falls back to default blue for invalid hex`() {
        let output = AssetGenerator.generateAccentColorContents(hex: "not-a-hex")
        #expect(output.contains("\"red\" : \"0x00\""))
        #expect(output.contains("\"green\" : \"0x7A\""))
        #expect(output.contains("\"blue\" : \"0xFF\""))
    }

    // MARK: - AppIcon

    @Test
    func `AppIcon emits three appearance variants (no-appearance plus dark plus tinted)`() {
        // Three entries: untyped (light/no-appearance), dark, tinted.
        // Pre-iOS-18 scaffolds emitted a single entry; the multi-variant
        // skeleton lets adopters drop dark/tinted PNGs without restructuring
        // the asset catalog.
        let output = AssetGenerator.generateAppIconContents()
        #expect(output.contains("\"appearance\" : \"luminosity\""))
        #expect(output.contains("\"value\" : \"dark\""))
        #expect(output.contains("\"value\" : \"tinted\""))
    }

    @Test
    func `AppIcon every variant declares 1024x1024 universal idiom`() {
        let output = AssetGenerator.generateAppIconContents()
        let sizeCount = output.components(separatedBy: "\"size\" : \"1024x1024\"").count - 1
        #expect(sizeCount == 3, "expected 3 size entries (one per variant), got \(sizeCount)")
        let idiomCount = output.components(separatedBy: "\"idiom\" : \"universal\"").count - 1
        #expect(idiomCount == 3)
        let platformCount = output.components(separatedBy: "\"platform\" : \"ios\"").count - 1
        #expect(platformCount == 3)
    }
}
