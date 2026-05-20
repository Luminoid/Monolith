import Foundation
import Testing
@testable import MonolithLib

struct AppIconValidationGeneratorTests {
    @Test
    func `script targets the requested iconset path`() {
        let output = AppIconValidationGenerator.generate(
            iconsetRelativePath: "MyApp/Resources/Assets.xcassets/AppIcon.appiconset"
        )
        #expect(output.contains("MyApp/Resources/Assets.xcassets/AppIcon.appiconset"))
    }

    @Test
    func `script is a bash script with strict mode`() {
        let output = AppIconValidationGenerator.generate(iconsetRelativePath: "Assets/AppIcon.appiconset")
        #expect(output.hasPrefix("#!/bin/bash"))
        #expect(output.contains("set -euo pipefail"))
    }

    @Test
    func `script handles missing iconset gracefully`() {
        let output = AppIconValidationGenerator.generate(iconsetRelativePath: "x")
        #expect(output.contains("skipping alpha check"))
    }

    @Test
    func `script uses python3 stdlib only — no pillow`() {
        let output = AppIconValidationGenerator.generate(iconsetRelativePath: "x")
        #expect(output.contains("/usr/bin/python3"))
        // PNG header parsing uses stdlib only (single-line `import os, struct, sys, zlib`).
        #expect(output.contains("os"))
        #expect(output.contains("struct"))
        #expect(output.contains("zlib"))
        #expect(!output.contains("import PIL"))
        #expect(!output.contains("from PIL"))
        #expect(!output.contains("pillow"))
    }

    @Test
    func `script flags RGBA and palette-tRNS as failures`() {
        let output = AppIconValidationGenerator.generate(iconsetRelativePath: "x")
        // color_type 4 (grayscale+alpha) and 6 (RGBA) — alpha bytes scanned
        #expect(output.contains("color_type in (4, 6)"))
        // color_type 3 (palette) — flagged when tRNS chunk present
        #expect(output.contains("color_type == 3"))
        #expect(output.contains("tRNS"))
    }

    @Test
    func `script error message references App Store Connect`() {
        let output = AppIconValidationGenerator.generate(iconsetRelativePath: "x")
        #expect(output.contains("App Store Connect"))
        #expect(output.contains("transparency"))
    }
}
