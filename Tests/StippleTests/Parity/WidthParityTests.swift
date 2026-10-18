import Testing

@testable import Stipple

/// Ports of Ink's `text-width.tsx`, `truncate-width.tsx`, `text-controls.tsx`,
/// `ansi-newlines.tsx`, `c1-rendering.tsx` and `absolute-truncation.tsx`.
@MainActor
struct WidthParityTests {
    private func fixed(_ view: some View, _ width: Int) -> some View {
        view.frame(width: width, alignment: .leading)
    }

    // MARK: text-width

    @Test func zeroWidthSpaceDoesNotOverwriteBorder() {
        let view = Text("he\u{200B}llo").frame(width: 5, alignment: .leading).border()
        #expect(plain(view).replacing("\u{200B}", with: "") == "┌─────┐\n│hello│\n└─────┘")
    }

    @Test func zeroWidthOverlayDoesNotEraseWideCharacters() {
        let view = ZStack(alignment: .topLeading) {
            Text("你好")
            Text("\u{200B}").offset(x: 1)
        }
        #expect(plain(view).replacing("\u{200B}", with: "") == "你好")
    }

    @Test func combiningMarksAndJoinedEmojiRetainGraphemes() {
        let view = Text("e\u{301}👩‍💻").frame(width: 3, alignment: .leading).border()
        #expect(plain(view) == "┌───┐\n│e\u{301}👩‍💻│\n└───┘")
    }

    @Test func crlfDoesNotOverwriteBorders() {
        let view = Text("hello\r\nworld").frame(width: 5, alignment: .leading).border()
        #expect(plain(view) == "┌─────┐\n│hello│\n│world│\n└─────┘")
    }

    @Test func wideCharactersDoNotAddExtraSpace() {
        let view = VStack {
            HStack {
                fixed(Text("🍔"), 2)
                Text("|")
            }
            HStack {
                fixed(Text("⏳"), 2)
                Text("|")
            }
        }
        #expect(plain(view) == "🍔|\n⏳|")
    }

    @Test func cjkInFixedWidth() {
        #expect(
            plain(
                HStack {
                    fixed(Text("你好"), 4)
                    Text("|")
                }) == "你好|")
    }

    @Test func mixedAsciiAndWide() {
        let view = VStack {
            HStack {
                fixed(Text("ab🍔cd"), 6)
                Text("|")
            }
            HStack {
                fixed(Text("abcdef"), 6)
                Text("|")
            }
        }
        #expect(plain(view) == "ab🍔cd|\nabcdef|")
    }

    @Test func styledTextDoesNotAffectLayoutWidth() {
        #expect(
            plain(
                HStack {
                    fixed(Text("hello").foregroundStyle(.red), 5)
                    Text("|")
                }) == "hello|")
    }

    @Test func emptyTextDoesNotAffectSiblings() {
        #expect(
            plain(
                HStack {
                    Text("")
                    Text("hello")
                }) == "hello")
    }

    @Test(arguments: [TruncationMode.tail, .middle, .head])
    func truncatedCJKDoesNotExceedWidth(mode: TruncationMode) {
        let view = Text("あいうえおかきくけこ|end").lineLimit(1).truncationMode(mode).frame(width: 20, alignment: .leading)
        #expect(TextMetrics.width(of: plain(view)) <= 20)
        let row = HStack {
            Text("あいうえおかきくけこ|end").lineLimit(1).truncationMode(mode).frame(width: 20, alignment: .leading)
            Text("|")
        }
        #expect(!plain(row).contains("\n"))
        #expect(plain(row).hasSuffix("|"))
    }

    @Test func overlayOnSecondCellOfWideCharacter() {
        let view = ZStack(alignment: .topLeading) {
            Text("あいうえおかきくけこ")
            Text("XYZ").offset(x: 9)
        }
        #expect(plain(view, width: 20) == "あいうえ XYZきくけこ")
    }

    @Test func overlayOnFirstCellOfWideCharacter() {
        let view = ZStack(alignment: .topLeading) {
            Text("あいうえおかきくけこ")
            Text("X").offset(x: 10)
        }
        #expect(plain(view, width: 20) == "あいうえおX きくけこ")
    }

    // MARK: truncate-width

    @Test(arguments: [
        (TruncationMode.tail, "你…"), (.middle, "你…"), (.head, "…界"),
    ])
    func truncationKeepsWideCharactersThatFit(mode: TruncationMode, expected: String) {
        let text = Text("你好世界").lineLimit(1).truncationMode(mode)
        let check = { #expect(plain(text.frame(width: 4, alignment: .leading)) == expected) }
        check()
    }

    @Test(arguments: [
        (TruncationMode.tail, "你…"), (.middle, "你…"), (.head, "…界"),
    ])
    func truncationPreservesAdjacentColumn(mode: TruncationMode, expected: String) {
        let view = HStack(spacing: 0) {
            Text("你好世界").lineLimit(1).truncationMode(mode).frame(width: 4, alignment: .leading)
            Text("|")
        }
        let check = { #expect(plain(view) == "\(expected) |") }
        check()
    }

    @Test func textThatFitsDoesNotReserveExtraWidth() {
        let view = HStack(spacing: 0) {
            Text("你好").lineLimit(1).truncationMode(.middle)
            Text("|")
        }
        .frame(width: 10, alignment: .leading)
        #expect(plain(view) == "你好|")
    }

    // MARK: text-controls

    @Test(arguments: ["\r", "\u{8}", "\u{B}", "\u{C}", "\u{0}", "\u{1}", "\u{7}", "\u{1A}", "\u{1F}", "\u{7F}"])
    func controlsAreRemovedInsideABorderedBox(control: String) {
        let view = Text("a\(control)b").frame(width: 4, alignment: .leading).border()
        #expect(plain(view) == "┌────┐\n│ab  │\n└────┘")
    }

    @Test(arguments: ["\u{0}", "\u{1}", "\u{7}", "\u{1A}", "\u{1F}", "\u{7F}"])
    func controlsKeepTheSiblingInTheNextColumn(control: String) {
        let view = HStack(spacing: 0) {
            fixed(Text("a\(control)b"), 10)
            Text("|")
        }
        #expect(plain(view) == "ab        |")
    }

    // MARK: ansi-newlines

    @Test(arguments: [("[31m", "[39m"), ("[44m", "[49m"), ("[1m", "[22m")])
    func rawANSIContinuesAcrossNewlines(open: String, close: String) {
        let opener = esc + open
        let closer = esc + close
        let actual = render(Text(ansi: "\(opener)A\nB\(closer)"))
        let expected = render(Text(ansi: "\(opener)A\(closer)\n\(opener)B\(closer)"))
        #expect(actual == expected)
        let stops = render(Text(ansi: "\(opener)A\nB\(closer)\nC"))
        #expect(stops == render(Text(ansi: "\(opener)A\(closer)\n\(opener)B\(closer)\nC")))
    }

    @Test(arguments: [("[31m", "[39m"), ("[44m", "[49m"), ("[1m", "[22m")])
    func rawANSISurvivesBlankLinesAndClipping(open: String, close: String) {
        let opener = esc + open
        let closer = esc + close
        let view = Text(ansi: "\(opener)A\n\nB\(closer)").fixedSize().offset(y: -2).frame(
            height: 1, alignment: .topLeading
        ).clipped()
        #expect(render(view) == render(Text(ansi: "\(opener)B\(closer)")))
    }

    // MARK: c1-rendering

    @Test(arguments: [4, 8])
    func c1SequencesRenderLikeTheirESCForms(width: Int) {
        let pairs = [
            ("\u{9B}31mred\u{9B}0m", "\(esc)[31mred\(esc)[0m"),
            (
                "\u{9D}8;;https://example.com\u{9C}link\u{9D}8;;\u{9C}",
                "\(esc)]8;;https://example.com\(esc)\\link\(esc)]8;;\(esc)\\"
            ),
            (
                "\u{9D}8;;https://example.com\u{7}link\u{9D}8;;\u{7}",
                "\(esc)]8;;https://example.com\u{7}link\(esc)]8;;\u{7}"
            ),
            ("\(esc)[31mred\u{9B}0m", "\(esc)[31mred\(esc)[0m"),
        ]
        for (encoded, standard) in pairs {
            let actual = render(Text(ansi: encoded).frame(width: width, alignment: .leading).border())
            let expected = render(Text(ansi: standard).frame(width: width, alignment: .leading).border())
            #expect(actual == expected)
        }
    }

    // MARK: absolute-truncation

    @Test(arguments: [TruncationMode.tail, .middle, .head])
    func truncatedTextInAnOverlayWithoutWidth(mode: TruncationMode) {
        let view = ZStack(alignment: .topLeading) {
            Text("hello").lineLimit(1).truncationMode(mode)
        }
        .frame(height: 2, alignment: .topLeading)
        #expect(plain(view) == "hello\n")
    }
}
