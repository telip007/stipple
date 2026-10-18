import Observation
import Testing

@testable import Stipple

@Observable
@MainActor
final class Model {
    var value = "start"
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = "light"
}

extension EnvironmentValues {
    fileprivate var theme: String {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

@MainActor
struct StateAndEnvironmentTests {
    private func plain(_ view: some View, width: Int = 20) -> String {
        Stipple.renderToString(view, width: width).replacing(/\u{1B}\[[0-9;]*m/, with: "")
    }

    @Test func customEnvironmentKey() {
        struct Themed: View {
            @Environment(\.theme) private var theme
            var body: some View { Text(theme) }
        }
        #expect(plain(Themed()) == "light")
        #expect(plain(Themed().environment(\.theme, "dark")) == "dark")
        #expect(Environment(\.theme).wrappedValue == "light")
    }

    @Test func observableModelInEnvironment() async {
        struct Reader: View {
            @Environment(Model.self) private var model
            var body: some View {
                Text(model.value).onKeyPress("x") {
                    model.value = "changed"
                    return .handled
                }
            }
        }
        let model = Model()
        let (runtime, terminal) = makeRuntime(Reader().environment(model))
        #expect(terminal.output.contains("start"))
        runtime.handle(.input(Array("x".utf8)))
        await runtime.settle()
        #expect(terminal.output.contains("changed"))
    }

    @Test func bindingPassesStateDown() async {
        struct Child: View {
            @Binding var count: Int
            var body: some View {
                Text("child \(count)").onKeyPress(.space) {
                    count += 1
                    return .handled
                }
            }
        }
        struct Parent: View {
            @State private var count = 0
            var body: some View { Child(count: $count) }
        }
        let (runtime, terminal) = makeRuntime(Parent())
        runtime.handle(.input(Array(" ".utf8)))
        await runtime.settle()
        #expect(terminal.output.contains("child 1"))
    }

    @Test func bindingHelpers() {
        struct Settings { var name = "a" }
        var storage = Settings()
        let binding = Binding(get: { storage }, set: { storage = $0 })
        binding.name.wrappedValue = "b"
        #expect(storage.name == "b")
        #expect(Binding.constant(3).wrappedValue == 3)
        #expect(Binding(projectedValue: binding).projectedValue.wrappedValue.name == "b")
    }

    @Test func stateOutsideBodyUsesInitialValue() {
        let state = State(initialValue: 5)
        state.wrappedValue = 6
        #expect(state.wrappedValue == 5)
        #expect(state.projectedValue.wrappedValue == 5)
        let optional = State<Int?>()
        #expect(optional.wrappedValue == nil)
    }

    @Test func stateResetsWhenBranchChanges() async {
        struct Inner: View {
            @State private var taps = 0
            var body: some View {
                Text("taps \(taps)").onKeyPress("t") {
                    taps += 1
                    return .handled
                }
            }
        }
        struct Outer: View {
            @State private var flag = true
            var body: some View {
                VStack {
                    if flag { Inner() } else { Inner() }
                }
                .onKeyPress("f") {
                    flag.toggle()
                    return .handled
                }
            }
        }
        let (runtime, terminal) = makeRuntime(Outer())
        runtime.handle(.input(Array("t".utf8)))
        await runtime.settle()
        #expect(terminal.output.contains("taps 1"))
        terminal.output = ""
        runtime.handle(.input(Array("f".utf8)))
        await runtime.settle()
        #expect(terminal.output.contains("taps 0"))
    }
}
