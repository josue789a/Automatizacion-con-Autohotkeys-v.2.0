#Requires AutoHotkey v2.0
; ============================================================================
; lib/companion_modosel.ahk - Selector de modo (Normal / Enfoque), persistencia y tray
; Extraido de companion.ahk (Frente 2 - Modularizacion)
; Depende de: enfoque (global), panelBlk (global)
; Es llamado desde: _EnfReconciliar, ResetEnfoque, hotkeys_csp ($^!+m), lanzador
; ============================================================================

; ===================== SELECTOR DE MODO (Normal / Enfoque) =====================
_ModoSel() {
    static s := {g: 0, tN: 0, tE: 0, tS: 0, tI: 0, visible: false, tray: 0, msg: false}
    return s
}
EstablecerModoTrabajo(nombre) {
    global enfoque
    if !IsSet(enfoque)
        return
    quiere := (nombre = "Enfoque") ? 1 : 0
    actual := enfoque.activo ? 1 : 0
    if (quiere = actual) {          ; ya está en ese modo: solo reaplica ubicaciones (sin tocar CSP)
        _AplicarLayoutPaneles(nombre)
        _ModoSelRefrescar()
        MostrarHUD(quiere ? "🔍 MODO ENFOQUE (ya activo)" : "🖥 MODO NORMAL (ya activo)", quiere ? "00E5FF" : "44DD88", 700)
        return
    }
    AccionEnfoque()
}
_ModoContarGuardados(nombre) {
    mon := {x: 0, y: 0, w: 0, h: 0}
    try mon := ObtenerMonitorCSP()
    n := 0
    for clave in ["ds", "cc", "ar", "hc"] {
        if (_LayoutPanelGuardado(nombre, clave, mon))
            n += 1
    }
    return n
}
_ModoSelPosGuardada(nombre) {
    ini := _PosGuiIniPath()
    sec := "Layout" nombre
    gx := IniRead(ini, sec, "gui_modox", "")
    gy := IniRead(ini, sec, "gui_modoy", "")
    if (gx = "" || gy = "")
        return 0
    mon := ObtenerMonitorCSP()
    x := mon.x + Integer(gx)
    y := mon.y + Integer(gy)
    return _PosicionValidaEnPantalla(x, y) ? {x: x, y: y} : 0
}
_ModoSelCrear() {
    global enfoque
    s := _ModoSel()
    if (IsObject(s.g) && DllCall("IsWindow", "Ptr", s.g.Hwnd))
        return
    familia := "Segoe UI"
    try familia := Trim(_Tema("type", "family", "Segoe UI"))
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000", "Selector de Modo")
    g.BackColor := _TemaHex("surface.base", "12141A")
    g.MarginX := 0
    g.MarginY := 0
    g.SetFont("s9 bold", familia)
    s.tN := g.Add("Text", "x" _E(6) " y" _E(6) " w" _E(88) " h" _E(26) " Center +0x200 +0x100", "🖥 NORMAL")
    s.tE := g.Add("Text", "x" _E(96) " y" _E(6) " w" _E(88) " h" _E(26) " Center +0x200 +0x100", "🔍 ENFOQUE")
    s.tS := g.Add("Text", "x" _E(188) " y" _E(6) " w" _E(26) " h" _E(26) " Center +0x200 +0x100", "💾")
    g.SetFont("s8 norm", familia)
    s.tI := g.Add("Text", "x" _E(6) " y" _E(37) " w" _E(208) " h" _E(16) " +0x200 +0x100", "")
    s.tI.SetFont("c" _TemaHex("text.muted", "8E97A8"))
    s.tN.OnEvent("Click", (*) => EstablecerModoTrabajo("Normal"))
    s.tE.OnEvent("Click", (*) => EstablecerModoTrabajo("Enfoque"))
    s.tS.OnEvent("Click", (*) => _ModoGuardarActivo())
    s.g := g
    w := _E(220)
    h := _E(58)
    modo := (IsSet(enfoque) && enfoque.activo) ? "Enfoque" : "Normal"
    pos := 0
    try pos := _ModoSelPosGuardada(modo)
    if (!pos) {
        mon := {x: 0, y: 0, w: A_ScreenWidth, h: A_ScreenHeight}
        try mon := ObtenerMonitorCSP()
        pos := {x: mon.x + (mon.w - w) // 2, y: mon.y + mon.h - h - _E(70)}
    }
    g.Show("Hide NoActivate x" pos.x " y" pos.y " w" w " h" h)
    WinSetTransparent(_AlphaTema("pill", 235), g)
    if IsSet(GfxMascaraRedondeada)
        GfxMascaraRedondeada(g.Hwnd, w, h, 8)
    if !s.msg {
        OnMessage(0x0201, _ModoSel_WM_LBUTTONDOWN)
        s.msg := true
    }
    SetTimer(_ModoSelVigilar, 500)
}
_ModoSelPintarSeg(c, on) {
    bg := on ? _TemaHex("accent.info", "00E5FF") : _TemaHex("surface.off", "333333")
    fg := on ? _TemaHex("knob.text", "23232B") : _TemaHex("text.idle", "8A8A8A")
    c.Opt("+Background" bg)
    c.SetFont("c" fg)
    c.Redraw()
}
_ModoSelRefrescar() {
    global enfoque
    if !IsSet(enfoque)
        return
    act := enfoque.activo ? 1 : 0
    modo := act ? "Enfoque" : "Normal"
    try _ModoTrayMarcar(act)
    s := _ModoSel()
    if !IsObject(s.g)
        return
    try {
        _ModoSelPintarSeg(s.tN, !act)
        _ModoSelPintarSeg(s.tE, act)
        n := _ModoContarGuardados(modo)
        s.tI.Text := "Activo: " StrUpper(modo) "  ·  " (n = 4 ? "✓ ubicaciones 4/4" : "⚠ " n "/4 guardadas, usa 💾")
    }
}
_ModoSelVigilar() {
    global panelBlk
    s := _ModoSel()
    if (!IsObject(s.g) || !DllCall("IsWindow", "Ptr", s.g.Hwnd)) {
        SetTimer(_ModoSelVigilar, 0)
        return
    }
    hwnd := s.g.Hwnd
    debe := s.visible && (WinActive("ahk_exe CLIPStudioPaint.exe") || (IsSet(panelBlk) && panelBlk.frente) || WinActive("ahk_id " hwnd))
    visible := DllCall("IsWindowVisible", "Ptr", hwnd)
    if (debe && !visible)
        s.g.Show("NoActivate")
    else if (!debe && visible)
        s.g.Hide()
}
ModoSel_Alternar() {
    s := _ModoSel()
    s.visible := !s.visible
    IniWrite(s.visible ? 1 : 0, _PosGuiIniPath(), "ModoSel", "visible")
    if (s.visible) {
        _ModoSelCrear()
        _ModoSelRefrescar()
        try s.g.Show("NoActivate")
    } else if IsObject(s.g) {
        try s.g.Hide()
    }
    MostrarHUD(s.visible ? "🎛 SELECTOR DE MODO: VISIBLE" : "🎛 SELECTOR DE MODO: OCULTO", "00E5FF", 800)
}
_ModoGuardarActivo() {
    global enfoque
    if !IsSet(enfoque)
        return
    _CapturarLayout(enfoque.activo ? "Enfoque" : "Normal")
    _ModoSelRefrescar()
}
_ModoTrayConstruir() {
    s := _ModoSel()
    if IsObject(s.tray)
        return s.tray
    mt := Menu()
    mt.Add("🖥 Modo 1 · Normal", (*) => EstablecerModoTrabajo("Normal"))
    mt.Add("🔍 Modo 2 · Enfoque", (*) => EstablecerModoTrabajo("Enfoque"))
    mt.Add()
    mt.Add("🎛 Selector flotante: Mostrar/Ocultar", (*) => ModoSel_Alternar())
    mt.Add("💾 Guardar ubicaciones en el modo activo", (*) => _ModoGuardarActivo())
    A_TrayMenu.Add("Modo de trabajo", mt)
    s.tray := mt
    return mt
}
_ModoTrayMarcar(act) {
    mt := _ModoTrayConstruir()
    try mt.Uncheck("🖥 Modo 1 · Normal")
    try mt.Uncheck("🔍 Modo 2 · Enfoque")
    mt.Check(act ? "🔍 Modo 2 · Enfoque" : "🖥 Modo 1 · Normal")
}
_ModoSelArranque() {
    s := _ModoSel()
    try _ModoTrayConstruir()
    v := IniRead(_PosGuiIniPath(), "ModoSel", "visible", "0")
    s.visible := (v = "1")
    if (s.visible)
        _ModoSelCrear()
    _ModoSelRefrescar()
}
_ModoSel_WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global panelBlk
    s := _ModoSel()
    if !IsObject(s.g)
        return
    if (hwnd != s.g.Hwnd && hwnd != s.tI.Hwnd)
        return
    if (IsSet(panelBlk) && panelBlk.locked)
        return
    PostMessage(0xA1, 2, 0, , "ahk_id " s.g.Hwnd)   ; arrastre por la línea de estado
}
