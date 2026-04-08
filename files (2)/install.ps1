# install.ps1 - VibeRaise Installer
# Run once from the VibeRaise directory:
#   powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  VibeRaise Installer" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# ── 1. Check Python ────────────────────────────────────────────────────────────
Write-Host "Checking Python..." -NoNewline
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    $python = Get-Command python3 -ErrorAction SilentlyContinue
}
if (-not $python) {
    Write-Host " ✗" -ForegroundColor Red
    Write-Host "Python not found. Install Python 3 from https://python.org" -ForegroundColor Red
    exit 1
}
Write-Host " ✓ ($($python.Source))" -ForegroundColor Green

# ── 2. Find real claude binary ─────────────────────────────────────────────────
Write-Host "Finding claude binary..." -NoNewline
$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
if (-not $claudeCmd) {
    Write-Host " ✗" -ForegroundColor Red
    Write-Host "claude not found in PATH. Install Claude Code first." -ForegroundColor Red
    Write-Host "  npm install -g @anthropic-ai/claude-code" -ForegroundColor Yellow
    exit 1
}
$claudeReal = $claudeCmd.Source
Write-Host " ✓ ($claudeReal)" -ForegroundColor Green

# ── 3. Set up install directory ────────────────────────────────────────────────
$installDir = "$env:USERPROFILE\.vibeRaise"
New-Item -ItemType Directory -Force -Path $installDir | Out-Null
Write-Host "Install directory: $installDir" -ForegroundColor Gray

# ── 4. Copy wrapper files ──────────────────────────────────────────────────────
Copy-Item "$ScriptDir\claude-wrapper.py" "$installDir\claude-wrapper.py" -Force
Copy-Item "$ScriptDir\focus-window.ps1"  "$installDir\focus-window.ps1"  -Force
Write-Host "✓ Copied wrapper files" -ForegroundColor Green

# ── 5. Create claude-real.cmd pointing at the real binary ─────────────────────
$claudeRealCmd = "$installDir\claude-real.cmd"
Set-Content -Path $claudeRealCmd -Value "@echo off`r`n`"$claudeReal`" %*"
Write-Host "✓ Created claude-real.cmd -> $claudeReal" -ForegroundColor Green

# ── 6. Create claude.cmd shim ─────────────────────────────────────────────────
$claudeShim = "$installDir\claude.cmd"
Set-Content -Path $claudeShim -Value "@echo off`r`npython `"$installDir\claude-wrapper.py`" %*"
Write-Host "✓ Created claude.cmd shim" -ForegroundColor Green

# ── 7. Add installDir to front of user PATH ───────────────────────────────────
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*$installDir*") {
    [Environment]::SetEnvironmentVariable("PATH", "$installDir;$userPath", "User")
    Write-Host "✓ Added $installDir to user PATH" -ForegroundColor Green
    Write-Host "  (Restart your terminal for PATH to take effect)" -ForegroundColor Yellow
} else {
    Write-Host "✓ PATH already contains install directory" -ForegroundColor Green
}

# ── 8. Claude Code hooks (on_stop → focus window) ─────────────────────────────
Write-Host ""
Write-Host "Setting up Claude Code hooks..." -ForegroundColor Cyan

$hookDir = "$env:USERPROFILE\.vibepause\hooks"
New-Item -ItemType Directory -Force -Path $hookDir | Out-Null

# on_stop hook: fires when Claude finishes a response and waits for you
$onStopContent = @"
@echo off
powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "$installDir\focus-window.ps1"
"@
Set-Content -Path "$hookDir\on_stop.cmd" -Value $onStopContent
Write-Host "✓ Created on_stop.cmd hook" -ForegroundColor Green

# on_user_prompt hook: fires when you submit input (no-op needed, just for symmetry)
Set-Content -Path "$hookDir\on_user_prompt.cmd" -Value "@echo off"
Write-Host "✓ Created on_user_prompt.cmd hook" -ForegroundColor Green

# Register hooks in Claude Code settings.json
$settingsPath = "$env:USERPROFILE\.claude\settings.json"
Write-Host "Registering hooks in $settingsPath..." -NoNewline

$hooksBlock = @{
    Stop = @(
        @{
            matcher = ""
            hooks   = @(
                @{
                    type    = "command"
                    command = "`"$hookDir\on_stop.cmd`""
                }
            )
        }
    )
    UserPromptSubmit = @(
        @{
            matcher = ""
            hooks   = @(
                @{
                    type    = "command"
                    command = "`"$hookDir\on_user_prompt.cmd`""
                }
            )
        }
    )
}

if (Test-Path $settingsPath) {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
} else {
    New-Item -ItemType Directory -Force -Path (Split-Path $settingsPath) | Out-Null
    $settings = [PSCustomObject]@{}
}

if (-not $settings.PSObject.Properties["hooks"]) {
    $settings | Add-Member -MemberType NoteProperty -Name "hooks" -Value ([PSCustomObject]@{})
}
$settings.hooks = $hooksBlock
$settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding UTF8
Write-Host " ✓" -ForegroundColor Green

# ── 9. Done ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  Done! Restart your terminal to activate." -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "How it works:" -ForegroundColor White
Write-Host "  Claude is thinking  → you can switch to another window/screen"
Write-Host "  Claude asks you something → your terminal pops to the front"
Write-Host ""
Write-Host "Works via two layers:"
Write-Host "  1. Claude Code on_stop hook   (reliable, fires on every response)"
Write-Host "  2. Python PTY wrapper         (catches mid-stream prompt patterns)"
Write-Host ""
Write-Host "To uninstall: powershell -File uninstall.ps1" -ForegroundColor Gray
Write-Host ""
