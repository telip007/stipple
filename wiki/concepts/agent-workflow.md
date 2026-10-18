---
title: Agent workflow
summary: How AGENTS.md, skills, hooks and the wiki make every agent session follow the same rules.
updated: 2026-10-18
---

# Agent workflow

Contributors increasingly work with coding agents. These mechanisms make an
agent session start from what the project knows and leave it knowing more.
Rationale: [0005 LLM-maintained wiki](../decisions/0005-llm-wiki.md).

## Layers

1. **[AGENTS.md](../../AGENTS.md)** is the portable contract for every agent
   (commands, rules, wiki duties). [CLAUDE.md](../../CLAUDE.md) imports it and
   adds Claude Code specifics.
2. **Skills** in `.claude/skills/`:
   [wiki](../../.claude/skills/wiki/SKILL.md) and
   [backpressure](../../.claude/skills/backpressure/SKILL.md).
3. **Claude Code hooks** in [.claude/settings.json](../../.claude/settings.json)
   (active once a contributor trusts the checkout):
   - `SessionStart` → [session-start.sh](../../Scripts/hooks/session-start.sh):
     sets the repository-local `core.hooksPath=.githooks` and loads the wiki
     index and recent log entries into context.
   - `PostToolUse` (Edit/Write) → [lint-edited-file.sh](../../Scripts/hooks/lint-edited-file.sh):
     swift-format and SwiftLint on the edited file, with violations fed back
     to the agent. Skips SwiftLint with a hint if it isn't installed.
   - `Stop` → [wiki-guard.sh](../../Scripts/hooks/wiki-guard.sh): blocks
     ending a turn when non-wiki files changed and `wiki/` didn't, once per
     distinct change set.
4. **Git hooks and CI** enforce lint, tests, commit headers and wiki structure
   for everyone ([Backpressure setup](backpressure-setup.md)).

## Gotchas

- The git pre-commit hook enforces wiki *structure*, not wiki *updates*.
  Requiring humans to edit the wiki on every commit would be friction.
  Agents are expected to keep it current, and reviewers check PRs for it.
- Agents other than Claude Code don't run these hooks. AGENTS.md states the
  same duties in plain text.
- Several agents may work in one checkout at once. Touch only the files of
  your module, and append to `wiki/log.md` rather than rewriting it.
