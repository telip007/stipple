import Testing

@testable import Stipple

/// Parses `text` as one chunk, the way the terminal delivers a single read.
func decode(_ text: String) -> [InputEvent] {
    var parser = InputParser()
    return parser.parse(text.utf8)
}

/// Parses `bytes` as one chunk.
func decode(bytes: [UInt8]) -> [InputEvent] {
    var parser = InputParser()
    return parser.parse(bytes)
}

/// The key presses in `events`, ignoring other events.
func keyPresses(_ events: [InputEvent]) -> [KeyPress] {
    events.compactMap { event in
        if case .key(let press) = event { return press }
        return nil
    }
}

/// The only key press in `text`, failing the test when there is not exactly one.
func singleKey(_ text: String, sourceLocation: SourceLocation = #_sourceLocation) -> KeyPress? {
    let presses = keyPresses(decode(text))
    #expect(presses.count == 1, sourceLocation: sourceLocation)
    return presses.first
}

/// A down press with no modifiers.
func press(_ key: KeyEquivalent, _ characters: String = "", _ modifiers: EventModifiers = []) -> KeyPress {
    KeyPress(key: key, characters: characters, modifiers: modifiers)
}
