#Requires AutoHotkey v2.0
#Warn All, OutputDebug
SetWorkingDir(A_ScriptDir)
#Include "XPPEN_NO_ADMIN.ahk"
AbrirPanelPuntos()
out := ""
global ACC
for p in ACC.paneles {
    out .= p.id ": abi=" p.altoAbi " cerr=" p.altoCerr " lineDy=" p.lineDy " ctrls=" p.ctrls.Length "`n"
}
FileAppend(out, "acc_debug.txt", "UTF-8")
ExitApp()
