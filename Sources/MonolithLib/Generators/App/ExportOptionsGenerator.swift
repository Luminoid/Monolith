/// `ExportOptions.plist` for the fastlane `beta` lane's `build_app`. Exports
/// an App Store Connect `.ipa` locally (the default `export` destination) so
/// `upload_to_testflight` has a file to send; `destination: upload` would
/// upload during export and leave no `.ipa` behind.
enum ExportOptionsGenerator {
    static func generate() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>method</key>
            <string>app-store-connect</string>
            <key>signingStyle</key>
            <string>automatic</string>
            <key>uploadSymbols</key>
            <true/>
        </dict>
        </plist>

        """
    }
}
