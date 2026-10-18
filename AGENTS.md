# AGENTS.md

Instructions for coding agents (and humans) working on Stipple.

## What this is

Stipple is a SwiftUI-shaped library for terminal UIs, a port of
[Ink](https://github.com/vadimdemedes/ink) (React for CLIs). It keeps Ink's
runtime behaviour, such as inline rendering, `Static` scrollback and raw-mode
input, and exposes a SwiftUI-style API. Single target, `Sources/Stipple/`, with
one directory per module; the module contracts are in
`wiki/concepts/architecture.md`.

## Before you start

1. Read `wiki/index.md` and the pages relevant to your task, at minimum
   `wiki/concepts/architecture.md`.
2. Ink is the behavioural reference. Port its behaviour, not its API
   (`wiki/sources/ink.md` says which upstream file maps to which module).
3. Apple/Swift docs: the DocC JSON behind a page
   (`https://developer.apple.com/tutorials/data/documentation/<path>.json`) or
   a Markdown converter such as sosumi.ai. Mirror SwiftUI names and shapes
   where a SwiftUI equivalent exists.

## Commands

| Command | What |
| --- | --- |
| `make bootstrap` | install SwiftLint (Homebrew), enable git hooks |
| `make fix` | auto-format |
| `make check` | wiki lint + swift-format + SwiftLint + build + tests + 90% coverage |
| `make test-linux` | tests in a `swift:6.2-noble` container (runs in pre-push when Docker is up) |

## Rules

- `make check` must pass before you call work done. Quote the result.
- Never weaken a check (no lint disables, no lowering coverage, no
  `@preconcurrency`/`nonisolated(unsafe)`/`try!` to silence the compiler).
  If a rule seems wrong, ask a maintainer and record a decision in
  `wiki/decisions/`.
- **No web or flexbox concepts in the public API** (no `flexGrow`,
  `justifyContent`, `flexDirection`). Layout is SwiftUI's two-pass model.
- **Never leave the user's terminal broken**: raw mode, hidden cursor and the
  alternate screen are restored on exit, on error and on crash.
- Public API needs doc comments and tests. Never name a static member `none`
  (it collides with `Optional.none`).
- Keep `README.md` and `Tests/StippleTests/ReadmeExampleTests.swift` in sync.
- Commit messages and PR titles follow [Conventional Commits](https://www.conventionalcommits.org/)
  (`feat(layout): …`, `fix: …`, `feat!: …` for breaking changes; checked by
  the `commit-msg` hook and CI). They drive versions and the changelog via
  release-please, so **never edit `CHANGELOG.md` or version strings by hand**.
- Platform-conditional code (`canImport(Darwin)` / `canImport(Glibc)`) must keep
  Linux working. CI builds and tests on macOS and Linux.
- Public repository: never put personal data, local paths, machine details
  or references to unrelated projects in code, docs, wiki or commit messages.

## Wiki duties

After any change to code, configuration, tooling or decisions:

1. Update the affected pages in `wiki/` and bump their `updated:` date.
2. Add a decision record for new decisions, and gotchas to the relevant page.
3. Append `## [YYYY-MM-DD] update | <what>` to `wiki/log.md`.
4. `make wiki-lint`.

Conventions: `wiki/SCHEMA.md`. Workflow: `.claude/skills/wiki/SKILL.md`.
