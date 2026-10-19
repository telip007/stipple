---
title: Demos
summary: How the README GIFs, MP4s and screenshots are recorded with VHS from the examples, and how to re-record them.
updated: 2026-10-19
---

# Demos

The README shows the four examples (`counter`, `logs`, `chat`, `tasks`, see
[Examples](../../Examples)) as GIFs, MP4s and PNG stills; `logs` is also the
hero GIF. They are scripted
recordings, not hand-captured, so they can be regenerated whenever the
rendering changes.

## Recording

```sh
brew install vhs     # pulls in ttyd and ffmpeg
make demos
```

[`make demos`](../../Makefile) builds the examples in release mode, puts the
clipboard text for the paste demo on the macOS clipboard, and runs every tape in
[Scripts/demos](../../Scripts/demos/chat.tape) with `STIPPLE_BIN` pointing at the
release binaries. Each tape writes `<name>.gif`, `<name>.mp4` and
`<name>.png` (a `Screenshot`) to `.github/assets/demos/`.

| Tape | Shows |
| --- | --- |
| `counter.tape` | arrow keys changing state, `q` to exit |
| `logs.tape` | alternate screen: a `SelectionList` pick, Tab to the `ScrollView`, Page Up pauses following while lines arrive, Page Down resumes it, typing in the filter `TextField` |
| `chat.tape` | typing, Enter to send, a "thinking" spinner and a reply streamed word by word, a bracketed paste, Ctrl-C |
| `tasks.tape` | three jobs at a time with spinners and progress bars, `Static` scrollback, run to completion |

All tapes share one look (Catppuccin Frappe, 18 pt, a colourful window bar) and
use `Hide` for the `PATH` setup so the recordings start at the prompt. `logs`
uses 14 pt and 10 fps to stay within the size budget below.

## Why GIF and MP4

GitHub renders `<video>` inline only for files uploaded as attachments to an
issue or PR, not for files committed to the repository. The README therefore
embeds the GIF inline and links the MP4 as "Watch in higher quality". The GIFs
are small (tens to hundreds of kilobytes) because terminal frames are mostly
flat colour; keep each under 2-3 MB when changing frame rate or size. Scrolling
is the exception: every new row in a following scroll view changes the whole
pane, so `logs.gif` (about 2.6 MB) needs a slow stream (a line every 700 ms),
a smaller window and 10 fps. Re-encoding with a smaller palette saves little.

## Gotchas

- Tapes are not part of `make check`: recording needs a browser (via ttyd) and
  takes about a minute. Re-record when visuals change.
- `STIPPLE_BIN` must be an absolute path. Without it the tapes use
  `.build/release` of the current directory.
- `Paste` in VHS pastes the host clipboard, which is why `make demos` is macOS
  only (`pbcopy`).
- VHS writes `Screenshot` files asynchronously, so a still may show the state a
  moment after the line the tape put it on.
- VHS has no Home or End key; tapes scroll back to the bottom with
  repeated `PageDown`.
- xterm.js in the recorder sometimes shows a frame half drawn (it does not
  honour synchronized output), so a single extracted video frame can look
  torn or miss a keystroke. Check a contact sheet
  (`ffmpeg -i x.mp4 -vf "fps=1,scale=500:-1,tile=3x6" sheet.png`) before
  suspecting the app, and confirm in a pty.
- An example that exits early leaves the shell prompt in the recording and
  later keystrokes are executed by bash. Look at the PNG after re-recording.
