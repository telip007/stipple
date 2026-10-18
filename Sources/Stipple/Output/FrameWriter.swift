/// Draws the live frame, static output and console writes to a terminal.
/// Port of the frame logic in Ink's `ink.tsx`: `renderFrame`,
/// `renderInteractiveFrame`, `restoreLastOutput`, `resized`, `clear`, the
/// `writeToStdout` path and unmount.
///
/// Frames are written synchronously. The caller decides how often to render.
@MainActor
final class FrameWriter {
    /// One frame as the renderer produces it.
    struct Frame: Equatable, Sendable {
        /// The frame, with ANSI escapes and without a trailing newline.
        var text: String
        /// The number of rows the frame occupies.
        var height: Int
        /// The `<Static>` output written above the frame, or empty.
        var staticOutput: String
    }

    let output: any TerminalOutput
    let options: FrameWriterOptions
    let log: LogUpdate
    let interactive: Bool
    var alternateScreen: Bool
    var cursorPosition: CursorPosition?
    var lastOutput = ""
    var lastOutputToRender = ""
    var lastOutputHeight = 0
    var fullStaticOutput = ""
    var lastTerminalWidth: Int
    var lastTerminalHeight: Int
    var isUnmounting = false
    var isFinished = false

    /// Whether any `<Static>` output has been written. The runtime uses this to
    /// skip a final render that would repeat `<Static>` children on exit.
    var hasRenderedStaticOutput = false

    /// Creates a writer for `output`. With `alternateScreen` set and the writer
    /// interactive, this switches to the alternate screen and hides the cursor.
    init(output: any TerminalOutput, options: FrameWriterOptions = FrameWriterOptions()) {
        self.output = output
        self.options = options
        interactive = options.interactive ?? output.isTerminal
        alternateScreen = options.alternateScreen && interactive && output.isTerminal
        log = LogUpdate(output: output, incremental: options.incremental, showCursor: options.showCursor)
        lastTerminalWidth = output.size.width
        lastTerminalHeight = output.size.height
        if alternateScreen {
            output.write(Escape.enterAlternateScreen + Escape.hideCursor)
        }
    }

    /// Draws `frame` above which `staticOutput` is written once.
    /// - Parameters:
    ///   - frame: The frame text, with ANSI escapes and without a trailing newline.
    ///   - height: The number of rows the frame occupies.
    ///   - staticOutput: Output for `<Static>` children added since the last write, or empty.
    func write(frame: String, height: Int, staticOutput: String) {
        write(Frame(text: frame, height: height, staticOutput: staticOutput))
    }

    /// Tells the writer the terminal was resized. A shrink that would leave the
    /// old frame misplaced erases it. The next `write` draws the frame again.
    func resized() {
        guard interactive, !isFinished else { return }
        let size = output.size
        if size.width < lastTerminalWidth || (size.height < lastTerminalHeight && log.cursorPosition != nil) {
            log.clear()
            lastOutput = ""
            lastOutputToRender = ""
            lastOutputHeight = 0
        }
        lastTerminalWidth = size.width
        lastTerminalHeight = size.height
    }

    /// Sets where the terminal cursor should rest, relative to the top of the frame.
    /// Nil hides the position. The next `write` applies it.
    func setCursorPosition(_ position: CursorPosition?) {
        cursorPosition = position
        log.setCursorPosition(position)
    }

    /// Forgets the `<Static>` output so it is not replayed. Call this when the
    /// `<Static>` identity changes.
    func staticChanged() {
        fullStaticOutput = ""
        hasRenderedStaticOutput = false
    }

    /// Writes `text` above the frame, for console output while rendering.
    /// The frame is erased, `text` is written, and the frame is drawn again.
    func writeAbove(_ text: String) {
        guard !isFinished else { return }
        if options.debug {
            emit(text + fullStaticOutput + lastOutput)
            return
        }
        guard interactive else {
            emit(text)
            return
        }
        let sync = shouldSynchronize
        if sync {
            emit(Escape.beginSynchronizedUpdate)
        }
        log.clear()
        emit(text)
        restoreLastOutput()
        if sync {
            emit(Escape.endSynchronizedUpdate)
        }
    }

    /// Erases the frame from the terminal. Nothing is erased in debug or non-interactive mode.
    func clear() {
        guard interactive, !options.debug else { return }
        log.clear()
        lastOutputHeight = 0
    }

    /// Ends rendering. Pass `finalFrame` to draw it first, so the unmount render is
    /// part of the same call. The cursor is then left below the frame, and the
    /// alternate screen is left. A non-interactive writer prints its last frame here.
    func finish(finalFrame: Frame? = nil) {
        guard !isFinished else { return }
        isUnmounting = true
        if let finalFrame {
            write(finalFrame)
        }
        lastOutputHeight = 0
        isFinished = true
        if interactive, !options.debug {
            log.done()
        }
        if alternateScreen {
            emit(Escape.exitAlternateScreen + Escape.showCursor)
            alternateScreen = false
        }
        if !interactive {
            emit(options.debug ? "\n" : lastOutput + "\n")
        }
    }
}
