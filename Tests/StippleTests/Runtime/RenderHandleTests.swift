import Testing

@testable import Stipple

@MainActor
struct RenderHandleTests {
    @Test func handleRerendersClearsAndUnmounts() async throws {
        let (runtime, terminal) = makeRuntime(Text("first"))
        let handle = RenderHandle(runtime: runtime)
        handle.rerender(Text("second"))
        #expect(terminal.output.contains("second"))
        handle.rerender(VStack { Text("third") })
        #expect(terminal.output.contains("third"))
        handle.clear()
        handle.unmount()
        try await handle.waitUntilExit()
        try await handle.waitUntilExit()
        #expect(terminal.restored)
    }

    @Test func resizeRerendersWithNewSize() async {
        struct SizeView: View {
            @Environment(\.terminalSize) private var size
            var body: some View { Text("w\(size.width)") }
        }
        let (runtime, terminal) = makeRuntime(SizeView())
        terminal.size = Size(width: 30, height: 5)
        runtime.handle(.resize(terminal.size))
        // Resizes go through the frame throttle, so a burst draws once.
        await runtime.settle()
        #expect(terminal.output.contains("w30"))
    }

    @Test func keyboardProtocols() {
        let (_, kitty) = makeRuntime(Text("x")) { $0.keyboardProtocol = .kitty(.disambiguateEscapeCodes) }
        #expect(kitty.kittyFlags == [.disambiguateEscapeCodes])
        let (runtime, auto) = makeRuntime(Text("x")) { $0.keyboardProtocol = .automatic }
        #expect(auto.kittyQueried)
        runtime.handle(.input(Array("\u{1B}[?1u".utf8)))
        #expect(auto.kittyFlags == [.disambiguateEscapeCodes])
    }

    @Test func pasteWithoutHandlerBecomesKeyPress() async {
        struct Typed: View {
            @State private var text = ""
            var body: some View {
                Text("typed \(text)").onKeyPress { press in
                    text += press.characters
                    return .handled
                }
            }
        }
        let (runtime, terminal) = makeRuntime(Typed())
        runtime.handle(.input(Array("\u{1B}[200~abc\u{1B}[201~".utf8)))
        runtime.handle(.input(Array("\u{1B}[I".utf8)))
        await runtime.settle()
        #expect(terminal.output.contains("typed abc"))
    }

    @Test func keyPhasesFilter() async {
        struct Phases: View {
            @State private var log = ""
            var body: some View {
                Text("log \(log)")
                    .onKeyPress(keys: ["a"], phases: .up) { _ in
                        log += "up"
                        return .handled
                    }
                    .onKeyPress(phases: .all) { press in
                        log += press.phase == .repeat ? "r" : ""
                        return .ignored
                    }
            }
        }
        let (runtime, terminal) = makeRuntime(Phases()) { $0.keyboardProtocol = .kitty(.reportEventTypes) }
        runtime.handle(.input(Array("\u{1B}[97;1:3u".utf8)))
        runtime.handle(.input(Array("\u{1B}[97;1:2u".utf8)))
        await runtime.settle()
        #expect(terminal.output.contains("log upr"))
    }

    @Test func alternateScreenUsesTerminalHeight() {
        let (runtime, terminal) = makeRuntime(
            VStack {
                Text("top")
                Spacer()
                Text("bottom")
            }
        ) { $0.alternateScreen = true }
        #expect(runtime.produceFrame().height == terminal.size.height)
        #expect(terminal.notedModes?.alternateScreen == true)
    }
}
