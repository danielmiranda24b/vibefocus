# focus-window.ps1
# Brings the calling terminal window (Windows Terminal, cmd, PowerShell, Git Bash, etc.)
# to the foreground.

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool IsIconic(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool AllowSetForegroundWindow(int dwProcessId);

    [DllImport("kernel32.dll")]
    public static extern uint GetConsoleWindow();
}
"@

$SW_RESTORE = 9
$SW_SHOW    = 5

# ── Strategy 1: find Windows Terminal (wt.exe) window ─────────────────────────
$wtProc = Get-Process -Name "WindowsTerminal" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($wtProc -and $wtProc.MainWindowHandle -ne [IntPtr]::Zero) {
    $hwnd = $wtProc.MainWindowHandle
    if ([Win32]::IsIconic($hwnd)) {
        [Win32]::ShowWindow($hwnd, $SW_RESTORE) | Out-Null
    } else {
        [Win32]::ShowWindow($hwnd, $SW_SHOW) | Out-Null
    }
    [Win32]::AllowSetForegroundWindow($wtProc.Id) | Out-Null
    [Win32]::SetForegroundWindow($hwnd) | Out-Null
    exit 0
}

# ── Strategy 2: PowerShell host window ────────────────────────────────────────
$psProc = Get-Process -Name "pwsh","powershell" -ErrorAction SilentlyContinue |
          Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } |
          Select-Object -First 1
if ($psProc) {
    $hwnd = $psProc.MainWindowHandle
    if ([Win32]::IsIconic($hwnd)) {
        [Win32]::ShowWindow($hwnd, $SW_RESTORE) | Out-Null
    } else {
        [Win32]::ShowWindow($hwnd, $SW_SHOW) | Out-Null
    }
    [Win32]::AllowSetForegroundWindow($psProc.Id) | Out-Null
    [Win32]::SetForegroundWindow($hwnd) | Out-Null
    exit 0
}

# ── Strategy 3: conhost / cmd fallback ────────────────────────────────────────
$termProcs = @("ConEmu64","ConEmuC64","cmder","mintty","bash","cmd","conhost")
foreach ($name in $termProcs) {
    $proc = Get-Process -Name $name -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } |
            Select-Object -First 1
    if ($proc) {
        $hwnd = $proc.MainWindowHandle
        if ([Win32]::IsIconic($hwnd)) {
            [Win32]::ShowWindow($hwnd, $SW_RESTORE) | Out-Null
        } else {
            [Win32]::ShowWindow($hwnd, $SW_SHOW) | Out-Null
        }
        [Win32]::AllowSetForegroundWindow($proc.Id) | Out-Null
        [Win32]::SetForegroundWindow($hwnd) | Out-Null
        exit 0
    }
}
