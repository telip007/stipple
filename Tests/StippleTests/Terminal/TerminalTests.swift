import Foundation
import Testing

@testable import Stipple

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Process-wide signals (`SIGWINCH`, `SIGCONT`) are shared, so these tests run one at a time.
@Suite(.serialized) @MainActor
struct TerminalTests {
    // MARK: Environment

    @Test func sizeComesFromTheWindow() throws {
        let pty = try PTY(columns: 90, rows: 33)
        #expect(pty.terminal().size == Size(width: 90, height: 33))
    }

    @Test func sizeFallsBackToEnvironmentThenDefault() throws {
        let pipe = Pipe()
        let descriptor = pipe.fileHandleForWriting.fileDescriptor
        let env = Terminal(
            inputDescriptor: 0, outputDescriptor: descriptor, environment: ["COLUMNS": "120", "LINES": "40"])
        #expect(env.size == Size(width: 120, height: 40))
        let partial = Terminal(
            inputDescriptor: 0, outputDescriptor: descriptor, environment: ["COLUMNS": "0", "LINES": "x"])
        #expect(partial.size == Size(width: 80, height: 24))
    }

    @Test func terminalDetection() throws {
        let pty = try PTY()
        #expect(pty.terminal().isTerminal)
        #expect(pty.terminal().isInputTerminal)
        #expect(pty.terminal().isInteractive)
        let pipe = Pipe()
        let piped = Terminal(
            inputDescriptor: 0, outputDescriptor: pipe.fileHandleForWriting.fileDescriptor, environment: [:])
        #expect(!piped.isTerminal)
        #expect(!piped.isInteractive)
        #expect(piped.colorDepth == .monochrome)
        #expect(pty.terminal(environment: ["COLORTERM": "truecolor"]).colorDepth == .trueColor)
    }

    @Test(
        arguments: [
            ([:], false), (["CI": "true"], true), (["CI": "1"], true), (["CI": "0"], false), (["CI": "false"], false),
            (["CONTINUOUS_INTEGRATION": "1"], true), (["BUILD_NUMBER": "7"], true), (["RUN_ID": "x"], true),
        ] as [([String: String], Bool)])
    func ciDetection(environment: [String: String], expected: Bool) throws {
        let pty = try PTY()
        let terminal = pty.terminal(environment: environment)
        #expect(terminal.isCI == expected)
        #expect(terminal.isInteractive == !expected)
    }

    @Test func defaultInitializerReadsProcessEnvironment() {
        let terminal = Terminal()
        #expect(terminal.inputDescriptor == 0)
        #expect(terminal.outputDescriptor == 1)
        _ = terminal.isCI
    }

    // MARK: Output and raw mode

    @Test func writeReachesTheTerminal() throws {
        let pty = try PTY()
        pty.terminal().write("héllo\n")
        #expect(pty.read(until: "héllo").contains("héllo"))
    }

    @Test func rawModeTogglesAndRestoresAttributes() throws {
        let pty = try PTY()
        let terminal = pty.terminal()
        let before = try #require(TTY.attributes(pty.device))
        #expect(terminal.enableRawMode())
        #expect(terminal.enableRawMode())
        #expect(terminal.isRawModeEnabled)
        let raw = try #require(TTY.attributes(pty.device))
        #expect(raw.c_lflag & tcflag_t(ICANON | ECHO | ISIG) == 0)
        #expect(raw.c_oflag & tcflag_t(OPOST) != 0)
        #expect(CrashRestore.registeredCount >= 1)
        terminal.restore()
        terminal.restore()
        let after = try #require(TTY.attributes(pty.device))
        let touched = tcflag_t(ICANON | ECHO | ISIG | IEXTEN)
        #expect(after.c_lflag & touched == before.c_lflag & touched)
        #expect(after.c_iflag == before.c_iflag)
        #expect(!terminal.isRawModeEnabled)
    }

    @Test func rawModeFailsOnNonTerminals() {
        let pipe = Pipe()
        let terminal = Terminal(
            inputDescriptor: pipe.fileHandleForReading.fileDescriptor, outputDescriptor: 1, environment: [:])
        #expect(!terminal.enableRawMode())
        terminal.disableRawMode()
    }

    // MARK: Modes

    @Test func modesWriteOnceAndRestoreExactlyWhatIsActive() throws {
        let pty = try PTY()
        let terminal = pty.terminal()
        terminal.setAlternateScreen(true)
        terminal.setAlternateScreen(true)
        terminal.setCursorVisible(false)
        terminal.setBracketedPaste(true)
        terminal.setFocusReporting(true)
        terminal.pushKittyKeyboard([.disambiguateEscapeCodes, .reportEventTypes])
        terminal.queryKittyKeyboard()
        terminal.pushKittyKeyboard(.reportAssociatedText)
        terminal.popKittyKeyboard()
        let entered = pty.read(until: "\u{1B}[<u")
        #expect(entered == "\u{1B}[?1049h\u{1B}[?25l\u{1B}[?2004h\u{1B}[?1004h\u{1B}[>3u\u{1B}[?u\u{1B}[>24u\u{1B}[<u")
        terminal.restore()
        #expect(pty.read(until: "1049l") == "\u{1B}[<u\u{1B}[?1004l\u{1B}[?2004l\u{1B}[?25h\u{1B}[?1049l")
        terminal.restore()
        #expect(pty.drain().isEmpty)
        #expect(terminal.modes.isEmpty)
    }

    @Test func switchingOffAndPoppingEmptyAreQuiet() throws {
        let pty = try PTY()
        let terminal = pty.terminal()
        terminal.popKittyKeyboard()
        terminal.setAlternateScreen(false)
        terminal.setCursorVisible(true)
        terminal.setBracketedPaste(false)
        terminal.setFocusReporting(false)
        #expect(pty.drain().isEmpty)
        terminal.setCursorVisible(false)
        terminal.setCursorVisible(true)
        #expect(pty.read(until: "?25h") == "\u{1B}[?25l\u{1B}[?25h")
        #expect(terminal.modes.isEmpty)
    }

    @Test func mouseReportingSwitchesOnceAndRestores() throws {
        let pty = try PTY()
        let terminal = pty.terminal()
        terminal.setMouseReporting(false)
        terminal.setMouseReporting(true)
        terminal.setMouseReporting(true)
        #expect(pty.read(until: "1006h") == "\u{1B}[?1000h\u{1B}[?1006h")
        terminal.setMouseReporting(false)
        #expect(pty.read(until: "1000l") == "\u{1B}[?1006l\u{1B}[?1000l")
        terminal.setMouseReporting(true)
        _ = pty.read(until: "1006h")
        terminal.setMouseMotionReporting(true)
        terminal.setMouseMotionReporting(true)
        #expect(pty.read(until: "1003h") == "\u{1B}[?1003h")
        terminal.setMouseMotionReporting(false)
        // Leaving `?1003` stops all tracking in xterm, so button reports come back on.
        #expect(pty.read(until: "1000h") == "\u{1B}[?1003l\u{1B}[?1000h")
        terminal.setMouseMotionReporting(true)
        _ = pty.read(until: "1003h")
        terminal.restore()
        #expect(pty.read(until: "1000l") == "\u{1B}[?1003l\u{1B}[?1006l\u{1B}[?1000l")
        #expect(terminal.modes.isEmpty)
    }
}
