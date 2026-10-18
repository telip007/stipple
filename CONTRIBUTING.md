# Contributing

Thanks for helping! Bug reports, missing endpoints, docs fixes and features
are all welcome.

## Setup

```sh
make bootstrap   # installs SwiftLint via Homebrew, enables .githooks
make check       # what CI runs: lint, build, tests, coverage
```

You need Swift 6.2+ (Xcode 26 or a Swift 6.2 toolchain on Linux) and
SwiftLint (Homebrew on macOS, the release binary on Linux).

Developing on **macOS**? Keep Docker running: the pre-push hook then also runs
the Linux tests (`make test-linux`). On **Linux**, `make check` already runs
natively; Apple-platform builds are verified by CI.

`make bootstrap` sets `git config core.hooksPath .githooks` for this repository
only. The pre-commit hook runs the linters and wiki checks; the pre-push hook
runs `make check`. If you use Claude Code, the committed hooks in
`.claude/settings.json` do the same automatically once you trust the folder,
and also lint each edited file. See `wiki/concepts/agent-workflow.md`.

## Making changes

- Read `AGENTS.md`. It applies to humans too, and is short.
- Generated code (`Sources/OpenRouterAPI/Generated/`) is never edited by
  hand. Change the generator config or the spec patch script, then run
  `make generate`.
- Add tests for behaviour changes. Coverage of the hand-written target must
  stay ≥ 90 %.
- Update the wiki (`wiki/`) when you change behaviour or make a decision, and
  append a line to `wiki/log.md`. Reviewers will ask for it.
- Public API changes: update `README.md` and `ReadmeExampleTests.swift`.
- Write commit messages and PR titles as
  [Conventional Commits](https://www.conventionalcommits.org/). PRs are
  squash-merged, so the **PR title** becomes the commit on `main` and decides
  the next version:

  | Title | Release |
  | --- | --- |
  | `fix(stream): handle empty deltas` | patch |
  | `feat(chat): add stop sequences` | minor |
  | `feat!: rename RetryPolicy.none` (or a `BREAKING CHANGE:` footer) | major (minor while on 0.x) |
  | `docs:`, `test:`, `ci:`, `refactor:`, `chore:` | no release |

  Don't edit `CHANGELOG.md`; it's generated.

## Pull requests

- Keep PRs focused, with a Conventional Commits title and a description of
  what and why.
- CI must be green (macOS, Apple platform builds, Linux, lint, generated code
  up to date).
- By contributing you agree that your contributions are licensed under the
  Apache License 2.0.

## Reporting bugs

Please include the Swift version, platform, the request (redact keys!) and the
error. For responses that fail to decode, a redacted response body helps most.
