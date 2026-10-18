/// A mouse report from a terminal with mouse reporting on (`?1000` with SGR
/// encoding `?1006`, or the older X10 encoding).
struct MouseEvent: Hashable, Sendable {
    /// A mouse button.
    enum Button: Hashable, Sendable {
        case left, middle, right
    }

    /// The direction of one wheel notch.
    enum ScrollDirection: Hashable, Sendable {
        case up, down, left, right
    }

    /// What happened.
    enum Kind: Hashable, Sendable {
        /// A button went down.
        case press(Button)
        /// A button went up. X10 reports don't say which, so the button is `nil` there.
        case release(Button?)
        /// The pointer moved, with a button held or not (only with `?1002` or `?1003`).
        case move
        /// One wheel notch.
        case scroll(ScrollDirection)
    }

    /// What happened.
    var kind: Kind
    /// The cell under the pointer, zero-based (the terminal reports from 1).
    var location: Point
    /// Shift, Option (meta) and Control held during the event.
    var modifiers: EventModifiers
}

/// Decoding of mouse reports.
enum MouseReports {
    /// Decodes an SGR report, the body of `ESC [ < b ; x ; y M` (press) or `… m` (release).
    static func sgrEvents(body: Substring, final: UInt8) -> [InputEvent] {
        let fields = body.split(separator: ";", omittingEmptySubsequences: false).map { Int($0) }
        guard fields.count == 3, let code = fields[0], let column = fields[1], let row = fields[2] else { return [] }
        let isRelease = final == UInt8(ascii: "m")
        return event(code: code, column: column, row: row, isRelease: isRelease).map { [.mouse($0)] } ?? []
    }

    /// Decodes an X10 report, the three bytes after `ESC [ M`, each offset by 32.
    static func x10Events(_ bytes: [UInt8]) -> [InputEvent] {
        guard bytes.count == 3 else { return [] }
        let code = Int(bytes[0]) - 32
        let isRelease = code & 0b11 == 3 && code & 64 == 0
        return event(code: code, column: Int(bytes[1]) - 32, row: Int(bytes[2]) - 32, isRelease: isRelease)
            .map { [.mouse($0)] } ?? []
    }

    /// The event for button code `code` at the one-based `column` and `row`.
    static func event(code: Int, column: Int, row: Int, isRelease: Bool) -> MouseEvent? {
        // Codes from 128 are extra buttons (back, forward), which Stipple doesn't map.
        guard (0..<128).contains(code), column >= 1, row >= 1 else { return nil }
        var modifiers: EventModifiers = []
        if code & 4 != 0 { modifiers.insert(.shift) }
        if code & 8 != 0 { modifiers.insert(.option) }
        if code & 16 != 0 { modifiers.insert(.control) }
        let low = code & 0b11
        let kind: MouseEvent.Kind
        if code & 64 != 0 {
            kind = .scroll([.up, .down, .left, .right][low])
        } else if code & 32 != 0 {
            kind = .move
        } else {
            let button: MouseEvent.Button? = low == 3 ? nil : [.left, .middle, .right][low]
            if isRelease {
                kind = .release(button)
            } else if let button {
                kind = .press(button)
            } else {
                kind = .release(nil)
            }
        }
        return MouseEvent(kind: kind, location: Point(x: column - 1, y: row - 1), modifiers: modifiers)
    }
}
