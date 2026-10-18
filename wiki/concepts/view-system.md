---
title: View system
summary: View, ViewBuilder, the view graph, state, environment, layout, modifiers and the render loop.
updated: 2026-10-18
---

# View system

Ink uses React's reconciler. Stipple instead keeps its own retained graph of
`ViewNode`s, one per view value, and rebuilds the parts whose state changed.
The code lives in `Views/`, `State/`, `Layout/`, `Modifiers/` and `Runtime/`.

## Views

- `View` is `@MainActor` and has a `body`, as in SwiftUI. Built-in views have
  `Body == Never` and also conform to the internal `PrimitiveView`, whose
  `update(_ node:) -> [ChildView]` configures the node (layout, behaviours)
  and returns the children
  ([View.swift](../../Sources/Stipple/Views/View.swift)).
- `@ViewBuilder` uses parameter packs (`TupleView<(repeat each Content)>`).
  `TupleView` gets its children through `Mirror`.
  `if`/`else` becomes `ConditionalContent`, whose branches have distinct ids,
  so switching branches resets state.
- Built-in modifiers are one generic `ModifiedView<Content>` that holds a
  configuration closure ([ModifiedView.swift](../../Sources/Stipple/Modifiers/ModifiedView.swift)).
  Custom `ViewModifier`s go through `ModifiedContent`. Public modifiers return
  `some View`.

## The graph

- `ViewNode.rebuild()`: a primitive's `update` runs, or a composite view's dynamic
  properties are installed and its `body` evaluated inside
  `withObservationTracking`. Any observed change (`@State`, `@Observable`
  models) calls `invalidate()`, and the `ViewGraph` batches the node for the next frame
  ([ViewNode.swift](../../Sources/Stipple/State/ViewNode.swift)).
- Reconciliation matches children by explicit id (`ForEach`), or by position,
  plus the view's type. Matching nodes are updated and the rest are mounted or unmounted.
- Dynamic properties (`@State`, `@Environment`, `@FocusState`) contain a
  reference-typed link. `Mirror` sees copies of the property, but the copies
  share the link, so installing into a copy connects the view's own property
  to node-owned storage ([DynamicProperty.swift](../../Sources/Stipple/State/DynamicProperty.swift)).
- After a flush, `onAppear` callbacks run, tasks are started, restarted or
  cancelled (`task(id:)`), queued `onChange` actions run, and focus is reconciled.

## Layout

SwiftUI's two-pass model ([decision 0002](../decisions/0002-two-pass-layout.md)):

- `NodeLayout.sizeThatFits(_:node:)` and `placeChildren(of:in:proposal:)`.
  Sizes are cached per pass and proposal. A `nil` dimension in `ProposedSize`
  asks for the ideal size. `Int.infinity` (2³²) asks for the maximum and is
  small enough that sums can't overflow.
- Nodes without a layout are transparent: groups, composite views and
  environment or behaviour modifiers. Their children join the parent's layout
  (`layoutChildren`). A single-child modifier with several children stacks
  them vertically.
- Stacks follow SwiftUI's algorithm: higher `layoutPriority` first, then least
  flexible first, and each child is offered `remaining / remainingCount`.
  `VStack` defaults to `.leading` and `HStack` to `.top`, which suits terminals better
  than SwiftUI's `.center`.
- `Spacer` reads the enclosing stack's axis from the environment.
- `GeometryReader` writes its size into node storage after placement and
  invalidates itself if the size changed. The runtime repeats the
  flush, layout and geometry-callback loop up to four times per frame.

## Runtime

`Runtime` ([Runtime.swift](../../Sources/Stipple/Runtime/Runtime.swift)) wires the
pieces together in the same order as Ink's `ink.tsx` and `App.tsx`:

1. It sets up the frame writer, raw mode, bracketed paste and keyboard protocol, mounts the view and renders.
2. Terminal events arrive as bytes, go through the `InputParser` and become
   events. A pending lone ESC is flushed after 50 ms.
3. Keys: Ctrl-C exits (`exitOnCtrlC`). Tab and Shift-Tab move focus and Escape
   blurs it. The press then goes to handlers on the focused path (innermost
   first), then to global handlers (outside any `.focusable()`) in tree order, until one returns `.handled`.
4. Rendering is throttled to `maxFps` on the leading and trailing edge, and a
   `Task.yield()` batches changes made in the same turn. Each frame flushes
   the graph, collects `Static` output, lays out at the terminal width (height
   unbounded inline, the terminal height on the alternate screen), draws to a
   `Canvas` and hands the frame to the `FrameWriter`.
5. `exit()` draws the final frame, finishes the writer, unmounts the graph
   (`onDisappear`, task cancellation), restores the terminal and resumes `waitUntilExit()`.

`TerminalHost` abstracts the terminal, so runtime tests drive a fake
(`Tests/StippleTests/Runtime/FakeTerminal.swift`).

## Gotchas

- **Nested generic context types break inference.** `TimelineView.Context` nested
  in the generic `TimelineView<Content>` made `TimelineView(...) { context in … }`
  fail with "generic parameter 'Content' could not be inferred". SwiftUI uses a
  separate non-generic type, so Stipple has `TimelineContext`.
- **Optional property wrappers need an unconstrained `init(wrappedValue:)`.**
  `@FocusState private var focus: Field?` without an initial value is only
  default-initialized through `init(wrappedValue: nil)`. A constrained
  `init()` is not considered, and the view's memberwise initializer then
  demands a `focus:` argument.
- **Ink wrap parity**: `"Hello world, this wraps"` at width 11 wraps to
  `Hello / world, this / ␠wraps` because Ink calls wrap-ansi with `trim: false`.
- `KeyPress.Phases.contains(_ phase:)` must call `contains(Self.down)`. A bare
  `.down` resolves to `Phase.down`, so the call recurses infinitely.
