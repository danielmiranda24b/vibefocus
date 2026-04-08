# VibeFocus — Project Context for Claude Code

## What this project is
VibeFocus is a Claude Code add-on that notifies you the moment Claude finishes or needs your input.
It fires a Windows toast notification + beep + persistent orange taskbar flash, and brings VS Code
to the front if another app was covering it. Safe for 8+ concurrent Claude sessions.

## Repo structure
```
vibefocus/
  index.html                  # Landing page (deployed on Vercel)
  vercel.json                 # Forces .bat/.command files to download instead of display
  VibeFocus-Install.bat       # Windows one-click installer (user downloads + double-clicks)
  VibeFocus-Install.command   # macOS one-click installer (user downloads + double-clicks)

  viberaise/
    install.ps1               # Windows full installer — auto-installs Node.js + Claude Code if missing
    install.sh                # macOS full installer — same auto-install logic
    windows/
      focus-window.ps1        # Core notification script (toast, beep, flash, focus logic)
      run-hidden.vbs          # Launches PowerShell 5.1 silently (no visible terminal window)
    mac/
      notify.sh               # macOS notification script (osascript + VS Code focus)

  ~/.claude/settings.json     # NOT in repo — written by installer on user's machine
  ~/.vibeRaise/               # NOT in repo — created by installer on user's machine
  ~/.vibepause/hooks/         # NOT in repo — hook .cmd/.sh files written by installer
```

## How it works end-to-end
1. Installer writes three hook scripts into `~/.vibepause/hooks/`
2. Installer merges three hooks into `~/.claude/settings.json`:
   - `Stop` — fires when Claude finishes a response
   - `Notification` — fires when Claude has a message
   - `PreToolUse` (matcher: Bash) — fires before every Bash tool call (permission prompts)
3. When Claude triggers a hook: `on_stop.cmd` → `wscript run-hidden.vbs` → `powershell focus-window.ps1`
4. `focus-window.ps1` runs silently and:
   - Shows a Windows toast notification (WinRT via PowerShell 5.1)
   - Falls back to a balloon tip if toasts are disabled
   - Plays a system beep
   - Flashes the VS Code taskbar button orange (persistent until clicked)
   - Calls `SetForegroundWindow` to bring VS Code to front only if it's not already focused

## Key technical decisions
- **PowerShell 5.1 (`powershell.exe`) not 7 (`pwsh`)** — WinRT toast notifications only work in 5.1
- **Named mutex `Global\VibeRaiseFocus` with 5000ms timeout** — prevents 8 concurrent sessions from
  crashing VS Code via simultaneous Win32 calls; 5s timeout lets Stop hook wait for a PreToolUse
  that fired just before it
- **No `ShowWindow` / `AttachThreadInput`** — these hide Electron (VS Code) windows when called
  from an external process; only `SetForegroundWindow` is used
- **`FLASHW_TIMERNOFG` flag** — taskbar glows orange persistently until user clicks VS Code
- **Toast AUMID** = `{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe`
  — must use a registered AUMID or Windows silently drops toasts
- **WinRT type loading must be on one line** — multi-line `[Type, Assembly, ContentType=WindowsRuntime]`
  syntax causes a parser error in `-File` mode, silently killing the script before anything runs
- **`AbandonedMutexException` treated as success** — if previous PS crashed without releasing the
  mutex, catching this exception and continuing (not exiting) is the correct behaviour

## Install flow (what the scripts do)
Both `install.ps1` and `install.sh` follow the same steps:
1. Check for Node.js → install via winget (Windows) or brew/tarball (Mac) if missing
2. Check for Claude Code → `npm install -g @anthropic-ai/claude-code` if missing
3. Create `~/.vibeRaise/` and copy/download the core scripts
4. Write hook `.cmd` / `.sh` files with paths resolved to the current machine
5. Read `~/.claude/settings.json`, merge the three hooks (no duplicates), write back
6. Fire a test notification after 3 seconds

## Deployment
- GitHub: https://github.com/danielmiranda24b/vibefocus (branch: master)
- Website: deployed on Vercel (auto-redeploys on push to master)
- Install commands (also embedded in VibeFocus-Install.bat / .command):
  - Windows: `irm https://raw.githubusercontent.com/danielmiranda24b/vibefocus/main/viberaise/install.ps1 | iex`
  - macOS: `curl -fsSL https://raw.githubusercontent.com/danielmiranda24b/vibefocus/main/viberaise/install.sh | bash`
