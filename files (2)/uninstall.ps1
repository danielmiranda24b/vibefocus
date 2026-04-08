# uninstall.ps1 - VibeRaise Uninstaller

$installDir = "$env:USERPROFILE\.vibeRaise"
$hookDir    = "$env:USERPROFILE\.vibepause\hooks"

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host "  VibeRaise Uninstaller" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host ""

# ── Remove from PATH ───────────────────────────────────────────────────────────
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -like "*$installDir*") {
    $newPath = ($userPath -split ";" | Where-Object { $_ -ne $installDir }) -join ";"
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    Write-Host "✓ Removed $installDir from PATH" -ForegroundColor Green
}

# ── Remove install directory ───────────────────────────────────────────────────
if (Test-Path $installDir) {
    Remove-Item -Recurse -Force $installDir
    Write-Host "✓ Removed $installDir" -ForegroundColor Green
}

# ── Remove hooks directory ─────────────────────────────────────────────────────
if (Test-Path $hookDir) {
    Remove-Item -Recurse -Force $hookDir
    Write-Host "✓ Removed $hookDir" -ForegroundColor Green
}

# ── Remove hooks from Claude Code settings.json ───────────────────────────────
$settingsPath = "$env:USERPROFILE\.claude\settings.json"
if (Test-Path $settingsPath) {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    if ($settings.PSObject.Properties["hooks"]) {
        $settings.PSObject.Properties.Remove("hooks")
        $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding UTF8
        Write-Host "✓ Removed hooks from Claude Code settings.json" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host "  Done. Restart your terminal." -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host ""
