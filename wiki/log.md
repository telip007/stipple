# Wiki log

Append-only. Format: see [SCHEMA.md](SCHEMA.md#log-format).

## [2026-10-18] decision | Foundations
Recorded decisions 0001–0003: SwiftUI-shaped API over Ink's runtime, two-pass layout instead of Yoga, inline rendering by default.

## [2026-10-18] update | Scaffold and module contracts
Package, tooling copied from the backpressure setup, shared Core types, and the architecture page with one contract per module.

## [2026-10-18] update | Open-source and agent setup
README, NOTICE, CONTRIBUTING, SECURITY, CHANGELOG stub, CI and issue templates adapted for a terminal library; wiki pages for backpressure, agent workflow, testing and releasing; decisions 0004–0007 (backpressure, LLM wiki, Apache 2.0 with Ink attribution, Conventional Commits).

## [2026-10-18] update | Input module
InputParser decodes stdin bytes into key, paste and focus events, with legacy, rxvt and kitty sequences and buffering across chunks. Ink deviations and gotchas are on the Input page.

## [2026-10-18] update | Output module
Ported log-update (standard and incremental), line-update, cursor-helpers, the frame logic from ink.tsx (debug, non-interactive, interactive, full clear, static output, alternate screen, writeAbove, resize, finish) into `Sources/Stipple/Output/`, with 67 byte-exact tests in `Tests/StippleTests/Output/`. Output page written with the escape table and gotchas.

## [2026-10-18] update | Render module
Text metrics, wrapping, truncation, ANSI tokenizer and parser, SGR encoder, cell canvas with wide-character-safe clipping, fill and borders, `BorderStyle`; ported Ink's measure-text, sanitize-ansi, ansi-tokenizer, clip/overlap wide background and combining-mark tests.

## [2026-10-18] update | View system, runtime and examples
View/ViewBuilder, retained view graph with Observation tracking, @State/@Binding/@Environment/@FocusState, two-pass layout (stacks, spacer, frame, padding, border, background, clip, offset), Text, Static, GeometryReader, TimelineView, key/paste/focus dispatch, throttled runtime and three examples verified end to end in a pty.

## [2026-10-18] update | View-layer tests and fixes
View-layer tests raised coverage from 84.7% to 96.9%. They exposed three bugs, now fixed: a final frame that missed state changed just before exit (synchronous invalidation queue), text with no minimum width, and flexible frames that ignored their ideal size.

## [2026-10-18] update | Screen reader, overlays, text transform, suspend
Added accessibility modifiers and screen reader rendering, `.overlay`/`.background` with views, `.textTransform` (Ink's `Transform`) and `@Environment(\.suspendTerminal)`.

## [2026-10-18] update | Output uses TextMetrics for widths
Removed `Output/DisplayWidth.swift`; the line diff measures columns with `TextMetrics.width(of:)` from `Render/`, so there is one width function. Output tests now check that measure directly.

## [2026-10-18] update | Output screen-reader mode
Added `FrameWriterOptions.screenReader`: whole-frame rewrite, wrapped to the terminal width with `TextLayout.wrap`, cursor never shown or hidden. Ported from the `isScreenReaderEnabled` branches of `ink.tsx`. Byte-exact tests in `ScreenReaderTests.swift`.

## [2026-10-18] update | Divider, hidden, disabled; Linux green
Added `Divider`, `.hidden()` and `.disabled(_:)` (handlers and focus respect `isEnabled`). The full suite passes on Linux (swift:6.2-noble) after fixing name-shadowing and import differences between Swift 6.2 and 6.4.
