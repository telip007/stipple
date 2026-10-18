---
title: 0003 Inline rendering by default, alternate screen opt-in
summary: Like Ink, frames render inline below the shell prompt and Static output goes to scrollback; the alternate screen is an option.
updated: 2026-10-18
---

# 0003 Inline rendering by default, alternate screen opt-in

## Context

REPLs and agent CLIs want their history in the terminal's normal scrollback.
Full-screen apps (vim, htop) want the alternate screen.

## Decision

Follow Ink. The live region is redrawn in place (log-update), `Static` content is
written once above it and scrolls away naturally, and `RenderOptions.alternateScreen`
switches to the alternate screen.

## Consequences

- The frame writer ports Ink's log-update, including the incremental mode and the
  fullscreen-height edge cases.
