---
title: 0005 LLM-maintained wiki
summary: Project knowledge lives in wiki/, maintained by agents and enforced by hooks and lint.
updated: 2026-10-18
---

# 0005 LLM-maintained wiki

## Context

Why Ink's behaviour was ported one way and not another, which terminal quirk
forced a workaround, which escape sequence is deliberately not emitted: this
knowledge gets lost in PR threads and chat sessions.
[Karpathy's LLM-wiki pattern](../sources/llm-wiki-pattern.md) compiles it once
into interlinked markdown and keeps it current.

## Decision

Keep a wiki in `wiki/` following [SCHEMA.md](../SCHEMA.md), maintained by
agents as part of every change, with layered enforcement
([Agent workflow](../concepts/agent-workflow.md)).

## Consequences

- PRs that change behaviour also update the relevant wiki pages and the log.
  Reviewers check this.
- The index is the retrieval mechanism. If it outgrows a single file, add
  search and record that here.
- The wiki is public, so it never holds personal data or local paths
  (`make wiki-lint` enforces this).
