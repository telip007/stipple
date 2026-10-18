@testable import Stipple

/// A `TerminalOutput` that records every write, for asserting exact bytes.
@MainActor
final class RecordingOutput: TerminalOutput {
    private var recorded: [String] = []
    var size: Size
    var isTerminal: Bool

    init(size: Size = Size(width: 80, height: 24), isTerminal: Bool = true) {
        self.size = size
        self.isTerminal = isTerminal
    }

    func write(_ text: String) {
        recorded.append(text)
    }

    /// The writes since the last call, in order. Forgets them.
    func take() -> [String] {
        defer { recorded = [] }
        return recorded
    }
}

/// Escape sequences spelled out, so the tests read as bytes.
enum Bytes {
    static let esc = "\u{1B}["
    static let hide = "\u{1B}[?25l"
    static let show = "\u{1B}[?25h"
    static let begin = "\u{1B}[?2026h"
    static let end = "\u{1B}[?2026l"
}
