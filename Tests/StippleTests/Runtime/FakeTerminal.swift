@testable import Stipple

/// A scripted terminal: records output and lets tests feed events.
@MainActor
final class FakeTerminal: TerminalHost {
    var output = ""
    var errorOutput = ""
    var size = Size(width: 40, height: 10)
    var isTerminal = true
    var isInteractive = true
    var isInputTerminal = true
    private(set) var rawMode = false
    private(set) var bracketedPaste = false
    private(set) var kittyFlags: [KittyKeyboardFlags] = []
    private(set) var kittyQueried = false
    private(set) var restored = false
    private(set) var notedModes: (alternateScreen: Bool, cursorHidden: Bool)?
    private var continuation: AsyncStream<TerminalEvent>.Continuation?

    func write(_ text: String) { output += text }
    func writeError(_ text: String) { errorOutput += text }

    func enableRawMode() -> Bool {
        rawMode = isInputTerminal
        return rawMode
    }

    func restore() {
        restored = true
        rawMode = false
    }

    func events() -> AsyncStream<TerminalEvent> {
        let (stream, continuation) = AsyncStream<TerminalEvent>.makeStream()
        self.continuation = continuation
        return stream
    }

    func setBracketedPaste(_ enabled: Bool) { bracketedPaste = enabled }
    func pushKittyKeyboard(_ flags: KittyKeyboardFlags) { kittyFlags.append(flags) }
    func queryKittyKeyboard() { kittyQueried = true }
    func noteModes(alternateScreen: Bool, cursorHidden: Bool) { notedModes = (alternateScreen, cursorHidden) }

    private(set) var suspensions = 0

    func suspend<T>(_ body: () async throws -> T) async throws -> T {
        suspensions += 1
        output += "<suspended>"
        defer { output += "</suspended>" }
        return try await body()
    }

    /// Plain text of the last frame drawn (escape codes removed, erased lines dropped).
    var lastFrame: String {
        let plain = output.replacing(/\u{1B}\[[0-9;?]*[A-Za-z]/, with: "\u{0}")
        let frames = plain.split(separator: "\u{0}", omittingEmptySubsequences: true)
        return frames.last.map { String($0).trimmingSuffix("\n") } ?? ""
    }
}

extension String {
    func trimmingSuffix(_ suffix: Character) -> String {
        var copy = self
        while copy.last == suffix { copy.removeLast() }
        return copy
    }
}

@MainActor
func makeRuntime(_ view: some View, configure: (inout RenderOptions) -> Void = { _ in }) -> (Runtime, FakeTerminal) {
    let terminal = FakeTerminal()
    var options = RenderOptions()
    options.maxFps = 1000
    configure(&options)
    return (Runtime(view: view, options: options, terminal: terminal), terminal)
}
