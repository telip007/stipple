/// Something that happened on the terminal, delivered by ``Terminal/events()``.
public enum TerminalEvent: Equatable, Sendable {
    /// Raw bytes read from standard input, in arrival order. A chunk may end
    /// in the middle of an escape sequence or a UTF-8 character.
    case input([UInt8])
    /// The terminal changed size, or the process regained the terminal after
    /// being stopped or suspended. Redraw at the new size.
    case resize(Size)
}

/// Errors thrown by ``Terminal``.
public enum TerminalError: Error, Equatable {
    /// ``Terminal/suspend(_:)`` was called while the terminal was already suspended.
    case alreadySuspended
}
