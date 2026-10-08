import Testing
@testable import MonolithLib

/// The raw-mode line editor, fed the bytes a terminal sends.
struct LineEditorTests {
    /// Feeds `bytes` and returns the editor and the last event.
    private func feed(_ bytes: [UInt8], backEnabled: Bool = true) -> (editor: LineEditor, last: LineEditor.Event) {
        var editor = LineEditor(backEnabled: backEnabled)
        var last = LineEditor.Event.none
        for byte in bytes {
            last = editor.feed(byte)
        }
        return (editor, last)
    }

    private func bytes(_ text: String) -> [UInt8] {
        Array(text.utf8)
    }

    private let left: [UInt8] = [0x1B, 0x5B, 0x44]
    private let right: [UInt8] = [0x1B, 0x5B, 0x43]
    private let up: [UInt8] = [0x1B, 0x5B, 0x41]
    private let backspace: [UInt8] = [0x7F]

    // MARK: - UTF-8

    /// Regression: bytes outside printable ASCII were dropped, so "José"
    /// became "Jos" and "李纯厚" became empty.
    @Test
    func `non-ASCII text is kept`() {
        #expect(feed(bytes("José")).editor.text == "José")
        #expect(feed(bytes("李纯厚")).editor.text == "李纯厚")
        #expect(feed(bytes("Zoë 🚀")).editor.text == "Zoë 🚀")
        #expect(feed(bytes("Jos") + [0xC3, 0xA9, 0x0D]).last == .submit("José"))
    }

    @Test
    func `a malformed UTF-8 sequence is dropped`() {
        // A lone continuation byte, then a lead byte cut off by ASCII.
        #expect(feed([0x41, 0x80, 0xE6, 0x42]).editor.text == "AB")
        // An overlong encoding of "/".
        #expect(feed([0xC0, 0xAF]).editor.text.isEmpty)
    }

    @Test
    func `backspace removes a whole character`() {
        #expect(feed(bytes("李纯厚") + backspace).editor.text == "李纯")
        // "é" as e + combining acute accent is one character.
        #expect(feed(bytes("Jose\u{301}") + backspace).editor.text == "Jos")
    }

    @Test
    func `the cursor moves over characters`() {
        let edited = feed(bytes("李厚") + left + bytes("纯") + right + bytes("!"))
        #expect(edited.editor.text == "李纯厚!")
        #expect(edited.editor.right.isEmpty)
    }

    // MARK: - Escape sequences

    /// Regression: the ESC handler read exactly two bytes, so Delete
    /// (`ESC [ 3 ~`) left `~` and Ctrl-Right (`ESC [ 1 ; 5 C`) left `;5C`.
    @Test
    func `longer escape sequences don't leak into the text`() {
        let delete: [UInt8] = [0x1B, 0x5B, 0x33, 0x7E]
        let ctrlRight: [UInt8] = [0x1B, 0x5B, 0x31, 0x3B, 0x35, 0x43]
        let f5: [UInt8] = [0x1B, 0x5B, 0x31, 0x35, 0x7E]
        #expect(feed(bytes("abc") + left + left + delete).editor.text == "ac")
        #expect(feed(bytes("abc") + ctrlRight + f5).editor.text == "abc")
    }

    @Test
    func `home and end move to the ends of the line`() {
        let home: [UInt8] = [0x1B, 0x5B, 0x48]
        let end: [UInt8] = [0x1B, 0x5B, 0x46]
        let homeTilde: [UInt8] = [0x1B, 0x5B, 0x31, 0x7E]
        let ss3Home: [UInt8] = [0x1B, 0x4F, 0x48]
        #expect(feed(bytes("bc") + home + bytes("a") + end + bytes("d")).editor.text == "abcd")
        #expect(feed(bytes("bc") + homeTilde + bytes("a")).editor.text == "abc")
        #expect(feed(bytes("bc") + ss3Home + bytes("a")).editor.text == "abc")
        #expect(feed(bytes("bc") + [0x01] + bytes("a") + [0x05] + bytes("d")).editor.text == "abcd")
    }

    @Test
    func `the up arrow goes back only when allowed`() {
        #expect(feed(up).last == .back)
        #expect(feed(up, backEnabled: false).last == .none)
        #expect(feed([0x1B, 0x4F, 0x41]).last == .back)
    }

    @Test
    func `control keys`() {
        #expect(feed([0x03]).last == .interrupt)
        #expect(feed([0x04]).last == .interrupt)
        #expect(feed(bytes("ab") + [0x0A]).last == .submit("ab"))
        #expect(feed(bytes("abc") + left + [0x15]).editor.text == "c")
        #expect(feed(bytes("abc") + left + [0x0B]).editor.text == "ab")
        #expect(feed([0x09, 0x07]).editor.text.isEmpty)
    }
}
