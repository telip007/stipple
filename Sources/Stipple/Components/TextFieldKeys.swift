extension TextEditing.Command {
    /// The edit a key press asks for, or `nil` when the press is not for a text field
    /// and should reach other handlers. Ctrl-A/E/B/F/U/K/W/D follow readline; Option or
    /// Control with the arrows and Backspace work by word, and Command by line.
    init?(_ press: KeyPress) {
        let modifiers = press.modifiers.subtracting([.capsLock, .numLock])
        switch press.key {
        case .character(let character):
            guard let command = Self.command(for: character, press: press, modifiers: modifiers) else { return nil }
            self = command
        case .backspace:
            self = Self.backspace(modifiers)
        case .delete:
            self = .deleteForward
        case .leftArrow:
            self = Self.movement(modifiers, word: .wordLeft, line: .moveToStart, character: .moveLeft)
        case .rightArrow:
            self = Self.movement(modifiers, word: .wordRight, line: .moveToEnd, character: .moveRight)
        case .home:
            self = .moveToStart
        case .end:
            self = .moveToEnd
        case .return:
            self = .submit
        default:
            return nil
        }
    }

    /// Control letters are readline shortcuts. Other characters are text unless
    /// Option, Command or Hyper is held.
    private static func command(for character: Character, press: KeyPress, modifiers: EventModifiers) -> Self? {
        if modifiers.contains(.control) {
            return controlCommands[character]
        }
        guard modifiers.isDisjoint(with: [.option, .command, .hyper]) else { return nil }
        return .insert(press.characters.isEmpty ? String(character) : press.characters)
    }

    private static let controlCommands: [Character: Self] = [
        "a": .moveToStart,
        "e": .moveToEnd,
        "b": .moveLeft,
        "f": .moveRight,
        "u": .deleteToStart,
        "k": .deleteToEnd,
        "w": .deleteWordBackward,
        "d": .deleteForward,
    ]

    private static func backspace(_ modifiers: EventModifiers) -> Self {
        if modifiers.contains(.command) { return .deleteToStart }
        return hasWordModifier(modifiers) ? .deleteWordBackward : .deleteBackward
    }

    private static func movement(_ modifiers: EventModifiers, word: Self, line: Self, character: Self) -> Self {
        if modifiers.contains(.command) { return line }
        return hasWordModifier(modifiers) ? word : character
    }

    private static func hasWordModifier(_ modifiers: EventModifiers) -> Bool {
        !modifiers.isDisjoint(with: [.option, .control])
    }
}
