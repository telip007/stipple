/// Escape sequences that switch terminal modes.
enum TerminalSequence {
    static let alternateScreenOn = "\u{1B}[?1049h"
    static let alternateScreenOff = "\u{1B}[?1049l"
    static let cursorHide = "\u{1B}[?25l"
    static let cursorShow = "\u{1B}[?25h"
    static let bracketedPasteOn = "\u{1B}[?2004h"
    static let bracketedPasteOff = "\u{1B}[?2004l"
    static let focusReportingOn = "\u{1B}[?1004h"
    static let focusReportingOff = "\u{1B}[?1004l"
    /// Button and wheel reports (`?1000`) in SGR encoding (`?1006`).
    static let mouseReportingOn = "\u{1B}[?1000h\u{1B}[?1006h"
    static let mouseReportingOff = "\u{1B}[?1006l\u{1B}[?1000l"
    static let kittyKeyboardPop = "\u{1B}[<u"
    static let kittyKeyboardQuery = "\u{1B}[?u"

    static func kittyKeyboardPush(_ flags: KittyKeyboardFlags) -> String {
        "\u{1B}[>\(flags.resolved.rawValue)u"
    }
}

/// The terminal modes that are switched on, so that restore undoes exactly
/// what is active and a continue after Ctrl-Z can switch them on again.
struct TerminalModes: Equatable, Sendable {
    var alternateScreen = false
    var cursorHidden = false
    var bracketedPaste = false
    var focusReporting = false
    var mouseReporting = false
    /// One entry per pushed flag set, bottom first.
    var kittyKeyboard: [KittyKeyboardFlags] = []

    var isEmpty: Bool { self == Self() }

    /// Switches every active mode on, in the order a fresh start uses.
    var enterSequence: String {
        var out = ""
        if alternateScreen { out += TerminalSequence.alternateScreenOn }
        if cursorHidden { out += TerminalSequence.cursorHide }
        if bracketedPaste { out += TerminalSequence.bracketedPasteOn }
        if focusReporting { out += TerminalSequence.focusReportingOn }
        if mouseReporting { out += TerminalSequence.mouseReportingOn }
        for flags in kittyKeyboard { out += TerminalSequence.kittyKeyboardPush(flags) }
        return out
    }

    /// Switches every active mode off, in reverse order of `enterSequence`.
    var restoreSequence: String {
        var out = String(repeating: TerminalSequence.kittyKeyboardPop, count: kittyKeyboard.count)
        if mouseReporting { out += TerminalSequence.mouseReportingOff }
        if focusReporting { out += TerminalSequence.focusReportingOff }
        if bracketedPaste { out += TerminalSequence.bracketedPasteOff }
        if cursorHidden { out += TerminalSequence.cursorShow }
        if alternateScreen { out += TerminalSequence.alternateScreenOff }
        return out
    }
}

/// Reads the CI flag the way the `is-in-ci` package does.
enum TerminalEnvironment {
    static func isCI(_ environment: [String: String]) -> Bool {
        if let value = environment["CI"], value != "0", value.lowercased() != "false" {
            return true
        }
        return ["CONTINUOUS_INTEGRATION", "BUILD_NUMBER", "RUN_ID"].contains { environment[$0] != nil }
    }

    static func dimension(_ environment: [String: String], _ key: String) -> Int? {
        environment[key].flatMap { Int($0) }.flatMap { $0 > 0 ? $0 : nil }
    }
}
