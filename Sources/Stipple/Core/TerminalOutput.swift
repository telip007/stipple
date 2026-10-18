/// Where rendered frames go. The real terminal implements it in
/// `Terminal/`; tests use a recording implementation.
@MainActor
protocol TerminalOutput: AnyObject {
    /// Writes text (including escape sequences) unbuffered.
    func write(_ text: String)
    /// The current size in cells. Non-terminals report 80×24.
    var size: Size { get }
    /// Whether output goes to a terminal (as opposed to a pipe or file).
    var isTerminal: Bool { get }
}
