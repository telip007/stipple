import Testing

@testable import Stipple

/// Ports of Ink's `padding.tsx`, `margin.tsx`, `gap.tsx` and `display.tsx`.
/// A margin is padding outside a border or background, so both map to `.padding`.
@MainActor
struct BoxModelParityTests {
    @Test func padding() {
        #expect(plain(Text("X").padding(2)) == "\n\n  X\n\n")
    }

    @Test func paddingX() {
        #expect(
            plain(
                HStack {
                    Text("X").padding(.horizontal, 2)
                    Text("Y")
                }) == "  X  Y")
    }

    @Test func paddingY() {
        #expect(plain(Text("X").padding(.vertical, 2)) == "\n\nX\n\n")
    }

    @Test func paddingTop() {
        #expect(plain(Text("X").padding(.top, 2)) == "\n\nX")
    }

    @Test func paddingBottom() {
        #expect(plain(Text("X").padding(.bottom, 2)) == "X\n\n")
    }

    @Test func paddingLeft() {
        #expect(plain(Text("X").padding(.leading, 2)) == "  X")
    }

    @Test func paddingRight() {
        #expect(
            plain(
                HStack {
                    Text("X").padding(.trailing, 2)
                    Text("Y")
                }) == "X  Y")
    }

    @Test func nestedPadding() {
        #expect(plain(Text("X").padding(2).padding(2)) == "\n\n\n\n    X\n\n\n\n")
    }

    @Test func paddingWithMultilineString() {
        #expect(plain(Text("A\nB").padding(2)) == "\n\n  A\n  B\n\n")
    }

    @Test func paddingWithNewlines() {
        #expect(plain(Text("Hello\nWorld").padding(1)) == "\n Hello\n World\n")
    }

    @Test func paddingWithWrappedText() {
        // `Box padding={1} width={5}` leaves 3 columns for "Hello World".
        let view = Text("Hello World").padding(1).frame(width: 5, alignment: .topLeading)
        #expect(plain(view) == "\n Hel\n lo\n Wor\n ld\n")
    }

    @Test func textWrappingRespectsPaddingXWithFlexGrow() {
        let view = HStack {
            HStack {
                Text("•")
                Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit")
                    .padding(.leading, 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 2)
            .padding(.horizontal, 2)
        }
        .border(.rounded)
        .frame(width: 40, alignment: .topLeading)
        for line in plain(view).split(separator: "\n") {
            #expect(TextMetrics.width(of: line) <= 40, "\(line)")
        }
    }

    // MARK: gap

    @Test func rowGap() {
        #expect(
            plain(
                HStack(spacing: 1) {
                    Text("A")
                    Text("B")
                }) == "A B")
    }

    @Test func columnGap() {
        #expect(
            plain(
                VStack(spacing: 1) {
                    Text("A")
                    Text("B")
                }) == "A\n\nB")
    }

    @Test(.disabled("No flex-wrap equivalent: a SwiftUI HStack never wraps; Ink gives 'A B\\n\\nC'"))
    func wrappingGap() {}

    // MARK: display

    @Test func displayNone() {
        let view = VStack {
            if false { Text("Kitty!") }
            Text("Doggo")
        }
        #expect(plain(view) == "Doggo")
    }

    @Test func conditionalSiblingRestoresLayout() {
        struct Example: View {
            var show: Bool
            var body: some View {
                HStack {
                    if show { Text("Cat") }
                    Text("Dog")
                }
            }
        }
        #expect(plain(Example(show: false)) == "Dog")
        #expect(plain(Example(show: true)) == "CatDog")
    }
}
