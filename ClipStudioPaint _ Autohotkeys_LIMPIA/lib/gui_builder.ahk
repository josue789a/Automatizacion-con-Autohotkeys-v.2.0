#Requires AutoHotkey v2.0
; ============================================================================
;  lib/gui_builder.ahk  -  Utilidades visuales reutilizables (Frente 2)
;  Solo funciones: no ejecuta código al incluirse, así que es seguro
;  incluirlo en cualquier posición del árbol de #Include.
;  Las coordenadas se usan tal cual; el llamador aplica _E() / DPI si lo necesita.
; ============================================================================

; ---------------------------------------------------------------------------
;  GbSetFont - Fija la fuente para los controles que se añadan DESPUÉS.
; ---------------------------------------------------------------------------
GbSetFont(guiObj, tam := 9, peso := 400, nombre := "Segoe UI", extra := "") {
    guiObj.SetFont("s" tam " w" peso (extra != "" ? " " extra : ""), nombre)
}

; ---------------------------------------------------------------------------
;  GbBoton - Botón posicionado con callback Click opcional.
;  fnCallback: Func/BoundFunc/Closure (recibe ctrl, info) o "" para ninguno.
;  Devuelve el control Button.
; ---------------------------------------------------------------------------
GbBoton(guiObj, texto, x, y, w, h, fnCallback, opts := "") {
    btn := guiObj.Add("Button"
        , Format("x{} y{} w{} h{} {}", x, y, w, h, opts), texto)
    if (fnCallback != "" && HasMethod(fnCallback))
        btn.OnEvent("Click", fnCallback)
    return btn
}

; ---------------------------------------------------------------------------
;  GbEditConCue - Edit de una línea con placeholder gris (cue banner) y
;  reserva opcional de margen derecho (p. ej. para un botón/icono superpuesto).
;  Devuelve el control Edit.
;  Nota: EM_SETCUEBANNER no se muestra en Edits multilínea (no usar +Multi).
; ---------------------------------------------------------------------------
GbEditConCue(guiObj, cueText, x, y, w, h, margenDer := 0, opts := "") {
    ed := guiObj.Add("Edit"
        , Format("x{} y{} w{} h{} {}", x, y, w, h, opts))
    ; Cue Banner gris: EM_SETCUEBANNER = 0x1501 (wParam=1: visible aun con foco)
    try SendMessage(0x1501, 1, StrPtr(cueText), ed.Hwnd)
    ; Margen derecho: EM_SETMARGINS = 0xD3, EC_RIGHTMARGIN = 2, valor en HIWORD
    if (margenDer > 0)
        try SendMessage(0xD3, 2, margenDer << 16, ed.Hwnd)
    return ed
}

; ---------------------------------------------------------------------------
;  GbParLabelEdit - Etiqueta + Edit con cue en la misma fila.
;  w = ancho TOTAL del par; el Edit ocupa (w - wLabel).
;  La etiqueta se centra verticalmente respecto al alto h (SS_CENTERYOFFSET).
;  opts se aplica al Edit.
;  Devuelve un objeto con las propiedades .Label y .Edit.
; ---------------------------------------------------------------------------
GbParLabelEdit(guiObj, labelText, cueText, x, y, w, h, wLabel := 80, opts := "") {
    lbl := guiObj.Add("Text"
        , Format("x{} y{} w{} h{} +0x200", x, y, wLabel, h), labelText)
    ed := GbEditConCue(guiObj, cueText, x + wLabel, y, Max(w - wLabel, 1), h, 0, opts)
    return {Label: lbl, Edit: ed}
}
