import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// The process's terminal: raw mode, size, mode switches, input and signals.
///
/// A `Terminal` wraps an input and an output file descriptor, normally
/// standard input and output. Everything it changes is undone by ``restore()``,
/// and also on `exit`, on fatal signals (`SIGTERM`, `SIGHUP`, `SIGINT`,
/// `SIGQUIT`, `SIGABRT`, `SIGSEGV`, `SIGBUS`, `SIGILL`, `SIGTRAP`, `SIGFPE`)
/// and on Swift runtime traps, so the user's shell is never left in raw mode
/// or on the alternate screen. Call ``restore()`` yourself on the normal paths:
/// a `Terminal` that is just dropped is only restored when the process ends.
@MainActor
public final class Terminal: TerminalOutput {
    /// The descriptor input is read from and termios is applied to.
    public let inputDescriptor: Int32
    /// The descriptor output is written to and the size is read from.
    public let outputDescriptor: Int32

    let environment: [String: String]
    let owner = CrashRestore.makeOwner()
    var modes = TerminalModes()
    var originalAttributes: termios?
    /// True while the terminal is handed back (suspended, or stopped with Ctrl-Z).
    var isReleased = false
    var eventState = EventState()

    /// Creates a terminal over file descriptors.
    ///
    /// - Parameters:
    ///   - inputDescriptor: Where input comes from. Defaults to standard input (descriptor 0).
    ///   - outputDescriptor: Where output goes. Defaults to standard output (descriptor 1).
    ///   - environment: Variables used for `COLUMNS`, `LINES`, CI and color depth detection.
    ///     Defaults to the process environment.
    public init(
        inputDescriptor: Int32 = 0,
        outputDescriptor: Int32 = 1,
        environment: [String: String]? = nil,
    ) {
        self.inputDescriptor = inputDescriptor
        self.outputDescriptor = outputDescriptor
        self.environment = environment ?? ProcessInfo.processInfo.environment
    }

    // MARK: Environment

    /// The size in cells: the window size, else `COLUMNS` and `LINES`, else 80×24.
    public var size: Size {
        let window = TTY.windowSize(outputDescriptor)
        return Size(
            width: window?.width ?? TerminalEnvironment.dimension(environment, "COLUMNS") ?? 80,
            height: window?.height ?? TerminalEnvironment.dimension(environment, "LINES") ?? 24,
        )
    }

    /// Whether output goes to a terminal rather than a pipe or file.
    public var isTerminal: Bool { isatty(outputDescriptor) == 1 }

    /// Whether input comes from a terminal, which is what raw mode needs.
    public var isInputTerminal: Bool { isatty(inputDescriptor) == 1 }

    /// Whether the environment looks like a CI system (`CI`, `CONTINUOUS_INTEGRATION`,
    /// `BUILD_NUMBER` or `RUN_ID`), as `is-in-ci` decides.
    public var isCI: Bool { TerminalEnvironment.isCI(environment) }

    /// Whether to draw interactively: output is a terminal and this is not CI.
    public var isInteractive: Bool { isTerminal && !isCI }

    /// How many colors the output supports, from the environment and
    /// ``isTerminal`` (see ``ColorDepth/detect(environment:isTerminal:)``).
    public var colorDepth: ColorDepth { ColorDepth.detect(environment: environment, isTerminal: isTerminal) }

    // MARK: Output

    /// Writes text, including escape sequences, straight to the output descriptor.
    public func write(_ text: String) {
        TTY.writeAll(outputDescriptor, text)
    }

    // MARK: Raw mode

    /// Whether input is currently in raw mode.
    public var isRawModeEnabled: Bool { originalAttributes != nil && !isReleased }

    /// Switches input to raw mode: no echo, no line buffering, no signal keys
    /// (Ctrl-C arrives as byte `0x03`). Does nothing if already raw.
    ///
    /// - Returns: `false` if the input is not a terminal.
    @discardableResult
    public func enableRawMode() -> Bool {
        if originalAttributes != nil { return true }
        guard let original = TTY.attributes(inputDescriptor) else { return false }
        if !isReleased {
            guard TTY.apply(TTY.raw(from: original), to: inputDescriptor) else { return false }
        }
        originalAttributes = original
        refreshCrashRecord()
        return true
    }

    /// Leaves raw mode and restores the attributes from before ``enableRawMode()``.
    public func disableRawMode() {
        guard let original = originalAttributes else { return }
        originalAttributes = nil
        if !isReleased { TTY.apply(original, to: inputDescriptor) }
        refreshCrashRecord()
    }

    /// Undoes everything: switches every active mode off and leaves raw mode.
    /// Safe to call any number of times.
    public func restore() {
        if !isReleased { write(modes.restoreSequence) }
        modes = TerminalModes()
        disableRawMode()
        refreshCrashRecord()
    }

    // MARK: Mode switches

    /// Enters or leaves the alternate screen (`?1049`).
    public func setAlternateScreen(_ enabled: Bool) {
        guard modes.alternateScreen != enabled else { return }
        modes.alternateScreen = enabled
        switchMode(enabled ? TerminalSequence.alternateScreenOn : TerminalSequence.alternateScreenOff)
    }

    /// Shows or hides the cursor (`?25`).
    public func setCursorVisible(_ visible: Bool) {
        guard modes.cursorHidden == visible else { return }
        modes.cursorHidden = !visible
        switchMode(visible ? TerminalSequence.cursorShow : TerminalSequence.cursorHide)
    }

    /// Turns bracketed paste (`?2004`) on or off.
    public func setBracketedPaste(_ enabled: Bool) {
        guard modes.bracketedPaste != enabled else { return }
        modes.bracketedPaste = enabled
        switchMode(enabled ? TerminalSequence.bracketedPasteOn : TerminalSequence.bracketedPasteOff)
    }

    /// Turns focus in/out reporting (`?1004`) on or off.
    public func setFocusReporting(_ enabled: Bool) {
        guard modes.focusReporting != enabled else { return }
        modes.focusReporting = enabled
        switchMode(enabled ? TerminalSequence.focusReportingOn : TerminalSequence.focusReportingOff)
    }

    /// Turns mouse reporting on or off: button presses, releases and the
    /// wheel (`?1000`), in SGR encoding (`?1006`). While it is on, most
    /// terminals select text only with Shift (or Option on macOS) held.
    public func setMouseReporting(_ enabled: Bool) {
        guard modes.mouseReporting != enabled else { return }
        modes.mouseReporting = enabled
        switchMode(enabled ? TerminalSequence.mouseReportingOn : TerminalSequence.mouseReportingOff)
    }

    /// Pushes kitty keyboard protocol flags (`CSI > flags u`). Pair it with ``popKittyKeyboard()``.
    public func pushKittyKeyboard(_ flags: KittyKeyboardFlags) {
        modes.kittyKeyboard.append(flags)
        switchMode(TerminalSequence.kittyKeyboardPush(flags))
    }

    /// Pops the most recent kitty keyboard flags (`CSI < u`). Does nothing if none were pushed.
    public func popKittyKeyboard() {
        guard modes.kittyKeyboard.popLast() != nil else { return }
        switchMode(TerminalSequence.kittyKeyboardPop)
    }

    /// Asks the terminal for its kitty keyboard flags (`CSI ? u`). The reply
    /// arrives as input bytes, or not at all if the terminal does not support the protocol.
    public func queryKittyKeyboard() {
        if !isReleased { write(TerminalSequence.kittyKeyboardQuery) }
    }

    private func switchMode(_ sequence: String) {
        guard !isReleased else { return }
        write(sequence)
        refreshCrashRecord()
    }

    // MARK: Crash safety

    /// Publishes what a signal handler must undo right now, or withdraws the record if nothing is active.
    func refreshCrashRecord() {
        let attributes = isReleased ? nil : originalAttributes
        let bytes = isReleased ? "" : modes.restoreSequence
        if attributes == nil && bytes.isEmpty {
            CrashRestore.unregister(owner: owner)
        } else {
            CrashRestore.register(
                owner: owner,
                inputDescriptor: inputDescriptor,
                outputDescriptor: outputDescriptor,
                attributes: attributes,
                restoreBytes: Array(bytes.utf8),
            )
        }
    }
}
