---
title: 0001 SwiftUI-shaped API over Ink's runtime
summary: Port Ink's runtime behaviour faithfully, but expose a SwiftUI-style API (View, @ViewBuilder, modifiers, property wrappers) instead of React's.
updated: 2026-10-18
---

# 0001 SwiftUI-shaped API over Ink's runtime

## Context

Ink is React for CLIs. Swift developers already know SwiftUI's vocabulary,
and Swift has no JSX, hooks or reconciler. A literal port would feel foreign.

## Decision

Port Ink's behaviour (inline rendering, `Static`, frame throttling, input
parsing, focus, alternate screen, non-interactive output) and translate its API
to SwiftUI idioms: `View` + `@ViewBuilder`, modifiers instead of props, property
wrappers instead of hooks, and environment values instead of contexts. The full
mapping is in [architecture](../concepts/architecture.md#ink--stipple-api-map).

## Consequences

- Ink's tests and examples serve as behavioural references, not API references.
- Where SwiftUI has a name for a concept, Stipple uses it, even when Ink's name differs.
