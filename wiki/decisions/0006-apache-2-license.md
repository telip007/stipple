---
title: 0006 Apache 2.0 license
summary: Apache 2.0 with an explicit patent grant; Ink is MIT, so Stipple credits it in README and NOTICE as a behavioural port.
updated: 2026-10-18
---

# 0006 Apache 2.0 license

## Context

Stipple has no runtime dependencies. Users range from hobby tools to commercial
CLIs. [Ink](../sources/ink.md), the project it ports, is MIT licensed
(Copyright Vadim Demedes).

## Decision

License Stipple under Apache 2.0 ([LICENSE](../../LICENSE)), the common choice
for Swift packages, with an explicit patent grant. Stipple re-implements Ink's
observable behaviour behind a different, SwiftUI-shaped API and is not a
translation of its source. Even so, the MIT notice is preserved in
[NOTICE](../../NOTICE) and Ink is credited in the README's acknowledgements.

## Consequences

- Contributions are accepted under the same license (Apache 2.0 §5). No CLA.
- Any code that is copied or closely derived from Ink must keep Ink's notice;
  the NOTICE file already carries it. Prefer re-implementing from behaviour.
- Stipple is independent and not affiliated with or endorsed by Ink's authors.
