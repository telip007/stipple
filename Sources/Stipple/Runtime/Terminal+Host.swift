extension Terminal: TerminalHost {
    func noteModes(alternateScreen: Bool, cursorHidden: Bool) {
        modes.alternateScreen = alternateScreen
        modes.cursorHidden = cursorHidden
        refreshCrashRecord()
    }

    func writeError(_ text: String) {
        TTY.writeAll(2, text)
    }
}
