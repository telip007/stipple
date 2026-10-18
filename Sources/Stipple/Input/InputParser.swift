/// Decodes stdin bytes into ``InputEvent`` values and keeps incomplete input between chunks.
///
/// Feed every chunk read from stdin to ``parse(_:)``. A sequence split across chunks
/// (an escape sequence, a UTF-8 character, a bracketed paste) is held until its last
/// byte arrives. A lone ESC is held too, because it may start a sequence. When
/// ``hasPendingInput`` is true, call ``flushPendingEscape()`` about 50 ms after the
/// last byte; that turns the ESC into an Escape key press.
struct InputParser: Sendable {
    /// Bytes that do not yet form a complete token.
    private var pending: [UInt8] = []
    /// Bytes read since `ESC [ 2 0 0 ~`, or `nil` outside a bracketed paste.
    private var paste: [UInt8]?

    /// Whether a buffered ESC is waiting for ``flushPendingEscape()``.
    var hasPendingInput: Bool {
        guard paste == nil, pending.first == InputBytes.escape else { return false }
        // `ESC [ 2 0 0` may still become a paste marker, so it waits for the next byte.
        return pending != InputBytes.pasteStartPrefix
    }

    /// Decodes the events completed by `bytes`.
    mutating func parse(_ bytes: some Collection<UInt8>) -> [InputEvent] {
        pending.append(contentsOf: bytes)
        return drain()
    }

    /// Turns a buffered ESC into the Escape key (`ESC ESC` into Option-Escape) and decodes the bytes after it.
    mutating func flushPendingEscape() -> [InputEvent] {
        guard hasPendingInput else { return [] }
        let isDouble = pending.count > 1 && pending[1] == InputBytes.escape
        pending.removeFirst(isDouble ? 2 : 1)
        let escape = KeyPress(key: .escape, modifiers: isDouble ? .option : [])
        return [.key(escape)] + drain()
    }

    /// Decodes `pending` from the front and stores the incomplete tail again.
    private mutating func drain() -> [InputEvent] {
        var input = pending
        pending = []
        var events: [InputEvent] = []
        var cursor = 0
        while cursor < input.count {
            if paste != nil {
                guard let rest = consumePaste(input, from: cursor, events: &events) else { break }
                input = rest
                cursor = 0
                continue
            }
            switch InputDecoder.token(in: input, at: cursor) {
            case .incomplete:
                pending = Array(input[cursor...])
                return events
            case .consumed(let length, let tokenEvents):
                events += tokenEvents
                cursor += length
            case .pasteStart(let length):
                paste = []
                cursor += length
            }
        }
        return events
    }

    /// Appends the bytes from `cursor` to the open paste. Returns the bytes after the end marker
    /// once it has arrived, and emits the paste event; returns `nil` while the paste is still open.
    private mutating func consumePaste(
        _ input: [UInt8],
        from cursor: Int,
        events: inout [InputEvent],
    ) -> [UInt8]? {
        guard var buffer = paste else { return nil }
        // The end marker may straddle the previous chunk, so search from its last possible start.
        let searchStart = max(0, buffer.count - InputBytes.pasteEnd.count + 1)
        buffer.append(contentsOf: input[cursor...])
        guard let end = InputDecoder.firstIndex(of: InputBytes.pasteEnd, in: buffer, from: searchStart) else {
            paste = buffer
            return nil
        }
        paste = nil
        events.append(.paste(InputDecoder.utf8String(buffer[..<end])))
        return Array(buffer[(end + InputBytes.pasteEnd.count)...])
    }
}
