#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode("Mouse", "Screen")
SetTitleMatchMode(2)

puntos := []

ObtenerCSPHwnd() {
    bestHwnd := 0
    bestArea := 0
    for hwnd in WinGetList("ahk_exe CLIPStudioPaint.exe") {
        try {
            WinGetPos(&tx, &ty, &tw, &th, "ahk_id " hwnd)
            if (tw * th > bestArea) {
                bestArea := tw * th
                bestHwnd := hwnd
            }
        }
    }
    return bestHwnd
}

; F1 — captura punto con GetCursorPos (coordenadas físicas absolutas)
F1:: {
    pt := Buffer(8, 0)
    DllCall("GetCursorPos", "ptr", pt)
    x := NumGet(pt, 0, "int")
    y := NumGet(pt, 4, "int")
    puntos.Push({ x: x, y: y })
    n := puntos.Length
    ToolTip("P" n ": (" x ", " y ")  —  Total: " n "`nF2=copiar todo  F3=limpiar  F4=datos CSP")
    SetTimer(() => ToolTip(), -2000)
}

; F2 — copia puntos al portapapeles
F2:: {
    if (puntos.Length = 0) {
        ToolTip("No hay puntos capturados")
        SetTimer(() => ToolTip(), -1500)
        return
    }
    texto := ""
    for i, p in puntos
        texto .= "P" i ": (" p.x ", " p.y ")`n"
    A_Clipboard := texto
    ToolTip("✅ " puntos.Length " puntos copiados")
    SetTimer(() => ToolTip(), -2000)
}

; F3 — limpia lista
F3:: {
    puntos := []
    ToolTip("🗑 Lista limpiada")
    SetTimer(() => ToolTip(), -1000)
}

; F11 — captura datos de ventana CSP y los copia al portapapeles
F11:: {
    hwnd := ObtenerCSPHwnd()
    if (!hwnd) {
        ToolTip("❌ CSP no encontrado")
        SetTimer(() => ToolTip(), -2000)
        return
    }
    WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
    texto := "CSP: x=" wx "  y=" wy "  w=" ww "  h=" wh
    A_Clipboard := texto
    ToolTip(texto . "`n(copiado al portapapeles)")
    SetTimer(() => ToolTip(), -4000)
}

Escape:: ExitApp()
