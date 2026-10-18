import Testing

@testable import Stipple

/// Ports of Ink's `components.tsx` (text wrapping, Newline, Spacer, Static, Transform).
@MainActor
struct ComponentParityTests {
    @Test func text() {
        #expect(plain(Text("Hello World")) == "Hello World")
        #expect(plain(Text("Count: \(1)")) == "Count: 1")
        #expect(plain(Text("\(1)")) == "1")
    }

    @Test func multipleTextNodes() {
        #expect(plain(Text("Hello") + Text(" World")) == "Hello World")
    }

    @Test func textWithComponent() {
        struct World: View {
            var body: some View { Text("World") }
        }
        #expect(
            plain(
                HStack {
                    Text("Hello ")
                    World()
                }) == "Hello World")
    }

    @Test func wrapText() {
        #expect(plain(Text("Hello World").frame(width: 7, alignment: .leading)) == "Hello\nWorld")
        #expect(plain(Text("Hello World").frame(width: 20, alignment: .leading)) == "Hello World")
    }

    @Test(.disabled("No hard-wrap mode (Ink wrap=\"hard\" gives 'Hello W\\norld'); Text always breaks at spaces"))
    func hardWrapText() {}

    @Test func hardWrapWithLongWord() {
        #expect(plain(Text("aaaaaaaaaa").frame(width: 5, alignment: .leading)) == "aaaaa\naaaaa")
    }

    @Test func truncateEnd() {
        let view = Text("Hello World").lineLimit(1).frame(width: 7, alignment: .leading)
        #expect(plain(view) == "Hello …")
    }

    @Test func truncateMiddle() {
        let view = Text("Hello World").lineLimit(1).truncationMode(.middle).frame(width: 7, alignment: .leading)
        #expect(plain(view) == "Hel…rld")
    }

    @Test func truncateStart() {
        let view = Text("Hello World").lineLimit(1).truncationMode(.head).frame(width: 7, alignment: .leading)
        #expect(plain(view) == "… World")
    }

    @Test func truncatesEachLineOfMultilineText() {
        // Ink's `truncate` cuts every line on its own and keeps all lines. SwiftUI's lineLimit(1) shows only the first.
        let view = Text("hello world\nfoo").lineLimit(1).frame(width: 6, alignment: .leading)
        withKnownIssue("lineLimit(1) drops the lines after the first instead of truncating each line") {
            #expect(plain(view) == "hello…\nfoo")
        }
    }

    @Test(arguments: [
        "\(esc)]8;;https://example.com\u{7}Click here\(esc)]8;;\u{7}",
        "\(esc)]8;;https://example.com\(esc)\\Click here\(esc)]8;;\(esc)\\",
    ])
    func hyperlinkDoesNotWrap(input: String) {
        #expect(plain(Text(ansi: input).frame(width: 20, alignment: .leading)) == "Click here")
    }

    @Test func nonHyperlinkOSCDoesNotWrap() {
        #expect(
            plain(Text(ansi: "\(esc)]0;My Title\u{7}Some text").frame(width: 20, alignment: .leading)) == "Some text")
    }

    @Test(arguments: [
        "\(esc)]8;;https://example.com\u{7}abcdefghij\(esc)]8;;\u{7}",
        "\(esc)]8;;https://example.com\(esc)\\abcdefghij\(esc)]8;;\(esc)\\",
    ])
    func hyperlinkHardWraps(input: String) {
        #expect(plain(Text(ansi: input).frame(width: 5, alignment: .leading)) == "abcde\nfghij")
    }

    @Test func hyperlinkKeepsLinkOnEveryLine() {
        let output = render(
            Text(ansi: "\(esc)]8;;https://example.com\u{7}abcdefghij\(esc)]8;;\u{7}").frame(
                width: 5, alignment: .leading))
        let lines = output.split(separator: "\n")
        #expect(lines.count == 2)
        for line in lines {
            #expect(line.hasPrefix("\(esc)]8;;https://example.com"))
            #expect(line.hasSuffix("\(esc)]8;;\(esc)\\"))
        }
    }

    @Test func emptyTextNodeIsIgnored() {
        #expect(
            plain(
                VStack {
                    HStack { Text("Hello World") }
                    Text("")
                }) == "Hello World")
        #expect(plain(Text("")).isEmpty)
    }

    @Test func leadingWhitespaceIsKept() {
        #expect(render(Text(" ERROR ").foregroundStyle(.red)) == "\(esc)[31m ERROR \(esc)[39m")
    }

    @Test func newline() {
        #expect(plain(Text("Hello\nWorld")) == "Hello\nWorld")
        #expect(plain(Text("Hello\n\nWorld")) == "Hello\n\nWorld")
    }

    @Test func horizontalSpacer() {
        let view = HStack {
            Text("Left")
            Spacer()
            Text("Right")
        }.frame(width: 20, alignment: .topLeading)
        #expect(plain(view) == "Left           Right")
    }

    @Test func verticalSpacer() {
        let view = VStack {
            Text("Top")
            Spacer()
            Text("Bottom")
        }.frame(height: 6, alignment: .topLeading)
        #expect(plain(view) == "Top\n\n\n\n\nBottom")
    }

    @Test func linkEscapesAreClosed() {
        let output = render(Text("Example").link("https://example.com"))
        #expect(output == "\(esc)]8;;https://example.com\(esc)\\Example\(esc)]8;;\(esc)\\")
    }

    @Test func replaceChildNodeWithText() {
        struct Dynamic: View {
            var replace: Bool
            var body: some View {
                if replace { Text("x") } else { Text("test").foregroundStyle(.green) }
            }
        }
        #expect(render(Dynamic(replace: false)) == "\(esc)[32mtest\(esc)[39m")
        #expect(render(Dynamic(replace: true)) == "x")
    }

    @Test func removingFrameRestoresNaturalHeight() {
        struct Dynamic: View {
            var remove: Bool
            var body: some View {
                if remove {
                    VStack { Text("x") }
                } else {
                    VStack {
                        Spacer()
                        Text("x")
                    }.frame(height: 4, alignment: .topLeading)
                }
            }
        }
        #expect(plain(Dynamic(remove: false)) == "\n\n\nx")
        #expect(plain(Dynamic(remove: true)) == "x")
    }

    // MARK: Static

    @Test(.disabled("Static takes no padding/style; renderToString placement of static items is unspecified"))
    func staticOutput() {
        // Ink: Static(['A','B','C'], paddingBottom 1) beside a Box(marginTop 1){X} gives 'A\nB\nC\n\n\nX'.
        let view = HStack {
            Static(["A", "B", "C"]) { Text($0) }
            Text("X").padding(.top, 1)
        }
        #expect(plain(view) == "A\nB\nC\n\n\nX")
    }

    @Test func staticItemsAppearInRenderToString() {
        let view = VStack(alignment: .leading) {
            Static(["A", "B"]) { Text($0) }
            Text("live")
        }
        withKnownIssue("renderToString leaves out Static items; Ink's renderToString returns them before the frame") {
            #expect(plain(view) == "A\nB\nlive")
        }
    }

    // MARK: Transform

    @Test(
        .disabled(
            "No Transform/textTransform in Stipple yet; Ink: transform (line, index) => [index: line] over a Text"))
    func transformChildren() {}
}
