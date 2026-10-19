---
title: Rendering
summary: Text measurement, wrapping and truncation, ANSI parsing, the cell canvas, borders, SGR encoding and color depth.
updated: 2026-10-19
---

# Rendering

The `Render/` module turns styled text into terminal cells and cells into
ANSI lines. It is plain value types with no isolation and no terminal access,
so every part is tested directly ([contract](architecture.md),
upstream mapping in [Ink](../sources/ink.md)). Code: [`Sources/Stipple/Render/`](../../Sources/Stipple/Render/).

## Pieces

| Type | File | Ink / npm equivalent |
| --- | --- | --- |
| `TextMetrics` | [`TextMetrics.swift`](../../Sources/Stipple/Render/TextMetrics.swift), [`EastAsianWidth.swift`](../../Sources/Stipple/Render/EastAsianWidth.swift) | `string-width`, `widest-line`, `measure-text.ts` |
| `TextLayout`, `TruncationMode` | [`TextLayout.swift`](../../Sources/Stipple/Render/TextLayout.swift), [`StyledGrapheme.swift`](../../Sources/Stipple/Render/StyledGrapheme.swift) | `wrap-ansi`, `cli-truncate`, `wrap-text.ts` |
| `ANSITokenizer`, `ANSIText` | [`ANSITokenizer.swift`](../../Sources/Stipple/Render/ANSITokenizer.swift), [`ANSIText.swift`](../../Sources/Stipple/Render/ANSIText.swift) | `ansi-tokenizer.ts`, `sanitize-ansi.ts` |
| `SGR` | [`SGR.swift`](../../Sources/Stipple/Render/SGR.swift) | `colorize.ts`, `ansi-styles` |
| `ColorDepth` | [`Core/ColorDepth.swift`](../../Sources/Stipple/Core/ColorDepth.swift) | `supports-color`, `ansi-styles`' `rgbToAnsi256` and `ansi256ToAnsi` |
| `Canvas` | [`Canvas.swift`](../../Sources/Stipple/Render/Canvas.swift) and `Canvas+*.swift` | `output.ts`, `render-background.ts`, `render-border.ts` |
| `BorderStyle` | [`BorderStyle.swift`](../../Sources/Stipple/Render/BorderStyle.swift) | `cli-boxes` |

## API

`TextMetrics`, `TruncationMode`, `ColorDepth` and `BorderStyle` (with `Edges` and `Colors`)
are public. The rest is internal because it works on `StyledRun`.

```swift
TextMetrics.width(of: some StringProtocol) -> Int
TextMetrics.width(of: Character) -> Int
TextMetrics.measure(_ text: String) -> Size              // widest line x line count; "" is 0x0
TextMetrics.measure(_ runs: [StyledRun]) -> Size

TextLayout.lines(_ runs: [StyledRun]) -> [[StyledRun]]   // split on "\n"; never empty
TextLayout.wrap(_ runs: [StyledRun], width: Int) -> [[StyledRun]]
TextLayout.truncate(_ runs: [StyledRun], width: Int, mode: TruncationMode) -> [StyledRun]  // one line

ANSIText.parse(_ string: String) -> [StyledRun]
ANSIText.encode(_ runs: [StyledRun]) -> String

Canvas(width:height:)
canvas.write(_ runs: [StyledRun], at: Point, clip: Rect? = nil)
canvas.fill(_ rect: Rect, background: Color, clip: Rect? = nil)
canvas.paint(_ rect: Rect, background: Color, clip: Rect? = nil)
canvas.drawBorder(_ border: BorderStyle, in: Rect, edges: BorderStyle.Edges = .all, style: Style, clip: Rect? = nil)
canvas.drawBorder(_ border: BorderStyle, in: Rect, edges: BorderStyle.Edges = .all, colors: BorderStyle.Colors, clip: Rect? = nil)
canvas.encodedLines(colorDepth: ColorDepth = .trueColor) -> [String]

ColorDepth.detect(environment: [String: String], isTerminal: Bool) -> ColorDepth  // .monochrome, .ansi16, .ansi256, .trueColor
canvas.plainLines() -> [String]
canvas.cell(x:y:) -> Canvas.Cell?      // grapheme, style, isContinuation
```

## How it works

**Width.** `TextMetrics.width` has an ASCII fast path over UTF-8. Anything else
is measured per grapheme cluster (Swift's `Character`): the first printing
scalar decides. Wide and fullwidth East Asian characters (range table in
`EastAsianWidth.swift`) and emoji (`isEmojiPresentation`, a text emoji plus
`U+FE0F`, a regional-indicator pair) are 2. Controls, marks, format and
default-ignorable characters are 0, so a cluster that only holds those is 0.
Halfwidth and fullwidth forms that join a cluster add their own width.

**Wrapping.** `TextLayout.wrap` ports `wrap-ansi` with `hard: true, trim:
false`, the way Ink calls it. Text is split into graphemes that carry their
style, wrapped by display width, and regrouped into runs, so styles survive
breaks. Zero-width marks join the grapheme before them first.

**Truncation.** Works on columns. A wide character that would straddle the cut
is dropped, so the result never exceeds `width`. The `…` takes the style of
the character next to it (`cli-truncate` leaves it unstyled).

**ANSI parsing.** `ANSITokenizer` is a direct port of Ink's tokenizer.
`ANSIText.parse` keeps SGR and OSC 8 and drops everything else. A malformed
sequence drops the rest of the string.

**Canvas.** Cells hold a `Character`, an interned style id and a continuation
flag. Styles are interned per canvas so cells stay small and comparing styles
while encoding is an integer compare. `encodedLines` switches styles with the
shortest SGR parameters, caches transitions per style pair, closes the style
and any hyperlink at the end of each row and trims trailing unstyled spaces.

### Color depth

Cells keep the colors as written; `encodedLines(colorDepth:)` reduces every
interned style before encoding, the way chalk picks a color level per stream.
RGB becomes the nearest xterm-256 entry (grey ramp for greys, else the 6×6×6
cube, ansi-styles' `rgbToAnsi256`); a 256-color entry becomes the nearest of
the 16 ANSI colors (`ansi256ToAnsi`); `.monochrome` drops colors and keeps
attributes and links. The runtime takes `RenderOptions.colorDepth`, else
`Terminal.colorDepth`, which runs `ColorDepth.detect` over the terminal's
environment and whether stdout is a tty. `renderToString` takes a
`colorDepth:` that defaults to `.trueColor`, so its output is stable.

`detect` follows `supports-color` (v10): `FORCE_COLOR`, Azure Pipelines,
non-tty → none, `TERM=dumb`, CI vendors, TeamCity, `COLORTERM=truecolor`,
kitty/Ghostty/WezTerm, `TERM_PROGRAM` (iTerm 3+ truecolor, older iTerm and
Apple Terminal 256), `TERM` ending in `-256(color)`, then color-ish `TERM`
names or any `COLORTERM` (16). The tests use upstream's expected values.

## Gotchas

- **Width is per grapheme, not per scalar.** `"e\u{301}"` is one cell. `"👩‍💻"`
  is one cluster of width 2. A lone regional indicator is 1, a pair is 2.
- **Tabs and other controls are 0 wide** and draw nothing (as in Ink).
  Expand tabs before layout if you want them.
- **Variation selectors can change width.** `"❤"` is 1, `"❤\u{FE0F}"` is 2. When
  a selector arrives in a later run, `Canvas.write` widens the cell, and
  `TextLayout` merges marks into the previous grapheme before measuring.
  Terminals disagree on some emoji, so keep `U+FE0F` in the text.
- **A wide character cut by a clip, a write or a fill edge never leaves half
  a glyph.** The cell that is left becomes a space with its own style, so
  backgrounds survive. The tests port Ink's `clip-wide-background` and
  `overlap-wide-background`.
- **`fill` keeps characters; `paint` covers them.** `fill` only sets the
  background. `paint` writes background-colored spaces, as Ink's
  `renderBackground` does, and is what `.background(_ color:)` uses, so a
  colored background is opaque: an overlay box with one hides the text under
  it, also where its own content is blank. (Before 0.5.1 `.background` used
  `fill`, and text under an overlay showed through its blank cells.)
- **Hidden border sides drop their corners**, as in Ink: with the left side
  hidden the top row starts with the top edge character. A 1-row box draws the
  bottom border over the top one.
- **Trailing styled cells are kept.** Only unstyled spaces are trimmed, so a
  background that reaches the right edge is not lost. A space that only has a
  foreground color is kept too (Ink does the same).
- **`wrap` with `trim: false` leaves spaces at breaks**: `"hello world"` at
  width 5 is `hello`, one line holding a single space, and `world`; at width
  10 it is `"hello "` and `"world"`. This is what Ink shows.
- **`wrap` with width ≤ 0 returns the lines unwrapped.** Ink does the same,
  because wrapping into zero columns would make one line per character.
- **Wide character in a one-column line** overflows instead of producing an
  empty line before it (a small deviation from `wrap-ansi`).
- **SGR output is combined**: `\e[1;31m` instead of Ink's `\e[31m\e[1m`.
  Clearing bold also clears dim (SGR 22), so the encoder re-enables the one
  that stays.
- **Unsupported SGR parts** (underline colors `58`, blink, hidden, malformed
  color forms) are dropped by the parser; underline styles `4:n` become a plain
  underline.
- **Color depth deviations from `supports-color`.** `NO_COLOR` (non-empty)
  turns color off unless `FORCE_COLOR` is set; `supports-color` ignores it,
  Node's `getColorDepth` honours it. `COLORTERM=24bit` counts as truecolor too.
  The `--color`/`--no-color` argv flags are not read (arguments belong to the
  app), and there is no Windows branch.
- **A tty with no `TERM` gets no color**, as in `supports-color`: detection
  falls through to the minimum. Set `RenderOptions.colorDepth` to override.
- **Monochrome keeps attributes.** chalk at level 0 drops all styling; Stipple
  still writes bold, inverse and the rest, because carets and selections are
  drawn with inverse.
- **The East Asian Width table is hand-written** from Unicode 16 data for W and F
  characters. Emoji presentation comes from the standard library, so new
  emoji follow the toolchain's Unicode version.
