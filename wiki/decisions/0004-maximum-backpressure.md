---
title: 0004 Maximum backpressure
summary: Warnings are errors, strict lint, 90% coverage gate, hooks and CI so contributors and agents get fast, automated feedback.
updated: 2026-10-18
---

# 0004 Maximum backpressure

## Context

Feedback a tool can give is feedback a reviewer doesn't have to
([Don't waste your back pressure](../sources/dont-waste-your-backpressure.md)).
That matters doubly for an open-source project that receives contributions
from humans and agents, and for a library that controls a user's terminal,
where a subtle bug leaves the shell unusable.

## Decision

Turn every deterministic check to its strictest useful setting
([Backpressure setup](../concepts/backpressure-setup.md)). Checks are never
weakened to get a green build. Changing a rule needs maintainer agreement and
a decision record. Supported platforms are macOS 15+ and Linux, and CI covers
exactly those.

## Consequences

- Contributors get precise local feedback (`make check`) that matches CI.
- Nondeterministic checks (type-checking time limits) are excluded.
- swift-format owns layout, SwiftLint owns semantics. Conflicts are resolved
  in favour of swift-format.
- Linux is verified before every push when Docker is available, because the
  Glibc/termios paths compile nowhere else.
