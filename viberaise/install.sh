#!/bin/bash
# VibeFocus — one-click installer for macOS
# Notifies you (notification + sound) when Claude finishes or needs permission.
# Brings VS Code to front if another app is covering it.
#
# Usage (one-liner from the web):
#   curl -fsSL https://raw.githubusercontent.com/danielmiranda24b/vibefocus/main/viberaise/install.sh | bash
#
# Or from a cloned repo:
#   bash viberaise/install.sh

REPO_RAW="https://raw.githubusercontent.com/danielmiranda24b/vibefocus/main/viberaise"
VIBE_DIR="$HOME/.vibeRaise"
HOOKS_DIR="$HOME/.vibepause/hooks"
CFG_FILE="$HOME/.claude/settings.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "  VibeFocus installer for macOS"
echo "  ─────────────────────────────────"
echo ""

# ── Create directories ────────────────────────────────────────────────────────
mkdir -p "$VIBE_DIR" "$HOOKS_DIR" "$(dirname "$CFG_FILE")"

# ── Copy or download core script ──────────────────────────────────────────────
LOCAL="$SCRIPT_DIR/mac/notify.sh"
if [ -f "$LOCAL" ]; then
    cp "$LOCAL" "$VIBE_DIR/notify.sh"
    echo "  [copied]    notify.sh"
else
    echo "  [download]  notify.sh"
    curl -fsSL "$REPO_RAW/mac/notify.sh" -o "$VIBE_DIR/notify.sh"
fi
chmod +x "$VIBE_DIR/notify.sh"

# ── Write hook shell scripts ──────────────────────────────────────────────────
cat > "$HOOKS_DIR/on_stop.sh" << EOF
#!/bin/bash
"$VIBE_DIR/notify.sh" "Claude is done" "Waiting for your input"
EOF

cat > "$HOOKS_DIR/on_notification.sh" << EOF
#!/bin/bash
"$VIBE_DIR/notify.sh" "Claude needs you" "Permission or input required"
EOF

cat > "$HOOKS_DIR/on_pre_tool_use.sh" << EOF
#!/bin/bash
"$VIBE_DIR/notify.sh" "Claude needs permission" "Allow or deny the bash command"
EOF

chmod +x "$HOOKS_DIR/on_stop.sh" "$HOOKS_DIR/on_notification.sh" "$HOOKS_DIR/on_pre_tool_use.sh"
echo "  [created]   hook scripts"

# ── Merge into Claude settings.json ──────────────────────────────────────────
python3 - << PYEOF
import json, os

cfg_file  = os.path.expanduser("$CFG_FILE")
hooks_dir = os.path.expanduser("$HOOKS_DIR")

settings = {}
if os.path.exists(cfg_file):
    with open(cfg_file) as f:
        settings = json.load(f)

settings.setdefault("hooks", {})

def add_hook(event, matcher, cmd):
    settings["hooks"].setdefault(event, [])
    for entry in settings["hooks"][event]:
        for h in entry.get("hooks", []):
            if h.get("command") == cmd:
                return  # already present
    settings["hooks"][event].append({
        "matcher": matcher,
        "hooks": [{"type": "command", "command": cmd}]
    })

add_hook("Stop",         "",     hooks_dir + "/on_stop.sh")
add_hook("Notification", "",     hooks_dir + "/on_notification.sh")
add_hook("PreToolUse",   "Bash", hooks_dir + "/on_pre_tool_use.sh")

with open(cfg_file, "w") as f:
    json.dump(settings, f, indent=4)
PYEOF

echo "  [merged]    ~/.claude/settings.json"

# ── Test ──────────────────────────────────────────────────────────────────────
echo ""
echo "  Done! Testing in 3 seconds — switch to another window now..."
echo ""
sleep 3
"$VIBE_DIR/notify.sh" "VibeFocus installed!" "Claude will now notify you when done"
