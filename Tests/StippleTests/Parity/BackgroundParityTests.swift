import Testing

@testable import Stipple

/// Ports of Ink's `background.tsx`.
@MainActor
struct BackgroundParityTests {
    private func bg(_ code: String, _ text: String) -> String {
        "\(esc)[\(code)m\(text)\(esc)[49m"
    }

    @Test func textInheritsBoxBackground() {
        #expect(render(HStack { Text("Hello World") }.background(.green)) == bg("42", "Hello World"))
    }

    @Test func textExplicitBackgroundOverridesInherited() {
        let view = HStack { Text("Hello World").background(.blue) }.background(.red)
        #expect(render(view) == bg("44", "Hello World"))
    }

    @Test func nestedBoxBackground() {
        let view = HStack { HStack { Text("Hello World") }.background(.blue) }.background(.red)
        #expect(render(view) == bg("44", "Hello World"))
    }

    @Test func nestedTextInheritsNearestTextBackground() {
        let view = HStack { (Text("Hello ") + Text("World")).background(.blue) }.background(.red)
        #expect(render(view) == bg("44", "Hello World"))
    }

    @Test func noBackgroundWithoutParent() {
        #expect(render(HStack { Text("Hello World") }) == "Hello World")
    }

    @Test func multipleTextsShareBackground() {
        let view = HStack {
            Text("Hello ")
            Text("World")
        }.background(.yellow)
        #expect(render(view) == bg("43", "Hello World"))
    }

    @Test(.disabled("Text.background(nil) means inherit; Ink's backgroundColor=\"\" clears the inherited background"))
    func explicitlyNoBackground() {}

    @Test func complexNestedStructure() {
        let view = HStack {
            HStack {
                Text("Outer: ")
                HStack {
                    Text("Inner: ")
                    Text("Explicit").background(.red)
                }
                .background(.blue)
            }
        }
        .background(.yellow)
        #expect(render(view) == "\(esc)[43mOuter: \(esc)[44mInner: \(esc)[41mExplicit\(esc)[49m")
    }

    @Test func backgroundColorFormats() {
        #expect(render(Text("Hello").background(Color(hex: "#FF0000"))) == bg("48;2;255;0;0", "Hello"))
        #expect(render(Text("Hello").background(.palette(9))) == bg("48;5;9", "Hello"))
        #expect(render(Text("Hello").background(Color(red: 255, green: 0, blue: 0))) == bg("48;2;255;0;0", "Hello"))
    }

    @Test func wideCharactersAndEmoji() {
        #expect(render(HStack { Text("こんにちは") }.background(.yellow)) == bg("43", "こんにちは"))
        #expect(render(HStack { Text("🎉🎊") }.background(.red)) == bg("41", "🎉🎊"))
    }

    @Test func backgroundFillsTheBox() {
        let view = Text("Hello").frame(width: 10, height: 3, alignment: .topLeading).background(.red)
        let lines = render(view).split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 3)
        #expect(lines[0] == "\(esc)[41mHello     \(esc)[49m")
        #expect(lines[1] == "\(esc)[41m          \(esc)[49m")
        #expect(lines[2] == "\(esc)[41m          \(esc)[49m")
    }

    @Test func backgroundWithBorderFillsContentOnly() {
        let view = Text("Hi").frame(width: 4, alignment: .leading).background(.red).border(.single)
        let lines = render(view).split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines[0] == "┌────┐")
        #expect(lines[1] == "│\(esc)[41mHi  \(esc)[49m│")
    }

    @Test func backgroundWithPaddingFillsPaddedArea() {
        let lines = render(Text("X").padding(1).background(.blue)).split(
            separator: "\n", omittingEmptySubsequences: false)
        #expect(lines == ["\(esc)[44m   \(esc)[49m", "\(esc)[44m X \(esc)[49m", "\(esc)[44m   \(esc)[49m"])
    }

    @Test func backgroundWithCenterAlignment() {
        let view = Text("Hi").frame(width: 6, height: 3, alignment: .center).background(.green)
        let lines = render(view).split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines == ["\(esc)[42m      \(esc)[49m", "\(esc)[42m  Hi  \(esc)[49m", "\(esc)[42m      \(esc)[49m"])
    }

    @Test func backgroundWithColumnLayout() {
        let view = VStack {
            Text("A")
            Text("B")
        }.frame(width: 3, alignment: .topLeading).background(.cyan)
        let lines = render(view).split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines == ["\(esc)[46mA  \(esc)[49m", "\(esc)[46mB  \(esc)[49m"])
    }

    @Test func backgroundFillsEveryWrappedLine() {
        let view = Text("Hello World").frame(width: 8, alignment: .leading).background(.blue)
        let lines = render(view).split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 2)
        for line in lines {
            #expect(line.hasPrefix("\(esc)[44m") && line.hasSuffix("\(esc)[49m"))
            #expect(ANSIText.parse(String(line)).map(\.text).joined().count == 8)
        }
    }

    @Test func textOnlyBackgroundDoesNotFillWidth() {
        #expect(render(Text("Hi").background(.red)) == bg("41", "Hi"))
    }
}
