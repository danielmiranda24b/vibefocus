' run-hidden.vbs — launches powershell.exe (5.1) completely silently, no window at all
' Usage: wscript //nologo run-hidden.vbs script.ps1 [arg1] [arg2]
Dim WshShell, cmd, i
Set WshShell = CreateObject("WScript.Shell")
cmd = "powershell.exe -ExecutionPolicy Bypass -NonInteractive -File """ & WScript.Arguments(0) & """"
For i = 1 To WScript.Arguments.Count - 1
    cmd = cmd & " """ & WScript.Arguments(i) & """"
Next
WshShell.Run cmd, 0, False
