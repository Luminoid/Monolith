import Foundation

/// The line being typed at a raw-mode wizard prompt, fed one byte at a time.
///
/// Text is kept as two strings around the cursor, so the cursor, Backspace,
/// and Delete move over whole grapheme clusters ("é" written as e + U+0301
/// is one step). Bytes of a multi-byte UTF-8 character are held until the
/// character is complete. Escape sequences are read to their final byte, so
/// a key the editor doesn't handle (F1, Ctrl-arrow) is dropped whole instead
/// of leaking `~` or `;5C` into the text.
struct LineEditor {
    /// What the caller does after a byte.
    enum Event: Equatable {
        /// Nothing visible changed.
        case none
        /// Redraw the line from `left` and `right`.
        case redraw
        /// Enter: the line is done.
        case submit(String)
        /// Up arrow, when back navigation is allowed.
        case back
        /// Ctrl-C or Ctrl-D: cancel.
        case interrupt
    }

    private enum EscapeState {
        case none
        /// ESC read; the next byte picks the sequence kind.
        case escape
        /// `ESC [`: parameter and intermediate bytes until a final byte.
        case controlSequence([UInt8])
        /// `ESC O`: one final byte follows.
        case singleShift
    }

    /// Text before the cursor.
    private(set) var left = ""
    /// Text after the cursor.
    private(set) var right = ""
    /// Whether the up arrow is reported as `.back`.
    let backEnabled: Bool

    private var escape = EscapeState.none
    private var pendingUTF8: [UInt8] = []
    private var expectedUTF8Length = 0

    /// Longest `ESC [` sequence kept before it is dropped as garbage.
    private static let maxSequenceLength = 16

    init(backEnabled: Bool) {
        self.backEnabled = backEnabled
    }

    /// The whole line.
    var text: String {
        left + right
    }

    mutating func feed(_ byte: UInt8) -> Event {
        switch escape {
        case .none:
            break
        case .escape:
            switch byte {
            case 0x5B: escape = .controlSequence([])
            case 0x4F: escape = .singleShift
            default: escape = .none // Alt+key: ignored
            }
            return .none
        case let .controlSequence(parameters):
            if (0x40 ... 0x7E).contains(byte) {
                escape = .none
                return controlSequence(final: byte, parameters: parameters)
            }
            escape = parameters.count < Self.maxSequenceLength ? .controlSequence(parameters + [byte]) : .none
            return .none
        case .singleShift:
            escape = .none
            return controlSequence(final: byte, parameters: [])
        }

        if byte >= 0x80 {
            return utf8Byte(byte)
        }
        pendingUTF8 = []
        return asciiByte(byte)
    }

    /// A byte below 0x80: a key, or the start of an escape sequence.
    private mutating func asciiByte(_ byte: UInt8) -> Event {
        switch byte {
        case 0x0A, 0x0D: // Enter
            return .submit(text)
        case 0x7F, 0x08: // Backspace
            guard !left.isEmpty else { return .none }
            left.removeLast()
            return .redraw
        case 0x1B:
            escape = .escape
            return .none
        case 0x03, 0x04: // Ctrl-C, Ctrl-D
            return .interrupt
        case 0x01: // Ctrl-A
            return moveHome()
        case 0x05: // Ctrl-E
            return moveEnd()
        case 0x15: // Ctrl-U: delete before the cursor
            guard !left.isEmpty else { return .none }
            left = ""
            return .redraw
        case 0x0B: // Ctrl-K: delete after the cursor
            guard !right.isEmpty else { return .none }
            right = ""
            return .redraw
        case 0x20 ... 0x7E:
            left.unicodeScalars.append(Unicode.Scalar(byte))
            return .redraw
        default:
            return .none
        }
    }

    // MARK: - Escape Sequences

    private mutating func controlSequence(final: UInt8, parameters: [UInt8]) -> Event {
        // A modifier (`1;5C` for Ctrl-Right) or any other parameter means a
        // key this editor doesn't handle, except the `~` keys below.
        switch (final, parameters) {
        case (0x41, []): // Up
            return backEnabled ? .back : .none
        case (0x43, []): // Right
            guard let next = right.first else { return .none }
            right.removeFirst()
            left.append(next)
            return .redraw
        case (0x44, []): // Left
            guard let previous = left.last else { return .none }
            left.removeLast()
            right.insert(previous, at: right.startIndex)
            return .redraw
        case (0x48, []): // Home
            return moveHome()
        case (0x46, []): // End
            return moveEnd()
        case (0x7E, [0x33]): // Delete: ESC [ 3 ~
            guard !right.isEmpty else { return .none }
            right.removeFirst()
            return .redraw
        case (0x7E, [0x31]), (0x7E, [0x37]): // Home: ESC [ 1 ~ or ESC [ 7 ~
            return moveHome()
        case (0x7E, [0x34]), (0x7E, [0x38]): // End: ESC [ 4 ~ or ESC [ 8 ~
            return moveEnd()
        default:
            return .none
        }
    }

    private mutating func moveHome() -> Event {
        guard !left.isEmpty else { return .none }
        right = left + right
        left = ""
        return .redraw
    }

    private mutating func moveEnd() -> Event {
        guard !right.isEmpty else { return .none }
        left += right
        right = ""
        return .redraw
    }

    // MARK: - UTF-8

    /// Collects the bytes of one multi-byte character and inserts it once
    /// complete. A malformed sequence is dropped.
    private mutating func utf8Byte(_ byte: UInt8) -> Event {
        switch byte {
        case 0xC2 ... 0xDF, 0xE0 ... 0xEF, 0xF0 ... 0xF4: // lead byte
            pendingUTF8 = [byte]
            expectedUTF8Length = byte >= 0xF0 ? 4 : byte >= 0xE0 ? 3 : 2
            return .none
        case 0x80 ... 0xBF where !pendingUTF8.isEmpty: // continuation
            pendingUTF8.append(byte)
            guard pendingUTF8.count == expectedUTF8Length else { return .none }
            // An invalid sequence (an overlong form, a surrogate) doesn't decode.
            let decoded = String(bytes: pendingUTF8, encoding: .utf8)
            pendingUTF8 = []
            guard let decoded else { return .none }
            left += decoded
            return .redraw
        default:
            pendingUTF8 = []
            return .none
        }
    }
}
