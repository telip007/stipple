/// How `Stipple.render` and `Stipple.run` drive the terminal. The fields
/// follow Ink's `render()` options.
public struct RenderOptions: Sendable {
    /// Which keyboard protocol to ask the terminal for.
    public enum KeyboardProtocol: Sendable, Equatable {
        /// Classic VT/xterm sequences only.
        case legacy
        /// Ask whether the terminal speaks the kitty protocol and use it if so.
        case automatic
        /// Use the kitty keyboard protocol with these flags, without asking first.
        case kitty(KittyKeyboardFlags)
    }

    /// Exit when Ctrl-C is pressed. Raw mode turns Ctrl-C into a key press,
    /// so without this the app has to handle it.
    public var exitOnCtrlC = true
    /// The most frames drawn per second; state changes in between are batched.
    public var maxFps = 30
    /// Draw on the alternate screen, like full-screen apps; the terminal's
    /// previous content comes back on exit.
    public var alternateScreen = false
    /// Rewrite only the lines that changed instead of the whole frame.
    public var incrementalRendering = false
    /// Write every frame in full without erasing the previous one, for debugging layout.
    public var debug = false
    /// Force interactive (`true`) or plain (`false`) output. `nil` detects it:
    /// plain when stdout isn't a terminal or when running in CI.
    public var interactive: Bool?
    /// The keyboard protocol to use.
    public var keyboardProtocol = KeyboardProtocol.legacy
    /// Turn on screen reader output. `nil` reads `STIPPLE_SCREEN_READER=true`.
    public var isScreenReaderEnabled: Bool?

    /// Creates the default options.
    public init() {}
}
