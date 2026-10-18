import Testing

@testable import Stipple

@Suite struct TextLayoutTests {
    // MARK: lines

    @Test func linesSplitOnNewline() {
        let lines = TextLayout.lines([run("ab\ncd", .red), run("e\n\nf")])
        #expect(texts(lines) == ["ab", "cde", "", "f"])
        #expect(lines[1] == [run("cd", .red), run("e")])
    }

    @Test func linesOfEmptyInput() {
        #expect(TextLayout.lines([]) == [[]])
        #expect(TextLayout.lines([run("")]) == [[]])
        #expect(texts(TextLayout.lines([run("a\n")])) == ["a", ""])
    }

    @Test func linesMergeNeighboursOfEqualStyle() {
        #expect(TextLayout.lines([run("a", .red), run("b", .red)]) == [[run("ab", .red)]])
    }

    @Test func linesKeepCarriageReturnAttachedToNewline() {
        #expect(texts(TextLayout.lines([run("a\r\nb")])) == ["a\r", "b"])
    }

    // MARK: wrap

    @Test(arguments: [
        ("hello world", 5, ["hello", " ", "world"]),
        ("hello world", 20, ["hello world"]),
        ("hello world", 11, ["hello world"]),
        ("hello world", 10, ["hello ", "world"]),
        ("abcdefghij", 5, ["abcde", "fghij"]),
        ("abcdefghijk", 5, ["abcde", "fghij", "k"]),
        ("ab cdefgh", 4, ["ab ", "cdef", "gh"]),
        ("a b c", 3, ["a b", " c"]),
        ("ab\ncd", 5, ["ab", "cd"]),
        ("ab\n\ncd", 5, ["ab", "", "cd"]),
        ("", 5, [""]),
        ("你好吗", 4, ["你好", "吗"]),
        ("你好吗", 5, ["你好", "吗"]),
        ("a你b", 2, ["a", "你", "b"]),
        ("  indented", 20, ["  indented"]),
        ("trailing ", 20, ["trailing "]),
        ("e\u{301}x", 1, ["e\u{301}", "x"]),
    ])
    func wrap(input: String, width: Int, expected: [String]) {
        #expect(texts(TextLayout.wrap([run(input)], width: width)) == expected)
    }

    @Test func wrapWithoutRoomKeepsLines() {
        #expect(texts(TextLayout.wrap([run("hello world\nx")], width: 0)) == ["hello world", "x"])
        #expect(texts(TextLayout.wrap([run("hello")], width: -3)) == ["hello"])
    }

    @Test func wrapKeepsStylesAcrossBreaks() {
        let lines = TextLayout.wrap([run("hello ", .red), run("world", .blue)], width: 5)
        #expect(lines == [[run("hello", .red)], [run(" ", .red)], [run("world", .blue)]])
    }

    @Test func wrapBreaksWordInsideStyledRun() {
        let lines = TextLayout.wrap([run("abcdef", .red)], width: 4)
        #expect(lines == [[run("abcd", .red)], [run("ef", .red)]])
    }

    @Test func wrapDropsZeroWidthControls() {
        #expect(texts(TextLayout.wrap([run("a\u{7}b")], width: 5)) == ["ab"])
    }

    // MARK: truncate

    @Test(arguments: [
        ("hello world", 5, TruncationMode.tail, "hell…"),
        ("hello world", 6, .middle, "hel…ld"),
        ("hello world", 6, .head, "…world"),
        ("hello world", 7, .middle, "hel…rld"),
        ("hello", 5, .tail, "hello"),
        ("hello", 9, .head, "hello"),
        ("hello world", 1, .tail, "…"),
        ("hello world", 1, .middle, "…"),
        ("hello world", 2, .head, "…d"),
        ("hello world", 2, .middle, "h…"),
        ("你好吗", 4, .tail, "你…"),
        ("你好吗", 5, .tail, "你好…"),
        ("你好吗", 4, .head, "…吗"),
        ("你好吗", 4, .middle, "你…"),
        ("abcdef", 4, .tail, "abc…"),
    ])
    func truncate(input: String, width: Int, mode: TruncationMode, expected: String) {
        #expect(text(TextLayout.truncate([run(input)], width: width, mode: mode)) == expected)
    }

    @Test func truncateBelowOneColumnIsEmpty() {
        #expect(TextLayout.truncate([run("abc")], width: 0, mode: .tail).isEmpty)
        #expect(TextLayout.truncate([run("abc")], width: -1, mode: .head).isEmpty)
    }

    @Test func truncateReturnsFittingRunsUnchanged() {
        let runs = [run("ab", .red), run("c", .blue)]
        #expect(TextLayout.truncate(runs, width: 3, mode: .tail) == runs)
    }

    @Test func ellipsisTakesStyleOfNeighbour() {
        let runs = [run("abc", .red), run("def", .blue)]
        #expect(TextLayout.truncate(runs, width: 4, mode: .tail) == [run("abc…", .red)])
        #expect(TextLayout.truncate(runs, width: 4, mode: .head) == [run("…def", .blue)])
        #expect(
            TextLayout.truncate(runs, width: 5, mode: .middle)
                == [run("ab…", .red), run("ef", .blue)])
    }

    @Test func ellipsisWithoutRunsIsPlain() {
        #expect(TextLayout.truncate([], width: 1, mode: .tail).isEmpty)
    }
}
