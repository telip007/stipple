---
title: Components
summary: Built-in controls built only from Stipple's view API, starting with TextField and SecureField.
updated: 2026-10-18
---

# Components

Components are views built with the public view API, not with new runtime
hooks, so they show what an app can build. They live in
[`Sources/Stipple/Components/`](../../Sources/Stipple/Components/).

## TextField and SecureField

`TextField(_:text:)` is a single-line input, as SwiftUI's `TextField`
([TextField.swift](../../Sources/Stipple/Components/TextField.swift)).
`SecureField` is the same field with each character drawn as `*`.

- **Focus.** The field is focusable. Tab reaches it, and its key handling runs only while
  it has focus. `.focusable(_:autoFocus:)` makes it focus on mount, and
  `.focused(_:equals:)` or `.focused(_:)` ties focus to a `@FocusState`.
- **Submit.** `.onSubmit { }` is an environment value, as in SwiftUI. Return calls the
  nearest action. Without one, Return does nothing.
- **Editing.** Printable characters insert at the cursor. Backspace and Delete remove a
  grapheme. Left and Right move, and Home and End jump to the ends. Ctrl-A and Ctrl-E
  also jump to the ends, Ctrl-U and Ctrl-K delete to the start and end, and Ctrl-W
  and Option-Backspace delete a word. Option-Left and Option-Right move by word, and
  Command-Left and Command-Right by line. A paste inserts the whole text at once.
  The mapping lives in [TextFieldKeys.swift](../../Sources/Stipple/Components/TextFieldKeys.swift),
  and the edits in [TextEditing.swift](../../Sources/Stipple/Components/TextEditing.swift).
- **Cursor.** The insertion point is a grapheme index in the field's own `@State`. It is
  clamped into the text whenever the binding changes from outside. While focused, the
  character under the caret is drawn inverse, and `.cursorPosition` puts the terminal
  cursor there so input methods work. A field wider than its proposal scrolls to keep
  the caret visible. Wide characters count two columns.
- **Placeholder.** Dimmed while the text is empty. With focus, the caret sits on its first character.

### How it is built

`TextField` and `SecureField` are composite views. Their `body` returns
`EditableText`, which owns the cursor `@State` and turns key presses into edits of
the bound text. That returns `FieldCore`, a primitive with a `FieldLayout`
([EditableText.swift](../../Sources/Stipple/Components/EditableText.swift),
[FieldCore.swift](../../Sources/Stipple/Components/FieldCore.swift)). The primitive
puts the focus registration and key handler on its own node, so focus and keys
stay on the same node. The layout checks focus at placement and draw time. It sets
the cursor position at placement, and draws the caret at draw time. A focus change
therefore needs no rebuild.

## Gotchas

- **Put focus modifiers directly on the field.** `TextField`'s own `.focusable` and
  `.focused` overloads return `TextField`, so they reach the field's node. The generic
  `View` versions wrap the field instead, and the keys then land on the wrapper's child, which
  does not have focus. So `TextField(...).padding().focusable()` focuses the wrapper, and the field never gets key presses.
  Apply the focus modifiers first, then layout modifiers.
- **Read `@FocusState` in `body`.** Setting focus from a key handler moves focus only
  when the view that owns the `@FocusState` rebuilds, which happens when its `body` reads
  it. This is the same for `.focused` on any view, not specific to fields.
- **Pastes keep their newlines.** A field is single-line, but a paste is inserted as-is. A
  newline is stored in the text, and the field draws it as a character. Strip newlines in
  the caller if that matters.
- **Masking counts graphemes.** `SecureField` shows one `*` per grapheme cluster, so an
  emoji with a skin-tone modifier is one `*`, not two.

## Tests

[`Tests/StippleTests/Components/`](../../Tests/StippleTests/Components/) covers the
editing model, the key mapping, the window and scroll rules, and the runtime
behaviour: typing, submit, paste, focus through `.focusable` and `@FocusState`, the
cursor position, and external changes to the bound text.
