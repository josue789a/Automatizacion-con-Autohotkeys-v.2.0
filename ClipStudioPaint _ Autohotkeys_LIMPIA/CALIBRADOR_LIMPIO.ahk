#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, OutputDebug

; ==============================================================================
; LANZADOR LIMPIO ALTERNO (MODO NO-ADMIN)
; Abre directamente el Calibrador oficial con estado limpio (sin particularidades
; previas ni eventos custom residuales) para pruebas manuales reales de usuario.
; Salida limpia: Ctrl + Alt + Shift + Q (^!+q) o cerrando la ventana.
; ==============================================================================

SetWorkingDir(A_ScriptDir)
#Include "XPPEN_NO_ADMIN.ahk"

; Abre de inmediato el panel del Calibrador
SetTimer(() => AbrirPanelPuntos(), -200)
