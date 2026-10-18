/// Sizes and draws text: wraps to the proposed width, or truncates when a
/// line limit is set.
@MainActor
struct TextNodeLayout: NodeLayout {
    let runs: [StyledRun]
    let lineLimit: Int?
    let truncationMode: TruncationMode
    let alignment: TextAlignment

    init(runs: [StyledRun], environment: EnvironmentValues) {
        self.runs = runs
        lineLimit = environment.lineLimit
        truncationMode = environment.truncationMode
        alignment = environment.multilineTextAlignment
    }

    func lines(width: Int?) -> [[StyledRun]] {
        let hardLines = TextLayout.lines(runs)
        guard let width else { return Array(hardLines.prefix(lineLimit ?? .max)) }
        if lineLimit == 1 {
            return hardLines.prefix(1).map { TextLayout.truncate($0, width: width, mode: truncationMode) }
        }
        let wrapped = hardLines.flatMap { TextLayout.wrap($0, width: width) }
        guard let lineLimit, wrapped.count > lineLimit, lineLimit > 0 else { return wrapped }
        var kept = Array(wrapped.prefix(lineLimit))
        kept[lineLimit - 1] = TextLayout.truncate(
            kept[lineLimit - 1] + [StyledRun(text: "…", style: kept[lineLimit - 1].last?.style ?? .plain)],
            width: width, mode: .tail)
        return kept
    }

    func sizeThatFits(_ proposal: ProposedSize, node: ViewNode) -> Size {
        guard runs.contains(where: { !$0.text.isEmpty }) else { return .zero }
        let lines = lines(width: proposal.width)
        let width = lines.map { line in line.reduce(0) { $0 + TextMetrics.width(of: $1.text) } }.max() ?? 0
        return Size(width: width, height: lines.count)
    }

    func placeChildren(of node: ViewNode, in bounds: Rect, proposal: ProposedSize) {}

    func draw(_ node: ViewNode, into canvas: inout Canvas, clip: Rect) {
        let frame = node.frame
        for (row, line) in lines(width: frame.size.width).prefix(frame.size.height).enumerated() {
            let width = line.reduce(0) { $0 + TextMetrics.width(of: $1.text) }
            let offset = alignment.offset(width: width, in: frame.size.width)
            canvas.write(line, at: Point(x: frame.minX + offset, y: frame.minY + row), clip: clip)
        }
    }
}

/// How lines of a multi-line text align with each other.
public enum TextAlignment: Hashable, Sendable {
    /// Left-aligned.
    case leading
    /// Centered.
    case center
    /// Right-aligned.
    case trailing

    func offset(width: Int, in space: Int) -> Int {
        switch self {
        case .leading: 0
        case .center: max(0, (space - width) / 2)
        case .trailing: max(0, space - width)
        }
    }
}
