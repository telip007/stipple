/// How a node sizes, places and draws itself. Nodes without one (groups,
/// composite views, most modifiers) are transparent: their children take
/// part in the parent's layout directly.
@MainActor
protocol NodeLayout {
    /// The size the node wants for `proposal`. Child sizes come from
    /// `node.layoutChildren`.
    func sizeThatFits(_ proposal: ProposedSize, node: ViewNode) -> Size
    /// Places the node's layout children inside `bounds` (the node's frame).
    func placeChildren(of node: ViewNode, in bounds: Rect, proposal: ProposedSize)
    /// Draws the node's own content (not its children).
    func draw(_ node: ViewNode, into canvas: inout Canvas, clip: Rect)
    /// The clip rectangle the node's children draw with.
    func childClip(_ node: ViewNode, clip: Rect) -> Rect
    /// Whether placing children depends on nothing but the bounds, the
    /// proposal and the children's sizes, and changes nothing else. Such a
    /// subtree is placed again only when it rebuilt or its proposal changed,
    /// and moved as a whole when only its origin did.
    var placesPurely: Bool { get }
}

extension NodeLayout {
    func draw(_ node: ViewNode, into canvas: inout Canvas, clip: Rect) {}

    func childClip(_ node: ViewNode, clip: Rect) -> Rect { clip }

    var placesPurely: Bool { false }
}

// Layouts that read state or have effects while placing (scroll views,
// geometry readers, text fields, `Static`) keep the default and are placed
// every frame, and so are their ancestors.
extension StackLayout { var placesPurely: Bool { true } }
extension OverlayLayout { var placesPurely: Bool { true } }
extension LayeredLayout { var placesPurely: Bool { true } }
extension PassThroughLayout { var placesPurely: Bool { true } }
extension InsetLayout { var placesPurely: Bool { true } }
extension ClipLayout { var placesPurely: Bool { true } }
extension OffsetLayout { var placesPurely: Bool { true } }
extension FixedSizeLayout { var placesPurely: Bool { true } }
extension FrameLayout { var placesPurely: Bool { true } }
extension HiddenLayout { var placesPurely: Bool { true } }
extension BackgroundLayout { var placesPurely: Bool { true } }
extension BorderLayout { var placesPurely: Bool { true } }
extension TextNodeLayout { var placesPurely: Bool { true } }
extension DividerLayout { var placesPurely: Bool { true } }
extension SpacerLayout { var placesPurely: Bool { true } }

/// A layout with exactly one child that it forwards to, possibly with a
/// changed proposal. Modifiers such as padding and frames build on it.
@MainActor
protocol SingleChildLayout: NodeLayout {}

extension SingleChildLayout {
    /// The node's children as one unit: a single child as-is, several as an
    /// implicit vertical stack.
    func content(of node: ViewNode) -> ChildGroup {
        ChildGroup(nodes: node.layoutChildren)
    }
}

/// Several layout children that a single-child modifier treats as one:
/// stacked vertically, leading-aligned, like an implicit `VStack`.
@MainActor
struct ChildGroup {
    let nodes: [ViewNode]
    private let stack = StackLayout(axis: .vertical, alignment: .leading, spacing: 0)

    func sizeThatFits(_ proposal: ProposedSize) -> Size {
        switch nodes.count {
        case 0: .zero
        case 1: nodes[0].sizeThatFits(proposal)
        default: stack.size(of: nodes, proposal: proposal)
        }
    }

    func place(at origin: Point, proposal: ProposedSize) {
        switch nodes.count {
        case 0: break
        case 1: nodes[0].place(at: origin, proposal: proposal)
        default:
            let size = stack.size(of: nodes, proposal: proposal)
            stack.place(nodes, in: Rect(origin: origin, size: size), proposal: proposal)
        }
    }
}
