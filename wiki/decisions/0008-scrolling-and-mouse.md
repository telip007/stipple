---
title: 0008 Scrolling and opt-in mouse input
summary: ScrollView follows SwiftUI's API with sticky positions (an edge stays an edge), keys only near focus, and mouse reporting off by default.
updated: 2026-10-18
---

# 0008 Scrolling and opt-in mouse input

## Context

Full-screen apps (a transcript next to a side panel, as in modern coding
agents) need a scrolling pane. Ink has none: its apps scroll by pushing
output into the terminal's scrollback with `Static`, which doesn't work on
the alternate screen. SwiftUI has `ScrollView`, `ScrollPosition`,
`defaultScrollAnchor(_:for:)` and `scrollIndicators(_:)`, and modern TUIs
support the mouse wheel. Mouse reporting has a cost: while it is on, the
terminal sends drags to the app, so text selection needs a modifier key.

## Decision

- **SwiftUI's names and shapes**: `ScrollView(_ axes:content:)`,
  `ScrollPosition` with `init(edge:)`, `init(y:)`, `init(id:)`,
  `scrollTo(edge:)`, `scrollTo(y:)`, `scrollTo(id:)`, `edge`, `y`, `viewID`,
  `isPositionedByUser`, plus `scrollBy(lines:)` (not in SwiftUI);
  `defaultScrollAnchor(_:)` and `defaultScrollAnchor(_:for:)` with
  `ScrollAnchorRole`; `scrollIndicators(_:axes:)`; `UnitPoint`; `Axis.Set`;
  `.id(_:)`; `.onTapGesture(count:perform:)`. Units are rows. Only vertical
  scrolling is implemented.
- **Positions are sticky.** A position is re-applied on every layout: an edge
  stays at that edge as content changes, a row stays at the top, an id stays
  in view. User scrolling writes back an edge when the view rests against
  one, else a row. Reaching the bottom therefore pins again, which is the
  chat behaviour, for every scroll view (like `less +F` at the end of a
  file). SwiftUI's `scrollTo(edge:)` is one-shot instead.
- **Keys only near focus.** A scroll view takes ↑/↓, Page Up/Down and
  Home/End when focus is in it or on the focusable view around it, after
  the focused view's own handlers. `.scrollOnPageKeys()` opts into Page
  Up/Down from anywhere, after global handlers. A text field elsewhere keeps
  its arrows.
- **Mouse reporting is opt-in** (`RenderOptions.mouseReporting`, default off),
  uses `?1000` with SGR `?1006` only (no drag or motion reports), and is a
  `TerminalModes` member, so restore, crash recovery and Ctrl-Z undo it.
- **Real mouse control behind the same option**: a left press focuses the
  focusable view under the pointer, `.onTapGesture(count:perform:)` handles
  clicks and double-clicks (innermost handler per count wins),
  `.onHover(perform:)` handles the pointer, and `SelectionList` rows select on
  click and submit on double-click. Motion reports (`?1003`) are only on while
  a hover handler exists.
- **Hit-testing only on the alternate screen**, where the frame starts at row
  0. Inline frames don't know their screen row, so the wheel goes to the
  scroll view around focus or the innermost one, and clicks and hover are off.

## Consequences

- Chat apps need one modifier, `.defaultScrollAnchor(.bottom)`, and can read
  `position.edge == .bottom` to show a "jump to latest" hint.
- An app that wants a one-shot jump to the bottom of a log without following
  it must set a row (`scrollTo(y:)`) instead of an edge.
- With mouse reporting on, users select text with Shift (Option in some macOS
  terminals) held. The README and `RenderOptions` say so.
- The whole content is laid out and walked every frame; drawing outside the
  viewport is clipped but not skipped. Very long transcripts may need
  windowing later.
