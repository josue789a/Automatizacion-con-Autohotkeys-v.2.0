#Requires AutoHotkey v2.0
; [LIB] companion — fuente: XPPEN AHK VERSION ESTABLE.ahk L1251–1282, 1300–1703, 2348–2479, 2485–2635, 2796–3487, 4099–4157, 4297–4600
; [FRANJA-PILL] Interruptor temporal de la franja inferior de los botones companion.
; false = franja oculta (aspecto limpio). true = la recupera tal como estaba.
; El codigo de cada barra (creacion, color y valor) se conserva intacto.
_PillFranja() => false ; false = franja oculta (aspecto limpio). true = la recupera tal como estaba.
class BorderFrame {
    T := 0
    B := 0
    L := 0
    R := 0
    _k := ""                                  ; [FIX-PARPADEO] última geometría aplicada
    __New(color) {
        opts := "-Caption +AlwaysOnTop +ToolWindow +E0x20"
        for side in ["T","B","L","R"] {
            g := Gui(opts)
            g.BackColor := color
            g.Show("w0 h0 NoActivate")
            this.%side% := g
        }
    }
    Show(x,y,w,h,g := 1) {
        ; [FIX-PARPADEO] idempotente: LoopAccesoRapido (80 ms) re-llamaba 4 SetWindowPos + 4 WinSetTransparent aunque nada cambió
        clave := x "," y "," w "," h "," g
        try {
            if (this._k = clave && DllCall("IsWindowVisible", "Ptr", this.T.Hwnd))
                return
        }
        this._k := clave
        flags := 0x10 | 0x40
        DllCall("SetWindowPos","Ptr",this.T.Hwnd,"Ptr",-1,"Int",x,"Int",y,"Int",w,"Int",g,"UInt",flags)
        DllCall("SetWindowPos","Ptr",this.B.Hwnd,"Ptr",-1,"Int",x,"Int",y + h - g,"Int",w,"Int",g,"UInt",flags)
        DllCall("SetWindowPos","Ptr",this.L.Hwnd,"Ptr",-1,"Int",x,"Int",y,"Int",g,"Int",h,"UInt",flags)
        DllCall("SetWindowPos","Ptr",this.R.Hwnd,"Ptr",-1,"Int",x + w - g,"Int",y,"Int",g,"Int",h,"UInt",flags)
        WinSetTransparent(85,"ahk_id " this.T.Hwnd)
        WinSetTransparent(85,"ahk_id " this.B.Hwnd)
        WinSetTransparent(85,"ahk_id " this.L.Hwnd)
        WinSetTransparent(85,"ahk_id " this.R.Hwnd)
    }
    Hide() {
        this._k := ""
        this.T.Hide()
        this.B.Hide()
        this.L.Hide()
        this.R.Hide()
    }
}
IniciarDeteccion() {
    bestHwnd := 0
    bestArea := 0
    for hwnd in WinGetList("ahk_exe CLIPStudioPaint.exe") {
        try {
            WinGetPos(&tx,&ty,&tw,&th,"ahk_id " hwnd)
            if (tw * th > bestArea) {
                bestArea := tw * th
                bestHwnd := hwnd
            }
        }
    }
    colorV.cspHwnd := bestHwnd
    colorV.dsID := BuscarVentanaCSP(0,"eslizador","colores")
    if (colorV.dsID) {
        colorV.bDS := BorderFrame("44AA66")
        colorV.hover := true
        colorV.dsVis := false
        try WinSetTransparent(_CompOp("hover","op_rep","panel_ds",5),"ahk_id " colorV.dsID)
        try WinSetExStyle("+0x20","ahk_id " colorV.dsID)
    }
    colorCC.id := BuscarVentanaCSP(0,"rculo de colores","olores")
    if (colorCC.id) {
        colorCC.bCC := BorderFrame("AA6622")
        colorCC.hover := false
        colorCC.dsVis := true
        try WinSetTransparent(255,"ahk_id " colorCC.id)
        try WinSetExStyle("-0x20","ahk_id " colorCC.id)
    }
    ar.id := BuscarVentanaCSP(0,"Acceso r","pido")
    if (ar.id) {
        ar.bAR := BorderFrame("AA8844")
        ar.hover := false
        ar.dsVis := true
        try WinSetTransparent(255,"ahk_id " ar.id)
        try WinSetExStyle("-0x20","ahk_id " ar.id)
    }
}
BuscarVentanaCSP(idActual,frag1,frag2) {
    if (idActual) {
        try {
            if WinExist("ahk_id " idActual)
                return idActual
        }
    }
    for hwnd in WinGetList("ahk_exe CLIPStudioPaint.exe") {
        try {
            t := WinGetTitle("ahk_id " hwnd)
            if InStr(t,frag1) && InStr(t,frag2)
                return hwnd
        }
    }
    return 0
}
CheckReload() {
    try newTime := FileGetTime(A_ScriptFullPath,"M")
    catch
        return
    if (sys.lastModTime = "") {
        sys.lastModTime := newTime
        return
    }
    if (newTime != sys.lastModTime) {
        sys.lastModTime := newTime
        mon := ObtenerMonitorCSP()
        x := mon.x + (mon.w // 2) - 120
        y := mon.y + (mon.h // 2) - 20
        ToolTip("💾 Script actualizado y recargado",x,y)
        _SonarUI("reload")
        Sleep(300)
        ToolTip()
        Reload()
    }
}
ChequearZonaHistorial() {
    global lockGui
    if !WinActive("ahk_exe CLIPStudioPaint.exe")
        return
    if sys.modoEscritura
        return
    if (hist.modo = 2)
        return
    MouseGetPos(&mx,&my)
    z := ZONAS.hist
    enZona := (mx >= z.x1 && mx <= z.x2 && my >= z.y1 && my <= z.y2) && !ZonaPausada("Historial")
    if (enZona && !hist.abierto) {
        hist.abierto := true
        try WinSetTransparent(_CompOp("pildora","op_act","history_lock",_AlphaTema("pill",235)),lockGui.g)
        Send("{Numpad9}")
    } else if (!enZona && hist.abierto) {
        hist.abierto := false
        try WinSetTransparent(_CompOp("pildora","op_rep","history_lock",_AlphaTema("pill",235)),lockGui.g)
        Send("{Numpad9}")
    }
}
LimpiarAltPegadoPureRef() {
    if !stylus.altActive
        return
    if !WinActive("ahk_exe PureRef.exe")
        return
    stylus.altActive := false
    Send("{Alt up}")
}
ChequearZonaAltA() {
    if !WinActive("ahk_exe CLIPStudioPaint.exe")
        return
    if sys.modoEscritura
        return
    _ChequearBotones(btn,ZONAS.izq,"IzqB")
}
ChequearZonaDerecha() {
    if !WinActive("ahk_exe CLIPStudioPaint.exe")
        return
    if sys.modoEscritura
        return
    _ChequearBotones(botDer,ZONAS.der,"DerB")
}
_ChequearBotones(estado,zonas,pref := "") {
    if !enfoque.activo
        return
    if !panelBlk.clicAuto
        return
    MouseGetPos(&mx,&my)
    Loop 3 {
        z := zonas[A_Index]
        k := "b" A_Index
        enZona := (mx >= z.x1 && mx <= z.x2 && my >= z.y1 && my <= z.y2) && !(pref != "" && ZonaPausada(pref A_Index))
        if (enZona && !estado.%k%) {
            estado.%k% := true
            SendEvent("{Click " mx " " my "}")
        } else if (!enZona && estado.%k%)
            estado.%k% := false
    }
}
LoopColorV() {
    if CmpEnTransicion()
        return
    if !WinActive("ahk_exe CLIPStudioPaint.exe") {
        if (colorV.hover) {
            if (colorV.dsVis && colorV.dsID) {
                colorV.dsVis := false
                try WinSetTransparent(_CompOp("hover","op_rep","panel_ds",5),"ahk_id " colorV.dsID)
                try WinSetExStyle("+0x20","ahk_id " colorV.dsID)
            }
            if IsObject(colorV.bDS)
                colorV.bDS.Hide()
        }
        return
    }
    if (!colorV.dsID) {
        colorV.dsID := BuscarVentanaCSP(0,"eslizador","colores")
        if (colorV.dsID) {
            colorV.bDS := BorderFrame("44AA66")
            colorV.dsVis := false
            try WinSetTransparent(_CompOp("hover","op_rep","panel_ds",5),"ahk_id " colorV.dsID)
            try WinSetExStyle("+0x20","ahk_id " colorV.dsID)
        }
        return
    }
    try {
        if !WinExist("ahk_id " colorV.dsID) {
            if IsObject(colorV.bDS)
                colorV.bDS.Hide()
            colorV.dsID := 0
            colorV.dsVis := false
            return
        }
        WinGetPos(&wx,&wy,&ww,&wh,"ahk_id " colorV.dsID)
        colorV.dsX := wx
        colorV.dsY := wy
        colorV.dsW := ww
        colorV.dsH := wh
    } catch {
        if IsObject(colorV.bDS)
            colorV.bDS.Hide()
        colorV.dsID := 0
        colorV.dsVis := false
        return
    }
    if (!colorV.hover)
        return
    MouseGetPos(&mx,&my)
    enDS := (mx >= wx && mx <= wx + ww && my >= wy && my <= wy + wh)
    enCirculo := false
    if (colorCC.id && colorCC.ccW > 0) {
        if (colorCC.hover)
            enCirculo := colorCC.dsVis
        else
            enCirculo := (mx >= colorCC.ccX && mx <= colorCC.ccX + colorCC.ccW && my >= colorCC.ccY && my <= colorCC.ccY + colorCC.ccH)
    }
    if (A_TickCount < colorV.supresionHasta) {
        enDS := false
        enCirculo := false
    }
    if (enDS || enCirculo) {
        if (!colorV.dsVis) {
            colorV.dsVis := true
            try WinSetTransparent(_CompOp("hover","op_act","panel_ds",255),"ahk_id " colorV.dsID)
            try WinSetExStyle("-0x20","ahk_id " colorV.dsID)
            if IsObject(colorV.bDS)
                colorV.bDS.Hide()
        }
    } else {
        if (colorV.dsVis) {
            colorV.dsVis := false
            try WinSetTransparent(_CompOp("hover","op_rep","panel_ds",5),"ahk_id " colorV.dsID)
            try WinSetExStyle("+0x20","ahk_id " colorV.dsID)
        }
        if IsObject(colorV.bDS) {
            if (_CompBorde("hover","panel_ds",true))
                colorV.bDS.Show(wx,wy,ww,wh)
            else
                colorV.bDS.Hide()
        }
    }
}
LoopColorCC() {
    if CmpEnTransicion()
        return
    if !WinActive("ahk_exe CLIPStudioPaint.exe") {
        if (colorCC.hover) {
            if (colorCC.dsVis && colorCC.id) {
                colorCC.dsVis := false
                try WinSetTransparent(5,"ahk_id " colorCC.id)
                try WinSetExStyle("+0x20","ahk_id " colorCC.id)
            }
            if IsObject(colorCC.bCC)
                colorCC.bCC.Hide()
        }
        colorCC.ccW := 0
        return
    }
    if (!colorCC.id) {
        colorCC.id := BuscarVentanaCSP(0,"rculo de colores","olores")
        if (colorCC.id) {
            colorCC.bCC := BorderFrame("AA6622")
            colorCC.dsVis := false
            try WinSetTransparent(5,"ahk_id " colorCC.id)
            try WinSetExStyle("+0x20","ahk_id " colorCC.id)
        }
        return
    }
    try {
        if !WinExist("ahk_id " colorCC.id) {
            if IsObject(colorCC.bCC)
                colorCC.bCC.Hide()
            colorCC.id := 0
            colorCC.dsVis := false
            colorCC.ccW := 0
            return
        }
        WinGetPos(&wx,&wy,&ww,&wh,"ahk_id " colorCC.id)
        colorCC.ccX := wx
        colorCC.ccY := wy
        colorCC.ccW := ww
        colorCC.ccH := wh
    } catch {
        if IsObject(colorCC.bCC)
            colorCC.bCC.Hide()
        colorCC.id := 0
        colorCC.dsVis := false
        colorCC.ccW := 0
        return
    }
    if (!colorCC.hover)
        return
    MouseGetPos(&mx,&my)
    dentro := (mx >= wx && mx <= wx + ww && my >= wy && my <= wy + wh)
    if (!dentro) {
        enDeslizador := false
        if (!colorV.hover && colorV.dsID && colorV.dsW > 0)
            enDeslizador := (mx >= colorV.dsX && mx <= colorV.dsX + colorV.dsW && my >= colorV.dsY && my <= colorV.dsY + colorV.dsH)
        dentro := enDeslizador
    }
    if (A_TickCount < colorCC.supresionHasta)
        dentro := false
    if (dentro) {
        if (!colorCC.dsVis) {
            colorCC.dsVis := true
            try WinSetTransparent(_CompOp("hover","op_act","panel_cc",255),"ahk_id " colorCC.id)
            try WinSetExStyle("-0x20","ahk_id " colorCC.id)
            if IsObject(colorCC.bCC)
                colorCC.bCC.Hide()
        }
    } else {
        if (colorCC.dsVis) {
            colorCC.dsVis := false
            try WinSetTransparent(_CompOp("hover","op_rep","panel_cc",5),"ahk_id " colorCC.id)
            try WinSetExStyle("+0x20","ahk_id " colorCC.id)
        }
        if IsObject(colorCC.bCC) {
            if (_CompBorde("hover","panel_cc",true))
                colorCC.bCC.Show(wx,wy,ww,wh)
            else
                colorCC.bCC.Hide()
        }
    }
}
LoopAccesoRapido() {
    if CmpEnTransicion()
        return
    if (!ar.hover)
        return
    if !WinActive("ahk_exe CLIPStudioPaint.exe") {
        if (ar.dsVis && ar.id) {
            ar.dsVis := false
            try WinSetTransparent(5,"ahk_id " ar.id)
            try WinSetExStyle("+0x20","ahk_id " ar.id)
        }
        if IsObject(ar.bAR)
            ar.bAR.Hide()
        return
    }
    if (!ar.id) {
        ar.id := BuscarVentanaCSP(0,"Acceso r","pido")
        if (ar.id) {
            ar.bAR := BorderFrame("AA8844")
            ar.dsVis := false
            try WinSetTransparent(5,"ahk_id " ar.id)
            try WinSetExStyle("+0x20","ahk_id " ar.id)
        }
        return
    }
    try {
        if !WinExist("ahk_id " ar.id) {
            if IsObject(ar.bAR)
                ar.bAR.Hide()
            ar.id := 0
            ar.dsVis := false
            return
        }
        WinGetPos(&wx,&wy,&ww,&wh,"ahk_id " ar.id)
    } catch {
        if IsObject(ar.bAR)
            ar.bAR.Hide()
        ar.id := 0
        ar.dsVis := false
        return
    }
    MouseGetPos(&mx,&my)
    dentro := (mx >= wx && mx <= wx + ww && my >= wy && my <= wy + wh)
    if (dentro) {
        if (!ar.dsVis) {
            ar.dsVis := true
            try WinSetTransparent(255,"ahk_id " ar.id)
            try WinSetExStyle("-0x20","ahk_id " ar.id)
            if IsObject(ar.bAR)
                ar.bAR.Hide()
        }
    } else {
        if (ar.dsVis) {
            ar.dsVis := false
            try WinSetTransparent(5,"ahk_id " ar.id)
            try WinSetExStyle("+0x20","ahk_id " ar.id)
        }
        if IsObject(ar.bAR)
            ar.bAR.Show(wx,wy,ww,wh)
    }
}
ResetProcesando() => E.procesando := false
__Q_SEND_NORMAL() {
    global colorEstado
    Q.pendiente := false
    SendInput("q")
    _SonarUI("pluma")
    Stab_ResetUniversal("q")
    if (colorEstado = 1)
        MostrarMiniTextoOscuro("🟡 COLOR SECUNDARIO", _Tema("color", "color_secundario", "51D67B"), 800)
    else if (colorEstado = 2)
        MostrarMiniTexto("⚪ ALPHA TRANSPARENTE", _Tema("color", "color_alpha", "1C6EA4"), 800)
    else
        MostrarMiniTexto("🔵 COLOR PRIMARIO", _Tema("color", "color_primario", "00E5FF"), 800)
}
AlternarEstabilizacion() {
    global stabU, Q, estabGui, ESTAB_MAX, ESTAB_MIN
    static ocupado := false
    static lastTick := 0
    static lastPressTime := 0
    static reintentos := 0
    ; Un reset universal en curso NO debe tragarse el toggle: abortarlo y reintentar enseguida
    if stabU.ocupado {
        stabU.abortar := true
        if (reintentos < 6) {
            reintentos += 1
            SetTimer(AlternarEstabilizacion, -25)
        }
        return
    }
    reintentos := 0
    now := A_TickCount
    if (ocupado || (now - lastTick < 30))
        return
    if GetKeyState("LButton","P")
        return
    lastTick := now
    ocupado := true
    esDobleTap := (now - lastPressTime < 350)
    lastPressTime := esDobleTap ? 0 : now
    delta := ESTAB_MAX - ESTAB_MIN
    alta := (Q.estadoEstab = 0)
    destino := alta ? ESTAB_MAX : ESTAB_MIN
    if esDobleTap
        envio := "{j 100}{- " destino "}"
    else
        envio := alta ? "{- " delta "}" : "{j " delta "}"
    try {
        SendInput(envio)                       ; sin BlockInput: SendInput ya es atomico y BlockInput anade latencia
        Q.estadoEstab := alta ? 1 : 0
        if esDobleTap {
            estabGui.valor := destino
            estabGui.previsto := destino
            estabGui.sincronizado := true
        } else if estabGui.sincronizado {
            estabGui.valor := Max(0,Min(100,estabGui.valor + (alta ? delta : -delta)))
            estabGui.previsto := estabGui.valor
        }
        if estabGui.sincronizado
            _Stab_Recordar(estabGui.valor)
        OutputDebug("[StabNormal] envio=" envio " ms=" (A_TickCount - now))
        ; Toda la parte visual/sonora despues del envio y fuera de este hilo
        SetTimer(_Stab_ToggleUI.Bind(alta, esDobleTap), -1)
    } finally {
        ocupado := false
    }
}
_Stab_ToggleUI(alta, esDobleTap) {
    global ESTAB_MAX, ESTAB_MIN, estabGui
    SetTimer(alta ? _BeepEstabAlta : _BeepEstabBaja, -1)
    if esDobleTap
        MostrarMiniTexto("🔄 RE-SINCRONIZADO: " (alta ? "ALTA (" ESTAB_MAX ")" : "BAJA (" ESTAB_MIN ")"), alta ? "1A5C2A" : "1A2E5C", 1000)
    else
        MostrarMiniTexto(alta ? "🟢 ESTABILIZACIÓN ALTA (" ESTAB_MAX ")" : "🔵 ESTABILIZACIÓN BAJA (" ESTAB_MIN ")", alta ? "1A5C2A" : "1A2E5C", 700)
    if estabGui.sincronizado
        ActualizarEstabGUI()
}
_AplicarEstabVisibilidadBase() {
    if !IsObject(estabGui.g) || estabGui.foco
        return
    if (estabGui.visible && enfoque.activo) {
        try estabGui.g.Show("NoActivate")
        _EstabDibujar()
    } else {
        try estabGui.g.Hide()
    }
}
_CompanionRestaurarAudio(silencioso := false) {
    res := 0
    try res := _AudReiniciar()
    if (silencioso)
        return res
    if (res)
        MostrarAvisoUI("moderno", "AUDIO RESTAURADO", "SUBSISTEMA REINICIADO", 1, "00E5FF", 1200)
    else
        MostrarAvisoUI("moderno", "AUDIO EN CURSO", "REINICIO YA EN PROCESO", 2, "FF6B00", 1000)
}

; Gancho para RELOAD_INI (Companion Python): reinicia audio sin banners.
_CompanionRestaurarAudioSilencioso() {
    return _CompanionRestaurarAudio(true)
}


; ===================== LIENZO HUD (Z / R / Space) =====================
; Overlay GDI+ vectorial: se dibuja UNA vez por modo a un DIB 32bpp y se muestra con UpdateLayeredWindow.
_TemaHex(clave, def) {
    c := def
    try c := Trim(_Tema("color", clave, def))
    return RegExMatch(c, "^[0-9A-Fa-f]{6}$") ? c : def
}
_LHArgb(hex, a) => (a << 24) | Integer("0x" hex)

_LH() {
    static e := {gui: 0, hwnd: 0, vis: false, modo: "", tecla: "", t0: 0, hasta: 0, paso: 0, pasos: 4
        , x: 0, y: 0, cache: Map(), tok: 0, fallo: false}
    return e
}
_LHGdipIniciar() {
    e := _LH()
    if (e.tok)
        return true
    if (e.fallo)
        return false
    try {
        if !DllCall("GetModuleHandle", "Str", "gdiplus", "Ptr")
            DllCall("LoadLibrary", "Str", "gdiplus")
        si := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
        NumPut("UInt", 1, si, 0)
        tok := 0
        if (DllCall("gdiplus\GdiplusStartup", "Ptr*", &tok, "Ptr", si, "Ptr", 0) = 0 && tok) {
            e.tok := tok
            return true
        }
    }
    e.fallo := true
    return false
}
_LHPen(argb, ancho) {
    pen := 0
    DllCall("gdiplus\GdipCreatePen1", "UInt", argb, "Float", ancho, "Int", 2, "Ptr*", &pen)
    if (pen) {
        DllCall("gdiplus\GdipSetPenLineCap197819", "Ptr", pen, "Int", 2, "Int", 2, "Int", 2)
        DllCall("gdiplus\GdipSetPenLineJoin", "Ptr", pen, "Int", 2)
    }
    return pen
}
_LHTrazo(gfx, argb, ancho, x1, y1, x2, y2) {
    pen := _LHPen(argb, ancho)
    if !pen
        return
    DllCall("gdiplus\GdipDrawLine", "Ptr", gfx, "Ptr", pen, "Float", x1, "Float", y1, "Float", x2, "Float", y2)
    DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
}
_LHArco(gfx, argb, ancho, x, y, w, h, a0, sw) {
    pen := _LHPen(argb, ancho)
    if !pen
        return
    DllCall("gdiplus\GdipDrawArc", "Ptr", gfx, "Ptr", pen, "Float", x, "Float", y, "Float", w, "Float", h, "Float", a0, "Float", sw)
    DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
}
_LHElipse(gfx, argb, ancho, x, y, w, h) {
    pen := _LHPen(argb, ancho)
    if !pen
        return
    DllCall("gdiplus\GdipDrawEllipse", "Ptr", gfx, "Ptr", pen, "Float", x, "Float", y, "Float", w, "Float", h)
    DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
}
_LHRelleno(gfx, argb, x, y, w, h) {
    br := 0
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", argb, "Ptr*", &br)
    if !br
        return
    DllCall("gdiplus\GdipFillEllipse", "Ptr", gfx, "Ptr", br, "Float", x, "Float", y, "Float", w, "Float", h)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
}
_LHFlecha(gfx, argb, ancho, cx, cy, r, angFin) {
    a := angFin * 0.0174532925
    px := cx + r * Cos(a)
    py := cy + r * Sin(a)
    bx := Sin(a)          ; -tangente
    by := -Cos(a)
    for lado in [0.62, -0.62] {
        c := Cos(lado)
        s := Sin(lado)
        vx := bx * c - by * s
        vy := bx * s + by * c
        _LHTrazo(gfx, argb, ancho, px, py, px + vx * 13, py + vy * 13)
    }
}
_LHConstruir(modo) {
    e := _LH()
    if e.cache.Has(modo)
        return e.cache[modo]
    if !_LHGdipIniciar()
        return 0
    w := 112
    h := 142
    try {
        w := _E(112)
        h := _E(142)
    }
    k := w / 112
    switch modo {
        case "z":
            acento := _TemaHex("accent.info", "00E5FF")
            txt := "ZOOM"
        case "r":
            acento := _TemaHex("accent.warn", "FF6B00")
            txt := "ROTAR"
        default:
            acento := _TemaHex("accent.success", "44DD88")
            txt := "MOVER"
    }
    fondo := _TemaHex("surface.base", "12141A")
    blanco := _TemaHex("text.primary", "F0F0F0")
    aCuerpo := 225
    try aCuerpo := Min(255, Integer(_AlphaTema("hud", 215)) + 10)
    familia := "Segoe UI"
    try familia := Trim(_Tema("type", "family", "Segoe UI"))

    hdc := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")
    bi := Buffer(40, 0)
    NumPut("UInt", 40, bi, 0)
    NumPut("Int", w, bi, 4)
    NumPut("Int", -h, bi, 8)
    NumPut("UShort", 1, bi, 12)
    NumPut("UShort", 32, bi, 14)
    bits := 0
    hbm := DllCall("CreateDIBSection", "Ptr", hdc, "Ptr", bi, "UInt", 0, "Ptr*", &bits, "Ptr", 0, "UInt", 0, "Ptr")
    if (!hbm) {
        DllCall("DeleteDC", "Ptr", hdc)
        return 0
    }
    DllCall("SelectObject", "Ptr", hdc, "Ptr", hbm, "Ptr")
    gfx := 0
    DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdc, "Ptr*", &gfx)
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", gfx, "Int", 4)
    DllCall("gdiplus\GdipSetTextRenderingHint", "Ptr", gfx, "Int", 4)
    DllCall("gdiplus\GdipScaleWorldTransform", "Ptr", gfx, "Float", k, "Float", k, "Int", 0)

    ; halo translúcido + cuerpo de vidrio + borde de acento
    Loop 6 {
        r := 56 - (A_Index - 1) * 1.2
        _LHRelleno(gfx, _LHArgb(acento, 16), 56 - r, 56 - r, r * 2, r * 2)
    }
    _LHRelleno(gfx, _LHArgb(fondo, aCuerpo), 10, 10, 92, 92)
    _LHElipse(gfx, _LHArgb(acento, 255), 3, 10, 10, 92, 92)

    ; glifos vectoriales
    cA := _LHArgb(acento, 255)
    cB := _LHArgb(blanco, 255)
    switch modo {
        case "z":      ; lupa con "+"
            _LHElipse(gfx, cA, 5, 35, 35, 30, 30)
            _LHTrazo(gfx, cA, 8, 61, 61, 74, 74)
            _LHTrazo(gfx, cB, 3.5, 44, 50, 56, 50)
            _LHTrazo(gfx, cB, 3.5, 50, 44, 50, 56)
        case "r":      ; dos flechas circulares
            _LHArco(gfx, cA, 5, 32, 32, 48, 48, 200, 120)
            _LHArco(gfx, cA, 5, 32, 32, 48, 48, 20, 120)
            _LHFlecha(gfx, cA, 5, 56, 56, 24, 320)
            _LHFlecha(gfx, cA, 5, 56, 56, 24, 140)
            _LHElipse(gfx, cB, 3, 53, 53, 6, 6)
        default:       ; mano (dedos, palma, pulgar)
            _LHTrazo(gfx, cA, 8, 46, 64, 46, 41)
            _LHTrazo(gfx, cA, 8, 56, 64, 56, 34)
            _LHTrazo(gfx, cA, 8, 66, 64, 66, 36)
            _LHTrazo(gfx, cA, 8, 76, 64, 76, 43)
            _LHTrazo(gfx, cA, 20, 52, 67, 70, 67)
            _LHTrazo(gfx, cA, 16, 54, 76, 68, 76)
            _LHTrazo(gfx, cA, 8, 45, 72, 33, 59)
    }

    ; etiqueta (cápsula + texto)
    _LHTrazo(gfx, cA, 24, 28, 127, 84, 127)
    _LHTrazo(gfx, _LHArgb(fondo, 255), 22, 28, 127, 84, 127)
    fam := 0
    DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", familia, "Ptr", 0, "Ptr*", &fam)
    if (fam) {
        fnt := 0
        fmt := 0
        br := 0
        DllCall("gdiplus\GdipCreateFont", "Ptr", fam, "Float", 12, "Int", 1, "Int", 2, "Ptr*", &fnt)
        DllCall("gdiplus\GdipCreateStringFormat", "Int", 0, "Int", 0, "Ptr*", &fmt)
        DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", fmt, "Int", 1)
        DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", fmt, "Int", 1)
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", cB, "Ptr*", &br)
        rc := Buffer(16, 0)
        NumPut("Float", 0, rc, 0)
        NumPut("Float", 116, rc, 4)
        NumPut("Float", 112, rc, 8)
        NumPut("Float", 22, rc, 12)
        if (fnt && fmt && br)
            DllCall("gdiplus\GdipDrawString", "Ptr", gfx, "WStr", txt, "Int", -1, "Ptr", fnt, "Ptr", rc, "Ptr", fmt, "Ptr", br)
        if (br)
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
        if (fmt)
            DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", fmt)
        if (fnt)
            DllCall("gdiplus\GdipDeleteFont", "Ptr", fnt)
        DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", fam)
    }
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gfx)
    ent := {hdc: hdc, hbm: hbm, w: w, h: h}
    e.cache[modo] := ent
    return ent
}
_LHAsegurarGui() {
    e := _LH()
    if (e.hwnd && DllCall("IsWindow", "Ptr", e.hwnd))
        return
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x80000 +E0x20 +E0x08000000", "LienzoHUD")
    e.gui := g
    e.hwnd := g.Hwnd
}
_LHPintar(ent, alfa) {
    e := _LH()
    pt := Buffer(8, 0)
    NumPut("Int", e.x, pt, 0)
    NumPut("Int", e.y, pt, 4)
    sz := Buffer(8, 0)
    NumPut("Int", ent.w, sz, 0)
    NumPut("Int", ent.h, sz, 4)
    ps := Buffer(8, 0)
    bl := Buffer(4, 0)
    NumPut("UChar", 0, "UChar", 0, "UChar", alfa, "UChar", 1, bl)
    DllCall("UpdateLayeredWindow", "Ptr", e.hwnd, "Ptr", 0, "Ptr", pt, "Ptr", sz, "Ptr", ent.hdc, "Ptr", ps, "UInt", 0, "Ptr", bl, "UInt", 2)
}
LienzoHUD_Mostrar(modo, tecla := "", minMs := 0) {
    e := _LH()
    if (modo != "z" && modo != "r" && modo != "space")
        return false
    ent := _LHConstruir(modo)
    if !ent
        return false
    if (e.vis && e.modo = modo && e.paso = 0) {      ; auto-repeat: solo extiende, sin repintar
        pt := Buffer(8)
        DllCall("GetCursorPos", "Ptr", pt)
        e.ultimoX := NumGet(pt, 0, "int")
        e.ultimoY := NumGet(pt, 4, "int")
        _LHAsegurarGui()
        e.gui.Show("x" e.ultimoX " y" e.ultimoY " NA")
        e.tecla := tecla
        e.hasta := Max(e.hasta, A_TickCount + minMs)
        return true
    }
    if (e.paso) {
        SetTimer(_LHFade, 0)
        e.paso := 0
    }
    _LHAsegurarGui()
    if !e.vis {
        pt := Buffer(8, 0)
        DllCall("GetCursorPos", "Ptr", pt)
        px := NumGet(pt, 0, "Int")
        py := NumGet(pt, 4, "Int")
        mon := {x: 0, y: 0, w: A_ScreenWidth, h: A_ScreenHeight}
        try mon := ObtenerMonitorCSP()
        pos := "cursor"
        try pos := Trim(_Tema("lienzo", "pos", "cursor"))
        if (pos = "centro") {
            x := mon.x + (mon.w - ent.w) // 2
            y := mon.y + (mon.h - ent.h) // 2
        } else {
            ; HUD centrado directamente sobre el puntero (el circulo reemplaza el icono/cursor de CSP)
            x := px - ent.w // 2
            y := py - ent.w // 2
        }
        e.x := Max(mon.x, Min(x, mon.x + mon.w - ent.w))
        e.y := Max(mon.y, Min(y, mon.y + mon.h - ent.h))
    }
    e.modo := modo
    e.tecla := tecla
    e.t0 := A_TickCount
    e.hasta := A_TickCount + minMs
    DllCall("ShowWindow", "Ptr", e.hwnd, "Int", 8)
    _LHPintar(ent, 255)
    e.vis := true
    SetTimer(_LHTick, 30)
    return true
}
_LHTick() {
    e := _LH()
    if !e.vis {
        SetTimer(_LHTick, 0)
        return
    }
    ahora := A_TickCount
    if (ahora < e.hasta)
        return
    if (e.tecla != "" && WinActive("ahk_exe CLIPStudioPaint.exe") && (GetKeyState(e.tecla, "P") || GetKeyState(e.tecla)) && ahora - e.t0 < 8000)
        return
    SetTimer(_LHTick, 0)
    ms := 120
    try ms := Integer(_Tema("motion", "fast", "60")) * 2
    e.pasos := Max(2, Min(8, ms // 15))
    e.paso := 0
    SetTimer(_LHFade, 15)
}
_LHFade() {
    e := _LH()
    e.paso += 1
    if (!e.vis || e.paso >= e.pasos || !e.cache.Has(e.modo)) {
        _LHOcultar()
        return
    }
    _LHPintar(e.cache[e.modo], Round(255 * (1 - e.paso / e.pasos)))
}
_LHOcultar() {
    e := _LH()
    SetTimer(_LHTick, 0)
    SetTimer(_LHFade, 0)
    e.vis := false
    e.paso := 0
    if (e.hwnd)
        DllCall("ShowWindow", "Ptr", e.hwnd, "Int", 0)
}
LienzoHUD_Invalidar() {   ; llamar tras cambiar colores de theme.ini (opcional)
    e := _LH()
    _LHOcultar()
    for k, ent in e.cache {
        DllCall("DeleteObject", "Ptr", ent.hbm)
        DllCall("DeleteDC", "Ptr", ent.hdc)
    }
    e.cache := Map()
}
LienzoHUD_ChequeoR() {
    if (!WinActive("ahk_exe CLIPStudioPaint.exe") || (!GetKeyState("r", "P") && !GetKeyState("r")))
        return
    LienzoHUD_Mostrar("r", "r", 0)
}
LienzoHUD_ChequeoSpace() {
    if (!WinActive("ahk_exe CLIPStudioPaint.exe") || (!GetKeyState("Space", "P") && !GetKeyState("Space")))
        return
    LienzoHUD_Mostrar("space", "Space", 0)
}




; --- Submodulo Lienzos CSP extraido (Frente 2) ---
#Include %A_LineFile%\..\companion_modosel.ahk
#Include %A_LineFile%\..\companion_lienzos.ahk
#Include %A_LineFile%\..\companion_enfoque.ahk
; ===== JIT-2: transición multi-monitor =====
class CmpState {
    static trans := false
    static transHasta := 0
    static tabletaAncho := 2560
    static nivel := 0                 ; contador de transiciones anidadas
    static moviendo := Map()          ; hwnds en movimiento (anti-reentrada)
    static guardaDpi := false         ; el guardia WM_DPICHANGED ya está registrado
}

CmpTransIniciar() {
    if (!CmpState.guardaDpi) {
        OnMessage(0x02E0, CmpGuardaDpi, -1)   ; -1: se ejecuta ANTES que los manejadores existentes
        CmpState.guardaDpi := true
    }
    CmpState.nivel += 1
    CmpState.trans := true
    CmpState.transHasta := Max(CmpState.transHasta, A_TickCount + 2000)
}

CmpTransFin() {
    CmpState.nivel := Max(0, CmpState.nivel - 1)
    if (CmpState.nivel = 0)
        CmpState.trans := false
}

CmpEnTransicion() {
    if (CmpState.trans && A_TickCount > CmpState.transHasta) {
        CmpState.trans := false
        CmpState.nivel := 0
        CmpState.moviendo.Clear()
        CmpLog("TRANS watchdog expiró")
    }
    return CmpState.trans
}

; Durante una transición, absorbe WM_DPICHANGED: ningún otro manejador reposiciona (retorno entero = corta la cadena)
CmpGuardaDpi(wParam, lParam, msg, hwnd) {
    if (CmpEnTransicion())
        return 0
}

CmpMonitorTableta() {
    ; La tableta es siempre un monitor NO primario; se prefiere el de ancho nativo (2560) o lógico a 150% (1707).
    prim := MonitorGetPrimary()
    noPrim := 0
    anchoLog := Round(CmpState.tabletaAncho * 96 / 144)
    loop MonitorGetCount() {
        if (A_Index = prim)
            continue
        MonitorGet(A_Index, &l, &t, &r, &b)
        ancho := r - l
        if (ancho = CmpState.tabletaAncho || Abs(ancho - anchoLog) <= 1)
            return A_Index
        if (!noPrim)
            noPrim := A_Index
    }
    return noPrim ? noPrim : prim
}

; Mueve hwnd al monitor 'mon' en dos fases. x,y relativos al monitor; wLog,hLog en unidades a 96 DPI.
CmpMoverDosFases(hwnd, mon, x, y, wLog, hLog) {
    static SWP := 0x001C                    ; NOZORDER | NOACTIVATE | NOREDRAW (se redibuja una sola vez al final)
    if (CmpState.moviendo.Has(hwnd))        ; anti-reentrada: este hwnd ya se está moviendo
        return
    CmpState.moviendo[hwnd] := true
    CmpTransIniciar()
    try {
        MonitorGet(mon, &ml, &mt, &mr, &mb)
        CmpDump("2f-inicio", hwnd)

        ; DPI esperado del monitor destino (evita depender de lecturas "estables" ambiguas)
        dpiDest := 0, dx := 0, dy := 0
        cxm := (ml + mr) // 2, cym := (mt + mb) // 2
        hMon := DllCall("MonitorFromPoint", "int64", (cym << 32) | (cxm & 0xFFFFFFFF), "uint", 2, "ptr")
        if (hMon && DllCall("shcore\GetDpiForMonitor", "ptr", hMon, "int", 0, "uint*", &dx, "uint*", &dy, "int") = 0)
            dpiDest := dx

        ; Fase 1: tamaño mínimo en el destino (el cambio de DPI ocurre con la ventana casi invisible)
        DllCall("SetWindowPos", "ptr", hwnd, "ptr", 0, "int", ml + x, "int", mt + y, "int", 1, "int", 1, "uint", SWP)

        ; Esperar a que el DPI de la ventana alcance el del monitor destino (máx. 400 ms).
        ; Sin dato de DPI destino: dos lecturas iguales seguidas.
        ult := 0, fin := A_TickCount + 400
        while (A_TickCount < fin) {
            Sleep(15)                       ; deja correr WM_DPICHANGED (absorbido por CmpGuardaDpi)
            d := DllCall("GetDpiForWindow", "ptr", hwnd, "uint")
            if (dpiDest ? (d = dpiDest) : (d = ult))
                break
            ult := d
        }

        ; Fase 2: tamaño y posición finales con el DPI ya asentado
        dpi := DllCall("GetDpiForWindow", "ptr", hwnd, "uint")
        if (!dpi)
            dpi := 96
        w := Round(wLog * dpi / 96), h := Round(hLog * dpi / 96)
        DllCall("SetWindowPos", "ptr", hwnd, "ptr", 0, "int", ml + x, "int", mt + y, "int", w, "int", h, "uint", SWP)

        ; Verificación + un único reintento
        WinGetPos(&px, &py, &pw, &ph, "ahk_id " hwnd)
        if (Abs(px - (ml + x)) > 2 || Abs(py - (mt + y)) > 2 || Abs(pw - w) > 2 || Abs(ph - h) > 2) {
            CmpLog("2f-reintento")
            Sleep(30)
            dpi := DllCall("GetDpiForWindow", "ptr", hwnd, "uint")
            if (!dpi)
                dpi := 96
            w := Round(wLog * dpi / 96), h := Round(hLog * dpi / 96)
            DllCall("SetWindowPos", "ptr", hwnd, "ptr", 0, "int", ml + x, "int", mt + y, "int", w, "int", h, "uint", SWP)
        }

        ; Invalidación única al final (INVALIDATE|ALLCHILDREN|UPDATENOW|FRAME)
        DllCall("RedrawWindow", "ptr", hwnd, "ptr", 0, "ptr", 0, "uint", 0x0581)
        CmpDump("2f-fin", hwnd)
    } catch as e {
        CmpLog("2f-error " e.Message)
    } finally {
        CmpState.moviendo.Delete(hwnd)
        CmpTransFin()
    }
}

#Include %A_LineFile%\..\companion_flotantes.ahk

CmpLog(msg) {
    static f := A_ScriptDir "\logs\companion_trans.log"
    DirCreate(A_ScriptDir "\logs")
    FileAppend(Format("{1} [{2}] {3}`n", FormatTime(, "HH:mm:ss"), A_TickCount, msg), f)
}

CmpDump(tag, hwnd) {
    WinGetPos(&x, &y, &w, &h, hwnd)
    mon := 0
    loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if (x + w//2 >= l && x + w//2 < r && y + h//2 >= t && y + h//2 < b)
            mon := A_Index
    }
    dpi := DllCall("GetDpiForWindow", "ptr", hwnd, "uint")
    CmpLog(Format("{1}: pos=({2},{3}) {4}x{5} mon={6} dpi={7}", tag, x, y, w, h, mon, dpi))
}

CmpMonitores(tag) {
    CmpLog(tag ": count=" MonitorGetCount() " primary=" MonitorGetPrimary())
    loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        CmpLog(Format("  mon{1}: {2},{3} {4}x{5} name={6}", A_Index, l, t, r-l, b-t, MonitorGetName(A_Index)))
    }
}

OnMessage(0x02E0, (wp, lp, msg, hwnd) => CmpLog(Format("WM_DPICHANGED hwnd={1} dpi={2}", hwnd, wp & 0xFFFF)))
OnMessage(0x007E, (wp, lp, msg, hwnd) => CmpMonitores("WM_DISPLAYCHANGE"))

