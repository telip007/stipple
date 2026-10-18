import Testing

@testable import Stipple

@MainActor
struct ModifierTests {
    private func plain(_ view: some View, width: Int = 20) -> String {
        Stipple.renderToString(view, width: width).replacing(/\u{1B}\[[0-9;]*m/, with: "")
    }

    @Test func paddingEdgesAndInsets() {
        #expect(plain(Text("x").padding(.leading, 2)) == "  x")
        #expect(plain(Text("x").padding(EdgeInsets(top: 1, leading: 1))) == "\n x")
        #expect(plain(Text("x").padding().border()) == "┌───┐\n│   │\n│ x │\n│   │\n└───┘")
    }

    @Test func fixedFrameClipsAndAligns() {
        #expect(plain(Text("abcdef").frame(width: 3)) == "abc\ndef")
        #expect(plain(Text("abcdef").frame(width: 3, height: 1).clipped()) == "abc")
        #expect(plain(Text("a").frame(width: 3, height: 3, alignment: .bottomTrailing)) == "\n\n  a")
        #expect(plain(Text("a").frame(width: 3, alignment: .center)) == " a")
    }

    @Test func flexibleFrameBounds() {
        #expect(plain(Text("a").frame(minWidth: 4, alignment: .trailing)) == "   a")
        #expect(plain(Text("abcdef").frame(maxWidth: 3)) == "abc\ndef")
        #expect(plain(Text("a").frame(minHeight: 2, alignment: .bottom)) == "\na")
        #expect(plain(Text("a").frame(idealWidth: 5, alignment: .trailing).fixedSize()) == "    a")
    }

    @Test func offsetMovesWithoutLayout() {
        #expect(
            plain(
                VStack {
                    Text("a").offset(x: 2)
                    Text("b")
                }) == "  a\nb")
    }

    @Test func layoutPriorityWinsSpace() {
        let view = HStack {
            Text("aaaa")
            Text("bbbb").layoutPriority(1)
        }
        #expect(plain(view, width: 6) == "aabbbb\naa")
    }

    @Test func zstackOverlays() {
        let view = ZStack(alignment: .center) {
            Text("-----")
            Text("x")
        }
        #expect(plain(view) == "--x--")
    }

    @Test func styleModifiersCascade() {
        let output = Stipple.renderToString(
            VStack {
                Text("a")
                Text("b").bold(false)
            }
            .foregroundStyle(.red).bold().italic().underline().strikethrough().dim().inverse()
        )
        #expect(output.contains("31"))
        #expect(output.contains("a"))
        #expect(output.contains("b"))
    }

    @Test func textModifiersAndConcatenation() {
        let text =
            Text("a").foregroundStyle(.blue).background(.white).bold().italic().underline()
            .strikethrough().dim().inverse().link("https://example.com") + Text(verbatim: "b")
        let output = Stipple.renderToString(text)
        #expect(output.contains("\u{1B}]8;;https://example.com"))
        #expect(output.replacing(/\u{1B}\][^\u{7}\u{1B}]*(\u{7}|\u{1B}\\)/, with: "").contains("b"))
    }

    @Test func ansiText() {
        #expect(plain(Text(ansi: "\u{1B}[32mgreen\u{1B}[39m plain")) == "green plain")
    }

    @Test func lineLimitAndTruncation() {
        #expect(plain(Text("hello world").lineLimit(1), width: 8) == "hello w…")
        #expect(plain(Text("hello world").lineLimit(1).truncationMode(.head), width: 8) == "…o world")
        #expect(plain(Text("one two three four").lineLimit(2), width: 8).split(separator: "\n").count == 2)
    }

    @Test func headTruncationKeepsTheLastLines() {
        func lines(_ view: some View, width: Int) -> [String] {
            plain(view, width: width).split(separator: "\n").map {
                String($0.drop { $0 == " " }.reversed().drop { $0 == " " }.reversed())
            }
        }
        #expect(
            lines(Text("one two three four five").lineLimit(2).truncationMode(.head), width: 10) == [
                "…hree four", "five",
            ])
        #expect(lines(Text("a\nb\nc\nd").lineLimit(2).truncationMode(.head), width: 8) == ["…c", "d"])
        #expect(lines(Text("a\nb").lineLimit(2).truncationMode(.head), width: 8) == ["a", "b"])
    }

    @Test func multilineAlignment() {
        let view = Text("a\nbbb").multilineTextAlignment(.trailing)
        #expect(plain(view) == "  a\nbbb")
        #expect(plain(Text("a\nbbb").multilineTextAlignment(.center)) == " a\nbbb")
    }

    @Test func backgroundFillsAndInherits() {
        let output = Stipple.renderToString(Text("x").padding(.horizontal, 1).background(.blue))
        #expect(output.contains("44"))
    }

    @Test func customViewModifier() {
        struct Card: ViewModifier {
            @State private var title = "T"
            func body(content: Content) -> some View {
                VStack {
                    Text(title)
                    content
                }.border(.rounded)
            }
        }
        #expect(plain(Text("x").modifier(Card())) == "╭─╮\n│T│\n│x│\n╰─╯")
    }

    @Test func groupAndAnyViewAndEmpty() {
        let view = VStack {
            Group {
                Text("a")
                Text("b")
            }
            AnyView(Text("c"))
            AnyView(AnyView(Text("d")))
            EmptyView()
            Optional<Text>.none
        }
        #expect(plain(view) == "a\nb\nc\nd")
    }

    @Test func spacerOutsideStackIsEmpty() {
        #expect(plain(Spacer(minLength: 3)).isEmpty)
        #expect(
            plain(
                VStack {
                    Text("a")
                    Spacer(minLength: 1)
                    Text("b")
                }) == "a\n\nb")
    }

    @Test func forEachWithIdentifiableAndKeyPath() {
        struct Item: Identifiable {
            let id: Int
            let name: String
        }
        let items = [Item(id: 1, name: "one"), Item(id: 2, name: "two")]
        #expect(plain(VStack { ForEach(items) { Text($0.name) } }) == "one\ntwo")
        #expect(plain(HStack(spacing: 1) { ForEach(["x", "y"], id: \.self) { Text($0) } }) == "x y")
    }
}
