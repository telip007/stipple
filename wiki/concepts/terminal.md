---
title: Terminal
summary: Raw mode, crash-safe restore, signals, size, stdin reading and terminal mode switches.
updated: 2026-10-18
---

# Terminal

`Sources/Stipple/Terminal/` owns the file descriptors. It replaces what Node
gives Ink for free (`process.stdin.setRawMode`, `stdout.columns`, the `resize`
event, `signal-exit`) and adds the crash safety that Swift needs on top.

## Pieces

| File | What |
| --- | --- |
| [Terminal.swift](../../Sources/Stipple/Terminal/Terminal.swift) | `public final class Terminal: TerminalOutput` (`@MainActor`): size (`TIOCGWINSZ`, then `COLUMNS`/`LINES`, then 80×24), `isTerminal`, `isInputTerminal`, `isCI`, `isInteractive`, unbuffered `write`, raw mode and the mode switches |
| [TTY.swift](../../Sources/Stipple/Terminal/TTY.swift) | Thin `termios`/`ioctl`/`write(2)` wrappers. Raw mode is `cfmakeraw` with `ONLCR` kept, so `\n` still returns the carriage |
| [TerminalModes.swift](../../Sources/Stipple/Terminal/TerminalModes.swift) | Tracks which modes are on (alternate screen, hidden cursor, bracketed paste, focus reporting, mouse reporting, kitty flag stack) and builds the exact sequence that undoes them |
| [Terminal+Events.swift](../../Sources/Stipple/Terminal/Terminal+Events.swift) | `events() -> AsyncStream<TerminalEvent>`: `.input([UInt8])` from a reader thread, `.resize(Size)` from a Dispatch `SIGWINCH` source, and a redraw after `SIGCONT` |
| [InputReader.swift](../../Sources/Stipple/Terminal/InputReader.swift) | A blocking `read(2)` loop off the main thread, stopped through a self-pipe |
| [Terminal+Suspend.swift](../../Sources/Stipple/Terminal/Terminal+Suspend.swift) | `suspend(_:)` hands the terminal to other code (modes off, cooked mode) and reclaims it afterwards. `suspendProcess()` does the same around `SIGTSTP` for Ctrl-Z |
| [CrashRestore.swift](../../Sources/Stipple/Terminal/CrashRestore.swift) | Signal handlers and `atexit` |
| [KittyKeyboardFlags.swift](../../Sources/Stipple/Terminal/KittyKeyboardFlags.swift) | The kitty progressive-enhancement flags |

The runtime talks to the terminal through `TerminalHost`
([Terminal+Host.swift](../../Sources/Stipple/Runtime/Terminal+Host.swift)), so
runtime tests use a fake. `Terminal` itself is tested against real
pseudo-terminals (`Tests/StippleTests/Terminal/PTY.swift`).

## Crash safety

Swift traps (`fatalError`, force-unwrapping nil, out-of-bounds) end in
`SIGTRAP` or `SIGILL` on arm64 and `SIGABRT` elsewhere. None of them runs
`atexit`, so without a handler the shell would be left in raw mode with no
echo and a hidden cursor.

- Each live `Terminal` publishes a precomputed `RestoreRecord`: the
  descriptors, the `termios` from before raw mode and the bytes that undo the
  active modes. Each mode switch rebuilds and republishes the record.
- The records are listed in an immutable snapshot published through an
  `Atomic<UInt>`. A signal handler reads it with plain loads, calls only
  `tcsetattr` and `write`, restores the previous disposition and re-raises.
  Old records are retired, not freed, so a handler never reads freed memory.
- Covered signals: `SIGTERM`, `SIGHUP`, `SIGQUIT`, `SIGINT` (stdin not in raw
  mode), `SIGABRT`, `SIGSEGV`, `SIGBUS`, `SIGILL`, `SIGTRAP`, `SIGFPE`. The
  handlers run on an alternate signal stack, so a stack overflow can still
  restore the terminal.
- **Verified end to end** (2026-10-18): an app that calls `fatalError` inside a
  pty ended by signal 5 (`SIGTRAP`). Afterwards the pty had `ICANON` and `ECHO`
  set again, and the output ended with `ESC[?2004l ESC[?25h`.

## Gotchas

- **Mouse reporting is opt-in and steals text selection.** `setMouseReporting(true)`
  writes `?1000h?1006h` (button and wheel reports, SGR encoding) and restore
  writes `?1006l?1000l` before the screen modes, so crash recovery, Ctrl-Z and
  `suspend(_:)` undo it like every other mode. While it is on, a plain drag
  goes to the app; users hold Shift (Option in some macOS terminals) to select
  text. That is why `RenderOptions.mouseReporting` defaults to off. Only
  `?1000` is used: no drag (`?1002`) or motion (`?1003`) reports, so the
  terminal doesn't flood stdin.

- The frame writer, not `Terminal`, switches the alternate screen and hides the
  cursor. The runtime reports those modes with `noteModes(alternateScreen:cursorHidden:)`
  so crash restore undoes them too, without writing the sequences twice.
- With `.strictMemorySafety()`, every `termios`/`sigaction`/pointer expression
  needs `unsafe`, and `RestoreRecord` is `@unsafe`.
- `isInteractive` excludes CI the way `is-in-ci` does (`CI`,
  `CONTINUOUS_INTEGRATION`, `BUILD_NUMBER`, `RUN_ID`). Output to a pipe or in CI
  gets plain frames.
