/// Builds views from a collection, identifying each by an id so state
/// follows the element when the collection changes.
public struct ForEach<Data: RandomAccessCollection, ID: Hashable, Content: View>: View, PrimitiveView {
    /// The collection.
    public var data: Data
    let id: KeyPath<Data.Element, ID>
    let content: (Data.Element) -> Content

    /// Creates views for `data`, identified by the key path `id`.
    public init(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder content: @escaping (Data.Element) -> Content)
    {
        self.data = data
        self.id = id
        self.content = content
    }

    /// Never called: `ForEach` is a built-in view.
    public typealias Body = Never

    func update(_ node: ViewNode) -> [ChildView] {
        data.map { ChildView(id: AnyHashable($0[keyPath: id]), view: content($0), environment: node.environment) }
    }
}

extension ForEach where Data.Element: Identifiable, ID == Data.Element.ID {
    /// Creates views for identifiable elements.
    public init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.init(data, id: \.id, content: content)
    }
}

extension ForEach where Data == Range<Int>, ID == Int {
    /// Creates views for a constant range.
    public init(_ data: Range<Int>, @ViewBuilder content: @escaping (Int) -> Content) {
        self.init(data, id: \.self, content: content)
    }
}
