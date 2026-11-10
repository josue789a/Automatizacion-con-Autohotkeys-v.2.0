#Requires AutoHotkey v2.0
; [LIB] hud_badges — fuente: XPPEN AHK VERSION ESTABLE.ahk L1765–1808 y L1859–2347
_CheckGitDone() {
    MostrarHUD("✅ GitHub actualizado","44DD88",2000)
    _SonarUI("guardar")
}
ResetEstadoAltX() {
    sel.estadoAltX := false
    sel.guiActivo := false
}
__ResetEstadoC() => sel.estadoC := 0
_DestruirGui(guiObj) {
    if !IsObject(guiObj)
        return
    try {
        if (guiObj.Hwnd && DllCall("IsWindow", "Ptr", guiObj.Hwnd)) {
            DllCall("ShowWindow", "Ptr", guiObj.Hwnd, "Int", 0)
            DllCall("DestroyWindow", "Ptr", guiObj.Hwnd)
        }
        guiObj.Destroy()
    }
}
_LimpiarGUIs() {
    _AvisoCerrarBadge()
    _AvisoCerrarHUD()
    _DestruirGui(floatGui.hud)
    floatGui.hud := 0
    floatGui.hudHwnd := 0
    floatGui.hudLabel := 0
    floatGui.hudBar := 0
    _DestruirGui(floatGui.miniTip)
    floatGui.miniTip := 0
    floatGui.miniTipID := 0
    floatGui.miniTipTick := 0
    _DestruirGui(floatGui.tooltipToggle)
    floatGui.tooltipToggle := 0
    _DestruirGui(floatGui.miniGUI)
    floatGui.miniGUI := 0
    _DestruirGui(floatGui.enfoque)
    floatGui.enfoque := 0
    enfoque.activo := false
    OcultarGUIEnfoque()
    _DestruirGui(floatGui.overlayIcon)
    floatGui.overlayIcon := 0
    floatGui.overlayIconID := 0
}
; ==========================================================================
; AVISOS VISUALES UNIFICADOS (2 formatos x 3 zonas de prioridad)
;   Formatos : "moderno" (badge 240x72, 2 niveles) | "bruto" (HUD 208x40)
;   Zonas    : 1 = centro del lienzo | 2 = tercio superior/central | 3 = P30 (periferica)
; Opcional: definir AVISO_MONITOR_LIENZO := N (indice de monitor) para forzar la pantalla XP-Pen.
; ==========================================================================

_PosicionAviso(w,h) => _CalcularPosicionZona(3, w, h)

; Monitor del lienzo: detecta con precision la pantalla donde esta CLIP Studio Paint (XP-Pen secundaria)
_AvisoMonitorLienzo(&l, &t, &r, &b) {
    global AVISO_MONITOR_LIENZO
    n := MonitorGetCount()
    if (IsSet(AVISO_MONITOR_LIENZO) && IsNumber(AVISO_MONITOR_LIENZO) && AVISO_MONITOR_LIENZO >= 1 && AVISO_MONITOR_LIENZO <= n) {
        MonitorGet(Integer(AVISO_MONITOR_LIENZO), &l, &t, &r, &b)
        return
    }
    mon := ObtenerMonitorCSP()
    l := mon.x, t := mon.y, r := mon.x + mon.w, b := mon.y + mon.h
}

; Rango EXCLUSIVO de un evento (HUD_ev_<id>), leído directo del INI del perfil activo.
; Devuelve {x,y,w,h} o 0. Prevalece sobre la zona genérica Alta/Media/Baja.
_HudRangoEv(idEv) {
    global PERFIL
    if (idEv = "")
        return 0
    v := IniRead(_PosGuiIniPath(), _ZonaSec("Rangos"), "HUD_ev_" . idEv, "")
    if (v = "" && _ZonaSuf() != "")
        v := IniRead(_PosGuiIniPath(), _ZonaSec("Rangos", 1), "HUD_ev_" . idEv, "")
    if (v = "")
        v := IniRead(_PosGuiIniPath(), "Puntos_p" PERFIL, "HUD_ev_" . idEv, "")
    if (v = "")
        return 0
    p := StrSplit(v, ",", " `t")
    if (p.Length < 4 || !IsInteger(p[1]) || !IsInteger(p[2]) || !IsInteger(p[3]) || !IsInteger(p[4]))
        return 0
    if (Integer(p[3]) < 40 || Integer(p[4]) < 20)
        return 0
    return {x: Integer(p[1]), y: Integer(p[2]), w: Integer(p[3]), h: Integer(p[4])}
}

; Devuelve {x, y} ya recortado al monitor segun la zona de prioridad calibrada.
_CalcularPosicionZona(zona, w, h) {
    clave := (zona = 1) ? "HUD_Alta" : ((zona = 2) ? "HUD_Media" : "HUD_Baja")
    rg := ObtenerRango(clave)
    if (IsObject(rg) && IsInteger(rg.w) && IsInteger(rg.h) && rg.w >= 30 && rg.h >= 16) {
        px := rg.x + (rg.w - w) // 2
        py := rg.y + (rg.h - h) // 2
        p := _AvisoClamp(px, py, w, h)
        return {x: p[1], y: p[2]}
    }
    _AvisoMonitorLienzo(&l, &t, &r, &b)
    mw := r - l, mh := b - t
    x := l + (mw - w) // 2
    if (zona = 1)
        y := t + Round(mh * 0.42) - h // 2     ; zona 1: centro focal del lienzo
    else if (zona = 2)
        y := t + Round(mh * 0.16)              ; zona 2: tercio superior/central
    else
        y := t + Round(mh * 0.78) - h // 2     ; zona 3: tercio inferior del lienzo
    p := _AvisoClamp(x, y, w, h)
    return {x: p[1], y: p[2]}
}

_AvisoCerrarAuxiliares() {
    global floatGui
    if IsObject(floatGui.miniTip)
        _DestruirGui(floatGui.miniTip)
    if IsObject(floatGui.miniGUI)
        _DestruirGui(floatGui.miniGUI)
    if IsObject(floatGui.tooltipToggle)
        _DestruirGui(floatGui.tooltipToggle)
    if IsObject(floatGui.overlayIcon)
        _DestruirGui(floatGui.overlayIcon)
}
_AvisoCerrarBadge() {
    global floatGui, _AvisoBadgesActivos
    try SetTimer(_TimerOcultarBadge, 0)
    if (IsObject(floatGui) && IsObject(floatGui.badge)) {
        try {
            if (floatGui.badgeHwnd && DllCall("IsWindow", "Ptr", floatGui.badgeHwnd))
                DllCall("ShowWindow", "Ptr", floatGui.badgeHwnd, "Int", 0)
            floatGui.badge.Destroy()
        }
    }
    if (IsSet(_AvisoBadgesActivos) && IsObject(_AvisoBadgesActivos)) {
        for h in _AvisoBadgesActivos {
            if (h && DllCall("IsWindow", "Ptr", h))
                try DllCall("ShowWindow", "Ptr", h, "Int", 0)
        }
        _AvisoBadgesActivos := []
    }
    if IsObject(floatGui) {
        floatGui.badge := floatGui.badgeHwnd := floatGui.badgeSub := floatGui.badgeMain := floatGui.badgeSubBar := floatGui.badgeBar := 0
        floatGui.badgeTick := 0
    }
}
_TimerOcultarBadge() {
    _AvisoCerrarBadge()
}
_AvisoCerrarHUD() {
    global floatGui
    try SetTimer(_TimerOcultarHUD, 0)
    if (IsObject(floatGui) && IsObject(floatGui.hud)) {
        try {
            if (floatGui.hudHwnd && DllCall("IsWindow", "Ptr", floatGui.hudHwnd))
                DllCall("ShowWindow", "Ptr", floatGui.hudHwnd, "Int", 0)
            floatGui.hud.Hide()
        }
    }
    if IsObject(floatGui)
        floatGui.hudTick := 0
}
_TimerOcultarHUD() {
    _AvisoCerrarHUD()
}

; Desactiva el redondeo automático de esquinas de Windows 11 DWM (DWMWCP_DONOTROUND = 1).
; Asegura que los brackets a 90° de las esquinas se rendericen íntegros sin recortes elípticos.
_DwmNoRedondear(hwnd) {
    static pref := 0
    if (!pref) {
        pref := Buffer(4)
        NumPut("Int", 1, pref)
    }
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 33, "Ptr", pref.Ptr, "UInt", 4, "Int")
}

; Despachador universal irrompible: sin ventanas huérfanas ni letras superpuestas.
; formato: "moderno" | "bruto"    zona: 1 (Alta), 2 (Media), 3 (Baja)
MostrarAvisoUI(formato, textoPrincipal, subtexto := "", zona := 2, colorAcento := "00E5FF", duracion := 0, opacidad := 0, claveEv := "") {
    global AVISO_ESC, floatGui, _AvisoBadgesActivos
    f := StrLower(String(formato))
    if (f = "desactivado" || f = "ninguno" || f = "off" || f = "sin gui" || f = "0")
        return
    bruto := (f = "bruto" || f = "hud" || f = "compacto" || f = "2")
    if !(zona = 1 || zona = 2 || zona = 3)
        zona := 2
    esAnclado := (duracion = -1)
    if (!esAnclado && duracion <= 0)
        duracion := HudDuracionZona(zona)

    ; En prioridad baja (zona 3) o si el subtexto duplica el texto o dice evento/herramienta, se suprime la primera línea
    if (zona = 3 || StrLower(Trim(subtexto)) = StrLower(Trim(textoPrincipal)) || InStr(subtexto, "EVENT") || InStr(subtexto, "HERRAMIENTA"))
        subtexto := ""

    _AvisoCerrarAuxiliares()

    if (!bruto) {
        ; ---------- MODO MODERNO: Focus Brackets / Cinema HUD ----------
        _AvisoCerrarHUD()
        _AvisoCerrarBadge()

        ; Rango adaptativo: si el evento fue reubicado individualmente, manda sobre la zona
        w := Round(240 * AVISO_ESC)
        h := Round(72  * AVISO_ESC)
        px := "", py := ""
        rgEv := _HudRangoEv(claveEv)
        if (IsObject(rgEv) && IsInteger(rgEv.w) && IsInteger(rgEv.h) && rgEv.w >= 40 && rgEv.h >= 20) {
            w := Round(rgEv.w), h := Round(rgEv.h)
            px := Round(rgEv.x), py := Round(rgEv.y)
        } else {
            claveRango := (zona = 1) ? "HUD_Alta" : ((zona = 2) ? "HUD_Media" : "HUD_Baja")
            rg := ObtenerRango(claveRango)
            if (IsObject(rg) && IsInteger(rg.w) && IsInteger(rg.h) && rg.w >= 40 && rg.h >= 20) {
                w := Round(rg.w), h := Round(rg.h)
                px := Round(rg.x), py := Round(rg.y)
            }
        }
        if (px = "" || py = "") {
            p := _CalcularPosicionZona(zona, w, h)
            px := p.x, py := p.y
        }

        grande := (h >= 90)
        brazo := grande ? 16 : 10
        grosor := grande ? 3 : 2

        ; Ventana limpia con +E0x20 (click-through limpio sin artefactos DWM)
        g := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20 -DPIScale")
        g.BackColor := "12141A"
        g.MarginX := 0
        g.MarginY := 0
        hw := 0
        try hw := g.Hwnd                      ; [FIX-GUINOWIN] nunca confiar en g.Hwnd: un Q/W concurrente puede destruir g
        if (!hw)
            return
        _DwmNoRedondear(hw)

        ; Opacidad seleccionable (100% = 255, 70% = 178, 40% = 102)
        if (opacidad = 0)
            opacidad := (zona = 1) ? 70 : ((zona = 2) ? 70 : 100)
        alpha := (opacidad <= 40) ? 102 : ((opacidad <= 70) ? 178 : 255)
        WinSetTransparent(alpha, g)

        ; Esquinas luminosas (viewfinder brackets)
        xr := w - brazo, yb := h - brazo
        xr2 := w - grosor, yb2 := h - grosor
        c := "Background" colorAcento
        g.Add("Text", Format("x0 y0 w{} h{} {}", brazo, grosor, c))
        g.Add("Text", Format("x0 y0 w{} h{} {}", grosor, brazo, c))
        g.Add("Text", Format("x{} y0 w{} h{} {}", xr, brazo, grosor, c))
        g.Add("Text", Format("x{} y0 w{} h{} {}", xr2, grosor, brazo, c))
        g.Add("Text", Format("x0 y{} w{} h{} {}", yb2, brazo, grosor, c))
        g.Add("Text", Format("x0 y{} w{} h{} {}", yb, grosor, brazo, c))
        g.Add("Text", Format("x{} y{} w{} h{} {}", xr, yb2, brazo, grosor, c))
        g.Add("Text", Format("x{} y{} w{} h{} {}", xr2, yb, grosor, brazo, c))

        ; Micro-barra de acento en la base (centrada, 3 px)
        mbw := Max(30, Round(w * 0.30))
        g.Add("Text", Format("x{} y{} w{} h3 {}", (w - mbw) // 2, h - 7, mbw, c))

        ; Tipografía que se expande proporcionalmente al tamaño dibujado
        tSize := Max(10, Min(36, Round(h * 0.16)))
        sSize := grande ? 10 : 8
        tAlto := tSize * 2
        tY := (h - tAlto) // 2 + (subtexto != "" ? 8 : 0)
        ancho := Max(40, w - 24)

        if (subtexto != "") {
            g.SetFont("s" sSize " bold c9AA7C7", "Segoe UI")
            g.Add("Text", Format("x12 y{} w{} h18 Center BackgroundTrans +0x200 +0x4000", Max(4, tY - 18), ancho), subtexto)
        }
        g.SetFont("s" tSize " bold cFFFFFF", "Segoe UI")
        g.Add("Text", Format("x12 y{} w{} h{} Center BackgroundTrans +0x200 +0x4000", tY, ancho, tAlto), textoPrincipal)

        floatGui.badge := g
        floatGui.badgeHwnd := hw
        floatGui.badgeTick := A_TickCount
        _AvisoBadgesActivos.Push(hw)
        try g.Show(Format("x{} y{} w{} h{} NoActivate", px, py, w, h))
        ; [FIX-GUINOWIN] g.Show() deja correr otros hilos (Q/W): si este badge ya fue cerrado o reemplazado, abortar
        ; sin tocar g, sin DWM/Region y sin pisar el SetTimer del badge nuevo
        if (!DllCall("IsWindow", "Ptr", hw) || floatGui.badgeHwnd != hw)
            return
        try _DwmNoRedondear(hw)
        try WinSetRegion(Format("0-0 w{} h{}", w, h), g)
        if (!esAnclado)
            SetTimer(_TimerOcultarBadge, -duracion)
        return
    }

    ; ---------- MODO BRUTO: HUD compacto (se adapta al rango calibrado) ----------
    _AvisoCerrarBadge()
    _AvisoCerrarHUD()
    w := Round(208 * AVISO_ESC)
    h := Round(40  * AVISO_ESC)
    px := "", py := ""
    rgEv := _HudRangoEv(claveEv)
    if (IsObject(rgEv) && IsInteger(rgEv.w) && IsInteger(rgEv.h) && rgEv.w >= 40 && rgEv.h >= 20) {
        w := Round(rgEv.w), h := Round(rgEv.h)
        px := Round(rgEv.x), py := Round(rgEv.y)
    } else {
        claveRango := (zona = 1) ? "HUD_Alta" : ((zona = 2) ? "HUD_Media" : "HUD_Baja")
        rg := ObtenerRango(claveRango)
        if (IsObject(rg) && IsInteger(rg.w) && IsInteger(rg.h) && rg.w >= 40 && rg.h >= 20) {
            w := Round(rg.w), h := Round(rg.h)
        }
        p := _CalcularPosicionZona(zona, w, h)
        px := p.x, py := p.y
    }
    if (opacidad = 0)
        opacidad := (zona = 1) ? 70 : ((zona = 2) ? 70 : 100)
    alpha := (opacidad <= 40) ? 102 : ((opacidad <= 70) ? 178 : 235)

    if (!IsObject(floatGui.hud) || !floatGui.hudHwnd || !DllCall("IsWindow", "Ptr", floatGui.hudHwnd)) {
        g := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20")
        g.BackColor := "1A1A1A"
        g.MarginX := 0
        g.MarginY := 0
        WinSetTransparent(alpha, g)
        barH := Max(2, Round(3 * AVISO_ESC))
        lblY := Round(4 * AVISO_ESC)
        lblH := Max(16, h - barH - lblY - Round(3 * AVISO_ESC))
        fSize := Max(7, Min(28, Round(h * 0.22)))
        lbl := g.Add("Text", "x0 y" lblY " w" w " h" lblH " cFFFFFF +0x200 +0x4000 Center", textoPrincipal)
        lbl.SetFont("s" fSize " bold", "Segoe UI")
        bar := g.Add("Progress", "x0 y" (h - barH) " w" w " h" barH)
        bar.Opt("c" colorAcento)
        bar.Value := 100
        try g.Show(Format("x{} y{} w{} h{} NoActivate", px, py, w, h))
        floatGui.hud := g
        floatGui.hudLabel := lbl
        floatGui.hudBar := bar
        floatGui.hudHwnd := g.Hwnd
        floatGui.hudTick := A_TickCount
    } else {
        WinSetTransparent(alpha, floatGui.hud)
        floatGui.hudLabel.Value := textoPrincipal
        floatGui.hudBar.Opt("c" colorAcento)
        floatGui.hudBar.Value := 100
        DllCall("SetWindowPos", "Ptr", floatGui.hudHwnd, "Ptr", -1, "int", px, "int", py, "int", w, "int", h, "uint", 0x0040 | 0x0010)
        floatGui.hudTick := A_TickCount
        try floatGui.hud.Show("NoActivate")
        if IsSet(GfxMascaraRedondeada)
            try GfxMascaraRedondeada(floatGui.hudHwnd, w, h, 6)
    }
    if (!esAnclado)
        SetTimer(_TimerOcultarHUD, -duracion)
}

; ===== DESPACHADOR DE EVENTOS CONFIGURADOS EN CALIBRADOR =====
_AvisoEvento(clave, textoPrincipal := "", subtexto := "", colorAcento := "00E5FF", duracion := 0) {
    global PERFIL
    c := HudConfigEvento(clave)
    zNum := (c.zona = "alta") ? 1 : ((c.zona = "media") ? 2 : 3)
    if (duracion = 0)
        duracion := HudDuracionDe(clave)
    ; Consultar si el usuario personalizó el nombre del evento en el calibrador
    try {
        txtCustom := IniRead(_PosGuiIniPath(), "HudTextos" PERFIL, "texto_" clave, "")
        if (txtCustom != "")
            textoPrincipal := Trim(RegExReplace(txtCustom, "\s*\(.*\)\s*$"))
    }
    if (textoPrincipal = "") {
        for ev in _PtsEventosDefs() {
            if (ev[1] = clave) {
                textoPrincipal := Trim(RegExReplace(ev[2],"\s*\(.*\)\s*$"))
                break
            }
        }
    }
    MostrarAvisoUI(c.formato, textoPrincipal, subtexto, zNum, colorAcento, duracion, c.opacidad, clave)
}

_MapearTextoAEvento(texto) {
    t := StrUpper(texto)
    if InStr(t, "AERÓGRAFO ALPHA") || InStr(t, "AEROGRAFO ALPHA")
        return "aerografo_alpha"
    if InStr(t, "AERÓGRAFO") || InStr(t, "AEROGRAFO")
        return "aerografo"
    if InStr(t, "SOFT BRUSH") || InStr(t, "PINCEL SUAVE")
        return "pincel_suave"
    if InStr(t, "HARD BRUSH") || InStr(t, "PINCEL DURO")
        return "pincel_duro"
    if InStr(t, "DIFU MIXER") || InStr(t, "DIFUMINADOR")
        return "difu_mixer"
    if InStr(t, "OPC PRESSURE") || InStr(t, "OPACIDAD POR PRESIÓN") || InStr(t, "OPACIDAD")
        return "opc_presion"
    if InStr(t, "ERASER LAZO") || InStr(t, "BORRADOR LAZO")
        return "borrador_lazo"
    if InStr(t, "SOFT ERASER") || InStr(t, "BORRADOR SUAVE")
        return "borrador_suave"
    if InStr(t, "ERASER") || InStr(t, "BORRADOR")
        return "borrador"
    if InStr(t, "SMUDGE") || InStr(t, "DEDO")
        return "smudge"
    if InStr(t, "SMEAR")
        return "smear"
    if InStr(t, "COLOR MIX") || InStr(t, "MEZCLA DE COLOR")
        return "color_mix"
    if InStr(t, "COLOR SECUNDARIO")
        return "color_secundario"
    if InStr(t, "COLOR PRIMARIO")
        return "color_primario"
    if InStr(t, "ALPHA TRANSPARENTE")
        return "color_alpha"
    if InStr(t, "FILL") || InStr(t, "RELLENO")
        return "relleno"
    if InStr(t, "LASSO") || InStr(t, "LAZO")
        return "lazo"
    if InStr(t, "DESELECCIÓN") || InStr(t, "DESELECCION")
        return "deseleccion"
    if InStr(t, "RESELECCIÓN") || InStr(t, "RESELECCION")
        return "reseleccion"
    if InStr(t, "INVERTIR SELECCIÓN") || InStr(t, "INV. ÁREA") || InStr(t, "INV_SELECCION")
        return "inv_seleccion"
    if InStr(t, "ÁREA CON COLOR") || InStr(t, "AREA CON COLOR")
        return "area_color"
    if InStr(t, "SELECCIÓN") || InStr(t, "SELECCION")
        return "seleccion"
    if InStr(t, "SHIFT SOSTENIDO") || InStr(t, "REGLA RECTA") || InStr(t, "REGLA LIBERADA") || InStr(t, "SHIFT+S")
        return "shift_sostenido"
    if InStr(t, "FLIP HORIZONTAL") || InStr(t, "REFLEJAR HORIZONTAL")
        return "flip_horizontal"
    if InStr(t, "ROTAR") || InStr(t, "ROTACIÓN") || InStr(t, "✋ R")
        return "rotar_lienzo"
    if InStr(t, "ZOOM") || InStr(t, "🔍 Z")
        return "zoom_lienzo"
    if InStr(t, "REGLA") || InStr(t, "RULE")
        return "regla_ocultar"
    if InStr(t, "HIDE LAYER") || InStr(t, "SHOW LAYER") || InStr(t, "VISIBILIDAD")
        return "capa_visibilidad"
    if InStr(t, "BUSCAR CAPAS") || InStr(t, "COLOR CAPA") || InStr(t, "COLOR DE CAPA") || InStr(t, "BORRAR COLOR") || InStr(t, "CICLO CAPAS") || InStr(t, "CAPAS 1")
        return "macro_capas"
    if InStr(t, "REFERENCE LAYER") || InStr(t, "CAPA DE REFERENCIA")
        return "capa_referencia"
    if InStr(t, "GUARDAR") || InStr(t, "GUARDADO")
        return "guardar"
    if InStr(t, "DESHACER")
        return "deshacer"
    if InStr(t, "REHACER")
        return "rehacer"
    if InStr(t, "PEGAR") || InStr(t, "COPIAR")
        return "copiar"
    if InStr(t, "ENFOQUE") || InStr(t, "FOCUS")
        return "enfoque"
    if InStr(t, "HOVER") || InStr(t, "ACCESO RÁPIDO") || InStr(t, "ACCESO RAPIDO")
        return "hover_paneles"
    if InStr(t, "HISTORY LOCKED") || InStr(t, "DYNAMIC HISTORY") || InStr(t, "HISTORIAL")
        return "history_lock"
    if InStr(t, "BLOQUE") || InStr(t, "FIJAR") || InStr(t, "MOVER BOTONES")
        return "bloque_gui"
    if InStr(t, "AL FRENTE") || InStr(t, "SOLO EN CSP")
        return "gui_frente"
    if InStr(t, "ESTABILIZADOR") || InStr(t, "ESTABILIZACIÓN") || InStr(t, "ESTABILIZACION")
        return "estab_slider"
    if InStr(t, "SINCRONIZ")
        return "estab_sync"
    if InStr(t, "LAYOUT")
        return "layout"
    if InStr(t, "RELOAD") || InStr(t, "REINICI") || InStr(t, "GITHUB")
        return "reload"
    return ""
}

; ---- Compatibilidad hacia atras redirigida al motor de prioridades ----
MostrarBadgeCombo(comboText, toolText, colorAcento := "00E5FF", duracion := 1500, zona := 2) {
    ev := _MapearTextoAEvento(toolText)
    if (!ev)
        ev := _MapearTextoAEvento(comboText)
    if (ev != "")
        return _AvisoEvento(ev, toolText, comboText, colorAcento, duracion)
    return MostrarAvisoUI("moderno", toolText, comboText, zona, colorAcento, duracion)
}

MostrarHUD(texto, colorBarra := "00E5FF", duracion := 1200, zona := 3) {
    ev := _MapearTextoAEvento(texto)
    if (ev != "")
        return _AvisoEvento(ev, texto, "", colorBarra, duracion)
    return MostrarAvisoUI("bruto", texto, "", zona, colorBarra, duracion)
}

QuitarToolTip() => ToolTip()
OcultarToolTip() => ToolTip()
OcultarToolTipAltG() => ToolTip()
OcultarToolTipQ() => ToolTip()
OcultarIndicador() => ToolTip()
QuitarToolTipE() => ToolTip()
QuitarToolTipZ() => ToolTip()
MostrarIndicador(texto) => MostrarHUD(texto, "00E5FF", 2500)
MostrarToolTipE(texto, duracion := 1200) {
    ev := _MapearTextoAEvento(texto)
    if (ev != "")
        return _AvisoEvento(ev, texto, "BORRADOR", "FF4444", duracion)
    return MostrarAvisoUI("bruto", texto, "", 2, "FF4444", duracion)
}

MostrarIconoHerramienta(tipo,duracion := 700) {
    global AVISO_ESC
    if IsObject(floatGui.overlayIcon)
        _DestruirGui(floatGui.overlayIcon)
    thisID := A_TickCount
    floatGui.overlayIconID := thisID
    lado := Round(110 * AVISO_ESC)
    g := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20")
    g.BackColor := "181818"
    g.MarginX := 0
    g.MarginY := 0
    hbm := 0
    nomIcono := (tipo = "zoom" || tipo = "z") ? "z" : (tipo = "rotar" || tipo = "r") ? "r" : (tipo = "space" || tipo = "move") ? "space" : ""
    if (nomIcono != "" && IsSet(GfxIconoLienzo))
        try hbm := GfxIconoLienzo(nomIcono, lado, true)
    if (hbm) {
        g.Add("Picture","x0 y0 w" lado " h" lado,"HBITMAP:" hbm)
    } else {
        iconoChar := (tipo = "zoom") ? "🔍" : (tipo = "rotar") ? "↻" : "⚙"
        fSize := (tipo = "rotar") ? Round(56 * AVISO_ESC) : Round(50 * AVISO_ESC)
        txt := g.Add("Text","x0 y0 w" lado " h" lado " Center +0x0200 cWhite",iconoChar)
        txt.SetFont("s" fSize " bold","Segoe UI Symbol")
    }
    g.Show("w" lado " h" lado " NoActivate Hide")
    _AvisoPosicionar(g.Hwnd)
    if IsSet(GfxMascaraRedondeada)
        try GfxMascaraRedondeada(g.Hwnd, lado, lado, Round(lado * 0.22))
    WinSetTransparent(185,"ahk_id " g.Hwnd)
    floatGui.overlayIcon := g
    SetTimer(() => _OcultarIconoSi(thisID),-duracion)
}
_OcultarIconoSi(id) {
    if (floatGui.overlayIconID != id)
        return
    if IsObject(floatGui.overlayIcon)
        _DestruirGui(floatGui.overlayIcon)
    floatGui.overlayIcon := 0
    floatGui.overlayIconID := 0
}
MostrarToolTipZ(texto,duracion := 800) {
    ev := _MapearTextoAEvento(texto)
    if (ev != "")
        return _AvisoEvento(ev, texto, "LIENZO", "00E5FF", duracion)
    if InStr(texto,"Z")
        MostrarIconoHerramienta("zoom",duracion)
    else if InStr(texto,"R")
        MostrarIconoHerramienta("rotar",duracion)
    else
        MostrarHUD(texto,"00E5FF",duracion)
}
ToolTipCS(texto,duracion := 800) {
    ev := _MapearTextoAEvento(texto)
    if (ev != "")
        return _AvisoEvento(ev, texto, "", texto = "🟢 REHACER" ? "44DD88" : "FF4444", duracion)
    return MostrarAvisoUI("bruto", texto, "", 3, texto = "🟢 REHACER" ? "44DD88" : "FF4444", duracion)
}

_AvisoClamp(x, y, w, h) {
    mejor := 1, mejorD := 1e18
    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &L, &T, &R, &B)
        dx := (x < L) ? L - x : (x > R ? x - R : 0)
        dy := (y < T) ? T - y : (y > B ? y - B : 0)
        d := dx*dx + dy*dy
        if (d < mejorD) {
            mejorD := d, mejor := A_Index
        }
    }
    MonitorGetWorkArea(mejor, &L, &T, &R, &B)
    return [Max(L, Min(x, R - w)), Max(T, Min(y, B - h)), mejorD]
}

_AvisoPosicionar(hwnd) {
    rc := Buffer(16, 0)
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rc)
    w := NumGet(rc, 8, "Int") - NumGet(rc, 0, "Int")
    h := NumGet(rc, 12, "Int") - NumGet(rc, 4, "Int")
    p := _PosicionAviso(w, h)
    DllCall("SetWindowPos","Ptr",hwnd,"Ptr",-1,"int",p.x,"int",p.y,"int",0,"int",0,"uint",0x0040 | 0x0010 | 0x0001)
}

MostrarMiniTexto(texto,colorHex := "00E5FF",duracion := 1200,colorTexto := "FFFFFF") {
    ev := _MapearTextoAEvento(texto)
    acento := (colorHex = "222222" || colorHex = "1A1A2E" || colorHex = "2B3B32") ? _Tema("color", "color_primario", "00E5FF") : colorHex
    tit := RegExReplace(texto, "^[🔄🔁❌✅💨⚪🟡🔵🟠👁🟢🔍🎨🗑↺↩\s]+", "")
    if (tit = "")
        tit := texto
    if (ev != "")
        return _AvisoEvento(ev, tit, "HERRAMIENTA", acento, duracion)
    MostrarAvisoUI("moderno", tit, "CLIP STUDIO PAINT", 2, acento, duracion)
}
_OcultarMiniTipSi(id) {
}
MostrarMiniTextoOscuro(texto,colorHex := "EEEEEE",duracion := 1200) => MostrarMiniTexto(texto, "FFD166", duracion)
MostrarMiniGUI(texto,colorHex := "00E5FF",duracion := 1200) => MostrarMiniTexto(texto, colorHex, duracion)
_OcultarMiniGUISi(hwndMG) {
    if (IsObject(floatGui.miniGUI) && floatGui.miniGUI.Hwnd = hwndMG) {
        floatGui.miniGUI.Destroy()
        floatGui.miniGUI := 0
    }
}
MostrarTooltipToggle(titulo,simbolo,color) {
    ev := _MapearTextoAEvento(titulo)
    colHex := (color = "verde") ? "44DD88" : "FF4444"
    if (ev != "")
        return _AvisoEvento(ev, titulo, simbolo, colHex, 1500)
    MostrarAvisoUI("moderno", titulo, simbolo, 3, colHex, 1500)
}
_OcultarToggleSi(hwndT) {
}
QuitarTooltipToggle() {
    if IsObject(floatGui.tooltipToggle)
        try floatGui.tooltipToggle.Destroy()
    floatGui.tooltipToggle := 0
}
