/// The frames and timing of an indeterminate spinner (the `ink-spinner` presets).
public struct ProgressViewStyle: Sendable, Hashable {
    /// The frames, shown in order and repeated.
    public var frames: [String]
    /// The time each frame is shown.
    public var interval: Duration

    /// Creates a spinner from its frames. The default interval is 80 ms.
    public init(frames: [String], interval: Duration = .milliseconds(80)) {
        self.frames = frames
        self.interval = interval
    }

    /// Braille dots, `⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏`. The default.
    public static var dots: Self {
        Self(frames: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"])
    }

    /// A rotating line, `-\|/`.
    public static var line: Self {
        Self(frames: ["-", "\\", "|", "/"], interval: .milliseconds(130))
    }

    /// A quarter-circle arc, `◜◠◝◞◡◟`.
    public static var arc: Self {
        Self(frames: ["◜", "◠", "◝", "◞", "◡", "◟"], interval: .milliseconds(100))
    }
}

extension View {
    /// Sets the spinner used by ``ProgressView`` in this view.
    public func progressViewStyle(_ style: ProgressViewStyle) -> some View {
        environment(\.spinnerStyle, style)
    }
}

struct SpinnerStyleKey: EnvironmentKey {
    static var defaultValue: ProgressViewStyle { .dots }
}

extension EnvironmentValues {
    var spinnerStyle: ProgressViewStyle {
        get { self[SpinnerStyleKey.self] }
        set { self[SpinnerStyleKey.self] = newValue }
    }
}

/// Shows progress: an animated spinner when the amount is unknown, or a bar
/// that fills the width it is offered when it is known (Ink's `ink-spinner`
/// and `ink-progress-bar` jobs).
///
/// ```swift
/// ProgressView("Loading")                      // ⠋ Loading
/// ProgressView(value: 0.4)                     // ████░░░░░░  (fills its width)
/// ProgressView("Copying", value: done, total: count)
/// ProgressView().progressViewStyle(.line)     // -, \, |, /
/// ```
///
/// The spinner advances on a `TimelineView`, so it animates only while it is on screen.
public struct ProgressView: View {
    private let label: String?
    private let value: Double?
    private let total: Double
    @Environment(\.spinnerStyle) private var spinnerStyle

    /// An indeterminate spinner.
    public init() {
        label = nil
        value = nil
        total = 1
    }

    /// An indeterminate spinner followed by `label`.
    public init(_ label: String) {
        self.label = label
        value = nil
        total = 1
    }

    /// A determinate bar showing `value` out of `total`. Values outside
    /// `0...total` are clamped, and a total of 0 or less shows an empty bar.
    public init(value: Double, total: Double = 1) {
        label = nil
        self.value = value
        self.total = total
    }

    /// A determinate bar with `label` before it.
    public init(_ label: String, value: Double, total: Double = 1) {
        self.label = label
        self.value = value
        self.total = total
    }

    /// A spinner or a bar, depending on whether a value was given.
    public var body: some View {
        if let value {
            bar(value: value)
        } else {
            spinner
        }
    }

    @ViewBuilder
    private var spinner: some View {
        let style = spinnerStyle
        TimelineView(.periodic(every: style.interval)) { context in
            let frame = style.frames[context.frame % style.frames.count]
            if let label {
                Text(frame) + Text(" " + label)
            } else {
                Text(frame)
            }
        }
    }

    @ViewBuilder
    private func bar(value: Double) -> some View {
        let fraction = Self.fraction(value: value, total: total)
        if let label {
            HStack(spacing: 1) {
                Text(label)
                GeometryReader { proxy in
                    Text(Self.barText(fraction: fraction, width: proxy.size.width))
                }
            }
        } else {
            GeometryReader { proxy in
                Text(Self.barText(fraction: fraction, width: proxy.size.width))
            }
        }
    }

    /// `value / total` clamped to `0...1`; an empty bar when `total` is not positive.
    static func fraction(value: Double, total: Double) -> Double {
        guard total > 0 else { return 0 }
        return min(max(value / total, 0), 1)
    }

    /// `width` cells: filled (`█`) up to the fraction, then empty (`░`).
    static func barText(fraction: Double, width: Int) -> String {
        guard width > 0 else { return "" }
        let filled = Int((fraction * Double(width)).rounded())
        return String(repeating: "█", count: filled) + String(repeating: "░", count: width - filled)
    }
}
