# Run from the repository root via `make demos` (after `swift build -c release`).
# STIPPLE_BIN (absolute path) overrides the directory holding the example binaries.
Output .github/assets/demos/logs.gif
Output .github/assets/demos/logs.mp4

Set Shell "bash"
Set Theme "Catppuccin Frappe"
Set FontSize 14
Set Width 1000
Set Height 560
Set Padding 24
Set Framerate 10
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
Type "logs" Sleep 400ms Enter
Sleep 2s
Set TypingSpeed 0
# The service list has focus: pick a service, then go back to all.
Down Sleep 1500ms
Up Sleep 1000ms
# Focus the log and scroll up: following pauses while new lines keep arriving.
Tab Sleep 600ms
PageUp Sleep 500ms
PageUp Sleep 500ms
PageUp Sleep 800ms
Up Sleep 200ms
Up Sleep 200ms
Up Sleep 1000ms
Screenshot .github/assets/demos/logs.png
Sleep 1000ms
# Back to the bottom: following resumes (VHS has no End key).
PageDown Sleep 300ms
PageDown Sleep 300ms
PageDown Sleep 300ms
PageDown Sleep 1500ms
# Filter the messages.
Tab Sleep 600ms
Type@90ms "declined" Sleep 2500ms
Ctrl+C
Sleep 1s
