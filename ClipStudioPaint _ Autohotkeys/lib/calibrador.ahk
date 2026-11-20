#Requires AutoHotkey v2.0
; [LIB] calibrador — fuente: XPPEN AHK VERSION ESTABLE.ahk L4601–4883, 4910–5517
; ===== Zonas duales: selector [NORMAL | ENFOQUE] del panel =====
_PtsModoMarcar() {
    global ptsModo,ptsEd,enfoque
    if (!IsObject(ptsModo.btnN) || !IsObject(ptsModo.btnE))
        return
    sel := (ptsModo.sel = 2) ? 2 : 1
    vivo := enfoque.activo ? 2 : 1
    try {
        ptsModo.btnN.Text := "🖼  " . ((sel = 1) ? "● " : "○ ") . "NORMAL · Modo 1" . ((vivo = 1) ? "  [activo en CSP]" : "")
        ptsModo.btnE.Text := "🎯  " . ((sel = 2) ? "● " : "○ ") . "ENFOQUE · Modo 2" . ((vivo = 2) ? "  [activo en CSP]" : "")
        ptsModo.btnN.SetFont((sel = 1) ? "s9 bold" : "s9 norm")
        ptsModo.btnE.SetFont((sel = 2) ? "s9 bold" : "s9 norm")
    }
    try ptsModo.barN.Value := (sel = 1) ? 100 : 0     ; tira azul bajo el botón elegido
    try ptsModo.barE.Value := (sel = 2) ? 100 : 0
    try {
        ptsModo.btnN5.Text := ((sel = 1) ? "● " : "○ ") . "NORMAL" . ((vivo = 1) ? " ✓" : "")
        ptsModo.btnE5.Text := ((sel = 2) ? "● " : "○ ") . "ENFOQUE" . ((vivo = 2) ? " ✓" : "")
        ptsModo.btnN5.SetFont((sel = 1) ? "s9 bold" : "s9 norm")
        ptsModo.btnE5.SetFont((sel = 2) ? "s9 bold" : "s9 norm")
    }
    try ptsEd.g.Title := "📍 Calibración · rangos, avisos y sistema  ·  editando " . ((sel = 2) ? "ENFOQUE · Modo 2" : "NORMAL · Modo 1")
}
PtsModo_Set(m) {
    global ptsModo,ptsEd,enfoque
    m := (m = 2) ? 2 : 1
    if (ptsEd.dibujando || ptsEd.capturando || (ptsModo.sel = m && (enfoque.activo ? 2 : 1) = m)) {
        _PtsModoMarcar()
        return
    }
    ptsModo.edit := true
    if (ptsModo.sel != m)
        _PtsModoCambiar(m)
    if ((enfoque.activo ? 2 : 1) != m)
        AccionEnfoque()
    else
        _PtsModoMarcar()
}

_PtsRefrescarDiferido() {
    global ptsEd
    if (!IsSet(ptsEd) || !IsObject(ptsEd) || !ptsEd.g || !IsObject(ptsEd.g))
        return
    lv := 0
    try lv := ptsEd.lv
    try lv.Opt("-Redraw")
    try {
        _PtsRefrescar()
        try _NvPanRefrescarTabla()
        try {
            if (HasProp(ptsEd, "stNvZonas") && IsObject(ptsEd.stNvZonas))
                ptsEd.stNvZonas.Text := _NvPanTexto()
        }
    } finally {
        try lv.Opt("+Redraw")
    }
}
_PtsModoCambiar(m) {
    global ptsModo,ptsEd
    try GuardarPuntos(false)      ; vuelca el modo que se abandona (ptsModo.sel aún es el anterior)
    ptsModo.sel := m
    ptsModo.edit := true
    CargarPuntos()                ; PUNTOS / ZONAS / HIST_ALTO pasan al modo elegido
    _PtsRefrescar()               ; RecalcularZonas + filas del ListView en caliente
    _PtsModoMarcar()
    try _NvPanRefrescarTabla()        ; lvNv con los valores del nuevo modo
    if (IsObject(ptsEd) && HasProp(ptsEd,"ovl") && IsObject(ptsEd.ovl) && ptsEd.ovl.Length > 0) {
        OcultarZonasCalibracion()     ; destruye cajas + etiquetas del modo anterior
        MostrarZonasCalibracion()     ; recalcula y dibuja las del modo nuevo
    }
    ; re-selecciona la fila actual para que las cajas X/Y/Ancho/Alto muestren los valores del modo nuevo
    if (IsObject(ptsEd.lv)) {
        r := (IsInteger(ptsEd.sel) && ptsEd.sel > 0) ? Integer(ptsEd.sel) : 1
        try ptsEd.lv.Modify(0,"-Select")
        try ptsEd.lv.Modify(r,"Select Focus Vis")
    }
}
_PtsModoVigilar() {
    global ptsModo,ptsEd
    if (ptsModo.recreando)
        return
    if (!IsObject(ptsEd.g) || ptsEd.g = 0)
        return
    vivo := 0
    try vivo := ptsEd.g.Hwnd ? WinExist("ahk_id " ptsEd.g.Hwnd) : 0
    if (vivo)
        return
    SetTimer(_PtsModoVigilar,0)
    OcultarZonasCalibracion()
    if (!ptsModo.edit)
        return
    try GuardarPuntos(false)
    ptsModo.edit := false
    ptsModo.btnN := 0
    ptsModo.btnE := 0
    CargarPuntos()                ; vuelve al modo vivo de CSP
}
PtsModo_SincronizarCSP() {        ; la llama AccionEnfoque tras conmutar enfoque.activo
    global ptsModo,enfoque
    Critical("On")
    hot := enfoque.activo ? 2 : 1
    if (!ptsModo.edit)
        CargarPuntos()
    else if (ptsModo.sel = hot)
        _PtsModoMarcar()
    else
        _PtsModoCambiar(hot)
    Critical("Off")
}

; ===== Sistema de Tooltips Contextuales (Hover en controles) =====
_AyudaEstado() {
    static e := {mapa: Map(), actual: 0}
    return e
}

AyudaRegistrar(ctrl, texto) {
    if (texto = "") {
        if _AyudaEstado().mapa.Has(ctrl.Hwnd)
            _AyudaEstado().mapa.Delete(ctrl.Hwnd)
    } else {
        _AyudaEstado().mapa[ctrl.Hwnd] := texto
    }
}
_AyudaReg(ctl, texto) => AyudaRegistrar(ctl, texto)

AyudaIniciar() {
    static activo := false
    if activo
        return
    activo := true
    OnMessage(0x0200, _MostrarAyudaContextual)        ; WM_MOUSEMOVE
}

_MostrarAyudaContextual(wParam, lParam, msg, hwnd) {
    e := _AyudaEstado()
    MouseGetPos(, , , &ch, 2)
    if (ch = e.actual)
        return
    e.actual := ch
    ToolTip(, , , 19)
    SetTimer(_AyudaMostrar.Bind(ch), -450)            ; retardo de hover
    SetTimer(_AyudaVigilar, 150)
}

_AyudaMostrar(ch) {
    e := _AyudaEstado()
    if (ch != e.actual || !e.mapa.Has(ch))
        return
    ToolTip(e.mapa[ch], , , 19)
}

_AyudaVigilar() {
    e := _AyudaEstado()
    MouseGetPos(, , , &ch, 2)
    if (ch && ch = e.actual)
        return
    e.actual := 0
    ToolTip(, , , 19)
    SetTimer(_AyudaVigilar, 0)
}

AbrirPanelPuntos() {
    global PERFIL,PERFILES,ESC,AVISO_ESC,panelBlk,ESTAB_ALPHA_H,ESTAB_ALPHA_F,ptsPend
    if (!IsSet(ptsPend) || !IsObject(ptsPend))
        ptsPend := Map()
    AyudaIniciar()
    if (!ptsModo.recreando) {
        if (IsObject(ptsEd.g) && !ptsModo.edit) {   ; panel oculto/cerrado antes: se reconstruye con el modo vivo
            try OnMessage(0x004E,_PtsTemaLvNotify, 0)
    ptsEd.temaLvHwnd := 0
    ptsEd.temaLv := 0
    try ptsEd.g.Destroy()
            ptsEd.g := 0
        }
        ptsModo.sel := enfoque.activo ? 2 : 1
        ptsModo.edit := true
    }
    if IsObject(ptsEd.g) {
        try {
            if (WinGetMinMax("ahk_id " ptsEd.g.Hwnd) = -1)
                ptsEd.g.Restore()
            else
                ptsEd.g.Show()
            return
        }
        ptsEd.g := 0
    }
    defs := _PtsZonaDefs()
    evs := _PtsEventosDefs()
    _PtsEvLeer()
    ptsEd.nac := _PtsMonNacim()             ; monitor de nacimiento (tableta); mismo para escala y ajuste
    uiF := _PtsUIEscala()
    uiS := (n) => Round(n * uiF)
    uiP := (px, py, pw, ph := 0) => Format("x{} y{} w{}{}", uiS(px), uiS(py), uiS(pw), ph ? " h" uiS(ph) : "")
    fs := Round(9 * Min(uiF, 1.35))
    ptsTop := (Trim(IniRead(_PosGuiIniPath(),"Calibrador","alwaysOnTop","1")) != "0")
    g := Gui("+Resize" . (ptsTop ? " +AlwaysOnTop" : ""),"📍 Calibración · rangos, avisos y sistema")
    ptsEd.ly := {top: ptsTop, foco: false, listo: false, items: [], cols: [], dx: 0, dy: 0, cw0: 0, ch0: 0, bTop: 0}
    g.SetFont("s" fs,"Segoe UI")
    TW := 736          ; ancho de la pestaña (unidades lógicas, se escalan con uiF)
    TH := 580          ; alto de la pestaña
    cw := 704          ; ancho útil dentro de la pestaña
    x0 := 28
    tb := g.Add("Tab3",uiP(12,12,TW,TH),["🔔 Eventos y particularidades","📐 Zonas y rangos","⚙ Sistema y perfiles","🎨 Paleta de temas"])
    lyM := [_PtsLayCuenta(g)]

    ; ---------------- Pestaña 1: eventos y particularidades ----------------
    tb.UseTab(1)
    p1wL := 220                      ; ancho columna izquierda (catálogo)
    p1xR := x0 + p1wL + 16           ; x de la columna derecha (editor)
    p1wR := cw - p1wL - 16           ; ancho de la columna derecha

    lbT1 := g.Add("Text",uiP(x0,50,p1wL - 64,22) . " +0x200","Catálogo de eventos")
    lbT1.SetFont("w600")
    btnNuevoEv := g.Add("Button",uiP(x0 + p1wL - 28,48,28,24),"➕")
    btnAgrupar := g.Add("Button",uiP(x0 + p1wL - 58,48,28,24),"▦")
    ptsEd.btnAgrupar := btnAgrupar
    btnAgrupar.OnEvent("Click", _PtsEvToggleAgrupar)
    btnNuevoEv.OnEvent("Click", (*) => _PtsNuevoEvento())

    ; --- P1: buscador del catálogo (columna izquierda) ---
    p1edBuscar := g.Add("Edit", uiP(x0,76,p1wL,24))
    SendMessage(0x1501, 1, StrPtr("🔍 Buscar evento..."), p1edBuscar.Hwnd)   ; EM_SETCUEBANNER
    p1edBuscar.OnEvent("Change", _PtsBuscarCambio)

    ddGrupo := g.Add("DropDownList",uiP(x0,104,p1wL) . " Choose1",["📁 Todos los grupos","No definidos","Pinceles y Trazos","Borradores y Mezcla","Color y Paleta","Selección","Lienzo y Reglas","Capas y Archivo","Personalizados"])
    lvEv := g.Add("ListView",uiP(x0,134,p1wL,426) . " +Multi NoSortHdr Grid +LV0x10000",["Acción (evento)","Atajo CSP","Remapeo Companion","Particularidades","Grupo","Formato","Prioridad","Opac.","Duración"])
    ; Respaldo: fuerza LVS_EX_DOUBLEBUFFER (0x10000) por mensaje (LVM_SETEXTENDEDLISTVIEWSTYLE = 0x1036)
    SendMessage(0x1036, 0x10000, 0x10000, lvEv.Hwnd)

    ; --- P1: encabezado del evento (columna derecha) ---
    lbT2 := g.Add("Text",uiP(p1xR,50,p1wR - 130,18) . " +0x200","Editor de evento")
    lbT2.SetFont("w600")
    p1tTitulo := g.Add("Text", uiP(p1xR,70,p1wR - 140,30) . " +0x200", "Seleccione un evento")
    p1tTitulo.SetFont("s14 bold")
    p1tSub := g.Add("Text", uiP(p1xR,100,p1wR - 140,18) . " +0x200", "Configuración del evento seleccionado")
    p1ddEstado := g.Add("DropDownList", uiP(p1xR + p1wR - 124,58,124) . " Choose1", ["✔ Activo","⏸ Inactivo"])
    p1Anchor := g.Add("Text", uiP(p1xR,99,p1wR,1) . " Hidden")   ; ancla del viewport (borde inferior + 30px = y 130)

    ; Hotkey Esc para cerrar el panel
    g.OnEvent("Escape", _PtsEscCerrar)

    ptsEd.edBuscar := p1edBuscar
    ptsEd.p1tTitulo := p1tTitulo
    ptsEd.p1tSub := p1tSub
    ptsEd.p1ddEstado := p1ddEstado
    p1ddEstado.OnEvent("Change", _PtsEvEstadoCambio)
    ptsEd.filtroEv := ""
    lvEv.OnEvent("ItemSelect", _PtsEvEncabezado)     ; se suma a _PtsEvSel, no lo reemplaza

    ; Lista de una sola columna visible (las demás quedan a ancho 0, siguen legibles con GetText)
    loop lvEv.GetCount("Col") - 1
        lvEv.ModifyCol(A_Index + 1, 0)
    lvEv.ModifyCol(1, Round((p1wL - 26) * A_ScreenDPI / 96))

    ; ===== PANEL EMBEBIDO CON MOTOR DE ACORDEÓN (Fase A) =====
    _AccInit(g, tb, x0, p1wR - 18, uiP, p1Anchor)
    gMain := g, uiMain := uiP            ; Box 2 se construye DENTRO del viewport
    g := ACC.g, uiP := ACC.uiP           ; ACC.g = viewport, ACC.uiP = coords locales
    try {

    ; --- métricas de layout (todo derivado de cw) ---
    lyCw := ACC.cw
    lyK := Min(1.4, Max(0.85, lyCw / _LyBase()))
    lyS := (v) => Round(v * lyK)
    lyXr := x0 + Round(lyCw * 0.37)      ; inicio zona de controles
    lyXe := x0 + lyCw - 14               ; borde derecho útil
    lyXc := lyXe - lyS(32)               ; borde derecho cuando hay check
    lyIx := x0 + Round(lyCw * 0.325)     ; icono "probar" junto al título
    lyL := x0 + 14

    ; --- (A) Configuración básica: contenedor de 01/02/03 ---
    pGA := _AccNuevo("gA", "(A) Configuración básica", _LyY("gA"), 0, true)
    _R(g.Add("Text",uiP(x0 + 14,_LyY("gA") + 24,lyCw - 28,20) . " +0x200 cGray","Identidad, apariencia y comportamiento general del evento."))
    _AccFin()
    _AccGrupoDef("gA", ["p1","p2","snd"])

    ; --- [1] Base (fila fija) ---
    lyY := _LyY("p1"), a := lyY + 14
    _AccNuevo("p1", "Base", lyY, _AccResumen1, true, true)
    _LyEncab(x0, lyCw, lyY, "01", "Base", "Atajo CSP · Remapeo Companion")
    cx := Max(lyXr, lyXe - (lyS(404) + lyS(26)))
    lbA := _R(g.Add("Text",uiP(cx,a,lyS(62),24) . " +0x200 +0x100","Atajo CSP:"))
    cx += lyS(66)
    edAtajo := _R(g.Add("Edit",uiP(cx,a,lyS(90),24),""))
    indAtajo := _R(g.Add("Text",uiP(cx + lyS(90) - 22,a + 3,19,18) . " +0x200 +0x100 +Center +BackgroundFFFFFF",""))
    cx += lyS(98)
    lbR := _R(g.Add("Text",uiP(cx,a,lyS(66),24) . " +0x200 +0x100","Remapeo:"))
    cx += lyS(70)
    edRemap := _R(g.Add("Edit",uiP(cx,a,lyS(130),24),""))
    indRemap := _R(g.Add("Text",uiP(cx + lyS(130) - 22,a + 3,19,18) . " +0x200 +0x100 +Center +BackgroundFFFFFF",""))
    cx += lyS(136)
    bRemapGuardar := _R(g.Add("Button",uiP(cx,a,lyS(28),24),"💾"))
    _AyudaReg(bRemapGuardar, "Guardar atajo de remapeo.")
    cx += lyS(32)
    bRemapReset := _R(g.Add("Button",uiP(cx,a,lyS(28),24),"↺"))
    _AyudaReg(bRemapReset, "Restablecer atajo por defecto.")
    _AccFin()
    _AccFila(_LyH("p1"))
    _KgAttach(edAtajo, _PtsAtajoAviso)
    _KgAttach(edRemap, _PtsAtajoAviso)
    _PtsIndInit(edAtajo, indAtajo, edRemap, indRemap, lbA, lbR)
    edAtajo.OnEvent("Change", (*) => _PtsIndRefrescar())
    edRemap.OnEvent("Change", (*) => _PtsIndRefrescar())
    lvEv.OnEvent("ItemSelect", (*) => SetTimer(_PtsIndRefrescar, -50))
    lvEv.OnEvent("ItemSelect", (*) => SetTimer(_PtsHudChkSync, -60))
    bRemapGuardar.OnEvent("Click", (*) => SetTimer(_PtsIndOk, -60))

    ; --- [2] Feedback visual: HUD (fila fija + 2 líneas) ---
    lyY := _LyY("p2"), r1 := lyY + 14, lyB := lyY + 56, lyC := lyY + 86
    _AccNuevo("p2", "Feedback visual (HUD)", lyY, _AccResumen2, true, true)
    _LyEncab(x0, lyCw, lyY, "02", "Feedback visual (HUD)", "Formato · Zona · Opacidad · Texto · Duración")
    bEvProbar := _R(g.Add("Button",uiP(lyIx,lyY + 4,24,24),"🔔"))
    _AyudaReg(bEvProbar, "Probar el aviso HUD.")
    chkHud := _R(g.Add("CheckBox",uiP(lyXe - 22,lyY + 15,22,22),""))
    chkHud.Value := 1
    _AyudaReg(chkHud, "Activar/desactivar el HUD (equivale a Formato = Desactivado).")
    cx := Max(lyXr, lyXc - lyS(410))
    _R(g.Add("Text",uiP(cx,r1,lyS(54),24) . " +0x200","Formato:"))
    cx += lyS(56)
    ddF := _R(g.Add("DropDownList",uiP(cx,r1,lyS(84)) . " Choose1",["Moderno","Bruto","Desactivado"]))
    _AyudaReg(ddF, "Formato HUD: aspecto visual del aviso (Moderno con corchetes, Bruto minimalista o Desactivado).")
    cx += lyS(92)
    _R(g.Add("Text",uiP(cx,r1,lyS(34),24) . " +0x200","Zona:"))
    cx += lyS(36)
    ddZ := _R(g.Add("DropDownList",uiP(cx,r1,lyS(62)) . " Choose3",["Alta","Media","Baja"]))
    cx += lyS(70)
    _R(g.Add("Text",uiP(cx,r1,lyS(62),24) . " +0x200","Opacidad:"))
    cx += lyS(64)
    ddOp := _R(g.Add("DropDownList",uiP(cx,r1,lyS(92)) . " Choose2",["100% (Máx)","70% (Med)","40% (Bajo)"]))
    chkHud.OnEvent("Click", _PtsHudChkClick)
    ddF.OnEvent("Change", _PtsHudChkSync)
    _LyHudCtl(chkHud)
    ; línea 2: texto · duración · anclar/reubicar
    cx := lyL
    lyEt := Max(lyS(90), (lyXe - lyL) - lyS(496))
    _R(g.Add("Text",uiP(cx,lyB,lyS(82),24) . " +0x200","Texto evento:"))
    cx += lyS(84)
    eTxtEv := _R(g.Add("Edit",uiP(cx,lyB,lyEt,24),""))
    cx += lyEt + lyS(3)
    bTxtEv := _R(g.Add("Button",uiP(cx,lyB,lyS(28),24),"✏"))
    _AyudaReg(bTxtEv, "Guardar texto del evento.")
    cx += lyS(30)
    bTxtReset := _R(g.Add("Button",uiP(cx,lyB,lyS(28),24),"↺"))
    _AyudaReg(bTxtReset, "Restablecer texto por defecto.")
    cx += lyS(38)
    _R(g.Add("Text",uiP(cx,lyB,lyS(86),24) . " +0x200","Duración (ms):"))
    cx += lyS(88)
    eDurEv := _R(g.Add("Edit",uiP(cx,lyB,lyS(56),24),""))
    try SendMessage(0x1501, 1, StrPtr("Auto"), eDurEv.Hwnd)
    _AyudaReg(eDurEv, "Duración propia del aviso (ms). Vacío o Auto = hereda la duración por prioridad.")
    cx += lyS(59)
    bDurEv := _R(g.Add("Button",uiP(cx,lyB,lyS(28),24),"⏱"))
    _AyudaReg(bDurEv, "Aplicar duración propia.")
    cx += lyS(32)
    lblDurEfec := _R(g.Add("Text",uiP(cx,lyB,lyS(100),24) . " +0x200 cGray","Efectiva: —"))
    lblDurEfec.SetFont("s" _LyFs(8))
    cx += lyS(100)
    bEvAnclar := _R(g.Add("Button",uiP(cx,lyB,lyS(30),24),"📌"))
    _AyudaReg(bEvAnclar, "Anclar el HUD de este evento.")
    cx += lyS(32)
    bEvReub := _R(g.Add("Button",uiP(cx,lyB,lyS(30),24),"📍"))
    _AyudaReg(bEvReub, "Reubicar la zona del HUD.")
    ; línea 3: duración por prioridad
    cx := lyL
    _R(g.Add("Text",uiP(cx,lyC,lyS(124),24) . " +0x200 cGray","Duración x prioridad:"))
    cx += lyS(128)
    _R(g.Add("Text",uiP(cx,lyC,lyS(32),24) . " +0x200","Alta:"))
    cx += lyS(34)
    eDurA := _R(g.Add("Edit",uiP(cx,lyC,lyS(50),24), IniRead(_PosGuiIniPath(),"HudDuraciones" PERFIL,"duracion_alta","300")))
    cx += lyS(58)
    _R(g.Add("Text",uiP(cx,lyC,lyS(42),24) . " +0x200","Media:"))
    cx += lyS(44)
    eDurM := _R(g.Add("Edit",uiP(cx,lyC,lyS(50),24), IniRead(_PosGuiIniPath(),"HudDuraciones" PERFIL,"duracion_media","500")))
    cx += lyS(58)
    _R(g.Add("Text",uiP(cx,lyC,lyS(34),24) . " +0x200","Baja:"))
    cx += lyS(36)
    eDurB := _R(g.Add("Edit",uiP(cx,lyC,lyS(50),24), IniRead(_PosGuiIniPath(),"HudDuraciones" PERFIL,"duracion_baja","400")))
    cx += lyS(58)
    bDurGuardar := _R(g.Add("Button",uiP(cx,lyC,lyS(28),24),"💾"))
    _AyudaReg(bDurGuardar, "Guardar duraciones por prioridad.")
    cx += lyS(36)
    _R(g.Add("Text",uiP(cx,lyC,lyS(150),24) . " +0x200 cGray","(def: 3, 5, 4 ms/s)"))
    _AccFin()
    _AccFila(_LyH("p2"))

    ; --- [3] Feedback sonoro (fila fija + 1 línea) ---
    lyY := _LyY("snd"), s1 := lyY + 14, s2 := lyY + 56
    _AccNuevo("snd", "Feedback sonoro", lyY, _AccResumenSnd, true, true)
    _LyEncab(x0, lyCw, lyY, "03", "Feedback sonoro", "Ámbito · Activación · Sonido · Volumen")
    bSndProbar := _R(g.Add("Button",uiP(lyIx,lyY + 4,24,24),"🔊"))
    _AyudaReg(bSndProbar, "Probar el sonido.")
    cx := Max(lyXr, lyXe - lyS(428))
    cbSndAct := _R(g.Add("CheckBox",uiP(cx,s1 + 1,lyS(76),22),"Activar"))
    cx += lyS(86)
    _R(g.Add("Text",uiP(cx,s1,lyS(50),24) . " +0x200","Sonido:"))
    cx += lyS(52)
    ddSndTipo := _R(g.Add("DropDownList",uiP(cx,s1,lyS(100)) . " Choose1",_SndTiposDef().nombres))
    cx += lyS(110)
    _R(g.Add("Text",uiP(cx,s1,lyS(60),24) . " +0x200","Volumen:"))
    cx += lyS(62)
    slSndVol := _R(g.Add("Slider",uiP(cx,s1,lyS(76),24) . " Range0-100 NoTicks",60))
    cx += lyS(78)
    lblSndVol := _R(g.Add("Text",uiP(cx,s1,lyS(40),24) . " +0x200","60%"))
    ; línea 2: ámbito · heredar · efectivo
    cx := lyL
    _R(g.Add("Text",uiP(cx,s2,lyS(54),24) . " +0x200","Ámbito:"))
    cx += lyS(56)
    ddSndAmb := _R(g.Add("DropDownList",uiP(cx,s2,lyS(110)) . " Choose1",["Global","Este evento"]))
    cx += lyS(120)
    bSndHeredar := _R(g.Add("Button",uiP(cx,s2,lyS(142),24),"↺ Heredar de Global"))
    cx += lyS(150)
    lblSndEfec := _R(g.Add("Text",uiP(cx,s2,Max(lyS(60),lyXe - cx),24) . " +0x200 cGray",""))
    _AccFin()
    _AccFila(_LyH("snd"))

    ; --- [4] Comportamientos (avanzado) ---
    _AccNuevo("p4", "(B) Particularidades", 612, _AccResumen3, false)
    _CompInit()
    COMP.lblEv := _R(g.Add("Text",uiP(x0 + 14,612 + 24,400,20) . " +0x200 cGray","Funciones especiales que modifican el evento."))
    _CompBloqueNuevo("b1", "01", "Presencia y Superficie", "Pildora táctil en pantalla que dispara el evento con lápiz o dedo.", 612 + 44, true) ; ===== BLOQUE_B_P1_BEGIN =====
    cbPill  := _CompFila("pildora", "Mostrar píldora táctil", 612 + 44,
        ["Botón táctil en pantalla que dispara este evento con lápiz o dedo."], "b1", false, "pildora")
    _PtsPildoraBtnAgregar(x0 + 34, 612 + 68)
    _CompBloqueNuevo("b2", "02", "Disparador Espacial", "Paso → Tecla CSP, Paso → Clic, Hover por rango.", 612 + 116) ; ===== BLOQUE_B_P2_BEGIN =====
    cbCruzar := _CompFila("cruzar", "Paso ➔ Tecla CSP", 612 + 92,
        ["Al pasar el lápiz por el rango se envía el atajo."], "b2", false, "rango")
    cbAuto   := _CompFila("auto", "Paso ➔ Clic (auto-clic)", 612 + 116,
        ["Al pasar el lápiz se ejecuta un clic automático."], "b2", false, "rango")
    cbHover  := _CompFila("hover", "Hover por rango", 612 + 140,
        ["Respuesta visual según la posición."], "b2", false, "rep act borde")
    _CompBloqueNuevo("b3", "03", "Modulación de Tecla", "Pulsación rápida, Alternador A ⇄ B.", 612 + 164) ; ===== BLOQUE_B_P3_BEGIN =====
    cbQuick  := _CompFila("quick", "Pulsación rápida", 612 + 188,
        ["Toque corto / toque rápido."], "b3", false, "quick")
    cbToggle := _CompFila("toggle", "Alternador A ⇄ B", 612 + 212,
        ["Alterna entre Tecla A y Tecla B."], "b3", false, "toggle")
    _CompBloqueNuevo("b4", "04", "Deslizador Virtual", "Deslizador universal, Snap y control de precisión.", 612 + 236) ; ===== BLOQUE_B_P4_BEGIN =====
    cbSlider := _CompFila("slider", "Deslizador Universal", 612 + 260,
        ["Teclas subir/bajar, Snap points, opacidades y botones de dibujo."], "b4", false, "slider")
    _CompBloqueNuevo("b5", "05", "Nuevas Ventanas y Lienzos", "Visibilidad de zonas, nuevas ventanas y lienzos.", 612 + 284) ; ===== BLOQUE_B_P5_BEGIN =====
    cbNv     := _CompFila("ventanas", "Lienzos y Nuevas Ventanas", 612 + 308,
        ["Visibilidad y zonas de lienzos auxiliares con dibujo directo en un solo toque."], "b5", false, "ventanas")
    _AccFin()
    p4 := _AccPanel("p4")
    COMP.panel := p4
    p4.altoFn := _CompAlto
    p4.posFn  := _CompPos

    stEv := _AccPie(g.Add("Text",uiP(x0,656,cw,22) . " cGray +0x200","▶ Selecciona un evento para ver o editar sus particularidades."))
    } finally {
        g := gMain, uiP := uiMain            ; restaurar contexto de la ventana principal
    }
    tb.OnEvent("Change", (*) => _AccRelayout())
    _AccAjustar()
    _AccRelayout()

    ; ---------------- Pestaña 2: zonas y rangos ----------------
    tb.UseTab(2)
    lyM.Push(_PtsLayCuenta(g))
    g.Add("Text",uiP(x0,50,cw,34),"Dibuja cada zona arrastrando el lápiz sobre la pantalla (un clic = punto). Doble toque en una fila = dibujar. Los puntos P1..P32 se recalculan solos para los demás scripts.")
    mdH := (cw - 12) // 2                                   ; ancho de cada bloque de modo (12 px de separación central)
    bModoN := g.Add("Button",uiP(x0,88,mdH - 36,30),"")
    bGuardN := g.Add("Button",uiP(x0 + mdH - 36,88,36,30),"💾")
    g.Add("Text",uiP(x0 + mdH + 5,90,2,30) . " +0x11")      ; separador vertical grabado (SS_ETCHEDVERT)
    bModoE := g.Add("Button",uiP(x0 + mdH + 12,88,mdH - 36,30),"")
    bGuardE := g.Add("Button",uiP(x0 + mdH + 12 + mdH - 36,88,36,30),"💾")
    try bGuardN.SetFont("s10","Segoe UI Emoji")
    try bGuardE.SetFont("s10","Segoe UI Emoji")
    ptsModo.btnN := bModoN
    ptsModo.btnE := bModoE
    ptsModo.barN := g.Add("Progress",uiP(x0,118,mdH,6) . " -Theme c4A90E2 BackgroundD0D0D0",0)
    ptsModo.barE := g.Add("Progress",uiP(x0 + mdH + 12,118,mdH,6) . " -Theme c4A90E2 BackgroundD0D0D0",0)
    _PtsModoMarcar()
    bModoN.OnEvent("Click",(*) => PtsModo_Set(1))
    bModoE.OnEvent("Click",(*) => PtsModo_Set(2))
    bGuardN.OnEvent("Click",(*) => _CapturarLayout("Normal"))
    bGuardE.OnEvent("Click",(*) => _CapturarLayout("Enfoque"))
    lv := g.Add("ListView",uiP(x0,134,cw,266) . " -Multi NoSortHdr Grid",["Zona","Tipo","X","Y","Ancho","Alto"])
    for d in defs
        lv.Add("",d.n,(d.t = "punto") ? "Punto" : "Rango","","","","")
    lv.ModifyCol(1,uiS(284))
    lv.ModifyCol(2,uiS(70))
    Loop 4
        lv.ModifyCol(2 + A_Index,uiS(80))
    ; --- grupo: acciones sobre la zona seleccionada ---
    g.Add("GroupBox",uiP(x0,406,cw,58),"✏ Zona seleccionada")
    zbT := cw - 24
    zbC := Round(zbT * 0.40)                    ; bloque combinado [Dibujar zona][En cadena]
    zbA := zbC // 2
    zbB := zbC - zbA
    zbR := (zbT - zbC - 24) // 3                ; ancho de cada botón restante
    bDib := g.Add("Button",uiP(x0 + 12,430,zbA,28),"✏ Dibujar zona")
    bCad := g.Add("Button",uiP(x0 + 12 + zbA,430,zbB,28),"⏩ En cadena")
    bAjz := g.Add("Button",uiP(x0 + 12 + zbC + 8,430,zbR,28),"📐 Ajustar zona")
    bVer := g.Add("Button",uiP(x0 + 12 + zbC + 8 + (zbR + 8),430,zbR,28),"👁 Ver zonas")
    bDef := g.Add("Button",uiP(x0 + 12 + zbC + 8 + 2 * (zbR + 8),430,zbR,28),"↺ Por defecto")
    ; --- grupo: herramientas globales ---
    g.Add("GroupBox",uiP(x0,472,cw,106),"🧰 Herramientas globales")
    yg := 496
    g.Add("Text",uiP(x0 + 14,yg,200,26) . " +0x200","Desplazar TODOS los puntos:")
    g.Add("Text",uiP(x0 + 216,yg,24,26) . " +0x200","ΔX")
    dx := g.Add("Edit",uiP(x0 + 242,yg,70,26),"0")
    g.Add("Text",uiP(x0 + 326,yg,24,26) . " +0x200","ΔY")
    dy := g.Add("Edit",uiP(x0 + 352,yg,70,26),"0")
    bDelta := g.Add("Button",uiP(x0 + 440,yg - 1,110,28),"Aplicar Δ")
    yg2 := 536
    g.Add("Text",uiP(x0 + 14,yg2,110,26) . " +0x200","📐 Paneles CSP:")
    bTog1 := g.Add("Button",uiP(x0 + 126,yg2 - 1,190,28),"🎯 Alternar (1 ⇄ 2)")
    bTog1.OnEvent("Click",(*) => AccionEnfoque())

    ; ---------------- Pestaña 3: sistema y perfiles (dos columnas) ----------------
    tb.UseTab(3)
    lyM.Push(_PtsLayCuenta(g))
    xL := x0
    wL := 370
    xR := x0 + 382
    wR := 322
    ; --- grupo: perfil y escalas ---
    g.Add("GroupBox",uiP(xL,50,wL,132),"👤 Perfil y escalas")
    g.Add("Text",uiP(xL + 14,76,150,26) . " +0x200","Perfil de equipo:")
    ddl := g.Add("DropDownList",uiP(xL + 168,76,190) . " Choose" PERFIL,PERFILES)
    g.Add("Text",uiP(xL + 14,110,150,26) . " +0x200","Escala de botones (%):")
    eEsc := g.Add("Edit",uiP(xL + 168,110,60,26),Round(ESC * 100))
    g.Add("Text",uiP(xL + 236,110,126,26) . " +0x200 cGray","(al guardar)")
    g.Add("Text",uiP(xL + 14,144,150,26) . " +0x200","Escala de avisos (%):")
    eEscAv := g.Add("Edit",uiP(xL + 168,144,60,26),Round(AVISO_ESC * 100))
    g.Add("Text",uiP(xL + 236,144,126,26) . " +0x200 cGray","(HUD, mini-textos)")
    ; --- grupo: botones y paneles ---
    g.Add("GroupBox",uiP(xL,192,wL,126),"🧷 Botones del script y paneles de CSP")
    bMover := g.Add("Button",uiP(xL + 14,216,168,28),panelBlk.locked ? "🔓 Mover botones" : "🔒 Fijar botones")
    bReub := g.Add("Button",uiP(xL + 190,216,168,28),"↺ Reubicar botones")
    g.Add("Text",uiP(xL + 14,252,340,20) . " cGray","Layout de paneles de CSP (guardar / aplicar):")
    bLN := g.Add("Button",uiP(xL + 14,276,108,28),"💾 Normal")
    bLE := g.Add("Button",uiP(xL + 128,276,116,28),"💾 Enfoque")
    bLA := g.Add("Button",uiP(xL + 250,276,100,28),"▶ Aplicar")

    ; --- grupo: backup ---
    g.Add("GroupBox",uiP(xL,330,wL,112),"🗂 Copia de seguridad de posiciones_gui.ini")
    bBak := g.Add("Button",uiP(xL + 14,354,166,28),"💾 Crear backup")
    bRes := g.Add("Button",uiP(xL + 188,354,166,28),"↩ Restaurar último")
    lblBak := g.Add("Text",uiP(xL + 14,392,342,40) . " cGray","Sin backups todavía.")
    bBak.OnEvent("Click",_PtsBackupIni)
    bRes.OnEvent("Click",_PtsRestaurarIni)
    ; --- grupo (columna derecha): botón HUB ---
    g.Add("GroupBox",uiP(xR,50,wR,204),"🧩 Píldoras — marcar = mostrar")
    hubItems := [["lock","Bloquear"],["puntos","Calibrador"],["reload","Recargar"],["hc","Hist. Color"],["nv","Ventana"],["ar","Acceso R."],["ds","Slider"],["cc","CIRCLE"]]
    for i, it in hubItems {
        vis := !(hubGui.embebidos.Has(it[1]) && hubGui.embebidos[it[1]]) ? 1 : 0
        chk := g.Add("CheckBox",uiP(xR + 16 + Mod(i - 1,2) * 150,78 + ((i - 1) // 2) * 28,140,24) . " Checked" vis,it[2])
        chk.OnEvent("Click",_PtsHubToggle.Bind(it[1]))
    }
    g.Add("Text",uiP(xR,260,wR,34) . " cGray","Marcado = la píldora se muestra (por defecto nacen ocultas). Clic derecho en una píldora abre el menú.")

    ; --- grupo (columna derecha): acceso rápido (extras del menú clic derecho) ---
    g.Add("GroupBox",uiP(xR,300,wR,190),"⚡ Acceso rápido — menú clic derecho")
    rapItems := [["frente","📌 Frente"],["estab","🎚 Estabilizador"],["flip","🪞 Voltear lienzo"],["enfoque","🔍 Modo Enfoque"],["layout","📐 Layout Paneles"],["rapidas","⚡ Acciones Rápidas"],["audio","🔊 Restaurar audio"]]
    for i, it in rapItems {
        act := _HubRapidaActiva(it[1]) ? 1 : 0
        chk := g.Add("CheckBox",uiP(xR + 16 + Mod(i - 1,2) * 150,320 + ((i - 1) // 2) * 28,140,24) . " Checked" act,it[2])
        chk.OnEvent("Click",_HubToggleRapida.Bind(it[1]))
    }
    g.Add("Text",uiP(xR + 16,438,wR - 32,34) . " cGray","Marcado = aparece en el anticlick del companion. Sin marcar = solo desde aquí.")

    ; ---------------- Pestaña 4: paleta de temas (lista única con scroll) ----------------
    tb.UseTab(4)
    lyM.Push(_PtsLayCuenta(g))
    g.Add("Text",uiP(x0,50,cw,34),"Elige la paleta de colores y estilos para los botones del script, los colores de acento y los avisos en pantalla. Se guarda en theme.ini y se aplica al instante.")
    temaLbl := g.Add("Text",uiP(x0,86,cw,22) . " +0x200","")
    temaLbl.SetFont("s" fs " bold","Segoe UI")
    temas := _TemaPerfiles()
    lvTema := g.Add("ListView",uiP(x0,110,cw,350) . " -Multi NoSortHdr Grid",["Paleta","Color 1","Color 2","Color 3","Color 4","Color 5"])
    lvTema.ModifyCol(1,uiS(300))
    Loop 5
        lvTema.ModifyCol(1 + A_Index,uiS(76))
    for p in temas
        lvTema.Add("",p.nombre,p.swatches[1],p.swatches[2],p.swatches[3],p.swatches[4],p.swatches[5])
    ptsEd.temaLvHwnd := lvTema.Hwnd
    OnMessage(0x004E,_PtsTemaLvNotify)                 ; NM_CUSTOMDRAW: pinta cada celda con su color
    lvTema.OnEvent("ItemSelect",_PtsTemaSel)
    lvTema.OnEvent("ItemFocus",_PtsTemaFocus)
    lvTema.OnEvent("DoubleClick",_PtsTemaDobleClick)
    bwTema := 105
    xTemaAp := x0 + cw - 12 - bwTema
    xTemaProbar := xTemaAp - 8 - bwTema
    temaDesc := g.Add("Text",uiP(x0,466,xTemaProbar - x0 - 12,54) . " cGray","")
    bTemaProbar := g.Add("Button",uiP(xTemaProbar,466,bwTema,32),"🔔 Probar")
    bTemaAp := g.Add("Button",uiP(xTemaAp,466,bwTema,32),"✔ Aplicar")
    bTemaProbar.OnEvent("Click",(*) => _PtsTemaProbarSel())
    bTemaAp.OnEvent("Click",(*) => _PtsTemaAplicarSel())
    ptsEd.temaLbl := temaLbl
    ptsEd.temaLv := lvTema
    ptsEd.temaDesc := temaDesc
    ptsEd.temaBtn := bTemaAp
    ptsEd.temaBtnProbar := bTemaProbar
    ptsEd.temas := temas
    ptsEd.temaSel := 1
    ; ---------------- barra inferior ----------------
    tb.UseTab(0)
    lyM.Push(_PtsLayCuenta(g))                       ; lyM[5] = fin de la pestaña 4
    st := g.Add("Text",uiP(12,12 + TH + 8,TW,22),"")
    byb := 12 + TH + 36
    p2xPin := 12 + TW - 112                          ; borde derecho de la pestaña = 748
    p2xRei := p2xPin - 8 - 128
    p2xOk  := p2xRei - 8 - 142
    p2xSav := p2xOk  - 8 - 128
    bSav := g.Add("Button",uiP(p2xSav,byb,128,32),"💾 Guardar cambios")
    bOk := g.Add("Button",uiP(p2xOk,byb,142,32) . " +0xB","💾 Guardar y cerrar")
    bRei := g.Add("Button",uiP(p2xRei,byb,128,32),"🔄 Reiniciar script")
    bPin := g.Add("Button",uiP(p2xPin,byb,112,32),ptsTop ? "📌 Al frente" : "🪟 Normal")

    ; --- P2: línea separadora y contador del footer ---
    p2Sep := g.Add("Text",uiP(12,12 + TH + 2,TW,2) . " +0x10","")        ; SS_ETCHEDHORZ, se estira con el layout
    p2Cont := g.Add("Text",uiP(12,byb + 5,190,22) . " +0x200 +0x4000","ℹ Ningún evento seleccionado")
    ptsEd.p2Cont := p2Cont
    ptsEd.bOkAcento := bOk
    ptsEd.hAcento := bOk.Hwnd
    OnMessage(0x002B, _PtsDrawItemAcento)            ; WM_DRAWITEM; registrar de nuevo la misma función no la duplica
    bSav.OnEvent("Click", _PtsGuardarCambios)
    bPin.OnEvent("Click",_PtsTopToggle)
    _PtsInd()["st"] := st
    for par in [
        [bModoN, "Edita las zonas del modo Normal (1)"],
        [bModoE, "Edita las zonas del modo Enfoque (2)"],
        [lv, "Catálogo de zonas y rangos: selecciona una para editarla"],
        [bDib, "Dibuja con el lápiz la zona seleccionada"],
        [bCad, "Dibuja en cadena: empieza en la fila seleccionada y sigue con las siguientes"],
        [bAjz, "Mueve y estira la zona seleccionada en vivo arrastrando sus esquinas"],
        [bVer, "Muestra sobre la pantalla las zonas definidas"],
        [bDef, "Devuelve la zona seleccionada a su valor por defecto"],
        [dx, "Desplazamiento horizontal (ΔX) a sumar a la zona"],
        [dy, "Desplazamiento vertical (ΔY) a sumar a la zona"],
        [bDelta, "Mueve la zona seleccionada según ΔX y ΔY"],
        [bGuardN, "Guarda el layout actual de CSP como modo 1 (Normal)"],
        [bGuardE, "Guarda el layout actual de CSP como modo 2 (Enfoque)"],
        [bTog1, "Alterna entre el layout Normal y el de Enfoque"],
        [ddGrupo, "Filtra la lista de eventos por grupo"],
        [lvEv, "Eventos y avisos: selecciona uno para configurarlo"],
        [ddF, "Formato del aviso: Moderno, Bruto o Desactivado"],
        [ddZ, "Zona del HUD donde aparece este aviso: Alta, Media o Baja"],
        [ddOp, "Opacidad del aviso: 100 %, 70 % o 40 %"],
        [bEvProbar, "Lanza un destello de prueba del aviso"],
        [bEvAnclar, "Previsualiza el aviso anclado en pantalla"],
        [bEvReub, "Dibuja una posición exclusiva para este evento"],
        [eTxtEv, "Texto personalizado que mostrará este evento"],
        [bTxtEv, "Guarda el texto personalizado del evento"],
        [bTxtReset, "Restaura el texto por defecto del evento"],
        [eDurEv, "Duración de este evento, en milisegundos"],
        [bDurEv, "Aplica la duración escrita a este evento"],
        [eDurA, "Duración de los avisos de prioridad Alta (ms)"],
        [eDurM, "Duración de los avisos de prioridad Media (ms)"],
        [eDurB, "Duración de los avisos de prioridad Baja (ms)"],
        [bDurGuardar, "Guarda las duraciones por prioridad"],
        [ddl, "Perfil de equipo cuya configuración estás editando"],
        [eEsc, "Escala de los botones, en porcentaje"],
        [eEscAv, "Escala de los avisos, en porcentaje"],
        [bMover, "Desbloquea los botones para moverlos, o los fija"],
        [bReub, "Devuelve los botones a su posición original"],
        [bLN, "Guarda la distribución actual como layout Normal"],
        [bLE, "Guarda la distribución actual como layout Enfoque"],
        [bLA, "Aplica el layout guardado del modo actual"],
        [bBak, "Crea una copia de seguridad de posiciones_gui.ini"],
        [bRes, "Restaura la última copia de seguridad del INI"],
        [lvTema, "Paletas de temas: selecciona una para previsualizarla"],
        [bTemaAp, "Aplica la paleta de temas seleccionada"]
    ]
        AyudaRegistrar(par[1], par[2])
    AyudaRegistrar(bOk, "Guarda los cambios y cierra el calibrador")
    AyudaRegistrar(bRei, "Reinicia el script para aplicar la configuración")
    AyudaRegistrar(bPin, "Alterna ventana Siempre al frente o Modo normal")
    ptsEd.ly.bTop := bPin
    ptsEd.g := g
    ptsEd.lv := lv
    ptsEd.bVer := bVer
    ptsEd.dibujando := false      ; true mientras se dibuja/ajusta: overlays de zonas ocultos
    ptsEd.ovlEstaba := false      ; "Ver zonas" estaba activo antes de atenuar
    ptsEd.dx := dx
    ptsEd.dy := dy
    ptsEd.eEsc := eEsc
    ptsEd.eEscAv := eEscAv
    ptsEd.st := st
    ptsEd.lvEv := lvEv
    ptsEd.ddGrupo := ddGrupo
    ptsEd.mapFilas := []
    ptsEd.ddF := ddF
    ptsEd.ddZ := ddZ
    ptsEd.ddOp := ddOp
    ptsEd.eTxtEv := eTxtEv
    ptsEd.eDurEv := eDurEv
    ptsEd.lblDurEfec := lblDurEfec
    ptsEd.stEv := stEv
    ptsEd.lblBak := lblBak
    ptsEd.bRes := bRes
    ptsEd.bEvAnclar := bEvAnclar
    ptsEd.bEvReub := bEvReub
    ptsEd.bEvReub.Enabled := false
    ptsEd.evAnclado := false
    ptsEd.guiAnclado := 0
    ptsEd.sel := 0
    ptsEd.evSel := 0
    ptsEd.edAtajo := edAtajo
    ptsEd.edRemap := edRemap
    ptsEd.cbPill := cbPill
    ptsEd.cbHover := cbHover
    ptsEd.cbCruzar := cbCruzar
    ptsEd.cbAuto := cbAuto
    ptsEd.cbQuick := cbQuick
    ptsEd.cbToggle := cbToggle
    ptsEd.cbSlider := cbSlider
    ptsEd.ddSndAmb := ddSndAmb, ptsEd.cbSndAct := cbSndAct, ptsEd.ddSndTipo := ddSndTipo
    ptsEd.slSndVol := slSndVol, ptsEd.lblSndVol := lblSndVol, ptsEd.lblSndEfec := lblSndEfec
    ptsEd.bSndHeredar := bSndHeredar, ptsEd.sndBusy := false
    ddSndAmb.OnEvent("Change", _PtsSndRefrescar)
    cbSndAct.OnEvent("Click", _PtsSndCambio.Bind(false))
    ddSndTipo.OnEvent("Change", _PtsSndCambio.Bind(true))
    slSndVol.OnEvent("Change", _PtsSndVolChange)
    bSndProbar.OnEvent("Click", _PtsSndProbar)
    bSndHeredar.OnEvent("Click", _PtsSndHeredar)
    _PtsSndRefrescar()
    st.Value := "Perfil activo: " PERFILES[PERFIL] ". Selecciona una zona."
    lv.OnEvent("ItemSelect",_PtsSel)
    lv.OnEvent("DoubleClick",(*) => _PtsDibujarSel(false))
    lv.OnEvent("ContextMenu",_PtsMenuZona)             ; clic derecho: pausar / reanudar / eliminar
    bDib.OnEvent("Click",(*) => _PtsDibujarSel(false))
    bCad.OnEvent("Click",(*) => _PtsDibujarSel(true))
    bVer.OnEvent("Click",_PtsToggleVerZonas)
    bDef.OnEvent("Click",_PtsDefecto)
    bAjz.OnEvent("Click",(*) => _PtsAjustarZona())
    bDelta.OnEvent("Click",_PtsDesplazar)
    ddGrupo.OnEvent("Change",(*) => _PtsEvFilas())
    lvEv.OnEvent("ItemSelect",_PtsEvSel)
    lvEv.OnEvent("DoubleClick",_PtsEvDobleClickCol)
    lvEv.OnEvent("ContextMenu",_PtsEvContextMenu)
    gMain.OnEvent("ContextMenu", _PtsFondoContextMenu)
    tb.OnEvent("ContextMenu", _PtsFondoContextMenu)
    bRemapGuardar.OnEvent("Click",_PtsEvRemapGuardar)
    bRemapReset.OnEvent("Click",_PtsEvRemapReset)
    cbPill.OnEvent("Click",_PtsEvPartToggle.Bind("pildora"))
    cbHover.OnEvent("Click",_PtsEvPartToggle.Bind("hover"))
    cbCruzar.OnEvent("Click",_PtsEvPartToggle.Bind("cruzar"))
    cbAuto.OnEvent("Click",_PtsEvPartToggle.Bind("auto"))
    cbQuick.OnEvent("Click",_PtsEvPartToggle.Bind("quick"))
    cbToggle.OnEvent("Click",_PtsEvPartToggle.Bind("toggle"))
    cbSlider.OnEvent("Click",_PtsEvPartToggle.Bind("slider"))
    ddF.OnEvent("Change",_PtsEvCambio)
    ddZ.OnEvent("Change",_PtsEvCambio)
    ddOp.OnEvent("Change",_PtsEvCambio)
    bEvProbar.OnEvent("Click",_PtsEvProbar)
    bEvAnclar.OnEvent("Click",_PtsEvToggleAnclar)
    bEvReub.OnEvent("Click",_PtsEvReubicarZona)
    ddl.OnEvent("Change",_PtsCambiarPerfil)
    bMover.OnEvent("Click",(ctrl,*) => _PtsMoverBotones(ctrl))
    bReub.OnEvent("Click",_PtsReubicar)
    bLN.OnEvent("Click",(*) => _CapturarLayout("Normal"))
    bLE.OnEvent("Click",(*) => _CapturarLayout("Enfoque"))
    bLA.OnEvent("Click",(*) => _AplicarLayoutPaneles(enfoque.activo ? "Enfoque" : "Normal"))
    bRei.OnEvent("Click",_PtsReiniciar)
    bOk.OnEvent("Click",_PtsCerrar)
    g.OnEvent("Close",_PtsCerrar)
    g.OnEvent("Escape",_PtsEscCerrar)
    g.Show("Hide AutoSize")
    ov := Map(bModoN.Hwnd,"mitad", bModoE.Hwnd,"mitad", ptsModo.barN.Hwnd,"mitad", ptsModo.barE.Hwnd,"mitad"
        , lv.Hwnd,"lv", lvEv.Hwnd,"lv", lvTema.Hwnd,"lv", bDib.Hwnd,"fila4", bCad.Hwnd,"fila4", bVer.Hwnd,"fila4", bDef.Hwnd,"fila4"
        , bSav.Hwnd,"der", bOk.Hwnd,"der", bRei.Hwnd,"der", bPin.Hwnd,"der")
    _PtsLayInit(g,lyM,tb,lv,lvEv,ov,{TW:TW,cw:cw,x0:x0,xR:xR,wL:wL,wR:wR})
    g.OnEvent("Size",_PtsLayRedim)
    _PtsAjustarVentana(g)                   ; cabe en el área útil del monitor de nacimiento y queda un poco sobre el centro
    _PtsFijarMinimo(g)                      ; mínimo = tamaño real de diseño, no el de nacimiento
    _AccRelayout()
    g.Show()                                ; muestra directamente en la posición y monitor final sin teletransportación
    OnMessage(0x0232,_PtsFinMovimiento)     ; WM_EXITSIZEMOVE: re-encaja al soltar tras arrastrar
    OnMessage(0x007E,_PtsDisplayChange)     ; WM_DISPLAYCHANGE: cambio de topología
    OnMessage(0x020A,_AccOnWheel)           ; WM_MOUSEWHEEL: scroll de paneles en pestaña 1
    ; SetTimer(_PtsAutoMin,250) ; Desactivado: auto-minimización eliminada
    SetTimer(_PtsModoVigilar,500)
    _PtsRefrescar()
    _PtsEvFilas()
    _PtsBakRefrescar()
    _PtsTemaMarcar()
    _NvPanRefrescarTabla()
    lv.Modify(1,"Select Focus")
    _PtsSel(lv,1,true)
    lvEv.Modify(1,"Select Focus")
    _PtsEvSel(lvEv,1,true)
}

; ===== [RESIZE + MODO VENTANA] panel redimensionable y "📌 Al frente / 🪟 Normal" =====
_PtsLayCuenta(g) {                 ; nº de controles creados hasta ahora (marca el inicio/fin de cada pestaña)
    n := 0
    for hwnd, c in g
        n += 1
    return n
}
_PtsLayInit(g,lyM,tb,lv,lvEv,ov,u) {
    global ptsEd
    ly := ptsEd.ly
    tb.GetPos(&tx,&ty,&tw,&th)
    k := tw / u.TW                 ; px reales por unidad de diseño (escala UI × DPI)
    lvEv.GetPos(&ex,&ey,&ew,&eh)
    lv.GetPos(&lx,&lyy,&lw,&lh)
    bot1 := ey + eh                ; borde inferior del ListView de eventos (pestaña 1)
    bot2 := lyy + lh               ; borde inferior del ListView de zonas (pestaña 2)
    bot4 := 0
    if (HasProp(ptsEd, "temaLv") && IsObject(ptsEd.temaLv)) {
        ptsEd.temaLv.GetPos(, &t4y, , &t4h)
        bot4 := t4y + t4h          ; borde inferior de temas (pestaña 4)
    }
    items := []
    idx := 0
    for hwnd, c in g {
        idx += 1
        c.GetPos(&x,&y,&w,&h)
        ux := x / k
        uw := w / k
        typ := c.Type
        modo := ov.Has(hwnd) ? ov[hwnd] : ""
        t := (idx <= lyM[1]) ? 0 : (idx <= lyM[2]) ? 1 : (idx <= lyM[3]) ? 2 : (idx <= lyM[4]) ? 3 : (idx <= lyM[5]) ? 4 : 5
        r := {c: c, x: x, y: y, w: w, h: h, ax: 0, aw: 0, ay: 0, ah: 0, ps: 0, pb: 0}
        if (t = 0) {                                   ; el Tab3: crece en ancho y alto
            r.aw := 1
            r.ah := 1
        } else if (t = 1) {                            ; pestaña 1: eventos y particularidades
            if (modo = "lv") {
                r.aw := 1
                ; sin r.ah: lvEv conserva su alto; el acordeón es el único dueño del vertical
                r.aw := 0                              ; P2b: lvEv congelado en p1wL (220 px); la columna derecha absorbe el ensanchado
            } else if ((typ = "GroupBox" || typ = "Text") && uw >= u.cw - 1) {
                r.aw := 1
            } else if (typ = "Text" && y < ey - 1 && ux >= u.x0 + u.cw - 300) {
                r.ax := 1                              ; etiqueta "Grupo:" pegada a su desplegable
            } else if (typ = "Text" && ux >= u.xR - 4 && y < ey - 1) {
                r.aw := 1                              ; P2b: lbT2, p1tTitulo, p1tSub y p1Anchor (el viewport del acordeón sigue a p1Anchor)
            } else if (typ = "DropDownList" && ux >= u.xR - 4 && y < ey - 1) {
                r.ax := 1                              ; P2b: p1ddEstado pegado al borde derecho
            }
            ; (eliminado) r.ay := 1 bajo la lista: lo reposiciona _AccRelayout
        } else if (t = 2) {                            ; pestaña 2: zonas y rangos
            if (modo = "lv") {
                r.aw := 1
                r.ah := 1
            } else if (modo = "mitad") {
                r.ps := u.cw * k
                r.pb := u.x0 * k
            } else if (modo = "fila4") {
                r.ps := (u.cw - 24) * k
                r.pb := (u.x0 + 12) * k
            } else if (modo = "der") {
                r.ax := 1
            } else if ((typ = "GroupBox" || typ = "Text") && uw >= u.cw - 1) {
                r.aw := 1
            }
            if (modo != "lv" && y >= bot2 - 1)
                r.ay := 1
        } else if (t = 3) {                            ; pestaña 3: sistema y perfiles
            if (ux >= u.xR - 1) {
                r.ax := 0.5
                if (uw >= u.wR - 1)
                    r.aw := 0.5
            } else if (uw >= u.wL - 1) {
                r.aw := 0.5
            }
        } else if (t = 4) {                            ; pestaña 4: paleta de temas
            if (modo = "lv") {
                r.aw := 1
                r.ah := 1
            } else if ((typ = "GroupBox" || typ = "Text") && uw >= u.cw - 1)
                r.aw := 1
            else if (typ = "Text" && uw >= u.cw - 260)
                r.aw := 1
            else if (typ = "Button" && ux >= u.x0 + u.cw - 12 - 240)
                r.ax := 1
            if (modo != "lv" && bot4 && y >= bot4 - 1)
                r.ay := 1                              ; descripcion y boton bajan con la ventana
        } else {                                       ; barra inferior: pegada al borde de abajo
            r.ay := 1
            if (typ = "Text" && uw >= u.TW - 1)
                r.aw := 1
            else if (modo = "der")
                r.ax := 1
        }
        if (r.ax || r.aw || r.ay || r.ah || r.ps)
            items.Push(r)
    }
    ly.items := items
    ly.cols := []
    colList := [lv, lvEv]
    if (HasProp(ptsEd, "lvNv") && IsObject(ptsEd.lvNv))
        colList.Push(ptsEd.lvNv)
    if (HasProp(ptsEd, "temaLv") && IsObject(ptsEd.temaLv))
        colList.Push(ptsEd.temaLv)
    for l in colList
        ly.cols.Push({l: l, w0: SendMessage(0x101D,0,0,l)})   ; LVM_GETCOLUMNWIDTH de la col. 1
    need := 0
    for r in items
        need := Max(need, r.y + r.h)                   ; borde inferior real de la barra de botones
    ly.cw0 := tx * 2 + tw                              ; ancho de diseño (margen 12 u a cada lado)
    ly.ch0 := need + Round(12 * k)                     ; alto de diseño = pie de botones + margen
    ly.dyMin := Max(0, Min(lh,eh) - Round(80 * k))     ; los ListView pueden encogerse hasta ~80 u
    ly.dx := 0
    ly.dy := 0
    ly.listo := true
}
_PtsLayRedim(gg, minMax, w, h) {
    global ptsEd
    if (minMax = -1 || !IsObject(ptsEd.g) || !HasProp(ptsEd,"ly"))
        return
    ly := ptsEd.ly
    if (!ly.listo)
        return
    dx := Max(0, w - ly.cw0)                           ; nunca por debajo del tamaño AutoSize
    dy := Max(-ly.dyMin, h - ly.ch0)
    if (dx = ly.dx && dy = ly.dy)
        return
    ly.dx := dx
    ly.dy := dy
    hw := ptsEd.g.Hwnd
    DllCall("SendMessage","Ptr",hw,"UInt",0x000B,"Ptr",0,"Ptr",0)      ; WM_SETREDRAW off
    for r in ly.items {
        if (r.ps) {
            s := (r.ps + dx) / r.ps
            r.c.Move(Round(r.pb + (r.x - r.pb) * s),Round(r.y + r.ay * dy),Round(r.w * s))
        } else {
            r.c.Move(Round(r.x + r.ax * dx),Round(r.y + r.ay * dy),Round(r.w + r.aw * dx),Round(r.h + r.ah * dy))
        }
    }
    for ci in ly.cols
        try ci.l.ModifyCol(1,ci.w0 + dx)
    if (IsSet(ACC) && IsObject(ACC))
        _AccRelayout()                                  ; Size es el único dueño: reubica viewport y scrollbar con el Tab ya movido
    DllCall("SendMessage","Ptr",hw,"UInt",0x000B,"Ptr",1,"Ptr",0)      ; WM_SETREDRAW on
    DllCall("RedrawWindow","Ptr",hw,"Ptr",0,"Ptr",0,"UInt",0x185)
}
_PtsAjustarVentana(g) {
    ; Encaja la ventana en el área útil (sin barra de tareas) del monitor de nacimiento (tableta) y la sube un poco del centro.
    global ptsEd
    mon := (HasProp(ptsEd,"nac") && IsObject(ptsEd.nac)) ? ptsEd.nac : _PtsMonNacim()
    wl := mon.wl
    wt := mon.wt
    wr := mon.wr
    wb := mon.wb
    g.GetPos(&x,&y,&w,&h)
    nw := Min(w, wr - wl - 16)
    nh := Min(h, wb - wt - 12)
    nx := wl + (wr - wl - nw) // 2
    ny := wt + Round((wb - wt - nh) * 0.30)            ; 0.50 = centro exacto; 0.30 = algo más arriba
    g.Move(nx,ny,nw,nh)
    g.GetClientPos(&cx,&cy,&cw,&ch)
    _PtsLayRedim(g,0,cw,ch)                            ; aplica el layout aunque no haya cambiado el tamaño
}

_PtsFirmaMonitores() {
    ; Mismo formato que [Perfil] ultimaFirma: "l,t,r,b;l,t,r,b"
    s := ""
    loop MonitorGetCount() {
        MonitorGet(A_Index,&ml,&mt,&mr,&mb)
        s .= (s ? ";" : "") ml "," mt "," mr "," mb
    }
    return s
}
_PtsMonInfo(i) {
    MonitorGet(i,&ml,&mt,&mr,&mb)
    MonitorGetWorkArea(i,&wl,&wt,&wr,&wb)
    return {idx: i, x: ml, y: mt, w: mr - ml, h: mb - mt, wl: wl, wt: wt, wr: wr, wb: wb}
}
_PtsHwndCSP() {
    global colorV
    try {
        if (IsSet(colorV) && IsObject(colorV) && HasProp(colorV,"cspHwnd") && colorV.cspHwnd && WinExist("ahk_id " colorV.cspHwnd))
            return colorV.cspHwnd
    }
    return WinExist("ahk_exe CLIPStudioPaint.exe")
}
_PtsMonNacim() {
    ; Monitor de nacimiento del Calibrador. Orden: override > firma guardada vigente > ventana de CSP (guarda firma) > primario.
    ; Claves en posiciones_gui.ini [Calibrador]: nacMonitor (override, índice 1..n), nacRect="x,y,w,h", nacFirma (topología).
    ini := _PosGuiIniPath()
    firma := _PtsFirmaMonitores()
    n := MonitorGetCount()
    try {                                                              ; 1) override manual
        v := Trim(IniRead(ini,"Calibrador","nacMonitor",""))
        if (IsInteger(v) && Integer(v) >= 1 && Integer(v) <= n)
            return _PtsMonInfo(Integer(v))
    }
    try {                                                              ; 2) firma guardada, si la topología no cambió
        if (IniRead(ini,"Calibrador","nacFirma","") = firma) {
            q := StrSplit(Trim(IniRead(ini,"Calibrador","nacRect","")),",")
            if (q.Length = 4) {
                loop n {
                    MonitorGet(A_Index,&ml,&mt,&mr,&mb)
                    if (ml = Integer(q[1]) && mt = Integer(q[2]) && mr - ml = Integer(q[3]) && mb - mt = Integer(q[4]))
                        return _PtsMonInfo(A_Index)
                }
            }
        }
    }
    try {                                                              ; 3) resolver desde CSP y guardar firma
        hw := _PtsHwndCSP()
        if (hw && WinGetMinMax("ahk_id " hw) != -1) {
            WinGetPos(&wx,&wy,&ww,&wh,"ahk_id " hw)
            cx := wx + ww // 2
            cy := wy + wh // 2
            loop n {
                MonitorGet(A_Index,&ml,&mt,&mr,&mb)
                if (cx >= ml && cx < mr && cy >= mt && cy < mb) {
                    info := _PtsMonInfo(A_Index)
                    IniWrite(info.x "," info.y "," info.w "," info.h,ini,"Calibrador","nacRect")
                    IniWrite(firma,ini,"Calibrador","nacFirma")
                    return info
                }
            }
        }
    }
    return _PtsMonInfo(MonitorGetPrimary())                            ; 4) respaldo, no se guarda
}
_PtsFijarMinimo(g) {
    ; +MinSize = mínimo real de diseño (cw0 × ch0-dyMin, área cliente). Se mide sin depender de unidades de +MinSize WxH:
    ; se quita el mínimo, se lleva la ventana a ese tamaño, se fija "+MinSize" (tamaño actual) y se restaura el tamaño.
    global ptsEd
    ly := ptsEd.ly
    if (!ly.listo || WinGetMinMax("ahk_id " g.Hwnd) != 0)
        return
    g.Opt("-MinSize")
    g.GetPos(&x,&y,&w,&h)
    g.GetClientPos(,,&cw,&ch)
    g.Move(,,ly.cw0 + (w - cw),ly.ch0 - ly.dyMin + (h - ch))
    g.Opt("+MinSize")
    g.Move(,,w,h)
}
_PtsFinMovimiento(wParam, lParam, msg, hwnd) {
    global ptsEd
    try {
        if (IsObject(ptsEd.g) && hwnd = ptsEd.g.Hwnd)
            SetTimer(_PtsReencajar,-80)
    }
}
_PtsDisplayChange(wParam, lParam, msg, hwnd) {
    global ptsEd
    try {
        if (IsObject(ptsEd.g) && hwnd = ptsEd.g.Hwnd)
            SetTimer(_PtsReencajar,-600)
    }
}
_PtsReencajar(*) {
    ; Clamp de posición y tamaño al área útil del monitor donde quedó la ventana. No recentra si ya cabe.
    global ptsEd
    try {
        if (!IsObject(ptsEd.g) || !HasProp(ptsEd,"ly") || !ptsEd.ly.listo)
            return
        g := ptsEd.g
        if (WinGetMinMax("ahk_id " g.Hwnd) != 0)
            return
        hMon := DllCall("MonitorFromWindow","Ptr",g.Hwnd,"UInt",2,"Ptr")
        mi := Buffer(40,0)
        NumPut("UInt",40,mi)
        if (!DllCall("GetMonitorInfoW","Ptr",hMon,"Ptr",mi))
            return
        wl := NumGet(mi,20,"Int")
        wt := NumGet(mi,24,"Int")
        wr := NumGet(mi,28,"Int")
        wb := NumGet(mi,32,"Int")
        g.GetPos(&x,&y,&w,&h)
        nw := Min(w, wr - wl - 16)
        nh := Min(h, wb - wt - 12)
        loop 2 {
            nx := Max(wl, Min(x, wr - nw))
            ny := Max(wt, Min(y, wb - nh))
            if (nx = x && ny = y && nw = w && nh = h)
                break
            g.Move(nx,ny,nw,nh)
            g.GetPos(&x,&y,&w,&h)
            nw := w
            nh := h
        }
    }
}
_PtsTopToggle(*) {
    global ptsEd
    ly := ptsEd.ly
    ly.top := !ly.top
    try ptsEd.g.Opt(ly.top ? "+AlwaysOnTop" : "-AlwaysOnTop")
    try ly.bTop.Text := ly.top ? "📌 Al frente" : "🪟 Normal"
    try IniWrite(ly.top ? 1 : 0,_PosGuiIniPath(),"Calibrador","alwaysOnTop")
    ly.foco := true
    try ptsEd.st.Value := ly.top ? "📌 Siempre al frente: la ventana flota sobre CSP." : "🪟 Modo normal: se minimiza sola al volver a CSP."
}
_PtsAutoMin() {                    ; modo Normal: al tomar el foco CSP, la ventana se minimiza
    global ptsEd
    if (!IsObject(ptsEd.g) || !HasProp(ptsEd,"ly")) {
        SetTimer(_PtsAutoMin,0)
        return
    }
    ly := ptsEd.ly
    hw := 0
    try hw := ptsEd.g.Hwnd
    if (!hw || !WinExist("ahk_id " hw)) {
        SetTimer(_PtsAutoMin,0)
        return
    }
    if (ly.top || ptsEd.dibujando || ptsEd.capturando)
        return
    if (!DllCall("IsWindowVisible","Ptr",hw))
        return
    if (WinGetMinMax("ahk_id " hw) = -1) {
        ly.foco := false
        return
    }
    if (WinActive("ahk_id " hw)) {
        ly.foco := true                                ; solo se auto-minimiza si el usuario ya la usó
        return
    }
}
; ===== P2: escala de la ventana, HUB y paleta de temas integrada =====
_PtsUIEscala() {
    ; Factor de escala de la ventana del calibrador: 1.0 = monitor FHD lógico (1080 px de alto).
    ; Tableta 2.5K sube la ventana; monitor de 24" FHD la deja en 1.0. Se limita para que
    ; la ventana (~700 unidades de alto) nunca pase del 92% del monitor de nacimiento.
    ; Override manual: [Calibrador] escalaUI=100..250 (%) en posiciones_gui.ini
    global ptsEd
    f := 1.0
    try {
        mon := (HasProp(ptsEd,"nac") && IsObject(ptsEd.nac)) ? ptsEd.nac : ObtenerMonitorCSP()
        dpi := Max(96, A_ScreenDPI)
        alto := mon.h / (dpi / 96)
        f := Min(alto / 1080, alto * 0.92 / 700)
    }
    try {
        v := Trim(IniRead(_PosGuiIniPath(),"Calibrador","escalaUI",""))
        if (IsInteger(v) && Integer(v) >= 60 && Integer(v) <= 250)
            f := Integer(v) / 100
    }
    return Max(0.8, Min(1.8, f))
}
_PtsHubToggle(clave,*) {
    _MenuToggleEmbebido(clave)
}
_PtsClicAutoToggle(chk, *) {
    global panelBlk
    panelBlk.clicAuto := chk.Value ? true : false
    _EscribirEstadoBloque("clicAuto", panelBlk.clicAuto ? 1 : 0)
}
_PtsTemaMarcar(seleccionarFila := true) {
    ; Detecta qué paleta de _TemaPerfiles() coincide con theme.ini y marca su fila.
    if (!IsObject(ptsEd.g) || !HasProp(ptsEd,"temaLv") || !IsObject(ptsEd.temaLv))
        return 0
    perfiles := _TemaPerfiles()
    act := 0
    nomActivo := IniRead(A_ScriptDir "\theme.ini", "meta", "nombre", "")
    if (nomActivo != "") {
        for i, p in perfiles {
            if (p.nombre = nomActivo) {
                act := i
                break
            }
        }
    }
    if (!act) {
        for i, p in perfiles {
            ok := true
            for clave, hex in p.tokens {
                if (_Tema("color",clave,"") != StrUpper(hex)) {
                    ok := false
                    break
                }
            }
            if (ok) {
                act := i
                break
            }
        }
    }
    if (act > 0) {
        if (seleccionarFila) {
            try ptsEd.temaLv.Modify(act,"Select Vis Focus")
            try ptsEd.temaSel := act
            try ptsEd.temaDesc.Value := perfiles[act].desc
        }
    }
    try ptsEd.temaLbl.Value := "Tema activo: " . ((act > 0) ? perfiles[act].nombre : (nomActivo != "" ? nomActivo : _Tema("meta","nombre","Personalizado")))
    return act
}
_PtsTemaSel(lv, fila, selected := true, *) {
    global ptsEd
    if (!selected)
        return
    if (fila < 1 || fila > ptsEd.temas.Length)
        return
    ptsEd.temaSel := fila
    try ptsEd.temaDesc.Value := ptsEd.temas[fila].desc
}
_PtsTemaFocus(lv, fila, *) {
    global ptsEd
    if (fila >= 1 && fila <= ptsEd.temas.Length) {
        ptsEd.temaSel := fila
        try ptsEd.temaDesc.Value := ptsEd.temas[fila].desc
    }
}
_PtsTemaDobleClick(lv, fila, *) {
    global ptsEd
    if (fila < 1 || fila > ptsEd.temas.Length)
        fila := (HasProp(ptsEd,"temaLv") && IsObject(ptsEd.temaLv)) ? ptsEd.temaLv.GetNext() : 0
    if (fila < 1 || fila > ptsEd.temas.Length)
        fila := ptsEd.temaSel
    if (fila < 1 || fila > ptsEd.temas.Length)
        fila := 1
    ptsEd.temaSel := fila
    try ptsEd.temaDesc.Value := ptsEd.temas[fila].desc
    _PtsTemaAplicarSel()
}
_PtsTemaProbarSel(*) {
    global ptsEd
    fila := (HasProp(ptsEd,"temaLv") && IsObject(ptsEd.temaLv)) ? ptsEd.temaLv.GetNext() : 0
    if (fila < 1 || fila > ptsEd.temas.Length)
        fila := (HasProp(ptsEd,"temaLv") && IsObject(ptsEd.temaLv)) ? ptsEd.temaLv.GetNext(0, "Focused") : 0
    if (fila < 1 || fila > ptsEd.temas.Length)
        fila := ptsEd.temaSel
    if (fila < 1 || fila > ptsEd.temas.Length)
        fila := 1
    ptsEd.temaSel := fila
    try ptsEd.temaDesc.Value := ptsEd.temas[fila].desc
    p := ptsEd.temas[fila]
    _PtsTemaAplicar(p, false)
    colAcento := (p.swatches.Length >= 1) ? p.swatches[1] : "00E5FF"
    if IsObject(ptsEd.st)
        ptsEd.st.Value := "🔔 Probando paleta en vivo: " p.nombre
    MostrarAvisoUI("moderno", "PALETA: " p.nombre, "PRUEBA EN VIVO", 2, colAcento, 1800)
}
_PtsTemaAplicarSel(*) {
    global ptsEd
    fila := (HasProp(ptsEd,"temaLv") && IsObject(ptsEd.temaLv)) ? ptsEd.temaLv.GetNext() : 0
    if (fila < 1 || fila > ptsEd.temas.Length)
        fila := (HasProp(ptsEd,"temaLv") && IsObject(ptsEd.temaLv)) ? ptsEd.temaLv.GetNext(0, "Focused") : 0
    if (fila < 1 || fila > ptsEd.temas.Length)
        fila := ptsEd.temaSel
    if (fila < 1 || fila > ptsEd.temas.Length)
        fila := 1
    ptsEd.temaSel := fila
    try ptsEd.temaDesc.Value := ptsEd.temas[fila].desc
    p := ptsEd.temas[fila]
    _PtsTemaAplicar(p, false)
    colAcento := (p.swatches.Length >= 1) ? p.swatches[1] : "00E5FF"
    MostrarAvisoUI("moderno", p.nombre, "PALETA APLICADA", 2, colAcento, 1500)
}
_PtsTemaAplicar(p, reselect := false, *) {
    ; Reutiliza el motor de theme_gfx (escribe theme.ini, vacía caché, repinta paneles).
    try _TemaSelAplicarPerfil(p)
    try IniWrite(p.nombre,A_ScriptDir "\theme.ini","meta","nombre")
    try _TemaRecargar()
    act := _PtsTemaMarcar(reselect)
    if IsObject(ptsEd.st)
        ptsEd.st.Value := "🎨 Paleta aplicada: " p.nombre
    try _SonarUI("calib")
}
; ===== Catálogo de zonas (todo en función con static: el código global de aquí no se auto-ejecuta) =====
_PtsZonaDefs() {
    static defs := 0
    if IsObject(defs)
        return defs
    defs := []
    Loop 3
        defs.Push({k:"IzqB" A_Index,n:"Panel izq · B" A_Index,t:"caja",p:3 + (A_Index - 1) * 4,zi:A_Index,lado:"izq",c:"2ECC71"})
    Loop 3
        defs.Push({k:"DerB" A_Index,n:"Panel der · B" A_Index,t:"caja",p:15 + (A_Index - 1) * 4,zi:A_Index,lado:"der",c:"3498DB"})
    defs.Push({k:"Historial",n:"Franja de historial",t:"hist",c:"E67E22"})
    defs.Push({k:"ToggleIzq",n:"Ocultar/mostrar panel izq (P1)",t:"punto",p:1,c:"E74C3C"})
    defs.Push({k:"ToggleDer",n:"Ocultar/mostrar panel der (P2)",t:"punto",p:2,c:"E74C3C"})
    defs.Push({k:"ZonaSegura",n:"Zona segura del cursor (P29)",t:"punto",p:29,c:"F1C40F"})
    defs.Push({k:"Estab",n:"Deslizador de estabilización",t:"estab",c:ESTAB_COLOR})
    defs.Push({k:"EstabFoco",n:"Deslizador de enfoque (Shift+E)",t:"estabF",c:"FF8800"})
    defs.Push({k:"HUD_Alta",n:"Aviso HUD · Zona 1 (Alta)",t:"hud",c:"FF4D6D"})
    defs.Push({k:"HUD_Media",n:"Aviso HUD · Zona 2 (Media)",t:"hud",c:"FFB703"})
    defs.Push({k:"HUD_Baja",n:"Aviso HUD · Zona 3 (Baja)",t:"hud",c:"9B59B6"})
    Loop 8
        defs.Push({k:"NvZona" A_Index,n:"Nueva ventana " A_Index,t:"rango",c:"9A7BFF"})
    return defs
}

; Zona libre: "" , ",,," o cualquier valor sin 4 números con ancho/alto > 0
_NvZonaVacia(v) {
    v := Trim(v)
    if (v = "")
        return true
    p := StrSplit(v, ",")
    if (p.Length < 4)
        return true
    for t in p {
        if !IsNumber(Trim(t))
            return true
    }
    return (Number(Trim(p[3])) <= 0 || Number(Trim(p[4])) <= 0)
}

_NvPanTexto() {
    ini := _PosGuiIniPath(), sec := _ZonaSec("Rangos")
    pes := IniRead(ini, sec, "NvPestana", "")
    ; En Enfoque, si no hay franja propia, heredar visualmente la de Modo Normal
    if (_NvZonaVacia(pes) && _ZonaSuf() != "")
        pes := IniRead(ini, _ZonaSec("Rangos", 1), "NvPestana", "")
    avisoPes := _NvZonaVacia(pes)
        ? "Franja de pestañas: sin calibrar (se usa el cálculo automático del marco)  |  "
        : "Franja de pestañas ✔  |  "
    cont := 0, prox := 0
    Loop 8 {
        if (!_NvZonaVacia(IniRead(ini, sec, "NvZona" A_Index, "")))
            cont++
        else if (!prox)
            prox := A_Index
    }
    sigue := prox ? "Próximo: Nueva ventana " prox : "8/8 ocupadas"
    return avisoPes "Lienzos: " cont "/8 · " sigue "  (👁 Ver zonas para previsualizar)"
}

_NvPanRefrescarTabla() {
    if (!IsObject(ptsEd) || !HasProp(ptsEd, "lvNv") || !IsObject(ptsEd.lvNv))
        return
    lv := ptsEd.lvNv
    lv.Opt("-Redraw")
    lv.Delete()
    ini := _PosGuiIniPath(), sec := _ZonaSec("Rangos")

    ; Fila 1 (OBLIGATORIA): Franja de pestañas (NvPestana) al inicio de todas
    pes := IniRead(ini, sec, "NvPestana", "")
    if (_NvZonaVacia(pes) && _ZonaSuf() != "")
        pes := IniRead(ini, _ZonaSec("Rangos", 1), "NvPestana", "")   ; Fallback a Modo Normal
    if (!_NvZonaVacia(pes)) {
        p := StrSplit(Trim(pes), ",")
        lv.Add("", "⭐ 1. Franja pestañas (NvPestana)", "Rango", p[1], p[2], p[3], p[4], "Calibrada ✔")
    } else {
        c := _NvCfg()
        lv.Add("", "⚠️ 1. Franja pestañas (NvPestana)", "Rango", c["tabX"], c["tabY"], "—", "—", "REQUERIDA ⚠️")
    }

    ; Filas 2 a 9: Zonas de destino (NvZona1 a NvZona8)
    Loop 8 {
        z := "NvZona" A_Index
        v := IniRead(ini, sec, z, "")
        if (!_NvZonaVacia(v)) {
            p := StrSplit(Trim(v), ",")
            if (p.Length = 4)
                lv.Add("", "Zona " A_Index " (" z ")", "Rango", p[1], p[2], p[3], p[4], "Configurada")
            else
                lv.Add("", "Zona " A_Index " (" z ")", "Rango", "", "", "", "", "Sin datos")
        } else {
            lv.Add("", "Zona " A_Index " (" z ")", "Rango", "—", "—", "—", "—", "Libre")
        }
    }
    lv.Opt("+Redraw")
}

_NvPanCargarOpac(row, ini, sec, clave) {
    if (!IsObject(ptsEd) || !HasProp(ptsEd, "eNvOH"))
        return
    esZona := (row >= 2)
    ptsEd.eNvOH.Enabled := esZona
    ptsEd.eNvOD.Enabled := esZona
    if (!esZona) {
        ptsEd.eNvOH.Value := ""
        ptsEd.eNvOD.Value := ""
        return
    }
    oh := 100, od := 25
    v := IniRead(ini, sec, clave "_Opac", "")
    if (v != "") {
        p := StrSplit(Trim(v), ",")
        if (p.Length >= 2 && IsInteger(Trim(p[1])) && IsInteger(Trim(p[2]))) {
            oh := Min(100, Max(0, Integer(Trim(p[1]))))
            od := Min(100, Max(0, Integer(Trim(p[2]))))
        }
    }
    ptsEd.eNvOH.Value := oh
    ptsEd.eNvOD.Value := od
}

_NvPanSel(lv, row, sel) {
    if (!sel || row < 1)
        return
    ini := _PosGuiIniPath(), sec := _ZonaSec("Rangos")
    clave := (row = 1) ? "NvPestana" : "NvZona" (row - 1)
    _NvPanCargarOpac(row, ini, sec, clave)
    v := IniRead(ini, sec, clave, "")
    if (v != "") {
        p := StrSplit(Trim(v), ",")
        if (p.Length >= 4) {
            ptsEd.eNvX.Value := p[1]
            ptsEd.eNvY.Value := p[2]
            ptsEd.eNvW.Value := p[3]
            ptsEd.eNvH.Value := p[4]
            return
        }
    }
    if (clave = "NvPestana") {
        c := _NvCfg()
        ptsEd.eNvX.Value := c["tabX"]
        ptsEd.eNvY.Value := c["tabY"]
        ptsEd.eNvW.Value := "20"
        ptsEd.eNvH.Value := "20"
    } else {
        ptsEd.eNvX.Value := ""
        ptsEd.eNvY.Value := ""
        ptsEd.eNvW.Value := ""
        ptsEd.eNvH.Value := ""
    }
}

_NvPanAplicarValores(*) {
    if (!IsObject(ptsEd) || !HasProp(ptsEd, "lvNv") || !IsObject(ptsEd.lvNv))
        return
    row := ptsEd.lvNv.GetNext()
    if (row < 1) {
        ToolTip("Selecciona primero una fila de la tabla", , , 19)
        SetTimer(() => ToolTip(, , , 19), -1500)
        return
    }
    x := Trim(ptsEd.eNvX.Value), y := Trim(ptsEd.eNvY.Value)
    w := Trim(ptsEd.eNvW.Value), h := Trim(ptsEd.eNvH.Value)
    ; Campos vacíos ("" o "—") = zona aún sin dibujar
    vacio := (v) => (v = "" || v = "—")
    sinRect := vacio(x) && vacio(y) && vacio(w) && vacio(h)
    ini := _PosGuiIniPath(), sec := _ZonaSec("Rangos")
    clave := (row = 1) ? "NvPestana" : "NvZona" (row - 1)

    ; 1) Rect: solo se valida si el usuario escribió algo; la pestaña (fila 1) siempre lo exige
    if (sinRect && row = 1) {
        ToolTip("Dibuja o escribe primero el rango (X, Y, Ancho, Alto)", , , 19)
        SetTimer(() => ToolTip(, , , 19), -1800)
        return
    }
    if (!sinRect && (!IsInteger(x) || !IsInteger(y) || !IsInteger(w) || !IsInteger(h) || Integer(w) <= 0 || Integer(h) <= 0)) {
        ToolTip("Introduce números válidos (X, Y enteros; Ancho y Alto > 0)", , , 19)
        SetTimer(() => ToolTip(, , , 19), -1800)
        return
    }

    ; 2) Opacidad (solo zonas, fila >= 2): enteros 0–100, se guarda SIEMPRE
    if (row >= 2) {
        oh := Trim(ptsEd.eNvOH.Value), od := Trim(ptsEd.eNvOD.Value)
        if (!IsInteger(oh) || !IsInteger(od) || Integer(oh) < 0 || Integer(oh) > 100 || Integer(od) < 0 || Integer(od) > 100) {
            ToolTip("Opacidad: usa enteros de 0 a 100", , , 19)
            SetTimer(() => ToolTip(, , , 19), -1800)
            return
        }
        IniWrite(Integer(oh) "," Integer(od), ini, sec, clave "_Opac")
    }

    ; 3) Zona sin coordenadas: solo opacidad → reaplicar, refrescar y salir
    if (sinRect) {
        try _NvReaplicarOpacidad()
        try _NvPanRefrescarTabla()
        try ptsEd.lvNv.Modify(row, "Select Focus")
        ToolTip("Opacidad guardada", , , 19)
        SetTimer(() => ToolTip(, , , 19), -1500)
        return
    }

    ; 4) Zona con coordenadas: guardar rect y reaplicar opacidad
    IniWrite(Format("{},{},{},{}", x, y, w, h), ini, sec, clave)
    if (row >= 2)
        try _NvReaplicarOpacidad()
    if (clave = "NvPestana") {
        mH := WinExist("ahk_class " _NvCfg()["claseMarco"])
        if mH {
            WinGetPos(&fx, &fy, &fw, &fh, "ahk_id " mH)
            IniWrite(Format("{},{},{},{}", fx, fy, fw, fh), ini, sec, "NvPestanaMarco")
        }
    }
    CargarPuntos()
    _PtsRefrescar()
    if (IsObject(ptsEd) && HasProp(ptsEd, "lvNv") && IsObject(ptsEd.lvNv))
        _NvPanRefrescarTabla()
    if (IsObject(ptsEd) && HasProp(ptsEd, "stNvZonas") && IsObject(ptsEd.stNvZonas))
        ptsEd.stNvZonas.Text := _NvPanTexto()
    if (ptsEd.ovl.Length > 0)
        MostrarZonasCalibracion(0)
    ToolTip("Valores guardados para " clave, , , 19)
    SetTimer(() => ToolTip(, , , 19), -1200)
}

_NvPanProximoLibre() {
    ini := _PosGuiIniPath(), sec := _ZonaSec("Rangos")
    Loop 8 {
        if (_NvZonaVacia(IniRead(ini, sec, "NvZona" A_Index, "")))
            return A_Index
    }
    return 0
}

_NvPanDibujar(st := 0) {
    ini := _PosGuiIniPath(), sec := _ZonaSec("Rangos")
    libre := _NvPanProximoLibre()
    reemplaza := !libre
    if (reemplaza) {
        libre := 1                 ; sin libres: reemplaza la ventana 1
        titulo := "Las 8 ventanas están ocupadas: dibuja para REEMPLAZAR «Nueva ventana 1»"
    } else
        titulo := "Dibuja el lienzo " libre " de 8  (Nueva ventana " libre ")"
    r := _PtsDibujarRango(titulo, "9A7BFF", false)
    if (!r)
        return
    IniWrite(Format("{},{},{},{}", r.x, r.y, r.w, r.h), ini, sec, "NvZona" libre)
    CargarPuntos()
    _PtsRefrescar()
    if (IsObject(ptsEd) && HasProp(ptsEd, "lvNv") && IsObject(ptsEd.lvNv))
        _NvPanRefrescarTabla()
    msg := "✔ Nueva ventana " libre (reemplaza ? " reemplazada" : " guardada") " (lienzo " libre "/8)"
    if (IsObject(ptsEd) && HasProp(ptsEd, "stNvZonas") && IsObject(ptsEd.stNvZonas))
        ptsEd.stNvZonas.Text := msg "  |  " _NvPanTexto()
    if (IsObject(st))
        st.Text := msg
    if (ptsEd.ovl.Length > 0)
        MostrarZonasCalibracion(0)
}

_NvPanBorrar(st := 0) {
    ini := _PosGuiIniPath(), sec := _ZonaSec("Rangos")
    ; 1) fila seleccionada en el ListView: 1 = NvPestana, 2-9 = NvZona1..8
    clave := ""
    fila := 0
    if (IsObject(ptsEd) && HasProp(ptsEd, "lvNv") && IsObject(ptsEd.lvNv))
        fila := ptsEd.lvNv.GetNext(0)
    if (fila = 1)
        clave := "NvPestana"
    else if (fila >= 2 && fila <= 9)
        clave := "NvZona" (fila - 1)
    ; 2) sin selección: última zona no vacía (buscando de 8 hacia 1)
    if (clave = "") {
        Loop 8 {
            idx := 9 - A_Index
            if (!_NvZonaVacia(IniRead(ini, sec, "NvZona" idx, ""))) {
                clave := "NvZona" idx
                break
            }
        }
    }
    if (clave = "")
        return
    try IniDelete(ini, sec, clave)
    if ZonaPausada(clave)
        ZonaPausar(clave, false)                          ; borrar la zona tambien limpia su pausa
    CargarPuntos()
    _PtsRefrescar()
    if (IsObject(ptsEd) && HasProp(ptsEd, "lvNv") && IsObject(ptsEd.lvNv))
        _NvPanRefrescarTabla()
    if (IsObject(ptsEd) && HasProp(ptsEd, "stNvZonas") && IsObject(ptsEd.stNvZonas))
        ptsEd.stNvZonas.Text := _NvPanTexto()
    if (ptsEd.ovl.Length > 0)
        MostrarZonasCalibracion(0)
}

_NvPanPestana(st := 0) {
    ini := _PosGuiIniPath(), sec := _ZonaSec("Rangos")
    r := _PtsDibujarRango("FRANJA DE PESTAÑAS de CSP (donde aparece la pestaña nueva, 2.ª con 1 sola abierta). NO es un lienzo", "FFD166", false)
    if (!r)
        return
    IniWrite(Format("{},{},{},{}", r.x, r.y, r.w, r.h), ini, sec, "NvPestana")
    h := WinExist("ahk_class " _NvCfg()["claseMarco"])
    if h {
        WinGetPos(&fx, &fy, &fw, &fh, "ahk_id " h)
        IniWrite(Format("{},{},{},{}", fx, fy, fw, fh), ini, sec, "NvPestanaMarco")
    }
    CargarPuntos()
    _PtsRefrescar()
    if (IsObject(ptsEd) && HasProp(ptsEd, "lvNv") && IsObject(ptsEd.lvNv))
        _NvPanRefrescarTabla()
    if (IsObject(ptsEd) && HasProp(ptsEd, "stNvZonas") && IsObject(ptsEd.stNvZonas))
        ptsEd.stNvZonas.Text := "✔ Franja de pestañas guardada (no cuenta como lienzo)  |  " _NvPanTexto()
    if (IsObject(st))
        st.Text := "Franja de pestañas guardada."
    if (ptsEd.ovl.Length > 0)
        MostrarZonasCalibracion(0)
}

_NvPanDobleClick(lv, row) {
    if (row < 1)
        return
    ini := _PosGuiIniPath(), sec := _ZonaSec("Rangos")
    if (row = 1) {
        _NvPanPestana(HasProp(ptsEd, "stNvZonas") ? ptsEd.stNvZonas : 0)
    } else if (row >= 2 && row <= 9) {
        numZ := row - 1
        r := _PtsDibujarRango("Dibuja la zona para la nueva ventana " numZ, "9A7BFF", false)
        if (!r)
            return
        IniWrite(Format("{},{},{},{}", r.x, r.y, r.w, r.h), ini, sec, "NvZona" numZ)
        CargarPuntos()
        _PtsRefrescar()
        _NvPanRefrescarTabla()
        if (IsObject(ptsEd) && HasProp(ptsEd, "stNvZonas") && IsObject(ptsEd.stNvZonas))
            ptsEd.stNvZonas.Text := _NvPanTexto()
        if (ptsEd.ovl.Length > 0)
            MostrarZonasCalibracion(0)
    }
}

_PtsDefPorClave(k) {
    for d in _PtsZonaDefs() {
        if (d.k = k)
            return d
    }
    return 0
}

; ---- P1: buscador y encabezado de la Pestaña 1 ----
_PtsBuscarCambio(ctrl, *) {
    global ptsEd
    ptsEd.filtroEv := Trim(ctrl.Value)
    SetTimer(_PtsEvFiltroAplicar, -150)              ; debounce one-shot, sin timers huérfanos
}

_PtsEvFiltroOk(nombre, grupo := "") {
    global ptsEd
    f := ptsEd.HasProp("filtroEv") ? ptsEd.filtroEv : ""
    return f = "" || InStr(nombre, f) || (grupo != "" && InStr(grupo, f))
}

_PtsEvFiltroAplicar() {
    global ptsEd
    if !(ptsEd.HasProp("lvEv") && IsObject(ptsEd.lvEv))
        return
    _PtsEvFilas()
    _PtsEvEncabezado(ptsEd.lvEv, 0, false)
    OutputDebug("[P1] filtro catalogo='" ptsEd.filtroEv "' filas=" ptsEd.lvEv.GetCount())
}

_PtsEvEncabezado(ctrl, item, selected) {
    global ptsEd
    if !ptsEd.HasProp("p1tTitulo")
        return
    fila := ctrl.GetNext(0, "F")
    if !fila
        fila := ctrl.GetNext(0)
    n := ctrl.GetCount("S")
    ptsEd.p1tTitulo.Text := fila ? RegExReplace(ctrl.GetText(fila, 1), "^⏸\s*") : "Seleccione un evento"
    ptsEd.p1tSub.Text := n > 1 ? n " eventos seleccionados" : "Configuración del evento seleccionado"
    _PtsEvSyncEstado(ctrl)
    if ptsEd.HasProp("p2Cont")
        ptsEd.p2Cont.Text := "ℹ " . (n = 0 ? "Ningún evento seleccionado" : (n = 1 ? "1 evento seleccionado" : n " eventos seleccionados"))
}

_PtsAccPanel(id) {
    global ACC
    for p in ACC.paneles
        if (p.id = id)
            return p
    return 0
}

_PtsGrupoSync(idGrp, miembros, *) {
    global ptsEd
    pG := _PtsAccPanel(idGrp)
    if !pG
        return
    if !ptsEd.HasProp("grpMem")
        ptsEd.grpMem := Map()
    if !pG.abierto {                                  ; recién colapsado: recordar y cerrar cuerpos
        mem := Map()
        for id in miembros {
            p := _PtsAccPanel(id)
            if !p
                continue
            mem[id] := p.abierto
            if p.abierto
                _AccToggle(id)
        }
        ptsEd.grpMem[idGrp] := mem
    } else {                                          ; reabierto: restaurar lo que estaba abierto
        mem := ptsEd.grpMem.Has(idGrp) ? ptsEd.grpMem[idGrp] : Map()
        for id in miembros {
            p := _PtsAccPanel(id)
            if !p
                continue
            want := mem.Has(id) ? mem[id] : p.def
            if (p.abierto != want)
                _AccToggle(id)
        }
    }
}

; ---- P2: botón de acento (owner-draw) ----
_PtsDrawItemAcento(wParam, lParam, msg, hwnd) {
    global ptsEd
    if !(IsObject(ptsEd) && ptsEd.HasProp("hAcento") && ptsEd.hAcento)
        return
    x64 := (A_PtrSize = 8)
    if (NumGet(lParam, x64 ? 24 : 20, "Ptr") != ptsEd.hAcento)
        return                                       ; no es nuestro botón: no se toca
    hDC := NumGet(lParam, x64 ? 32 : 24, "Ptr")
    rc := lParam + (x64 ? 40 : 28)
    est := NumGet(lParam, 16, "UInt")
    col := (est & 0x4) ? 0xE0A9B8 : ((est & 0x1) ? 0xD1355E : 0xFF4D7C)   ; COLORREF BGR: #B8A9E0, #5E35D1, #7C4DFF
    hBr := DllCall("gdi32\CreateSolidBrush", "UInt", col, "Ptr")
    DllCall("user32\FillRect", "Ptr", hDC, "Ptr", rc, "Ptr", hBr)
    DllCall("gdi32\DeleteObject", "Ptr", hBr)
    DllCall("gdi32\SetBkMode", "Ptr", hDC, "Int", 1)
    DllCall("gdi32\SetTextColor", "Ptr", hDC, "UInt", 0xFFFFFF)
    hFont := SendMessage(0x0031, 0, 0, ptsEd.hAcento)                    ; WM_GETFONT
    old := DllCall("gdi32\SelectObject", "Ptr", hDC, "Ptr", hFont, "Ptr")
    DllCall("user32\DrawTextW", "Ptr", hDC, "Str", ptsEd.bOkAcento.Text, "Int", -1, "Ptr", rc, "UInt", 0x25)   ; CENTER|VCENTER|SINGLELINE
    DllCall("gdi32\SelectObject", "Ptr", hDC, "Ptr", old)
    return 1
}

_PtsEventosDefs() {
    static evs := 0
    if IsObject(evs)
        return evs
    evs := [
        ["pluma", "Plumilla / Pincel Tinta (Q)", "Pinceles y Trazos"],
        ["aerografo", "Aerógrafo Principal (W)", "Pinceles y Trazos"],
        ["aerografo_alpha", "Aerógrafo Alpha Borrador (W doble → K)", "Pinceles y Trazos"],
        ["pincel_suave", "Pincel Suave (Alt + Q)", "Pinceles y Trazos"],
        ["pincel_duro", "Pincel Duro · Hard Brush (RButton + Q → F6)", "Pinceles y Trazos"],
        ["difu_mixer", "Difuminador Mezclador (RButton + W → Ñ)", "Pinceles y Trazos"],
        ["opc_presion", "Opacidad por Presión (Alt + W → <)", "Pinceles y Trazos"],
        ["borrador", "Borrador de Capas (E)", "Borradores y Mezcla"],
        ["borrador_suave", "Borrador Suave · Soft Eraser (E doble → L)", "Borradores y Mezcla"],
        ["borrador_lazo", "Borrador de Lazo (RButton + E → F12)", "Borradores y Mezcla"],
        ["smudge", "Edge Blur / Difuminar Borde (P)", "Borradores y Mezcla"],
        ["smear", "Smear Mezcla (1) (F → B)", "Borradores y Mezcla"],
        ["smear_soft", "Smear Soft Mezcla (2) (NumpadEnd)", "Borradores y Mezcla"],
        ["color_mix", "Mezcla de Color (X → D)", "Borradores y Mezcla"],
        ["color_primario", "Color Primario (Q doble)", "Color y Paleta"],
        ["color_secundario", "Color Secundario (Q doble alterno)", "Color y Paleta"],
        ["relleno", "Bote de Pintura / Relleno (RButton + 1 → V)", "Color y Paleta"],
        ["area_color", "Área con Color (S doble)", "Color y Paleta"],
        ["lazo", "Herramienta Lazo (S)", "Selección"],
        ["deseleccion", "Deselección (X físico → X)", "Selección"],
        ["reseleccion", "Reselección (X físico → F10)", "Selección"],
        ["inv_seleccion", "Invertir Selección (C)", "Selección"],
        ["shift_sostenido", "Regla Recta · Shift Sostenido (RButton + F)", "Lienzo y Reglas"],
        ["flip_horizontal", "Volteo Horizontal del Lienzo (Space + Alt+B → Alt+G)", "Lienzo y Reglas"],
        ["rotar_lienzo", "Rotación de Lienzo (Z doble → R)", "Lienzo y Reglas"],
        ["zoom_lienzo", "Zoom de Lienzo (Z)", "Lienzo y Reglas"],
        ["regla_ocultar", "Reglas: mostrar / ocultar (RButton + T)", "Lienzo y Reglas"],
        ["capa_visibilidad", "Visibilidad de Capa (Space + E)", "Capas y Archivo"],
        ["guardar", "Guardar Archivo .clip (Ctrl + S)", "Capas y Archivo"],
        ["deshacer", "Deshacer (Ctrl + Z)", "Capas y Archivo"],
        ["rehacer", "Rehacer (Ctrl + Y)", "Capas y Archivo"],
        ["copiar", "Copiar al Portapapeles (Ctrl + C)", "Capas y Archivo"],
        ["enfoque", "Modo Enfoque / Plegar Paneles (Tab / F3)", "Capas y Archivo"],
        ["history_lock", "Bloqueo de Franja Historial", "Capas y Archivo"],
        ["panel_ds", "Panel Deslizador de Colores (DS)", "Capas y Archivo"],
        ["panel_cc", "Panel Círculo de Colores (CC)", "Capas y Archivo"],
        ["gui_frente", "Botones al Frente / Solo en CSP", "Capas y Archivo"],
        ["estab_slider", "Deslizador de Estabilización", "Capas y Archivo"],
        ["layout", "Guardar / Aplicar Layout de Paneles", "Capas y Archivo"],
        ["reload", "Recargar Script", "Capas y Archivo"]
    ]
    ; --- eventos personalizados (persistidos en posiciones_gui.ini) ---
    try {
        sec := IniRead(_PosGuiIniPath(), "EventosCustom")
        for linea in StrSplit(sec, "`n", "`r") {
            p := InStr(linea, "=")
            if (!p)
                continue
            k := Trim(SubStr(linea, 1, p - 1))
            if (k = "lista" || k = "")
                continue
            d := StrSplit(Trim(SubStr(linea, p + 1)), "|")
            if (d.Length >= 1 && d[1] != "") {
                g := (d.Length >= 2) ? Trim(d[2]) : ""
                evs.Push([k, d[1], (g = "") ? "Personalizados" : g])
            }
        }
    }
    try {
        sg := IniRead(_PosGuiIniPath(), "EventosGrupo")
        for lin in StrSplit(sg, "`n", "`r") {
            q := InStr(lin, "=")
            if (!q)
                continue
            kk := Trim(SubStr(lin, 1, q - 1)), gr := Trim(SubStr(lin, q + 1))
            if (kk = "" || gr = "")
                continue
            for e in evs {
                if (e[1] = kk) {
                    e[3] := gr
                    break
                }
            }
        }
    }
    ; --- filtrar eventos eliminados ---
    try {
        secElim := IniRead(_PosGuiIniPath(), "EventosEliminados")
        mapElim := Map()
        for linea in StrSplit(secElim, "`n", "`r") {
            p := InStr(linea, "=")
            k := p ? Trim(SubStr(linea, 1, p - 1)) : Trim(linea)
            if (k = "lista" || k = "")
                continue
            v := p ? Trim(SubStr(linea, p + 1)) : "1"
            if (v = "1" || v = "")
                mapElim[k] := 1
        }
        listaElim := IniRead(_PosGuiIniPath(), "EventosEliminados", "lista", "")
        for item in StrSplit(listaElim, ",") {
            tItem := Trim(item)
            if (tItem != "")
                mapElim[tItem] := 1
        }
        i := evs.Length
        while (i >= 1) {
            if mapElim.Has(evs[i][1])
                evs.RemoveAt(i)
            i--
        }
    }
    return evs
}

_PtsEventoSlug(txt) {
    s := StrLower(Trim(RegExReplace(txt, "\(.*?\)", "")))
    s := StrReplace(StrReplace(StrReplace(StrReplace(StrReplace(s, "á", "a"), "é", "e"), "í", "i"), "ó", "o"), "ú", "u")
    s := StrReplace(s, "ñ", "n")
    return Trim(RegExReplace(s, "[^a-z0-9]+", "_"), "_")
}

; ── Asistente de nuevo evento (4 pestañas) ────────────────────────────
global ptsWiz := ""      ; asistente abierto (objeto) o ""
global ptsPend := Map()  ; slugs pendientes de parametrizar (cache para CUSTOMDRAW)

_PtsGruposBase() {
    return ["Pinceles y Trazos","Borradores y Mezcla","Color y Paleta","Selección","Lienzo y Reglas","Capas y Archivo"]
}

_PtsNuevoNombreDef() {
    usados := Map()
    for e in _PtsEventosDefs() {
        usados[StrLower(e[2])] := 1
        usados[e[1]] := 1
    }
    n := 1
    while (usados.Has(StrLower("Nuevo evento " n)) || usados.Has(_PtsEventoSlug("Nuevo evento " n)))
        n += 1
    return "Nuevo evento " n
}

_PtsSlugUnico(nombre) {
    base := _PtsEventoSlug(nombre)
    if (base = "")
        base := "evento"
    existe := Map()
    for e in _PtsEventosDefs()
        existe[e[1]] := 1
    slug := base
    n := 2
    while existe.Has(slug) {
        slug := base "_" n
        n += 1
    }
    return slug
}

_PtsNuevoEvento() {
    global ptsEd, ptsWiz
    if (IsObject(ptsWiz)) {
        try ptsWiz.g.Show()
        return
    }
    sug := _PtsNuevoNombreDef()
    g := Gui("+Owner" ptsEd.g.Hwnd " -MinimizeBox -MaximizeBox", "Nuevo evento")
    g.SetFont("s10")
    d := {g: g, cerrado: false}

    d.tab := g.Add("Tab3", "w440 h330", ["1 · Nombre","2 · Básica","3 · Grupo"])

    d.tab.UseTab(1)
    g.Add("Text", "w410", "Nombre visible del evento (opcional):")
    d.edNom := g.Add("Edit", "w410")
    try SendMessage(0x1501, 1, StrPtr(sug), d.edNom.Hwnd)    ; EM_SETCUEBANNER
    g.Add("Text", "w410 cGray", "Si lo dejas vacío se llamará «" sug "». El identificador técnico se genera solo.")

    d.tab.UseTab(2)
    g.Add("Text", "w410", "Atajo CSP principal (clic y pulsa la combinación, ej: Ctrl+Shift+B):")
    d.edAtajo := g.Add("Edit", "w410")
    _KgAttach(d.edAtajo)

    g.Add("Text", "w410 y+8", "Remapeo Companion *Opcional (clic y pulsa la combinación):")
    d.edRemap := g.Add("Edit", "w410")
    _KgAttach(d.edRemap)

    ; Resaltado suave amarillo señalando configuración automática predeterminada
    g.Add("Text", "w410 y+10 h24 c855a00 BackgroundFFF3CD +0x200", "  ★ Valores automáticos predeterminados:")

    g.Add("Text", "w410 y+8", "Formato visual HUD:")
    d.ddHud := g.Add("DropDownList", "w220 Choose1", ["Moderno","Bruto","Desactivado"])

    g.Add("Text", "w410 y+8", "Duración propia del aviso (ms, vacío = predeterminada):")
    d.edDur := g.Add("Edit", "w180 Number")
    try SendMessage(0x1501, 1, StrPtr("Predeterminada (global)"), d.edDur.Hwnd)

    d.chkSnd := g.Add("CheckBox", "w410 y+8 Checked", "Sonido / feedback visual al disparar")

    d.tab.UseTab(3)
    g.Add("Text", "w410", "Grupo (opcional). Sin elegir → «No definidos»:")
    lista := ["No definidos"]
    for x in _PtsGruposBase()
        lista.Push(x)
    pre := 1
    if (IsObject(ptsEd.ddGrupo) && ptsEd.ddGrupo.Value > 1) {   ; respeta el filtro activo
        for i, x in lista {
            if (x = ptsEd.ddGrupo.Text)
                pre := i
        }
    }
    d.ddGrp := g.Add("DropDownList", "w320 Choose" pre, lista)
    g.Add("Text", "w410 y+12 cGray", "💡 Los comportamientos avanzados (píldora, auto-clic, hover) se desbloquean en los acordeones del calibrador una vez creado el evento básico.")

    d.tab.UseTab()
    d.tab.GetPos(&tx, &ty, &tw, &th)
    btnMan := g.Add("Button", "x" tx " y" (ty + th + 10) " w215", "Continuar manualmente")
    btnOk  := g.Add("Button", "x+10 w215 Default", "Crear evento")
    g.Add("Text", "x" tx " y+8 w440 cGray", "Cerrar esta ventana equivale a «Continuar manualmente».")

    btnMan.OnEvent("Click",  (*) => _PtsWizFin(d, false))
    btnOk.OnEvent("Click",   (*) => _PtsWizFin(d, true))
    g.OnEvent("Close",       (*) => _PtsWizFin(d, false))
    g.OnEvent("Escape",      (*) => _PtsWizFin(d, false))

    ptsWiz := d
    ptsEd.g.Opt("+Disabled")
    g.Show("AutoSize")
    try d.edNom.Focus()
}

_PtsWizFin(d, usarConfig) {
    global ptsEd, ptsWiz
    if (d.cerrado)
        return
    d.cerrado := true
    r := {nombre: Trim(d.edNom.Value), grupo: d.ddGrp.Text
        , atajo: "", remap: "", hud: 1, dur: "", snd: 0}
    if (usarConfig) {
        r.atajo := Trim(d.edAtajo.Value)
        r.remap := Trim(d.edRemap.Value)
        r.hud   := d.ddHud.Value
        r.dur   := Trim(d.edDur.Value)
        r.snd   := d.chkSnd.Value
    }
    ptsEd.g.Opt("-Disabled")          ; antes de destruir, para no perder el foco
    d.g.Destroy()
    ptsWiz := ""
    try WinActivate("ahk_id " ptsEd.g.Hwnd)
    _PtsEvCrear(r)
}

_PtsEvCrear(r) {
    global ptsEd, ptsPend
    ini := _PosGuiIniPath()
    nombre := Trim(RegExReplace(r.nombre, "[|\r\n]", " "))
    if (nombre = "")
        nombre := _PtsNuevoNombreDef()
    grupo := (r.grupo != "") ? r.grupo : "No definidos"
    slug := _PtsSlugUnico(nombre)

    _PtsEventosDefs().Push([slug, nombre, grupo])      ; evs es static: la referencia persiste
    try IniWrite(nombre "|" grupo, ini, "EventosCustom", slug)
    if (r.atajo != "")
        try IniWrite(r.atajo, ini, "Remapeos", "atajo_" slug)
    if (r.remap != "")
        try IniWrite(r.remap, ini, "Remapeos", "remap_" slug)

    configurado := (r.atajo != "" || r.remap != "" || r.snd || r.dur != "" || r.hud != 1)
    if (configurado) {
        try IniDelete(ini, "EventosPendientes", slug)
    } else {
        try IniWrite("1", ini, "EventosPendientes", slug)
    }

    _PtsEvLeer()                                        ; poblar cfg para el nuevo slug
    if (configurado)
        _PtsEvWizAplicarCfg(slug, r)

    ; si el filtro de grupo oculta la fila nueva, volver a "Todos" (no dispara Change)
    if (IsObject(ptsEd.ddGrupo) && ptsEd.ddGrupo.Value > 1 && ptsEd.ddGrupo.Text != grupo)
        ptsEd.ddGrupo.Value := 1

    _PtsEvFilas()
    defs := _PtsEventosDefs()
    Loop ptsEd.lvEv.GetCount() {
        if (ptsEd.mapFilas.Has(A_Index) && defs[ptsEd.mapFilas[A_Index]][1] = slug) {
            ptsEd.lvEv.Modify(A_Index, "Select Focus Vis")
            _PtsEvSel(ptsEd.lvEv, A_Index, true)
            break
        }
    }
    _SonarUI("calib")
}

_PtsEvWizAplicarCfg(slug, r) {
    global ptsEd, PERFIL
    ini := _PosGuiIniPath()
    c := ptsEd.cfg[slug]
    ; Formato (+ zona/opacidad tal como las dejó _PtsEvLeer)
    _PtsEvGuardar(slug, ["moderno","bruto","desactivado"][r.hud], c.z, c.op)
    ; Duración propia
    if (r.dur != "") {
        try IniWrite(r.dur, ini, "HudEventos" PERFIL, "duracion_" slug)
        try _gDurCache.Clear()
    }
    ; Sonido / feedback
    if (r.snd) {
        try IniWrite("1", ini, "HudSonido" PERFIL, "ev_" slug "_activo")
        try _SndCacheMap().Clear()
    }
}

; Llamar desde el guardado de cualquier cambio manual sobre un evento (quita el rojo)
_PtsEvLimpiarPend(slug) {
    global ptsEd, ptsPend
    if (!IsObject(ptsPend) || !ptsPend.Has(slug))
        return
    try IniDelete(_PosGuiIniPath(), "EventosPendientes", slug)
    ptsPend.Delete(slug)
    try ptsEd.lvEv.Redraw()
}

_PtsJoin(arr, sep) {
    out := ""
    for v in arr
        out .= (A_Index > 1 ? sep : "") v
    return out
}
; ===== Lectura / escritura de zonas =====
_PtsEstabRect(foco) {
    global PERFIL
    ini := _PosGuiIniPath()
    sec := "Estab_p" PERFIL
    p := foco ? "f" : ""
    x := IniRead(ini,sec,p "x","")
    y := IniRead(ini,sec,p "y","")
    w := IniRead(ini,sec,p "w","")
    h := IniRead(ini,sec,p "h","")
    if (IsInteger(x) && IsInteger(y) && IsInteger(w) && IsInteger(h))
        return {x:Integer(x),y:Integer(y),w:Integer(w),h:Integer(h)}
    return {x:"",y:"",w:"",h:""}
}
_PtsRectDe(d) {
    global PUNTOS,ZONAS
    t := d.t
    if (t = "caja") {
        zs := (d.lado = "izq") ? ZONAS.izq : ZONAS.der
        z := zs[d.zi]
        return {x:z.x1,y:z.y1,w:z.x2 - z.x1 + 1,h:z.y2 - z.y1 + 1}
    }
    if (t = "hist") {
        z := ZONAS.hist
        return {x:z.x1,y:z.y1,w:z.x2 - z.x1 + 1,h:z.y2 - z.y1 + 1}
    }
    if (t = "punto") {
        rg := ObtenerRango(d.k)
        if (IsObject(rg) && IsInteger(rg.w) && rg.w > 0 && IsInteger(rg.h) && rg.h > 0)
            return rg
        return {x:PUNTOS[d.p][1],y:PUNTOS[d.p][2],w:"",h:""}
    }
    if (t = "estab" || t = "estabF")
        return _PtsEstabRect(t = "estabF")
    r := ObtenerRango(d.k, 0, true)                   ; el editor ve los valores aunque la zona este pausada
    return IsObject(r) ? r : {x:"",y:"",w:"",h:""}
}
_PtsAplicarZona(d,r) {
    global PUNTOS,HIST_ALTO,PERFIL
    t := d.t
    msg := ""
    if (t = "caja") {
        if (r.w < 6 || r.h < 6) {
            ptsEd.st.Value := "Rango demasiado pequeño (mín. 6×6 px)."
            return false
        }
        x2 := r.x + r.w - 1
        y2 := r.y + r.h - 1
        esq := [[r.x,r.y],[x2,r.y],[r.x,y2],[x2,y2]]
        for k,c in esq {
            PUNTOS[d.p + k - 1][1] := c[1]
            PUNTOS[d.p + k - 1][2] := c[2]
        }
        msg := r.w "×" r.h " en (" r.x "," r.y ")"
    } else if (t = "hist") {
        if (r.w < 6 || r.h < 1) {
            ptsEd.st.Value := "Rango de historial demasiado pequeño."
            return false
        }
        PUNTOS[27][1] := r.x
        PUNTOS[27][2] := r.y
        PUNTOS[28][1] := r.x + r.w - 1
        PUNTOS[28][2] := r.y
        HIST_ALTO := Max(0,r.h - 1)
        msg := r.w "×" r.h " en (" r.x "," r.y ")"
    } else if (t = "punto") {
        w := (IsInteger(r.w) && r.w > 0) ? r.w : 0
        h := (IsInteger(r.h) && r.h > 0) ? r.h : 0
        px := (w > 0) ? (r.x + w // 2) : r.x
        py := (h > 0) ? (r.y + h // 2) : r.y
        PUNTOS[d.p][1] := px
        PUNTOS[d.p][2] := py
        if (w > 0 && h > 0)
            IniWrite(r.x "," r.y "," w "," h,_PosGuiIniPath(),_ZonaSec("Rangos"),d.k)
        else
            IniWrite(px "," py,_PosGuiIniPath(),_ZonaSec("Rangos"),d.k)
        msg := (w > 0) ? (w "×" h " en (" r.x "," r.y ")") : ("(" px "," py ")")
    } else if (t = "estab") {
        if !_EstabTamanoValido(r.w,r.h) {
            ptsEd.st.Value := "Zona demasiado pequeña (mín. 14 px de grosor y 60 de largo)."
            return false
        }
        if !_EstabAplicarRect(r.x,r.y,r.w,r.h) {
            ini := _PosGuiIniPath()
            sec := "Estab_p" PERFIL
            IniWrite(r.x,ini,sec,"x")
            IniWrite(r.y,ini,sec,"y")
            IniWrite(r.w,ini,sec,"w")
            IniWrite(r.h,ini,sec,"h")
        }
        msg := r.w "×" r.h " (" ((r.w > r.h) ? "horizontal" : "vertical") ")"
    } else if (t = "estabF") {
        if !_EstabTamanoValido(r.w,r.h) {
            ptsEd.st.Value := "Zona demasiado pequeña (mín. 14 px de grosor y 60 de largo)."
            return false
        }
        _EstabFocoGuardarRect(r.x,r.y,r.w,r.h)
        msg := r.w "×" r.h " (" ((r.w > r.h) ? "horizontal" : "vertical") "). Aparece con Shift+E"
        try _EstabFocoPrevisualizar()
    } else {
        if (r.w < 6 || r.h < 6) {
            ptsEd.st.Value := "Rango demasiado pequeño (mín. 6×6 px)."
            return false
        }
        IniWrite(r.x "," r.y "," r.w "," r.h,_PosGuiIniPath(),_ZonaSec("Rangos"),d.k)
        msg := r.w "×" r.h " en (" r.x "," r.y ")"
    }
    _PtsZonasVivo(d)                       ; Dibuja cajas overlay en pantalla (feedback inmediato)
    ptsEd.st.Value := d.n " guardado: " msg
    _SonarUI("calib")
    SetTimer(_PtsRefrescarDiferido, -30)   ; RecalcularZonas + ListView + tabla Nv, agrupado en un solo disparo
    return true
}
_RgGuardarMirror() {
    global PERFIL
    ini := _PosGuiIniPath()
    sec := _ZonaSec("Rangos")
    IniWrite("x,y,ancho,alto en px de pantalla virtual (puntos: x,y). Derivado de P1..P32; HUD_Alta y HUD_Media son propios.",ini,sec,"_formato")
    for d in _PtsZonaDefs() {
        if (d.t = "estab" || d.t = "estabF" || d.t = "hud")
            continue
        r := _PtsRectDe(d)
        if (d.t = "punto" && !(IsInteger(r.w) && r.w > 0 && IsInteger(r.h) && r.h > 0))
            v := r.x "," r.y
        else
            v := r.x "," r.y "," r.w "," r.h
        IniWrite(v,ini,sec,d.k)
    }
}
; ===== P1: zonas en vivo (reconstruye las cajas o destella la zona recién trazada) =====
_PtsZonasVivo(d := 0) {
    if (!IsObject(ptsEd) || !IsObject(ptsEd.ovl))
        return
    if (ptsEd.HasProp("dibujando") && ptsEd.dibujando)
        return                                 ; overlays atenuados: se rearman al terminar el dibujo/ajuste
    if (ptsEd.ovl.Length > 0) {          ; "Ver zonas" activo: rearmar todas las cajas con los valores nuevos
        MostrarZonasCalibracion(0)
        return
    }
    if IsObject(d)
        _PtsDestello(d)
}
_PtsDestello(d := 0) {
    ; Sin argumentos (la llama el SetTimer) solo limpia el destello anterior.
    static gF := 0
    if IsObject(gF) {
        try _OvlDestruir(gF)
        gF := 0
    }
    if !IsObject(d)
        return
    r := _PtsRectDe(d)
    if (!IsObject(r) || !IsInteger(r.x) || !IsInteger(r.y))
        return
    if (IsInteger(r.w) && r.w > 0 && IsInteger(r.h) && r.h > 0)
        gF := _CrearRectOverlay(r.x,r.y,r.w,r.h,d.c,d.n)
    else
        gF := _CrearRectOverlay(r.x - 6,r.y - 6,12,12,d.c,d.n)
    SetTimer(_PtsDestello,-1600)
}

; Área de trabajo del monitor que contiene el punto (x, y); si ninguno, el primario.
_PtsAreaMonitor(x, y, &mL, &mT, &mR, &mB) {
    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
        if (x >= l && x < r && y >= t && y < b) {
            mL := l, mT := t, mR := r, mB := b
            return
        }
    }
    MonitorGetWorkArea(MonitorGetPrimary(), &mL, &mT, &mR, &mB)
}

; Posiciona una etiqueta (lw x lh) junto a un rectángulo sin salir del monitor.
; Regla: por defecto arriba (cy - 30); si cy < mT + 40, flip hacia abajo;
; si abajo tampoco cabe, dentro del rectángulo. X se clampa a [mL+4, mR-lw].
_PtsClampEtiqueta(cx, cy, cw, ch, lw, lh, &lx, &ly) {
    _PtsAreaMonitor(cx + cw // 2, cy + ch // 2, &mL, &mT, &mR, &mB)
    ly := cy - 30
    if (cy < mT + 40) {
        ly := cy + ch + 4
        if (ly + lh > mB)
            ly := cy + 4
    }
    lx := cx
    if (lx + lw > mR)
        lx := mR - lw
    if (lx < mL + 4)
        lx := mL + 4
}

; ===== Dibujo con lápiz =====
_PtsDibujarRango(texto,color := "9A7BFF",permitirPunto := false,ses := "") {
    static enRango := false
    if (enRango)
        return 0
    enRango := true
    ptsEd.dibujando := true
    ov := 0
    tip := 0
    tipTxt := 0
    pv := 0
    ok := false
    cancelado := false
    x0 := 0
    y0 := 0
    rx := 0
    ry := 0
    rw := 0
    rh := 0
    try {
        try ptsEd.g.Hide()
        vx := SysGet(76)
        vy := SysGet(77)
        vw := SysGet(78)
        vh := SysGet(79)
        ov := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale","")
        ov.BackColor := "0B0B14"
        ov.Show("x" vx " y" vy " w" vw " h" vh)
        WinSetTransparent(80,"ahk_id " ov.Hwnd)
        if (IsObject(ptsEd) && HasProp(ptsEd, "ovl") && IsObject(ptsEd.ovl)) {
            for govl in ptsEd.ovl
                try DllCall("SetWindowPos","Ptr",govl.Hwnd,"Ptr",-1,"int",0,"int",0,"int",0,"int",0,"uint",0x0003)
        }
        if (IsObject(ptsEd) && HasProp(ptsEd, "gRefAnterior") && IsObject(ptsEd.gRefAnterior))
            try DllCall("SetWindowPos","Ptr",ptsEd.gRefAnterior.Hwnd,"Ptr",-1,"int",0,"int",0,"int",0,"int",0,"uint",0x0003)
        mEtZ := _OvlEtiquetas()
        for hwZ, glZ in mEtZ
            try DllCall("SetWindowPos","Ptr",glZ.Hwnd,"Ptr",-1,"int",0,"int",0,"int",0,"int",0,"uint",0x0003)
        mon := ObtenerMonitorCSP()
        if (IsObject(ses)) {
            tip := 0
            _PtsPanelAlFrente(ses)          ; el panel queda sobre el overlay
        } else {
            tip := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale","")
            tip.BackColor := "1E1E2E"
            tip.SetFont("s11 bold cWhite","Segoe UI")
            tipTxt := tip.AddText("x12 y8 w900 h26 Center",texto)
            tip.Show("x" (mon.x + (mon.w - 924) // 2) " y" (mon.y + 40) " w924 h42 NoActivate")
        }
        KeyWait("LButton")                             ; esperar a que se libere el clic del botón/doble-clic
        cur := Buffer(8,0)
        t0 := A_TickCount
        while (true) {
            while (!GetKeyState("LButton") && !GetKeyState("LButton","P")) {
                if (GetKeyState("Escape","P") || A_TickCount - t0 > 60000
                    || (IsObject(ses) && ses.cambio != "")) {
                    cancelado := true
                    break
                }
                Sleep(10)
            }
            if (cancelado || !IsObject(ses))
                break
            DllCall("GetCursorPos","Ptr",cur)
            if !_PtsPanelContiene(ses, NumGet(cur,0,"int"), NumGet(cur,4,"int"))
                break
            KeyWait("LButton")              ; toque sobre el panel: no inicia rectángulo
            t0 := A_TickCount
        }
        if !cancelado {
            DllCall("GetCursorPos","Ptr",cur)
            x0 := NumGet(cur,0,"int")
            y0 := NumGet(cur,4,"int")
            pv := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale","")
            pv.BackColor := color
            pv.Show("x" x0 " y" y0 " w4 h4 NoActivate")
            WinSetTransparent(150,"ahk_id " pv.Hwnd)
            rx := x0
            ry := y0
            rw := 4
            rh := 4
            ultW := -1
            ultH := -1
            while (GetKeyState("LButton") || GetKeyState("LButton","P")) {
                DllCall("GetCursorPos","Ptr",cur)
                mx := NumGet(cur,0,"int")
                my := NumGet(cur,4,"int")
                rx := Min(x0,mx)
                ry := Min(y0,my)
                rw := Max(4,Abs(mx - x0))
                rh := Max(4,Abs(my - y0))
                DllCall("SetWindowPos","Ptr",pv.Hwnd,"Ptr",-1,"int",rx,"int",ry,"int",rw,"int",rh,"uint",0x0010)
                if (rw != ultW || rh != ultH) {
                    ultW := rw
                    ultH := rh
                    if (IsObject(ses))
                        _PtsPanelInfo(ses, rw " × " rh)
                    else
                        tipTxt.Value := texto "   ·   " rw " × " rh
                }
                if (GetKeyState("Escape","P") || (IsObject(ses) && ses.cambio != "")) {
                    cancelado := true
                    break
                }
                Sleep(8)
            }
            if !cancelado
                ok := true
        }
    } finally {
        for gg in [pv,tip,ov] {
            if IsObject(gg)
                try gg.Destroy()
        }
        enRango := false
        if (!ptsEd.HasProp("ovlEstaba") || !ptsEd.ovlEstaba)
            ptsEd.dibujando := false
    }
    KeyWait("Escape","T1")
    try ptsEd.g.Show()
    if !ok
        return 0
    if (permitirPunto && rw <= 8 && rh <= 8)
        return {x:x0,y:y0,w:0,h:0}
    return {x:rx,y:ry,w:rw,h:rh}
}
_PtsFilaActual() {
    global ptsEd
    if (!IsObject(ptsEd.lv))
        return ptsEd.sel
    f := ptsEd.lv.GetNext(0,"F")
    if (f < 1)
        f := ptsEd.lv.GetNext(0)
    return (f >= 1) ? f : ptsEd.sel
}

_PtsOvlLimpiarRefAnterior() {
    global ptsEd
    if (IsObject(ptsEd) && HasProp(ptsEd, "gRefAnterior") && IsObject(ptsEd.gRefAnterior)) {
        try _OvlDestruir(ptsEd.gRefAnterior)
        ptsEd.gRefAnterior := 0
    }
}

_PtsOvlAtenuar(on, dActual := 0) {
    global ptsEd
    if (on) {
        ptsEd.dibujando := true
        ptsEd.ovlEstaba := (IsObject(ptsEd.bVer) && InStr(ptsEd.bVer.Text,"Ocultar"))
        ; Si las zonas no estaban mostradas en pantalla, las mostramos como referencia visual
        if (!IsObject(ptsEd.ovl) || ptsEd.ovl.Length = 0) {
            MostrarZonasCalibracion()
            ptsEd.ovlAutoCreado := true
        } else {
            ptsEd.ovlAutoCreado := false
        }
        ; Bajar opacidad de todas las demás zonas para que sirvan de guía sin estorbar
        for g in ptsEd.ovl {
            try WinSetTransparent(45, g.Hwnd)
        }
        mEt := _OvlEtiquetas()
        for hw, gl in mEt {
            try WinSetTransparent(70, gl.Hwnd)
        }
        ; Mostrar silueta previa (estado anterior) de la zona activa
        _PtsOvlLimpiarRefAnterior()
        if (IsObject(dActual)) {
            r := _PtsRectDe(dActual)
            if (IsObject(r) && IsInteger(r.w) && r.w > 0 && IsInteger(r.h) && r.h > 0) {
                ptsEd.gRefAnterior := _CrearRectOverlay(r.x, r.y, r.w, r.h, "00E5FF", dActual.n " [anterior]")
                try WinSetTransparent(170, ptsEd.gRefAnterior.Hwnd)
            }
        }
    } else {
        _PtsOvlLimpiarRefAnterior()
        ptsEd.dibujando := false
        if (ptsEd.HasProp("ovlAutoCreado") && ptsEd.ovlAutoCreado) {
            OcultarZonasCalibracion()
            ptsEd.ovlAutoCreado := false
        } else {
            ; Restaurar opacidad normal
            for g in ptsEd.ovl {
                try WinSetTransparent(160, g.Hwnd)
            }
            mEt := _OvlEtiquetas()
            for hw, gl in mEt {
                try WinSetTransparent(255, gl.Hwnd)
            }
        }
    }
}

_PtsDibujarSel(encadenar := false) {
    defs := _PtsZonaDefs()
    i := _PtsFilaActual()
    if (i < 1 || i > defs.Length) {
        ptsEd.st.Value := "Selecciona primero una zona en la lista."
        return
    }
    ptsEd.sel := i
    _PtsOvlAtenuar(true, defs[i])
    try {
        Loop {
            d := defs[i]
            _PtsOvlAtenuar(true, d)
            if (d.t = "punto")
                txt := "✏ " d.n "  ·  haz clic en el punto (o arrastra una caja)  ·  Esc = cancelar"
            else
                txt := "✏ " d.n "  ·  arrastra el lápiz para dibujar el rango  ·  Esc = cancelar"
            r := _PtsDibujarRango(txt,d.c,d.t = "punto")
            if !IsObject(r) {
                ptsEd.st.Value := "Dibujo cancelado."
                break
            }
            okz := _PtsAplicarZona(d,r)
            if (!okz || !encadenar || i >= defs.Length)
                break
            i += 1
            ptsEd.sel := i
            try ptsEd.lv.Modify(i,"Select Focus Vis")
        }
    } finally {
        _PtsOvlAtenuar(false)
    }
}

_PtsLvEntero(fila, col) {
    global ptsEd
    try {
        v := Trim(ptsEd.lv.GetText(fila, col))
        if RegExMatch(v, "^-?\d+$")
            return Integer(v)
    }
    return ""
}

_PtsAjustarZona() {
    global ptsEd
    defs := _PtsZonaDefs()
    i := _PtsFilaActual()
    if (i < 1 || i > defs.Length) {
        ptsEd.st.Value := "Selecciona primero una zona en la lista."
        return
    }
    ptsEd.sel := i
    d := defs[i]
    x := _PtsLvEntero(i, 3)
    y := _PtsLvEntero(i, 4)
    w := _PtsLvEntero(i, 5)
    h := _PtsLvEntero(i, 6)
    sinTam := (d.t = "punto" || w = "" || h = "" || w <= 0 || h <= 0)
    if (x = "" || y = "") {
        _PtsDibujarSel(false)
        return
    }
    rIni := {x: x, y: y, w: (sinTam ? 80 : w), h: (sinTam ? 60 : h)}
    txt := "📐 Ajustar " d.n "  ·  arrastra esquinas/bordes  ·  Enter/doble clic = guardar  ·  Esc = cancelar"
    _PtsOvlAtenuar(true, d)
    try {
        r := _PtsEditarRangoInteractivo(txt, d.k, rIni)
        if (!IsObject(r)) {
            ptsEd.st.Value := "Ajuste cancelado."
            return
        }
        if (sinTam)
            r := {x: r.x + r.w // 2, y: r.y + r.h // 2, w: 0, h: 0}
        _PtsAplicarZona(d, r)
    } finally {
        _PtsOvlAtenuar(false)
    }
}

; ===== Tabla de zonas =====
_PtsCamposDe(*) {
}
_PtsSel(ctrl,item,selected) {
    if (!selected || item < 1)
        return
    ptsEd.sel := item
    _PtsCamposDe(item)
    d := _PtsZonaDefs()[item]
    ptsEd.st.Value := d.n " — " ((d.t = "punto") ? "punto" : "rango") (ZonaPausada(d.k) ? " (⏸ pausada)" : "") ". Dibuja o ajusta la zona con el lápiz. Clic derecho: pausar / eliminar."
}
_PtsRefrescar() {
    RecalcularZonas()
    for i,d in _PtsZonaDefs() {
        r := _PtsRectDe(d)
        ptsEd.lv.Modify(i,"",(ZonaPausada(d.k) ? "⏸ " : "") d.n,(d.t = "punto") ? "Punto" : "Rango",r.x,r.y,r.w,r.h)
    }
    if (ptsEd.sel >= 1)
        _PtsCamposDe(ptsEd.sel)
}
_PtsDesplazar(*) {
    dx := Trim(ptsEd.dx.Value)
    dy := Trim(ptsEd.dy.Value)
    if (!IsInteger(dx) || !IsInteger(dy)) {
        ptsEd.st.Value := "ΔX y ΔY deben ser enteros."
        return
    }
    dx := Integer(dx)
    dy := Integer(dy)
    for p in PUNTOS {
        p[1] += dx
        p[2] += dy
    }
    _PtsRefrescar()
    _PtsZonasVivo()
    ptsEd.dx.Value := "0"
    ptsEd.dy.Value := "0"
    ptsEd.st.Value := "Desplazados: ΔX=" dx " ΔY=" dy
}
_PtsDefecto(*) {
    global HIST_ALTO,PUNTOS
    ptsEd.g.Opt("+OwnDialogs")
    if (MsgBox("¿Restablecer todos los puntos de este perfil a los valores por defecto?","Por defecto","YesNo Icon?") != "Yes")
        return
    PUNTOS := PuntosPorDefecto()
    HIST_ALTO := 104
    _PtsRefrescar()
    _PtsZonasVivo()
    ptsEd.st.Value := "Cargados los rangos por defecto (se guardan con 💾)."
}
; ===== Paquete 2: pausar / reanudar / eliminar zonas (menu contextual del ListView) =====
; Pausables: cajas de panel, historial, HUD y NvZona1-8. NO pausables (funcionales):
; ToggleIzq/ToggleDer (AccionEnfoque), ZonaSegura (parqueo en deshacer/rehacer),
; Estab, EstabFoco y NvPestana (obligatoria para detectar la franja de pestanas).
_PtsZonaPausable(d) {
    return (d.t = "caja" || d.t = "hist" || d.t = "hud" || SubStr(d.k, 1, 6) = "NvZona")
}

; Todas las zonas del catalogo son eliminables (Estab/EstabFoco/NvPestana con refresco en vivo).
_PtsZonaEliminable(d) {
    return true
}

_PtsMenuZona(ctrl, item, esDerecho, *) {
    if (item < 1)
        return
    defs := _PtsZonaDefs()
    if (item > defs.Length)
        return
    d := defs[item]
    ptsEd.lv.Modify(item, "Select Focus")
    ptsEd.sel := item
    lblPausa := ZonaPausada(d.k) ? "▶ Reanudar zona" : "⏸ Pausar zona"
    lblElim := "🗑 Eliminar (limpiar valores)"
    m := Menu()
    m.Add(lblPausa, (*) => _PtsPausarAlternar(d))
    m.Add(lblElim, (*) => _PtsEliminar(d))
    if (!_PtsZonaPausable(d))
        m.Disable(lblPausa)
    if (!_PtsZonaEliminable(d))
        m.Disable(lblElim)
    m.Show()
}

_PtsPausarAlternar(d) {
    if !_PtsZonaPausable(d)
        return
    pausar := !ZonaPausada(d.k)
    ZonaPausar(d.k, pausar)
    _PtsRefrescar()
    try _PtsZonasVivo()
    ptsEd.st.Value := d.n (pausar ? " ⏸ pausada: conserva sus valores; sus consumidores la ignoran." : " ▶ reanudada.")
    try _SonarUI("calib")
}

; Eliminar = limpiar sus claves INI en AMBOS modos (Normal y Enfoque) y volver a defecto/libre.
; Nunca toca _PtsZonaDefs() ni su orden. La pausa de la zona tambien se limpia.
_PtsEliminar(d) {
    global PUNTOS, HIST_ALTO, PERFIL, PUNTOS_DEF, estabGui
    if !_PtsZonaEliminable(d)
        return
    extra := (d.k = "ToggleIzq" || d.k = "ToggleDer") ? "`n`nOJO: este punto alimenta el modo Enfoque." : ""
    if (d.k = "NvPestana")
        extra := "`n`nOJO: «Nuevas ventanas» usará el cálculo de respaldo hasta que vuelvas a calibrar la franja de pestañas."
    else if (d.t = "estab")
        extra := "`n`nEl deslizador volverá a su posición por defecto."
    else if (d.t = "estabF")
        extra := "`n`nEl deslizador de enfoque se ocultará; reaparece con Shift+E en su posición por defecto."
    ptsEd.g.Opt("+OwnDialogs")
    if (MsgBox("¿Eliminar «" d.n "»? Se limpian sus valores guardados en ambos modos (Normal y Enfoque) y vuelve a su valor por defecto / libre." extra, "Eliminar zona", "YesNo Icon?") != "Yes")
        return
    ini := _PosGuiIniPath()
    secP := [_ZonaSec("Puntos", 1), _ZonaSec("Puntos", 2)]
    secR := [_ZonaSec("Rangos", 1), _ZonaSec("Rangos", 2)]
    idx := []
    if (d.t = "caja") {
        Loop 4
            idx.Push(d.p + A_Index - 1)
    } else if (d.t = "hist") {
        idx := [27, 28]
    } else if (d.t = "punto") {
        idx := [d.p]
    } else if (d.t = "estab") {
        idx := [31, 32]                               ; espejo PUNTOS[31]/[32] del rect del deslizador
    }
    for i in idx {
        if (IsObject(PUNTOS_DEF) && i <= PUNTOS_DEF.Length && i <= PUNTOS.Length)
            PUNTOS[i] := [PUNTOS_DEF[i][1], PUNTOS_DEF[i][2]]
        for sec in secP {
            try IniDelete(ini, sec, "P" i "x")
            try IniDelete(ini, sec, "P" i "y")
        }
        if (PERFIL = 1) {
            try IniDelete(ini, "Puntos", "P" i "x")
            try IniDelete(ini, "Puntos", "P" i "y")
        }
    }
    if (d.t = "hist") {
        HIST_ALTO := 104
        for sec in secP
            try IniDelete(ini, sec, "HistAlto")
        if (PERFIL = 1)
            try IniDelete(ini, "Puntos", "HistAlto")
    }
    for sec in secR
        try IniDelete(ini, sec, d.k)
    if (d.k = "NvPestana") {
        for sec in secR
            try IniDelete(ini, sec, "NvPestanaMarco")     ; marco CSP guardado junto a la franja
    }
    if (d.t = "estab" || d.t = "estabF") {
        secE := "Estab_p" PERFIL
        claves := (d.t = "estab") ? ["x", "y", "w", "h"] : ["fx", "fy", "fw", "fh"]
        for c in claves
            try IniDelete(ini, secE, c)                   ; "visible" NO se toca
        if (d.t = "estab") {
            ; en vivo solo si ya esta visible (_EstabAplicarRect lo mostraria si estuviera oculto)
            try {
                if (IsObject(estabGui.g) && estabGui.visible) {
                    r := _EstabRectGuardada()             ; sin claves => _EstabRectCalibrada() (defecto)
                    _EstabAplicarRect(r.x, r.y, r.w, r.h)
                    for c in claves                       ; _EstabAplicarRect reescribe el rect: se limpia de nuevo
                        try IniDelete(ini, secE, c)
                }
            }
        } else {
            try _EstabFocoOcultar()                       ; reaparece con Shift+E leyendo el rect por defecto
        }
    }
    _PtsCache(true)                                       ; INI de Puntos cambió (ambos modos + legacy)
    if ZonaPausada(d.k)
        ZonaPausar(d.k, false)
    _PtsRefrescar()
    try _PtsZonasVivo()
    if (SubStr(d.k, 1, 2) = "Nv")
        try _NvPanRefrescarTabla()                        ; la pestaña 5 refleja la zona eliminada
    ptsEd.st.Value := d.n " eliminada: valores limpiados (defecto / libre)."
    try _SonarUI("calib")
}
; ===== Eventos / HUD =====
_GuardarDuracionesHUD(dA, dM, dB) {
    global PERFIL, _gDurCache
    vals := []
    for v in [dA,dM,dB] {
        v := Trim(v)
        if (!IsInteger(v) || Integer(v) < 1 || Integer(v) > 60000) {
            if IsObject(ptsEd.st)
                ptsEd.st.Value := "Duración inválida: enteros de 1 a 60000 ms (3 se lee como 300 ms)."
            return
        }
        n := Integer(v)
        vals.Push((n <= 10) ? n * 100 : n)
    }
    ini := _PosGuiIniPath()
    sec := "HudDuraciones" PERFIL
    IniWrite(vals[1], ini, sec, "duracion_alta")
    IniWrite(vals[2], ini, sec, "duracion_media")
    IniWrite(vals[3], ini, sec, "duracion_baja")
    ; HudDuracionDe() no lee la sección de arriba: lee [HudDuracion<perfil>] con
    ; claves alta|media|baja y sin normalizar, así que aquí se escribe ya en ms.
    for i, clave in ["alta","media","baja"]
        IniWrite(vals[i], ini, "HudDuracion" PERFIL, clave)
    _gDurCache.Clear()
    if IsObject(ptsEd.st)
        ptsEd.st.Value := "⏱ Duraciones guardadas: Alta=" vals[1] "ms, Media=" vals[2] "ms, Baja=" vals[3] "ms"
    if (IsObject(ptsEd.g) && IsObject(ptsEd.lvEv)) {
        _PtsEvFilas()
        _PtsEvDurRefrescar()
    }
}
_PtsDurPropia(id) {
    global PERFIL
    v := Trim(IniRead(_PosGuiIniPath(),"HudEventos" PERFIL,"duracion_" id,""))
    return (IsInteger(v) && Integer(v) > 0) ? String(Integer(v)) : ""
}
_PtsDurEfectiva(id,z) {
    ; HudDuracionDe (core_config) es la que usa el motor, así que la etiqueta muestra
    ; lo que de verdad va a pasar; el resto replica su orden por si aún no está.
    if IsSet(HudDuracionDe) {
        try return HudDuracionDe(id)
    }
    propia := _PtsDurPropia(id)
    if (propia != "") {
        v := Integer(propia)
        return Max(50,(v <= 10) ? v * 100 : v)
    }
    return HudDuracionZona(z)
}
_PtsEvDurAplicar(*) {
    global PERFIL, _gDurCache
    filas := _PtsEvObtenerSeleccionados(ptsEd.lvEv)
    if (filas.Length = 0 && ptsEd.evSel >= 1)
        filas := [ptsEd.evSel]
    if (filas.Length = 0) {
        ptsEd.st.Value := "Selecciona uno o más eventos para fijar su duración."
        return
    }
    v := Trim(ptsEd.eDurEv.Value)
    if (v != "" && (!IsInteger(v) || Integer(v) < 1 || Integer(v) > 60000)) {
        ptsEd.st.Value := "Duración inválida: entero de 1 a 60000 ms, o vacío para heredar de la prioridad."
        return
    }
    if (v != "") {
        ms := Integer(v)
        v := String((ms <= 10) ? ms * 100 : ms)   ; HudDuracionDe no normaliza: se guarda ya en ms
    }
    defs := _PtsEventosDefs()
    ini := _PosGuiIniPath()
    sec := "HudEventos" PERFIL
    n := 0
    for row in filas {
        if !ptsEd.mapFilas.Has(row)
            continue
        IniWrite(v,ini,sec,"duracion_" defs[ptsEd.mapFilas[row]][1])
        n += 1
    }
    _gDurCache.Clear()
    _PtsEvFilas()
    _PtsEvDurRefrescar()
    ptsEd.st.Value := (v = "") ? ("Duración propia borrada en " n " evento(s): heredan de su prioridad.") : ("Duración guardada: " v " ms en " n " evento(s).")
    _SonarUI("calib")
}
_PtsEvDobleClick(ctrl, rowNumber) {
    global PERFIL, _gDurCache
    if (rowNumber < 1 || !ptsEd.mapFilas.Has(rowNumber))
        return
    defs := _PtsEventosDefs()
    ev := defs[ptsEd.mapFilas[rowNumber]]
    idEv := ev[1]
    nomEv := ev[2]
    c := ptsEd.cfg[idEv]
    durPropia := _PtsDurPropia(idEv)
    durEfec := _PtsDurEfectiva(idEv, c.z)

    txtActual := (durPropia != "") ? (durPropia " ms (individual)") : (durEfec " ms (heredada de " _PtsZonaTxt(c.z) ")")
    ib := InputBox(
        "Modificar duración individual para:`n`n" nomEv "`n`n• Actual: " txtActual "`n• Ingresa duración en ms (ej: 300, 500, o 3 para 300 ms)`n• Deja vacío para HEREDAR de la prioridad estándar.",
        "⏱ Duración individual — " nomEv,
        "w400 h240",
        durPropia != "" ? durPropia : durEfec
    )
    if (ib.Result != "OK")
        return

    v := Trim(ib.Value)
    if (v != "") {
        if (!IsNumber(v) || v * 1 < 1 || v * 1 > 60000) {
            MsgBox("Duración inválida: ingresa un número de 1 a 60000 ms.", "Calibrador", "Icon! 0x40000")
            return
        }
        ms := Integer(v)
        v := String((ms <= 10 && ms > 0) ? ms * 100 : ms)
    }

    ini := _PosGuiIniPath()
    sec := "HudEventos" PERFIL
    IniWrite(v, ini, sec, "duracion_" idEv)
    _gDurCache.Clear()
    _PtsEvFilas()
    _PtsEvDurRefrescar()
    _SonarUI("calib")
    ptsEd.st.Value := (v = "") ? ("Duración propia eliminada para " nomEv " (hereda de prioridad).") : ("Duración fijada a " v " ms para " nomEv ".")
}
_PtsEvDurRefrescar() {
    if (!IsObject(ptsEd.g) || !ptsEd.mapFilas.Has(ptsEd.evSel))
        return
    ev := _PtsEventosDefs()[ptsEd.mapFilas[ptsEd.evSel]]
    c := ptsEd.cfg[ev[1]]
    propia := _PtsDurPropia(ev[1])
    ptsEd.eDurEv.Value := propia
    efectiva := _PtsDurEfectiva(ev[1],c.z)
    ; Sin clave zona_<id> en el ini, HudDuracionDe cae en el defecto del evento y no
    ; en la prioridad: decir "heredada de Baja" ahí sería mentira.
    origen := (propia != "") ? "propia del evento" : ((efectiva = HudDuracionZona(c.z)) ? "heredada de " _PtsZonaTxt(c.z) : "por defecto del evento")
    ptsEd.lblDurEfec.Value := "Efectiva: " efectiva " ms"
    try _AyudaReg(ptsEd.lblDurEfec, "Duración efectiva del aviso (ms). Origen: " origen ".")
    filas := _PtsEvObtenerSeleccionados(ptsEd.lvEv)
    if (filas.Length > 1)
        ptsEd.stEv.Value := "▶ " filas.Length " eventos seleccionados  ·  " StrTitle(c.f) " · " _PtsZonaTxt(c.z) " · " c.op "% · " efectiva " ms"
    else
        ptsEd.stEv.Value := "▶ " ev[2] "  ·  " StrTitle(c.f) " · " _PtsZonaTxt(c.z) " · " c.op "% · " efectiva " ms"
}
_PtsZonaTxt(z) {
    return (z = "alta") ? "Alta" : ((z = "media") ? "Media" : "Baja")
}
; ═══════════ ACORDEÓN · Fase C ═══════════
_AccPx(v) {
    return Round(v * _PtsUIEscala())
}

; ===== Layout fila-horizontal (Fase 2) =====
_LyBase() => 704                                   ; ancho de diseño de cw
_LyFs(b) => Round(b * Min(_PtsUIEscala(), 1.35))   ; misma fórmula que _AccInit
_LyH(k) => (k = "p1") ? 52 : (k = "p2") ? 116 : (k = "snd") ? 84 : 0
_LyY(k) {                                          ; cadena monótona, sin solapes
    y := 250                                       ; gA
    if (k = "gA")
        return y
    y += 50                                        ; gA (47) + gap 3
    for id in ["p1","p2","snd"] {
        if (k = id)
            return y
        y += _LyH(id) + 3
    }
    return y + 9                                   ; p4: A→B = 12
}
; Fija el alto de una fila fija y baja el separador al pie (tras _AccFin)
_AccFila(altoLog) {
    global ACC
    p := ACC.paneles[ACC.paneles.Length]
    p.hdr.GetPos(, &hy)
    p.line.GetPos(, , , &lh)
    p.lineDy := _AccPx(altoLog - 2)
    p.altoCerr := p.lineDy + lh
    p.altoAbi := Max(p.altoAbi, p.lineDy + lh)
    p.line.Move(, hy + p.lineDy)
}
; NN + título + subtítulo (todo vía _R; la cabecera del motor queda oculta)
_LyEncab(x0, cw, yTop, nn, titulo, sub) {
    global ACC
    g := ACC.g, uiP := ACC.uiP
    xT := x0 + 44
    t := _R(g.Add("Text", uiP(x0 + 14, yTop + 6, 26, 20) . " +0x200", nn))
    t.SetFont("bold s" _LyFs(10))
    t := _R(g.Add("Text", uiP(xT, yTop + 6, Round(cw * 0.325) - 48, 20) . " +0x200 +0x4000", titulo))
    t.SetFont("bold s" _LyFs(10))
    t := _R(g.Add("Text", uiP(xT, yTop + 28, Round(cw * 0.37) - 46, 16) . " +0x200 +0x4000 cGray", sub))
    t.SetFont("s" _LyFs(8))
}
; Check maestro de 02 (⇔ ddF ≠ "Desactivado"), semántica de blocks.py
_LyHudCtl(c := 0) {
    static ctl := 0
    if (c)
        ctl := c
    return ctl
}
_LyHudPrev(v := 0) {
    static prev := 1
    if (v)
        prev := v
    return prev
}
_PtsHudChkClick(chk, *) {
    global ptsEd
    dd := ptsEd.ddF
    if (chk.Value)
        dd.Choose(_LyHudPrev())
    else {
        if (dd.Value != 3)
            _LyHudPrev(dd.Value)
        dd.Choose(3)
    }
    _PtsEvCambio()                                  ; Choose no dispara Change
}
_PtsHudChkSync(*) {
    global ptsEd
    c := _LyHudCtl()
    if (!c)
        return
    try {
        v := ptsEd.ddF.Value
        c.Value := (v != 3)
        if (v != 3)
            _LyHudPrev(v)
    }
}

_AccInit(g, tab, x0, cw, fnUiP, lvEv := 0) {
    global ACC
    yBase := _LyY("p1")                            ; y absoluto donde nace el Box 2
    vp := Gui("-Caption +Parent" g.Hwnd " +0x2000000 +0x200000 +E0x10000 +E0x200")
    vp.MarginX := 0, vp.MarginY := 0
    bg := ""
    try bg := g.BackColor
    vp.BackColor := (bg != "") ? bg : "FFFFFF"
    ; Misma fuente y escala que la ventana principal
    try {
        fs := Round(9 * Min(_PtsUIEscala(), 1.35))
        vp.SetFont("s" fs, "Segoe UI")
    }
    uiV := (x, y, r*) => fnUiP.Call(x - x0, y - yBase, r*)
    ACC := {g: vp, main: g, vp: vp, tab: tab, x0: x0, cw: cw, uiP: uiV, lv: lvEv
          , fitting: false, relaying: false, hStd: 0, paneles: [], actual: 0, pie: 0
          , y0: 0, gap: _AccPx(3), pad: _AccPx(3), scrollY: 0, maxScroll: 0
          , altoTot: 0, altoVis: 0, yBase: yBase, vpGeom: "", vpVis: false}
    vp.OnEvent("ContextMenu", _PtsFondoContextMenu)
    OnMessage(0x0115, _AccOnVScroll)               ; WM_VSCROLL
    OnMessage(0x020A, _AccOnWheel)                 ; WM_MOUSEWHEEL (idempotente si ya estaba registrado)
}
_AccNuevo(id, titulo, yTop, resumen := 0, abiertoDef := true, fijo := false) {
    g := ACC.g
    hdr := g.Add("Text", ACC.uiP.Call(ACC.x0, yTop, ACC.cw, 20) . " +0x200 +0x100", "")
    hdr.SetFont("bold")
    lin := g.Add("Text", ACC.uiP.Call(ACC.x0, yTop + 21, ACC.cw, 2) . " +0x10", "")
    p := {id: id, titulo: titulo, hdr: hdr, line: lin, ctrls: [], dys: [], resumen: resumen
        , abierto: true, altoAbi: 0, altoCerr: 0, lineDy: 0, def: abiertoDef, posFn: 0, altoFn: 0, fijo: fijo}
    hdr.OnEvent("Click", _AccToggle.Bind(id))
    ACC.actual := p
    return p
}
_R(ctrl) {                        ; registra el control en el panel en construcción
    ACC.actual.ctrls.Push(ctrl)
    return ctrl
}
_AccPie(ctrl) {                   ; control que sigue al último panel (stEv)
    ACC.pie := ctrl
    return ctrl
}
_AccFin() {
    p := ACC.actual
    p.hdr.GetPos(, &hy)
    p.line.GetPos(, &ly, , &lh)
    bottom := 0
    for c in p.ctrls {
        c.GetPos(, &cy, , &ch)
        p.dys.Push(cy - hy)
        bottom := Max(bottom, cy - hy + ch)
    }
    p.lineDy := ly - hy
    p.altoCerr := p.lineDy + lh
    p.altoAbi := bottom + ACC.pad
    if (ACC.paneles.Length = 0)
        ACC.y0 := hy
    p.abierto := (IniRead(_PosGuiIniPath(), "PanelesAbiertos", p.id, p.def ? "1" : "0") = "1")
    if (p.fijo)
        p.abierto := true
    ACC.paneles.Push(p)
    ACC.actual := 0
}
_AccPanel(id) {
    for p in ACC.paneles
        if (p.id = id)
            return p
    return 0
}
_AccY0() {
    try {
        ACC.lv.GetPos(, &ly, , &lh)
        return ly + lh + _AccPx(10)
    }
    return ACC.HasProp("yBase") ? ACC.yBase : ACC.y0
}
_AccSbSync() {
    global ACC
    if (!IsObject(ACC) || !ACC.HasProp("vp"))
        return
    si := Buffer(28, 0)
    ; SIF_RANGE|SIF_PAGE|SIF_POS|SIF_DISABLENOSCROLL
    NumPut("UInt", 28, "UInt", 0xF, "Int", 0, "Int", Max(0, Round(ACC.altoTot) - 1)
         , "UInt", Round(ACC.altoVis), "Int", Round(ACC.scrollY), si)
    DllCall("user32\SetScrollInfo", "Ptr", ACC.vp.Hwnd, "Int", 1, "Ptr", si, "Int", true)   ; SB_VERT
}
_AccOnVScroll(wParam, lParam, msg, hwnd) {
    global ACC
    if (!IsSet(ACC) || !IsObject(ACC) || !ACC.HasProp("vp") || hwnd != ACC.vp.Hwnd || lParam != 0)
        return
    pos := ACC.scrollY
    switch (wParam & 0xFFFF) {
        case 0: pos -= _AccPx(18)             ; SB_LINEUP
        case 1: pos += _AccPx(18)             ; SB_LINEDOWN
        case 2: pos -= ACC.altoVis            ; SB_PAGEUP
        case 3: pos += ACC.altoVis            ; SB_PAGEDOWN
        case 4, 5:                            ; THUMBPOSITION / THUMBTRACK
            si := Buffer(28, 0)
            NumPut("UInt", 28, "UInt", 0x10, si)
            DllCall("user32\GetScrollInfo", "Ptr", ACC.vp.Hwnd, "Int", 1, "Ptr", si)
            pos := NumGet(si, 24, "Int")
        case 6: pos := 0
        case 7: pos := ACC.maxScroll
        default: return 0
    }
    ACC.scrollY := Min(ACC.maxScroll, Max(0, Round(pos)))
    _AccRelayout()
    return 0
}
_AccOnWheel(wParam, lParam, msg, hwnd) {
    global ACC
    if (!IsSet(ACC) || !IsObject(ACC) || !ACC.HasProp("vp") || ACC.maxScroll <= 0 || !ACC.vpVis)
        return
    try {
        if (ACC.tab && ACC.tab.Value != 1)
            return
    }
    ; Comprobar si el cursor está sobre el viewport o dentro de su rectángulo de pantalla
    DllCall("user32\GetCursorPos", "Int64*", &pt := 0)
    px := pt & 0xFFFFFFFF, py := pt >> 32
    if (px > 0x7FFFFFFF)
        px -= 0x100000000
    if (py > 0x7FFFFFFF)
        py -= 0x100000000
    
    ; Obtener ventana bajo el cursor
    hUnder := DllCall("user32\WindowFromPoint", "Int64", pt, "Ptr")
    
    ; Permitir si el cursor está en el viewport O si el cursor está en el editor de eventos (g)
    esViewport := (hUnder = ACC.vp.Hwnd || DllCall("user32\IsChild", "Ptr", ACC.vp.Hwnd, "Ptr", hUnder))
    esEditor := (hUnder = ACC.g.Hwnd || DllCall("user32\IsChild", "Ptr", ACC.g.Hwnd, "Ptr", hUnder))
    
    if (!esViewport && !esEditor)
        return
    delta := (wParam >> 16)
    if (delta > 0x7FFF)
        delta -= 0x10000
    paso := _AccPx(36)
    ACC.scrollY := Min(ACC.maxScroll, Max(0, ACC.scrollY - (delta > 0 ? paso : -paso)))
    _AccRelayout()
    return 0
}
_AccFit() {
    ; Anulado: el alto de la ventana lo gobierna solo el evento Size (_PtsLayRedim).
    ; Se conserva el stub para no romper llamadas antiguas.
    return
}
_AccWorkArea(&wt, &wb) {
    global ACC
    hw := (IsSet(ACC) && IsObject(ACC) && ACC.HasProp("main")) ? ACC.main.Hwnd : (ACC.HasProp("g") ? ACC.g.Hwnd : 0)
    if (!hw) {
        wt := 0, wb := A_ScreenHeight
        return
    }
    WinGetPos(&gx, &gy, &gw, &gh, hw)
    cx := gx + gw // 2, cy := gy + 20
    wt := 0, wb := A_ScreenHeight
    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
        if (cx >= l && cx < r && cy >= t && cy < b) {
            wt := t, wb := b
            break
        }
    }
}
_AccDisponible() {
    global ACC
    if (!ACC.tab)
        return 99999
    ACC.tab.GetPos(, &ty, , &th)
    hw := ACC.HasProp("main") ? ACC.main.Hwnd : ACC.g.Hwnd
    WinGetPos(, , , &gh, hw)
    WinGetClientPos(, , , &ch, hw)
    _AccWorkArea(&wt, &wb)
    maxCh := (wb - wt - 12) - (gh - ch)        ; alto cliente máximo
    foot := ch - (ty + th)                      ; franja inferior (estado + botonera)
    return maxCh - foot - _AccPx(8)
}
_AccAltoDe(p) {
    if (!p.abierto)
        return p.altoCerr
    return p.altoFn ? p.altoFn.Call() : p.altoAbi
}
_AccFinPaneles() {
    y := _AccY0()
    for p in ACC.paneles
        y += _AccAltoDe(p) + ACC.gap
    return y + (ACC.pie ? _AccPx(22) : 0)
}
; Si no cabe, cierra de abajo hacia arriba (sin tocar p1 ni prioId). No persiste.
_AccAjustar(prioId := "") {
    lim := _AccDisponible()
    Loop ACC.paneles.Length {
        if (_AccFinPaneles() <= lim)
            return
        p := ACC.paneles[ACC.paneles.Length + 1 - A_Index]
        if (p.abierto && p.id != prioId && p.id != "p1" && !p.fijo)
            p.abierto := false
    }
}
_AccGrupoDef(padre, hijos) {
    global ACC
    if !ACC.HasProp("grupos")
        ACC.grupos := Map()
    for id in hijos
        ACC.grupos[id] := padre
}

_AccPanelOculto(p) {
    global ACC
    if !(ACC.HasProp("grupos") && ACC.grupos.Has(p.id))
        return false
    padre := _AccPanel(ACC.grupos[p.id])
    return IsObject(padre) && !padre.abierto
}

_AccToggle(id, *) {
    p := _AccPanel(id)
    if (!p || p.fijo)
        return
    p.abierto := !p.abierto
    try IniWrite(p.abierto ? 1 : 0, _PosGuiIniPath(), "PanelesAbiertos", id)
    _AccRelayout()
}
_AccPintarCab(p) {
    res := ""
    if (!p.abierto && p.resumen)
        try res := "  ·  " p.resumen.Call()
    p.hdr.Text := (p.abierto ? "▼ " : "▶ ") p.titulo res
}
_AccRefrescarResumen() {
    try _PtsSndRefrescar()     ; sincroniza ③ al cambiar de evento
    try _CompRefrescar()       ; sincroniza ④ al cambiar de evento
    global ACC
    if (!IsObject(ACC))
        return
    for p in ACC.paneles
        if (!p.abierto)
            _AccPintarCab(p)
}
_PtsRectCliente(hCtl, hPar, &x, &y, &w, &h) {
    rc := Buffer(16, 0), pt := Buffer(8, 0)
    DllCall("GetWindowRect", "Ptr", hCtl, "Ptr", rc)
    NumPut("Int", NumGet(rc, 0, "Int"), "Int", NumGet(rc, 4, "Int"), pt)
    DllCall("ScreenToClient", "Ptr", hPar, "Ptr", pt)
    x := NumGet(pt, 0, "Int"), y := NumGet(pt, 4, "Int")
    w := NumGet(rc, 8, "Int") - NumGet(rc, 0, "Int")
    h := NumGet(rc, 12, "Int") - NumGet(rc, 4, "Int")
}

_AccRelayout(*) {
    global ACC
    if (!IsObject(ACC) || !ACC.HasProp("vp") || ACC.paneles.Length = 0)
        return
    vp := ACC.vp
    try {
        if (ACC.tab && ACC.tab.Value != 1) {
            if (ACC.vpVis) {
                DllCall("user32\ShowWindow", "Ptr", vp.Hwnd, "Int", 0)   ; SW_HIDE
                ACC.vpVis := false
            }
            return
        }
    }
    if (ACC.relaying)
        return
    ACC.relaying := true
    redrawOff := false
    try {
        ; 1) Geometría del viewport (anclado al borde cliente real del ListView y del Tab3 en píxeles Win32)
        mainHw := (ACC.HasProp("main") && ACC.main) ? ACC.main.Hwnd : ACC.g.Hwnd
        _PtsRectCliente(ACC.lv.Hwnd, mainHw, &lx, &ly, &lw, &lh)
        _PtsRectCliente(ACC.tab.Hwnd, mainHw, &tx, &ty, &tw, &th)
        gap := _AccPx(30)
        vx := lx, vy := ly + lh + gap, vw := lw
        vh := Max(_AccPx(80), (ty + th - _AccPx(8)) - vy)
        geom := vx "|" vy "|" vw "|" vh
        if (geom != ACC.vpGeom) {
            DllCall("MoveWindow", "Ptr", vp.Hwnd, "Int", vx, "Int", vy, "Int", vw, "Int", vh, "Int", 1)
            ACC.vpGeom := geom
        }
        if (!ACC.vpVis) {
            DllCall("user32\ShowWindow", "Ptr", vp.Hwnd, "Int", 8)                       ; SW_SHOWNA
            DllCall("user32\SetWindowPos", "Ptr", vp.Hwnd, "Ptr", 0, "Int", 0, "Int", 0
                  , "Int", 0, "Int", 0, "UInt", 0x13)                                    ; HWND_TOP, NOMOVE|NOSIZE|NOACTIVATE
            ACC.vpVis := true
        }
        ; 2) Métricas de scroll
        altoTot := 0
        for p in ACC.paneles {
            if _AccPanelOculto(p)
                continue
            altoTot += _AccAltoDe(p) + ACC.gap
        }
        if (ACC.pie)
            altoTot += _AccPx(24)
        altoTot += _AccPx(60)                                                             ; margen inferior reducido (las alturas de bloque ahora son reales, ver _CompAlto)
        ACC.altoTot := altoTot
        ACC.altoVis := vh
        ACC.maxScroll := Max(0, altoTot - vh)
        ACC.scrollY := Min(Max(0, ACC.scrollY), ACC.maxScroll)
        ; 3) Reubicar contenido DENTRO del viewport, sin pintar hasta terminar
        SendMessage(0x000B, 0, 0, vp.Hwnd)                                               ; WM_SETREDRAW off
        redrawOff := true
        y := -ACC.scrollY
        for p in ACC.paneles {
            if _AccPanelOculto(p) {
                p.hdr.Visible := false
                p.line.Visible := false
                for c in p.ctrls
                    c.Visible := false
                continue
            }
            pH := _AccAltoDe(p)
            p.hdr.Move(, y)
            p.line.Move(, y + p.lineDy)
            p.hdr.Visible := true
            p.line.Visible := true
            if (p.fijo)
                p.hdr.Visible := false
            if (p.posFn && p.abierto) {
                p.posFn.Call(y, -100000, 100000)       ; sin culling: el viewport recorta
            } else {
                for i, c in p.ctrls {
                    if (p.abierto && !p.posFn) {
                        c.Move(, y + p.dys[i])
                        c.Visible := true
                    } else
                        c.Visible := false
                }
            }
            _AccPintarCab(p)
            y += pH + ACC.gap
        }
        if (ACC.pie) {
            ACC.pie.Move(, y)
            ACC.pie.Visible := true
        }
    } finally {
        ACC.relaying := false
        if (redrawOff) {
            SendMessage(0x000B, 1, 0, vp.Hwnd)                                           ; WM_SETREDRAW on
            _AccSbSync()
            ; 0x485 = INVALIDATE|ERASE|ALLCHILDREN|FRAME (sin UPDATENOW: repintado diferido y fusionado)
            DllCall("user32\RedrawWindow", "Ptr", vp.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x485)
        }
    }
}
_AccResumen1() {
    try {
        a := Trim(ptsEd.edAtajo.Value), r := Trim(ptsEd.edRemap.Value)
        return (a = "" ? "—" : a) " → " (r = "" ? "—" : r)
    }
    return ""
}
_AccResumen2() {
    try {
        return ptsEd.ddF.Text " · " ptsEd.ddZ.Text " · " ptsEd.ddOp.Text
    }
    return ""
}
_AccResumen3() {
    try {
        t := []
        if (ptsEd.cbPill.Value)
            t.Push("Píldora Táctil")
        if (ptsEd.cbHover.Value)
            t.Push("Hover")
        if (ptsEd.cbAuto.Value)
            t.Push("Gatillo")
        s := ""
        for x in t
            s .= (s = "" ? "" : " · ") x
        return (s = "") ? "ninguna" : s
    }
    return ""
}

_PtsNomEvento(idEv) {
    global PERFIL
    try {
        txt := IniRead(_PosGuiIniPath(), "HudTextos" PERFIL, "texto_" idEv, "")
        if (txt != "")
            return txt
    }
    for ev in _PtsEventosDefs() {
        if (ev[1] = idEv)
            return ev[2]
    }
    return idEv
}
_PtsEvTextoGuardar(*) {
    global PERFIL
    filas := _PtsEvObtenerSeleccionados(ptsEd.lvEv)
    row := (filas.Length > 0) ? filas[1] : ptsEd.evSel
    if (row < 1 || !ptsEd.mapFilas.Has(row))
        return
    idxReal := ptsEd.mapFilas[row]
    ev := _PtsEventosDefs()[idxReal]
    idEv := ev[1]
    nuevoTxt := Trim(ptsEd.eTxtEv.Value)
    if (nuevoTxt = "")
        nuevoTxt := ev[2]
    IniWrite(nuevoTxt, _PosGuiIniPath(), "HudTextos" PERFIL, "texto_" idEv)
    _PtsEvFilas()
    if (ptsEd.evAnclado)
        _PtsMostrarGuiAnclado(row)
    _SonarUI("calib")
    ptsEd.st.Value := "Texto guardado para '" idEv "': " nuevoTxt
}
_PtsEvTextoReset(*) {
    global PERFIL
    filas := _PtsEvObtenerSeleccionados(ptsEd.lvEv)
    row := (filas.Length > 0) ? filas[1] : ptsEd.evSel
    if (row < 1 || !ptsEd.mapFilas.Has(row))
        return
    idxReal := ptsEd.mapFilas[row]
    ev := _PtsEventosDefs()[idxReal]
    idEv := ev[1]
    try IniDelete(_PosGuiIniPath(), "HudTextos" PERFIL, "texto_" idEv)
    ptsEd.eTxtEv.Value := ev[2]
    _PtsEvFilas()
    if (ptsEd.evAnclado)
        _PtsMostrarGuiAnclado(row)
    _SonarUI("calib")
    ptsEd.st.Value := "Texto restaurado al original: " ev[2]
}
_PtsEvLeer() {
    ptsEd.cfg := Map()
    for ev in _PtsEventosDefs() {
        c := HudConfigEvento(ev[1])
        ptsEd.cfg[ev[1]] := {f:c.formato,z:c.zona,op:c.opacidad}
        _PtsEvActivoLeer(ev[1])
    }
}

; --- P3a: estado Activo/Inactivo por evento (clave activo_<slug>, por defecto 1) ---
_PtsEvActivoLeer(k) {
    global ptsEd, PERFIL
    if (!HasProp(ptsEd, "act") || !IsObject(ptsEd.act))
        ptsEd.act := Map()
    ptsEd.act[k] := (IniRead(_PosGuiIniPath(), "HudEventos" PERFIL, "activo_" k, "1") != "0")
    return ptsEd.act[k]
}

_PtsEvActivo(k) {
    global ptsEd
    if (HasProp(ptsEd, "act") && IsObject(ptsEd.act) && ptsEd.act.Has(k))
        return ptsEd.act[k]
    return _PtsEvActivoLeer(k)
}

_PtsEvActivoSet(k, on) {
    global ptsEd, PERFIL
    IniWrite(on ? "1" : "0", _PosGuiIniPath(), "HudEventos" PERFIL, "activo_" k)
    if (!HasProp(ptsEd, "act") || !IsObject(ptsEd.act))
        ptsEd.act := Map()
    ptsEd.act[k] := on ? true : false
}

_PtsEvFormatoTxt(k, c) {
    txt := (c.f = "desactivado") ? "🔴 OFF" : StrTitle(c.f)
    return _PtsEvActivo(k) ? txt : "⏸ " txt
}

_PtsEvSlugFila(fila) {
    global ptsEd
    if (!fila || !HasProp(ptsEd, "mapFilas") || !ptsEd.mapFilas.Has(fila))
        return ""
    return _PtsEventosDefs()[ptsEd.mapFilas[fila]][1]
}

; Sincroniza p1ddEstado con la selección: 1=Activo, 2=Inactivo, sin selección visible si hay mezcla
_PtsEvSyncEstado(ctrl) {
    global ptsEd
    if (!HasProp(ptsEd, "p1ddEstado"))
        return
    n := 0, act := 0, ina := 0, fila := 0
    while (fila := ctrl.GetNext(fila)) {
        slug := _PtsEvSlugFila(fila)
        if (slug = "")
            continue
        n += 1
        if (_PtsEvActivo(slug))
            act += 1
        else
            ina += 1
    }
    ptsEd.p1Sync := true
    ptsEd.p1ddEstado.Enabled := (n > 0)
    ptsEd.p1ddEstado.Choose(n = 0 ? 1 : (ina = 0 ? 1 : (act = 0 ? 2 : 0)))
    ptsEd.p1Sync := false
}

_PtsEvEstadoCambio(ctrl, *) {
    global ptsEd
    if (HasProp(ptsEd, "p1Sync") && ptsEd.p1Sync)
        return
    v := ctrl.Value
    if (v < 1)
        return
    lv := ptsEd.lvEv
    fila := 0
    while (fila := lv.GetNext(fila)) {
        slug := _PtsEvSlugFila(fila)
        if (slug = "")
            continue
        _PtsEvActivoSet(slug, v = 1)
        lv.Modify(fila, "Col6", _PtsEvFormatoTxt(slug, ptsEd.cfg[slug]))
    }
    DllCall("InvalidateRect", "Ptr", lv.Hwnd, "Ptr", 0, "Int", 1)
}

; --- P3b: vista agrupada nativa (LVM_*GROUP*) sobre lvEv ---
_PtsEvAgruparOn() {
    global ptsEd
    if (!HasProp(ptsEd, "agrupar"))
        ptsEd.agrupar := (IniRead(_PosGuiIniPath(), "CalibradorUI", "agrupar_eventos", "1") != "0")
    return ptsEd.agrupar
}

_PtsEvToggleAgrupar(*) {
    global ptsEd
    ptsEd.agrupar := !_PtsEvAgruparOn()
    IniWrite(ptsEd.agrupar ? "1" : "0", _PosGuiIniPath(), "CalibradorUI", "agrupar_eventos")
    _PtsEvFilas()
}

_PtsEvGrupoInsertar(nom) {
    global ptsEd
    lv := ptsEd.lvEv
    id := ptsEd.grpIds.Count + 1
    cb := (A_PtrSize = 8) ? 56 : 40                        ; LVGROUP base (sin campos Vista)
    buf := Buffer(cb, 0)
    NumPut("UInt", cb, buf, 0)
    NumPut("UInt", 0x15, buf, 4)                           ; LVGF_HEADER | LVGF_STATE | LVGF_GROUPID
    NumPut("Ptr", StrPtr(nom), buf, 8)
    NumPut("Int", StrLen(nom), buf, A_PtrSize = 8 ? 16 : 12)
    NumPut("Int", id, buf, A_PtrSize = 8 ? 36 : 24)
    NumPut("UInt", 0x9, buf, A_PtrSize = 8 ? 40 : 28)      ; stateMask: COLLAPSIBLE | COLLAPSED
    col := (ptsEd.grpCol.Has(nom) && ptsEd.grpCol[nom]) ? 1 : 0
    NumPut("UInt", 0x8 | col, buf, A_PtrSize = 8 ? 44 : 32)
    DllCall("SendMessageW", "Ptr", lv.Hwnd, "UInt", 0x1091, "Ptr", -1, "Ptr", buf)   ; LVM_INSERTGROUP al final
    ptsEd.grpIds[nom] := id
}

_PtsEvGruposPreparar(defs) {
    global ptsEd
    lv := ptsEd.lvEv
    if (!HasProp(ptsEd, "grpCol") || !IsObject(ptsEd.grpCol))
        ptsEd.grpCol := Map()
    ; recordar qué grupos estaban plegados antes de reconstruir
    if (HasProp(ptsEd, "grpIds") && IsObject(ptsEd.grpIds)) {
        for nom, id in ptsEd.grpIds
            ptsEd.grpCol[nom] := (DllCall("SendMessageW", "Ptr", lv.Hwnd, "UInt", 0x105C, "Ptr", id, "Ptr", 0x1) & 1) ? true : false   ; LVM_GETGROUPSTATE
    }
    ptsEd.grpIds := Map()
    DllCall("SendMessageW", "Ptr", lv.Hwnd, "UInt", 0x10A0, "Ptr", 0, "Ptr", 0)             ; LVM_REMOVEALLGROUPS
    on := _PtsEvAgruparOn()
    DllCall("SendMessageW", "Ptr", lv.Hwnd, "UInt", 0x109D, "Ptr", on ? 1 : 0, "Ptr", 0)    ; LVM_ENABLEGROUPVIEW
    if (!on)
        return
    for ev in defs {
        nom := (ev.Length >= 3) ? ev[3] : "General"
        if (!ptsEd.grpIds.Has(nom))
            _PtsEvGrupoInsertar(nom)
    }
}

_PtsEvAsignaGrupo(nf, grp) {
    global ptsEd
    if (!_PtsEvAgruparOn() || !HasProp(ptsEd, "grpIds"))
        return
    if (!ptsEd.grpIds.Has(grp))
        _PtsEvGrupoInsertar(grp)
    buf := Buffer(96, 0)
    NumPut("UInt", 0x100, buf, 0)                          ; mask = LVIF_GROUPID
    NumPut("Int", nf - 1, buf, 4)                          ; iItem (0-based)
    NumPut("Int", ptsEd.grpIds[grp], buf, A_PtrSize = 8 ? 52 : 40)   ; iGroupId
    DllCall("SendMessageW", "Ptr", ptsEd.lvEv.Hwnd, "UInt", 0x104C, "Ptr", 0, "Ptr", buf)   ; LVM_SETITEMW
}

_PtsEvGuardar(k,f,z,op) {
    global PERFIL
    ini := _PosGuiIniPath()
    sec := "HudEventos" PERFIL
    IniWrite(f,ini,sec,"formato_" k)
    IniWrite(z,ini,sec,"zona_" k)
    IniWrite(op,ini,sec,"opacidad_" k)
    ptsEd.cfg[k] := {f:f,z:z,op:op}
    _PtsEvLimpiarPend(k)
}
_PtsEvAtajoDefault(idEv) {
    static m := Map(
        "pluma", "Q", "aerografo", "W", "aerografo_alpha", "k", "pincel_suave", "Y",
        "pincel_duro", "F6", "difu_mixer", "Ñ", "opc_presion", "<", "borrador", "E",
        "borrador_suave", "L", "borrador_lazo", "F12", "smudge", "P", "smear", "B",
        "smear_soft", "NumpadEnd", "color_mix", "D", "color_primario", "Q", "color_secundario", "Ctrl+2",
        "relleno", "V", "area_color", "Ctrl+X", "lazo", "S", "deseleccion", "X", "reseleccion", "F10",
        "inv_seleccion", "C", "shift_sostenido", "Shift", "flip_horizontal", "Alt+G",
        "rotar_lienzo", "R", "zoom_lienzo", "Z", "regla_ocultar", "Alt+T", "capa_visibilidad", "Shift+D",
        "guardar", "Ctrl+S", "deshacer", "Ctrl+Z", "rehacer", "Ctrl+Y", "copiar", "Ctrl+C", "enfoque", "Tab",
        "history_lock", "—", "panel_ds", "—", "panel_cc", "—", "gui_frente", "—",
        "estab_slider", "—", "layout", "—", "reload", "^!+r"
    )
    return m.Has(idEv) ? m[idEv] : "—"
}

_PtsEvRemapDefault(idEv) {
    static m := Map(
        "pluma", "Q", "aerografo", "W", "aerografo_alpha", "W²", "pincel_suave", "Alt+Q",
        "pincel_duro", "RButton + Q", "difu_mixer", "RButton + W", "opc_presion", "Alt+W", "borrador", "E",
        "borrador_suave", "E²", "borrador_lazo", "RButton + E", "smudge", "Alt + X²",
        "smear", "Alt + F", "smear_soft", "Alt + F²", "color_mix", "Alt + X",
        "color_primario", "Q²", "color_secundario", "Q²", "relleno", "RButton + 1",
        "area_color", "S²", "lazo", "S", "deseleccion", "X (toggle 0)", "reseleccion", "X (toggle 1)",
        "inv_seleccion", "Space + RButton", "shift_sostenido", "RButton + F", "flip_horizontal", "Space + Alt+B",
        "rotar_lienzo", "Z²", "zoom_lienzo", "Z", "regla_ocultar", "RButton + T",
        "capa_visibilidad", "Space + E", "guardar", "Ctrl+S", "deshacer", "Ctrl+Z", "rehacer", "Ctrl+Y",
        "copiar", "Ctrl+C", "enfoque", "Tab / F3", "history_lock", "Píldora lock", "panel_ds", "Píldora ds / Hover",
        "panel_cc", "Píldora cc / Hover", "gui_frente", "Píldora frente", "estab_slider", "Slider estab",
        "layout", "Menú Companion", "reload", "Píldora reload"
    )
    return m.Has(idEv) ? m[idEv] : "—"
}

_PtsEvCaps(idEv) {
    if (idEv != "" && _PtsEvEsCustom(_PosGuiIniPath(), idEv)) {
        return {
            pildora:  true,
            hover:    true,
            cruzar:   true,
            auto:     true,
            toggle:   true,
            quick:    true,
            slider:   true,
            ventanas: true
        }
    }
    static pildoras := Map("history_lock",1, "panel_ds",1, "panel_cc",1, "gui_frente",1, "estab_slider",1, "reload",1)
    static hovers   := Map("history_lock",1, "panel_ds",1, "panel_cc",1, "shift_sostenido",1)
    static cruzars  := Map("panel_ds",1, "panel_cc",1, "history_lock",1)
    static autos    := Map("panel_ds",1, "panel_cc",1, "history_lock",1)
    static toggles  := Map("gui_frente",1, "estab_slider",1, "panel_ds",1, "panel_cc",1, "enfoque",1)
    static quickpr  := Map("shift_sostenido",1, "history_lock",1, "enfoque",1)
    static sliders  := Map("estab_slider",1)
    return {
        pildora:  pildoras.Has(idEv),
        hover:    hovers.Has(idEv),
        cruzar:   cruzars.Has(idEv),
        auto:     autos.Has(idEv),
        toggle:   toggles.Has(idEv),
        quick:    quickpr.Has(idEv),
        slider:   sliders.Has(idEv),
        ventanas: true
    }
}

_PtsEvResumen(idEv, c) {
    res := []
    if (c.f != "desactivado")
        res.Push("HUD")
    caps := _PtsEvCaps(idEv)
    ini := _PosGuiIniPath()
    sec := "Particularidades"
    esCust := (idEv != "" && _PtsEvEsCustom(ini, idEv))
    p := IniRead(ini, sec, "pildora_" idEv, (esCust || !caps.pildora) ? "0" : "1")
    h := IniRead(ini, sec, "hover_" idEv, (esCust || !caps.hover) ? "0" : "1")
    cr := IniRead(ini, sec, "cruzar_" idEv, "0")
    a := IniRead(ini, sec, "auto_" idEv, "0")
    if (caps.pildora && p = "1")
        res.Push("Píldora")
    if (caps.hover && h = "1")
        res.Push("Hover")
    if (caps.cruzar && cr = "1")
        res.Push("Cruce")
    if (caps.auto && a = "1")
        res.Push("Auto-clic")
    q := IniRead(ini, sec, "quick_" idEv, "0")
    t := IniRead(ini, sec, "toggle_" idEv, "0")
    sl := IniRead(ini, sec, "slider_" idEv, "0")
    if (caps.quick && q = "1")
        res.Push("Rápida")
    if (caps.toggle && t = "1")
        res.Push("Alternador")
    if (caps.slider && sl = "1")
        res.Push("Slider")
    s := ""
    for r in res
        s .= (s ? " " : "") . "[" r "]"
    return s ? s : "—"
}

_PtsEvRemapGuardar(*) {
    if (!ptsEd.evSel || !ptsEd.mapFilas.Has(ptsEd.evSel))
        return
    idEv := _PtsEventosDefs()[ptsEd.mapFilas[ptsEd.evSel]][1]
    ini := _PosGuiIniPath()
    sec := "Remapeos"
    IniWrite(Trim(ptsEd.edAtajo.Value), ini, sec, "atajo_" idEv)
    IniWrite(Trim(ptsEd.edRemap.Value), ini, sec, "remap_" idEv)
    try _RemapCargarHotkeys()
    _PtsEvFilas()
    _PtsEvLimpiarPend(idEv)
    _SonarUI("calib")
    ptsEd.st.Value := "Atajo y remapeo guardados para '" idEv "'."
}

_PtsEvRemapReset(*) {
    if (!ptsEd.evSel || !ptsEd.mapFilas.Has(ptsEd.evSel))
        return
    idEv := _PtsEventosDefs()[ptsEd.mapFilas[ptsEd.evSel]][1]
    ini := _PosGuiIniPath()
    sec := "Remapeos"
    try IniDelete(ini, sec, "atajo_" idEv)
    try IniDelete(ini, sec, "remap_" idEv)
    ptsEd.edAtajo.Value := _PtsEvAtajoDefault(idEv)
    ptsEd.edRemap.Value := _PtsEvRemapDefault(idEv)
    _PtsEvFilas()
    _SonarUI("calib")
    ptsEd.st.Value := "Atajo y remapeo restaurados por defecto para '" idEv "'."
}

; Exclusión mutua cruzar ⇄ auto: al activar uno, el otro se apaga (INI + checkbox + tarjeta).
_PtsExcluirCruzarAuto(tipo, idEv) {
    global COMP
    otro := (tipo = "cruzar") ? "auto" : "cruzar"
    ini := _PosGuiIniPath()
    sec := "Particularidades"
    if (IniRead(ini, sec, otro "_" idEv, "0") = "1")
        IniWrite("0", ini, sec, otro "_" idEv)
    try (otro = "auto" ? ptsEd.cbAuto : ptsEd.cbCruzar).Value := 0
    if (IsSet(COMP) && IsObject(COMP) && COMP.HasProp("abierta") && COMP.abierta = otro)
        COMP.abierta := tipo        ; la tarjeta del apagado cede su lugar a la activada
}

_PtsEvPartToggle(tipo, ctrl, *) {
    ; ===== INICIO P1 =====
    if (tipo = "cruzar" || tipo = "auto") && (ctrl.Value = 1) {
        _PtsExcluirOpuesto(tipo, _PtsEvIdSel())
        SetTimer(_EspacialCargar, -60)        ; refresca la caché RAM tras escribir el flag propio
    }
    if (tipo = "pildora") && HasProp(ptsEd, "bPildora")
        ptsEd.bPildora.Enabled := (ctrl.Value = 1)
    ; ===== FIN P1 =====
    if (!ptsEd.evSel || !ptsEd.mapFilas.Has(ptsEd.evSel))
        return
    idEv := _PtsEventosDefs()[ptsEd.mapFilas[ptsEd.evSel]][1]
    ini := _PosGuiIniPath()
    sec := "Particularidades"
    val := ctrl.Value ? "1" : "0"
    IniWrite(val, ini, sec, tipo "_" idEv)
    if (val = "1" && (tipo = "cruzar" || tipo = "auto"))
        _PtsExcluirCruzarAuto(tipo, idEv)
    _PtsEvFilas()
    _PtsEvLimpiarPend(idEv)
    if (tipo = "pildora")
        _PillSincronizarDinamicas()
    try _EspacialCargar()
    _SonarUI("calib")
    _AccRefrescarResumen()
    ptsEd.st.Value := "Particularidad '" tipo "' actualizada para '" idEv "'."
}

_PtsEvFilas() {
    global ptsPend
    defs := _PtsEventosDefs()
    selIds := []
    for row in _PtsEvObtenerSeleccionados(ptsEd.lvEv) {
        if (ptsEd.mapFilas.Has(row)) {
            idx := ptsEd.mapFilas[row]
            if (IsInteger(idx) && idx >= 1 && idx <= defs.Length) {
                item := defs[idx]
                if (IsObject(item) && item.Length >= 1)
                    selIds.Push(item[1])
            }
        }
    }
    ptsEd.lvEv.Delete()
    ptsEd.mapFilas := []
    filtroGrupo := (IsObject(ptsEd.ddGrupo) && ptsEd.ddGrupo.Value > 1) ? ptsEd.ddGrupo.Text : ""
    _PtsEvGruposPreparar(defs)
    ptsPend := Map()
    iniP := _PosGuiIniPath()
    for i, ev in defs {
        if (IniRead(iniP, "EventosPendientes", ev[1], "0") = "1")
            ptsPend[ev[1]] := true
    }
    orden := []
    for i, ev in defs {
        if (!ptsPend.Has(ev[1]) && ptsEd.cfg[ev[1]].f != "desactivado")
            orden.Push(i)
    }
    for i, ev in defs {
        if (!ptsPend.Has(ev[1]) && ptsEd.cfg[ev[1]].f = "desactivado")
            orden.Push(i)
    }
    for i, ev in defs {
        if (ptsPend.Has(ev[1]))
            orden.Push(i)
    }
    ini := _PosGuiIniPath()
    secRem := "Remapeos"
    pausados := _PtsEvPausadosMapa()
    for i in orden {
        ev := defs[i]
        grp := (ev.Length >= 3) ? ev[3] : "General"
        if (filtroGrupo != "" && grp != filtroGrupo)
            continue
        c := ptsEd.cfg[ev[1]]
        propia := _PtsDurPropia(ev[1])
        durTxt := (propia != "") ? propia " ms" : "(" _PtsDurEfectiva(ev[1],c.z) ")"
        nomEv := _PtsNomEvento(ev[1])
        if !_PtsEvFiltroOk(nomEv, grp)
            continue
        ptsEd.mapFilas.Push(i)
        nomShow := pausados.Has(ev[1]) ? "⏸ " nomEv : nomEv
        formatoTxt := _PtsEvFormatoTxt(ev[1], c)
        atajoCol := IniRead(ini, secRem, "atajo_" ev[1], _PtsEvAtajoDefault(ev[1]))
        remapCol := IniRead(ini, secRem, "remap_" ev[1], _PtsEvRemapDefault(ev[1]))
        partCol := _PtsEvResumen(ev[1], c)
        nf := ptsEd.lvEv.Add("", nomShow, atajoCol, remapCol, partCol, grp, formatoTxt, _PtsZonaTxt(c.z), c.op "%", durTxt)
        _PtsEvAsignaGrupo(nf, grp)
    }
    primera := 0
    for row, idxReal in ptsEd.mapFilas {
        if (idxReal < 1 || idxReal > defs.Length)
            continue
        evItem := defs[idxReal]
        if (!IsObject(evItem) || evItem.Length < 1)
            continue
        for sid in selIds {
            if (sid = evItem[1]) {
                ptsEd.lvEv.Modify(row,(primera = 0) ? "Select Focus Vis" : "Select")
                if (primera = 0)
                    primera := row
                break
            }
        }
    }
    if (primera > 0)
        ptsEd.evSel := primera
}
_PtsEvObtenerSeleccionados(lv) {
    filas := []
    row := 0
    Loop {
        row := lv.GetNext(row)
        if (!row)
            break
        filas.Push(row)
    }
    return filas
}
_PtsEvSel(ctrl,item,selected) {
    if (!selected || item < 1 || !ptsEd.mapFilas.Has(item))
        return
    ptsEd.evSel := item
    idxReal := ptsEd.mapFilas[item]
    idEv := _PtsEventosDefs()[idxReal][1]
    if (IsObject(ptsEd) && HasProp(ptsEd, "eTxtEv") && IsObject(ptsEd.eTxtEv))
        ptsEd.eTxtEv.Value := _PtsNomEvento(idEv)
    ini := _PosGuiIniPath()
    secRem := "Remapeos"
    secPart := "Particularidades"
    atajoVal := IniRead(ini, secRem, "atajo_" idEv, _PtsEvAtajoDefault(idEv))
    remapVal := IniRead(ini, secRem, "remap_" idEv, _PtsEvRemapDefault(idEv))
    if (HasProp(ptsEd, "edAtajo") && IsObject(ptsEd.edAtajo))
        ptsEd.edAtajo.Value := (atajoVal = "—") ? "" : atajoVal
    if (HasProp(ptsEd, "edRemap") && IsObject(ptsEd.edRemap))
        ptsEd.edRemap.Value := (remapVal = "—") ? "" : remapVal
    caps := _PtsEvCaps(idEv)
    esCust := (idEv != "" && _PtsEvEsCustom(ini, idEv))
    if (HasProp(ptsEd, "cbPill") && IsObject(ptsEd.cbPill)) {
        ptsEd.cbPill.Enabled := caps.pildora
        ptsEd.cbPill.Value := caps.pildora ? (IniRead(ini, secPart, "pildora_" idEv, (esCust || !caps.pildora) ? "0" : "1") = "1") : 0
    }
    if HasProp(ptsEd, "bPildora")
        ptsEd.bPildora.Enabled := (HasProp(ptsEd, "cbPill") && IsObject(ptsEd.cbPill) && ptsEd.cbPill.Value = 1)
    if (HasProp(ptsEd, "cbHover") && IsObject(ptsEd.cbHover)) {
        ptsEd.cbHover.Enabled := caps.hover
        ptsEd.cbHover.Value := caps.hover ? (IniRead(ini, secPart, "hover_" idEv, (esCust || !caps.hover) ? "0" : "1") = "1") : 0
    }
    if (HasProp(ptsEd, "cbCruzar") && IsObject(ptsEd.cbCruzar)) {
        ptsEd.cbCruzar.Enabled := caps.cruzar
        ptsEd.cbCruzar.Value := caps.cruzar ? (IniRead(ini, secPart, "cruzar_" idEv, "0") = "1") : 0
    }
    if (HasProp(ptsEd, "cbAuto") && IsObject(ptsEd.cbAuto)) {
        ptsEd.cbAuto.Enabled := caps.auto
        ptsEd.cbAuto.Value := caps.auto ? (IniRead(ini, secPart, "auto_" idEv, "0") = "1") : 0
    }
    if (HasProp(ptsEd, "cbQuick") && IsObject(ptsEd.cbQuick)) {
        ptsEd.cbQuick.Enabled := caps.quick
        ptsEd.cbQuick.Value := caps.quick ? (IniRead(ini, secPart, "quick_" idEv, "0") = "1") : 0
    }
    if (HasProp(ptsEd, "cbToggle") && IsObject(ptsEd.cbToggle)) {
        ptsEd.cbToggle.Enabled := caps.toggle
        ptsEd.cbToggle.Value := caps.toggle ? (IniRead(ini, secPart, "toggle_" idEv, "0") = "1") : 0
    }
    if (HasProp(ptsEd, "cbSlider") && IsObject(ptsEd.cbSlider)) {
        ptsEd.cbSlider.Enabled := caps.slider
        ptsEd.cbSlider.Value := caps.slider ? (IniRead(ini, secPart, "slider_" idEv, "0") = "1") : 0
    }
    _CompCargarCampos(idEv)
    filas := _PtsEvObtenerSeleccionados(ctrl)
    if (filas.Length > 1) {
        ptsEd.st.Value := filas.Length " eventos seleccionados. Cambia formato, prioridad u opacidad para aplicarlo a todos."
        _PtsEvDurRefrescar()
        _AccRefrescarResumen()
        return
    }
    c := ptsEd.cfg[_PtsEventosDefs()[idxReal][1]]
    ptsEd.ddF.Choose((c.f = "desactivado") ? 3 : ((c.f = "bruto") ? 2 : 1))
    ptsEd.ddZ.Choose((c.z = "alta") ? 1 : ((c.z = "media") ? 2 : 3))
    opIdx := (c.op = 100) ? 1 : ((c.op = 40) ? 3 : 2)
    ptsEd.ddOp.Choose(opIdx)
    _PtsEvDurRefrescar()
    _AccRefrescarResumen()
    if (ptsEd.evAnclado)
        _PtsMostrarGuiAnclado(item)
}
_PtsEvCambio(*) {
    filas := _PtsEvObtenerSeleccionados(ptsEd.lvEv)
    if (filas.Length = 0 && ptsEd.evSel >= 1)
        filas := [ptsEd.evSel]
    if (filas.Length = 0)
        return
    f := (ptsEd.ddF.Value = 3) ? "desactivado" : ((ptsEd.ddF.Value = 2) ? "bruto" : "moderno")
    z := ["alta","media","baja"][Max(1,ptsEd.ddZ.Value)]
    op := [100,70,40][Max(1,ptsEd.ddOp.Value)]
    defs := _PtsEventosDefs()
    evNom := ""
    for row in filas {
        if (ptsEd.mapFilas.Has(row)) {
            idxReal := ptsEd.mapFilas[row]
            ev := defs[idxReal]
            _PtsEvGuardar(ev[1],f,z,op)
            if (evNom = "")
                evNom := ev[2]
        }
    }
    _PtsEvFilas()
    _PtsEvDurRefrescar()
    if (filas.Length = 1 && evNom != "") {
        ptsEd.st.Value := evNom ": " StrTitle(f) " · " _PtsZonaTxt(z) " (" op "%)"
    } else {
        ptsEd.st.Value := filas.Length " eventos actualizados en conjunto: " StrTitle(f) " · " _PtsZonaTxt(z) " (" op "%)"
    }
}
_PtsEvProbar(*) {
    filas := _PtsEvObtenerSeleccionados(ptsEd.lvEv)
    row := (filas.Length > 0) ? filas[1] : ptsEd.evSel
    if (row < 1 || !ptsEd.mapFilas.Has(row))
        return
    idxReal := ptsEd.mapFilas[row]
    ev := _PtsEventosDefs()[idxReal]
    c := ptsEd.cfg[ev[1]]
    zNum := (c.z = "alta") ? 1 : ((c.z = "media") ? 2 : 3)
    tit := Trim(RegExReplace(ev[2],"\s*\(.*\)\s*$"))
    durPrueba := 1800                             ; Al menos 1.8 s para ver claramente donde caen los eventos
    colAcento := (ev[1] = "color_primario") ? "00E5FF" : ((zNum = 1) ? "FF6F61" : ((zNum = 2) ? "00E5FF" : "9A7BFF"))
    formatoPrueba := (c.f = "desactivado") ? "moderno" : c.f
    MostrarAvisoUI(formatoPrueba, tit, (zNum = 3 ? "" : "PRUEBA"), zNum, colAcento, durPrueba, c.op)
    _SonarFast(ev[1])
}
_PtsOcultarGuiAnclado() {
    if (IsObject(ptsEd) && HasProp(ptsEd, "guiAncladoTxt") && IsObject(ptsEd.guiAncladoTxt)) {
        try ptsEd.guiAncladoTxt.Destroy()
        ptsEd.guiAncladoTxt := 0
    }
    if (IsObject(ptsEd) && HasProp(ptsEd, "guiAnclado") && IsObject(ptsEd.guiAnclado)) {
        try ptsEd.guiAnclado.Destroy()
        ptsEd.guiAnclado := 0
    }
    if (IsObject(ptsEd) && HasProp(ptsEd, "evAnclado")) {
        ptsEd.evAnclado := false
        if (HasProp(ptsEd, "bEvAnclar") && IsObject(ptsEd.bEvAnclar))
            ptsEd.bEvAnclar.Text := "📌"
        if (HasProp(ptsEd, "bEvReub") && IsObject(ptsEd.bEvReub))
            ptsEd.bEvReub.Enabled := false
    }
}

_PtsMostrarGuiAnclado(row) {
    global AVISO_ESC
    if (row < 1 || !ptsEd.mapFilas.Has(row))
        return false
    idxReal := ptsEd.mapFilas[row]
    ev := _PtsEventosDefs()[idxReal]
    c := ptsEd.cfg[ev[1]]
    if (c.f = "desactivado") {
        ptsEd.st.Value := "El evento '" ev[2] "' está en formato Desactivado (sin HUD). Cámbialo a Moderno o Bruto para anclar."
        return false
    }
    zNum := (c.z = "alta") ? 1 : ((c.z = "media") ? 2 : 3)
    tit := Trim(RegExReplace(_PtsNomEvento(ev[1]),"\s*\(.*\)\s*$"))
    colAcento := (ev[1] = "color_primario") ? "00E5FF" : ((zNum = 1) ? "FF6F61" : ((zNum = 2) ? "00E5FF" : "9A7BFF"))
    claveRango := (zNum = 1) ? "HUD_Alta" : ((zNum = 2) ? "HUD_Media" : "HUD_Baja")

    ; Limpieza previa de ambas capas
    if (HasProp(ptsEd, "guiAncladoTxt") && IsObject(ptsEd.guiAncladoTxt)) {
        try ptsEd.guiAncladoTxt.Destroy()
        ptsEd.guiAncladoTxt := 0
    }
    if (HasProp(ptsEd, "guiAnclado") && IsObject(ptsEd.guiAnclado)) {
        try ptsEd.guiAnclado.Destroy()
        ptsEd.guiAnclado := 0
    }

    w := Round(240 * AVISO_ESC)
    h := Round(72  * AVISO_ESC)
    px := "", py := ""
    ; Rango individual del evento manda por sobre la zona genérica
    rgEv := _HudRangoEv(ev[1])
    if (IsObject(rgEv) && IsInteger(rgEv.w) && IsInteger(rgEv.h) && rgEv.w >= 40 && rgEv.h >= 20) {
        w := Round(rgEv.w), h := Round(rgEv.h)
        px := Round(rgEv.x), py := Round(rgEv.y)
    } else {
        rg := ObtenerRango(claveRango)
        if (IsObject(rg) && IsInteger(rg.w) && IsInteger(rg.h) && rg.w >= 40 && rg.h >= 20) {
            w := Round(rg.w), h := Round(rg.h)
            px := Round(rg.x), py := Round(rg.y)
        }
    }
    if (px = "" || py = "") {
        p := _CalcularPosicionZona(zNum, w, h)
        px := p.x, py := p.y
    }

    ; g = fondo/decoración translúcida · gt = texto opaco encima
    g  := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale", "HUD_Anclado_Calibrador")
    gt := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale", "HUD_Anclado_Calibrador_Txt")
    gt.MarginX := 0
    gt.MarginY := 0

    if (c.f = "bruto") {
        g.BackColor := "1A1A1A"
        g.MarginX := 0
        g.MarginY := 0
        alpha := (c.op <= 40) ? 102 : ((c.op <= 70) ? 178 : 235)
        WinSetTransparent(alpha, g)
        barH := Max(2, Round(3 * AVISO_ESC))
        lblY := Round(4 * AVISO_ESC)
        lblH := Max(16, h - barH - lblY - Round(3 * AVISO_ESC))
        fSize := Max(7, Min(28, Round(h * 0.22)))
        bar := g.Add("Progress", Format("x0 y{} w{} h{}", h - barH, w, barH))
        bar.Opt("c" colAcento)
        bar.Value := 100

        gt.BackColor := "1A1A1A"
        WinSetTransColor("1A1A1A", gt)
        lbl := gt.Add("Text", Format("x0 y{} w{} h{} cFFFFFF +0x200 +0x4000 Center BackgroundTrans", lblY, w, lblH), tit)
        lbl.SetFont("s" fSize " bold q4", "Segoe UI")
    } else {
        grande := (h >= 90)
        brazo := grande ? 16 : 10
        grosor := grande ? 3 : 2
        g.BackColor := "12141A"
        g.MarginX := 0
        g.MarginY := 0
        alpha := (c.op <= 40) ? 102 : ((c.op <= 70) ? 178 : 255)
        WinSetTransparent(alpha, g)
        xr := w - brazo, yb := h - brazo
        xr2 := w - grosor, yb2 := h - grosor
        bgC := "Background" colAcento
        g.Add("Text", Format("x0 y0 w{} h{} {}", brazo, grosor, bgC))
        g.Add("Text", Format("x0 y0 w{} h{} {}", grosor, brazo, bgC))
        g.Add("Text", Format("x{} y0 w{} h{} {}", xr, brazo, grosor, bgC))
        g.Add("Text", Format("x{} y0 w{} h{} {}", xr2, grosor, brazo, bgC))
        g.Add("Text", Format("x0 y{} w{} h{} {}", yb2, brazo, grosor, bgC))
        g.Add("Text", Format("x0 y{} w{} h{} {}", yb, grosor, brazo, bgC))
        g.Add("Text", Format("x{} y{} w{} h{} {}", xr, yb2, brazo, grosor, bgC))
        g.Add("Text", Format("x{} y{} w{} h{} {}", xr2, yb, grosor, brazo, bgC))
        mbw := Max(30, Round(w * 0.30))
        g.Add("Text", Format("x{} y{} w{} h3 {}", (w - mbw) // 2, h - 7, mbw, bgC))

        tSize := Max(10, Min(36, Round(h * 0.16)))
        sSize := grande ? 10 : 8
        tAlto := tSize * 2
        tY := (h - tAlto) // 2 + 8
        ancho := Max(40, w - 24)

        gt.BackColor := "12141A"
        WinSetTransColor("12141A", gt)
        gt.SetFont("s" sSize " bold c9AA7C7 q4", "Segoe UI")
        gt.Add("Text", Format("x12 y{} w{} h18 Center BackgroundTrans +0x200 +0x4000", Max(4, tY - 18), ancho), "📌 ANCLADO · " StrUpper(_PtsZonaTxt(c.z)))
        gt.SetFont("s" tSize " bold cFFFFFF q4", "Segoe UI")
        gt.Add("Text", Format("x12 y{} w{} h{} Center BackgroundTrans +0x200 +0x4000", tY, ancho, tAlto), tit)
    }

    ; Orden de apilado: primero g, luego gt encima
    g.Show(Format("x{} y{} w{} h{} NoActivate", px, py, w, h))
    gt.Show(Format("x{} y{} w{} h{} NoActivate", px, py, w, h))

    ptsEd.guiAnclado := g
    ptsEd.guiAncladoTxt := gt
    ptsEd.evAnclado := true
    ptsEd.bEvAnclar.Text := "🔒"
    ptsEd.bEvReub.Enabled := true
    ptsEd.st.Value := "HUD de " tit " ANCLADO indefinidamente. '📍 Reubicar' accionado para calibrar con el lápiz."
    return true
}
_PtsEvToggleAnclar(*) {
    if (ptsEd.evAnclado) {
        _PtsOcultarGuiAnclado()
        ptsEd.st.Value := "HUD desanclado de pantalla."
        _SonarUI("calib")
        return
    }
    filas := _PtsEvObtenerSeleccionados(ptsEd.lvEv)
    row := (filas.Length > 0) ? filas[1] : ptsEd.evSel
    if (row < 1 || !ptsEd.mapFilas.Has(row))
        return
    if _PtsMostrarGuiAnclado(row)
        _SonarUI("calib")
}
_PtsEvReubicarZona(*) {
    if (!ptsEd.evAnclado) {
        ptsEd.st.Value := "Primero ancla el HUD con '📌 Anclar' para reubicarlo."
        return
    }
    filas := _PtsEvObtenerSeleccionados(ptsEd.lvEv)
    row := (filas.Length > 0) ? filas[1] : ptsEd.evSel
    if (row < 1 || !ptsEd.mapFilas.Has(row))
        return
    idxReal := ptsEd.mapFilas[row]
    ev := _PtsEventosDefs()[idxReal]
    idEv := ev[1]
    tit := Trim(RegExReplace(_PtsNomEvento(idEv),"\s*\(.*\)\s*$"))

    r := _PtsEditarRangoInteractivo(tit, idEv)
    if (!r) {
        _PtsMostrarGuiAnclado(row)
        ptsEd.st.Value := "Reubicación cancelada."
        return
    }

    global AVISO_ESC, PERFIL
    anchoMin := Round(240 * AVISO_ESC)
    altoMin  := Round(72  * AVISO_ESC)
    fw := (r.w < 60) ? anchoMin : r.w
    fh := (r.h < 24) ? altoMin  : r.h

    ini := _PosGuiIniPath()
    sec := _ZonaSec("Rangos")
    ; Guarda el rango exclusivo de este evento (prevalece sobre la zona)
    IniWrite(Format("{},{},{},{}", r.x, r.y, fw, fh), ini, sec, "HUD_ev_" . idEv)
    CargarPuntos()

    _PtsMostrarGuiAnclado(row)
    _SonarUI("calib")
    ptsEd.st.Value := "Evento '" tit "' reubicado a (" r.x ", " r.y ") " fw "x" fh " px (ubicación guardada)."
}

; Manipulador interactivo: arrastrar = mover, bordes/esquinas = redimensionar.
; Enter / ✔ = guardar, Esc / ✖ = cancelar. Devuelve {x,y,w,h} o 0.
_DzLog(msg) {
    try FileAppend(FormatTime(, "HH:mm:ss") "." A_MSec " | " msg "`n", A_Temp "\_dz_ultimo.txt", "UTF-8")
}

_PtsLeerRangoEvento(idEv, tipo := "hud") {
    ini := _PosGuiIniPath(), sec := _ZonaSec("Rangos")
    id := RegExReplace(idEv, "^(HUD_ev_)+", "")
    if (tipo = "zona") {                    ; Disparador Espacial: <id>_x/_y/_w/_h
        v := []
        for suf in ["_x", "_y", "_w", "_h"] {
            t := Trim(IniRead(ini, sec, id . suf, ""))
            if !IsInteger(t)
                return ""
            v.Push(Integer(t))
        }
        return {x: v[1], y: v[2], w: v[3], h: v[4]}
    }
    s := IniRead(ini, sec, "HUD_ev_" . id, "")   ; aviso HUD
    if (s = "")
        s := IniRead(ini, sec, id, "")
    p := StrSplit(s, ",")
    if (p.Length = 4 && IsInteger(Trim(p[1])) && IsInteger(Trim(p[2]))
        && IsInteger(Trim(p[3])) && IsInteger(Trim(p[4])))
        return {x: Integer(Trim(p[1])), y: Integer(Trim(p[2]))
              , w: Integer(Trim(p[3])), h: Integer(Trim(p[4]))}
    return ""
}

_PtsEditarRangoInteractivo(titulo, idEv, rectIni := "", ses := "") {
    _DzLog("ENTRANDO A _PtsEditarRangoInteractivo")
    global AVISO_ESC, ptsEd
    x := "", y := ""
    w := Round(240 * AVISO_ESC), h := Round(72 * AVISO_ESC)

    if (IsObject(rectIni) && rectIni.HasProp("x") && rectIni.HasProp("y")) {
        x := rectIni.x, y := rectIni.y
        w := rectIni.HasProp("w") ? rectIni.w : w
        h := rectIni.HasProp("h") ? rectIni.h : h
    } else {
        ; 1) Rango ya guardado (clave según tipo: zona = <id>_x.._h · hud = HUD_ev_<id>)
        try {
            rr := _PtsLeerRangoEvento(idEv, IsObject(ses) ? ses.tipo : "hud")
            if IsObject(rr) {
                x := rr.x, y := rr.y, w := rr.w, h := rr.h
            }
        }
    }
    ; 3) Centro de pantalla
    if (x = "") {
        x := Round((A_ScreenWidth - w) / 2)
        y := Round((A_ScreenHeight - h) / 2)
    }
    if (IsObject(rectIni))
        w := Max(w, 40), h := Max(h, 30)
    else
        w := Max(w, 120), h := Max(h, 50)

    if (!IsObject(rectIni))
        try ptsEd.guiAnclado.Hide()

    st := {done: false, ok: false}
    r := ""
    g := Gui("+AlwaysOnTop -Caption +Resize +ToolWindow -DPIScale")
    g.BackColor := "00E5FF"
    g.SetFont("s9 bold c000000", "Segoe UI")
    if (!IsObject(ses))
        g.Add("Text", "x8 y6 w220 h34 BackgroundTrans +0x80", "↔ Arrastra · esquinas para estirar`nEnter ✔ · Esc ✖")
    bOk := g.Add("Button", "Default w30 h24", "✔")
    bNo := g.Add("Button", "w30 h24", "✖")
    bOk.OnEvent("Click", (*) => (_DzLog("done por click-OK"), st.ok := true, st.done := true))
    bNo.OnEvent("Click", (*) => (_DzLog("done por click-NO"), st.done := true))
    g.OnEvent("Escape", (*) => (_DzLog("done por Escape"), st.done := true))
    g.OnEvent("Close", (*) => (_DzLog("done por Close"), st.done := true))

    ; --- Opciones externas con Línea Guía para zonas chicas / abarrotadas ---
    gCall := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +Owner" g.Hwnd)
    gCall.BackColor := "101018"
    gCall.MarginX := 2
    gCall.MarginY := 2
    gCall.SetFont("s9 bold c000000", "Segoe UI")
    bOkExt := gCall.Add("Button", "x3 y3 w28 h24", "✔")
    bNoExt := gCall.Add("Button", "x33 y3 w28 h24", "✖")
    bOkExt.OnEvent("Click", (*) => (st.ok := true, st.done := true))
    bNoExt.OnEvent("Click", (*) => (st.done := true))

    gLineaH := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale +Owner" g.Hwnd)
    gLineaH.BackColor := "00E5FF"
    gLineaV := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale +Owner" g.Hwnd)
    gLineaV.BackColor := "00E5FF"

    _ActualizarCallout() {
        local cx := 0, cy := 0, cw := 0, ch := 0
        local mL := 0, mT := 0, mR := A_ScreenWidth, mB := A_ScreenHeight
        local x0 := 0, y0 := 0, px := 0, py := 0, haciaDer := true, largoLinea := 30
        if (st.done || !WinExist("ahk_id " g.Hwnd)) {
            try gCall.Destroy()
            try gLineaH.Destroy()
            try gLineaV.Destroy()
            return
        }
        WinGetPos(&cx, &cy, &cw, &ch, g.Hwnd)
        if (cw >= 85 && ch >= 50) {
            bOk.Visible := true
            bNo.Visible := true
            gCall.Hide()
            gLineaH.Hide()
            gLineaV.Hide()
            return
        }
        bOk.Visible := false
        bNo.Visible := false

        Loop MonitorGetCount() {
            MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
            if (cx >= l && cx < r && cy >= t && cy < b) {
                mL := l, mT := t, mR := r, mB := b
                break
            }
        }
        haciaDer := (cx + cw // 2 < (mL + mR) // 2)
        ; Flip: si no cabe del lado elegido, usar el opuesto (si ese sí cabe)
        if (haciaDer && cx + cw + largoLinea + 64 > mR && cx - largoLinea - 64 >= mL)
            haciaDer := false
        else if (!haciaDer && cx - largoLinea - 64 < mL && cx + cw + largoLinea + 64 <= mR)
            haciaDer := true
        ; Ancla vertical siempre dentro del monitor
        cyc := Min(Max(cy + ch // 2, mT + 4), mB - 4)
        if (haciaDer) {
            x0 := Min(cx + cw, mR - 4), y0 := cyc, px := x0 + largoLinea, py := y0 + 15
            if (px + 64 > mR)  px := mR - 64
            if (px < mL + 4)   px := mL + 4
            if (py + 30 > mB)  py := mB - 30
            if (py < mT + 4)   py := mT + 4
            gLineaH.Show(Format("NA x{} y{} w{} h2", Min(x0, px), y0, Max(2, Abs(px - x0))))
            gLineaV.Show(Format("NA x{} y{} w2 h{}", px, Min(y0, py + 12), Max(2, Abs(py + 12 - y0))))
        } else {
            x0 := Max(cx, mL + 4), y0 := cyc, px := x0 - largoLinea - 64, py := y0 + 15
            if (px < mL)       px := mL + 4
            if (px + 64 > mR)  px := mR - 64
            if (py + 30 > mB)  py := mB - 30
            if (py < mT + 4)   py := mT + 4
            gLineaH.Show(Format("NA x{} y{} w{} h2", Min(px + 64, x0), y0, Max(2, Abs(x0 - (px + 64)))))
            gLineaV.Show(Format("NA x{} y{} w2 h{}", px + 64, Min(y0, py + 12), Max(2, Abs(py + 12 - y0))))
        }
        gCall.Show(Format("NA x{} y{} w64 h30", px, py))
    }

    g.OnEvent("Size", (gui, mm, cw, ch) => (_ActualizarCallout(), (cw >= 85 && ch >= 50 ? (bOk.Move(cw - 68, ch - 30), bNo.Move(cw - 34, ch - 30)) : 0)))

    NcHit(wParam, lParam, msg, hwnd) {
        if (hwnd != g.Hwnd)
            return
        mx := lParam << 48 >> 48
        my := lParam << 32 >> 48
        WinGetPos(&wx, &wy, &ww, &wh, g.Hwnd)
        mg := 12
        eL := (mx < wx + mg), eR := (mx >= wx + ww - mg)
        eT := (my < wy + mg), eB := (my >= wy + wh - mg)
        if (eT && eL)
            return 13   ; HTTOPLEFT
        if (eT && eR)
            return 14   ; HTTOPRIGHT
        if (eB && eL)
            return 16   ; HTBOTTOMLEFT
        if (eB && eR)
            return 17   ; HTBOTTOMRIGHT
        if (eL)
            return 10   ; HTLEFT
        if (eR)
            return 11   ; HTRIGHT
        if (eT)
            return 12   ; HTTOP
        if (eB)
            return 15   ; HTBOTTOM
        return 2        ; HTCAPTION: arrastrar para mover
    }

    r := 0
    try {
        _DzLog("Antes de OnMessage y g.Show")
        OnMessage(0x84, NcHit)
        _DzLog("Antes de g.Show")
        g.Show("x" x " y" y " w" w " h" h)
        g.Move(x, y, w, h)
        _DzLog("Despues de g.Show")
        WinSetTransparent(150, g.Hwnd)
        _PtsPanelAlFrente(ses)
        _ActualizarCallout()
        _DzLog("Despues de WinSetTransparent")
        if (IsSet(ptsEd) && IsObject(ptsEd) && HasProp(ptsEd, "st") && IsObject(ptsEd.st))
            ptsEd.st.Value := "Reubicando: " titulo " — arrastra / estira y confirma con Enter."
        _DzLog("espera iniciada idEv=" idEv " hwnd=" g.Hwnd)
        while (!st.done) {
            if !WinExist("ahk_id " g.Hwnd) {
                _DzLog("GUI destruida externamente")
                break
            }
            if (IsObject(ses) && ses.cambio != "") {
                try {
                    WinGetPos(&kx, &ky, &kw, &kh, g.Hwnd)
                    ses.rect := {x: kx, y: ky, w: kw, h: kh}
                }
                break
            }
            _ActualizarCallout()
            Sleep(25)
        }
        _DzLog("espera terminada done=" st.done " ok=" st.ok)
        if (st.ok) {
            WinGetPos(&fx, &fy, &fw2, &fh2, g.Hwnd)
            r := {x: fx, y: fy, w: fw2, h: fh2}
        }
    } catch as e {
        _DzLog("EXCEPCION INTERNA _PtsEditarRangoInteractivo: " e.Message " @" e.What " L" e.Line)
        r := 0
    } finally {
        _DzLog("Entrando al finally de _PtsEditarRangoInteractivo")
        try OnMessage(0x84, NcHit, 0)
        try gCall.Destroy()
        try gLineaH.Destroy()
        try gLineaV.Destroy()
        try g.Destroy()
    }
    return r
}
; ===== Sistema y perfiles =====
_PtsAlphaChange(*) {
    global ESTAB_ALPHA_H,PERFIL
    v := Trim(ptsEd.eAlpha.Value)
    if (!IsInteger(v) || Integer(v) < 10 || Integer(v) > 100)
        return
    ESTAB_ALPHA_H := Round(Integer(v) * 2.55)
    IniWrite(Integer(v),_PosGuiIniPath(),"Estab_p" PERFIL,"alphaH")
    _EstabAlpha(false)
}
_PtsAlphaFChange(*) {
    global ESTAB_ALPHA_F,PERFIL
    v := Trim(ptsEd.eAlphaF.Value)
    if (!IsInteger(v) || Integer(v) < 10 || Integer(v) > 100)
        return
    ESTAB_ALPHA_F := Round(Integer(v) * 2.55)
    IniWrite(Integer(v),_PosGuiIniPath(),"Estab_p" PERFIL,"alphaF")
    if estabGui.foco
        _EstabAlpha(false)
}
_PtsDibujarZonaEstab(foco := false) {
    clave := foco ? "EstabFoco" : "Estab"
    d := _PtsDefPorClave(clave)
    if !IsObject(d)
        return
    txt := foco ? "✏ Dibuja la zona del deslizador de ENFOQUE (Shift+E)  ·  ancho = horizontal  ·  Esc = cancelar"
                : "✏ Arrastra para dibujar el deslizador de ESTABILIZACIÓN  ·  ancho = horizontal  ·  Esc = cancelar"
    r := _PtsDibujarRango(txt,d.c,false)
    if !IsObject(r) {
        if IsObject(ptsEd.st)
            ptsEd.st.Value := "Dibujo cancelado."
        return
    }
    _PtsAplicarZona(d,r)
}

; ===== INICIO P1: helpers de píldora y exclusión mutua =====
_PtsEvIdSel() {
    if (!IsSet(ptsEd) || !IsObject(ptsEd) || !HasProp(ptsEd, "mapFilas") || !IsObject(ptsEd.mapFilas))
        return ""
    ; evSel es la fila tocada por última vez (lvEv es +Multi: GetNext(0) puede devolver otra)
    fila := HasProp(ptsEd, "evSel") ? ptsEd.evSel : 0
    if (!fila || !ptsEd.mapFilas.Has(fila))
        fila := (HasProp(ptsEd, "lvEv") && IsObject(ptsEd.lvEv)) ? ptsEd.lvEv.GetNext(0) : 0
    if (!fila || !ptsEd.mapFilas.Has(fila))
        return ""
    defs := _PtsEventosDefs()
    idxReal := ptsEd.mapFilas[fila]
    if (!IsInteger(idxReal) || idxReal < 1 || idxReal > defs.Length)
        return ""
    return defs[idxReal][1]
}

_PtsExcluirOpuesto(tipo, idEv) {
    ; tipo = "cruzar" (Paso➔Tecla) o "auto" (Paso➔Clic): desmarca el opuesto en UI e INI
    opuesto := (tipo = "cruzar") ? "auto" : "cruzar"
    cb := (tipo = "cruzar") ? (HasProp(ptsEd, "cbAuto") ? ptsEd.cbAuto : 0) : (HasProp(ptsEd, "cbCruzar") ? ptsEd.cbCruzar : 0)
    if (cb && cb.Value = 1)
        cb.Value := 0
    if (idEv != "")
        IniWrite("0", _PosGuiIniPath(), "Particularidades", opuesto "_" idEv)
    try _PtsExcluirCruzarAuto(tipo, idEv)
}

_PillGuiDe(p) {
    if (p is Gui)
        return p
    for nom in ["g", "gui", "ventana"]
        if HasProp(p, nom) && (p.%nom% is Gui)
            return p.%nom%
    return ""
}

; Píldoras rígidas (companion_flotantes): no viven en _PillDin(), se resuelven por idEv.
_PillGuiRigida(idEv) {
    global dsGui, ccGui, lockGui, frenteGui, estabBtnGui, reloadGui
    o := 0
    switch idEv {
        case "panel_ds":     o := IsSet(dsGui) ? dsGui : 0
        case "panel_cc":     o := IsSet(ccGui) ? ccGui : 0
        case "history_lock": o := IsSet(lockGui) ? lockGui : 0
        case "gui_frente":   o := IsSet(frenteGui) ? frenteGui : 0
        case "estab_slider": o := IsSet(estabBtnGui) ? estabBtnGui : 0
        case "reload":       o := IsSet(reloadGui) ? reloadGui : 0
        default: return ""
    }
    g := IsObject(o) ? o.g : 0
    return (IsObject(g) && (g is Gui)) ? g : ""
}

_PtsPildoraUbicar(idEv := "", *) {
    if (idEv = "")
        idEv := _PtsEvIdSel()
    if (idEv = "")
        return
    _PillSincronizarDinamicas()               ; crea la píldora si pildora_<idEv>=1
    try _CompPildoraAplicar(idEv)             ; W1: tamaño/color antes de centrar
    pd := _PillDin()
    esRigida := !(pd.Has(idEv))
    if esRigida {
        g := _PillGuiRigida(idEv)
    } else {
        p := pd[idEv]
        g := HasProp(p, "g") && (p.g is Gui) ? p.g : _PillGuiDe(p)
    }
    if !g {
        ToolTip("Activa [x] Píldora Táctil para este evento")
        SetTimer(() => ToolTip(), -1800)
        return
    }
    if esRigida {
        g.Show("NA")                          ; rígida: solo se muestra/parpadea, no se reubica
    } else {
        ; Centro del área de trabajo del monitor bajo el cursor
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my)
        idx := MonitorGetPrimary()
        Loop MonitorGetCount() {
            MonitorGet(A_Index, &l, &t, &r, &b)
            if (mx >= l && mx < r && my >= t && my < b) {
                idx := A_Index
                break
            }
        }
        MonitorGetWorkArea(idx, &l, &t, &r, &b)
        g.GetPos(, , &w, &h)
        nx := l + (r - l - w) // 2
        ny := t + (b - t - h) // 2
        g.Show("NA x" nx " y" ny)
        try GuardarPosicionGUI("Pildora_" idEv, g.Hwnd)   ; firma (nombre, hwnd)
    }
    ; Parpadeo de localización (restaura la opacidad previa; evita 0 para no perder el puntero)
    hw := g.Hwnd
    prev := WinGetTransparent("ahk_id " hw)
    est := {n: 0}
    Parpadeo() {
        est.n += 1
        if (est.n > 6) {
            SetTimer(Parpadeo, 0)
            WinSetTransparent(prev = "" ? 255 : prev, "ahk_id " hw)
            return
        }
        WinSetTransparent(Mod(est.n, 2) ? 255 : 70, "ahk_id " hw)
    }
    SetTimer(Parpadeo, 120)
}

_PtsPildoraBtnAgregar(x, y, w := 210) {
    if (HasProp(ptsEd, "bPildora") && IsObject(ptsEd.bPildora))
        return ptsEd.bPildora
    targetG := (IsSet(ACC) && IsObject(ACC) && HasProp(ACC, "g") && IsObject(ACC.g)) ? ACC.g : ((IsSet(ptsEd) && HasProp(ptsEd, "g") && IsObject(ptsEd.g)) ? ptsEd.g : "")
    ptsEd.bPildora := targetG.Add("Button", "x" x " y" y " w" w " h26", "[ Mostrar / Ubicar píldora ]")
    ptsEd.bPildora.OnEvent("Click", (*) => _PtsPildoraUbicar())
    return ptsEd.bPildora
}
; ===== FIN P1 =====

_PtsDibujarZonaEvento(key := "") {
    idEv := _PtsSndIdEv()
    if (idEv = "") {
        MsgBox("Selecciona primero un evento en el catálogo para dibujar su zona.", "Dibujar zona", "Iconi")
        return
    }
    nomEv := _PtsNomEvento(idEv)
    txt := "✏ Arrastra sobre la pantalla para definir la zona de «" nomEv "»  ·  Esc = cancelar"
    try _EspacialPausar(true)
    try {
        r := _PtsDibujarRango(txt, "00E5FF", false)
    } finally {
        try _EspacialPausar(false)
    }
    if !IsObject(r) {
        if IsObject(ptsEd.st)
            ptsEd.st.Value := "Dibujo cancelado."
        return
    }
    if (r.w < 8 || r.h < 8) {                              ; clic suelto: no pisar la zona anterior con 0×0
        MostrarHUD("Zona muy pequeña (mín. 8×8 px): no se guardó", "FF5252", 1400)
        if IsObject(ptsEd.st)
            ptsEd.st.Value := "Zona descartada (menos de 8×8 px)."
        return
    }
    ini := _PosGuiIniPath(), sec := "Rangos" PERFIL
    IniWrite(r.x, ini, sec, idEv "_x")
    IniWrite(r.y, ini, sec, idEv "_y")
    IniWrite(r.w, ini, sec, idEv "_w")
    IniWrite(r.h, ini, sec, idEv "_h")
    try _EspacialCargar()
    MostrarHUD("Zona guardada: " r.w "x" r.h " px", "00E5FF", 1200)
    if IsObject(ptsEd.st)
        ptsEd.st.Value := "Zona registrada para '" nomEv "': (" r.x ", " r.y ", " r.w "x" r.h ")."
    _PtsEvFilas()
}
_PtsReiniciar(*) {
    GuardarPuntos()
    _RgGuardarMirror()
    ToolTip("🔄 Reiniciando script…")
    Sleep(250)
    Reload()
}
_PtsMoverBotones(ctrl) {
    _ToggleBloqueo()
    ctrl.Text := panelBlk.locked ? "🔓 Mover botones" : "🔒 Fijar botones"
}
_PtsReubicar(*) {
    ReubicarBotones()
    ptsEd.st.Value := "Botones reubicados para este perfil."
}
ReubicarBotones() {
    mon := ObtenerMonitorCSP()
    F := 0x0001 | 0x0004 | 0x0010
    ancho := _AnchoBtn("SLIDER") + _AnchoBtn("CIRCLE") + _AnchoBtn("QUICK") + _AnchoBtn("ESTAB") + _E(31) * 2 + PANEL_GAP * 5
    x0 := mon.x + (mon.w - ancho) // 2
    y0 := mon.y + Round(mon.h * 0.02) + 42 + 4
    sx := x0
    for g in [dsGui,ccGui,arGui,lockGui,frenteGui,estabBtnGui] {
        if !IsObject(g.g)
            continue
        DllCall("SetWindowPos","Ptr",g.g.Hwnd,"Ptr",0,"int",sx,"int",y0,"int",0,"int",0,"uint",F)
        WinGetPos(&gx,&gy,&gw,&gh,"ahk_id " g.g.Hwnd)
        sx += gw + PANEL_GAP
    }
    if (IsObject(estabGui.g) && !estabGui.horiz) {
        WinGetPos(&lkX,&lkY,&lkW,&lkH,"ahk_id " lockGui.g.Hwnd)
        ex := Min(lkX + lkW + PANEL_GAP,mon.x + mon.w - _E(220))
        DllCall("SetWindowPos","Ptr",estabGui.g.Hwnd,"Ptr",0,"int",ex,"int",lkY,"int",0,"int",0,"uint",F)
    }
    WinGetPos(&gx,&gy,&gw,&dsH,"ahk_id " dsGui.g.Hwnd)
    hcY := y0 + dsH + PANEL_GAP
    DllCall("SetWindowPos","Ptr",hcGui.g.Hwnd,"Ptr",0,"int",x0,"int",hcY,"int",0,"int",0,"uint",F)
    WinGetPos(&gx,&gy,&gw,&hcH,"ahk_id " hcGui.g.Hwnd)
    ry := hcY + hcH + PANEL_GAP
    DllCall("SetWindowPos","Ptr",reloadGui.g.Hwnd,"Ptr",0,"int",x0,"int",ry,"int",0,"int",0,"uint",F)
    WinGetPos(&gx,&gy,&rw,&rh,"ahk_id " reloadGui.g.Hwnd)
    DllCall("SetWindowPos","Ptr",puntosGui.g.Hwnd,"Ptr",0,"int",x0 + rw + PANEL_GAP,"int",ry,"int",0,"int",0,"uint",F)
    GuardarPosicionGUI("PanelBlock",dsGui.g.Hwnd)
    GuardarPosicionGUI("Slider",dsGui.g.Hwnd)
    GuardarPosicionGUI("Circle",ccGui.g.Hwnd)
    GuardarPosicionGUI("Quick",arGui.g.Hwnd)
    GuardarPosicionGUI("Lock",lockGui.g.Hwnd)
    GuardarPosicionGUI("Frente",frenteGui.g.Hwnd)
    GuardarPosicionGUI("EstabBtn",estabBtnGui.g.Hwnd)
    GuardarPosicionGUI("HC",hcGui.g.Hwnd)
    _GuardarOffsetHC()
    GuardarPosicionGUI("Reload",reloadGui.g.Hwnd)
    GuardarPosicionGUI("PuntosBtn",puntosGui.g.Hwnd)
    GuardarPosicionGUI("Estab",estabGui.g.Hwnd)
}
_PtsUltimoBackupIni() {
    mejor := "", t := 0
    Loop Files A_ScriptDir "\posiciones_gui_*.bak.ini" {
        ; FileCopy hereda la fecha del original, así que dos copias seguidas empatan
        ; al segundo. El sello del nombre sí es el instante real de la copia.
        fm := Integer(A_LoopFileTimeModified)
        if RegExMatch(A_LoopFileName,"^posiciones_gui_(\d{8})_(\d{6})\.bak\.ini$",&m)
            fm := Integer(m[1] m[2])
        if (fm > t) {
            t := fm
            mejor := A_LoopFilePath
        }
    }
    if (mejor = "")
        return 0
    return {ruta:mejor,nombre:SubStr(mejor,StrLen(A_ScriptDir) + 2),tick:t}
}
_PtsSelloLibre() {
    sello := FormatTime(,"yyyyMMdd_HHmmss")
    if FileExist(A_ScriptDir "\posiciones_gui_" sello ".bak.ini") {
        Sleep(1000 - Mod(A_MSec,1000) + 10)   ; dos clics en el mismo segundo no deben pisarse
        sello := FormatTime(,"yyyyMMdd_HHmmss")
    }
    return sello
}
_PtsBakRefrescar() {
    if (!IsObject(ptsEd.g) || !IsObject(ptsEd.lblBak))
        return
    b := _PtsUltimoBackupIni()
    if IsObject(b) {
        ptsEd.lblBak.Value := "Último: " b.nombre "`n" FormatTime(b.tick,"dd/MM/yyyy HH:mm:ss")
        ptsEd.bRes.Enabled := true
    } else {
        ptsEd.lblBak.Value := "Sin backups todavía."
        ptsEd.bRes.Enabled := false
    }
}
_PtsBackupIni(*) {
    ini := _PosGuiIniPath()
    if !FileExist(ini) {
        ptsEd.st.Value := "⚠ No existe posiciones_gui.ini: no hay nada que respaldar."
        return
    }
    sello := _PtsSelloLibre()
    dest := A_ScriptDir "\posiciones_gui_" sello ".bak.ini"
    try {
        FileCopy(ini,dest)
    } catch as e {
        ptsEd.st.Value := "⚠ Backup fallido: " e.Message
        return
    }
    _PtsBakRefrescar()
    ptsEd.st.Value := "💾 Backup creado: posiciones_gui_" sello ".bak.ini"
    _SonarUI("calib")
}
_PtsRestaurarIni(*) {
    b := _PtsUltimoBackupIni()
    if !IsObject(b) {
        ptsEd.st.Value := "No hay ningún posiciones_gui_*.bak.ini en la carpeta del script."
        return
    }
    ptsEd.g.Opt("+OwnDialogs")
    if (MsgBox("¿Restaurar " b.nombre "?`n`nAntes se guardará una copia del estado actual (para poder deshacer) y el script se reiniciará.","Restaurar backup","YesNo Icon?") != "Yes")
        return
    ini := _PosGuiIniPath()
    sello := _PtsSelloLibre()
    try {
        FileCopy(ini,A_ScriptDir "\posiciones_gui_" sello ".bak.ini")
        FileCopy(b.ruta,ini,1)
    } catch as e {
        ptsEd.st.Value := "⚠ Restauración fallida: " e.Message
        return
    }
    ; Sin GuardarPuntos: los puntos en memoria son los viejos y pisarían el ini restaurado.
    ToolTip("↩ Backup restaurado: " b.nombre)
    Sleep(250)
    Reload()
}
_PtsCambiarPerfil(ctrl,*) {
    CambiarPerfil(ctrl.Value)
}
_PtsEscCerrar(*) {
    try ptsEd.g.Destroy()
    ptsEd.g := 0
}

_PtsCerrar(*) {
    SetTimer(_PtsIndRefrescar, 0)
    SetTimer(_PtsIndOk, 0)
    if (ptsEd.dibujando)
        return
    OcultarZonasCalibracion()        ; primero: antes de cualquier llamada que pueda lanzar error
    _PtsOcultarGuiAnclado()
    GuardarPuntos()
    _RgGuardarMirror()
    OcultarZonasCalibracion()
    recargar := false
    try {
        v := Trim(ptsEd.eEsc.Value)
        if (IsNumber(v) && Number(v) >= 40 && Number(v) <= 200 && Abs(Number(v) - ESC * 100) >= 0.5) {
            IniWrite(Round(Number(v)),_PosGuiIniPath(),"Puntos" PERFIL,"escala")
            recargar := true
        }
    }
    try {
        v := Trim(ptsEd.eEscAv.Value)
        if (IsNumber(v) && Number(v) >= 40 && Number(v) <= 250 && Abs(Number(v) - AVISO_ESC * 100) >= 0.5) {
            IniWrite(Round(Number(v)),_PosGuiIniPath(),"Puntos" PERFIL,"escalaAvisos")
            recargar := true
        }
    }
    SetTimer(_PtsModoVigilar,0)
    ptsModo.edit := false
    ptsModo.btnN := 0
    ptsModo.btnE := 0
    CargarPuntos()
    try OnMessage(0x004E,_PtsTemaLvNotify, 0)
    ptsEd.temaLvHwnd := 0
    ptsEd.temaLv := 0
    try ptsEd.g.Destroy()
    ptsEd.g := 0
    ptsEd.sel := 0
    if (recargar) {
        ToolTip("🔄 Aplicando escala…")
        Sleep(250)
        Reload()
    }
    _SonarUI("calib")
}
; ===== Vista previa de zonas (misma firma) =====
_PtsToggleVerZonas(*) {
    if (ptsEd.ovl.Length > 0)
        OcultarZonasCalibracion()
    else
        MostrarZonasCalibracion(0)
}
MostrarZonasCalibracion(ms := 0, modo := "todo") {
    OcultarZonasCalibracion()
    try RecalcularZonas()
    ; modo "foco" (dibujo): solo la zona en edición, sin el universo completo
    if (modo = "foco") {
        _PtsPushZonaSesion(ptsEd.ovl)
        return
    }
    for i, z in ZONAS.izq
        ptsEd.ovl.Push(_CrearRectOverlay(z.x1,z.y1,z.x2 - z.x1 + 1,z.y2 - z.y1 + 1,"2ECC71","Z" i))
    for i, z in ZONAS.der
        ptsEd.ovl.Push(_CrearRectOverlay(z.x1,z.y1,z.x2 - z.x1 + 1,z.y2 - z.y1 + 1,"3498DB","Z" . (i + 3)))
    h := ZONAS.hist
    ptsEd.ovl.Push(_CrearRectOverlay(h.x1,h.y1,h.x2 - h.x1 + 1,h.y2 - h.y1 + 1,"E67E22","Z7"))
    nombresHud := Map("HUD_Alta","ZONA 1 · ALTA","HUD_Media","ZONA 2 · MEDIA","HUD_Baja","ZONA 3 · BAJA","Estab","ESTABILIZADOR","EstabFoco","ESTAB FOCO")
    for k in ["HUD_Alta","HUD_Media","HUD_Baja","Estab","EstabFoco"] {
        d := _PtsDefPorClave(k)
        if !IsObject(d)
            continue
        r := _PtsRectDe(d)
        if (IsInteger(r.x) && IsInteger(r.y) && IsInteger(r.w) && IsInteger(r.h) && r.w > 0 && r.h > 0)
            ptsEd.ovl.Push(_CrearRectOverlay(r.x,r.y,r.w,r.h,d.c,nombresHud.Has(k) ? nombresHud[k] : d.n))
    }
    _PtsPushZonaSesion(ptsEd.ovl)   ; última zona dibujada / activa (cian)
    ptsP := Map(1,"Z8",2,"Z9",29,"Z10")
    for i in [1,2,29] {
        col := (i = 29) ? "F1C40F" : "E74C3C"
        lbl := ptsP.Has(i) ? ptsP[i] : ("P" i)
        dClv := (i = 1) ? "ToggleIzq" : ((i = 2) ? "ToggleDer" : "ZonaSegura")
        d := _PtsDefPorClave(dClv)
        r := IsObject(d) ? _PtsRectDe(d) : 0
        if (IsObject(r) && IsInteger(r.w) && r.w > 0 && IsInteger(r.h) && r.h > 0)
            ptsEd.ovl.Push(_CrearRectOverlay(r.x,r.y,r.w,r.h,col,lbl))
        else
            ptsEd.ovl.Push(_CrearRectOverlay(PUNTOS[i][1] - 5,PUNTOS[i][2] - 5,10,10,col,lbl))
    }
    ; Zonas de eventos configurados (HUD_ev_*)
    try {
        for ev in _PtsEventosRangos()
            ptsEd.ovl.Push(_CrearRectOverlay(ev.x, ev.y, ev.w, ev.h, "00E5FF", "EV " ev.id))
    }
    Loop 8 {
        d := _PtsDefPorClave("NvZona" A_Index)
        if IsObject(d) {
            r := _PtsRectDe(d)
            if (IsObject(r) && IsInteger(r.w) && r.w > 0 && IsInteger(r.h) && r.h > 0)
                ptsEd.ovl.Push(_CrearRectOverlay(r.x,r.y,r.w,r.h,d.c,"VENTANA " A_Index))
        }
    }
    dPes := _PtsDefPorClave("NvPestana")
    if IsObject(dPes) {
        r := _PtsRectDe(dPes)
        if (IsObject(r) && IsInteger(r.w) && r.w > 0 && IsInteger(r.h) && r.h > 0)
            ptsEd.ovl.Push(_CrearRectOverlay(r.x,r.y,r.w,r.h,dPes.c,"FRANJA PESTAÑAS (NO LIENZO)"))
    }
    if (ms > 0)
        SetTimer(OcultarZonasCalibracion,-ms)
    if (IsObject(ptsEd) && HasProp(ptsEd,"bVer") && IsObject(ptsEd.bVer))
        ptsEd.bVer.Text := "❌ Ocultar zonas"
    if (IsObject(ptsEd) && HasProp(ptsEd,"bNvVer") && IsObject(ptsEd.bNvVer))
        ptsEd.bNvVer.Text := "❌ Ocultar zonas"
}
OcultarZonasCalibracion() {
    try SetTimer(OcultarZonasCalibracion,0)
    lista := (IsObject(ptsEd) && HasProp(ptsEd,"ovl") && IsObject(ptsEd.ovl)) ? ptsEd.ovl : []
    if (IsObject(ptsEd))
        ptsEd.ovl := []               ; vaciar ANTES de destruir: evita reentrada
    for g in lista {
        try _OvlDestruir(g)
    }
    _OvlBarrerHuerfanas()
    if (IsObject(ptsEd) && HasProp(ptsEd,"bVer") && IsObject(ptsEd.bVer))
        ptsEd.bVer.Text := "👁 Ver zonas"
    if (IsObject(ptsEd) && HasProp(ptsEd,"bNvVer") && IsObject(ptsEd.bNvVer))
        ptsEd.bNvVer.Text := "👁 Ver zonas"
}

; Prefijo corto Zn para las 10 zonas del Disparador Espacial / periféricos
_PtsZid(id) {
    static m := Map("izqb1","Z1","izqb2","Z2","izqb3","Z3"
                  , "derb1","Z4","derb2","Z5","derb3","Z6"
                  , "historial","Z7","toggleizq","Z8","toggleder","Z9","zonasegura","Z10")
    k := StrLower(String(id))
    return m.Has(k) ? m[k] : ""
}

; Overlay cian de la zona activa / recién dibujada (ses.rect) → lista de overlays dada
_PtsPushZonaSesion(lista) {
    try {
        s := _PtsSesActual()
        if (!IsObject(s) || !HasProp(s, "rect") || !IsObject(s.rect))
            return
        r := s.rect
        esMapa := (r is Map)
        rx := esMapa ? r["x"] : r.x
        ry := esMapa ? r["y"] : r.y
        rw := esMapa ? r["w"] : r.w
        rh := esMapa ? r["h"] : r.h
        if (!IsInteger(rx) || !IsInteger(ry) || !IsInteger(rw) || !IsInteger(rh) || rw <= 0 || rh <= 0)
            return
        id  := HasProp(s, "idEv") ? s.idEv : (HasProp(s, "id") ? s.id : "")
        lista.Push(_CrearRectOverlay(rx, ry, rw, rh, "00E5FF", id))
    }
}

; ===================== ZONAS ESPACIALES (Panel Flotante) =====================
; Muestra SOLO las zonas del Disparador Espacial (Modo 1):
;   Click al pasar:    IZQ B1-B3, DER B1-B3, P29 (zona segura)
;   Lanzar tecla:      HISTORIAL
; NO dibuja lienzos, pestañas CSP, avisos HUD ni deslizadores.
; Doble buffer: se construyen los overlays nuevos ANTES de destruir los viejos (sin hueco visible).
_PtsMostrarZonasEspaciales() {
    global ptsEd
    if (!IsSet(ptsEd) || !IsObject(ptsEd))
        ptsEd := {}
    viejos := (HasProp(ptsEd, "ovlEsp") && IsObject(ptsEd.ovlEsp)) ? ptsEd.ovlEsp : []
    ptsEd.ovlEsp := []          ; el Ocultar interno de _Impl pasa a ser no-op
    try {
        _PtsMostrarZonasEspacialesImpl()
    } finally {
        for o in viejos
            try _OvlDestruir(o)
    }
}

_PtsMostrarZonasEspacialesImpl() {
    global ptsEd, ZONAS
    _PtsOcultarZonasEspaciales()
    if (!IsSet(ptsEd) || !IsObject(ptsEd))
        ptsEd := {}
    ptsEd.ovlEsp := []
    try RecalcularZonas()   ; siempre recargar: la última zona dibujada debe verse sin reiniciar
    if (!IsSet(ZONAS) || !IsObject(ZONAS))
        return

    if (IsSet(ZONAS) && IsObject(ZONAS)) {
        if (HasProp(ZONAS, "izq") && IsObject(ZONAS.izq)) {
            for i, z in ZONAS.izq
                ptsEd.ovlEsp.Push(_CrearRectOverlay(z.x1, z.y1, z.x2 - z.x1 + 1, z.y2 - z.y1 + 1, "2ECC71", "Z" i))
        }
        if (HasProp(ZONAS, "der") && IsObject(ZONAS.der)) {
            for i, z in ZONAS.der
                ptsEd.ovlEsp.Push(_CrearRectOverlay(z.x1, z.y1, z.x2 - z.x1 + 1, z.y2 - z.y1 + 1, "3498DB", "Z" (i + 3)))
        }
        if (HasProp(ZONAS, "hist") && IsObject(ZONAS.hist)) {
            h := ZONAS.hist
            ptsEd.ovlEsp.Push(_CrearRectOverlay(h.x1, h.y1, h.x2 - h.x1 + 1, h.y2 - h.y1 + 1, "E67E22", "historial"))
        }
    }

    ; Z8 y Z9: Toggle panel izq. y der.
    try {
        d8 := _PtsDefPorClave("ToggleIzq")
        r8 := IsObject(d8) ? _PtsRectDe(d8) : 0
        if (IsObject(r8) && IsInteger(r8.w) && r8.w > 0 && r8.h > 0)
            ptsEd.ovlEsp.Push(_CrearRectOverlay(r8.x, r8.y, r8.w, r8.h, "9B59B6", "toggleizq"))
    }
    try {
        d9 := _PtsDefPorClave("ToggleDer")
        r9 := IsObject(d9) ? _PtsRectDe(d9) : 0
        if (IsObject(r9) && IsInteger(r9.w) && r9.w > 0 && r9.h > 0)
            ptsEd.ovlEsp.Push(_CrearRectOverlay(r9.x, r9.y, r9.w, r9.h, "9B59B6", "toggleder"))
    }

    ; Z10: Zona segura cursor
    try {
        d := _PtsDefPorClave("ZonaSegura")
        r := IsObject(d) ? _PtsRectDe(d) : 0
        if (IsObject(r) && IsInteger(r.w) && r.w > 0 && r.h > 0)
            ptsEd.ovlEsp.Push(_CrearRectOverlay(r.x, r.y, r.w, r.h, "F1C40F", "zonasegura"))
    }
    ; Eventos configurados exclusivamente con Disparador Espacial (<id>_x..h)
    try {
        for ev in _PtsEventosEspacialesRangos()
            ptsEd.ovlEsp.Push(_CrearRectOverlay(ev.x, ev.y, ev.w, ev.h, "00E5FF", ev.id))
    }
    _PtsPushZonaSesion(ptsEd.ovlEsp)   ; última zona dibujada / activa (cian)
}

_PtsOcultarZonasEspaciales() {
    global ptsEd
    if !(IsSet(ptsEd) && IsObject(ptsEd) && HasProp(ptsEd, "ovlEsp") && IsObject(ptsEd.ovlEsp))
        return
    for o in ptsEd.ovlEsp
        try _OvlDestruir(o)
    ptsEd.ovlEsp := []
    try _OvlBarrerHuerfanas()
}

_PtsZonasEspacialesVisibles() {
    global ptsEd
    return (IsSet(ptsEd) && IsObject(ptsEd) && HasProp(ptsEd, "ovlEsp") && IsObject(ptsEd.ovlEsp) && ptsEd.ovlEsp.Length > 0)
}

_PtsAlternarZonasEspaciales() {
    if _PtsZonasEspacialesVisibles()
        _PtsOcultarZonasEspaciales()
    else
        _PtsMostrarZonasEspaciales()
    return _PtsZonasEspacialesVisibles()   ; true = quedaron visibles
}

_OvlTextoZona(idEv, textoFallback := "") {
    if RegExMatch(idEv, "i)^custom_(\d+)$", &m) {
        num := m[1]
        nom := _PtsNomEvento(idEv)
        if (nom != "" && !RegExMatch(nom, "i)^Nuevo evento \d+$") && nom != idEv)
            return {largo: nom, corto: "Z" num}
        return {largo: "Zona " num, corto: "Z" num}
    }
    if RegExMatch(idEv, "i)^Z(\d+)$", &m)
        return {largo: "Zona " m[1], corto: "Z" m[1]}
    switch idEv {
        case "izqb1": return {largo: "Zona 1", corto: "Z1"}
        case "izqb2": return {largo: "Zona 2", corto: "Z2"}
        case "izqb3": return {largo: "Zona 3", corto: "Z3"}
        case "derb1": return {largo: "Zona 4", corto: "Z4"}
        case "derb2": return {largo: "Zona 5", corto: "Z5"}
        case "derb3": return {largo: "Zona 6", corto: "Z6"}
        case "historial": return {largo: "Zona 7", corto: "Z7"}
        case "toggleizq": return {largo: "Zona 8", corto: "Z8"}
        case "toggleder": return {largo: "Zona 9", corto: "Z9"}
        case "zonasegura": return {largo: "Zona 10", corto: "Z10"}
    }
    tx := (textoFallback != "") ? textoFallback : idEv
    return {largo: tx, corto: SubStr(tx, 1, 4)}
}

_CrearRectOverlay(x,y,w,h,color,idEv := "",textoLargo := "",textoCorto := "") {
    ow := Max(w,4)
    oh := Max(h,4)
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale","")
    g.BackColor := color
    g.Show("x" x " y" y " w" ow " h" oh " NoActivate")
    WinSetTransparent(160,g)              ; solo la caja es translúcida
    if (idEv != "") {
        info := _OvlTextoZona(idEv, textoLargo)
        tL := (textoLargo != "") ? textoLargo : info.largo
        tC := (textoCorto != "") ? textoCorto : info.corto
        _OvlEtiqueta(g,x,y,ow,oh,color,tL,tC)
    }
    return g
}
_OvlEtiquetas() {
    static m := Map()                     ; hwnd de la caja -> ventana de su etiqueta
    return m
}
_OvlBarrerHuerfanas() {
    m := _OvlEtiquetas()
    muertos := []
    for hw, gl in m {
        if (!DllCall("IsWindow","ptr",hw))      ; la caja ya no existe
            muertos.Push(hw)
    }
    for hw in muertos {
        try m[hw].Destroy()
        m.Delete(hw)
    }
}
_OvlEtiqueta(gBox,x,y,ow,oh,color,textoLargo,textoCorto := "") {
    fs := 10
    try fs := _FS(10)
    gl := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale","")
    gl.BackColor := "101018"
    gl.MarginX := 0
    gl.MarginY := 0
    gl.SetFont("s" fs " bold cFFFFFF","Segoe UI")
    
    ; Poco espacio: caja angosta (< 72px) o baja (< 36px) usa versión compacta 'ZN'
    pocoEspacio := (ow < 72 || oh < 36)
    texto := (pocoEspacio && textoCorto != "") ? textoCorto : textoLargo

    t := gl.Add("Text","x10 y5 +0x200 BackgroundTrans",texto)
    t.GetPos(,,&tw,&th)
    lw := tw + 20
    lh := th + 12
    try gl.Add("Text","x0 y" (lh - 3) " w" lw " h3 Background" color,"")   ; filete del color de la zona
    vx := SysGet(76)
    vy := SysGet(77)
    vw := SysGet(78)
    vh := SysGet(79)
    lx := x + (ow - lw) // 2
    if (ow >= lw + 8 && oh >= lh + 8) {
        ly := y + (oh - lh) // 2          ; caja grande: etiqueta centrada dentro
    } else {
        ly := y - lh - 4                  ; caja chica: etiqueta encima (o debajo si no hay sitio)
        if (ly < vy)
            ly := y + oh + 4
    }
    lx := Max(vx,Min(lx,vx + vw - lw))
    ly := Max(vy,Min(ly,vy + vh - lh))
    gl.Show("x" lx " y" ly " w" lw " h" lh " NoActivate")
    _OvlEtiquetas()[gBox.Hwnd] := gl
}
_OvlDestruir(g) {
    if !IsObject(g)
        return
    hw := 0
    try hw := g.Hwnd
    m := _OvlEtiquetas()
    if (hw && m.Has(hw)) {
        try m[hw].Destroy()
        m.Delete(hw)
    }
    try g.Destroy()
}

; Devuelve -1 si no aplica (que siga el handler normal), o el código CDRF a devolver
_PtsEvLvRojo(lp) {
    global ptsEd, ptsPend
    static CLR_TXT := 0x4040D8      ; BGR: rojo suave / sutil (R=D8 G=40 B=40)
    if (!IsSet(ptsPend) || !IsObject(ptsPend))
        return -1
    if (!HasProp(ptsEd, "lvEv") || !ptsEd.lvEv || NumGet(lp, 0, "Ptr") != ptsEd.lvEv.Hwnd)
        return -1
    stage := NumGet(lp, 24, "UInt")            ; NMLVCUSTOMDRAW x64: dwDrawStage @24
    if (stage = 0x1)                           ; CDDS_PREPAINT
        return 0x20                            ; CDRF_NOTIFYITEMDRAW
    if (stage = 0x10001) {                     ; CDDS_ITEMPREPAINT
        fila := NumGet(lp, 56, "UPtr") + 1     ; dwItemSpec (0-based)
        if (ptsEd.mapFilas.Has(fila)) {
            slug := _PtsEventosDefs()[ptsEd.mapFilas[fila]][1]
            if (!ptsPend.Has(slug) && !_PtsEvActivo(slug)) {
                NumPut("UInt", 0x888888, lp, 80)      ; P3a: inactivo, gris atenuado
                return 0x2
            }
            if (ptsPend.Has(slug)) {
                NumPut("UInt", CLR_TXT, lp, 80)   ; clrText @80
                return 0x2                        ; CDRF_NEWFONT
            }
        }
    }
    return -1
}

; [TEMA-LISTA] Pinta las celdas de color del ListView (NM_CUSTOMDRAW) y evita paginar.
_PtsTemaLvNotify(wParam, lParam, msg, hwnd) {
    global ptsEd
    if (NumGet(lParam, 16, "int") != -12)              ; NM_CUSTOMDRAW
        return

    ; Hook para eventos pendientes en lvEv:
    if (HasProp(ptsEd, "lvEv") && ptsEd.lvEv && NumGet(lParam, 0, "Ptr") = ptsEd.lvEv.Hwnd) {
        r := _PtsEvLvRojo(lParam)
        if (r != -1)
            return r
        return
    }

    if (!HasProp(ptsEd, "temaLvHwnd") || !ptsEd.temaLvHwnd || NumGet(lParam, 0, "Ptr") != ptsEd.temaLvHwnd)
        return
    try {
        if (!DllCall("IsWindow", "Ptr", ptsEd.temaLvHwnd))
            return
    } catch
        return
    stage := NumGet(lParam,24,"UInt")                 ; nmcd.dwDrawStage (x64)
    if (stage = 1)                                    ; CDDS_PREPAINT
        return 0x20                                   ; CDRF_NOTIFYITEMDRAW
    if (stage = 0x10001)                              ; CDDS_ITEMPREPAINT
        return 0x20                                   ; CDRF_NOTIFYSUBITEMDRAW
    if ((stage & 0x30001) = 0x30001) {                ; item + subitem
        sub := NumGet(lParam,88,"int")                ; NMLVCUSTOMDRAW.iSubItem (x64)
        if (sub >= 1 && sub <= 5) {
            fila := NumGet(lParam,56,"UPtr") + 1      ; nmcd.dwItemSpec (x64)
            if (fila >= 1 && fila <= ptsEd.temas.Length) {
                hex := ptsEd.temas[fila].swatches[sub]
                NumPut("UInt",_PtsColorRef(hex),lParam,84)       ; clrTextBk
                NumPut("UInt",_PtsTextoContraste(hex),lParam,80) ; clrText
            }
        }
        return 0x2                                    ; CDRF_NEWFONT
    }
}
_PtsColorRef(hex) {
    r := Integer("0x" SubStr(hex,1,2))
    g := Integer("0x" SubStr(hex,3,2))
    b := Integer("0x" SubStr(hex,5,2))
    return r | (g << 8) | (b << 16)
}
_PtsTextoContraste(hex) {
    r := Integer("0x" SubStr(hex,1,2))
    g := Integer("0x" SubStr(hex,3,2))
    b := Integer("0x" SubStr(hex,5,2))
    return (0.299 * r + 0.587 * g + 0.114 * b > 140) ? 0x000000 : 0xFFFFFF
}

; ════════════════════════════════════════════════════════════
;  KEY GRABBER — captura de combinaciones en controles Edit
; ════════════════════════════════════════════════════════════
_KgEst() {
    static m := Map()
    return m
}

_KgAttach(ctl, onCapture := "") {
    static hooked := false
    est := _KgEst(), muertos := []
    for h in est
        if !DllCall("IsWindow", "Ptr", h)
            muertos.Push(h)
    for h in muertos
        est.Delete(h)
    est[ctl.Hwnd] := Map("ctl",ctl, "cb",onCapture, "prev","", "last","", "tmp",false)
    ctl.OnEvent("Focus",_KgFocus)
    if !hooked {
        hooked := true
        OnMessage(0x100,_KgOnKey), OnMessage(0x104,_KgOnKey)
        OnMessage(0x101,_KgOnUp),  OnMessage(0x105,_KgOnUp)
        OnMessage(0x102,_KgOnChar), OnMessage(0x106,_KgOnChar)
    }
}

_KgFocus(ctl, *) {
    d := _KgEst()[ctl.Hwnd]
    d["prev"] := d["last"] := ctl.Value
    d["tmp"] := false
}

_KgMods() {
    p := []
    if GetKeyState("Ctrl")
        p.Push("Ctrl")
    if GetKeyState("Alt")
        p.Push("Alt")
    if GetKeyState("Shift")
        p.Push("Shift")
    if GetKeyState("LWin") || GetKeyState("RWin")
        p.Push("Win")
    return p
}

_KgJoin(p) {
    s := ""
    for x in p
        s .= (s = "" ? "" : "+") . x
    return s
}

_KgOnKey(wParam, lParam, msg, hwnd) {
    est := _KgEst()
    if !est.Has(hwnd)
        return
    d := est[hwnd], ctl := d["ctl"]
    vk := wParam
    if (lParam & 0x40000000)
        return 0
    mods := _KgMods()

    if (vk = 0x09 && !mods.Length)
        return
    if (vk = 0x10 || vk = 0x11 || vk = 0x12 || (vk >= 0xA0 && vk <= 0xA5) || vk = 0x5B || vk = 0x5C) {
        j := _KgJoin(mods)
        ctl.Value := (j = "" ? "…" : j "+…"), d["tmp"] := true
        return 0
    }
    if !mods.Length && !GetKeyState("Space") {
        if (vk = 0x1B) {
            ctl.Value := d["last"] := d["prev"], d["tmp"] := false
            _KgNotify(d, ctl.Value)
            return 0
        }
        if (vk = 0x08 || vk = 0x2E) {
            ctl.Value := d["last"] := "", d["tmp"] := false
            _KgNotify(d, "")
            return 0
        }
    }
    sc := (lParam >> 16) & 0xFF, ext := (lParam >> 24) & 1
    nombre := GetKeyName(Format("sc{:03X}", sc | (ext << 8)))
    if (nombre = "")
        nombre := GetKeyName(Format("vk{:X}", vk))
    if (nombre = "")
        return 0
    if (StrLen(nombre) = 1)
        nombre := StrUpper(nombre)
    if (vk != 0x20 && GetKeyState("Space"))
        mods.Push("Space")
    mods.Push(nombre)
    txt := _KgJoin(mods)
    ctl.Value := d["last"] := txt, d["tmp"] := false
    _KgNotify(d, txt)
    return 0
}

_KgOnUp(wParam, lParam, msg, hwnd) {
    est := _KgEst()
    if !est.Has(hwnd)
        return
    if (wParam = 0x09)
        return
    d := est[hwnd]
    if d["tmp"] && !_KgMods().Length {
        d["ctl"].Value := d["last"], d["tmp"] := false
    }
    return 0
}

_KgOnChar(wParam, lParam, msg, hwnd) {
    if _KgEst().Has(hwnd) && wParam != 9
        return 0
}

_KgNotify(d, txt) {
    cb := d["cb"]
    if cb
        cb(d["ctl"], txt)
}

; ═══ Indicadores de estado y ayuda contextual (pestaña 1) ═══
_PtsInd() {
    static m := Map()
    return m
}
_PtsIndInit(edA, indA, edR, indR, lbA, lbR) {
    m := _PtsInd()
    m["edAtajo"] := edA, m["indAtajo"] := indA, m["atajo"] := indA
    m["edRemap"] := edR, m["indRemap"] := indR, m["remap"] := indR
    try SendMessage(0x1501, 1, StrPtr("Requerido"), edA.Hwnd)      ; EM_SETCUEBANNER
    try SendMessage(0x1501, 1, StrPtr("Sin cambio"), edR.Hwnd)
    try SendMessage(0xD3, 2, 22 << 16, edA.Hwnd)                   ; EM_SETMARGINS: reserva el hueco del glifo
    try SendMessage(0xD3, 2, 22 << 16, edR.Hwnd)
    _AyudaReg(lbA, "Atajo CSP: combinación que CSP recibe para disparar este evento.")
    _AyudaReg(edA, "Atajo CSP: pulsa la combinación en el campo para capturarla.")
    _AyudaReg(lbR, "Remapeo Companion: tecla o gesto del lápiz/Companion que se traduce al atajo. Opcional.")
    _AyudaReg(edR, "Remapeo Companion (opcional).")
}
_PtsIndSet(clave, estado, tip := "") {
    ind := _PtsInd()
    if !ind.Has(clave)
        return
    static G := Map("req", ["*", "C0392B"], "opt", ["ℹ", "7F8C8D"], "auto", ["ℹ", "7F8C8D"]
                  , "warn", ["⚠", "D35400"], "ok", ["✓", "27AE60"], "", ["", "000000"])
    if !G.Has(estado)
        estado := ""
    c := ind[clave]
    c.SetFont("c" G[estado][2])
    c.Value := G[estado][1]
    _AyudaReg(c, tip)
}
_PtsAtajoColision(col, txt) {
    global ptsEd
    if (txt = "")
        return ""
    sel := ptsEd.lvEv.GetNext(0)
    Loop ptsEd.lvEv.GetCount()
        if (A_Index != sel && ptsEd.lvEv.GetText(A_Index, col) = txt)
            return RegExReplace(ptsEd.lvEv.GetText(A_Index, 1), "^⏸\s*")
    return ""
}
_PtsIndRefrescar(avisar := false) {
    global ptsEd
    try {
        m := _PtsInd()
        if !m.Has("edAtajo")
            return
        a := Trim(m["edAtajo"].Value), r := Trim(m["edRemap"].Value)
        sel := ptsEd.lvEv.GetNext(0)
        esPildora := sel ? InStr(ptsEd.lvEv.GetText(sel, 4), "Píldora") : false
    } catch
        return   ; GUI/controles destruidos: salir en silencio
    dupA := _PtsAtajoColision(2, a), dupR := _PtsAtajoColision(3, r)
    try {
        if (dupA != "")
            _PtsIndSet("atajo", "warn", "⚠ «" a "» ya lo usa: " dupA)
        else if (a = "" && !esPildora)
            _PtsIndSet("atajo", "req", "Obligatorio: sin atajo CSP este evento no se dispara.")
        else if (a = "")
            _PtsIndSet("atajo", "opt", "Opcional: este evento se dispara desde la píldora.")
        else
            _PtsIndSet("atajo", "")
        if (dupR != "")
            _PtsIndSet("remap", "warn", "⚠ «" r "» ya lo usa: " dupR)
        else if (r = "")
            _PtsIndSet("remap", "opt", "Opcional: sin remapeo se usa solo el atajo CSP.")
        else
            _PtsIndSet("remap", "")
    } catch
        return
    if (avisar && (dupA != "" || dupR != "")) {
        ToolTip("⚠ «" (dupA != "" ? a : r) "» ya lo usa: " (dupA != "" ? dupA : dupR))
        SetTimer(() => ToolTip(), -2500)
    }
}

_PtsIndOk(*) {
    try {
        m := _PtsInd()
        if !m.Has("edAtajo")
            return
        for k, ed in [["atajo", m["edAtajo"]], ["remap", m["edRemap"]]] {
            indCtl := m["ind" (ed[1] = "atajo" ? "Atajo" : "Remap")]
            if (Trim(ed[2].Value) != "" && !InStr(indCtl.Value, "⚠"))
                _PtsIndSet(ed[1], "ok")
        }
    } catch
        return   ; no reprogramar el refresco si la GUI ya no existe
    SetTimer(_PtsIndRefrescar, -1800)
}

_PtsAtajoAviso(ctl, txt) {
    SetTimer(_PtsIndRefrescar.Bind(true), -40)
}

; Restaura el texto del estado; seguro si el control ya fue destruido
_PtsStRestaurar(st, prev) {
    try st.Value := prev
}

_PtsGuardarCambios(*) {
    try _PtsEvRemapGuardar()
    try GuardarPuntos()
    try _RgGuardarMirror()
    try _CompInvalidar()
    try CargarPuntos()
    try _PillSincronizarDinamicas()
    try _RemapCargarHotkeys()
    try _EspacialCargar()
    SetTimer(_PtsIndOk, -60)
    try {
        st := _PtsInd().Get("st", 0)
        if st {
            prev := st.Value
            st.Value := "✓ Cambios guardados"
            SetTimer(_PtsStRestaurar.Bind(st, prev), -2200)
        }
    }
    _SonarUI("calib")
}

; ════════════════════════════════════════════════════════════
;  lvEv — helpers de INI / selección
; ════════════════════════════════════════════════════════════
_PtsEvSecciones(ini) {
    out := []
    try txt := IniRead(ini)
    catch
        return out
    Loop Parse, txt, "`n", "`r"
        if RegExMatch(A_LoopField, "^(EventosCustom|EventosPendientes|Remapeos|Particularidades|HudEventos|HudSonido|HudTextos|HudDuracion|HudDuraciones|Rangos|Puntos|ZonasEstado)")
            out.Push(A_LoopField)
    return out
}

; Claves de una sección que pertenecen a `slug`. Una clave se atribuye al slug
; MÁS LARGO que la reconoce (evita que "pincel" se lleve las de "pincel_copia").
_PtsEvIniClaves(ini, sec, slug) {
    out := []
    try txt := IniRead(ini, sec)
    catch
        return out
    pat := "i)^([^_]+_)?\Q" slug "\E(_[^_]+)?$"
    mas := []
    for d in _PtsEventosDefs()
        if (d[1] != slug && StrLen(d[1]) > StrLen(slug) && InStr(d[1], slug))
            mas.Push("i)^([^_]+_)?\Q" d[1] "\E(_[^_]+)?$")
    Loop Parse, txt, "`n", "`r" {
        p := InStr(A_LoopField, "=")
        if !p
            continue
        k := SubStr(A_LoopField, 1, p - 1)
        if !RegExMatch(k, pat) && k != ("HUD_ev_" slug)
            continue
        ajeno := false
        for r in mas
            if RegExMatch(k, r) {
                ajeno := true
                break
            }
        if !ajeno
            out.Push(k)
    }
    return out
}

; Formato confirmado: [EventosCustom] slug=nombre|grupo  → comprobación exacta
_PtsEvEsCustom(ini, slug) => IniRead(ini, "EventosCustom", slug, "") != ""

_PtsEvNombreDe(slug) {
    for d in _PtsEventosDefs()
        if (d[1] = slug)
            return d[2]
    return ""
}

_PtsEvSlugDeFila(row) {
    global ptsEd
    defs := _PtsEventosDefs()
    if (HasProp(ptsEd, "mapFilas") && IsObject(ptsEd.mapFilas) && ptsEd.mapFilas.Length >= row) {
        idx := ptsEd.mapFilas[row]
        if (IsInteger(idx) && idx >= 1 && idx <= defs.Length)
            return defs[idx][1]
    }
    txt := RegExReplace(ptsEd.lvEv.GetText(row, 1), "^⏸\s*"), best := "", bl := 0
    for d in defs {
        if (txt = d[2])
            return d[1]
        if (InStr(txt, d[2]) && StrLen(d[2]) > bl)
            best := d[1], bl := StrLen(d[2])
    }
    return best
}

_PtsEvSlugsSel() {
    global ptsEd
    out := [], r := 0
    while (r := ptsEd.lvEv.GetNext(r)) {
        s := _PtsEvSlugDeFila(r)
        if (s != "")
            out.Push(s)
    }
    return out
}

_PtsEvSeleccionarSlug(slug) {
    global ptsEd
    Loop ptsEd.lvEv.GetCount()
        if (_PtsEvSlugDeFila(A_Index) = slug) {
            ptsEd.lvEv.Modify(0, "-Select")
            ptsEd.lvEv.Modify(A_Index, "Select Focus Vis")
            return
        }
}

; ════════════════════════════════════════════════════════════
;  lvEv — menú contextual
; ════════════════════════════════════════════════════════════
_PtsEvContextMenu(lv, item, isRight, x, y) {
    if (item > 0 && lv.GetNext(item - 1) != item) {
        lv.Modify(0, "-Select")
        lv.Modify(item, "Select Focus")
    }
    ; Clic derecho en zona vacía: solo "Nuevo evento" (ya no opera sobre selección vieja)
    hay := (item > 0 || !isRight) && lv.GetNext(0) > 0
    m := Menu()
    m.Add("➕ Nuevo evento", (*) => _PtsNuevoEvento())
    m.Add()
    m.Add("📋 Duplicar / Replicar evento", (*) => _PtsEvDuplicar())
    m.Add("⏸ Pausar / Activar evento", (*) => _PtsEvTogglePausa())
    m.Add("🗑 Eliminar evento", (*) => _PtsEvEliminar())
    m.Add("📁 Guardar en grupo", _PtsEvMenuGrupos())
    if !hay {
        m.Disable("📋 Duplicar / Replicar evento")
        m.Disable("⏸ Pausar / Activar evento")
        m.Disable("🗑 Eliminar evento")
        m.Disable("📁 Guardar en grupo")
    }
    m.Show()   ; sin coordenadas: x,y del evento son relativas al GUI y Show() las toma de la ventana activa
}

_PtsEvEliminar(*) {
    ini := _PosGuiIniPath()
    slugs := _PtsEvSlugsSel()
    if !slugs.Length
        return
    msg := "¿Eliminar " slugs.Length " evento(s) definitivamente?`n`nSe borrarán atajos, remapeos, formato HUD, sonido, particularidades y textos."
    if (MsgBox(msg, "Eliminar evento", "YesNo Icon!") != "Yes")
        return
    for s in slugs {
        try _PtsEvLimpiarPend(s)
        try _PillDestruirDinamica(s)
        try _PtsEvEliminadosAgregar(ini, s)
        try IniDelete(ini, "EventosPausados", s)
        try IniDelete(ini, "EventosGrupo", s)
        try IniDelete(ini, "EventosCustom", s)
        try _PtsEvListaQuitar(ini, s)
        for sec in _PtsEvSecciones(ini)
            for k in _PtsEvIniClaves(ini, sec, s)
                try IniDelete(ini, sec, k)
        defs := _PtsEventosDefs(), i := defs.Length
        while (i >= 1) {
            if (defs[i][1] = s)
                defs.RemoveAt(i)
            i--
        }
    }
    try ptsEd.lvEv.Modify(0, "-Select -Focus")
    ptsEd.evSel := 0
    _PillSincronizarDinamicas()
    _PtsEvFilas()
}

_PtsEvEliminadosAgregar(ini, slug) {
    IniWrite("1", ini, "EventosEliminados", slug)
    lista := IniRead(ini, "EventosEliminados", "lista", "")
    items := Map()
    for c in StrSplit(lista, ",", " `t")
        if (c != "")
            items[c] := 1
    items[slug] := 1
    out := ""
    for k in items
        out .= (out = "" ? "" : ",") k
    IniWrite(out, ini, "EventosEliminados", "lista")
}

_PtsEvDuplicar(*) {
    ini := _PosGuiIniPath()
    ultimo := ""
    for s in _PtsEvSlugsSel() {
        orig := _PtsEvNombreDe(s)
        if (orig = "")
            continue
        grupo := ""
        for d in _PtsEventosDefs()
            if (d[1] = s)
                grupo := d[3]
        nombre := orig " (Copia)"
        n := _PtsSlugUnico(nombre)
        for sec in _PtsEvSecciones(ini)
            for k in _PtsEvIniClaves(ini, sec, s) {
                v := IniRead(ini, sec, k, "")
                if (sec = "EventosCustom")
                    v := StrReplace(v, orig, nombre)
                nk := RegExReplace(k, "i)(^|_)\Q" s "\E(_|$)", "${1}" n "${2}",, 1)
                IniWrite(v, ini, sec, nk)
            }
        if !_PtsEvEsCustom(ini, n) {
            IniWrite(nombre "|" grupo, ini, "EventosCustom", n)
            _PtsEventosDefs().Push([n, nombre, grupo])
        }
        ultimo := n
    }
    _PtsEvFilas()
    if (ultimo != "")
        _PtsEvSeleccionarSlug(ultimo)
}

_PtsEvListaQuitar(ini, slug) {
    lista := IniRead(ini, "EventosCustom", "lista", "")
    if (Trim(lista) = "")
        return
    out := ""
    for c in StrSplit(lista, ",", " `t") {
        if (c != "" && c != slug)
            out .= (out = "" ? "" : ",") c
    }
    if (out != Trim(lista))
        IniWrite(out, ini, "EventosCustom", "lista")
}

_PtsEvGrupos() {
    return ["No definidos", "Pinceles y Trazos", "Borradores y Mezcla"
          , "Color y Paleta", "Selección", "Lienzo y Reglas", "Capas y Archivo", "Personalizados"]
}

_PtsEvPausado(slug) {
    return IniRead(_PosGuiIniPath(), "EventosPausados", slug, "0") = "1"
}

_PtsEvPausadosMapa() {
    m := Map()
    try {
        sec := IniRead(_PosGuiIniPath(), "EventosPausados")
        for lin in StrSplit(sec, "`n", "`r") {
            p := InStr(lin, "=")
            if (p && Trim(SubStr(lin, p + 1)) = "1")
                m[Trim(SubStr(lin, 1, p - 1))] := true
        }
    }
    return m
}

_PtsEvTogglePausa(*) {
    ini := _PosGuiIniPath()
    slugs := _PtsEvSlugsSel()
    if !slugs.Length
        return
    ; Selección mezclada: todos pasan al estado contrario al de la primera fila
    pausar := !_PtsEvPausado(slugs[1])
    for s in slugs {
        if pausar {
            IniWrite(1, ini, "EventosPausados", s)
            _ModToggleReset(s)
        } else
            try IniDelete(ini, "EventosPausados", s)
    }
    _PtsEvFilas()
}

_PtsEvMenuGrupos() {
    sub := Menu()
    for gr in _PtsEvGrupos()
        sub.Add(gr, _PtsEvMoverGrupo.Bind(gr))
    return sub
}

_PtsEvGuardarEnGrupo(*) {
    _PtsEvMenuGrupos().Show()
}

_PtsEvMoverGrupo(grupo, *) {
    ini := _PosGuiIniPath()
    slugs := _PtsEvSlugsSel()
    if !slugs.Length
        return
    defs := _PtsEventosDefs()
    for s in slugs {
        for e in defs {
            if (e[1] = s) {
                e[3] := grupo
                break
            }
        }
        IniWrite(grupo, ini, "EventosGrupo", s)
    }
    _PtsEvFilas()   ; una sola vez al final
}

_PtsFondoContextMenu(args*) {
    global ptsEd
    ctrl := (args.Length >= 6) ? args[2] : (args.Length >= 5 ? args[1] : 0)
    if IsObject(ctrl) {
        ; No pisar el menú nativo de ListView ni controles interactivos de entrada
        if (ptsEd.HasProp("lvEv") && ctrl.Hwnd = ptsEd.lvEv.Hwnd)
            return
        if (ctrl.Type ~= "^(Edit|DropDownList|ComboBox|Button|CheckBox)$")
            return
    }
    m := Menu()
    m.Add("➕ Nuevo evento", (*) => _PtsNuevoEvento())
    m.Show()
}

; ════════════════════════════════════════════════════════════
;  lvEv — doble clic contextual por columna
; ════════════════════════════════════════════════════════════
_PtsEvColDeClick(lv) {
    pt := Buffer(8), DllCall("GetCursorPos", "Ptr", pt)
    DllCall("ScreenToClient", "Ptr", lv.Hwnd, "Ptr", pt)
    hti := Buffer(24, 0)
    NumPut("Int", NumGet(pt, 0, "Int"), "Int", NumGet(pt, 4, "Int"), hti, 0)
    SendMessage(0x1039, 0, hti, lv.Hwnd)
    return NumGet(hti, 16, "Int") + 1
}

_PtsEvDobleClickCol(lv, row) {
    global ptsEd
    if !row
        return
    switch _PtsEvColDeClick(lv) {
        case 2:  _PtsEvEnfocarCampo(ptsEd.edAtajo)
        case 3:  _PtsEvEnfocarCampo(ptsEd.edRemap)
        default: _PtsEvDobleClick(lv, row)
    }
}

_PtsEvEnfocarCampo(ctl, enAcordeon := true) {
    global ACC
    if (enAcordeon && IsSet(ACC) && IsObject(ACC)) {
        p := _AccPanel("p1")
        if (p && !p.abierto) {
            p.abierto := true
            _AccRelayout()
        }
    }
    try ctl.Focus()
    ToolTip("⌨ Pulsa la combinación · Esc cancela · ⌫ limpia")
    SetTimer(() => ToolTip(), -2000)
}
