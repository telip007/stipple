/// How `FrameWriter` draws. The fields follow Ink's `render()` options that
/// affect output.
struct FrameWriterOptions: Equatable, Sendable {
    /// Draw on the alternate screen (`?1049`), restored on finish. Ignored unless
    /// the writer is interactive and the output is a terminal.
    var alternateScreen = false
    /// Diff the lines of the frame instead of erasing and rewriting all of it.
    var incremental = false
    /// Append every frame in full, with no erasing. Ink's `debug` mode.
    var debug = false
    /// Erase and move the cursor, with synchronized output. Nil uses whether the
    /// output is a terminal. The runtime passes `Terminal.isInteractive`, which also
    /// excludes CI.
    var interactive: Bool?
    /// Keep the cursor visible while rendering.
    var showCursor = false
    /// Screen-reader mode: wrap the frame to the terminal width and rewrite it whole,
    /// with no cursor movement. Ink's `isScreenReaderEnabled`.
    var screenReader = false

    /// Creates the default options: inline, not debug, not alternate screen.
    init(
        alternateScreen: Bool = false,
        incremental: Bool = false,
        debug: Bool = false,
        interactive: Bool? = nil,
        showCursor: Bool = false,
        screenReader: Bool = false
    ) {
        self.alternateScreen = alternateScreen
        self.incremental = incremental
        self.debug = debug
        self.interactive = interactive
        self.showCursor = showCursor
        self.screenReader = screenReader
    }
}
