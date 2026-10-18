---
title: Input
summary: How stdin bytes become key presses, pastes, focus and mouse events, including the kitty keyboard protocol.
updated: 2026-10-18
---

# Input

`InputParser` turns the bytes read from stdin into `InputEvent` values. It is a
plain value type with no terminal access, so it is tested with byte literals.
The public key types are in [`KeyPress.swift`](../../Sources/Stipple/Input/KeyPress.swift).
The decoder is a port of Ink's `parse-keypress.ts`, `input-parser.ts` and
`kitty-keyboard.ts` (see [ink](../sources/ink.md)).

## How it works

- `InputParser.parse(_:)` takes one chunk and returns the events it completes.
  Anything incomplete is kept for the next chunk: a partial escape sequence, a
  partial UTF-8 character, an unfinished bracketed paste. An empty chunk changes
  nothing.
- A lone ESC is held, because it may start a sequence. The runtime checks
  `hasPendingInput` after each read and, when it is true, calls
  `flushPendingEscape()` 50 ms after the last byte. That emits `.escape`. `ESC ESC`
  flushes as Option-Escape. The bytes after the ESC are then decoded as ordinary
  input, so a flushed `ESC [` becomes Escape followed by `[`.
- `hasPendingInput` is false inside a bracketed paste, and false for exactly
  `ESC [ 2 0 0`. That prefix may still become a paste marker, so it waits for the
  next byte.
- Inside a paste, every byte is kept verbatim until `ESC [ 2 0 1 ~` arrives, even
  when the paste spans chunks. The result is one `.paste(String)`.
- Printable text is decoded as a run and split into graphemes. Each grapheme is
  one key press, so fast typing in one chunk yields one event per character.

Decoder layout: [`InputParser.swift`](../../Sources/Stipple/Input/InputParser.swift)
(buffering and paste), [`InputDecoder.swift`](../../Sources/Stipple/Input/InputDecoder.swift)
(tokens, text, control bytes), [`InputDecoder+Escape.swift`](../../Sources/Stipple/Input/InputDecoder+Escape.swift)
(ESC, CSI, SS3), [`LegacyKeys.swift`](../../Sources/Stipple/Input/LegacyKeys.swift)
(xterm, VT and rxvt tables) and [`KittyKeys.swift`](../../Sources/Stipple/Input/KittyKeys.swift)
(kitty `CSI … u`, and the modifier and event parameters).

## Byte to event

| Input bytes | Event |
| --- | --- |
| `a` | `.character("a")`, characters `"a"` |
| `A` | `.character("a")`, characters `"A"`, `[.shift]` (Ink's `input` and `shift`) |
| `é`, `👍🏽` | one `.character` per grapheme |
| `0x00` | `.character(" ")`, `[.control]` (Ctrl+Space) |
| `0x01`–`0x1A` | `.character(letter)`, `[.control]`, except `0x08`, `0x09`, `0x0A` and `0x0D`, which are listed below |
| `0x1C`–`0x1F` | `.character` `\` `]` `^` `_`, `[.control]` |
| `0x08`, `0x7F` | `.backspace` |
| `0x09` | `.tab`, characters `"\t"` |
| `0x0D` | `.return`, characters `"\r"` |
| `0x0A` | `.return`, characters `"\n"` |
| `0x1B` alone, after the flush | `.escape` |
| `0x1B` + character or control byte | the same key with `[.option]` (`ESC x`, `ESC ^A`, `ESC ⏎`, `ESC DEL`) |
| `0x1B 0x1B` | `.escape` with `[.option]` (after the flush) |
| `ESC [ A`–`D`, `ESC O A`–`D` | `.upArrow`, `.downArrow`, `.rightArrow`, `.leftArrow` |
| `ESC [ H`/`F`, `ESC O H`/`F`, `ESC [ 1~`/`7~`, `ESC [ 4~`/`8~` | `.home` and `.end` |
| `ESC [ 2~` / `3~` / `5~` / `6~` | `.insert` / `.delete` / `.pageUp` / `.pageDown` |
| `ESC O P`–`S`, `ESC [ 11~`–`15~`, `17~`–`21~`, `23~`, `24~` | `.function(1)` to `.function(12)` |
| `ESC [ [ A`–`E`, `ESC [ [ 5~`/`6~` | Linux console F1–F5, PageUp, PageDown |
| `ESC [ Z` | `.tab` with `[.shift]` |
| `ESC O M` | `.return`, characters `"\r"` (keypad Enter) |
| `ESC [ 1 ; m X`, `ESC [ n ; m ~`, `ESC O 1 ; m X` | the key with the modifiers in `m` |
| `ESC [ a`–`d`, `ESC [ 2$`–`8$` | rxvt Shift keys |
| `ESC O a`–`d`, `ESC [ 2^`–`8^` | rxvt Ctrl keys |
| `ESC [ 200~` … `ESC [ 201~` | `.paste(String)` |
| `ESC [ I` / `ESC [ O` | `.focus(true)` / `.focus(false)` |
| `ESC [ ? flags u` | `.kittyKeyboardSupported(flags:)` |
| `ESC [ < b ; x ; y M` / `… m` | `.mouse`: SGR press / release, wheel when `b` has bit 64 (`64` up, `65` down, `66`/`67` left/right), movement with bit 32; Shift 4, Option 8, Control 16; `x`, `y` from 1 become a zero-based `Point` |
| `ESC [ M b x y` (3 raw bytes, each + 32) | `.mouse`: the older X10 encoding, for terminals without `?1006`; release doesn't say which button |
| `ESC [ code u` | the key for the codepoint (see below) |
| `ESC [ code ; mods:event u` | the same, with modifiers and phase |
| `ESC [ 1 ; mods:event A`–`D`, `ESC [ n ; mods:event ~` | functional keys with a phase |
| unmapped CSI, SS3 or `?` sequence | no event (dropped) |

### Modifier parameter

The `m` value is `1 + bitmask`, as in the kitty protocol. The same decoding
applies to legacy and kitty sequences.

| Bit | Value | Modifier |
| --- | --- | --- |
| 1 | 2 | `.shift` |
| 2 | 3 | `.option` (Alt) |
| 4 | 5 | `.control` |
| 8 | 9 | `.command` (Super) |
| 16 | 17 | `.hyper` |
| 32 | 33 | `.option` (Meta) |
| 64 | 65 | `.capsLock` |
| 128 | 129 | `.numLock` |

The `:event` part is 1 for press, 2 for repeat and 3 for release. It maps to
`KeyPress.Phase` `.down`, `.repeat` and `.up`. Legacy sequences always report
`.down`.

### Kitty codepoints

- Keys with a fixed name: Tab (9), Return (13 and keypad Enter 57414), Escape
  (27), Space (32), Backspace (127), the arrows, Home, End, Insert, Delete,
  PageUp and PageDown (57417–57426), and F13–F35 (57376–57398) as
  `.function(13)` to `.function(35)`.
- Keypad digits (57399–57408) and `. / * - + = ,` (57409–57416) are ordinary
  characters.
- Other printable codepoints are a `.character` in lowercase. The modifiers come
  only from the modifier field, never from the text. Text in the third field
  replaces `characters`.
- Modifier keys, lock keys, media keys, KP_Begin and reserved codes produce no
  event.

## Gotchas

- **Mouse reports are internal.** `MouseEvent` ([MouseEvent.swift](../../Sources/Stipple/Input/MouseEvent.swift))
  is not public; apps see the wheel through `ScrollView` and clicks through
  `.onTapGesture`. Extra buttons (codes from 128) and malformed reports are
  dropped. An SGR report split across reads waits like any CSI.
- **`ESC [ M` always starts an X10 report**, whether or not mouse reporting is
  on, and swallows the next three bytes. No key sends a bare `CSI M`.

- **No implicit Shift from kitty text.** With Caps Lock on, kitty can report `A`
  without Shift. The key is then `.character("a")` with no `.shift`, as Ink does.
- **Uppercase letters need no kitty protocol.** A legacy `A` is `.character("a")`
  with `[.shift]`, so `.onKeyPress("a")` matches it, as in Ink. Non-ASCII
  uppercase letters also get Shift. Ink only does this for A to Z.
- **Legacy modifier 9 is Command here.** Ink reads bit 8 of a legacy modifier as
  Meta. This port reports it as `.command`, the kitty meaning. A legacy terminal
  that sends modifier 9 will show up as Command.
- **Return and Tab keep their names.** Ink reports `\n` as `enter` (not Return)
  and a Tab key with an empty `input`. Here the text is `"\t"` and `"\r"`, so
  Return and Tab carry their characters.
- **Ctrl+C is an ordinary key.** The parser emits `.character("c")` with
  `[.control]` and never exits. The runtime decides whether Ctrl+C exits, as Ink's
  `exitOnCtrlC` does, and it should ignore `.up` events for that check.
- **Release events arrive only with kitty `reportEventTypes`.** Filter on
  `phase == .up` if a handler should ignore releases. Modifier-only events are
  dropped, so a Shift release shows up only as the modifiers of the next key.
- **`CSI R` is F3.** Ink maps it too. Cursor position reports (`CSI row ; col R`)
  therefore arrive as F3 if the runtime ever asks for one. Stipple does not.
- **Partial `ESC [ 200` waits.** A timeout never flushes it, so a paste marker
  that arrives in pieces is not cut short. A typed `ESC [ 2` followed by a pause
  flushes as Escape, then the text `[2`.
- **Invalid UTF-8** decodes to U+FFFD. An incomplete character at the end of a
  chunk waits for the next chunk.
- **An ESC before an invalid CSI byte** is the Escape key, and the bytes after it
  are decoded as text, so `ESC [` followed by a control byte gives Escape, `[`
  and the control key.
- **Unknown sequences are dropped, not typed.** `ESC [ 9 9 ~` and `ESC [ 2 0 1 ~`
  outside a paste produce no event, never text.
- **Bracketed paste needs the runtime to enable `?2004`.** Without it the terminal
  sends the text as keys, and `\r` inside it becomes a Return key press.

## Tests

[`Tests/StippleTests/Input/`](../../Tests/StippleTests/Input/) covers the byte table
above (mouse reports in `MouseInputTests`), buffering across chunks, paste spanning chunks, invalid UTF-8, and the
kitty codepoint and modifier rules. The tests are the parsing assertions from
Ink's `parse-keypress`, `input-parser`, `kitty-keyboard` and `use-input` tests,
restated for this API.
