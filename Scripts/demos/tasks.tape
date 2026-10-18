# Run from the repository root via `make demos` (after `swift build -c release`).
# STIPPLE_BIN (absolute path) overrides the directory holding the example binaries.
Output .github/assets/demos/tasks.gif
Output .github/assets/demos/tasks.mp4

Set Shell "bash"
Set Theme "Catppuccin Frappe"
Set FontSize 18
Set Width 760
Set Height 440
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
Type "tasks" Sleep 400ms Enter
Sleep 2s
Screenshot .github/assets/demos/tasks.png
Sleep 2s
Sleep 2500ms
