import Testing

@testable import Stipple

@MainActor
struct RenderToStringTests {
    private func plain(_ view: some View, width: Int = 20) -> String {
        Stipple.renderToString(view, width: width).replacing(/\u{1B}\[[0-9;]*m/, with: "")
    }

    @Test func text() {
        #expect(plain(Text("Hello")) == "Hello")
    }

    @Test func wrapsAtProposedWidth() {
        // Ink wraps with wrap-ansi's `trim: false`: when a row ends exactly at
        // the width, the separating space starts the next row.
        #expect(plain(Text("Hello world, this wraps"), width: 11) == "Hello\nworld, this\n wraps")
    }

    @Test func vstackAndHStack() {
        let view = VStack {
            Text("A")
            HStack(spacing: 1) {
                Text("B")
                Text("C")
            }
        }
        #expect(plain(view) == "A\nB C")
    }

    @Test func spacerPushesApart() {
        let view = HStack {
            Text("L")
            Spacer()
            Text("R")
        }
        #expect(plain(view, width: 10) == "L        R")
    }

    @Test func paddingAndBorder() {
        let view = Text("Hi").padding(.horizontal, 1).border(.rounded)
        #expect(plain(view) == "╭────╮\n│ Hi │\n╰────╯")
    }

    @Test func frameAlignment() {
        let view = Text("ab").frame(width: 6, alignment: .trailing).border()
        #expect(plain(view) == "┌──────┐\n│    ab│\n└──────┘")
    }

    @Test func flexibleFrameFills() {
        let view = Text("x").frame(maxWidth: .infinity, alignment: .leading).border()
        #expect(plain(view, width: 6) == "┌────┐\n│x   │\n└────┘")
    }

    @Test func conditionalAndForEach() {
        struct Rows: View {
            var show: Bool
            var body: some View {
                VStack {
                    if show {
                        Text("shown")
                    } else {
                        Text("hidden")
                    }
                    ForEach(1..<3) { Text("row \($0)") }
                }
            }
        }
        #expect(plain(Rows(show: true)) == "shown\nrow 1\nrow 2")
        #expect(plain(Rows(show: false)) == "hidden\nrow 1\nrow 2")
    }

    @Test func stateInitialValue() {
        struct Counter: View {
            @State private var count = 3
            var body: some View { Text("Count: \(count)") }
        }
        #expect(plain(Counter()) == "Count: 3")
    }

    @Test func styledTextEmitsSGR() {
        let output = Stipple.renderToString(Text("ok").foregroundStyle(.green).bold())
        #expect(output.contains("\u{1B}["))
        #expect(output.contains("ok"))
    }

    @Test func staticOutputPrecedesFrame() {
        let view = VStack {
            Static(["a", "b"]) { Text($0) }
            Text("live")
        }
        #expect(plain(view) == "a\nb\nlive")
    }
}
