/// Where a ``ScrollView`` is scrolled to, as SwiftUI's `ScrollPosition`.
///
/// Bind it with ``View/scrollPosition(_:)``. Set it to scroll the view, and
/// read it to see where the user scrolled. A position is kept as content
/// changes: one at the bottom edge stays at the bottom as content grows (the
/// chat behaviour), one at a row keeps that row at the top, and one at a
/// view keeps that view in sight.
///
/// When the user scrolls (keys or wheel), the view writes the new position
/// back with ``isPositionedByUser`` set: ``edge`` is `.top` or `.bottom`
/// when the view rests against that edge, otherwise ``y`` is the row at the
/// top of the viewport. Scrolling back to the bottom therefore pins it again.
///
/// ```swift
/// @State private var position = ScrollPosition(edge: .bottom)
///
/// ScrollView { transcript }
///     .scrollPosition($position)
/// // Later: position.scrollTo(edge: .bottom)
/// ```
public struct ScrollPosition: Hashable {
    enum Target: Hashable {
        case edge(Edge)
        case y(Int)
        case id(AnyHashable)
    }

    /// What the position points at; `nil` until something is set, in which
    /// case the view's ``View/defaultScrollAnchor(_:)`` decides.
    var target: Target?
    /// Rows to move by, from ``scrollBy(lines:)``; the view applies them once.
    var delta = 0

    /// Whether the user put the view here by scrolling, rather than the app.
    public internal(set) var isPositionedByUser = false

    /// A position that the view's default anchor decides (the top unless
    /// ``View/defaultScrollAnchor(_:)`` says otherwise).
    public init() {}

    /// A position for views identified by values of `idType`. The type is
    /// only documentation here, as in SwiftUI; any `Hashable` id works.
    public init<ID: Hashable>(idType: ID.Type) {}

    /// A position at an edge. Only `.top` and `.bottom` move a vertical scroll view.
    public init(edge: Edge) {
        target = .edge(edge)
    }

    /// A position with row `y` of the content at the top of the viewport.
    public init(y: Int) {
        target = .y(y)
    }

    /// A position that keeps the view marked with `.id(id)` in sight.
    public init(id: some Hashable) {
        target = .id(AnyHashable(id))
    }

    /// The edge the view is positioned at, if any.
    public var edge: Edge? {
        if case .edge(let edge) = target { return edge }
        return nil
    }

    /// The content row at the top of the viewport, if the position is a row.
    public var y: Int? {
        if case .y(let y) = target { return y }
        return nil
    }

    /// The id of the view the position keeps in sight, if any.
    public var viewID: AnyHashable? {
        if case .id(let id) = target { return id }
        return nil
    }

    /// The id of the view the position keeps in sight, if it has type `ID`.
    public func viewID<ID: Hashable>(type: ID.Type) -> ID? {
        viewID?.base as? ID
    }

    /// Scrolls to an edge and stays there as content changes.
    public mutating func scrollTo(edge: Edge) {
        set(.edge(edge))
    }

    /// Scrolls so that content row `y` is at the top of the viewport.
    public mutating func scrollTo(y: Int) {
        set(.y(y))
    }

    /// Scrolls just enough to bring the view marked with `.id(id)` (or a
    /// `ForEach` element with that id) fully into view. A view taller than
    /// the viewport shows its top.
    public mutating func scrollTo(id: some Hashable) {
        set(.id(AnyHashable(id)))
    }

    /// Scrolls by `lines` rows from wherever the view is now: down when
    /// positive, up when negative. Calls add up until the view applies them.
    public mutating func scrollBy(lines: Int) {
        delta += lines
        isPositionedByUser = false
    }

    private mutating func set(_ target: Target) {
        self.target = target
        delta = 0
        isPositionedByUser = false
    }

    /// The position for a view that rests at `offset`: an edge when it
    /// touches one, otherwise the row.
    static func resting(at offset: Int, maxOffset: Int, byUser: Bool) -> Self {
        var position = Self()
        if offset <= 0 {
            position.target = .edge(.top)
        } else if offset >= maxOffset {
            position.target = .edge(.bottom)
        } else {
            position.target = .y(offset)
        }
        position.isPositionedByUser = byUser
        return position
    }
}

/// What a default scroll anchor applies to, as in SwiftUI.
public enum ScrollAnchorRole: Hashable, Sendable, CaseIterable {
    /// Where the view starts.
    case initialOffset
    /// What stays in place when the content or the viewport changes size.
    /// `.bottom` keeps the distance to the bottom, so a view at the bottom stays there.
    case sizeChanges
    /// Where content shorter than the viewport sits.
    case alignment
}

/// When a scroll view draws its scroll indicator, as in SwiftUI.
public enum ScrollIndicatorVisibility: Hashable, Sendable {
    /// When the content is taller than the viewport.
    case automatic
    /// Always, taking the rightmost column even when nothing overflows.
    case visible
    /// Never.
    case hidden
    /// Never.
    case never
}

/// The default anchors of scroll views, one per role.
struct ScrollAnchors: Hashable, Sendable {
    var initialOffset: UnitPoint?
    var sizeChanges: UnitPoint?
    var alignment: UnitPoint?
}

struct ScrollAnchorsKey: EnvironmentKey {
    static let defaultValue = ScrollAnchors()
}

struct ScrollIndicatorVisibilityKey: EnvironmentKey {
    static let defaultValue = ScrollIndicatorVisibility.automatic
}

struct ScrollPositionBindingKey: EnvironmentKey {
    static let defaultValue: BoundScrollPosition? = nil
}

/// A scroll position binding as the environment holds it: equal to another
/// binding of the same state, so rebuilding `.scrollPosition($position)`
/// keeps the environment, and the views inside, unchanged.
struct BoundScrollPosition: Equatable {
    let binding: Binding<ScrollPosition>

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.binding.hasSameSource(as: rhs.binding)
    }
}

struct ScrollOnPageKeysKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// The scroll indicator visibility set by ``View/scrollIndicators(_:axes:)``.
    public var verticalScrollIndicatorVisibility: ScrollIndicatorVisibility {
        get { self[ScrollIndicatorVisibilityKey.self] }
        set { self[ScrollIndicatorVisibilityKey.self] = newValue }
    }

    var scrollAnchors: ScrollAnchors {
        get { self[ScrollAnchorsKey.self] }
        set { self[ScrollAnchorsKey.self] = newValue }
    }

    var scrollPositionBinding: Binding<ScrollPosition>? {
        get { self[ScrollPositionBindingKey.self]?.binding }
        set { self[ScrollPositionBindingKey.self] = newValue.map(BoundScrollPosition.init) }
    }

    var scrollOnPageKeys: Bool {
        get { self[ScrollOnPageKeysKey.self] }
        set { self[ScrollOnPageKeysKey.self] = newValue }
    }
}

extension View {
    /// Ties the position of the scroll view inside to `position`: setting it
    /// scrolls, and user scrolling writes it back. Scroll views nested in
    /// that one don't share it.
    public func scrollPosition(_ position: Binding<ScrollPosition>) -> some View {
        environmentChange { $0.scrollPositionBinding = position }
    }

    /// Sets where scroll views inside start, where they stay as content
    /// changes and where short content sits (every ``ScrollAnchorRole``).
    /// `.bottom` makes a chat view: it starts at the bottom, follows new
    /// content while it is at the bottom, and puts short content at the bottom.
    public func defaultScrollAnchor(_ anchor: UnitPoint?) -> some View {
        environmentChange { environment in
            environment.scrollAnchors = ScrollAnchors(initialOffset: anchor, sizeChanges: anchor, alignment: anchor)
        }
    }

    /// Sets the default anchor of scroll views inside for one role. For a
    /// chat that starts at the top while short but follows new content, use
    /// `.defaultScrollAnchor(.bottom, for: .sizeChanges)`.
    public func defaultScrollAnchor(_ anchor: UnitPoint?, for role: ScrollAnchorRole) -> some View {
        environmentChange { environment in
            switch role {
            case .initialOffset: environment.scrollAnchors.initialOffset = anchor
            case .sizeChanges: environment.scrollAnchors.sizeChanges = anchor
            case .alignment: environment.scrollAnchors.alignment = anchor
            }
        }
    }

    /// Sets when scroll views inside draw their scroll indicator, a thin
    /// bar in the rightmost column. Only the vertical axis has one.
    public func scrollIndicators(
        _ visibility: ScrollIndicatorVisibility,
        axes: Axis.Set = [.vertical, .horizontal],
    ) -> some View {
        environmentChange { environment in
            if axes.contains(.vertical) { environment.verticalScrollIndicatorVisibility = visibility }
        }
    }

    /// Lets Page Up and Page Down scroll the scroll view inside even while
    /// focus is outside it, for example on a text field below a transcript.
    /// Handlers of the focused view and global `.onKeyPress` handlers still
    /// see the keys first.
    public func scrollOnPageKeys(_ enabled: Bool = true) -> some View {
        environmentChange { $0.scrollOnPageKeys = enabled }
    }
}
