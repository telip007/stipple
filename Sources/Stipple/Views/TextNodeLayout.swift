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
    /// Laid-out lines by width. A layout lives until its node rebuilds, and
    /// a frame asks for the same width several times (measuring, placing,
    /// drawing), so wrapping runs once per width instead.
    private let cache = LineCache()

    /// Widths from here up hold any line: half of `Int.infinity`, which
    /// stays this large after insets and borders are taken off it.
    static let unlimitedWidth = Int.infinity / 2

    /// Whether any run has text. A loop: a closure in this main-actor type
    /// is checked for the actor on every call.
    private var hasText: Bool {
        for run in runs where !run.text.isEmpty {
            return true
        }
        return false
    }

    /// What the node keeps across rebuilds; `nil` lays out from the start
    /// every time.
    private let memory: TextMemory?

    init(runs: [StyledRun], environment: EnvironmentValues, memory: TextMemory? = nil) {
        self.memory = memory
        transform = environment.isScreenReaderEnabled ? nil : environment.textTransform
        wrapping = environment.textWrapping
        self.runs = runs
        lineLimit = environment.lineLimit
        truncationMode = environment.truncationMode
        alignment = environment.multilineTextAlignment
    }

    func lines(width: Int?) -> [[StyledRun]] {
        let width = effectiveWidth(width)
        if let cached = cache.lines[width] { return cached }
        if let width, let fitting = linesFitting(in: width) {
            cache.lines[width] = fitting
            return fitting
        }
        let lines = layOut(width: width)
        cache.lines[width] = lines
        return lines
    }

    /// The wrap metrics, when measuring with them beats laying out lines:
    /// word-wrapped text without a line limit, whose lines at `width` aren't
    /// known yet and can't be continued from a checkpoint.
    private func metricsForMeasuring(at width: Int) -> WrapMetrics? {
        guard let memory, wrapping == .words, lineLimit == nil, width > 0, cache.lines[width] == nil,
            memory.checkpoints[width] == nil, linesFitting(in: width) == nil
        else { return nil }
        return memory.metrics(of: runs)
    }

    /// Lines already laid out for more room that fit in `width` as they are.
    /// Greedy wrapping gives the same lines then: whatever fit still fits,
    /// and a word that didn't fit still doesn't. Stacks place children at
    /// the stack's own width, its widest child's, so this happens to every
    /// text in a stack whenever its widest child grows, as a streamed line does.
    private func linesFitting(in width: Int) -> [[StyledRun]]? {
        guard lineLimit == nil, wrapping != .truncate else { return nil }
        for (key, size) in cache.sizes where size.width <= width && (key ?? .max) > width {
            if let lines = cache.lines[key] { return lines }
        }
        return nil
    }

    /// `width`, or `nil` for unlimited room without a line limit: such text
    /// doesn't wrap, so it is laid out as for its ideal size, which a growing
    /// text would otherwise redo as one ever longer row. (With a line limit a
    /// cut is marked with `…`, which the ideal size doesn't do.)
    private func effectiveWidth(_ width: Int?) -> Int? {
        guard let width, lineLimit == nil, width >= Self.unlimitedWidth else { return width }
        return nil
    }

    private func layOut(width: Int?) -> [[StyledRun]] {
        // Width 0 means "no constraint" for wrapping, as wrap-ansi treats 0 columns (Ink parity).
        guard let width, width > 0 else { return Array(TextLayout.lines(runs).prefix(lineLimit ?? .max)) }
        if lineLimit == 1 {
            return TextLayout.lines(runs).prefix(1).map { TextLayout.truncate($0, width: width, mode: truncationMode) }
        }
        let wrapped: [[StyledRun]]
        switch wrapping {
        case .words:
            if let memory {
                // Text that only grew, as a reply being streamed, wraps from where it stopped.
                let result = TextLayout.wrap(runs, width: width, resuming: memory.checkpoints[width])
                memory.checkpoints[width] = result.checkpoint
                wrapped = result.lines
            } else {
                wrapped = TextLayout.lines(runs).flatMap { TextLayout.wrap($0, width: width) }
            }
        case .characters: wrapped = TextLayout.lines(runs).flatMap { Self.characterWrap($0, width: width) }
        case .truncate:
            wrapped = TextLayout.lines(runs).map { TextLayout.truncate($0, width: width, mode: truncationMode) }
        }
        guard let lineLimit, wrapped.count > lineLimit, lineLimit > 0 else { return wrapped }
        if truncationMode == .head {
            // As in SwiftUI, head truncation keeps the end of the text.
            var kept = Array(wrapped.suffix(lineLimit))
            kept[0] = TextLayout.truncate(
                [StyledRun(text: "…", style: kept[0].first?.style ?? .plain)] + kept[0], width: width, mode: .head)
            return kept
        }
        var kept = Array(wrapped.prefix(lineLimit))
        kept[lineLimit - 1] = TextLayout.truncate(
            kept[lineLimit - 1] + [StyledRun(text: "…", style: kept[lineLimit - 1].last?.style ?? .plain)],
            width: width, mode: .tail)
        return kept
    }

    func sizeThatFits(_ proposal: ProposedSize, node: ViewNode) -> Size {
        guard hasText else { return .zero }
        let key = effectiveWidth(proposal.width)
        if let cached = cache.sizes[key] { return cached }
        let size: Size
        if let width = key, let metrics = metricsForMeasuring(at: width) {
            // Measured without laying out lines, which only text on screen needs.
            size = metrics.size(width: width)
        } else {
            let lines = lines(width: key)
            let width = lines.map { line in line.reduce(0) { $0 + TextMetrics.width(of: $1.text) } }.max() ?? 0
            size = Size(width: width, height: lines.count)
        }
        cache.sizes[key] = size
        return size
    }

    func placeChildren(of node: ViewNode, in bounds: Rect, proposal: ProposedSize) {}

    func draw(_ node: ViewNode, into canvas: inout Canvas, clip: Rect) {
        let frame = node.frame
        // Text scrolled out of view costs nothing to draw.
        guard frame.minY < clip.maxY, frame.maxY > clip.minY else { return }
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

/// What a text node keeps across rebuilds: where wrapping stopped, by
/// width, and the text's wrap metrics while the text stays the same.
@MainActor
final class TextMemory {
    var checkpoints: [Int: WrapCheckpoint] = [:]
    private var metrics: (runs: [StyledRun], value: WrapMetrics)?

    /// The wrap metrics of `runs`, worked out again only when they change.
    func metrics(of runs: [StyledRun]) -> WrapMetrics {
        if let metrics, metrics.runs == runs { return metrics.value }
        let value = WrapMetrics(runs)
        metrics = (runs, value)
        return value
    }
}

/// The lines and sizes one ``TextNodeLayout`` worked out, by width.
@MainActor
private final class LineCache {
    var lines: [Int?: [[StyledRun]]] = [:]
    var sizes: [Int?: Size] = [:]
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
