# Run from the repository root via `make demos` (after `swift build -c release`).
# STIPPLE_BIN (absolute path) overrides the directory holding the example binaries.
Output .github/assets/demos/chat.gif
Output .github/assets/demos/chat.mp4

Set Shell "bash"
Set Theme "Catppuccin Frappe"
Set FontSize 18
Set Width 900
Set Height 520
Set Padding 24
Set Framerate 20
Set PlaybackSpeed 1
Set TypingSpeed 60ms
Set WindowBar Colorful
Set BorderRadius 8
Set Margin 0

Hide
Type 'export PS1="$ " PATH="${STIPPLE_BIN:-$PWD/.build/release}:$PATH"' Enter
Type "clear" Enter
Show
Sleep 600ms
Type "chat" Sleep 400ms Enter
Sleep 1s
Type "Hello from Stipple!" Sleep 400ms Enter
Sleep 800ms
Type "Inline rendering keeps history in scrollback." Sleep 400ms Enter
Sleep 800ms
# Paste: VHS pastes the host clipboard (the Makefile target fills it first).
Paste
Sleep 1s
Enter
Sleep 800ms
Type "Ctrl-C quits." Sleep 600ms
Screenshot .github/assets/demos/chat.png
Ctrl+C
Sleep 1500ms
