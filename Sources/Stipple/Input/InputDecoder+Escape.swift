/// Decoding of sequences that start with ESC.
extension InputDecoder {
    /// The Escape key, emitted when an ESC cannot start a sequence.
    static let escapeEvents: [InputEvent] = [.key(KeyPress(key: .escape))]

    /// Decodes the sequence that starts with the ESC at `start`.
    static func escapeToken(in input: [UInt8], at start: Int) -> InputToken {
        guard start + 1 < input.count else { return .incomplete }
        switch input[start + 1] {
        case InputBytes.bracket: return csiToken(in: input, at: start)
        case InputBytes.ss3: return ss3Token(in: input, at: start)
        case InputBytes.escape: return doubleEscapeToken(in: input, at: start)
        default: return altToken(in: input, at: start + 1)
        }
    }

    /// Decodes the byte after an ESC as that key with Option held. `start` indexes that byte.
    static func altToken(in input: [UInt8], at start: Int) -> InputToken {
        let byte = input[start]
        if isControl(byte) {
            return .consumed(length: 2, events: [.key(ControlKeys.press(for: byte, option: true))])
        }
        guard let length = utf8SequenceLength(in: input, at: start) else { return .incomplete }
        let text = Self.utf8String(input[start..<(start + length)])
        guard let character = text.first else { return .consumed(length: 1 + length, events: []) }
        return .consumed(length: 1 + length, events: [.key(keyPress(for: character, modifiers: .option))])
    }

    /// Decodes `ESC ESC …` as the token after the second ESC, with Option added. A bare `ESC ESC`
    /// waits for its next byte, because it may start a sequence.
    static func doubleEscapeToken(in input: [UInt8], at start: Int) -> InputToken {
        guard start + 2 < input.count else { return .incomplete }
        switch token(in: input, at: start + 1) {
        case .incomplete:
            return .incomplete
        case .consumed(let length, let events):
            return .consumed(length: length + 1, events: events.map(addingOption))
        case .pasteStart:
            return .consumed(length: 1, events: [.key(KeyPress(key: .escape, modifiers: .option))])
        }
    }

    /// Decodes `ESC [ … final`. Bytes that cannot form a CSI leave the ESC as the Escape key.
    static func csiToken(in input: [UInt8], at start: Int) -> InputToken {
        let payload = start + 2
        var index = payload
        while index < input.count {
            let byte = input[index]
            if index == payload, byte == InputBytes.bracket {
                // Legacy Linux console keys are `ESC [ [ A` to `ESC [ [ E`.
                index += 1
            } else if isRxvtShift(in: input, payload: payload, index: index) || isCSIFinal(byte) {
                return csiSequence(in: input, start: start, end: index + 1)
            } else if isCSIParameter(byte) || isCSIIntermediate(byte) {
                index += 1
            } else {
                return .consumed(length: 1, events: escapeEvents)
            }
        }
        return .incomplete
    }

    /// Decodes `ESC O … final`. SS3 carries digits and semicolons only when modified.
    static func ss3Token(in input: [UInt8], at start: Int) -> InputToken {
        var index = start + 2
        while index < input.count {
            let byte = input[index]
            if isCSIFinal(byte) {
                let body = Self.utf8String(input[(start + 2)..<index])
                return .consumed(length: index + 1 - start, events: LegacyKeys.ss3Events(body: body, final: byte))
            }
            guard (0x30...0x39).contains(byte) || byte == InputBytes.semicolon else {
                return .consumed(length: 1, events: escapeEvents)
            }
            index += 1
        }
        return .incomplete
    }

    /// Builds the token for a complete CSI, which runs from the ESC at `start` up to `end`.
    static func csiSequence(in input: [UInt8], start: Int, end: Int) -> InputToken {
        let length = end - start
        let body = Self.utf8String(input[(start + 2)..<(end - 1)])
        let final = input[end - 1]
        if body == "200", final == InputBytes.tilde {
            return .pasteStart(length: length)
        }
        return .consumed(length: length, events: LegacyKeys.csiEvents(body: body, final: final))
    }

    /// rxvt shifted editing keys end in `$`, which is an intermediate byte, so they end the CSI early.
    static func isRxvtShift(in input: [UInt8], payload: Int, index: Int) -> Bool {
        index == payload + 1 && input[index] == InputBytes.dollar && rxvtShiftDigits.contains(input[payload])
    }

    /// The digits that take `$` in rxvt: Insert, Delete, Page Up, Page Down, Home and End.
    static let rxvtShiftDigits: [UInt8] = Array("235678".utf8)

    /// `0x30–0x3F`, the CSI parameter bytes.
    static func isCSIParameter(_ byte: UInt8) -> Bool {
        (0x30...0x3F).contains(byte)
    }

    /// `0x20–0x2F`, the CSI intermediate bytes.
    static func isCSIIntermediate(_ byte: UInt8) -> Bool {
        (0x20...0x2F).contains(byte)
    }

    /// `0x40–0x7E`, the CSI final bytes.
    static func isCSIFinal(_ byte: UInt8) -> Bool {
        (0x40...0x7E).contains(byte)
    }

    /// The same event with Option added. Non-key events are returned unchanged.
    static func addingOption(_ event: InputEvent) -> InputEvent {
        guard case .key(var press) = event else { return event }
        press.modifiers.insert(.option)
        return .key(press)
    }
}
