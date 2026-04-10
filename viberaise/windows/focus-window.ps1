# focus-window.ps1
# Safe for 8+ concurrent Claude sessions. Named mutex ensures only one instance
# runs at a time. Brings VS Code to front only when covered (no ShowWindow/AttachThreadInput).
param(
    [string]$ToastTitle = "Claude is done",
    [string]$ToastBody  = "Waiting for your input"
)

# ── One instance at a time ────────────────────────────────────────────────────
$mtx = New-Object System.Threading.Mutex($false, "Global\VibeRaiseFocus")
try { $got = $mtx.WaitOne(5000) } catch [System.Threading.AbandonedMutexException] { $got = $true } catch { $got = $false }
if (-not $got) { $mtx.Dispose(); exit 0 }

try {

# ── Taskbar-only flash (FLASHW_TRAY=2, no WM_NCACTIVATE to Electron) ─────────
Add-Type -Name Win -Namespace VR -MemberDefinition @"
    [System.Runtime.InteropServices.StructLayout(
        System.Runtime.InteropServices.LayoutKind.Sequential)]
    public struct FWI {
        public uint sz; public IntPtr hwnd;
        public uint flags; public uint count; public uint ms;
    }
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern bool FlashWindowEx(ref FWI p);
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern void SwitchToThisWindow(IntPtr hWnd, bool fAltTab);

    public static void Flash(IntPtr h) {
        FWI f = new FWI();
        f.sz    = (uint)System.Runtime.InteropServices.Marshal.SizeOf(f);
        f.hwnd  = h;
        f.flags = 14;   // FLASHW_TRAY|FLASHW_TIMER|FLASHW_TIMERNOFG
        f.count = 0;    // flash until window is foregrounded
        f.ms    = 0;
        FlashWindowEx(ref f);
    }
"@ -ErrorAction SilentlyContinue

# ── Toast (powershell.exe 5.1 WinRT, AUMID is registered) ────────────────────
$sent = $false
try {
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
    $aumid = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe"
    $n     = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($aumid)
    if ($n.Setting -eq 'Enabled') {
        $x = New-Object Windows.Data.Xml.Dom.XmlDocument
        $x.LoadXml([string]::Format(
            '<toast duration="short"><visual><binding template="ToastGeneric">'+
            '<text>{0}</text><text>{1}</text></binding></visual>'+
            '<audio src="ms-winsoundevent:Notification.Default"/></toast>',
            $ToastTitle, $ToastBody))
        $n.Show((New-Object Windows.UI.Notifications.ToastNotification $x))
        $sent = $true
    }
} catch { }

# ── Balloon fallback ──────────────────────────────────────────────────────────
if (-not $sent) {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        $b = New-Object System.Windows.Forms.NotifyIcon
        $b.Icon    = [System.Drawing.SystemIcons]::Application
        $b.Visible = $true
        $b.ShowBalloonTip(5000, $ToastTitle, $ToastBody,
            [System.Windows.Forms.ToolTipIcon]::Info)
        [System.Windows.Forms.Application]::DoEvents()
    } catch { }
}

# ── Beep ─────────────────────────────────────────────────────────────────────
try { [System.Media.SystemSounds]::Beep.Play() } catch { }

# ── Smart focus + flash ───────────────────────────────────────────────────────
# Only target Code windows with a real title (skips extension host / GPU procs)
$vscWins = @(Get-Process -Name "Code" -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero -and $_.MainWindowTitle })

if ($vscWins.Count -gt 0) {
    $fgPid = [uint32]0
    [VR.Win]::GetWindowThreadProcessId([VR.Win]::GetForegroundWindow(), [ref]$fgPid) | Out-Null
    $fgName = (Get-Process -Id ([int]$fgPid) -ErrorAction SilentlyContinue).ProcessName
    $vscInFront = ($fgName -eq "Code")

    if (-not $vscInFront) {
        # keybd_event(0,0,0,0) tricks Windows into granting foreground rights to this
        # background process — without it, SetForegroundWindow is silently blocked
        [VR.Win]::keybd_event(0, 0, 0, 0)
        [VR.Win]::SwitchToThisWindow($vscWins[0].MainWindowHandle, $true)
        [VR.Win]::SetForegroundWindow($vscWins[0].MainWindowHandle) | Out-Null
    }

    $vscWins | ForEach-Object { try { [VR.Win]::Flash($_.MainWindowHandle) } catch { } }
}

} finally {
    try { $mtx.ReleaseMutex() } catch { }
    $mtx.Dispose()
}
