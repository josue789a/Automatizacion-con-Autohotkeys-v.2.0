#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, OutputDebug
#InstallMouseHook
#InstallKeybdHook
^!+q:: ExitApp()   ; salida de emergencia

global LOG := A_ScriptDir "\sonda_boton_lapiz.log"
try FileDelete(LOG)

_Reg(ev) {
    MouseGetPos(&mx, &my, &hw)
    proc := ""
    try proc := WinGetProcessName("ahk_id " hw)
    FileAppend(A_TickCount "`t" ev "`t" proc "`t" mx "," my "`n", LOG, "UTF-8")
}

~*RButton::_Reg("RButton down")
~*RButton up::_Reg("RButton up")
~*MButton::_Reg("MButton down")
~*XButton1::_Reg("XButton1 down")
~*XButton2::_Reg("XButton2 down")
~*F13::_Reg("F13 down")
~*F14::_Reg("F14 down")
~*F24::_Reg("F24 down")
