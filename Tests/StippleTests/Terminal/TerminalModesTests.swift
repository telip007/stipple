import Testing

@testable import Stipple

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

struct TerminalModesTests {
    @Test func kittyFlagValues() {
        #expect(KittyKeyboardFlags.disambiguateEscapeCodes.rawValue == 1)
        #expect(KittyKeyboardFlags.reportEventTypes.rawValue == 2)
        #expect(KittyKeyboardFlags.reportAlternateKeys.rawValue == 4)
        #expect(KittyKeyboardFlags.reportAllKeysAsEscapeCodes.rawValue == 8)
        #expect(KittyKeyboardFlags.reportAssociatedText.rawValue == 16)
    }

    @Test func associatedTextImpliesAllKeys() {
        #expect(KittyKeyboardFlags.reportAssociatedText.resolved.rawValue == 24)
        #expect(KittyKeyboardFlags.reportEventTypes.resolved.rawValue == 2)
        #expect(TerminalSequence.kittyKeyboardPush([.disambiguateEscapeCodes, .reportEventTypes]) == "\u{1B}[>3u")
    }

    @Test func enterAndRestoreAreMirrorImages() {
        let modes = TerminalModes(
            alternateScreen: true, cursorHidden: true, bracketedPaste: true, focusReporting: true,
            kittyKeyboard: [.disambiguateEscapeCodes, .reportEventTypes])
        #expect(modes.enterSequence == "\u{1B}[?1049h\u{1B}[?25l\u{1B}[?2004h\u{1B}[?1004h\u{1B}[>1u\u{1B}[>2u")
        #expect(modes.restoreSequence == "\u{1B}[<u\u{1B}[<u\u{1B}[?1004l\u{1B}[?2004l\u{1B}[?25h\u{1B}[?1049l")
        #expect(!modes.isEmpty)
        #expect(TerminalModes().isEmpty)
        #expect(TerminalModes().restoreSequence.isEmpty)
        #expect(TerminalModes().enterSequence.isEmpty)
    }

    @Test func dimensionParsing() {
        #expect(TerminalEnvironment.dimension(["A": "12"], "A") == 12)
        #expect(TerminalEnvironment.dimension(["A": "0"], "A") == nil)
        #expect(TerminalEnvironment.dimension(["A": "-3"], "A") == nil)
        #expect(TerminalEnvironment.dimension([:], "A") == nil)
    }

    @Test func rawAttributesMatchLibuv() throws {
        var original = termios()
        original.c_lflag = tcflag_t(ICANON | ECHO | ISIG | IEXTEN)
        original.c_iflag = tcflag_t(ICRNL | IXON | BRKINT)
        let raw = TTY.raw(from: original)
        #expect(raw.c_lflag & tcflag_t(ICANON | ECHO | ISIG | IEXTEN) == 0)
        #expect(raw.c_iflag & tcflag_t(ICRNL | IXON | BRKINT) == 0)
        #expect(raw.c_oflag & tcflag_t(ONLCR) != 0)
        #expect(raw.c_cflag & tcflag_t(CS8) == tcflag_t(CS8))
    }

    @Test func windowSizeIsNilForNonTerminals() {
        #expect(TTY.windowSize(-1) == nil)
        #expect(TTY.attributes(-1) == nil)
    }
}
