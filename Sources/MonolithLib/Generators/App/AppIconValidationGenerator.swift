/// Generates a script that fails when the app's 1024x1024 icon would be
/// rejected by App Store Connect for transparency.
///
/// App Store Connect rejects a 1024x1024 icon that has an alpha channel at
/// upload time, even when every pixel is opaque; `xcodebuild archive` exits 0
/// even when this is going to fail. Running the check from `make check` (or a
/// build phase) surfaces the problem locally before submission.
///
/// The check reads the PNG header and chunk list, never the pixels, so the
/// verdict doesn't depend on how the encoder filtered or interlaced the rows:
/// 1. PNG color type 6 (RGBA) or 4 (grayscale + alpha): an alpha channel.
/// 2. A `tRNS` chunk: a palette (PNG-8) or single-color transparency. An
///    opaque palette PNG (no `tRNS`) passes.
///
/// It skips the files in the iOS 18 tinted appearance slot and the macOS idiom
/// slots, which may carry alpha, as listed by the iconset's `Contents.json`
/// (every PNG is checked when that file is missing or unreadable).
///
/// The script is always fatal: it exits 1 on any failure. It is
/// dependency-free (`/usr/bin/python3` with the stdlib only; no Pillow).
enum AppIconValidationGenerator {
    /// Generate a shell script suitable for an Xcode Run Script build phase
    /// (or for direct CI invocation).
    /// - Parameter iconsetRelativePath: path from `${SRCROOT}` to the
    ///   `.appiconset` directory, e.g. `MyApp/Resources/Assets.xcassets/AppIcon.appiconset`.
    static func generate(iconsetRelativePath: String) -> String {
        """
        #!/bin/bash
        #
        # Validates the app icon has no transparency. App Store Connect rejects a
        # 1024x1024 icon with an alpha channel, even a fully opaque one.
        #
        # Run from `make check`, as an Xcode "Run Script" build phase, or from CI.
        # Exits 1 when a 1024x1024 PNG declares transparency: an alpha channel
        # (RGBA, grayscale + alpha) or a tRNS chunk (palette or single-color
        # transparency). Opaque RGB and opaque palette PNGs pass. The tinted
        # (iOS 18) and macOS slots in Contents.json may carry alpha and are skipped.

        set -euo pipefail

        ICONSET_REL="\(iconsetRelativePath)"
        ICONSET="${SRCROOT:-$(pwd)}/${ICONSET_REL}"

        if [ ! -d "$ICONSET" ]; then
            echo "warning: AppIcon.appiconset not found at $ICONSET, skipping alpha check"
            exit 0
        fi

        ICONSET="$ICONSET" /usr/bin/python3 <<'PYEOF'
        import json, os, struct, sys

        iconset = os.environ["ICONSET"]


        def may_have_alpha(image):
            \"""Slots allowed to carry alpha: the tinted appearance and macOS icons.\"""
            if image.get("idiom") == "mac":
                return True
            for appearance in image.get("appearances") or []:
                if isinstance(appearance, dict) and appearance.get("appearance") == "luminosity" and appearance.get("value") == "tinted":
                    return True
            return False


        def skipped_filenames():
            try:
                with open(os.path.join(iconset, "Contents.json"), encoding="utf-8") as f:
                    images = json.load(f).get("images") or []
            except (OSError, ValueError, AttributeError):
                return set()
            return {
                image["filename"]
                for image in images
                if isinstance(image, dict) and image.get("filename") and may_have_alpha(image)
            }


        def transparency(data):
            \"""Why a 1024x1024 PNG fails the check, or None when it passes.\"""
            if data[:8] != b"\\x89PNG\\r\\n\\x1a\\n" or data[12:16] != b"IHDR":
                return None
            width, height = struct.unpack(">II", data[16:24])
            if (width, height) != (1024, 1024):
                return None
            color_type = data[25]
            if color_type in (4, 6):
                return "has an alpha channel"
            idx = 8
            while idx + 8 <= len(data):
                length = struct.unpack(">I", data[idx:idx + 4])[0]
                chunk_type = data[idx + 4:idx + 8]
                if chunk_type == b"tRNS":
                    return "has a tRNS (transparency) chunk"
                if chunk_type in (b"IDAT", b"IEND"):
                    break  # tRNS always comes before the image data
                idx += 12 + length
            return None


        skipped = skipped_filenames()
        failures = []
        for fname in sorted(os.listdir(iconset)):
            if not fname.lower().endswith(".png") or fname in skipped:
                continue
            with open(os.path.join(iconset, fname), "rb") as f:
                reason = transparency(f.read())
            if reason:
                failures.append(f"{fname}: {reason}")

        if failures:
            print("error: app icon has transparency (App Store Connect will reject):")
            for failure in failures:
                print(f"  {failure}")
            print("Flatten over an opaque background and export as RGB without alpha. For palette PNGs, strip the tRNS chunk.")
            sys.exit(1)
        PYEOF

        echo "App icon alpha check passed."

        """
    }
}
