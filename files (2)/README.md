# VibeRaise 🪟⚡

Automatically brings your terminal window to the front whenever Claude Code is waiting for your input — so you can work in another window while Claude thinks, and get snapped back the moment it needs you.

Inspired by [VibePause](https://github.com/dantekakhadze/VibePause). Windows-native port.

---

## How It Works

| What's happening | Terminal |
|-----------------|----------|
| Claude is thinking / running tools | Stay wherever you are |
| Claude asks you a question | ⬆️ Terminal pops to the front |
| Claude finishes and waits | ⬆️ Terminal pops to the front |

---

## Requirements

- **Windows 10 / 11**
- **Python 3** — [python.org](https://python.org)
- **Claude Code** — `npm install -g @anthropic-ai/claude-code`

---

## Install

```powershell
git clone https://github.com/yourusername/VibeRaise.git
cd VibeRaise
powershell -ExecutionPolicy Bypass -File install.ps1
```

Then **restart your terminal**.

---

## Usage

Just use `claude` normally. When you switch to another window while it's working, it'll snap you back when it needs you.

```powershell
claude "refactor this file"
# → switch to your browser, watch a video, whatever
# → terminal pops up the moment Claude asks you something
```

---

## Supported Terminals

- ✅ Windows Terminal (`wt.exe`)
- ✅ PowerShell
- ✅ Command Prompt
- ✅ ConEmu / Cmder
- ✅ Git Bash (mintty)

---

## How It's Built

Two complementary layers:

**1. Claude Code `on_stop` hook** — registered in `~/.claude/settings.json`, fires every time Claude finishes a response and is waiting. Calls `focus-window.ps1` via a `.cmd` hook.

**2. Python wrapper** — sits in front of the real `claude` binary, watches stdout for prompt patterns (`?`, `(y/n)`, `Allow...?`, etc.) and raises the window mid-stream too.

The PowerShell `focus-window.ps1` uses Win32 `SetForegroundWindow` + `ShowWindow` to restore and raise the window, trying Windows Terminal first, then PowerShell, then cmd/conhost fallbacks.

---

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File uninstall.ps1
```

---

## Troubleshooting

**Window doesn't pop up**
- Make sure you restarted your terminal after install
- Run `where claude` — it should point to `%USERPROFILE%\.vibeRaise\claude.cmd`
- Check that Python is on your PATH: `python --version`

**"claude-real not found" error**
- Re-run `install.ps1` — it re-links the real binary

**Works in Windows Terminal but not PowerShell (or vice versa)**
- The focus script tries multiple strategies; open an issue with your terminal name

---

## License

MIT
