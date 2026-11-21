#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, OutputDebug
try FileDelete(A_ScriptDir "\_pen_timing.log")

_log(s) => FileAppend(A_TickCount " " s "`n", A_ScriptDir "\_pen_timing.log")
~*RButton::_log("AHK RButton DOWN")
~*RButton up::_log("AHK RButton UP")
~*LButton::_log("AHK LButton DOWN phys=" GetKeyState("LButton", "P"))

^!+q:: ExitApp()
