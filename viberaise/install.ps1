#Requires -Version 5.1
<#
.SYNOPSIS
    VibeFocus — one-click installer for Windows.
    Notifies you (toast + beep + taskbar flash) when Claude finishes or needs permission.
    Brings VS Code to front if another app is covering it.

.USAGE
    From the web (one-liner):
        irm https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/viberaise/install.ps1 | iex

    From a cloned repo:
        .\viberaise\install.ps1
#>

# ── Config ────────────────────────────────────────────────────────────────────
$REPO_RAW = "https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/viberaise"

$vibeDir  = "$env:USERPROFILE\.vibeRaise"
$hooksDir = "$env:USERPROFILE\.vibepause\hooks"
$cfgFile  = "$env:USERPROFILE\.claude\settings.json"

Write-Host ""
Write-Host "  VibeFocus installer for Windows" -ForegroundColor Cyan
Write-Host "  ─────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

# ── Create directories ────────────────────────────────────────────────────────
New-Item -ItemType Directory -Force -Path $vibeDir  | Out-Null
New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $cfgFile) | Out-Null

# ── Copy or download core scripts ─────────────────────────────────────────────
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

# ── Write hook CMD files (paths resolved to this machine) ─────────────────────
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

# ── Merge into Claude settings.json ──────────────────────────────────────────
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
Write-Host "  Done! Testing in 3 seconds — switch to another window now..." -ForegroundColor Green
Write-Host ""
Start-Sleep 3
powershell.exe -ExecutionPolicy Bypass -File "$vibeDir\focus-window.ps1" "VibeFocus installed!" "Claude will now notify you when done"
