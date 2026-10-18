// Finished tasks scroll into the terminal's history with `Static` while a
// spinner shows the running one. Run with `swift run tasks`.
import Stipple

struct Tasks: View {
    @State private var finished: [String] = []
    @State private var current = 1
    @Environment(\.exit) private var exit
    private let total = 8
    private let spinner = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

    var body: some View {
        VStack(alignment: .leading) {
            Static(finished) { name in
                Text("✔ ").foregroundStyle(.green) + Text(name)
            }
            if current <= total {
                TimelineView(.periodic(every: .milliseconds(80))) { context in
                    Text(spinner[context.frame % spinner.count]).foregroundStyle(.yellow)
                        + Text(" Task \(current) of \(total)")
                }
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
