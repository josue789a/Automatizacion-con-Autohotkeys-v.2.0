; ============================================================
; DETECTOR DE COORDENADAS
; F1 → capturar punto | F2 → copiar lista | F3 → borrar todo
; ============================================================

#NoEnv
#SingleInstance Force
SetWorkingDir %A_ScriptDir%

global puntos := []
global contador := 0

; -------------------------------------------------------
; F1 — Capturar punto actual del mouse
; -------------------------------------------------------
F1::
    MouseGetPos, mx, my
    contador++
    linea := "P" . contador . ": (" . mx . ", " . my . ")"
    puntos.Push(linea)
    msg := "P" . contador . " capturado`n(" . mx . ", " . my . ")"
    ToolTip, %msg%
    SetTimer, BorrarTooltip, -1500
return

; -------------------------------------------------------
; F2 — Copiar lista de puntos al portapapeles
; -------------------------------------------------------
F2::
    if (puntos.MaxIndex() = "") {
        ToolTip, No hay puntos capturados
        SetTimer, BorrarTooltip, -1500
        return
    }
    texto := ""
    for i, linea in puntos
        texto .= linea . "`n"
    Clipboard := RTrim(texto, "`n")
    total := puntos.MaxIndex()
    ToolTip, %total% punto(s) copiados al portapapeles
    SetTimer, BorrarTooltip, -1500
return

; -------------------------------------------------------
; F3 — Borrar todos los puntos
; -------------------------------------------------------
F3::
    puntos := []
    contador := 0
    ToolTip, Lista borrada
    SetTimer, BorrarTooltip, -1500
return

; -------------------------------------------------------
BorrarTooltip:
    ToolTip
return