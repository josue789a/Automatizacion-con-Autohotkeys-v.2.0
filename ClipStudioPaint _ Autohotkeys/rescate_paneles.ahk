#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================================
; rescate_paneles.ahk  --  Boton de panico y restauracion de emergencia
; ----------------------------------------------------------------------------
; Restaura inmediatamente cualquier panel de Clip Studio Paint que haya quedado
; en alpha 5 (invisible) o con estilo +0x20 (click-through) por cierre abrupto.
; ============================================================================

if !A_IsAdmin {
    try Run('*RunAs "' A_ScriptFullPath '"')
    ExitApp()
}

prevDH := A_DetectHiddenWindows
DetectHiddenWindows(true)

restaurados := 0
detalles := ""

try {
    for hwnd in WinGetList("ahk_exe CLIPStudioPaint.exe") {
        key := 0, alpha := 0, flags := 0
        ; LWA_ALPHA = 0x2
        ok := DllCall("user32\GetLayeredWindowAttributes", "Ptr", hwnd, "UInt*", &key, "UChar*", &alpha, "UInt*", &flags, "Int")
        if (ok && (flags & 0x2) && (alpha = 5)) {
            try WinSetTransparent(255, "ahk_id " hwnd)
            try WinSetExStyle("-0x20", "ahk_id " hwnd)
            tit := ""
            try tit := WinGetTitle("ahk_id " hwnd)
            restaurados++
            detalles .= "`n- HWND " hwnd ": " (tit != "" ? tit : "(sin titulo)")
        }
    }
} finally {
    DetectHiddenWindows(prevDH)
}

if (restaurados > 0) {
    TrayTip("Rescate de Paneles CSP", "✅ Se restauraron " restaurados " paneles ocultos." detalles, 1)
    MsgBox("Se restauraron con exito " restaurados " paneles de Clip Studio Paint:" detalles, "Rescate de Paneles CSP", "Iconi T6")
} else {
    TrayTip("Rescate de Paneles CSP", "ℹ Todos los paneles de CSP estan en estado normal.", 1)
}

ExitApp()
