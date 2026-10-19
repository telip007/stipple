# Run from the repository root via `make demos` (after `swift build -c release`).
# STIPPLE_BIN (absolute path) overrides the directory holding the example binaries.
Output .github/assets/demos/chat.gif
Output .github/assets/demos/chat.mp4

Set Shell "bash"
Set Theme "Catppuccin Frappe"
Set FontSize 18
Set Width 900
Set Height 560
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
Sleep 4s
Type "Where does the history go?" Sleep 400ms Enter
Sleep 4s
# Paste: VHS pastes the host clipboard (the Makefile target fills it first).
Paste
Sleep 800ms
Enter
Sleep 1500ms
Screenshot .github/assets/demos/chat.png
Sleep 3s
Type "Ctrl-C quits." Sleep 600ms
Ctrl+C
Sleep 1500ms
