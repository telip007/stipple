extension View {
    /// Handles key presses. Outside any `.focusable()` view the handler is
    /// global, like Ink's `useInput`; inside one it runs only while that
    /// view has focus. Return `.handled` to stop other handlers from seeing the press.
    public func onKeyPress(
        phases: KeyPress.Phases = [.down, .repeat],
        action: @escaping @MainActor (KeyPress) -> KeyPress.Result,
    ) -> some View {
        interaction { behaviors in
            behaviors.keyHandlers.append { press in
                phases.contains(press.phase) ? action(press) : .ignored
            }
        }
    }

    /// Handles presses of one key, regardless of modifiers.
    public func onKeyPress(_ key: KeyEquivalent, action: @escaping @MainActor () -> KeyPress.Result) -> some View {
        onKeyPress(keys: [key]) { _ in action() }
    }

    /// Handles presses of any of `keys`.
    public func onKeyPress(
        keys: Set<KeyEquivalent>,
        phases: KeyPress.Phases = [.down, .repeat],
        action: @escaping @MainActor (KeyPress) -> KeyPress.Result,
    ) -> some View {
        onKeyPress(phases: phases) { press in
            keys.contains(press.key) ? action(press) : .ignored
        }
    }

    /// Handles text pasted while bracketed paste is on, delivered whole
    /// (Ink's `usePaste`). Without a paste handler, pasted text arrives as key presses.
    public func onPaste(perform action: @escaping @MainActor (String) -> Void) -> some View {
        interaction { $0.pasteHandlers.append(action) }
    }
}

extension KeyPress {
    /// A set of key phases to handle.
    public struct Phases: OptionSet, Hashable, Sendable {
        /// The raw bit mask.
        public let rawValue: UInt8

        /// Creates phases from a raw bit mask.
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        /// Key down.
        public static let down = Self(rawValue: 1 << 0)
        /// Auto-repeat while held.
        public static let `repeat` = Self(rawValue: 1 << 1)
        /// Key up.
        public static let up = Self(rawValue: 1 << 2)
        /// Every phase.
        public static let all: Self = [.down, .repeat, .up]

        func contains(_ phase: Phase) -> Bool {
            switch phase {
            case .down: contains(Self.down)
            case .repeat: contains(Self.repeat)
            case .up: contains(Self.up)
            }
        }
    }
}
