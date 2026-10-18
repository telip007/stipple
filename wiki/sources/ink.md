---
title: Ink
summary: The upstream project Stipple ports (v8.0.0), and which upstream file maps to which Stipple module.
updated: 2026-10-18
---

# Ink

[Ink](https://github.com/vadimdemedes/ink) (MIT) provides React components for
CLIs. Stipple ports its behaviour from v8.0.0 ([decision 0001](../decisions/0001-swiftui-shaped-api.md)).

| Upstream (`src/`) | Stipple module |
| --- | --- |
| `ink.tsx`, `render.ts`, `instances.ts` | `Runtime/`, `Output/` (frame logic) |
| `log-update.ts`, `line-update.ts`, `cursor-helpers.ts`, `write-synchronized.ts` | `Output/` |
| `output.ts`, `renderer.ts`, `render-node-to-output.ts`, `render-border.ts`, `render-background.ts`, `colorize.ts` | `Render/` |
| `wrap-text.ts`, `measure-text.ts`, `squash-text-nodes.ts`, `ansi-tokenizer.ts`, `sanitize-ansi.ts`, `get-max-width.ts` | `Render/` |
| `parse-keypress.ts`, `input-parser.ts`, `kitty-keyboard.ts` | `Input/` |
| `reconciler.ts`, `dom.ts` | `Views/`, `State/` (view graph) |
| Yoga | `Layout/` (two-pass, [decision 0002](../decisions/0002-two-pass-layout.md)) |
| `components/App.tsx` (stdin, raw mode, focus) | `Runtime/`, `Terminal/` |
| `components/*`, `hooks/*` | `Views/` (see the [API map](../concepts/architecture.md#ink--stipple-api-map)) |

npm dependencies that Stipple reimplements: `string-width`, `wrap-ansi`,
`cli-truncate`, `cli-boxes`, `ansi-styles`, `ansi-escapes`, `is-in-ci` and
`signal-exit`.
