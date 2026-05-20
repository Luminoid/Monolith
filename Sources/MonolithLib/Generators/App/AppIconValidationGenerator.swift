/// Generates a build-phase script that fails the build if the app's 1024x1024
/// icon would be rejected by App Store Connect for transparency.
///
/// App Store Connect rejects 1024x1024 icons with an alpha channel at upload
/// time; `xcodebuild archive` exits 0 even when this is going to fail. Running
/// the check as a build phase surfaces the problem locally before submission.
///
/// Apple's rejection rule covers three cases:
/// 1. PNG color type 6 (RGBA) — straightforward alpha channel
/// 2. PNG color type 4 (grayscale + alpha) — uncommon but possible
/// 3. PNG color type 3 (palette / PNG-8) with a `tRNS` chunk — palette PNGs
///    declare transparency via a separate chunk. Opaque palette PNGs (no `tRNS`)
///    are the format both shipped Lumi apps use and pass review.
///
/// The generated script is dependency-free (`/usr/bin/python3` with PNG header
/// parsing in the stdlib) — no `brew install pillow` needed.
enum AppIconValidationGenerator {
    /// Generate a shell script suitable for an Xcode Run Script build phase
    /// (or for direct CI invocation).
    /// - Parameter iconsetRelativePath: path from `${SRCROOT}` to the
    ///   `.appiconset` directory, e.g. `MyApp/Resources/Assets.xcassets/AppIcon.appiconset`.
    static func generate(iconsetRelativePath: String) -> String {
        """
        #!/bin/bash
        #
        # Validates the app icon has no transparency. App Store Connect rejects
        # 1024x1024 icons with an alpha channel.
        #
        # Run as an Xcode "Run Script" build phase, or invoke from CI.
        # Conservative: fails only when transparency is actually declared
        # (RGBA / grayscale+alpha / palette+tRNS). Opaque palette PNGs pass.

        set -euo pipefail

        ICONSET_REL="\(iconsetRelativePath)"
        ICONSET="${SRCROOT:-$(pwd)}/${ICONSET_REL}"

        if [ ! -d "$ICONSET" ]; then
            echo "warning: AppIcon.appiconset not found at $ICONSET, skipping alpha check"
            exit 0
        fi

        ICONSET="$ICONSET" /usr/bin/python3 <<'PYEOF'
        import os, struct, sys, zlib

        iconset = os.environ["ICONSET"]
        failures = []

        for fname in sorted(os.listdir(iconset)):
            if not fname.endswith(".png"):
                continue
            full = os.path.join(iconset, fname)
            with open(full, "rb") as f:
                data = f.read()
            if data[:8] != b"\\x89PNG\\r\\n\\x1a\\n":
                continue

            width, height = struct.unpack(">II", data[16:24])
            color_type = data[25]
            if (width, height) != (1024, 1024):
                continue

            has_trns = False
            idat = b""
            idx = 8
            while idx < len(data):
                length = struct.unpack(">I", data[idx:idx+4])[0]
                chunk_type = data[idx+4:idx+8]
                chunk_data = data[idx+8:idx+8+length]
                if chunk_type == b"tRNS":
                    has_trns = True
                elif chunk_type == b"IDAT":
                    idat += chunk_data
                elif chunk_type == b"IEND":
                    break
                idx += 8 + length + 4

            has_translucent_pixel = False
            if color_type in (4, 6) and idat:
                raw = zlib.decompress(idat)
                bpp = 4 if color_type == 6 else 2
                stride = 1 + width * bpp
                alpha_off = bpp - 1
                for row in range(height):
                    row_start = row * stride + 1
                    for col in range(width):
                        if raw[row_start + col * bpp + alpha_off] < 255:
                            has_translucent_pixel = True
                            break
                    if has_translucent_pixel:
                        break

            if has_translucent_pixel or (color_type == 3 and has_trns):
                failures.append(fname)

        if failures:
            print("error: app icon has transparency (App Store Connect will reject):")
            for f in failures:
                print(f"  {f}")
            print("Flatten over an opaque background. For palette PNGs, strip the tRNS chunk.")
            sys.exit(1)
        PYEOF

        echo "App icon alpha check passed."

        """
    }
}
