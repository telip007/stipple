// Finished tasks scroll into the terminal's history with `Static` while a
// spinner and a progress bar show the running one. Run with `swift run tasks`.
import Stipple

struct Tasks: View {
    @State private var finished: [String] = []
    @State private var current = 1
    @Environment(\.exit) private var exit
    private let total = 8

    var body: some View {
        VStack(alignment: .leading) {
            Static(finished) { name in
                Text("✔ ").foregroundStyle(.green) + Text(name)
            }
            if current <= total {
                ProgressView("Task \(current) of \(total)").foregroundStyle(.yellow)
                ProgressView(value: Double(current - 1), total: Double(total))
                    .frame(maxWidth: 40)
                    .foregroundStyle(.green)
            }
        }
        .task {
            while current <= total {
                try? await Task.sleep(for: .milliseconds(400))
                finished.append("Task \(current)")
                current += 1
            }
            exit()
        }
    }
}

try await Stipple.run(Tasks())
