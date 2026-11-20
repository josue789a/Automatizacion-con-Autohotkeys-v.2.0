#Requires AutoHotkey v2.0
#SuspendExempt
InstallMouseHook
#HotIf WinActive("ahk_exe python.exe") || WinActive("ahk_exe pythonw.exe")
~RButton::   FileAppend(A_TickCount " RB down`n", A_ScriptDir "\probe_ahk.log")
~RButton up::FileAppend(A_TickCount " RB up`n",   A_ScriptDir "\probe_ahk.log")
~LButton::   FileAppend(A_TickCount " LB down`n", A_ScriptDir "\probe_ahk.log")
~LButton up::FileAppend(A_TickCount " LB up`n",   A_ScriptDir "\probe_ahk.log")
#HotIf

^!+q:: ExitApp()
