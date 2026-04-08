#Requires -Version 5.1
<#
.SYNOPSIS
    VibeFocus — one-click installer for Windows.
    Automatically installs Node.js and Claude Code if missing, then sets up
    toast + beep + taskbar flash notifications for Claude Code sessions.

.USAGE
    From the web (one-liner):
        irm https://raw.githubusercontent.com/danielmiranda24b/vibefocus/main/viberaise/install.ps1 | iex

    From a cloned repo:
        .\viberaise\install.ps1
#>

# ── Config ────────────────────────────────────────────────────────────────────
$REPO_RAW = "https://raw.githubusercontent.com/danielmiranda24b/vibefocus/main/viberaise"

$vibeDir  = "$env:USERPROFILE\.vibeRaise"
$hooksDir = "$env:USERPROFILE\.vibepause\hooks"
$cfgFile  = "$env:USERPROFILE\.claude\settings.json"

Write-Host ""
Write-Host "  VibeFocus installer for Windows" -ForegroundColor Cyan
Write-Host "  ─────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

# ── Step 1: Node.js ───────────────────────────────────────────────────────────
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "  [install]   Node.js not found — installing via winget..." -ForegroundColor Yellow
    winget install OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
    # Refresh PATH so npm is available in this session
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH","User")
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Write-Host ""
        Write-Host "  Node.js installed. Please restart your terminal and re-run this installer." -ForegroundColor Yellow
        Write-Host ""
        exit 0
    }
    Write-Host "  [ok]        Node.js $(node --version)" -ForegroundColor DarkGray
} else {
    Write-Host "  [ok]        Node.js $(node --version)" -ForegroundColor DarkGray
}

# ── Step 2: Claude Code ───────────────────────────────────────────────────────
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "  [install]   Claude Code not found — installing..." -ForegroundColor Yellow
    npm install -g @anthropic-ai/claude-code 2>&1 | Out-Null
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH","User")
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
        Write-Host "  [error]     Claude Code install failed. Try: npm install -g @anthropic-ai/claude-code" -ForegroundColor Red
        exit 1
    }
    Write-Host "  [ok]        Claude Code installed" -ForegroundColor DarkGray
} else {
    Write-Host "  [ok]        Claude Code $(claude --version 2>$null)" -ForegroundColor DarkGray
}

# ── Step 3: Create directories ────────────────────────────────────────────────
New-Item -ItemType Directory -Force -Path $vibeDir  | Out-Null
New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $cfgFile) | Out-Null

# ── Step 4: Copy or download core scripts ─────────────────────────────────────
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Install-Script($name, $dest) {
    $local = Join-Path $scriptDir "windows\$name"
    if (Test-Path $local) {
        Copy-Item $local $dest -Force
        Write-Host "  [copied]    $name" -ForegroundColor DarkGray
    } else {
        Write-Host "  [download]  $name" -ForegroundColor DarkGray
        Invoke-WebRequest "$REPO_RAW/windows/$name" -OutFile $dest -UseBasicParsing
    }
}

Install-Script "focus-window.ps1" "$vibeDir\focus-window.ps1"
Install-Script "run-hidden.vbs"   "$vibeDir\run-hidden.vbs"

# ── Step 5: Write hook CMD files (paths resolved to this machine) ──────────────
@"
@echo off
wscript //nologo "$vibeDir\run-hidden.vbs" "$vibeDir\focus-window.ps1"
"@ | Set-Content "$hooksDir\on_stop.cmd" -Encoding ASCII

@"
@echo off
wscript //nologo "$vibeDir\run-hidden.vbs" "$vibeDir\focus-window.ps1" "Claude needs you" "Permission or input required"
"@ | Set-Content "$hooksDir\on_notification.cmd" -Encoding ASCII

@"
@echo off
wscript //nologo "$vibeDir\run-hidden.vbs" "$vibeDir\focus-window.ps1" "Claude needs permission" "Allow or deny the bash command"
"@ | Set-Content "$hooksDir\on_pre_tool_use.cmd" -Encoding ASCII

Write-Host "  [created]   hook scripts" -ForegroundColor DarkGray

# ── Step 6: Merge into Claude settings.json ───────────────────────────────────
$cfg = if (Test-Path $cfgFile) {
    Get-Content $cfgFile -Raw | ConvertFrom-Json
} else {
    [PSCustomObject]@{}
}

if (-not ($cfg.PSObject.Properties['hooks'])) {
    $cfg | Add-Member -NotePropertyName hooks -NotePropertyValue ([PSCustomObject]@{})
}

function Add-Hook($event, $matcher, $cmd) {
    if (-not ($cfg.hooks.PSObject.Properties[$event])) {
        $cfg.hooks | Add-Member -NotePropertyName $event -NotePropertyValue @()
    }
    $already = $cfg.hooks.$event | Where-Object { $_.hooks | Where-Object { $_.command -eq $cmd } }
    if (-not $already) {
        $entry = [PSCustomObject]@{
            matcher = $matcher
            hooks   = @([PSCustomObject]@{ type = "command"; command = $cmd })
        }
        $cfg.hooks.$event = @($cfg.hooks.$event) + @($entry)
    }
}

Add-Hook "Stop"         ""     "`"$hooksDir\on_stop.cmd`""
Add-Hook "Notification" ""     "`"$hooksDir\on_notification.cmd`""
Add-Hook "PreToolUse"   "Bash" "`"$hooksDir\on_pre_tool_use.cmd`""

$cfg | ConvertTo-Json -Depth 10 | Set-Content $cfgFile -Encoding UTF8
Write-Host "  [merged]    ~/.claude/settings.json" -ForegroundColor DarkGray

# ── Test ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  All done! Testing in 3 seconds — switch to another window now..." -ForegroundColor Green
Write-Host ""
Start-Sleep 3
powershell.exe -ExecutionPolicy Bypass -File "$vibeDir\focus-window.ps1" "VibeFocus installed!" "Claude will now notify you when done"
