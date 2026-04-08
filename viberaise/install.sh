#!/bin/bash
# VibeFocus — one-click installer for macOS
# Automatically installs Node.js and Claude Code if missing, then sets up
# notifications for Claude Code sessions.
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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

echo ""
echo "  VibeFocus installer for macOS"
echo "  ─────────────────────────────────"
echo ""

# ── Step 1: Node.js ───────────────────────────────────────────────────────────
if ! command -v node &>/dev/null; then
    echo "  [install]   Node.js not found — installing..."
    if command -v brew &>/dev/null; then
        brew install node &>/dev/null
    else
        # Download and run the official Node.js macOS installer
        NODE_PKG=$(curl -fsSL https://nodejs.org/dist/index.json | python3 -c \
            "import json,sys; r=[x for x in json.load(sys.stdin) if x['lts']]; print(r[0]['version'])")
        ARCH=$(uname -m)
        [ "$ARCH" = "arm64" ] && PKG="node-${NODE_PKG}-darwin-arm64.tar.gz" || PKG="node-${NODE_PKG}-darwin-x64.tar.gz"
        curl -fsSL "https://nodejs.org/dist/${NODE_PKG}/${PKG}" -o /tmp/node.tar.gz
        sudo tar -xzf /tmp/node.tar.gz -C /usr/local --strip-components=1
        rm /tmp/node.tar.gz
    fi
    if ! command -v node &>/dev/null; then
        echo "  [error]     Node.js install failed. Install manually from https://nodejs.org"
        exit 1
    fi
fi
echo "  [ok]        Node.js $(node --version)"

# ── Step 2: Claude Code ───────────────────────────────────────────────────────
if ! command -v claude &>/dev/null; then
    echo "  [install]   Claude Code not found — installing..."
    npm install -g @anthropic-ai/claude-code &>/dev/null
    if ! command -v claude &>/dev/null; then
        echo "  [error]     Claude Code install failed. Try: npm install -g @anthropic-ai/claude-code"
        exit 1
    fi
    echo "  [ok]        Claude Code installed"
else
    echo "  [ok]        Claude Code $(claude --version 2>/dev/null)"
fi

# ── Step 3: Create directories ────────────────────────────────────────────────
mkdir -p "$VIBE_DIR" "$HOOKS_DIR" "$(dirname "$CFG_FILE")"

# ── Step 4: Copy or download core script ──────────────────────────────────────
LOCAL="$SCRIPT_DIR/mac/notify.sh"
if [ -f "$LOCAL" ]; then
    cp "$LOCAL" "$VIBE_DIR/notify.sh"
    echo "  [copied]    notify.sh"
else
    echo "  [download]  notify.sh"
    curl -fsSL "$REPO_RAW/mac/notify.sh" -o "$VIBE_DIR/notify.sh"
fi
chmod +x "$VIBE_DIR/notify.sh"

# ── Step 5: Write hook shell scripts ──────────────────────────────────────────
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

# ── Step 6: Merge into Claude settings.json ───────────────────────────────────
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
                return
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
echo "  All done! Testing in 3 seconds — switch to another window now..."
echo ""
sleep 3
"$VIBE_DIR/notify.sh" "VibeFocus installed!" "Claude will now notify you when done"
