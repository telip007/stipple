import Testing

@testable import Stipple

@Suite struct SGRTests {
    @Test func foregroundEncoding() {
        #expect(SGR.foreground(.black) == "30")
        #expect(SGR.foreground(.white) == "37")
        #expect(SGR.foreground(.gray) == "90")
        #expect(SGR.foreground(.brightWhite) == "97")
        #expect(SGR.foreground(.palette(200)) == "38;5;200")
        #expect(SGR.foreground(Color(red: 1, green: 2, blue: 3)) == "38;2;1;2;3")
    }

    @Test func backgroundEncoding() {
        #expect(SGR.background(.black) == "40")
        #expect(SGR.background(.white) == "47")
        #expect(SGR.background(.gray) == "100")
        #expect(SGR.background(.brightWhite) == "107")
        #expect(SGR.background(.palette(7)) == "48;5;7")
        #expect(SGR.background(Color(red: 255, green: 128, blue: 0)) == "48;2;255;128;0")
    }

    @Test func noChangeIsEmpty() {
        let style = Style(foreground: .red, attributes: .bold)
        #expect(SGR.transition(from: style, to: style).isEmpty)
    }

    @Test func switchOnAndOff() {
        let all = Style(attributes: [.bold, .dim, .italic, .underline, .inverse, .strikethrough])
        #expect(SGR.transition(from: .plain, to: all) == "\(esc)[1;2;3;4;7;9m")
        #expect(SGR.transition(from: all, to: .plain) == "\(esc)[22;23;24;27;29m")
    }

    @Test func colorChanges() {
        let red = Style(foreground: .red, background: .blue)
        #expect(SGR.transition(from: .plain, to: red) == "\(esc)[31;44m")
        #expect(SGR.transition(from: red, to: .plain) == "\(esc)[39;49m")
        #expect(SGR.transition(from: red, to: Style(foreground: .green, background: .blue)) == "\(esc)[32m")
    }

    @Test func clearingBoldKeepsDim() {
        let both = Style(attributes: [.bold, .dim])
        #expect(SGR.transition(from: both, to: Style(attributes: .dim)) == "\(esc)[22;2m")
        #expect(SGR.transition(from: both, to: Style(attributes: .bold)) == "\(esc)[22;1m")
        #expect(SGR.transition(from: Style(attributes: .bold), to: Style(attributes: .dim)) == "\(esc)[22;2m")
    }

    @Test func hyperlinks() {
        let link = Style(link: "https://example.com")
        #expect(SGR.transition(from: .plain, to: link) == "\(esc)]8;;https://example.com\(esc)\\")
        #expect(SGR.transition(from: link, to: .plain) == "\(esc)]8;;\(esc)\\")
        let other = Style(link: "https://example.org")
        #expect(
            SGR.transition(from: link, to: other)
                == "\(esc)]8;;\(esc)\\\(esc)]8;;https://example.org\(esc)\\")
    }

    @Test func linkAndColorTogether() {
        let styled = Style(foreground: .red, link: "u")
        #expect(SGR.transition(from: .plain, to: styled) == "\(esc)[31m\(esc)]8;;u\(esc)\\")
        #expect(SGR.transition(from: styled, to: .plain) == "\(esc)]8;;\(esc)\\\(esc)[39m")
    }
}
