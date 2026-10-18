// A counter: state, key handling and exiting.
// Run with `swift run counter`.
import Stipple

struct Counter: View {
    @State private var count = 0
    @Environment(\.exit) private var exit

    var body: some View {
        VStack(alignment: .leading) {
            Text("Count: \(count)").foregroundStyle(.green).bold()
            Text("↑/↓ change, q quit").dim()
        }
        .padding(.horizontal, 1)
        .border(.rounded, color: .cyan)
        .onKeyPress(.upArrow) {
            count += 1
            return .handled
        }
        .onKeyPress(.downArrow) {
            count -= 1
            return .handled
        }
        .onKeyPress("q") {
            exit()
            return .handled
        }
    }
}

try await Stipple.run(Counter())
