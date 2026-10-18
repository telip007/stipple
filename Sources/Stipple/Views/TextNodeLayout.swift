/// Sizes and draws text: wraps to the proposed width, or truncates when a
/// line limit is set.
@MainActor
struct TextNodeLayout: NodeLayout {
    let runs: [StyledRun]
    let lineLimit: Int?
    let truncationMode: TruncationMode
    let alignment: TextAlignment
    let transform: (@MainActor (String, Int) -> String)?
    let wrapping: TextWrapping

    init(runs: [StyledRun], environment: EnvironmentValues) {
        transform = environment.isScreenReaderEnabled ? nil : environment.textTransform
        wrapping = environment.textWrapping
        self.runs = runs
        lineLimit = environment.lineLimit
        truncationMode = environment.truncationMode
        alignment = environment.multilineTextAlignment
    }

    func lines(width: Int?) -> [[StyledRun]] {
        let hardLines = TextLayout.lines(runs)
        // Width 0 means "no constraint" for wrapping, as wrap-ansi treats 0 columns (Ink parity).
        guard let width, width > 0 else { return Array(hardLines.prefix(lineLimit ?? .max)) }
        if lineLimit == 1 {
            return hardLines.prefix(1).map { TextLayout.truncate($0, width: width, mode: truncationMode) }
        }
        let wrapped: [[StyledRun]]
        switch wrapping {
        case .words: wrapped = hardLines.flatMap { TextLayout.wrap($0, width: width) }
        case .characters: wrapped = hardLines.flatMap { Self.characterWrap($0, width: width) }
        case .truncate: wrapped = hardLines.map { TextLayout.truncate($0, width: width, mode: truncationMode) }
        }
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
        // Lay out with the proposal the text was measured with: truncation and
        // wrapping are not idempotent, so re-running them at the measured width can differ.
        for (row, line) in lines(width: node.placementProposal.width).prefix(frame.size.height).enumerated() {
            let width = line.reduce(0) { $0 + TextMetrics.width(of: $1.text) }
            let offset = alignment.offset(width: width, in: frame.size.width)
            let drawn = transform.map { ANSIText.parse($0(ANSIText.encode(line), row)) } ?? line
            canvas.write(drawn, at: Point(x: frame.minX + offset, y: frame.minY + row), clip: clip)
        }
    }
}

extension TextNodeLayout {
    /// Breaks a line every `width` columns regardless of word boundaries (Ink's `wrap="hard"`).
    static func characterWrap(_ line: [StyledRun], width: Int) -> [[StyledRun]] {
        var result: [[StyledRun]] = [[]]
        var column = 0
        for run in line {
            for character in run.text {
                let characterWidth = TextMetrics.width(of: character)
                if column + characterWidth > width, column > 0 {
                    result.append([])
                    column = 0
                }
                result[result.count - 1].append(StyledRun(text: String(character), style: run.style))
                column += characterWidth
            }
        }
        return result
    }
}

/// How text breaks lines that are wider than the offered space (Ink's `wrap` prop).
public enum TextWrapping: Hashable, Sendable {
    /// Break between words; break inside a word only when it doesn't fit on a line (default).
    case words
    /// Break at the exact column, ignoring word boundaries (Ink's `wrap="hard"`).
    case characters
    /// Don't wrap: shorten each line to fit, using the truncation mode (Ink's `wrap="truncate-*"`).
    case truncate
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
