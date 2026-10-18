---
title: Architecture
summary: The pipeline from a SwiftUI-style view tree to terminal bytes, the module boundaries and the contract each module implements.
updated: 2026-10-18
---

# Architecture

Stipple is a Swift port of [Ink](../sources/ink.md) (React for CLIs, v8.0.0).
Ink's runtime behaviour, including inline rendering, `<Static>` scrollback,
throttled frames, raw-mode input and focus, is reproduced. Its *API* is
translated to SwiftUI idioms ([decision 0001](../decisions/0001-swiftui-shaped-api.md)).

## Pipeline

```text
View tree ──body──▶ ViewGraph (identity, @State storage, environment, Observation tracking)
          ──layout──▶ two-pass layout: proposal → size → placement      (Layout/)
          ──draw──▶ Canvas: grid of styled cells, clipping, borders      (Render/)
          ──encode──▶ frame string (ANSI) + static output string         (Render/)
          ──write──▶ FrameWriter: inline log-update or alternate screen  (Output/)
          ──bytes──▶ Terminal: raw mode, size, signals, stdin            (Terminal/)
stdin bytes ──▶ InputParser ──▶ InputEvent ──▶ key/paste/focus dispatch  (Input/ → Runtime/)
```

Everything that touches the view graph or the terminal runs on the
`@MainActor`. Parsers, text measurement and the canvas are plain value
types with no isolation, so they test without a terminal.

## Modules and contracts

Each directory under `Sources/Stipple/` has one owner and a contract. Types
shared across modules live in `Core/` and `Input/KeyPress.swift`: `Size`,
`Point`, `Rect`, `Color`, `Style`, `TextAttributes`, `StyledRun`,
`TerminalOutput`, `KeyPress`, `KeyEquivalent`, `EventModifiers` and `InputEvent`.

### Terminal/ ([page](terminal.md))

Port of Ink's stdin/stdout handling plus the crash safety Node gives Ink for free.

- `final class Terminal: TerminalOutput` (`@MainActor`) wraps stdin/stdout file
  descriptors: `size` (`TIOCGWINSZ`, then `COLUMNS`/`LINES`, then 80×24),
  `isTerminal`, unbuffered `write`.
- Raw mode via `termios` (`enableRawMode()` / `restore()`), idempotent.
- Crash-safe restore: `atexit`, plus handlers for `SIGTERM`, `SIGHUP`, `SIGQUIT`,
  `SIGABRT` (Swift traps), `SIGSEGV` and `SIGBUS`. Each handler restores the
  terminal using only async-signal-safe calls, then re-raises. `SIGTSTP`/`SIGCONT`
  (Ctrl-Z) leave raw mode and restore it.
- `events() -> AsyncStream<TerminalEvent>`, where
  `TerminalEvent = .input([UInt8]) | .resize(Size)`. Resize comes from `SIGWINCH`
  through a Dispatch signal source; stdin is read off the main thread.
- Mode switches that write escape sequences: alternate screen (`?1049`), cursor
  visibility (`?25`), bracketed paste (`?2004`), focus reporting (`?1004`), kitty
  keyboard push/pop/query (`CSI > flags u`, `CSI < u`, `CSI ? u`). Synchronized
  output (`?2026`) is handled by the frame writer.
- Environment detection: `isCI` (`CI`, `CONTINUOUS_INTEGRATION`, `BUILD_NUMBER`,
  `RUN_ID`, as `is-in-ci` does), and `isInteractive = isTerminal && !isCI`.
- Works on macOS (Darwin) and Linux (Glibc).

### Input/ ([page](input.md))

Port of `parse-keypress.ts`, `input-parser.ts` and `kitty-keyboard.ts`.

- `struct InputParser { mutating func parse(_ bytes: some Collection<UInt8>) -> [InputEvent] }`
  splits chunks into events. Sequences split across chunks are buffered. A lone
  ESC is held until `mutating func flushPendingEscape() -> [InputEvent]` is
  called after a short timeout (the runtime calls it 50 ms after the last byte,
  the delay Ink uses).
- Decodes legacy xterm/VT sequences (arrows, Home/End, F-keys, modifiers in
  `CSI 1;m X`), Ctrl-letter (`0x01…0x1A`), Option as an ESC prefix, Backspace
  `0x7F`/`0x08`, keypad Enter, bracketed paste (`ESC[200~ … ESC[201~` →
  `.paste`), focus in/out, kitty `CSI codepoint;mods:event u` with press, repeat
  and release, and the kitty query reply.
- UTF-8 multi-byte characters and grapheme clusters arrive as one `.character`.

### Render/ ([page](rendering.md))

Port of `output.ts`, `colorize.ts`, `render-border.ts`, `render-background.ts`,
`wrap-text.ts`, `measure-text.ts`, `ansi-tokenizer.ts` and `sanitize-ansi.ts`,
plus `string-width`, `wrap-ansi` and `cli-truncate` behaviour.

- `enum TextMetrics { static func width(of: some StringProtocol) -> Int }`
  measures display width per grapheme: East Asian wide and emoji count 2,
  combining marks and zero-width count 0.
- `enum TextLayout`: `wrap(_ runs: [StyledRun], width:) -> [[StyledRun]]` does
  word wrap with hard breaks for overlong words and keeps styles across
  breaks. `truncate(_:width:mode:)` handles `.head`, `.middle` and `.tail` with `…`.
  `lines(_:)` splits on `\n`.
- `enum ANSIText { static func parse(_ string: String) -> [StyledRun] }` turns
  SGR-styled input such as subprocess output into runs and drops cursor
  movement and other unsafe controls (Ink's `sanitize-ansi`).
- `struct Canvas`: a `width × height` grid of cells (grapheme, style, and a
  continuation flag for the second half of wide characters).
  `write(_ runs:at:clip:)` draws one line and clips to a `Rect`.
  `fill(_ rect:background:clip:)` paints background only.
  `drawBorder(_ border: BorderStyle, in:style:clip:)`.
  `encodedLines() -> [String]` returns ANSI lines with minimal SGR transitions
  and trailing default cells trimmed, as Ink trims.
- `public struct BorderStyle` with Ink's `cli-boxes` set: `.single`, `.double`,
  `.rounded`, `.heavy` (Ink's `bold`), `.singleDouble`, `.doubleSingle`,
  `.classic` and `.arrow`, plus a memberwise initializer for custom borders.
- Color encoding: truecolor SGR `38;2`/`48;2`; palette `38;5`; ANSI `30–37`/`90–97`.

### Output/ ([page](output.md))

Port of `log-update.ts`, `line-update.ts`, `cursor-helpers.ts`,
`write-synchronized.ts` and the frame logic in `ink.tsx`
(`renderInteractiveFrame`, static output, resize, unmount).

- `@MainActor final class LogUpdate` with standard and incremental variants:
  `render(_:) -> Bool`, `clear()`, `done()`, `reset()`, `sync(_:)` and
  `setCursorPosition(_:)`.
- `@MainActor final class FrameWriter(output: any TerminalOutput, options:)`
  with `write(frame:height:staticOutput:)`, `resized()`,
  `writeAbove(_ text:)` (Ink's patched console and `useStdout().write`: clear
  the frame, write the text, restore the frame), `clear()` and `finish()`
  (unmount: leave the last frame and the cursor below it). Its behaviours:
  - Fullscreen detection: when a frame is at least as tall as the viewport, it
    has no trailing newline.
  - Static output is written once, above the frame.
  - Alternate screen: enter and exit, and replay accumulated static output on
    a full clear.
  - Non-interactive mode (CI or pipe): no escape codes, and only the final
    frame plus static output is written.
  - Debug mode: every frame is appended in full.
  - Synchronized output wraps each write in `?2026h`/`?2026l` when interactive.

### Views/, Layout/, State/, Runtime/ ([page](view-system.md))

These modules are the SwiftUI-shaped core: `View`, `@ViewBuilder`, `ViewGraph`,
`@State`, `@Binding`, `@Environment`, `@FocusState`, `Observation` tracking,
the layout protocol and stacks, modifiers, `Static`, the render loop with
`maxFps` throttling, and `Stipple.run` / `Stipple.render` /
`Stipple.renderToString`.

## Ink → Stipple API map

| Ink | Stipple |
| --- | --- |
| `render(<App/>, options)` | `Stipple.render(App(), options:)` → `RenderHandle` (`waitUntilExit()`, `unmount()`, `clear()`); `try await Stipple.run(App())` |
| `renderToString` | `Stipple.renderToString(App(), width: 80)` |
| `<Box flexDirection="column">` | `VStack(alignment:spacing:)`, `HStack`, `ZStack` |
| `padding`, `margin` | `.padding(_:)`. A margin is padding outside a border or background. |
| `width`, `minWidth`, `flexGrow` | `.frame(width:height:)`, `.frame(minWidth:maxWidth: .infinity)`, `Spacer()`, `.layoutPriority(_:)` |
| `gap` | stack `spacing:` |
| `borderStyle`, `borderColor` | `.border(.rounded, color: .cyan)` |
| `backgroundColor` | `.background(.blue)` |
| `overflow="hidden"` | `.clipped()` |
| `position="absolute"` | `.overlay(alignment:) { }`, `.background(alignment:) { }`, `ZStack` |
| `<Text color bold …>` | `Text("…").foregroundStyle(.green).bold().italic().underline().strikethrough().dim().inverse()` |
| `wrap="truncate-end"` | `.lineLimit(1).truncationMode(.tail)` |
| `<Newline/>` | `"\n"` inside `Text` |
| `<Spacer/>` | `Spacer()` |
| `<Static items>` | `Static(items) { item in … }` |
| `<Transform>` | `.textTransform { line, index in … }` |
| `useInput` | `.onKeyPress(_:action:)` (global unless inside a `.focusable()` view) |
| `usePaste` | `.onPaste { text in … }` |
| `useApp().exit` | `@Environment(\.exit) var exit`, then `exit()` / `exit(throwing:)` |
| `useStdout().write` | `@Environment(\.terminal) var terminal`, then `terminal.write(_:)` (above the live area) |
| `useFocus`, `useFocusManager` | `.focusable()`, `@FocusState`, `.focused(_:equals:)`, `@Environment(\.focusManager)`; Tab and Shift-Tab cycle |
| `useWindowSize` | `@Environment(\.terminalSize)` |
| `useBoxMetrics`, `measureElement` | `GeometryReader`, `.onGeometryChange(for:of:action:)` |
| `useAnimation` | `TimelineView(.periodic(every:))` |
| `useCursor` | `.cursorPosition(_:)` |
| `useIsScreenReaderEnabled` | `@Environment(\.isScreenReaderEnabled)` (`STIPPLE_SCREEN_READER=true`) |
| `aria-label`, `aria-hidden`, `aria-role`, `aria-state` | `.accessibilityLabel(_:)`, `.accessibilityHidden()`, `.accessibilityRole(_:)`, `.accessibilityState(_:)` |
| `suspendTerminal` | `@Environment(\.suspendTerminal)`, then `try await suspendTerminal { … }` |
| `useEffect` | `.task { }`, `.onAppear`, `.onDisappear`, `.onChange(of:)` |
| `useState` / context | `@State`, `@Binding`, `@Observable` models, `.environment(_:)` |
| `kittyKeyboard` option | `RenderOptions.keyboardProtocol` |
| `alternateScreen` option | `RenderOptions.alternateScreen` |

## Gotchas

- In Ink, a Text `color` cascades into child Text only. Stipple's style
  modifiers cascade through the environment, as `foregroundStyle` does in SwiftUI.
