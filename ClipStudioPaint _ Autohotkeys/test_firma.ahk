#Requires AutoHotkey v2.0
DllCall("SetThreadDpiAwarenessContext","ptr",-3,"ptr")
#Include %A_ScriptDir%\lib\core_config.ahk
f := _FirmaMonitores()
monCount := MonitorGetCount()
out := "Monitores: " monCount "`nFirma: " f "`n"
loop monCount {
    MonitorGet(A_Index, &l, &t, &r, &b)
    out .= Format("Mon {:d}: L={:d} T={:d} R={:d} B={:d} (W={:d} H={:d})`n", A_Index, l, t, r, b, r-l, b-t)
}
FileAppend(out, A_ScriptDir "\firma_res.txt", "UTF-8")
ExitApp()
