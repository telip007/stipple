import Testing

@testable import Stipple

struct MouseInputTests {
    private func mouse(_ text: String) -> [MouseEvent] {
        decode(text).compactMap { event in
            if case .mouse(let mouse) = event { return mouse }
            return nil
        }
    }

    @Test func sgrWheel() {
        #expect(
            mouse("\u{1B}[<64;10;5M") == [MouseEvent(kind: .scroll(.up), location: Point(x: 9, y: 4), modifiers: [])])
        #expect(mouse("\u{1B}[<65;1;1M").first?.kind == .scroll(.down))
        #expect(mouse("\u{1B}[<66;1;1M").first?.kind == .scroll(.left))
        #expect(mouse("\u{1B}[<67;1;1M").first?.kind == .scroll(.right))
    }

    @Test func sgrButtons() {
        #expect(
            mouse("\u{1B}[<0;3;2M").first == MouseEvent(kind: .press(.left), location: Point(x: 2, y: 1), modifiers: [])
        )
        #expect(mouse("\u{1B}[<0;3;2m").first?.kind == .release(.left))
        #expect(mouse("\u{1B}[<1;1;1M").first?.kind == .press(.middle))
        #expect(mouse("\u{1B}[<2;1;1m").first?.kind == .release(.right))
        #expect(mouse("\u{1B}[<35;1;1M").first?.kind == .move)
    }

    @Test func sgrModifiers() {
        #expect(mouse("\u{1B}[<4;1;1M").first?.modifiers == .shift)
        #expect(mouse("\u{1B}[<8;1;1M").first?.modifiers == .option)
        #expect(mouse("\u{1B}[<80;1;1M").first == MouseEvent(kind: .scroll(.up), location: .zero, modifiers: .control))
    }

    @Test func malformedReportsAreDropped() {
        #expect(decode("\u{1B}[<64;1M").isEmpty)
        #expect(decode("\u{1B}[<6:4;1;1M").isEmpty)
        #expect(decode("\u{1B}[<64;0;1M").isEmpty)
        #expect(decode("\u{1B}[<128;1;1M").isEmpty)
    }

    @Test func reportsSplitAcrossChunks() {
        var parser = InputParser()
        #expect(parser.parse(Array("\u{1B}[<64;1".utf8)).isEmpty)
        let events = parser.parse(Array("2;3M".utf8))
        #expect(events == [.mouse(MouseEvent(kind: .scroll(.up), location: Point(x: 11, y: 2), modifiers: []))])
    }

    @Test func reportsBetweenKeys() {
        let events = decode("a\u{1B}[<65;1;1Mb")
        #expect(events.count == 3)
        #expect(keyPresses(events).map(\.characters) == ["a", "b"])
    }

    @Test func x10Reports() {
        // Button byte 32 + 0, column and row 33 (cell 0, 0).
        #expect(
            decode(bytes: [0x1B, 0x5B, 0x4D, 32, 33, 33])
                == [.mouse(MouseEvent(kind: .press(.left), location: .zero, modifiers: []))])
        #expect(
            decode(bytes: [0x1B, 0x5B, 0x4D, 35, 40, 34]).first
                == .mouse(
                    MouseEvent(kind: .release(nil), location: Point(x: 7, y: 1), modifiers: [])))
        #expect(
            decode(bytes: [0x1B, 0x5B, 0x4D, 96, 33, 33]).first
                == .mouse(
                    MouseEvent(kind: .scroll(.up), location: .zero, modifiers: [])))
        var parser = InputParser()
        #expect(parser.parse([0x1B, 0x5B, 0x4D, 32]).isEmpty)
        #expect(parser.parse([33, 33]).count == 1)
        #expect(MouseReports.x10Events([1]).isEmpty)
    }
}
