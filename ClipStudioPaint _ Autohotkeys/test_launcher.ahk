#Requires AutoHotkey v2.0
out := "=== TEST RUN NO ADMIN ===`n"
Run('"' A_ScriptDir '\XPPEN_NO_ADMIN.ahk"')
Sleep(2500)
guis := WinGetList("ahk_class AutoHotkeyGUI")
out .= "Total GUIs de AutoHotkey encontradas: " guis.Length "`n"
for hwnd in guis {
    try {
        tit := WinGetTitle("ahk_id " hwnd)
        WinGetPos(&x,&y,&w,&h,"ahk_id " hwnd)
        vis := DllCall("IsWindowVisible", "Ptr", hwnd)
        out .= Format("  GUI {:d}: Vis={:d} | X={:d} Y={:d} W={:d} H={:d} | '{:s}'`n", hwnd, vis, x, y, w, h, tit)
    }
}
try FileDelete(A_ScriptDir "\test_run_res.txt")
FileAppend(out, A_ScriptDir "\test_run_res.txt", "UTF-8")
ExitApp()
