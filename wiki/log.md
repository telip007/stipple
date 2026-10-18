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

## [2026-10-18] update | README demos and README example tests
Scripted VHS tapes for the counter, tasks and chat examples record GIF, MP4 and PNG into `.github/assets/demos/` (`make demos`); README gets a hero GIF and an Examples section; `ReadmeExampleTests` compiles and renders the README's Swift snippet.

## [2026-10-18] update | Ink parity fixes from the QA suite
Merged about 190 parity tests ported from Ink. Fixed: Static output in renderToString, re-truncation when drawing, word wrapping next to spacers (stacks now offer the ideal length), the stretch idiom (placement at the final cross size), and per-line truncation and hard wrapping via `.textWrapping(_:)`.

## [2026-10-18] update | Terminal module
Raw mode, mode tracking, event stream (stdin reader thread, SIGWINCH, SIGCONT), suspend, and crash-safe restore through precomputed records and async-signal-safe handlers. Verified end to end: a `fatalError` inside a pty leaves the terminal cooked, echoing and with the cursor shown.

## [2026-10-18] update | TextField and SecureField
Single-line text inputs built from the public view API: focus through `.focusable` and `@FocusState`, `.onSubmit`, readline-style editing, a caret that is inverse and drives `.cursorPosition`, and masked secure entry. Gotchas on the Components page.

## [2026-10-18] update | Components: ProgressView and SelectionList
Added `ProgressView` (spinner with `ProgressViewStyle` presets dots, line and arc, and a determinate bar that fills its offered width) and `SelectionList` (focusable, keyboard-driven, scrolls with `visibleRows`), with tests in `Tests/StippleTests/Components/`.

## [2026-10-18] update | Components, examples and demos
Merged TextField/SecureField, ProgressView and SelectionList. Setting `@FocusState` now moves focus even when no body reads it. renderToString repeats layout until geometry settles, and SelectionList honours `.onSubmit`. The chat and tasks examples use the components, and the demos were re-recorded (`make demos` builds each product separately).

## [2026-10-18] update | Poll instead of sleeping in timing tests
The first push was blocked by a flaky Linux test under load. Timer-based tests now poll with `Runtime.waitUntil`.

## [2026-10-18] update | Published on GitHub
Pushed to github.com/telip007/stipple, and CI passes on macOS, Linux and lint. Allowed Actions to open PRs for release-please, and pinned the first release to 0.1.0.

## [2026-10-18] update | Color depth
`Color` promised approximation but SGR always wrote `38;2`. Added `ColorDepth` (detection ported from `supports-color`, downsampling from `ansi-styles`), `RenderOptions.colorDepth` (nil detects), `Terminal.colorDepth`, and a `colorDepth:` parameter on `renderToString` and `Canvas.encodedLines` (default truecolor). Deviations are listed on the Rendering page.

## [2026-10-18] update | Ctrl-D on an empty TextField
Ctrl-D still deletes forward, but on an empty field it is `.ignored`, so ancestor `.onKeyPress` handlers see it and apps can treat it as end-of-file, as readline does. Documented on the Components page and in the `TextField` doc comment.

## [2026-10-18] update | TextField caret after outside changes
Clearing a field's text from outside (e.g. in `onSubmit`) left the stale insertion point, so the caret showed on the placeholder's 4th character. The field now tracks the text of its own last edit and moves the insertion point to the end after any outside change; the placeholder caret is always on its first character.

## [2026-10-18] update | ScrollView and mouse wheel
Added `ScrollView`, `ScrollPosition`, `.scrollPosition`, `.defaultScrollAnchor(_:for:)`, `.scrollIndicators`, `.scrollOnPageKeys`, `.id`, `UnitPoint` and `Axis.Set` ([decision 0008](decisions/0008-scrolling-and-mouse.md)). Scroll views take keys near focus as a separate dispatch stage. `RenderOptions.mouseReporting` turns on `?1000`/`?1006`; the parser decodes SGR and X10 reports, the wheel scrolls the scroll view under the pointer, and `.onTapGesture` handles clicks on the alternate screen.

## [2026-10-18] update | Clicks, focus on click and hover
Under `RenderOptions.mouseReporting` on the alternate screen: a left press focuses the focusable view under the pointer, `SelectionList` rows select on click and submit on double-click, and `.onHover` reports the pointer through motion reports (`?1003`), which are on only while a hover handler exists. Tap and hover handlers no longer add a layout; hit-testing walks up from the innermost node.
