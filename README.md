# VibeFocus

Get notified the moment Claude Code finishes or needs your input — toast notification, beep, taskbar flash, and VS Code jumps to front if another app was covering it.

Works with multiple simultaneous Claude sessions.

---

## Install

### Windows
Click to download, then double-click the file:

**[⬇ Download VibeFocus-Install.bat](https://vibefocus.vercel.app/VibeFocus-Install.bat)**

Or paste in a terminal:
```powershell
irm https://raw.githubusercontent.com/danielmiranda24b/vibefocus/main/viberaise/install.ps1 | iex
```

### macOS
Click to download, then double-click the file:

**[⬇ Download VibeFocus-Install.command](https://vibefocus.vercel.app/VibeFocus-Install.command)**

Or paste in a terminal:
```bash
curl -fsSL https://raw.githubusercontent.com/danielmiranda24b/vibefocus/main/viberaise/install.sh | bash
```

The installer automatically installs Node.js and Claude Code if you don't have them.

---

## What triggers a notification

| Event | When |
|---|---|
| **Claude finishes** | End of every response |
| **Notification** | Claude has a message for you |
| **Permission prompt** | Claude needs to run a command |

---

## How it works

The installer registers three hooks in `~/.claude/settings.json`. When Claude fires a hook:

```
on_stop.cmd → run-hidden.vbs → focus-window.ps1
```

`focus-window.ps1` runs silently and:
- Shows a Windows toast notification
- Plays a system beep
- Flashes the VS Code taskbar button orange until you click it
- Brings VS Code to front if another app is covering it

Uses a named mutex so multiple Claude sessions don't conflict.

---

## Uninstall

### Windows
```powershell
Remove-Item -Recurse "$env:USERPROFILE\.vibeRaise"
Remove-Item "$env:USERPROFILE\.vibepause\hooks\on_stop.cmd"
Remove-Item "$env:USERPROFILE\.vibepause\hooks\on_notification.cmd"
Remove-Item "$env:USERPROFILE\.vibepause\hooks\on_pre_tool_use.cmd"
```
Then remove the `hooks` block from `~/.claude/settings.json`.

### macOS
```bash
rm -rf ~/.vibeRaise
rm ~/.vibepause/hooks/on_stop.sh ~/.vibepause/hooks/on_notification.sh ~/.vibepause/hooks/on_pre_tool_use.sh
```
Then remove the `hooks` block from `~/.claude/settings.json`.

---

## License

MIT
