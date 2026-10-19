// A build that runs three jobs at a time: each running job has its own
// spinner and progress bar, finished jobs scroll into the terminal's history
// with `Static`, and an overall bar tracks the whole run. Run with
// `swift run tasks`.
import Stipple

struct Job: Identifiable {
    let id: Int
    let name: String
    /// How much of the job one 50 ms tick completes.
    let speed: Double
    var progress = 0.0
    var ticks = 0

    var spinner: ProgressViewStyle {
        switch id % 3 {
        case 0: .dots
        case 1: .line
        default: .arc
        }
    }
}

struct Tasks: View {
    @State private var queued = [
        Job(id: 0, name: "Resolve packages", speed: 0.09),
        Job(id: 1, name: "Fetch swift-collections", speed: 0.05),
        Job(id: 2, name: "Fetch swift-algorithms", speed: 0.07),
        Job(id: 3, name: "Compile Stipple", speed: 0.025),
        Job(id: 4, name: "Compile examples", speed: 0.045),
        Job(id: 5, name: "Generate docs", speed: 0.06),
        Job(id: 6, name: "Link", speed: 0.08),
        Job(id: 7, name: "Run 1,480 tests", speed: 0.035),
    ]
    @State private var running: [Job] = []
    @State private var finished: [Job] = []
    @Environment(\.exit) private var exit
    private let total = 8
    private let parallel = 3

    var body: some View {
        VStack(alignment: .leading) {
            Static(finished) { job in
                Text("✔ ").foregroundStyle(.green) + Text(job.name) + Text("  \(job.ticks * 50) ms").dim()
            }
            ForEach(running) { job in
                HStack(spacing: 1) {
                    ProgressView().progressViewStyle(job.spinner).foregroundStyle(.yellow)
                    Text(job.name).frame(width: 24, alignment: .leading)
                    ProgressView(value: job.progress).frame(width: 24).foregroundStyle(.cyan)
                    Text("\(Int(job.progress * 100))%").dim()
                }
            }
            if !running.isEmpty {
                HStack(spacing: 1) {
                    Text("Overall").bold()
                    ProgressView(value: Double(finished.count), total: Double(total))
                        .frame(width: 30)
                        .foregroundStyle(.green)
                    Text("\(finished.count)/\(total)")
                }
                .padding(.top, 1)
            }
        }
        .task {
            while finished.count < total {
                while running.count < parallel, !queued.isEmpty {
                    running.append(queued.removeFirst())
                }
                try? await Task.sleep(for: .milliseconds(50))
                for index in running.indices {
                    running[index].progress = min(1, running[index].progress + running[index].speed)
                    running[index].ticks += 1
                }
                finished += running.filter { $0.progress >= 1 }
                running.removeAll { $0.progress >= 1 }
            }
            exit()
        }
    }
}

try await Stipple.run(Tasks())
