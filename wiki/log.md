# Wiki log

Append-only. Format: see [SCHEMA.md](SCHEMA.md#log-format).

## [2026-10-18] decision | Foundations
Recorded decisions 0001–0003: SwiftUI-shaped API over Ink's runtime, two-pass layout instead of Yoga, inline rendering by default.

## [2026-10-18] update | Scaffold and module contracts
Package, tooling copied from the backpressure setup, shared Core types, and the architecture page with one contract per module.

## [2026-10-18] update | Open-source and agent setup
README, NOTICE, CONTRIBUTING, SECURITY, CHANGELOG stub, CI and issue templates adapted for a terminal library; wiki pages for backpressure, agent workflow, testing and releasing; decisions 0004–0007 (backpressure, LLM wiki, Apache 2.0 with Ink attribution, Conventional Commits).

## [2026-10-18] update | Output module
Ported log-update (standard and incremental), line-update, cursor-helpers, the frame logic from ink.tsx (debug, non-interactive, interactive, full clear, static output, alternate screen, writeAbove, resize, finish) into `Sources/Stipple/Output/`, with 67 byte-exact tests in `Tests/StippleTests/Output/`. Output page written with the escape table and gotchas.
