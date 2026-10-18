import Testing

@testable import Stipple

/// Ports of Ink's `test/text.tsx`.
@MainActor
struct TextParityTests {
    @Test func emptyText() {
        #expect(render(Text("")).isEmpty)
    }

    @Test func standardColor() {
        #expect(render(Text("Test").foregroundStyle(.green)) == "\(esc)[32mTest\(esc)[39m")
    }

    @Test func dimmedColor() {
        let output = render(Text("Test").foregroundStyle(.green).dim())
        #expect(sameStyledText(output, "\(esc)[32m\(esc)[2mTest\(esc)[22m\(esc)[39m"))
    }

    @Test func dimBold() {
        let output = render(Text("Test").dim().bold())
        #expect(output != "Test")
        #expect(plain(Text("Test").dim().bold()) == "Test")
    }

    @Test func hexRgbAndPaletteColors() {
        let orange = Color(hex: "#FF8800")
        #expect(render(Text("Test").foregroundStyle(orange)) == "\(esc)[38;2;255;136;0mTest\(esc)[39m")
        #expect(render(Text("Test").foregroundStyle(.palette(194))) == "\(esc)[38;5;194mTest\(esc)[39m")
    }

    @Test func backgroundColors() {
        #expect(render(Text("Test").background(.green)) == "\(esc)[42mTest\(esc)[49m")
        #expect(
            render(Text("Test").background(Color(hex: "#FF8800")))
                == "\(esc)[48;2;255;136;0mTest\(esc)[49m")
        #expect(render(Text("Test").background(.palette(194))) == "\(esc)[48;5;194mTest\(esc)[49m")
    }

    @Test func inverse() {
        #expect(render(Text("Test").inverse()) == "\(esc)[7mTest\(esc)[27m")
    }

    @Test func emptyToNonEmptySiblingDoesNotWrap() {
        #expect(plain(HStack { Text("" + "hello") }) == "hello")
        #expect(plain(HStack { Text("x" + "hello") }) == "xhello")
    }

    @Test func contentNamedConstructor() {
        #expect(plain(Text("constructor")) == "constructor")
    }

    @Test func nestedTextSegmentsConcatenate() {
        #expect(plain(Text("abc") + Text("x")) == "abcx")
    }

    // MARK: Tabs (Ink expands them to 8-column tab stops)

    @Test func tabsAreExpandedToEightColumnStops() {
        let view = HStack {
            Text("A" + "\tB")
            Text("!")
        }
        #expect(plain(view) == "A       B!")
    }

    @Test func expandedTabsParticipateInWrapping() {
        let view = VStack(alignment: .leading) {
            Text("A\tB")
            Text("!")
        }.frame(width: 5, alignment: .topLeading)
        #expect(plain(view) == "A\n   B\n!")
    }

    @Test func tabStopsAccountForStyledWideCharacters() {
        let view = HStack {
            Text("界").foregroundStyle(.red) + Text("\tB")
            Text("!")
        }
        #expect(render(view) == "\(esc)[31m界\(esc)[39m      B!")
    }

    // MARK: ANSI sanitising (Text(ansi:))

    @Test func stripsCursorMovement() {
        let input = "\(esc)[1A\(esc)[2KStarting client ... \(esc)[32mdone\(esc)[0m\(esc)[1B"
        let output = render(Text(ansi: input))
        #expect(!output.contains("\(esc)[1A"))
        #expect(!output.contains("\(esc)[2K"))
        #expect(!output.contains("\(esc)[1B"))
        #expect(plain(Text(ansi: input)) == "Starting client ... done")
    }

    @Test func stripsCursorPositionAndErase() {
        #expect(plain(Text(ansi: "Hello\(esc)[5;10HWorld\(esc)[2J!")) == "HelloWorld!")
    }

    @Test func keepsSGR() {
        let output = render(Text(ansi: "\(esc)[32mgreen\(esc)[0m normal"))
        #expect(output.contains("\(esc)["))
        #expect(plain(Text(ansi: "\(esc)[32mgreen\(esc)[0m normal")) == "green normal")
    }

    @Test(arguments: [
        "\(esc)]8;;https://example.com\u{7}link\(esc)]8;;\u{7}",
        "\(esc)]8;;https://example.com\(esc)\\link\(esc)]8;;\(esc)\\",
        "\u{9D}8;;https://example.com\u{7}link\u{9D}8;;\u{7}",
        "\u{9D}8;;https://example.com\(esc)\\link\u{9D}8;;\(esc)\\",
    ])
    func keepsHyperlinks(input: String) {
        let output = render(Text(ansi: input))
        #expect(output.contains("\(esc)]8;;https://example.com"))
        #expect(plain(Text(ansi: input)) == "link")
    }

    @Test func colonColorsEqualSemicolonColors() {
        let colon = render(Text(ansi: "A\(esc)[38:2::255:100:0mcolor\(esc)[0mB"))
        let semicolon = render(Text(ansi: "A\(esc)[38;2;255;100;0mcolor\(esc)[0mB"))
        #expect(colon == semicolon)
        #expect(colon.contains("\(esc)[38;2;255;100;0m"))
    }

    @Test(arguments: [
        ("A\(esc)[>4;2mB\(esc)[2 qC", "ABC"),
        ("A\u{9B}>4;2mB\u{9B}2 qC", "ABC"),
        ("A\(esc)#8B\(esc)cC", "ABC"),
        ("A\(esc)Ptmux;\(esc)\(esc)]8;;https://example.com\u{7}\(esc)\\", "A"),
        ("A\u{90}payload\(esc)\\B\u{90}payload\u{9C}C", "ABC"),
        ("A\(esc)^pm-payload\(esc)\\B\(esc)_apc-payload\(esc)\\C", "ABC"),
        ("A\u{9E}pm-payload\u{9C}B\u{9F}apc-payload\u{9C}C", "ABC"),
        ("A\(esc)Xpayload\(esc)\\B", "AB"),
        ("A\u{98}payload\(esc)\\B\u{98}payload\u{9C}C", "ABC"),
        ("A\(esc)Xpayload\u{7}B\u{98}payload", "A"),
        ("A\(esc)[32mgreen\(esc)[0m\(esc)Xpayload\(esc)\\B", "AgreenB"),
        ("A\(esc)Ptmux;\(esc)\(esc)]0;title\u{7}\(esc)\\B", "AB"),
        ("\(esc)Ptmux;\(esc)link", ""),
        ("A\u{90}payload", "A"),
        ("A\(esc)]8;;https://example.comlink", "A"),
        ("A\u{9D}8;;https://example.comlink", "A"),
        ("A\(esc)#", "A"),
        ("A\(esc)#\u{7}payload", "A"),
        ("A\u{9C}B", "AB"),
        ("A\u{85}B\u{8E}C", "ABC"),
    ])
    func stripsControlSequences(input: String, expected: String) {
        let output = render(Text(ansi: input))
        #expect(plain(Text(ansi: input)) == expected)
        #expect(!output.contains("payload"))
        #expect(!output.contains("tmux;"))
        #expect(!output.contains("\u{9C}"))
    }
}
