import Testing

@testable import Stipple

@MainActor
@Suite struct ProgressViewTests {
    private func plain(_ view: some View, width: Int = 20) -> String {
        Stipple.renderToString(view, width: width).replacing(/\u{1B}\[[0-9;]*m/, with: "")
    }

    @Test func spinnerShowsItsFirstDotFrame() {
        #expect(plain(ProgressView()) == "⠋")
    }

    @Test func spinnerWithLabelFollowsTheFrame() {
        #expect(plain(ProgressView("Loading")) == "⠋ Loading")
    }

    // A bar measures the width it is offered in a geometry pass, which only the
    // runtime repeats; these run on the fake terminal, 40 columns wide.

    @Test func barFillsHalfOfTheOfferedWidth() {
        #expect(barLine(ProgressView(value: 0.5)) == "████████████████████" + "░░░░░░░░░░░░░░░░░░░░")
    }

    @Test func barRoundsToTheNearestCell() {
        // 0.25 of 40 cells is 10.
        #expect(barLine(ProgressView(value: 1, total: 4)).hasPrefix(String(repeating: "█", count: 10) + "░"))
    }

    @Test func barIsClampedToTheRange() {
        #expect(barLine(ProgressView(value: 2)) == String(repeating: "█", count: 40))
        #expect(barLine(ProgressView(value: -1)) == String(repeating: "░", count: 40))
    }

    @Test func barIsEmptyWhenTotalIsNotPositive() {
        #expect(barLine(ProgressView(value: 3, total: 0)) == String(repeating: "░", count: 40))
    }

    @Test func labelledBarTakesTheWidthAfterTheLabel() {
        // The label is 7 cells and a space follows it, so the bar gets 32 cells; 0.5 fills 16.
        let expected = "Copying " + String(repeating: "█", count: 16) + String(repeating: "░", count: 16)
        #expect(barLine(ProgressView("Copying", value: 0.5)) == expected)
    }

    @Test func presetsSetTheFirstFrame() {
        #expect(plain(ProgressView().progressViewStyle(.line)) == "-")
        #expect(plain(ProgressView().progressViewStyle(.arc)) == "◜")
        #expect(plain(ProgressView().progressViewStyle(.dots)) == "⠋")
    }

    @Test func customStyleUsesItsFrames() {
        let style = ProgressViewStyle(frames: ["a", "b"], interval: .milliseconds(10))
        #expect(plain(ProgressView().progressViewStyle(style)) == "a")
        #expect(ProgressViewStyle.line.frames.count == 4)
        #expect(ProgressViewStyle.arc.interval == .milliseconds(100))
    }

    @Test func barTextHandlesZeroWidth() {
        #expect(ProgressView.barText(fraction: 1, width: 0).isEmpty)
        #expect(ProgressView.barText(fraction: 0.5, width: 4) == "██░░")
    }

    @Test func fractionIsClampedAndSafeForZeroTotal() {
        #expect(ProgressView.fraction(value: 1, total: 4) == 0.25)
        #expect(ProgressView.fraction(value: 9, total: 4) == 1)
        #expect(ProgressView.fraction(value: 1, total: 0) == 0)
    }

    /// The first line the runtime draws for `view`, styling removed.
    private func barLine(_ view: some View) -> String {
        let (_, terminal) = makeRuntime(view)
        return terminal.lastFrame.split(separator: "\n").first.map(String.init) ?? ""
    }

    @Test func spinnerAdvancesWhileOnScreen() async throws {
        let style = ProgressViewStyle(frames: ["a", "b"], interval: .milliseconds(20))
        let (runtime, terminal) = makeRuntime(ProgressView().progressViewStyle(style))
        #expect(terminal.output.contains("a"))
        await runtime.waitUntil { terminal.output.contains("b") }
        #expect(terminal.output.contains("b"))
    }
}
