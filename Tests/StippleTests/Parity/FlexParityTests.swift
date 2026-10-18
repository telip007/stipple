import Testing

@testable import Stipple

/// Ports of Ink's `flex-direction.tsx`, `flex-justify-content.tsx` and `flex-align-items.tsx`
/// where SwiftUI has an equivalent.
@MainActor
struct FlexParityTests {
    @Test func directionRow() {
        #expect(
            plain(
                HStack {
                    Text("A")
                    Text("B")
                }) == "AB")
    }

    @Test func directionColumn() {
        #expect(
            plain(
                VStack {
                    Text("A")
                    Text("B")
                }) == "A\nB")
    }

    @Test func rowReverse() {
        // `flexDirection="row-reverse" width={4}`: B A right-aligned.
        let view = HStack {
            Spacer()
            Text("B")
            Text("A")
        }.frame(width: 4, alignment: .topLeading)
        #expect(plain(view) == "  BA")
    }

    @Test func columnReverse() {
        let view = VStack {
            Spacer()
            Text("B")
            Text("A")
        }.frame(height: 4, alignment: .topLeading)
        #expect(plain(view) == "\n\nB\nA")
    }

    // MARK: justifyContent

    @Test func rowCenter() {
        let view = HStack {
            Spacer()
            Text("Test")
            Spacer()
        }.frame(width: 10, alignment: .topLeading)
        #expect(plain(view) == "   Test")
        #expect(plain(Text("Test").frame(width: 10, alignment: .top)) == "   Test")
    }

    @Test func rowCenterMultipleNodes() {
        let view = HStack {
            Spacer()
            Text("A")
            Text("B")
            Spacer()
        }.frame(width: 10, alignment: .topLeading)
        #expect(plain(view) == "    AB")
    }

    @Test func rowFlexEnd() {
        let view = HStack {
            Spacer()
            Text("Test")
        }.frame(width: 10, alignment: .topLeading)
        #expect(plain(view) == "      Test")
        let two = HStack {
            Spacer()
            Text("A")
            Text("B")
        }.frame(width: 10, alignment: .topLeading)
        #expect(plain(two) == "        AB")
    }

    @Test func rowSpaceBetween() {
        let view = HStack {
            Text("A")
            Spacer()
            Text("B")
        }.frame(width: 4, alignment: .topLeading)
        #expect(plain(view) == "A  B")
    }

    @Test func rowFlexEndKeepsColor() {
        let view = HStack {
            Spacer()
            Text("X").foregroundStyle(.green)
        }.frame(width: 5, alignment: .topLeading)
        #expect(render(view) == "    \(esc)[32mX\(esc)[39m")
    }

    @Test func columnCenter() {
        let view = VStack {
            Spacer()
            Text("Test")
            Spacer()
        }.frame(height: 3, alignment: .topLeading)
        #expect(plain(view) == "\nTest\n")
    }

    @Test func columnFlexEnd() {
        let view = VStack {
            Spacer()
            Text("Test")
        }.frame(height: 3, alignment: .topLeading)
        #expect(plain(view) == "\n\nTest")
    }

    @Test func columnSpaceBetween() {
        let view = VStack {
            Text("A")
            Spacer()
            Text("B")
        }.frame(height: 4, alignment: .topLeading)
        #expect(plain(view) == "A\n\n\nB")
    }

    // MARK: alignItems

    @Test func rowAlignCenter() {
        let view = HStack(alignment: .center) { Text("Test") }.frame(height: 3, alignment: .leading)
        #expect(plain(view) == "\nTest\n")
    }

    @Test func rowAlignBottom() {
        let view = HStack {
            Text("A")
            Text("B")
        }.frame(height: 3, alignment: .bottomLeading)
        #expect(plain(view) == "\n\nAB")
    }

    @Test func columnAlignCenterAndEnd() {
        let center = VStack(alignment: .center) { Text("Test") }.frame(width: 10, alignment: .topLeading)
        #expect(plain(center) == "Test")
        #expect(plain(Text("Test").frame(width: 10, alignment: .top)) == "   Test")
        #expect(plain(Text("Test").frame(width: 10, alignment: .topTrailing)) == "      Test")
    }

    // MARK: flex.tsx / flex-align-self.tsx

    @Test func growEqually() {
        let view = HStack(spacing: 0) {
            Text("A").frame(maxWidth: .infinity, alignment: .leading)
            Text("B").frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 6, alignment: .topLeading)
        #expect(plain(view) == "A  B")
    }

    @Test func growOneElement() {
        let view = HStack(spacing: 0) {
            Text("A").frame(maxWidth: .infinity, alignment: .leading)
            Text("B")
        }
        .frame(width: 6, alignment: .topLeading)
        #expect(plain(view) == "A    B")
    }

    @Test(.disabled("Fixed frames never shrink in a SwiftUI stack; Ink's flexShrink/flexBasis have no counterpart"))
    func shrinkAndBasis() {}

    @Test func alignSelfCenterAndEndInAColumn() {
        let center = VStack(alignment: .center) { Text("Test") }.frame(width: 10, alignment: .topLeading)
        #expect(plain(center) == "Test")
        #expect(plain(Text("Test").frame(width: 10, alignment: .top)) == "   Test")
        #expect(plain(Text("Test").frame(width: 10, alignment: .topTrailing)) == "      Test")
    }

    @Test func alignSelfStretchInAColumn() {
        let view = Text("X").frame(maxWidth: .infinity, alignment: .leading).border().frame(
            width: 7, alignment: .topLeading)
        #expect(plain(view) == "┌─────┐\n│X    │\n└─────┘")
    }

    @Test func alignSelfStretchInARow() {
        let view = Text("X").frame(maxHeight: .infinity, alignment: .topLeading).border().frame(
            height: 5, alignment: .topLeading)
        #expect(plain(view) == "┌─┐\n│X│\n│ │\n│ │\n└─┘")
    }

    @Test(.disabled("No baseline alignment (alignSelf=\"baseline\"); HStack has no .firstTextBaseline"))
    func alignSelfBaseline() {}

    @Test(.disabled("No flex-wrap equivalent; Ink flexWrap/alignContent tests have no SwiftUI counterpart"))
    func wrapAndAlignContent() {}
}
