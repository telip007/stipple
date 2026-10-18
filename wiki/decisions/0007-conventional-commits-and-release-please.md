---
title: 0007 Conventional Commits and release-please
summary: Commit headers drive SemVer bumps and the changelog; release-please opens release PRs that tag and publish on merge.
updated: 2026-10-18
---

# 0007 Conventional Commits and release-please

## Context

A hand-curated changelog duplicates information already in commit messages,
and contributors forget it. [Conventional Commits](https://www.conventionalcommits.org/)
map directly onto [SemVer](https://semver.org/) (`fix` → patch, `feat` →
minor, `!` → major), so versions and release notes can be derived from
history instead of decided and written by hand. Consumers pin versions through
SwiftPM, which resolves semantic-version tags. The API is new, so breaking
changes are likely before 1.0.

## Decision

- SemVer starting at `0.1.0`. While on `0.x`, breaking changes bump the minor
  version. Plain tags (`0.1.0`, no `v`).
- Conventional Commits for every commit on `main`, enforced by a local
  `commit-msg` hook and a CI check on PR titles. Squash merges only, with the
  PR title as the commit message.
- [release-please](https://github.com/googleapis/release-please) (GitHub
  Action) maintains a release PR, generates `CHANGELOG.md`, and tags and
  publishes releases on merge.

## Consequences

- No manual changelog edits or version bumps. The PR title is the release
  note, so reviewers review titles.
- Releasing is merging a PR, which works from the GitHub UI without a local
  toolchain.
- PRs created by `GITHUB_TOKEN` need a manual CI trigger
  ([Releasing](../concepts/releasing.md#gotchas)).

Process details: [Releasing](../concepts/releasing.md).
