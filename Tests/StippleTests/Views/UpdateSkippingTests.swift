import Observation
import Testing

@testable import Stipple

/// Counts body evaluations, to see which views a change rebuilds.
@MainActor
final class BodyCounter {
    var counts: [String: Int] = [:]

    func hit(_ name: String) {
        counts[name, default: 0] += 1
    }
}

@Observable
@MainActor
private final class Rows {
    var titles = ["a", "b", "c"]
}

private struct Row: View, Equatable {
    let title: String
    let counter: Counted

    var body: some View {
        counter.counter.hit(title)
        return Text(title).foregroundStyle(.green).padding(.leading, 1)
    }
}

/// A non-equatable counter wrapper that compares by identity, so `Row` can be
/// `Equatable` while holding it.
private struct Counted: Equatable {
    let counter: BodyCounter

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.counter === rhs.counter }
}

private struct List: View {
    let rows: Rows
    let counter: Counted

    var body: some View {
        VStack {
            ForEach(Array(rows.titles.enumerated()), id: \.offset) { _, title in
                Row(title: title, counter: counter).bold()
            }
        }
        .lineLimit(2)
    }
}

@Observable
@MainActor
private final class Lines {
    var first = "one"
    var offset = 0
}

/// Two texts, the first one observed, so a change rebuilds only it.
private struct Column: View {
    let lines: Lines

    var body: some View {
        VStack(alignment: .leading) {
            First(lines: lines)
            Text("last").padding(.leading, 1)
        }
        .offset(x: 0, y: lines.offset)
    }
}

private struct First: View {
    let lines: Lines

    var body: some View {
        Text(lines.first)
    }
}

@MainActor
struct UpdateSkippingTests {
    /// Lays out and draws `graph` like a frame of the runtime, unstyled.
    private func frame(_ graph: ViewGraph, width: Int = 10, height: Int? = nil) -> String {
        graph.flush()
        let frame = FrameRenderer(graph: graph).render(width: width, height: height).frame
        return frame.replacing(/\u{1B}\[[0-9;]*m/, with: "")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0.reversed().drop(while: \.isWhitespace).reversed()) }
            .joined(separator: "\n")
    }

    @Test func keptSizesAndPlacementsFollowAChangeDeepInside() {
        let lines = Lines()
        let graph = ViewGraph()
        graph.mount(Column(lines: lines), environment: EnvironmentValues())
        #expect(frame(graph) == "one\n last")
        // An unchanged frame comes from the kept sizes and placements.
        #expect(frame(graph) == "one\n last")

        // The first text wraps onto two rows: the sibling below moves down.
        lines.first = "one two three"
        graph.drainInvalidations()
        #expect(frame(graph) == "one two\nthree\n last")

        lines.first = "one"
        graph.drainInvalidations()
        #expect(frame(graph) == "one\n last")
    }

    @Test func aMovedSubtreeKeepsItsShape() {
        let lines = Lines()
        let graph = ViewGraph()
        graph.mount(VStack { Column(lines: lines) }.frame(height: 4, alignment: .top), environment: EnvironmentValues())
        #expect(frame(graph) == "one\n last\n\n")
        lines.offset = 2
        graph.drainInvalidations()
        #expect(frame(graph) == "\n\none\n last")
    }

    @Test func aNewWidthLaysTextOutAgain() {
        let graph = ViewGraph()
        graph.mount(Text("one two three"), environment: EnvironmentValues())
        #expect(frame(graph, width: 20) == "one two three")
        #expect(frame(graph, width: 8) == "one two\nthree")
        #expect(frame(graph, width: 20) == "one two three")
    }

    @Test func bindingsToTheSameStateAreTheSame() {
        let state = State(wrappedValue: 1)
        let graph = ViewGraph()
        let node = ViewNode(graph: graph, parent: nil, view: EmptyView(), environment: EnvironmentValues())
        state.install(in: node, index: 0)
        #expect(state.projectedValue.hasSameSource(as: state.projectedValue))
        #expect(!state.projectedValue.hasSameSource(as: State(wrappedValue: 1).projectedValue))
        let plain = Binding(get: { 1 }, set: { _ in })
        #expect(!plain.hasSameSource(as: plain))
    }

    @Test func anEqualViewKeepsItsSubtree() async {
        let rows = Rows()
        let counter = BodyCounter()
        let (runtime, terminal) = makeRuntime(List(rows: rows, counter: Counted(counter: counter)))
        #expect(counter.counts == ["a": 1, "b": 1, "c": 1])

        rows.titles[1] = "B"
        await runtime.settle()
        // Only the row whose value changed is rebuilt.
        #expect(counter.counts == ["a": 1, "b": 1, "B": 1, "c": 1])
        #expect(terminal.output.contains("B"))
    }

    @Test func onSubmitKeepsTheEnvironmentAcrossRebuilds() {
        let graph = ViewGraph()
        let counter = BodyCounter()
        let row = Row(title: "a", counter: Counted(counter: counter))
        let environment = EnvironmentValues()
        // A new closure each time, as a parent's body makes one each rebuild.
        graph.mount(row.onSubmit {}, environment: environment)
        graph.update(row.onSubmit {}, environment: environment)
        #expect(counter.counts["a"] == 1)
    }

    @Test func aResizeRebuildsOnlyTheViewsThatReadTheSize() async {
        struct Sized: View {
            @Environment(\.terminalSize) private var size
            let counter: Counted
            var body: some View {
                counter.counter.hit("sized")
                return VStack {
                    Text("w\(size.width)")
                    Row(title: "row", counter: counter)
                }
            }
        }
        let counter = BodyCounter()
        let (runtime, terminal) = makeRuntime(Sized(counter: Counted(counter: counter)))
        terminal.size = Size(width: 30, height: 5)
        runtime.handle(.resize(terminal.size))
        await runtime.settle()
        #expect(terminal.output.contains("w30"))
        // The view that reads the size rebuilt; the equal row inside didn't.
        #expect(counter.counts == ["sized": 2, "row": 1])
    }

    @Test func aChangedEnvironmentRebuilds() {
        let graph = ViewGraph()
        let counter = BodyCounter()
        let row = Row(title: "a", counter: Counted(counter: counter))
        let environment = EnvironmentValues()
        graph.mount(row.environment(\.lineLimit, 1), environment: environment)
        graph.update(row.environment(\.lineLimit, 1), environment: environment)
        #expect(counter.counts["a"] == 1)
        graph.update(row.environment(\.lineLimit, 2), environment: environment)
        #expect(counter.counts["a"] == 2)
    }

    @Test func settingAnEqualValueKeepsTheEnvironmentsIdentity() {
        var base = EnvironmentValues()
        base.lineLimit = 3
        var first = base
        var second = base
        first.truncationMode = .head
        second.truncationMode = .head
        #expect(first.isIdentical(to: second))
        second.truncationMode = .tail
        #expect(!first.isIdentical(to: second))
        var same = base
        same.lineLimit = 3
        #expect(same.isIdentical(to: base))
    }
}
