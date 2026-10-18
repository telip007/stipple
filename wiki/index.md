# Wiki index

Start here. Conventions: [SCHEMA.md](SCHEMA.md). Timeline: [log.md](log.md).

## Concepts

- [Architecture](concepts/architecture.md): the pipeline from a SwiftUI-style view tree to terminal bytes, the module boundaries and the contract each module implements.
- [Terminal](concepts/terminal.md): raw mode, crash-safe restore, signals, size, stdin reading and terminal mode switches.
- [Input](concepts/input.md): how stdin bytes become key presses, pastes, focus and mouse events, including the kitty keyboard protocol.
- [Rendering](concepts/rendering.md): text measurement, wrapping and truncation, ANSI parsing, the cell canvas, borders and SGR encoding.
- [Output](concepts/output.md): how frames reach the terminal: log-update, static output, alternate screen, non-interactive and debug modes.
- [View system](concepts/view-system.md): view, ViewBuilder, the view graph, state, environment, layout, modifiers, scrolling, mouse routing and the render loop.
- [Components](concepts/components.md): built-in controls made only from the public view API: TextField and SecureField, ProgressView and SelectionList.
- [Backpressure setup](concepts/backpressure-setup.md): every automated check in this repository, where it runs, and the traps hit while wiring it up.
- [Testing](concepts/testing.md): how tests are structured, testing terminal code without a tty, README example tests and the coverage gate.
- [Demos](concepts/demos.md): how the README GIFs, MP4s and screenshots are recorded with VHS from the examples, and how to re-record them.
- [Releasing](concepts/releasing.md): Conventional Commits, release-please release PRs, SemVer bumps and Dependabot updates.
- [Agent workflow](concepts/agent-workflow.md): how AGENTS.md, skills, hooks and the wiki make every agent session follow the same rules.

## Decisions

- [0001 SwiftUI-shaped API over Ink's runtime](decisions/0001-swiftui-shaped-api.md): port Ink's runtime behaviour faithfully, but expose a SwiftUI-style API (View, @ViewBuilder, modifiers, property wrappers) instead of React's.
- [0002 SwiftUI two-pass layout instead of Yoga](decisions/0002-two-pass-layout.md): layout follows SwiftUI (parent proposes, child chooses its size, parent places) with no flexbox concepts in the public API.
- [0003 Inline rendering by default, alternate screen opt-in](decisions/0003-inline-rendering-by-default.md): like Ink, frames render inline below the shell prompt and Static output goes to scrollback; the alternate screen is an option.
- [0004 Maximum backpressure](decisions/0004-maximum-backpressure.md): warnings are errors, strict lint, 90% coverage gate, hooks and CI so contributors and agents get fast, automated feedback.
- [0005 LLM-maintained wiki](decisions/0005-llm-wiki.md): project knowledge lives in wiki/, maintained by agents and enforced by hooks and lint.
- [0006 Apache 2.0 license](decisions/0006-apache-2-license.md): Apache 2.0 with an explicit patent grant; Ink is MIT, so Stipple credits it in README and NOTICE as a behavioural port.
- [0007 Conventional Commits and release-please](decisions/0007-conventional-commits-and-release-please.md): commit headers drive SemVer bumps and the changelog; release-please opens release PRs that tag and publish on merge.
- [0008 Scrolling and opt-in mouse input](decisions/0008-scrolling-and-mouse.md): ScrollView follows SwiftUI's API with sticky positions (an edge stays an edge), keys only near focus, and mouse reporting off by default.

## Sources

- [Ink](sources/ink.md): the upstream project Stipple ports (v8.0.0), and which upstream file maps to which Stipple module.
- [Don't waste your back pressure](sources/dont-waste-your-backpressure.md): Moss's essay on automated feedback as the lever for agent autonomy.
- [LLM wiki pattern](sources/llm-wiki-pattern.md): Karpathy's idea file for agent-maintained knowledge bases.
