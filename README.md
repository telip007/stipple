# Stipple

SwiftUI for the terminal. A Swift port of [Ink](https://github.com/vadimdemedes/ink),
with the SwiftUI API you already know.

<p>
  <a href="https://github.com/telip007/stipple/actions/workflows/ci.yml"><img src="https://github.com/telip007/stipple/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/Swift-6.2+-F05138" alt="Swift 6.2+">
  <img src="https://img.shields.io/badge/platforms-macOS%20%7C%20Linux-lightgrey" alt="Platforms">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache%202.0-blue" alt="Apache 2.0"></a>
</p>

- **SwiftUI-shaped API:** `View`, `@ViewBuilder`, `VStack`/`HStack`, modifiers,
  `@State`, `@Environment`, `.onKeyPress`. No flexbox, no React.
- **Ink's runtime behaviour:** inline rendering below the shell prompt, `Static`
  scrollback, throttled frames, raw-mode input, focus with Tab, optional
  alternate screen, plain output in CI and pipes.
- **Never leaves your terminal broken:** raw mode, cursor and alternate screen
  are restored on exit, on error and on crash.
- **Swift 6, strict concurrency**, on macOS and Linux.

> [!NOTE]
> **Early development.** The API is taking shape and will change before 1.0.
> While on `0.x`, minor releases may contain breaking changes.

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/telip007/stipple.git", from: "0.1.0"), // x-release-please-version
],
targets: [
    .executableTarget(name: "MyTool", dependencies: [
        .product(name: "Stipple", package: "stipple"),
    ]),
]
```

Requires Swift 6.2+ and macOS 15 or Linux.

## Quick start

```swift
import Stipple

struct Counter: View {
    @State private var count = 0
    @Environment(\.exit) private var exit

    var body: some View {
        VStack(alignment: .leading) {
            Text("Count: \(count)").foregroundStyle(.green).bold()
            Text("↑ increment, q quit").dim()
        }
        .onKeyPress(.upArrow) {
            count += 1
            return .handled
        }
        .onKeyPress("q") {
            exit()
            return .handled
        }
    }
}

try await Stipple.run(Counter())
```

The examples in this README are compiled and run by
`Tests/StippleTests/ReadmeExampleTests.swift`, so they cannot drift from the API.

## Coming from Ink

| Ink | Stipple |
| --- | --- |
| `render(<App/>)` | `try await Stipple.run(App())` |
| `<Box flexDirection="column">` | `VStack`, `HStack`, `ZStack` |
| `<Text color="green" bold>` | `Text("…").foregroundStyle(.green).bold()` |
| `padding`, `borderStyle` | `.padding()`, `.border(.rounded)` |
| `<Static items={…}>` | `Static(items) { item in … }` |
| `useInput` | `.onKeyPress(_:action:)` |
| `useApp().exit` | `@Environment(\.exit)` |
| `useFocus` | `.focusable()`, `@FocusState`; Tab cycles |
| `useState` | `@State` |

The complete mapping is in the
[architecture page](wiki/concepts/architecture.md#ink--stipple-api-map).
Stipple ports Ink's behaviour, not its API.

## Coming from SwiftUI

Stipple mirrors SwiftUI's names and layout model, with these differences:

- **Cells, not points.** One unit is one terminal cell. Sizes, padding and
  spacing are whole numbers of columns and rows.
- **No gestures.** Input is the keyboard (`onKeyPress`, `onPaste`) and pasted
  text. Mouse input is not supported.
- **Focus moves with Tab and Shift-Tab.** `.focusable()` views join the cycle;
  `@FocusState` reads and sets it.
- **Inline by default.** The view renders below the shell prompt and leaves its
  last frame in scrollback. Use `RenderOptions.alternateScreen` for full-screen apps.
- **Text only.** Colours are ANSI, 256-colour or truecolor; borders are box-drawing
  characters. There are no images or custom drawing.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). In short: `make bootstrap`, then `make check`
before you push. Design notes, decisions and known gotchas live in the
[project wiki](wiki/index.md).

## License

[Apache 2.0](LICENSE). See [NOTICE](NOTICE) for third-party attribution.

## Acknowledgements

Stipple exists because of [Ink](https://github.com/vadimdemedes/ink) by
[Vadim Demedes](https://github.com/vadimdemedes) (MIT). Its rendering, input and
output behaviour is the reference this library ports. Stipple is an independent
project and is not affiliated with or endorsed by Ink or its authors.
