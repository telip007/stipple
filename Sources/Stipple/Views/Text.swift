/// Styled text. Long lines wrap at word boundaries unless a line limit
/// truncates them.
///
/// ```swift
/// Text("Done").foregroundStyle(.green).bold() + Text(" in 3s").dim()
/// ```
public struct Text: View, PrimitiveView, Equatable {
    struct Segment: Equatable {
        enum Content: Equatable {
            case plain(String)
            case ansi(String)
        }

        var content: Content
        var style = TextStyle()
    }

    var segments: [Segment]

    /// Creates text from a string, shown as-is.
    public init(_ content: some StringProtocol) {
        segments = [Segment(content: .plain(String(content)))]
    }

    /// Creates text from a string, shown as-is.
    public init(verbatim content: String) {
        segments = [Segment(content: .plain(content))]
    }

    /// Creates text from a string that already contains ANSI styling, such as
    /// a subprocess's colored output. Colors and attributes are kept; cursor
    /// movement and other control sequences are removed.
    public init(ansi content: String) {
        segments = [Segment(content: .ansi(content))]
    }

    private init(segments: [Segment]) {
        self.segments = segments
    }

    /// Never called: `Text` is a built-in view.
    public typealias Body = Never

    /// Concatenates two texts, keeping each one's styling.
    public static func + (lhs: Self, rhs: Self) -> Self {
        Self(segments: lhs.segments + rhs.segments)
    }

    func update(_ node: ViewNode) -> [ChildView] {
        node.layout = TextNodeLayout(runs: runs(in: node.environment), environment: node.environment)
        return []
    }

    /// The styled runs, with the environment's style underneath each segment's own.
    func runs(in environment: EnvironmentValues) -> [StyledRun] {
        let base = environment.textStyle
        return segments.flatMap { segment -> [StyledRun] in
            let style = base.merging(segment.style).resolved(background: environment.inheritedBackground)
            switch segment.content {
            case .plain(let string):
                return [StyledRun(text: string, style: style)]
            case .ansi(let string):
                return ANSIText.parse(string).map { run in
                    StyledRun(
                        text: run.text,
                        style: TextStyle(run.style).merging(segment.style).resolved(background: style.background))
                }
            }
        }
    }

    private func modified(_ change: (inout TextStyle) -> Void) -> Self {
        var copy = self
        for index in copy.segments.indices {
            change(&copy.segments[index].style)
        }
        return copy
    }

    /// Colors the text.
    public func foregroundStyle(_ color: Color?) -> Self { modified { $0.foreground = color } }
    /// Colors the cells behind the text.
    public func background(_ color: Color?) -> Self { modified { $0.background = color } }
    /// Makes the text bold.
    public func bold(_ isActive: Bool = true) -> Self { modified { $0.set(.bold, isActive) } }
    /// Makes the text italic.
    public func italic(_ isActive: Bool = true) -> Self { modified { $0.set(.italic, isActive) } }
    /// Underlines the text.
    public func underline(_ isActive: Bool = true) -> Self { modified { $0.set(.underline, isActive) } }
    /// Strikes the text through.
    public func strikethrough(_ isActive: Bool = true) -> Self { modified { $0.set(.strikethrough, isActive) } }
    /// Dims the text (Ink's `dimColor`).
    public func dim(_ isActive: Bool = true) -> Self { modified { $0.set(.dim, isActive) } }
    /// Swaps foreground and background colors.
    public func inverse(_ isActive: Bool = true) -> Self { modified { $0.set(.inverse, isActive) } }
    /// Makes the text a hyperlink, on terminals that support OSC 8.
    public func link(_ url: String) -> Self { modified { $0.link = url } }
}

/// Text styling that can be partially specified and layered: unset fields
/// fall through to the layer below.
struct TextStyle: Hashable, Sendable {
    var foreground: Color??
    var background: Color??
    var enabled: TextAttributes = []
    var disabled: TextAttributes = []
    var link: String?

    init() {}

    init(_ style: Style) {
        foreground = .some(style.foreground)
        background = .some(style.background)
        enabled = style.attributes
        link = style.link
    }

    mutating func set(_ attribute: TextAttributes, _ isActive: Bool) {
        if isActive {
            enabled.insert(attribute)
            disabled.remove(attribute)
        } else {
            disabled.insert(attribute)
            enabled.remove(attribute)
        }
    }

    /// `top` layered over `self`.
    func merging(_ top: Self) -> Self {
        var result = self
        if let foreground = top.foreground { result.foreground = foreground }
        if let background = top.background { result.background = background }
        result.enabled = enabled.subtracting(top.disabled).union(top.enabled)
        result.disabled = disabled.subtracting(top.enabled).union(top.disabled)
        result.link = top.link ?? link
        return result
    }

    /// A concrete style; a missing background falls back to the one painted behind the text.
    func resolved(background fallback: Color?) -> Style {
        Style(
            foreground: foreground.flatMap(\.self),
            background: background.flatMap(\.self) ?? fallback,
            attributes: enabled,
            link: link,
        )
    }
}
