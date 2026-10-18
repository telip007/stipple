import Testing

@testable import Stipple

@Suite struct ANSITextTests {
    private func parse(_ text: String) -> [StyledRun] {
        ANSIText.parse(text)
    }

    @Test func plainText() {
        #expect(parse("hello") == [run("hello")])
        #expect(parse("").isEmpty)
    }

    @Test func basicSGR() {
        let runs = parse("A\(esc)[1;4mtext\(esc)[0mB")
        let bold = Style(attributes: [.bold, .underline])
        #expect(runs == [run("A"), run("text", bold), run("B")])
    }

    @Test func colors() {
        #expect(parse("\(esc)[31mx") == [run("x", Style(foreground: .red))])
        #expect(parse("\(esc)[91mx") == [run("x", Style(foreground: .brightRed))])
        #expect(parse("\(esc)[44mx") == [run("x", Style(background: .blue))])
        #expect(parse("\(esc)[104mx") == [run("x", Style(background: .brightBlue))])
        #expect(parse("\(esc)[38;5;196mx") == [run("x", Style(foreground: .palette(196)))])
        #expect(parse("\(esc)[48;5;21mx") == [run("x", Style(background: .palette(21)))])
        #expect(
            parse("\(esc)[38;2;232;131;136mx") == [run("x", Style(foreground: Color(red: 232, green: 131, blue: 136)))])
        #expect(parse("\(esc)[48;2;1;2;3mx") == [run("x", Style(background: Color(red: 1, green: 2, blue: 3)))])
    }

    @Test func resets() {
        let styled = Style(
            foreground: .red, background: .blue, attributes: [.bold, .italic, .inverse, .strikethrough, .dim])
        #expect(parse("\(esc)[31;44;1;2;3;7;9mx") == [run("x", styled)])
        #expect(parse("\(esc)[31;44;1;2;3;7;9;39;49;22;23;27;29mx") == [run("x")])
        #expect(
            parse("\(esc)[4;24mx\(esc)[31m\(esc)[mx\(esc)[;1my") == [run("xx"), run("y", Style(attributes: .bold))])
        #expect(parse("\(esc)[1m\(esc)[0mx") == [run("x")])
    }

    @Test(arguments: [
        ("38:5:196", Color.palette(196)),
        ("38:2::255:0:0", Color(red: 255, green: 0, blue: 0)),
        ("38:2:0:255:0:0", Color(red: 255, green: 0, blue: 0)),
        ("38:2:255:0:0", Color(red: 255, green: 0, blue: 0)),
    ])
    func colonColors(parameters: String, expected: Color) {
        #expect(parse("\(esc)[\(parameters)mx") == [run("x", Style(foreground: expected))])
    }

    @Test func colonBackgroundAndMixedParameters() {
        let style = Style(foreground: .palette(196), background: Color(red: 0, green: 0, blue: 255), attributes: .bold)
        #expect(parse("\(esc)[1;38:5:196;48:2::0:0:255mx") == [run("x", style)])
    }

    @Test(arguments: ["4:1", "4:3", "4"])
    func underlineStyles(parameters: String) {
        #expect(parse("\(esc)[\(parameters)mx") == [run("x", Style(attributes: .underline))])
    }

    @Test(arguments: ["4:0", "4:"])
    func underlineOff(parameters: String) {
        #expect(parse("\(esc)[4m\(esc)[\(parameters)mx") == [run("x")])
    }

    @Test(arguments: ["58:5:1", "58:2::1:2:3", "38:2:1:255:0:0", "38:5:196:0", "58;5;1", "58;2;1;2;3", "38:9"])
    func unsupportedColorsAreDropped(parameters: String) {
        #expect(parse("\(esc)[\(parameters)mtext") == [run("text")])
    }

    @Test func droppedColorKeepsOtherParameters() {
        #expect(parse("\(esc)[1;58:5:1;31mx") == [run("x", Style(foreground: .red, attributes: .bold))])
        #expect(parse("\(esc)[58;5;1;31mx") == [run("x", Style(foreground: .red))])
    }

    @Test func truncatedExtendedColorsConsumeTheRest() {
        #expect(parse("\(esc)[38;5mx") == [run("x")])
        #expect(parse("\(esc)[38;2;1;2mx") == [run("x")])
        // An unknown extended color kind is skipped; the parameters after it apply on their own.
        #expect(parse("\(esc)[38;7;31mx") == [run("x", Style(foreground: .red, attributes: .inverse))])
    }

    @Test func outOfRangeValuesClamp() {
        #expect(parse("\(esc)[38;5;999mx") == [run("x", Style(foreground: .palette(255)))])
        #expect(parse("\(esc)[38;2;300;0;0mx") == [run("x", Style(foreground: Color(red: 255, green: 0, blue: 0)))])
    }

    @Test func nonSGRFinalsAndPrivateParametersAreDropped() {
        #expect(parse("A\(esc)[>4;2mB") == [run("AB")])
        #expect(parse("A\(esc)[2 qB\(esc)[2JC\(esc)[10;5HD") == [run("ABCD")])
        #expect(parse("A\u{9B}>4;2mB\u{9B}2 qC") == [run("ABC")])
        #expect(parse("A\u{9B}31mB") == [run("A"), run("B", Style(foreground: .red))])
    }

    @Test func hyperlinks() {
        let link = Style(link: "https://example.com")
        #expect(parse("\(esc)]8;;https://example.com\(esc)\\link\(esc)]8;;\(esc)\\") == [run("link", link)])
        #expect(parse("\(esc)]8;;https://example.com\u{9C}link\(esc)]8;;\u{9C}!") == [run("link", link), run("!")])
        #expect(parse("\u{9D}8;;https://example.com\u{7}link\u{9D}8;;\u{7}") == [run("link", link)])
        #expect(parse("\u{9D}8;;https://example.com\(esc)\\link\u{9D}8;;\(esc)\\") == [run("link", link)])
        #expect(parse("\(esc)]8;id=1;https://a.b/?x=1;2\u{7}t") == [run("t", Style(link: "https://a.b/?x=1;2"))])
    }

    @Test func linkSurvivesSGRReset() {
        let runs = parse("\(esc)]8;;u\u{7}a\(esc)[31mb\(esc)[0mc")
        #expect(
            runs == [
                run("a", Style(link: "u")), run("b", Style(foreground: .red, link: "u")), run("c", Style(link: "u")),
            ])
    }

    @Test func otherOSCIsDropped() {
        #expect(parse("A\(esc)]0;window title\u{7}B") == [run("AB")])
        #expect(parse("A\(esc)]8;;\u{7}B") == [run("AB")])
    }

    @Test func controlStringsAreDropped() {
        #expect(parse("A\(esc)Ptmux;\(esc)\(esc)]8;;https://example.com\(esc)\(esc)\\\(esc)\\B") == [run("AB")])
        #expect(parse("A\(esc)Ppayload\u{7}still\(esc)\\B") == [run("AB")])
        #expect(parse("A\(esc)Xpayload\(esc)\\B") == [run("AB")])
        #expect(parse("A\(esc)Xpayload\u{9C}B") == [run("AB")])
        #expect(parse("A\u{98}payload\u{9C}B") == [run("AB")])
        #expect(parse("A\(esc)\\B") == [run("AB")])
        #expect(parse("A\u{9C}B") == [run("AB")])
        #expect(parse("A\u{85}B\u{8E}C") == [run("ABC")])
    }

    @Test func malformedInputDropsTheRest() {
        #expect(parse("A\(esc)Xpayload") == [run("A")])
        #expect(parse("A\(esc)Xpayload\u{7}B") == [run("A")])
        #expect(parse("A\u{98}payload") == [run("A")])
        #expect(parse("A\(esc)#\u{7}payload") == [run("A")])
        #expect(parse("A\(esc)[31mB\(esc)[") == [run("A"), run("B", Style(foreground: .red))])
    }

    @Test func controlCharactersAreStripped() {
        #expect(parse("a\u{7}b\u{0}c\rd\u{7F}e") == [run("abcde")])
        #expect(parse("a\tb\nc") == [run("a\tb\nc")])
        #expect(parse("a\r\nb") == [run("a\nb")])
        #expect(parse("e\(esc)[31m\r\u{301}X") == [run("e\u{301}"), run("X", Style(foreground: .red))])
    }

    @Test func combiningMarksStayWithTheirBase() {
        let red = Style(foreground: .red)
        #expect(
            parse("e\(esc)[31m\(esc)[1m\u{301}X\(esc)[39m") == [
                run("e\u{301}"), run("X", Style(foreground: .red, attributes: .bold)),
            ])
        #expect(parse("e\(esc)[31m\u{301}") == [run("e\u{301}")])
        #expect(parse("\(esc)[31m\u{301}X") == [run("\u{301}X", red)])
        #expect(parse("e\n\(esc)[31m\u{301}X") == [run("e\n"), run("\u{301}X", red)])
        #expect(parse("\u{301}") == [run("\u{301}")])
    }

    @Test func encodeUsesMinimalTransitions() {
        let bold = Style(foreground: .red, attributes: .bold)
        let runs = [run("a"), run("b", bold), run("c", Style(foreground: .red)), run("d")]
        #expect(ANSIText.encode(runs) == "a\(esc)[1;31mb\(esc)[22mc\(esc)[39md")
        #expect(ANSIText.encode([]).isEmpty)
        #expect(ANSIText.encode([run("", bold)]).isEmpty)
    }

    @Test func encodeRoundTrips() {
        let input = "\(esc)[1;31mred\(esc)[22;44m on blue\(esc)[49;39m \(esc)[38;2;1;2;3mrgb\(esc)[39m"
        let runs = parse(input)
        #expect(parse(ANSIText.encode(runs)) == runs)
    }
}
