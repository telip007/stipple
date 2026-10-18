---
title: Testing
summary: How the tests are structured, how to test terminal code without a tty, README example tests and the coverage gate.
updated: 2026-10-18
---

# Testing

All tests use Swift Testing and run without a terminal or network access.
Tests live in `Tests/StippleTests/`, one file per module area, mirroring
`Sources/Stipple/`.

## Principles

- **Pure value types first.** The input parser, text measurement, the canvas and
  the encoder have no isolation and no I/O, so they are tested with bytes and
  strings in, strings out ([Architecture](architecture.md)).
- **Never touch the real tty.** Code that writes takes a `TerminalOutput`; tests
  pass a recording fake and assert the exact bytes. Whole views are checked with
  `Stipple.renderToString`.
- **Ink is the oracle.** For ported behaviour, the scenarios of Ink's own tests
  are re-created against Stipple's SwiftUI-style API ([Ink](../sources/ink.md)).
  Flexbox-specific tests are replaced by equivalent stack and frame layouts
  ([decision 0002](../decisions/0002-two-pass-layout.md)).
- **README examples are tests.** The code samples in the README are compiled and
  run by `Tests/StippleTests/ReadmeExampleTests.swift`, so documentation cannot
  drift from the API. Change one, change the other. The recorded demos
  are separate ([Demos](demos.md)).

## Coverage

`make coverage` enforces 90 % line coverage of `Sources/Stipple` via
[Scripts/check-coverage.py](../../Scripts/check-coverage.py). See
[Backpressure setup](backpressure-setup.md).

## Linux

`make test-linux` runs the suite in a `swift:6.2-noble` container with a named
volume for build artefacts. CI runs the same on Linux.

## Gotchas

- CI has no tty and sets `CI`, so interactive code paths must be reachable
  through injected dependencies, not by detecting the environment inside the test.
- Signal and raw-mode restore logic can't be asserted by a normal in-process
  test; exercise the restore function directly and keep the signal handlers
  minimal and async-signal-safe ([Architecture](architecture.md)).
- The first Linux run is slow (toolchain image and build); later runs reuse the
  cached volume.
