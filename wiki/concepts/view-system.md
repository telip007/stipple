---
title: View system
summary: View, ViewBuilder, the view graph, state, environment, layout, modifiers, scrolling, mouse routing and the render loop.
updated: 2026-10-19
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
- An update is skipped when the node isn't dirty, the view is `Equatable` and
  equal to the current one, and the environment is identical
  (`EnvironmentValues.isIdentical(to:)`). The subtree keeps its nodes, its
  observation and its cached layout. This is what lets a long list rebuild
  without rebuilding every row: make the row view `Equatable` (as SwiftUI does
  with `EquatableView`). `Text` is `Equatable`.
- Environment identity is a revision token. Setting a value derives the next
  revision, and setting an equal value on the same revision again derives the
  same one, so a modifier that rebuilds hands its children an identical
  environment. Values that aren't `Equatable` (closures, bindings) always make
  a new revision; the scroll position binding is stored as
  `BoundScrollPosition`, equal for bindings of the same `@State`
  (`Binding.source`).
- Dynamic properties (`@State`, `@Environment`, `@FocusState`) contain a
  reference-typed link. `Mirror` sees copies of the property, but the copies
  share the link, so installing into a copy connects the view's own property
  to node-owned storage ([DynamicProperty.swift](../../Sources/Stipple/State/DynamicProperty.swift)).
- After a flush, `onAppear` callbacks run, tasks are started, restarted or
  cancelled (`task(id:)`), queued `onChange` actions run, and focus is reconciled.

## Layout

SwiftUI's two-pass model ([decision 0002](../decisions/0002-two-pass-layout.md)):

- `NodeLayout.sizeThatFits(_:node:)` and `placeChildren(of:in:proposal:)`.
  Sizes are cached per proposal across frames, and a rebuild clears the cache
  of the node and its ancestors (see [Retained layout](#retained-layout)).
  A `nil` dimension in `ProposedSize`
  asks for the ideal size. `Int.infinity` (2³²) asks for the maximum and is
  small enough that sums can't overflow.
- Nodes without a layout are transparent: groups, composite views and
  environment or behaviour modifiers. Their children join the parent's layout
  (`layoutChildren`). A single-child modifier with several children stacks
  them vertically.
- Stacks follow SwiftUI's algorithm: higher `layoutPriority` first, then least
  flexible first. Each child is offered the larger of an equal share
  (`remaining / remainingCount`) and its ideal length, if the ideal still
  leaves the unprocessed siblings their minimums. That is how
  `HStack { Spacer(); Text("Test"); Spacer() }` centres the word instead of
  wrapping it. A child's minimum is the smaller of its lengths when offered
  0 and 1 cell. Text offered 0 doesn't wrap, as in Ink (wrap-ansi with 0
  columns), but it can shrink to one column.
- Stacks place children at the stack's final cross size, not the original
  proposal, so `.frame(maxWidth: .infinity)` children of a `.fixedSize()`
  `VStack` stretch to the widest sibling (Ink's `alignItems: stretch`).
- Text draws with the lines computed for the proposal it was placed with
  (`ViewNode.placementProposal`), because head and middle truncation aren't
  idempotent at the measured width.
  `VStack` defaults to `.leading` and `HStack` to `.top`, which suits terminals better
  than SwiftUI's `.center`.
- `Spacer` reads the enclosing stack's axis from the environment.
- `GeometryReader` writes its size into node storage after placement and
  invalidates itself if the size changed. The runtime repeats the
  flush, layout and geometry-callback loop up to four times per frame.

## Retained layout

Each frame lays out the whole tree, so the work a frame does has to be
proportional to what changed, not to the size of the tree. A transcript of a
few hundred blocks went from about a second per frame (debug build) to a few
milliseconds with these:

- **Sizes** live in `ViewNode.sizeCache` until the node or a node below it
  rebuilds. Layouts are values set on rebuild, so nothing else can change a
  size. `invalidateSizes()` walks up and stops at an empty cache on a node
  with a layout; transparent nodes never stop it, because parents measure
  through them (`layoutChildren`) and leave their caches empty.
- **Wrapped text**: `TextNodeLayout` keeps its lines and size per width in a
  `LineCache`, so measuring, placing and drawing wrap once per width. Text
  outside the clip isn't drawn.
- **Placement** is skipped when nothing below a node rebuilt, its proposal is
  the same, and the last placement used only layouts with
  `NodeLayout.placesPurely`. When only the origin changed, the subtree's frames
  are moved. Scroll views, geometry readers, text fields and `Static` read
  state or have effects while placing, so they and their ancestors are placed
  every frame; pure content inside them is not. A new layout that reads state
  in `placeChildren` must keep `placesPurely` false.
- **`layoutChildren`** is cached until the node or one below it rebuilds.
- **Tree walks** (geometry callbacks, the cursor, focus, global keys, mouse
  motion) visit nodes in place (`ViewNode.visit`) instead of concatenating
  arrays at every level.
- **A scroll view's ideal size** is its content's ideal size. Measuring the
  height again at the ideal width gave the same rows, but at a width that
  changed with the widest line, so every row was laid out again whenever a
  long line grew.

## Scrolling

`ScrollView` ([ScrollView.swift](../../Sources/Stipple/Views/ScrollView.swift))
is a primitive whose node keeps a `ScrollState` (offset and the measurements
of the last layout) in node storage. `ScrollPosition` and the scroll
modifiers are in [ScrollPosition.swift](../../Sources/Stipple/Views/ScrollPosition.swift)
([decision 0008](../decisions/0008-scrolling-and-mouse.md)).

- **Layout.** It takes the proposed height as its viewport and the proposed
  width (fully flexible both ways, like SwiftUI's); with no proposed height it
  is as tall as its content, so inline output shows everything unless a
  frame limits it. The content is laid out at the viewport width with height
  `nil` (its ideal height), placed `offset` rows above the viewport's top, and
  its children draw with the clip narrowed to the viewport.
- **Indicator.** `.automatic` (the default) measures the content at full width;
  if it overflows, the content gets one column less and the last column draws
  `┃` for the thumb and a dim `│` for the track. `.visible` always takes the
  column, `.hidden`/`.never` never do.
- **Resolving the offset**, on every placement: an `.edge` target gives 0 or the
  maximum, `.y` is clamped, `.id` places the content once at offset 0, finds
  the node whose `appID` matches (set by `.id(_:)` and on `ForEach` children)
  and scrolls just enough to show its frame (`layoutFrame`, the union of the
  layout children's frames for transparent nodes). With no target the
  default anchors decide: `.initialOffset` on the first layout, then
  `.sizeChanges` shifts the offset by `anchor.y × Δmax`, so `.bottom` keeps the
  distance to the bottom. `.alignment` positions content shorter than the
  viewport. `scrollBy(lines:)` adds its delta once and the view writes back
  the resting position.
- **Writing back.** Keys and the wheel call `ScrollState.scrollByUser(to:)`,
  which clamps, stores `ScrollPosition.resting(at:…)` (edge at either end,
  otherwise `.y`) with `isPositionedByUser`, and schedules a frame without
  rebuilding the subtree. A bound position is read at layout time inside
  `withObservationTracking`, so the app setting it schedules a frame even when
  no body reads it. One observation is kept at a time; the flag clears in
  the change callback.
- **Keys** ([Runtime+Input.swift](../../Sources/Stipple/Runtime/Runtime+Input.swift)).
  Scroll views are a separate dispatch stage, not ordinary key handlers: after
  the focused path, the scroll views that contain the focused node, or whose
  nearest focusable ancestor is the focused node (`ScrollView { }.focusable()`),
  innermost first, take ↑/↓, Page Up/Down and Home/End without modifiers.
  Then the global handlers run. Last, scroll views with
  `.scrollOnPageKeys()` take Page Up/Down. A text field elsewhere therefore
  keeps its arrows and Home/End.
- **Mouse** ([Runtime+Mouse.swift](../../Sources/Stipple/Runtime/Runtime+Mouse.swift)).
  On the alternate screen the frame starts at row 0, so a report's cell is a
  frame coordinate. `ViewGraph.nodes(at:in:)` walks the tree with the same
  clips as drawing and returns the nodes with a layout whose visible part
  contains the point, topmost first. A wheel notch scrolls 3 rows in the first
  scroll view of that list that can move (so an inner view at its end lets the
  outer one scroll). Inline, the frame's screen row is unknown, so the wheel
  goes to scroll views around focus, then the innermost one in tree order.
  Clicks, taps and hover use the *pointer path*: the innermost hit node and
  its ancestors, so transparent nodes (a `.focusable()` or `.onTapGesture`
  modifier without a layout) are found through their hit descendants.
  A left press first focuses the innermost enabled focusable node on the
  path (click-to-focus), then records the innermost node with tap handlers;
  the release must find the same node. Clicks on the same cell within
  500 ms form a series, and for each count the innermost handler on the path
  up from the pressed node runs when the series length is a multiple of its
  count. Every report updates hover: nodes with `.onHover` handlers on the
  path get `true` on entering and `false` on leaving. After each frame the
  runtime turns motion reports (`?1003`) on while any node has a hover
  handler and off when none has.

## Runtime

`Runtime` ([Runtime.swift](../../Sources/Stipple/Runtime/Runtime.swift)) wires the
pieces together in the same order as Ink's `ink.tsx` and `App.tsx`:

1. It sets up the frame writer, raw mode, bracketed paste and keyboard protocol, mounts the view and renders.
2. Terminal events arrive as bytes, go through the `InputParser` and become
   events. A pending lone ESC is flushed after 50 ms.
3. Keys: Ctrl-C exits (`exitOnCtrlC`). Tab and Shift-Tab move focus and Escape
   blurs it. The press then goes to handlers on the focused path (innermost
   first), scroll views in or around focus, global handlers (outside any
   `.focusable()`) in tree order, and scroll views with `.scrollOnPageKeys()`,
   until one returns `.handled`. Mouse reports (with `RenderOptions.mouseReporting`)
   go to `handleMouse` ([Scrolling](#scrolling)).
4. Rendering is throttled to `maxFps` on the leading and trailing edge, and a
   `Task.yield()` batches changes made in the same turn. Each frame flushes
   the graph, collects `Static` output, lays out at the terminal width (height
   unbounded inline, the terminal height on the alternate screen), draws to a
   `Canvas` and hands the frame to the `FrameWriter`.
5. `exit()` draws the final frame, finishes the writer, unmounts the graph
   (`onDisappear`, task cancellation), restores the terminal and resumes `waitUntilExit()`.

Screen reader mode replaces the canvas with `ScreenReaderRenderer`, Ink's
`renderNodeToScreenReaderOutput`: text as-is, horizontal stacks joined by spaces
and everything else by newlines, labels replacing content, and roles and states
as prefixes. A chain of accessibility modifier nodes is merged first, because
Ink keeps every `aria-*` prop on one element.

`TerminalHost` abstracts the terminal, so runtime tests drive a fake
(`Tests/StippleTests/Runtime/FakeTerminal.swift`).

## Gotchas

- An `Equatable` view whose `==` ignores something its body shows will not
  update when only that changes. Compare everything the body reads that isn't
  observed.

- **Reading a binding in a primitive's `update` isn't tracked.** Only composite
  bodies (and custom modifiers) run inside `withObservationTracking`. A
  primitive that must react to a binding the app sets, as `ScrollView` does
  with its position, has to track the read itself.
- **Write-backs during layout re-run the frame loop.** `scrollBy(lines:)` is
  resolved at placement and stores the new position into the binding; any
  body that reads it is invalidated, and `hasPendingWork` makes the runtime
  (and `renderToString`) lay out again. Write only when the value changes, or
  the loop never settles.
- **`.id(_:)` is transparent.** It must not get a layout: a `PassThroughLayout`
  would stack a multi-view body vertically even inside an `HStack`. Its frame
  for `scrollTo(id:)` is the union of its layout children's frames.
- **`.onTapGesture` and `.onHover` have no layout.** An earlier version gave
  them a `PassThroughLayout` so they had a frame to hit-test, which stacks a
  multi-view body vertically. The pointer path finds them through their hit
  descendants instead.
- **A ScrollView offered `.infinity` height answers `.infinity`.** That makes it
  the most flexible child of a stack, so it takes the space left after
  headers and inputs, as in SwiftUI.

- **`@FocusState var x: Bool` needs `= false`.** Swift only default-initializes a
  property wrapper through `init(wrappedValue:)` (for optionals, with `nil`) or an
  unconstrained `init()`. `FocusState`'s Bool `init()` is constrained, so write
  `@FocusState private var focused = false`. Optional focus state such as `Field?` works as in SwiftUI.
- **Setting `@FocusState` moves focus even if no body reads it.** The wrapper keeps a
  weak link to the graph and calls `requestFocusUpdate()`, which re-applies focus on the next flush.

- **Swift 6.2 resolves shadowed names differently from 6.4.** `let cross =
  sizes.map { $0.dimension(cross) }` compiled on 6.4 (where `cross` was the
  property) but failed on Linux with 6.2, which resolves it to the local
  being declared. The same happened with a local `text` shadowing
  `text(of:)`. Don't shadow members in their own initializer, and run
  `make test-linux`. Swift 6.2 also rejects `public import` that no public
  declaration uses, including in test files.

- **Invalidation is queued synchronously, not by a task hop.** Observation's
  `onChange` fires on the mutating thread before the new value is stored. An
  earlier version hopped to the main actor with a `Task`, so `count += 1;
  exit()` drew the final frame without the change. Nodes now go into a
  `Mutex`-protected `InvalidationQueue`, which every flush drains first
  ([InvalidationQueue.swift](../../Sources/Stipple/State/InvalidationQueue.swift)).
- **Text minimum width, revised.** Treating a width-0 proposal as 1 helped
  stacks but broke Ink parity: in Ink, text in a zero-width box overflows
  unwrapped. The stack now measures a child's minimum as
  `min(length(0), length(1))` instead.
- **`.frame(idealWidth:)` answers ideal-size proposals.** With neither min nor
  max set, a flexible frame returns its ideal size when asked for the ideal size
  (`fixedSize()`), as in SwiftUI.

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
