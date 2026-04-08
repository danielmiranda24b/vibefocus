# VibeFocus

Get notified when Claude Code finishes or needs your permission — toast notification, beep, taskbar flash, and VS Code jumps to front if another app was covering it.

Works with multiple simultaneous Claude sessions.

---

## Install

### Windows
```powershell
irm https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/viberaise/install.ps1 | iex
```

### macOS
```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/viberaise/install.sh | bash
```

The installer:
- Creates `~/.vibeRaise/` with the notification scripts
- Creates `~/.vibepause/hooks/` with the Claude hook scripts
- Merges the hooks into `~/.claude/settings.json` (your existing settings are preserved)
- Fires a test notification so you know it worked

---

## What triggers a notification

| Event | When |
|---|---|
| **Stop** | Claude finishes its response |
| **Notification** | Claude has a message for you |
| **PreToolUse (Bash)** | Claude needs permission to run a command |

---

## Uninstall

### Windows
```powershell
Remove-Item -Recurse "$env:USERPROFILE\.vibeRaise"
Remove-Item "$env:USERPROFILE\.vibepause\hooks\on_stop.cmd"
Remove-Item "$env:USERPROFILE\.vibepause\hooks\on_notification.cmd"
Remove-Item "$env:USERPROFILE\.vibepause\hooks\on_pre_tool_use.cmd"
```
Then remove the `hooks` entries from `~/.claude/settings.json`.

### macOS
```bash
rm -rf ~/.vibeRaise
rm ~/.vibepause/hooks/on_stop.sh ~/.vibepause/hooks/on_notification.sh ~/.vibepause/hooks/on_pre_tool_use.sh
```
Then remove the `hooks` entries from `~/.claude/settings.json`.
