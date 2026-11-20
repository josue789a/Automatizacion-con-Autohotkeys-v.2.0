Set WshShell = CreateObject("WScript.Shell")
scriptDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
pyExe = "C:\Users\jbard\AppData\Local\Python\pythoncore-3.14-64\pythonw.exe"
iniPath = scriptDir & "\posiciones_gui.ini"
WshShell.CurrentDirectory = scriptDir & "\calibrador_py"
WshShell.Run """" & pyExe & """ -m xppen_calibrador --ini """ & iniPath & """", 0, False
