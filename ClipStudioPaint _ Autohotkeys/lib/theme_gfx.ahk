#Requires AutoHotkey v2.0
; [LIB] theme_gfx — fuente: XPPEN AHK VERSION ESTABLE.ahk L5518–5716 y L5871–6057
_SetIcono(ctrl,nombre,esON := false) {
    static ultima := Map()
    if !IsObject(ctrl)
        return
    ruta := _RutaIcono(nombre)
    if (ruta != "") {
        if (ultima.Get(ctrl,"") = ruta)
            return
        try {
            ctrl.Value := ruta
            ultima[ctrl] := ruta
        }
        return
    }
    try ultima.Delete(ctrl)
    cod := _Glifo(nombre)
    if cod
        _Glifizar(ctrl,cod,esON)
}
_Glifizar(ctrl,cod,esON) {
    if !IsObject(ctrl)
        return false
    try {
        ctrl.Value := Chr(cod)
        ctrl.SetFont("s" _E(12) " c" _ColorIcono(esON),"Segoe Fluent Icons")
        return true
    }
    return false
}
_ColorIcono(esON) {
    ; El icono va siempre un punto por encima del label: FFFFFF en ON para que
    ; un glifo fino de ~15 px se lea sobre 636D83; icon.off (B2B2B2 por defecto)
    ; en OFF: legible sobre surface.off y distinto del ON de un vistazo.
    return esON ? "FFFFFF" : _Tema("color","icon.off","B2B2B2")
}
_Glifo(nombre) {
    static mapa := Map(
        "slider_on",0xE9E9,  "slider_off",0xE9E9,
        "circle_on",0xE790,  "circle_off",0xE790,
        "quick_on",0xE71D,   "quick_off",0xE71D,
        "hist_on",0xE81C,    "hist_off",0xE81C,
        "lock_closed",0xE72E,"lock_open",0xE785,
        "pin_on",0xE718,     "pin_off",0xE77A,
        "calib",0xE707,      "reload_g",0xE72C
    )
    return mapa.Has(nombre) ? mapa[nombre] : 0
}
_RutaIcono(nombre) {
    ; Respaldo real de iconos: PNG sueltos en disco. Si algun dia aparecen,
    ; se usan sin tocar codigo. La maquinaria base64 que habia aqui era un
    ; placeholder vacio que siempre devolvia false (se retiro en la ola 7;
    ; sigue en el .bak de esa ola si hiciera falta).
    arch := "csp2_" nombre ".png"
    ruta := A_ScriptDir "\iconos\" arch
    if FileExist(ruta)
        return ruta
    suelto := A_ScriptDir "\" arch
    if FileExist(suelto)
        return suelto
    return ""
}
; === F1-BEGIN ===
; F1: tema. Sin globales (lo posterior al primer #HotIf no ejecuta asignaciones globales).
_Tema(seccion,clave,defecto := "") {
    static cache := Map(), iniTema := A_ScriptDir "\theme.ini"
    if (seccion = "*") {   ; P3: _TemaRecargar() vacia la cache (selector de paleta)
        cache.Clear()
        return ""
    }
    k := seccion "|" clave
    if cache.Has(k)
        return cache[k]
    v := defecto
    try {
        leido := Trim(IniRead(iniTema,seccion,clave,""))
        if (leido != "" && _TemaValido(seccion,leido,defecto))
            v := (seccion = "color") ? StrUpper(leido) : leido
    }
    cache[k] := v
    return v
}
_TemaValido(seccion,v,defecto) {
    if (seccion = "color")
        return RegExMatch(v,"^[0-9A-Fa-f]{6}$") > 0
    if IsInteger(defecto)
        return IsInteger(v) && Integer(v) >= 0 && Integer(v) <= (seccion = "alpha" ? 255 : 4096)
    return !RegExMatch(v,"[\x3B\r\n]")
}
_FuenteInstalada(nombre) {
    static cache := Map()
    if cache.Has(nombre)
        return cache[nombre]
    hallada := false
    for raiz in ["HKLM","HKCU"] {
        if hallada
            break
        try {
            Loop Reg raiz "\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts","V" {
                if (InStr(A_LoopRegName,nombre) = 1) {
                    hallada := true
                    break
                }
            }
        }
    }
    cache[nombre] := hallada
    return hallada
}
_TemaFuente(rol := "texto") {
    if (rol = "iconos")
        cadena := ["Segoe Fluent Icons","Segoe MDL2 Assets"]
    else if (rol = "valor")
        cadena := [_Tema("type","family.value","Cascadia Mono"),"Consolas","Segoe UI"]
    else
        cadena := [_Tema("type","family","Segoe UI"),"Segoe UI"]
    for nombre in cadena {
        if _FuenteInstalada(nombre)
            return nombre
    }
    return "Segoe UI"
}
_RolDeHex(hex) {
    static m := Map(
        "00E5FF","info","1C6EA4","info","1A5276","info","1A2E5C","info",
        "44DD88","ok","1E8449","ok","27AE60","ok","51D67B","ok",
        "1A5C2A","ok","32CD32","ok","2ECC71","ok","FF6B00","warn",
        "FF8C42","warn","AA8844","warn","FFAA33","warn","FF6F61","warn",
        "FF4444","danger","C0392B","danger","E74C3C","danger","922B21","danger",
        "9A7BFF","estab","AA44FF","estab","6C3483","estab","1A1A2E","neutral",
        "888888","neutral","555555","neutral","9AA7C7","neutral","2B3B32","neutral",
        "222222","neutral","EEEEEE","neutral","424949","neutral"
    )
    h := StrUpper(hex)
    return m.Has(h) ? m[h] : ""
}
; Identidad hasta que theme.ini tenga [fx] roles = 1. Los "neutral" nunca se mapean (EEEEEE es fondo claro).
_AvisoColor(hex) {
    if (_Tema("fx","roles","0") != "1")
        return hex
    rol := _RolDeHex(hex)
    tokens := Map("info","accent.info","ok","accent.success","warn","accent.warn","danger","accent.danger","estab","accent.estab")
    return (rol != "" && tokens.Has(rol)) ? _Tema("color",tokens[rol],hex) : hex
}
; === F1-END ===
; === F2-BEGIN ===
_AlphaTema(clave, defecto) {
    v := _Tema("alpha", clave, String(defecto))
    return (IsInteger(v) && Integer(v) >= 0 && Integer(v) <= 255) ? Integer(v) : defecto
}
; Redondeo por región (sin DWM): esquinas limpias y SIN drop shadow.
; Mantiene el nombre y la clave "fx/corners" para no tocar los puntos de llamada.
;   corners: 0/otro = sin cambios | 1 = cuadrado | 2 = redondeo normal | 3 = redondeo pequeño
_DwmRedondear(hwnd) {
    v := _Tema("fx", "corners", "0")
    if !(IsInteger(v) && Integer(v) >= 1 && Integer(v) <= 3)
        return false
    v := Integer(v)

    ; Anular cualquier sombra residual del frame DWM (atributo 2 = NCRENDERING_POLICY, 1 = DISABLED)
    buf := Buffer(4, 0)
    NumPut("int", 1, buf)
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 2, "Ptr", buf, "UInt", 4)

    ; v=1 → quitar región (cuadrado)
    if (v = 1) {
        DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", 0, "Int", true)
        return true
    }

    ; Radio en px; el 3er/4to parámetro de CreateRoundRectRgn es el DIÁMETRO (2*radio)
    radio := (v = 2) ? 6 : 3
    GetWindowRectSize(hwnd, &w, &h)
    if (w <= 0 || h <= 0)
        return false

    ; right/bottom son exclusivos → +1
    hRgn := DllCall("gdi32\CreateRoundRectRgn"
        , "Int", 0, "Int", 0, "Int", w + 1, "Int", h + 1
        , "Int", radio * 2, "Int", radio * 2, "Ptr")
    if !hRgn
        return false

    ; Tras SetWindowRgn el sistema es dueño de hRgn: NO llamar DeleteObject
    return DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", hRgn, "Int", true) != 0
}

GetWindowRectSize(hwnd, &w, &h) {
    rc := Buffer(16, 0)
    if !DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rc) {
        w := h := 0
        return
    }
    w := NumGet(rc, 8, "Int") - NumGet(rc, 0, "Int")
    h := NumGet(rc, 12, "Int") - NumGet(rc, 4, "Int")
}
; D7 (chip interior) cerrado en la ola 7: el redondeo se hace con _DwmRedondear sobre
; la ventana, no con regiones en controles hijos. PillRegion() se retiro por no tener
; ningun consumidor (0 referencias) y no ser fiable en hijos (spike ola 0).
; === F2-END ===
; === F3-GFX-BEGIN ===
; F3 (Claude 2): iconos vectoriales GDI+ + máscara redondeada. Sin globales: todo el estado vive en static.
; API pública: GfxIconoLienzo(nombre, tam, esON, fondo)  |  GfxMascaraRedondeada(hwnd, w, h, radio)

; Arranque perezoso de GDI+. Devuelve el token (0 si falla). _GfxGdipInicio(true) lo cierra.
_GfxGdipInicio(cerrar := false) {
    static token := 0, alSalir := false
    if cerrar {
        if token
            DllCall("gdiplus\GdiplusShutdown", "Ptr", token)
        token := 0
        return 0
    }
    if token
        return token
    if !DllCall("GetModuleHandle", "Str", "gdiplus", "Ptr")
        DllCall("LoadLibrary", "Str", "gdiplus")
    si := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
    NumPut("UInt", 1, si)
    t := 0
    if DllCall("gdiplus\GdiplusStartup", "Ptr*", &t, "Ptr", si, "Ptr", 0) != 0
        return 0
    token := t
    if !alSalir {
        OnExit(_GfxGdipAlSalir)   ; se suma a _AudAlSalir y demás, no los reemplaza
        alSalir := true
    }
    return token
}
_GfxGdipAlSalir(*) {
    _GfxGdipInicio(true)
}
_GfxPen(argb, ancho) {
    pen := 0
    DllCall("gdiplus\GdipCreatePen1", "UInt", argb, "Float", ancho, "Int", 2, "Ptr*", &pen)
    if pen {
        DllCall("gdiplus\GdipSetPenLineCap197819", "Ptr", pen, "Int", 2, "Int", 2, "Int", 2)  ; extremos redondos
        DllCall("gdiplus\GdipSetPenLineJoin", "Ptr", pen, "Int", 2)
    }
    return pen
}
_GfxLinea(g, pen, s, x1, y1, x2, y2) {
    DllCall("gdiplus\GdipDrawLine", "Ptr", g, "Ptr", pen
        , "Float", x1*s, "Float", y1*s, "Float", x2*s, "Float", y2*s)
}
; Lupa (Z): círculo + mango + "+" interior. Rejilla de 24 unidades.
_GfxDibujaLupa(g, argb, s) {
    pen := _GfxPen(argb, 2.2*s)
    if !pen
        return
    DllCall("gdiplus\GdipDrawEllipse", "Ptr", g, "Ptr", pen
        , "Float", 3.2*s, "Float", 3.2*s, "Float", 13*s, "Float", 13*s)
    _GfxLinea(g, pen, s, 15.2, 15.2, 20.6, 20.6)
    _GfxLinea(g, pen, s, 7.2, 9.7, 12.2, 9.7)
    _GfxLinea(g, pen, s, 9.7, 7.2, 9.7, 12.2)
    DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
}
; Flecha circular (R): arco de 270° (de 315° a 225°, horario) + punta rellena en el extremo.
_GfxDibujaRotar(g, argb, s) {
    pen := _GfxPen(argb, 2.2*s)
    if !pen
        return
    DllCall("gdiplus\GdipDrawArc", "Ptr", g, "Ptr", pen
        , "Float", 4.5*s, "Float", 4.5*s, "Float", 15*s, "Float", 15*s
        , "Float", 315, "Float", 270)
    DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
    rad := ATan(1) * 4 / 180
    th := 225 * rad
    px := 12 + 7.5 * Cos(th), py := 12 + 7.5 * Sin(th)   ; extremo del arco
    tx := -Sin(th), ty := Cos(th)                         ; tangente (sentido horario)
    nx := Cos(th),  ny := Sin(th)                         ; radial
    pts := Buffer(24, 0)
    NumPut("Float", (px + tx*4.2) * s,            "Float", (py + ty*4.2) * s
         , "Float", (px + nx*3.6 - tx*0.8) * s,   "Float", (py + ny*3.6 - ty*0.8) * s
         , "Float", (px - nx*3.6 - tx*0.8) * s,   "Float", (py - ny*3.6 - ty*0.8) * s, pts)
    br := 0
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", argb, "Ptr*", &br)
    if br {
        DllCall("gdiplus\GdipFillPolygon", "Ptr", g, "Ptr", br, "Ptr", pts, "Int", 3, "Int", 0)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
    }
}
; Mano (Space): 4 dedos + palma + pulgar, todo con trazos gruesos de extremo redondo.
_GfxDibujaMano(g, argb, s) {
    pen := _GfxPen(argb, 2.6*s)
    if !pen
        return
    _GfxLinea(g, pen, s,  8.4, 6.5,  8.4, 14)     ; índice
    _GfxLinea(g, pen, s, 12.0, 5.0, 12.0, 14)     ; medio
    _GfxLinea(g, pen, s, 15.6, 6.0, 15.6, 14)     ; anular
    _GfxLinea(g, pen, s, 19.2, 8.5, 19.2, 14.5)   ; meñique
    _GfxLinea(g, pen, s,  7.3, 16.5, 4.3, 12.8)   ; pulgar
    DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
    pal := _GfxPen(argb, 7*s)
    if pal {
        _GfxLinea(g, pal, s, 9.5, 17, 17.5, 17)   ; palma (cápsula)
        DllCall("gdiplus\GdipDeletePen", "Ptr", pal)
    }
}
; Devuelve un HBITMAP (0 si falla) listo para Picture: ctrl.Value := "HBITMAP:" hbm
;   nombre: "z" | "r" | "space"   tam: px (8..256)   esON: color ON/OFF del tema
;   fondo: RGB hex opcional (6 dígitos); por defecto surface.on / surface.off del tema
; El bitmap es opaco (se pinta sobre el fondo) y queda en caché por nombre|tam|color|fondo:
; NO llamar DeleteObject sobre el handle devuelto.
GfxIconoLienzo(nombre, tam := 24, esON := false, fondo := "") {
    static cache := Map()
    nombre := StrLower(Trim(nombre))
    if !(nombre = "z" || nombre = "r" || nombre = "space")
        return 0
    tam := IsNumber(tam) ? Max(8, Min(256, Round(tam))) : 24
    fg := _ColorIcono(esON)
    if !RegExMatch(fondo, "^[0-9A-Fa-f]{6}$")
        fondo := esON ? _Tema("color", "surface.on", "636D83") : _Tema("color", "surface.off", "474747")
    clave := nombre "|" tam "|" fg "|" StrUpper(fondo)
    if cache.Has(clave)
        return cache[clave]
    if !_GfxGdipInicio()
        return 0
    bmp := 0
    if DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", tam, "Int", tam, "Int", 0
        , "Int", 0xE200B, "Ptr", 0, "Ptr*", &bmp) != 0 || !bmp
        return 0
    g := 0
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &g)
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g, "Int", 4)
    DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", g, "Int", 2)
    DllCall("gdiplus\GdipGraphicsClear", "Ptr", g, "UInt", Integer("0xFF" fondo))
    argb := Integer("0xFF" fg)
    s := tam / 24
    switch nombre {
        case "z":     _GfxDibujaLupa(g, argb, s)
        case "r":     _GfxDibujaRotar(g, argb, s)
        case "space": _GfxDibujaMano(g, argb, s)
    }
    hbm := 0
    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", bmp, "Ptr*", &hbm, "UInt", Integer("0xFF" fondo))
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", bmp)
    if hbm
        cache[clave] := hbm
    return hbm
}
; Esquinas redondeadas sin cuadrado negro (región, no depende de theme.ini ni de fx/corners).
;   hwnd: handle o objeto Gui | w,h: px físicos (0 = leer con GetWindowRectSize) | radio: px físicos (0 = quita la región)
; Hay que re-llamarla si la ventana cambia de tamaño. Tras SetWindowRgn el sistema es dueño de la región.
GfxMascaraRedondeada(hwnd, w := 0, h := 0, radio := 8) {
    if IsObject(hwnd)
        try hwnd := hwnd.Hwnd
    if !hwnd
        return false
    if (w <= 0 || h <= 0)
        GetWindowRectSize(hwnd, &w, &h)
    if (w <= 0 || h <= 0)
        return false
    radio := Max(0, Min(Integer(radio), Min(w, h) // 2))
    if (radio = 0) {
        DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", 0, "Int", true)
        return true
    }
    ; Win11: que DWM no añada su propio redondeo/borde encima de la región (33 = CORNER_PREFERENCE, 1 = DONOTROUND)
    pref := Buffer(4, 0)
    NumPut("Int", 1, pref)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 33, "Ptr", pref, "UInt", 4)
    hRgn := DllCall("gdi32\CreateRoundRectRgn"
        , "Int", 0, "Int", 0, "Int", w + 1, "Int", h + 1
        , "Int", radio * 2, "Int", radio * 2, "Ptr")
    if !hRgn
        return false
    return DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", hRgn, "Int", true) != 0
}
; === F3-GFX-END ===
; === P3-PALETA-BEGIN ===
; P3: Selector de paletas y temas armónicos para CSP Companion.
; Incluye 5 perfiles pre-diseñados (con réplica 1:1 de Clip Studio Paint).
; Guarda automáticamente en theme.ini y refresca todas las interfaces en vivo.

_TemaRecargar() => _Tema("*","*")

_TemaSelEst() {
    static est := {g:0, st:0}
    return est
}

_TemaPerfiles() {
    return [
        {
            nombre: "1. CSP Réplica Nativa (Oscuro CSP)",
            desc: "Idéntico a los paneles, barras y botones activos de Clip Studio Paint",
            swatches: ["636C82", "474747", "C8CEDE", "9A7BFF", "363636"],
            tokens: Map(
                "surface.on", "636C82",
                "surface.off", "474747",
                "surface.reload", "3B7A4B",
                "accent.estabSoft", "C8CEDE",
                "track.pillOff", "5A5A5A",
                "accent.estab", "9A7BFF",
                "text.primary", "FFFFFF",
                "text.idle", "B2B2B2",
                "surface.estabOpen", "363636",
                "surface.estabLocked", "282828",
                "track.off", "3A3A3A",
                "icon.off", "B8B8B8"
            )
        },
        {
            nombre: "2. Grafito Carbón (Minimalismo)",
            desc: "Tonos neutros puros sin tintes de color para máxima concentración",
            swatches: ["525252", "333333", "999999", "CCCCCC", "2A2A2A"],
            tokens: Map(
                "surface.on", "525252",
                "surface.off", "333333",
                "surface.reload", "405948",
                "accent.estabSoft", "999999",
                "track.pillOff", "454545",
                "accent.estab", "CCCCCC",
                "text.primary", "F0F0F0",
                "text.idle", "8A8A8A",
                "surface.estabOpen", "2A2A2A",
                "surface.estabLocked", "202020",
                "track.off", "333333",
                "icon.off", "8A8A8A"
            )
        },
        {
            nombre: "3. Slate Blue / Studio Pro (Wacom)",
            desc: "Azul pizarra digital moderno inspirado en herramientas de ilustración",
            swatches: ["4E6982", "343B47", "7AA2F7", "7DCFFF", "2A313D"],
            tokens: Map(
                "surface.on", "4E6982",
                "surface.off", "343B47",
                "surface.reload", "2E6B4F",
                "accent.estabSoft", "7AA2F7",
                "track.pillOff", "465162",
                "accent.estab", "7DCFFF",
                "text.primary", "FFFFFF",
                "text.idle", "A0AEC0",
                "surface.estabOpen", "2A313D",
                "surface.estabLocked", "1E232B",
                "track.off", "3B4452",
                "icon.off", "A0AEC0"
            )
        },
        {
            nombre: "4. OLED Alto Contraste",
            desc: "Negros profundos y barras luminosas para pantallas oscuras o dibujo con luz solar",
            swatches: ["737B8C", "1E1E1E", "E6EDF8", "B388FF", "141414"],
            tokens: Map(
                "surface.on", "737B8C",
                "surface.off", "1E1E1E",
                "surface.reload", "2E7D32",
                "accent.estabSoft", "E6EDF8",
                "track.pillOff", "3A3A3A",
                "accent.estab", "B388FF",
                "text.primary", "FFFFFF",
                "text.idle", "CCCCCC",
                "surface.estabOpen", "141414",
                "surface.estabLocked", "0A0A0A",
                "track.off", "2A2A2A",
                "icon.off", "CCCCCC"
            )
        },
        {
            nombre: "5. Sepia / Warm Paper (Estudio)",
            desc: "Tonos tierra orgánicos que descansan la vista emulando papel tradicional",
            swatches: ["6B5E57", "423B38", "D4B996", "E09F67", "36302D"],
            tokens: Map(
                "surface.on", "6B5E57",
                "surface.off", "423B38",
                "surface.reload", "556B2F",
                "accent.estabSoft", "D4B996",
                "track.pillOff", "524944",
                "accent.estab", "E09F67",
                "text.primary", "FFF8F0",
                "text.idle", "B8ABA0",
                "surface.estabOpen", "36302D",
                "surface.estabLocked", "292422",
                "track.off", "3D3734",
                "icon.off", "B8ABA0"
            )
        },
        {
            nombre: "6. CSP Medida Exacta (Píxel a Píxel)",
            desc: "Valores medidos de la interfaz real de CSP: menú 494949, paneles 424242, selección 636D83",
            swatches: ["636D83", "494949", "6A748A", "9AA8CC", "424242"],
            tokens: Map(
                "surface.on", "636D83",
                "surface.off", "494949",
                "surface.reload", "3B7A4B",
                "accent.estabSoft", "6A748A",
                "track.pillOff", "5C5C5C",
                "accent.estab", "9AA8CC",
                "text.primary", "F4F4F4",
                "text.idle", "C4C4C4",
                "surface.estabOpen", "424242",
                "surface.estabLocked", "2E2E2E",
                "track.off", "3A3A3A",
                "icon.off", "C4C4C4"
            )
        },
        {
            nombre: "7. Carbón de Paneles (CSP Neutro)",
            desc: "Neutros de paneles y barras de CSP sin azul: máxima calma para sesiones largas",
            swatches: ["5C5C5C", "424242", "9AA3B8", "7F8BA8", "2E2E2E"],
            tokens: Map(
                "surface.on", "5C5C5C",
                "surface.off", "424242",
                "surface.reload", "3D7A50",
                "accent.estabSoft", "9AA3B8",
                "track.pillOff", "515151",
                "accent.estab", "7F8BA8",
                "text.primary", "DCDCDC",
                "text.idle", "B4B4B4",
                "surface.estabOpen", "2E2E2E",
                "surface.estabLocked", "232323",
                "track.off", "3A3A3A",
                "icon.off", "B4B4B4"
            )
        },
        {
            nombre: "8. Pizarra Azul de Selección",
            desc: "Azul pizarra de la pestaña y la capa activas de CSP llevado a todo el panel",
            swatches: ["5F6B86", "3E4452", "B4BEDB", "86A8FF", "2F3441"],
            tokens: Map(
                "surface.on", "5F6B86",
                "surface.off", "3E4452",
                "surface.reload", "3A7D5A",
                "accent.estabSoft", "B4BEDB",
                "track.pillOff", "4D5568",
                "accent.estab", "86A8FF",
                "text.primary", "F4F4F4",
                "text.idle", "BAC2D6",
                "surface.estabOpen", "2F3441",
                "surface.estabLocked", "23262F",
                "track.off", "343945",
                "icon.off", "BAC2D6"
            )
        },
        {
            nombre: "9. Nocturno OLED (Negro Profundo)",
            desc: "Fondos casi negros con selección azul apagada y acento menta, para estudio sin luz",
            swatches: ["3D4660", "121212", "8B97B8", "5EEAD4", "0A0A0A"],
            tokens: Map(
                "surface.on", "3D4660",
                "surface.off", "121212",
                "surface.reload", "2E7D4F",
                "accent.estabSoft", "8B97B8",
                "track.pillOff", "2A2A2A",
                "accent.estab", "5EEAD4",
                "text.primary", "EDEDED",
                "text.idle", "A0A0A0",
                "surface.estabOpen", "0A0A0A",
                "surface.estabLocked", "000000",
                "track.off", "1C1C1C",
                "icon.off", "9A9A9A"
            )
        },
        {
            nombre: "10. Carbón Cálido (Arena)",
            desc: "Grises de CSP con matiz arena y acento ámbar suave para reducir la luz fría",
            swatches: ["6E665F", "484543", "CDBFA9", "E3B87A", "3A3836"],
            tokens: Map(
                "surface.on", "6E665F",
                "surface.off", "484543",
                "surface.reload", "5C7A3E",
                "accent.estabSoft", "CDBFA9",
                "track.pillOff", "5A5652",
                "accent.estab", "E3B87A",
                "text.primary", "F4EFE8",
                "text.idle", "C2BBB2",
                "surface.estabOpen", "3A3836",
                "surface.estabLocked", "2A2927",
                "track.off", "383634",
                "icon.off", "C2BBB2"
            )
        },
        {
            nombre: "11. Alto Contraste Accesible",
            desc: "Blanco y amarillo sobre negro con selección azul intenso; legibilidad máxima",
            swatches: ["3355B8", "202020", "FFFFFF", "FFD60A", "121212"],
            tokens: Map(
                "surface.on", "3355B8",
                "surface.off", "202020",
                "surface.reload", "1B8A3A",
                "accent.estabSoft", "FFFFFF",
                "track.pillOff", "4A4A4A",
                "accent.estab", "FFD60A",
                "text.primary", "FFFFFF",
                "text.idle", "E0E0E0",
                "surface.estabOpen", "121212",
                "surface.estabLocked", "000000",
                "track.off", "303030",
                "icon.off", "E0E0E0"
            )
        },
        {
            nombre: "12. Verde Estudio (Salvia)",
            desc: "Verdes salvia desaturados sobre carbón verdoso; descanso visual con acento menta",
            swatches: ["56705F", "3F4843", "B7D3BF", "7BE0A0", "333B37"],
            tokens: Map(
                "surface.on", "56705F",
                "surface.off", "3F4843",
                "surface.reload", "2F9E5B",
                "accent.estabSoft", "B7D3BF",
                "track.pillOff", "4F5A53",
                "accent.estab", "7BE0A0",
                "text.primary", "F2F7F3",
                "text.idle", "B9C6BD",
                "surface.estabOpen", "333B37",
                "surface.estabLocked", "262C29",
                "track.off", "363D39",
                "icon.off", "B9C6BD"
            )
        },
        {
            nombre: "13. Violeta de Acento (Ciruela)",
            desc: "Grises violáceos con acento lavanda, afín al color de acento del estabilizador",
            swatches: ["6B5F8C", "3E3A4A", "CFC4F2", "B39DFF", "2F2C3A"],
            tokens: Map(
                "surface.on", "6B5F8C",
                "surface.off", "3E3A4A",
                "surface.reload", "3B7A4B",
                "accent.estabSoft", "CFC4F2",
                "track.pillOff", "50495F",
                "accent.estab", "B39DFF",
                "text.primary", "F5F2FF",
                "text.idle", "BDB8D0",
                "surface.estabOpen", "2F2C3A",
                "surface.estabLocked", "232130",
                "track.off", "36323F",
                "icon.off", "BDB8D0"
            )
        },
        {
            nombre: "14. Ámbar Taller (Cobre)",
            desc: "Base neutra de CSP con selección cobre y acento ámbar encendido, como luz de lámpara",
            swatches: ["8A6A3B", "464646", "FFD98A", "FFB000", "363636"],
            tokens: Map(
                "surface.on", "8A6A3B",
                "surface.off", "464646",
                "surface.reload", "3F8A4F",
                "accent.estabSoft", "FFD98A",
                "track.pillOff", "575757",
                "accent.estab", "FFB000",
                "text.primary", "F8F8F8",
                "text.idle", "BEBEBE",
                "surface.estabOpen", "363636",
                "surface.estabLocked", "262626",
                "track.off", "3A3A3A",
                "icon.off", "BEBEBE"
            )
        },
        {
            nombre: "15. Claro Gris CSP (Modo Día)",
            desc: "Variante clara: grises suaves y selección pizarra con texto oscuro, para luz de día",
            swatches: ["AEB8D2", "D0D0D0", "5F6B8A", "4466D8", "E4E4E4"],
            tokens: Map(
                "surface.on", "AEB8D2",
                "surface.off", "D0D0D0",
                "surface.reload", "7FC48F",
                "accent.estabSoft", "5F6B8A",
                "track.pillOff", "A8A8A8",
                "accent.estab", "4466D8",
                "text.primary", "1E1E1E",
                "text.idle", "4A4A4A",
                "surface.estabOpen", "E4E4E4",
                "surface.estabLocked", "BEBEBE",
                "track.off", "C0C0C0",
                "icon.off", "4A4A4A"
            )
        }
    ]
}

_AbrirSelectorTema() {
    est := _TemaSelEst()
    if IsObject(est.g) {
        try {
            est.g.Show()
            return
        }
        est.g := 0
    }
    ventana := Gui("+AlwaysOnTop -MaximizeBox","🎨 Paletas de Tema — Clip Studio Companion")
    ventana.SetFont("s9","Segoe UI")
    ventana.Add("Text","xm w520 cGray","Elige un perfil de color armónico. Se guarda en theme.ini y se aplica al instante:")

    perfiles := _TemaPerfiles()
    for idx, p in perfiles {
        ventana.SetFont("s10 bold")
        ventana.Add("Text","xm y+14 w320",p.nombre)
        ventana.SetFont("s8 cGray")
        ventana.Add("Text","xm y+1 w320",p.desc)
        ventana.SetFont("s9 norm")

        swX := 330, swY := "yp-16"
        for hex in p.swatches {
            sw := ventana.Add("Progress","x" swX " " swY " w22 h26 +Border c" hex " Background" hex)
            sw.Value := 100
            swX += 25
            swY := "yp"
        }

        btn := ventana.Add("Button","x465 yp w80 h26","Aplicar")
        btn.OnEvent("Click",_TemaSelAplicarPerfil.Bind(p))
    }

    est.st := ventana.Add("Text","xm y+18 w545 h22 c007ACC","")
    btnCerrar := ventana.Add("Button","xm y+6 w120 h28 Default","Cerrar")
    btnCerrar.OnEvent("Click",_TemaSelCerrar)
    ventana.OnEvent("Close",_TemaSelCerrar)
    ventana.OnEvent("Escape",_TemaSelCerrar)
    est.g := ventana
    ventana.Show("AutoSize")
}

_TemaSelCerrar(*) {
    est := _TemaSelEst()
    ventana := est.g
    est.g := 0
    if IsObject(ventana)
        try ventana.Destroy()
}

_TemaSelAplicarPerfil(perfil, *) {
    est := _TemaSelEst()
    iniPath := A_ScriptDir "\theme.ini"
    try {
        for clave, hex in perfil.tokens {
            IniWrite(hex, iniPath, "color", clave)
        }
    } catch {
        try est.st.Value := "⚠ Error al escribir en theme.ini"
        return
    }
    _TemaRecargar()
    _TemaRefrescarPaneles()
    try est.st.Value := "✔ Paleta aplicada: " perfil.nombre
}

_TemaRefrescarPaneles() {
    for fnPanel in [ActualizarDsGUI,ActualizarCcGUI,ActualizarArGUI,ActualizarHCGUI,ActualizarLockGUI,ActualizarFrenteGUI,ActualizarEstabBtnGUI] {
        try fnPanel()
    }
    try reloadGui.g.BackColor := _Tema("color","surface.reload","3B7A4B")
    try puntosGui.g.BackColor := _Tema("color","surface.off","424242")
    try ActualizarEstabGUI(-1,true)
}
; === P3-PALETA-END ===
