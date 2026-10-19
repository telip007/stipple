// A full-screen log viewer on the alternate screen: a `SelectionList` of
// services, a `ScrollView` with a `LazyVStack` of thousands of lines that
// follows new ones while it rests at the bottom, and a filter `TextField`.
// Tab moves focus, Page Up/Down and the mouse wheel scroll, a click focuses a
// pane, and Ctrl-C quits. Run with `swift run logs`.
import Stipple

enum Level: String {
    case info = "INFO "
    case warn = "WARN "
    case error = "ERROR"

    var color: Color {
        switch self {
        case .info: .blue
        case .warn: .yellow
        case .error: .red
        }
    }
}

struct Service: Identifiable {
    let id: String
    let color: Color

    static let all = [
        Self(id: "all", color: .white),
        Self(id: "api", color: .cyan),
        Self(id: "auth", color: .magenta),
        Self(id: "billing", color: .green),
        Self(id: "worker", color: .yellow),
    ]
}

struct LogLine: Identifiable {
    let id: Int
    let service: Service
    let level: Level
    let message: String

    /// A clock time a second apart per line, so the history reads like a day.
    var time: String {
        let seconds = 8 * 3600 + id * 7
        func two(_ value: Int) -> String { value < 10 ? "0\(value)" : "\(value)" }
        return "\(two(seconds / 3600 % 24)):\(two(seconds / 60 % 60)):\(two(seconds % 60))"
    }

    private static let messages: [String: [String]] = [
        "api": [
            "GET /v1/projects 200 in 12ms",
            "POST /v1/builds 201 in 48ms",
            "GET /v1/builds/latest/log 200 in 7ms, streamed 1.2 MB to the client",
            "rate limit reached for token tk_live_9f3, retrying in 2s",
        ],
        "auth": [
            "session refreshed for user 4821",
            "issued token for device \"build-agent-7\"",
            "rejected login: password expired, sent a reset link",
        ],
        "billing": [
            "invoice INV-2291 paid",
            "charged 29.00 EUR for the team plan",
            "card declined for workspace acme, will retry tomorrow",
        ],
        "worker": [
            "picked up job swift-build#1043",
            "cache hit: 412 of 430 modules",
            "job swift-build#1043 finished in 38s",
            "disk usage at 81% on runner-3, pruning old artifacts before the next job",
        ],
    ]

    /// A deterministic line for `id`, so every run shows the same log.
    static func make(id: Int) -> Self {
        var seed = UInt64(id) &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        func next(_ bound: Int) -> Int {
            seed ^= seed >> 29
            seed &*= 0xBF58_476D_1CE4_E5B9
            return Int(seed >> 33) % bound
        }
        let service = Service.all[1 + next(Service.all.count - 1)]
        let roll = next(20)
        let level: Level = roll == 0 ? .error : roll < 3 ? .warn : .info
        let choices = messages[service.id] ?? []
        return Self(id: id, service: service, level: level, message: choices[next(choices.count)])
    }
}

struct LogViewer: View {
    enum Pane { case log, filter }

    @State private var lines = (0..<5_000).map(LogLine.make)
    @State private var service: String? = "all"
    @State private var filter = ""
    @State private var position = ScrollPosition(edge: .bottom)
    @State private var isHoveringFollow = false
    @FocusState private var pane: Pane?

    private var visibleLines: [LogLine] {
        lines.filter { line in
            (service == "all" || line.service.id == service)
                && (filter.isEmpty || line.message.lowercased().contains(filter.lowercased()))
        }
    }

    var body: some View {
        let visible = visibleLines
        VStack(alignment: .leading) {
            header(count: visible.count)
            HStack {
                sidebar
                logPane(visible)
            }
            filterBar
            Text("Tab focus · ↑/↓ PgUp/PgDn scroll · End follow · wheel and click work too · Ctrl-C quit").dim()
        }
        .task {
            // New lines keep arriving; the scroll view follows them only while
            // it rests at the bottom.
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(700))
                lines.append(LogLine.make(id: lines.count))
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading) {
            Text("Services").bold()
            SelectionList(Service.all, selection: $service) { service in
                Text("● ").foregroundStyle(service.color) + Text(service.id)
            }
        }
        .padding(.horizontal, 1)
        .frame(width: 16, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .border(.rounded, color: .gray)
    }

    private func logPane(_ visible: [LogLine]) -> some View {
        ScrollView {
            LazyVStack {
                ForEach(visible) { line in row(line) }
            }
        }
        .defaultScrollAnchor(.bottom)
        .scrollPosition($position)
        .scrollOnPageKeys()
        .focused($pane, equals: .log)
        .padding(.leading, 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .border(.rounded, color: pane == .log ? .cyan : .gray)
    }

    private var filterBar: some View {
        HStack {
            Text("filter ").foregroundStyle(.magenta)
            TextField("type to filter messages", text: $filter).focused($pane, equals: .filter)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 1)
        .border(.rounded, color: pane == .filter ? .cyan : .gray)
    }

    private func header(count: Int) -> some View {
        HStack {
            Text(" stipple logs ").bold().inverse()
            Text("  \(count) lines").dim()
            Spacer()
            followBadge
        }
        .padding(.horizontal, 1)
    }

    /// Following while pinned to the bottom; a click jumps back there.
    private var followBadge: some View {
        let isFollowing = position.edge == .bottom
        return Text(isFollowing ? " ● following " : " ‖ paused · End or click to follow ")
            .foregroundStyle(isFollowing ? .green : .yellow)
            .inverse(isHoveringFollow)
            .onHover { isHoveringFollow = $0 }
            .onTapGesture { position.scrollTo(edge: .bottom) }
    }

    private func row(_ line: LogLine) -> some View {
        HStack {
            Text(line.time).dim()
                + Text(" \(line.level.rawValue) ").foregroundStyle(line.level.color).bold()
                + Text(line.service.id.padding(to: 8)).foregroundStyle(line.service.color)
            Text(line.message)
        }
    }
}

extension String {
    fileprivate func padding(to width: Int) -> String {
        count >= width ? self : self + String(repeating: " ", count: width - count)
    }
}

var options = RenderOptions()
options.alternateScreen = true
options.mouseReporting = true
try await Stipple.run(LogViewer(), options: options)
