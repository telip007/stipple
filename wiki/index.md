# Wiki index

Start here. Conventions: [SCHEMA.md](SCHEMA.md). Timeline: [log.md](log.md).

## Concepts

- [Architecture](concepts/architecture.md): the pipeline from a SwiftUI-style view tree to terminal bytes, the module boundaries and the contract each module implements.
- [Terminal](concepts/terminal.md): raw mode, crash-safe restore, signals, size, stdin reading and terminal mode switches.
- [Input](concepts/input.md): how stdin bytes become key presses, pastes and focus events, including the kitty keyboard protocol.
- [Rendering](concepts/rendering.md): text measurement, wrapping and truncation, ANSI parsing, the cell canvas, borders and SGR encoding.
- [Output](concepts/output.md): how frames reach the terminal: log-update, static output, alternate screen, non-interactive and debug modes.
- [View system](concepts/view-system.md): view, ViewBuilder, the view graph, state, environment, layout, modifiers and the render loop.
- [Backpressure setup](concepts/backpressure-setup.md): every automated check in this repository, where it runs, and the traps hit while wiring it up.
- [Agent workflow](concepts/agent-workflow.md): how AGENTS.md, skills, hooks and the wiki make every agent session follow the same rules.

## Decisions

- [0001 SwiftUI-shaped API over Ink's runtime](decisions/0001-swiftui-shaped-api.md): port Ink's runtime behaviour faithfully, but expose a SwiftUI-style API (View, @ViewBuilder, modifiers, property wrappers) instead of React's.
- [0002 SwiftUI two-pass layout instead of Yoga](decisions/0002-two-pass-layout.md): layout follows SwiftUI (parent proposes, child chooses its size, parent places) with no flexbox concepts in the public API.
- [0003 Inline rendering by default, alternate screen opt-in](decisions/0003-inline-rendering-by-default.md): like Ink, frames render inline below the shell prompt and Static output goes to scrollback; the alternate screen is an option.
- [0004 Maximum backpressure](decisions/0004-maximum-backpressure.md): warnings are errors, strict lint, 90% coverage gate, hooks and CI.

## Sources

- [Ink](sources/ink.md): the upstream project Stipple ports (v8.0.0), and which upstream file maps to which Stipple module.
- [Don't waste your back pressure](sources/dont-waste-your-backpressure.md): Moss's essay on automated feedback as the lever for agent autonomy.
- [LLM wiki pattern](sources/llm-wiki-pattern.md): Karpathy's idea file for agent-maintained knowledge bases.
