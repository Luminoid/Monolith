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
        #expect(output.contains("import json, os, struct, sys"))
        #expect(!output.contains("import PIL"))
        #expect(!output.contains("from PIL"))
        #expect(!output.contains("pillow"))
    }

    @Test
    func `script judges the header and chunks, never the pixels`() {
        // Pixel rows are filtered (and possibly interlaced), so reading alpha
        // bytes straight out of IDAT gives a verdict that depends on the encoder.
        let output = AppIconValidationGenerator.generate(iconsetRelativePath: "x")
        #expect(output.contains("color_type in (4, 6)"))
        #expect(output.contains("tRNS"))
        #expect(!output.contains("zlib"))
        #expect(!output.contains("decompress"))
    }

    @Test
    func `script error message references App Store Connect`() {
        let output = AppIconValidationGenerator.generate(iconsetRelativePath: "x")
        #expect(output.contains("App Store Connect"))
        #expect(output.contains("transparency"))
    }

    // MARK: - Running the script

    @Test
    func `opaque RGB icon passes`() throws {
        let result = try runCheck(icons: [Icon(name: "icon.png", colorType: .rgb)])
        guard let result else { return }
        #expect(result.exitCode == 0, "\(result.stdout)")
        #expect(result.stdout.contains("App icon alpha check passed."))
    }

    @Test
    func `RGBA icon fails even when fully opaque`() throws {
        let result = try runCheck(icons: [Icon(name: "icon.png", colorType: .rgba)])
        guard let result else { return }
        #expect(result.exitCode == 1, "\(result.stdout)")
        #expect(result.stdout.contains("icon.png: has an alpha channel"))
    }

    @Test
    func `Sub-filtered opaque RGB icon passes`() throws {
        // The verdict must not depend on the encoder's row filter.
        let result = try runCheck(icons: [Icon(name: "icon.png", colorType: .rgb, subFiltered: true)])
        guard let result else { return }
        #expect(result.exitCode == 0, "\(result.stdout)")
    }

    @Test
    func `palette icon passes without tRNS and fails with it`() throws {
        let opaque = try runCheck(icons: [Icon(name: "icon.png", colorType: .palette)])
        guard let opaque else { return }
        #expect(opaque.exitCode == 0, "\(opaque.stdout)")

        let transparent = try runCheck(icons: [Icon(name: "icon.png", colorType: .palette, hasTRNS: true)])
        guard let transparent else { return }
        #expect(transparent.exitCode == 1, "\(transparent.stdout)")
        #expect(transparent.stdout.contains("icon.png: has a tRNS (transparency) chunk"))
    }

    @Test
    func `RGBA icon in the tinted slot is skipped`() throws {
        // The iOS 18 tinted appearance may carry alpha; light and dark may not.
        let contents = """
        {
          "images" : [
            { "filename" : "light.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
            {
              "appearances" : [ { "appearance" : "luminosity", "value" : "tinted" } ],
              "filename" : "tinted.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024"
            }
          ],
          "info" : { "author" : "xcode", "version" : 1 }
        }
        """
        let passing = try runCheck(
            icons: [Icon(name: "light.png", colorType: .rgb), Icon(name: "tinted.png", colorType: .rgba)],
            contentsJSON: contents
        )
        guard let passing else { return }
        #expect(passing.exitCode == 0, "\(passing.stdout)")

        let failing = try runCheck(
            icons: [Icon(name: "light.png", colorType: .rgba), Icon(name: "tinted.png", colorType: .rgba)],
            contentsJSON: contents
        )
        guard let failing else { return }
        #expect(failing.exitCode == 1, "\(failing.stdout)")
        #expect(failing.stdout.contains("light.png"))
        #expect(!failing.stdout.contains("tinted.png"))
    }

    @Test
    func `missing or malformed Contents json checks every PNG`() throws {
        let missing = try runCheck(icons: [Icon(name: "tinted.png", colorType: .rgba)])
        guard let missing else { return }
        #expect(missing.exitCode == 1, "\(missing.stdout)")

        let malformed = try runCheck(icons: [Icon(name: "tinted.png", colorType: .rgba)], contentsJSON: "[not json")
        guard let malformed else { return }
        #expect(malformed.exitCode == 1, "\(malformed.stdout)")
        #expect(!malformed.stdout.contains("Traceback"))
    }

    @Test
    func `the generated iconset Contents json passes with no images`() throws {
        // A fresh scaffold has slots but no PNGs yet.
        let result = try runCheck(icons: [], contentsJSON: AssetGenerator.generateAppIconContents())
        guard let result else { return }
        #expect(result.exitCode == 0, "\(result.stdout)")
    }

    // MARK: - Helpers

    /// PNG IHDR color types.
    private enum PNGColorType: Int {
        case rgb = 2
        case palette = 3
        case rgba = 6
    }

    private struct Icon {
        let name: String
        let colorType: PNGColorType
        var subFiltered = false
        var hasTRNS = false
    }

    /// Writes a 1024x1024 PNG of opaque white pixels (struct + zlib, no Pillow).
    /// Arguments: path, color type, row filter (0 None, 1 Sub), tRNS (0/1).
    private static let pngWriter = #"""
    import struct, sys, zlib
    path, color_type, filter_type, trns = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4] == "1"
    size = 1024
    channels = {2: 3, 3: 1, 6: 4}[color_type]
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    row = bytes([255] * (size * channels))
    if filter_type == 1:
        row = row[:channels] + bytes((row[i] - row[i - channels]) % 256 for i in range(channels, len(row)))
    raw = b"".join(bytes([filter_type]) + row for _ in range(size))
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, color_type, 0, 0, 0))
    if color_type == 3:
        png += chunk(b"PLTE", bytes([255, 255, 255]) * 256)
        if trns:
            png += chunk(b"tRNS", bytes([0]))
    png += chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)
    """#

    /// Builds an iconset in a scratch directory and runs the generated script
    /// on it. Nil when `/usr/bin/python3` (which the script itself calls) is
    /// missing, where the caller skips.
    private func runCheck(icons: [Icon], contentsJSON: String? = nil) throws -> ShellRunner.Output? {
        let python = "/usr/bin/python3"
        guard FileManager.default.isExecutableFile(atPath: python) else { return nil }

        let root = NSTemporaryDirectory() + "icon-check-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: root) }
        let iconset = root + "/AppIcon.appiconset"
        try FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

        let writer = root + "/write_png.py"
        try Self.pngWriter.write(toFile: writer, atomically: true, encoding: .utf8)
        for icon in icons {
            let written = try ShellRunner.run(
                executable: python,
                arguments: [writer, iconset + "/" + icon.name, "\(icon.colorType.rawValue)", icon.subFiltered ? "1" : "0", icon.hasTRNS ? "1" : "0"],
                captureStderr: true
            )
            try #require(written.exitCode == 0, "PNG writer failed: \(written.stderr)")
        }
        if let contentsJSON {
            try contentsJSON.write(toFile: iconset + "/Contents.json", atomically: true, encoding: .utf8)
        }

        let script = root + "/validate-app-icon.sh"
        try AppIconValidationGenerator.generate(iconsetRelativePath: "AppIcon.appiconset")
            .write(toFile: script, atomically: true, encoding: .utf8)
        // SRCROOT set explicitly, so a value inherited from Xcode can't redirect the check.
        return try ShellRunner.run(
            executable: "/usr/bin/env",
            arguments: ["SRCROOT=\(root)", "/bin/bash", script],
            captureStdout: true,
            captureStderr: true
        )
    }
}
