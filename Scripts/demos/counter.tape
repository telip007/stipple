# Run from the repository root via `make demos` (after `swift build -c release`).
# STIPPLE_BIN (absolute path) overrides the directory holding the example binaries.
Output .github/assets/demos/counter.gif
Output .github/assets/demos/counter.mp4

Set Shell "bash"
Set Theme "Catppuccin Frappe"
Set FontSize 18
Set Width 760
Set Height 300
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
Type "counter" Sleep 400ms Enter
Sleep 1s
Set TypingSpeed 0
Up Sleep 350ms
Up Sleep 350ms
Up Sleep 350ms
Up Sleep 350ms
Down Sleep 500ms
Up Sleep 350ms
Up Sleep 1s
Screenshot .github/assets/demos/counter.png
Type "q"
Sleep 1500ms
