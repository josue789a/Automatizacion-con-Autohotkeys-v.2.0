#Requires AutoHotkey v2.0
out := "TEST`n"
FileAppend(out, A_ScriptDir "\test_check.txt", "UTF-8")
ExitApp()
