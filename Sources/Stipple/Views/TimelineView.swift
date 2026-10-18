/// When a `TimelineView` updates.
public struct TimelineSchedule: Sendable, Hashable {
    let interval: Duration

    /// Updates every `interval`, e.g. `.periodic(every: .milliseconds(80))` for a spinner.
    public static func periodic(every interval: Duration) -> Self {
        Self(interval: interval)
    }
}

/// What a `TimelineView`'s content sees on each update.
public struct TimelineContext: Sendable, Hashable {
    /// Updates since the view appeared, starting at 0.
    public var frame: Int
    /// Time since the view appeared.
    public var elapsed: Duration
}

/// Rebuilds its content on a schedule (Ink's `useAnimation`).
///
/// ```swift
/// TimelineView(.periodic(every: .milliseconds(80))) { context in
///     Text(frames[context.frame % frames.count])
/// }
/// ```
public struct TimelineView<Content: View>: View, PrimitiveView {
    /// What the content sees on each update.
    public typealias Context = TimelineContext

    let schedule: TimelineSchedule
    let content: (Context) -> Content

    /// Creates a timeline view.
    public init(_ schedule: TimelineSchedule, @ViewBuilder content: @escaping (Context) -> Content) {
        self.schedule = schedule
        self.content = content
    }

    /// Never called: `TimelineView` is a built-in view.
    public typealias Body = Never

    func update(_ node: ViewNode) -> [ChildView] {
        let ticks = node.storage(at: 0) { TimelineTicks() }
        let interval = schedule.interval
        node.behaviors.tasks.append(
            NodeBehaviors.Task(id: AnyHashable(interval)) { [weak node] in
                let start = ContinuousClock.now
                ticks.frame = 0
                while !Task.isCancelled {
                    try? await Task.sleep(for: interval)
                    guard !Task.isCancelled else { return }
                    ticks.frame += 1
                    ticks.elapsed = ContinuousClock.now - start
                    node?.invalidate()
                }
            }
        )
        let context = Context(frame: ticks.frame, elapsed: ticks.elapsed)
        return [ChildView(id: nil, view: content(context), environment: node.environment)]
    }
}

@MainActor
final class TimelineTicks {
    var frame = 0
    var elapsed = Duration.zero
}
