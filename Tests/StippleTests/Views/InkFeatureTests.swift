import Testing

@testable import Stipple

@MainActor
struct InkFeatureTests {
    private func plain(_ view: some View, width: Int = 20) -> String {
        Stipple.renderToString(view, width: width).replacing(/\u{1B}\[[0-9;]*m/, with: "")
    }

    @Test func overlayAndBackgroundViews() {
        let overlay = Text("-----").overlay { Text("x") }
        #expect(plain(overlay) == "--x--")
        let leading = Text("-----").overlay(alignment: .leading) { Text("x") }
        #expect(plain(leading) == "x----")
        let background = Text("ab").background(alignment: .trailing) { Text("-----") }
        #expect(plain(background) == "ab")
    }

    @Test func aColoredBackgroundHidesWhatIsBehindIt() {
        // As in Ink, a background is opaque: an overlay box with one covers
        // the text under it, also where its own content is blank.
        let view = Text("abcdefgh").overlay {
            Text("x").frame(width: 4).background(.blue)
        }
        #expect(plain(view) == "ab x  gh")
    }

    @Test func textTransformRewritesLines() {
        let view = VStack {
            Text("one")
            Text("two")
        }
        .textTransform { line, index in line.uppercased() + "\(index)" }
        #expect(plain(view) == "ONE0\nTWO0")
        let nested = Text("a\nb").textTransform { line, index in "\(index)\(line)" }.textTransform { line, _ in
            line + "!"
        }
        #expect(plain(nested) == "0a!\n1b!")
    }

    @Test func screenReaderText() {
        let graph = ViewGraph()
        var environment = EnvironmentValues()
        environment.isScreenReaderEnabled = true
        let view = VStack {
            HStack {
                Text("Accept")
                Text("terms")
            }
            .accessibilityRole(.checkbox)
            .accessibilityState([.checked])
            Text("secret").accessibilityHidden()
            Text("✔").accessibilityLabel("done")
            VStack { Text("item") }.accessibilityRole(.list)
        }
        graph.mount(view, environment: environment)
        let text = graph.root.map { ScreenReaderRenderer.text(of: $0) }
        #expect(text == "checkbox: (checked) Accept terms\ndone\nlist: item")
    }

    @Test func screenReaderRuntimeFramesAndStatic() {
        struct App: View {
            @State private var lines = ["first"]
            var body: some View {
                VStack {
                    Static(lines) { Text($0) }
                    Text("live").textTransform { line, _ in "X" + line }
                }
            }
        }
        let (runtime, terminal) = makeRuntime(App()) { $0.isScreenReaderEnabled = true }
        #expect(runtime.isScreenReaderEnabled)
        #expect(terminal.output.contains("first"))
        #expect(terminal.output.contains("live"))
        #expect(!terminal.output.contains("Xlive"))
    }

    @Test func suspendTerminalHandsOverAndRedraws() async throws {
        struct App: View {
            @Environment(\.suspendTerminal) private var suspendTerminal
            @State private var result = 0
            var body: some View {
                Text("result \(result)").task {
                    result = (try? await suspendTerminal { 42 }) ?? -1
                }
            }
        }
        let (runtime, terminal) = makeRuntime(App())
        await runtime.waitUntil { terminal.output.contains("result 42") }
        #expect(terminal.suspensions == 1)
        #expect(terminal.output.contains("result 42"))
        let standalone = try await EnvironmentValues().suspendTerminal { "ran" }
        #expect(standalone == "ran")
    }
}
