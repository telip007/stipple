import Testing

@testable import Stipple

@Suite struct LineUpdateTests {
    @Test func repaintsFromTheFirstChangedCharacter() {
        #expect(lineUpdate(previous: "abc", next: "abd", columns: 80) == "\u{1B}[3G\u{1B}[Kd")
    }

    @Test func fullRepaintWithoutAKnownWidth() {
        #expect(lineUpdate(previous: "abc", next: "abd", columns: 0) == "\u{1B}[1G\u{1B}[Kabd")
    }

    @Test func fullRepaintWhenNothingIsShared() {
        #expect(lineUpdate(previous: "xyz", next: "abc", columns: 80) == "\u{1B}[1G\u{1B}[Kabc")
    }

    @Test func keepsTheSharedStyledPrefixAndReplaysItsSGR() {
        let previous = "\u{1B}[31mab\u{1B}[0m"
        let next = "\u{1B}[31mac\u{1B}[0m"
        #expect(lineUpdate(previous: previous, next: next, columns: 80) == "\u{1B}[2G\u{1B}[K\u{1B}[31mc\u{1B}[0m")
    }

    @Test func differenceInsideAnSGRSequenceRepaintsWhole() {
        #expect(lineUpdate(previous: "\u{1B}[31ma", next: "\u{1B}[31mb", columns: 80) == "\u{1B}[1G\u{1B}[K\u{1B}[31mb")
    }

    @Test func wideCharactersMoveTheColumnByTheirWidth() {
        #expect(lineUpdate(previous: "日本", next: "日x", columns: 80) == "\u{1B}[3G\u{1B}[Kx")
    }

    @Test func fullRepaintWhenThePrefixReachesTheLastColumn() {
        #expect(lineUpdate(previous: "日本", next: "日x", columns: 2) == "\u{1B}[1G\u{1B}[K日x")
    }

    @Test func fullRepaintWhenTheTailDoesNotFit() {
        #expect(lineUpdate(previous: "aaaa日", next: "aaab日", columns: 5) == "\u{1B}[1G\u{1B}[Kaaab日")
    }

    @Test func fullRepaintForLinesWithControlCharacters() {
        #expect(lineUpdate(previous: "a\tbc", next: "a\tbd", columns: 80) == "\u{1B}[1G\u{1B}[Ka\tbd")
    }
}
