---
title: Backpressure setup
summary: Every automated check in this repository, where it runs, and the traps hit while wiring it up.
updated: 2026-10-18
---

# Backpressure setup

Why: [0004 Maximum backpressure](../decisions/0004-maximum-backpressure.md),
based on [Don't waste your back pressure](../sources/dont-waste-your-backpressure.md).

## The checks

| Check | Config | Runs in |
| --- | --- | --- |
| Swift 6 language mode, complete concurrency checking | tools-version 6.2 | every build |
| Upcoming features `ExistentialAny`, `InternalImportsByDefault`, `MemberImportVisibility`, `NonisolatedNonsendingByDefault`, `InferIsolatedConformances`, plus `strictMemorySafety()` | `strictSettings` in [Package.swift](../../Package.swift) | every build |
| All warnings are errors | `.treatAllWarnings(as: .error)` | same |
| Formatting (4 spaces, 120 cols, documented public API, no force unwraps/try) | [.swift-format](../../.swift-format) | `make lint`, pre-commit, Claude Code PostToolUse hook, CI |
| Semantic lint (opt-in rules, small functions/types/files) | [.swiftlint.yml](../../.swiftlint.yml), `--strict` | same |
| Tests + 90 % line coverage | [Scripts/check-coverage.py](../../Scripts/check-coverage.py) | `make check`, pre-push, CI |
| Wiki structure and privacy | [Scripts/wiki-lint.py](../../Scripts/wiki-lint.py) | `make lint`, pre-commit, CI |
| Conventional Commits header | [Scripts/check-commit-message.py](../../Scripts/check-commit-message.py) | commit-msg hook, CI PR-title job |
| Linux build + tests (`swift:6.2-noble`) | [ci.yml](../../.github/workflows/ci.yml), `make test-linux` | CI, pre-push when Docker is up |

`make check` = wiki lint + format lint + SwiftLint + build + tests + coverage.
Git hooks in [.githooks](../../.githooks/pre-commit) run lint on commit and
`make check` on push. On macOS the [pre-push hook](../../.githooks/pre-push) also runs
`make test-linux` when Docker is running; on Linux, `make check` is already
native and the Darwin-only paths are left to CI.

CI jobs: PR title check, lint (`macos-26`), macOS build + test + coverage, and
Linux build + test. Only macOS 15+ and Linux are supported, so there are no
other-platform build jobs ([decision 0004](../decisions/0004-maximum-backpressure.md)).

## Gotchas

- **Linux compiles code macOS never sees.** Terminal handling uses
  `canImport(Darwin)` / `canImport(Glibc)` branches (`termios` flag types,
  signal constants and `ioctl` differ). A green macOS build proves nothing
  about the Glibc paths, which is why the pre-push hook runs `make test-linux`.
- **swift-format vs SwiftLint on `case let`.** swift-format's
  `UseLetInEveryBoundCaseVariable` wants `case .x(let a)`; SwiftLint's
  `pattern_matching_keywords` wants `case let .x(a)`. The SwiftLint rule is
  disabled: swift-format owns layout, SwiftLint owns semantics.
- **`multilineTrailingCommaBehavior: alwaysUsed` is buggy** in the
  toolchain's swift-format (emits `],)` and then flags it), so we use
  `keptAsWritten`.
- **`NonisolatedNonsendingByDefault` changes closure types.** Closure
  parameters that must hop executors need `@concurrent @Sendable`.
- Timing-based compiler flags (`-warn-long-expression-type-checking`) were
  rejected: nondeterministic across machines.
- Terminal tests must not touch the real tty. Test through
  `TerminalOutput` and `Stipple.renderToString` so CI (no tty) behaves like a
  laptop. See [Testing](testing.md).
