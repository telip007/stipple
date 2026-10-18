---
title: Output
summary: How frames reach the terminal: log-update, static output, alternate screen, non-interactive and debug modes.
updated: 2026-10-18
---

# Output

Port of Ink's frame writing: `log-update.ts`, `line-update.ts`,
`cursor-helpers.ts`, `write-synchronized.ts` and the frame logic in `ink.tsx`
(see [Ink](../sources/ink.md) for the upstream files). The module lives in
`Sources/Stipple/Output/`. Everything runs on the `@MainActor` and writes to
`any TerminalOutput` ([contract](architecture.md#output)). Throttling is not
here: the runtime decides how often to call the writer.

## Files

| File | Ink source | Role |
| --- | --- | --- |
| `FrameWriter.swift` | `ink.tsx`: `onRender`, `resized`, `clear`, `writeToStdout`, unmount | Public surface: `write`, `resized`, `setCursorPosition`, `writeAbove`, `clear`, `finish`, `staticChanged` |
| `FrameWriter+Frame.swift` | `renderFrame`, `renderInteractiveFrame`, screen-reader branch | Debug, non-interactive, screen-reader and interactive frame drawing, full clear, static output |
| `FrameWriterOptions.swift` | `render()` options | `alternateScreen`, `incremental`, `debug`, `interactive`, `showCursor` |
| `FullClear.swift` | `shouldClearTerminalForFrame` | Pure decision: diff in place or clear first |
| `LogUpdate.swift` | `log-update.ts` | Standard and incremental live-frame rewriting, cursor state |
| `LineUpdate.swift` | `line-update.ts` | Repaint one changed line from its first differing column |
| `CursorHelpers.swift` | `cursor-helpers.ts` | Cursor suffix, return-to-bottom, cursor-only and erase sequences |
| `Escape.swift` | `ansi-escapes` | Byte-identical sequence builders |

## How a frame is written

`FrameWriter.write(frame:height:staticOutput:)` picks one of three paths:

1. **Debug** (`debug: true`): append the accumulated `<Static>` output and the
   frame in full, every time. No erasing.
2. **Non-interactive** (`interactive` is false, or the output is not a
   terminal): write `<Static>` output as it arrives and keep the frame. `finish()`
   writes the last frame once, followed by a newline. No escape sequences.
3. **Interactive**: the frame is drawn in place by `LogUpdate`.
   - Unchanged frame, no static output, no pending cursor change: nothing is written.
   - Static output present: erase the live frame, write the static output, then draw the frame.
   - `FullClear` says so (overflowing frame, a frame leaving fullscreen, or a
     shrinking viewport under a fullscreen frame): erase the previous frame in
     one step (`ESC[1;1H ESC[J`, or walk up from the cursor), then draw.
   - Otherwise, `LogUpdate.render` erases the previous frame and rewrites it
     (standard), or rewrites only the changed rows (`incremental`).

Each write is wrapped in synchronized output (`ESC[?2026h`/`ESC[?2026l`) only
when the writer is interactive and the output is a terminal. Wrapping is also
skipped for a live write that changes nothing.

Frames taller than the viewport (`height >= rows`) have no trailing newline,
so the cursor stays on the last row. Shorter frames end with one.

### Screen-reader mode

`screenReader: true` (the runtime sets it from `RenderOptions.isScreenReaderEnabled`)
replaces the in-place diff with a whole-frame rewrite. It is Ink's
`isScreenReaderEnabled` branch. The order is debug, then non-interactive, then
screen reader, then interactive. In this mode:

- The frame is wrapped to the terminal width with `TextLayout.wrap` (hard
  breaks, spaces kept at the break). Each wrapped line is re-encoded with
  `ANSIText.encode`, so each line opens and closes its own styles.
- An unchanged frame with no static output writes nothing except the
  synchronized-update brackets. Ink does the same.
- Otherwise the previous frame is erased, `<Static>` output is written, the
  wrapped frame is written, and `LogUpdate` is synced with no cursor. The cursor
  is never shown or hidden.
- `writeAbove` redraws the wrapped frame without cursor placement.

### Console output while rendering

`writeAbove(_:)` is Ink's patched console and `useStdout().write`: erase the
frame, write the text, and redraw the last frame. Debug writes the text followed
by the static output and the last frame, as Ink does.

### Alternate screen

`alternateScreen: true` takes effect only when the writer is interactive and the
output is a terminal. Entering writes `ESC[?1049h` and hides the cursor. The
alternate screen has no scrollback, so a full clear replays every `<Static>`
line accumulated so far, ahead of the frame. `finish()` shows the cursor and
writes `ESC[?1049l`.

### Finish

`finish(finalFrame:)` (unmount) optionally draws a final frame first, with
`isUnmounting` set so `FullClear` can clear a fullscreen frame once. Then it
leaves the cursor below the frame (`LogUpdate.done`), shows the cursor, and
leaves the alternate screen. Non-interactive writers print their last frame
here. After `finish`, every call is a no-op.

## Escape sequences

Every sequence the module writes, with the `ansi-escapes` name and the
`Escape` member that builds it.

| Bytes | Meaning | Name here |
| --- | --- | --- |
| `ESC[?25l` | hide cursor | `hideCursor` |
| `ESC[?25h` | show cursor | `showCursor` |
| `ESC[?1049h` / `ESC[?1049l` | enter / exit alternate screen | `enterAlternateScreen` / `exitAlternateScreen` |
| `ESC[?2026h` / `ESC[?2026l` | begin / end synchronized update | `beginSynchronizedUpdate` / `endSynchronizedUpdate` |
| `ESC[nA` | cursor up n rows (`cursorUp()` is `ESC[1A`) | `cursorUp(_:)` |
| `ESC[nB` | cursor down n rows | `cursorDown(_:)` |
| `ESC[nD` / `ESC[nC` | cursor left / right (relative moves) | `cursorMove(x:y:)` |
| `ESC[nG` | cursor to column n-1 on the current row | `cursorTo(_:)` |
| `ESC[r;cH` | cursor to row r-1, column c-1 (`ESC[1;1H` is home) | `cursorTo(_:row:)` |
| `ESC[G` | cursor to column 0 (`cursorLeft`) | `cursorLeft` |
| `ESC[E` | cursor to column 0 of the next row (`cursorNextLine`) | `cursorNextLine` |
| `ESC[2K` | erase the whole line | `eraseLine` |
| `ESC[K` | erase from the cursor to the end of the line | `eraseEndLine` |
| `ESC[J` | erase from the cursor to the end of the screen | `eraseDown` |
| `ESC[1;1H ESC[J` | home, then erase down: the full clear | `homeAndEraseDown` |

`eraseLines(n)` writes `ESC[2K`, then `ESC[1A` between rows, and ends with
`ESC[G`. For `n == 0` it writes nothing.

## Gotchas

- **The cursor is hidden before the change check.** The first `render` writes
  `ESC[?25l` even when the text is unchanged, as Ink's `cli-cursor` does.
  Tests that count writes have to take that write into account.
- **`cursorUp()` is `ESC[1A`, not `ESC[A`.** Both mean one row, but the bytes
  differ, and the tests assert the `ansi-escapes` bytes.
- **Synchronized output brackets only changes.** `ESC[?2026h` is not written
  for a no-op write, so the terminal never has an open update without content.
- **`resized()` erases but does not draw.** It runs Ink's erase rules (width
  shrank, or height shrank with a cursor set). The caller must follow it with
  `write`, which redraws because the cleared frame is forgotten.
- **Lines are compared by grapheme cluster.** `lineUpdate` works on `Character`
  values. Ink compares UTF-16 code units. The two agree on the text the frame
  writer produces. They can differ for `\r\n`, which Swift counts as one
  `Character`. `splitLines` splits on the `\n` scalar only, so `\r\n` still
  splits as Ink does.
- **Column widths come from `TextMetrics`.** The line diff measures the
  unchanged prefix with `TextMetrics.width(of:)` (`Render/TextMetrics.swift`),
  the same measure the canvas uses. A second width function would let the diff
  and the canvas disagree about where the cursor is, so do not add one.
- **Windows console behaviour is not ported.** Ink clears every fullscreen frame
  on Windows (`isWindowsConsole`) because the console scrolls on the bottom-right
  write. Stipple targets macOS and Linux only, so that branch is absent.
- **Screen-reader frames are re-encoded.** The frame goes through
  `ANSIText.parse` and `encode`, so its escape bytes can differ from the input
  even when the text is the same. The wrapping is `TextLayout.wrap`'s, including
  its break rule: `"hello world"` at width 5 is `hello`, a line holding one
  space, and `world`.
- **Empty writes are skipped.** The module never calls `write("")`, so tests
  can assume every recorded write is non-empty.
- **Unmount needs the final frame passed in.** Ink's unmount renders once more
  with `isUnmounting` set. Here the runtime must call
  `finish(finalFrame:)` for that, because the writer does not render on its own.
- **Non-interactive output is written at finish.** Unlike Ink's `onRender`, the
  frame is not printed until `finish`. Only `<Static>` output is written earlier.

## Tests

`Tests/StippleTests/Output/` asserts exact bytes, following Ink's tests
(`log-update`, `line-update`, `cursor-helpers`, `static`, `clear-rerender`,
`alternate-screen`, `cursor-exit-position`). `RecordingOutput` is a
`TerminalOutput` that keeps every write, so a test can compare a whole
sequence of writes.
