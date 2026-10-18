/// What the runtime needs from a terminal. `Terminal` is the real one;
/// tests drive the runtime with a scripted fake.
@MainActor
protocol TerminalHost: TerminalOutput {
    /// Whether stdout is a terminal and not in CI.
    var isInteractive: Bool { get }
    /// Whether stdin is a terminal (raw mode and key input are possible).
    var isInputTerminal: Bool { get }
    /// Switches stdin to raw mode; `false` if stdin isn't a terminal.
    @discardableResult func enableRawMode() -> Bool
    /// Undoes every mode and leaves raw mode.
    func restore()
    /// Input bytes and resizes.
    func events() -> AsyncStream<TerminalEvent>
    /// Turns bracketed paste on or off.
    func setBracketedPaste(_ enabled: Bool)
    /// Pushes kitty keyboard flags.
    func pushKittyKeyboard(_ flags: KittyKeyboardFlags)
    /// Asks whether the terminal supports the kitty keyboard protocol.
    func queryKittyKeyboard()
    /// Records modes that the frame writer switched itself, so crash
    /// recovery undoes them too.
    func noteModes(alternateScreen: Bool, cursorHidden: Bool)
    /// Writes to standard error.
    func writeError(_ text: String)
}
