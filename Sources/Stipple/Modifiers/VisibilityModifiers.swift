extension View {
    /// Keeps the view's space but draws nothing.
    public func hidden() -> some View {
        layout(HiddenLayout())
    }

    /// Disables interaction: key and paste handlers in this view don't run
    /// and it can't take focus.
    public func disabled(_ disabled: Bool = true) -> some View {
        environmentChange { environment in
            if disabled { environment.isEnabled = false }
        }
    }
}

@MainActor
struct HiddenLayout: SingleChildLayout {
    func sizeThatFits(_ proposal: ProposedSize, node: ViewNode) -> Size {
        content(of: node).sizeThatFits(proposal)
    }

    func placeChildren(of node: ViewNode, in bounds: Rect, proposal: ProposedSize) {
        content(of: node).place(at: bounds.origin, proposal: proposal)
    }

    func childClip(_ node: ViewNode, clip: Rect) -> Rect { Rect(x: 0, y: 0, width: 0, height: 0) }
}

struct IsEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Whether interaction is enabled; `false` under `.disabled()`.
    public var isEnabled: Bool {
        get { self[IsEnabledKey.self] }
        set { self[IsEnabledKey.self] = newValue }
    }
}
