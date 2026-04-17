#!/bin/bash
# notify.sh — VibeRaise for macOS
# Shows a notification, plays a sound, and brings VS Code to front if covered.

# Mutex — prevents overlapping notifications from concurrent Claude sessions
# Equivalent to the named mutex in focus-window.ps1 (Windows)
LOCKFILE="/tmp/viberaise.lock"
exec 9>"$LOCKFILE"
if ! flock -n 9; then
    exit 0  # another instance is running, skip silently
fi

TITLE="${1:-Claude is done}"
BODY="${2:-Waiting for your input}"

# Notification + sound
osascript -e "display notification \"$BODY\" with title \"$TITLE\" sound name \"Glass\"" 2>/dev/null

# Bring VS Code to front only if something else has focus
FRONT=$(osascript -e 'tell application "System Events" to name of first application process whose frontmost is true' 2>/dev/null)
if [[ "$FRONT" != "Code" && "$FRONT" != "Electron" ]]; then
    osascript -e 'if application "Visual Studio Code" is running then tell application "Visual Studio Code" to activate end if' 2>/dev/null || true
fi
