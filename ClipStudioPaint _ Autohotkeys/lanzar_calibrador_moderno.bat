@echo off
cd /d "%~dp0calibrador_py"
start "" "C:\Users\jbard\AppData\Local\Python\pythoncore-3.14-64\pythonw.exe" -m xppen_calibrador --ini "%~dp0posiciones_gui.ini"
exit
