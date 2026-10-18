import Testing

@testable import Stipple

/// Ports of Ink's `render-to-string.tsx`, `width-height.tsx` and `position.tsx`.
@MainActor
struct LayoutParityTests {
    private func plainDefault(_ view: some View) -> String {
        ANSIText.parse(Stipple.renderToString(view)).map(\.text).joined()
    }

    // MARK: render-to-string

    @Test func defaultWidthIs80() {
        let lines = plainDefault(Text(String(repeating: "A", count: 100))).split(separator: "\n")
        #expect(lines.map(String.init) == [String(repeating: "A", count: 80), String(repeating: "A", count: 20)])
    }

    @Test func customWidth() {
        let output = ANSIText.parse(Stipple.renderToString(Text(String(repeating: "A", count: 50)), width: 30))
        #expect(
            output.map(\.text).joined() == String(repeating: "A", count: 30) + "\n" + String(repeating: "A", count: 20))
    }

    @Test func emptyViews() {
        #expect(plain(EmptyView()).isEmpty)
        #expect(plain(Group {}).isEmpty)
    }

    @Test func paddedAndMargined() {
        #expect(plain(Text("Padded").padding(.leading, 2)) == "  Padded")
    }

    @Test func fixedWidthAndHeightBox() {
        let lines = plain(Text("Hi").frame(width: 10, height: 3, alignment: .topLeading)).split(
            separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 3)
    }

    @Test func newlineInsertsBlankLine() {
        let view = VStack(alignment: .leading) {
            Text("Above")
            Text("\n")
            Text("Below")
        }
        #expect(plain(view) == "Above\n\n\nBelow")
    }

    @Test func borderWithFixedWidth() {
        let view = Text("Bordered").frame(width: 18, alignment: .leading).border(.single)
        #expect(plain(view, width: 20) == "┌──────────────────┐\n│Bordered          │\n└──────────────────┘")
    }

    @Test func boldText() {
        #expect(render(Text("Bold").bold()) == "\(esc)[1mBold\(esc)[22m")
    }

    @Test(
        .disabled(
            "Static takes no style (margins/padding) in Stipple; Ink: Static(style: {marginTop: 1, marginBottom: 1, marginLeft: 2}) gives '\\n  A\\n  B\\n'"
        ))
    func staticKeepsItsMargins() {}

    @Test func staticAndDynamicAreSeparatedByOneNewline() {
        let view = VStack(alignment: .leading) {
            Static(["A", "B", "C"]) { Text($0) }
            Text("Dynamic")
        }
        #expect(plain(view) == "A\nB\nC\nDynamic")
    }

    @Test func staticInsideAHiddenAncestorIsSkipped() {
        let view = VStack(alignment: .leading) {
            if false { Static(["Hidden"]) { Text($0).border() } }
            Text("Visible")
        }
        #expect(plain(view) == "Visible")
    }

    // MARK: width and height

    @Test func setWidth() {
        #expect(
            plain(
                HStack {
                    Text("A").frame(width: 5, alignment: .leading)
                    Text("B")
                }) == "A    B")
    }

    @Test func setMinWidth() {
        #expect(
            plain(
                HStack {
                    Text("A").frame(minWidth: 5, alignment: .leading)
                    Text("B")
                }) == "A    B")
        #expect(
            plain(
                HStack {
                    Text("AAAAA").frame(minWidth: 2, alignment: .leading)
                    Text("B")
                }) == "AAAAAB")
    }

    @Test func widthZeroOverflows() {
        // The zero-width box still draws its text, which the next sibling overwrites.
        let view = HStack {
            Text("hello").frame(width: 0, alignment: .leading)
            Text("|")
        }
        #expect(plain(view) == "|ello")
    }

    @Test func widthZeroWithTextBelow() {
        let view = VStack(alignment: .leading) {
            HStack {
                Text("hello").frame(width: 0, alignment: .leading)
                Text("|")
            }
            Text("next")
        }
        #expect(plain(view) == "|ello\nnext")
    }

    @Test func paddingLeavesNoRoomForText() {
        let view = HStack {
            Text("hello").padding(.horizontal, 1).frame(width: 2, alignment: .leading)
            Text("|")
        }
        #expect(plain(view) == " h|llo")
    }

    @Test func setMaxWidth() {
        let constrained = HStack {
            Text("AAAAA").frame(maxWidth: 3, alignment: .leading)
            Text("B")
        }
        #expect(plain(constrained, width: 10) == "AAAB\nAA")
    }

    @Test func setHeight() {
        #expect(
            plain(
                HStack {
                    Text("A")
                    Text("B")
                }.frame(height: 4, alignment: .topLeading)) == "AB\n\n\n")
    }

    @Test func cutTextOverTheSetHeight() {
        #expect(plain(Text("AAAABBBBCCCC").frame(height: 2, alignment: .topLeading), width: 4) == "AAAA\nBBBB")
    }

    @Test func setMinHeight() {
        #expect(plain(Text("A").frame(minHeight: 4, alignment: .topLeading)) == "A\n\n\n")
        #expect(
            plain(Text("A").frame(height: 4, alignment: .topLeading).frame(minHeight: 2, alignment: .topLeading))
                == "A\n\n\n")
    }

    @Test func setMaxHeight() {
        let constrained = Text("A").frame(height: 4, alignment: .topLeading).frame(maxHeight: 2, alignment: .topLeading)
        #expect(plain(constrained) == "A\n")
        #expect(plain(Text("A").frame(maxHeight: 4, alignment: .topLeading)) == "A")
    }

    @Test(.disabled("No percentage sizes: Ink width=\"50%\" / height=\"50%\" (use GeometryReader or Spacer ratios)"))
    func percentSizes() {}

    @Test(.disabled("No aspect ratio modifier (aspectRatio is not implemented); Ink: aspectRatio on Box"))
    func aspectRatio() {}

    // MARK: position

    private func overlay(
        @ViewBuilder _ content: () -> some View, alignment: Alignment = .topLeading, size: Size
    ) -> some View {
        ZStack(alignment: alignment) { content() }.frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    @Test func absoluteTopLeft() {
        let view = overlay({ Text("X").offset(x: 2, y: 1) }, size: Size(width: 5, height: 3))
        #expect(plain(view) == "\n  X\n")
    }

    @Test func absoluteBottomRight() {
        let view = Text("X")
            .padding(.bottom, 1)
            .padding(.trailing, 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .frame(width: 6, height: 4, alignment: .topLeading)
        #expect(plain(view) == "\n\n    X\n")
    }

    @Test func linesAboveTheOutputAreCut() {
        let view = overlay({ Text("Hidden\nFirst\nSecond").offset(y: -1) }, size: Size(width: 6, height: 2))
        #expect(plain(view) == "First\nSecond")
    }

    @Test func relativeOffsetKeepsFlow() {
        let view = HStack {
            Text("A").offset(x: 2)
            Text("B")
        }.frame(width: 5, alignment: .topLeading)
        #expect(plain(view) == " BA")
    }

    @Test(.disabled("No percentage offsets for absolutely positioned views"))
    func percentOffsets() {}
}
