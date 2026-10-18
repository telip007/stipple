# Contributing

Thanks for helping! Bug reports, missing Ink behaviour, docs fixes and features
are all welcome.

## Setup

```sh
make bootstrap   # installs SwiftLint via Homebrew, enables .githooks
make check       # what CI runs: lint, build, tests, coverage
```

You need Swift 6.2+ (Xcode 26 or a Swift 6.2 toolchain on Linux) and
SwiftLint (Homebrew on macOS, the release binary on Linux). Stipple supports
macOS 15+ and Linux only.

Developing on **macOS**? Keep Docker running: the pre-push hook then also runs
the Linux tests (`make test-linux`), which compile the Glibc/termios code paths
macOS never sees. On **Linux**, `make check` already runs natively; the
Darwin code paths are verified by CI.

`make bootstrap` sets `git config core.hooksPath .githooks` for this repository
only. The pre-commit hook runs the linters and wiki checks; the pre-push hook
runs `make check`. If you use Claude Code, the committed hooks in
`.claude/settings.json` do the same automatically once you trust the folder,
and also lint each edited file. See `wiki/concepts/agent-workflow.md`.

## Making changes

- Read `AGENTS.md`. It applies to humans too, and is short.
- Ink is the behavioural reference. When fixing or adding behaviour, check
  what Ink does (`wiki/sources/ink.md` maps upstream files to modules) and keep
  the public API SwiftUI-shaped: no flexbox or web concepts.
- Never leave the user's terminal broken: raw mode, cursor and the alternate
  screen must be restored on exit, on error and on crash.
- Add tests for behaviour changes. Coverage of the hand-written target must
  stay ≥ 90 %.
- Update the wiki (`wiki/`) when you change behaviour or make a decision, and
  append a line to `wiki/log.md`. Reviewers will ask for it.
- Public API changes: update `README.md` and `Tests/StippleTests/ReadmeExampleTests.swift`.
- Write commit messages and PR titles as
  [Conventional Commits](https://www.conventionalcommits.org/). PRs are
  squash-merged, so the **PR title** becomes the commit on `main` and decides
  the next version:

  | Title | Release |
  | --- | --- |
  | `fix(input): handle split escape sequences` | patch |
  | `feat(layout): add layoutPriority` | minor |
  | `feat!: rename RenderOptions.debug` (or a `BREAKING CHANGE:` footer) | major (minor while on 0.x) |
  | `docs:`, `test:`, `ci:`, `refactor:`, `chore:` | no release |

  Don't edit `CHANGELOG.md`; it's generated.
- Changed how an example looks? Re-record the README demos with `make demos`
  (needs [VHS](https://github.com/charmbracelet/vhs), macOS) and commit the
  files in `.github/assets/demos/`. See `wiki/concepts/demos.md`.

## Pull requests

- Keep PRs focused, with a Conventional Commits title and a description of
  what and why.
- CI must be green (lint, macOS, Linux).
- By contributing you agree that your contributions are licensed under the
  Apache License 2.0.

## Reporting bugs

Please include the Swift version, OS, terminal emulator and `TERM`, a minimal
view that reproduces the problem, and what you expected. For rendering
problems, the output of `Stipple.renderToString` is the most useful thing to
paste. If Ink behaves differently, say how.
