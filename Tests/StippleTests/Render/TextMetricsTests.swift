import Testing

@testable import Stipple

@Suite struct TextMetricsTests {
    @Test(arguments: [
        ("", 0), ("hello", 5), ("constructor", 11), ("a b", 3),
        ("你好", 4), ("한국어", 6), ("ｱ", 1), ("Ａ", 2), ("\u{3000}", 2),
        ("🍔", 2), ("🍔🍟", 4), ("👩‍💻", 2), ("🇯🇵", 2), ("🇯", 1),
        ("❤\u{FE0F}", 2), ("❤", 1), ("1\u{FE0F}\u{20E3}", 2),
        ("e\u{301}", 1), ("\u{301}", 0), ("a\u{200B}b", 2), ("\u{FEFF}", 0),
        ("\t", 0), ("a\tb", 2), ("a\nb", 2), ("a\r\nb", 2), ("\u{7F}", 0), ("\u{85}", 0),
        ("é", 1), ("ñandú", 5), ("→", 1), ("…", 1), ("\u{AD}", 0),
    ])
    func width(text: String, expected: Int) {
        #expect(TextMetrics.width(of: text) == expected)
    }

    @Test func widthOfSubstring() {
        #expect(TextMetrics.width(of: "ab你好"[...]) == 6)
    }

    @Test func widthOfCharacter() {
        #expect(TextMetrics.width(of: "a") == 1)
        #expect(TextMetrics.width(of: "你") == 2)
        #expect(TextMetrics.width(of: "\u{1B}") == 0)
        #expect(TextMetrics.width(of: "\r\n") == 0)
    }

    @Test func measureEmpty() {
        #expect(TextMetrics.measure("") == .zero)
    }

    @Test(arguments: [
        ("constructor", 11, 1), ("hello\nworld", 5, 2), ("a\nfoo\nhi", 3, 3),
        ("hello\n", 5, 2), ("\n\n", 0, 3), ("你好", 4, 1), ("🍔", 2, 1), ("🍔🍟\nabc", 4, 2),
    ])
    func measure(text: String, width: Int, height: Int) {
        #expect(TextMetrics.measure(text) == Size(width: width, height: height))
    }

    @Test func measureRunsIgnoresStyleBoundaries() {
        let runs = [run("he", .red), run("llo\nwor", .blue), run("ld!")]
        #expect(TextMetrics.measure(runs) == Size(width: 6, height: 2))
        #expect(TextMetrics.measure([]) == .zero)
        #expect(TextMetrics.measure([run("")]) == .zero)
    }

    @Test func measureStyledAnsi() {
        #expect(TextMetrics.measure(ANSIText.parse("\(esc)[31mred\(esc)[0m")) == Size(width: 3, height: 1))
        #expect(TextMetrics.measure(ANSIText.parse("\(esc)[38;5;196mred\(esc)[0m")) == Size(width: 3, height: 1))
    }

    @Test func eastAsianWidthTable() {
        #expect(!EastAsianWidth.isWide(0x41))
        #expect(!EastAsianWidth.isWide(0x10FF))
        #expect(EastAsianWidth.isWide(0x1100))
        #expect(EastAsianWidth.isWide(0x4E00))
        #expect(EastAsianWidth.isWide(0x20000))
        #expect(!EastAsianWidth.isWide(0x4DC0))
        #expect(!EastAsianWidth.isWide(0xE0000))
    }
}
