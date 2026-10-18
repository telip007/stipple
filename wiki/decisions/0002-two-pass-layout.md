---
title: 0002 SwiftUI two-pass layout instead of Yoga
summary: Layout follows SwiftUI (parent proposes, child chooses its size, parent places) with no flexbox concepts in the public API.
updated: 2026-10-18
---

# 0002 SwiftUI two-pass layout instead of Yoga

## Context

Ink lays out with Yoga (flexbox). SwiftUI's public layout model is different:
stacks, frames, spacers and layout priority. Exposing flexbox would clash with
the SwiftUI-shaped API ([0001](0001-swiftui-shaped-api.md)).

## Decision

Implement SwiftUI's two-pass model: a parent proposes a size, the child
returns the size it wants, and the parent places it. Ink's `Box` features map onto stacks
and modifiers. No `flexGrow`, `justifyContent` or `flexDirection` in the public API.

## Consequences

- Some Ink layouts (e.g. `flexWrap`) need a dedicated layout container later.
- Ink's flex tests are not ported 1:1; equivalent SwiftUI-style layouts are tested.
