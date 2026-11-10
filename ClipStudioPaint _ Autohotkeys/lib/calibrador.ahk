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
        ptsModo.btnN.Text := ((sel = 1) ? "● " : "○ ") . "NORMAL · Modo 1" . ((vivo = 1) ? "  [activo en CSP]" : "")
        ptsModo.btnE.Text := ((sel = 2) ? "● " : "○ ") . "ENFOQUE · Modo 2" . ((vivo = 2) ? "  [activo en CSP]" : "")
        ptsModo.btnN.SetFont((sel = 1) ? "s9 bold" : "s9 norm")
        ptsModo.btnE.SetFont((sel = 2) ? "s9 bold" : "s9 norm")
    }
    try ptsModo.barN.Value := (sel = 1) ? 100 : 0     ; tira azul bajo el botón elegido
    try ptsModo.barE.Value := (sel = 2) ? 100 : 0
    try ptsEd.g.Title := "📍 Calibración · rangos, avisos y sistema  ·  editando " . ((sel = 2) ? "ENFOQUE · Modo 2" : "NORMAL · Modo 1")
}
PtsModo_Set(m) {
    global ptsModo,ptsEd
    m := (m = 2) ? 2 : 1
    if (ptsModo.sel = m || ptsEd.dibujando || ptsEd.capturando) {
        _PtsModoMarcar()
        return
    }
    ptsModo.edit := true
    _PtsModoCambiar(m)
}
_PtsModoCambiar(m) {
    global ptsModo,ptsEd
    try GuardarPuntos(false)      ; vuelca el modo que se abandona (ptsModo.sel aún es el anterior)
    ptsModo.sel := m
    ptsModo.edit := true
    CargarPuntos()                ; PUNTOS / ZONAS / HIST_ALTO pasan al modo elegido
    _PtsRefrescar()               ; RecalcularZonas + filas del ListView en caliente
    _PtsModoMarcar()
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
    _AyudaEstado().mapa[ctrl.Hwnd] := texto
}

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
    global PERFIL,PERFILES,ESC,AVISO_ESC,panelBlk,ESTAB_ALPHA_H,ESTAB_ALPHA_F
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
    tb := g.Add("Tab3",uiP(12,12,TW,TH),["📐 Zonas y rangos","🔔 Eventos / HUD","⚙ Sistema y perfiles","🎨 Paleta de temas","🪟 Nuevas ventanas"])
    lyM := [_PtsLayCuenta(g)]
    ; ---------------- Pestaña 1: zonas y rangos ----------------
    tb.UseTab(1)
    g.Add("Text",uiP(x0,50,cw,34),"Dibuja cada zona arrastrando el lápiz sobre la pantalla (un clic = punto). Doble toque en una fila = dibujar. Los puntos P1..P32 se recalculan solos para los demás scripts.")
    bModoN := g.Add("Button",uiP(x0,88,cw // 2,30),"")
    bModoE := g.Add("Button",uiP(x0 + cw // 2,88,cw // 2,30),"")
    ptsModo.btnN := bModoN
    ptsModo.btnE := bModoE
    ptsModo.barN := g.Add("Progress",uiP(x0,118,cw // 2,4) . " -Theme c4A90E2 BackgroundF3F3F3",0)
    ptsModo.barE := g.Add("Progress",uiP(x0 + cw // 2,118,cw // 2,4) . " -Theme c4A90E2 BackgroundF3F3F3",0)
    _PtsModoMarcar()
    bModoN.OnEvent("Click",(*) => PtsModo_Set(1))
    bModoE.OnEvent("Click",(*) => PtsModo_Set(2))
    lv := g.Add("ListView",uiP(x0,124,cw,206) . " -Multi NoSortHdr Grid",["Zona","Tipo","X","Y","Ancho","Alto"])
    for d in defs
        lv.Add("",d.n,(d.t = "punto") ? "Punto" : "Rango","","","","")
    lv.ModifyCol(1,uiS(284))
    lv.ModifyCol(2,uiS(70))
    Loop 4
        lv.ModifyCol(2 + A_Index,uiS(80))
    ; --- grupo: dibujar ---
    g.Add("GroupBox",uiP(x0,338,cw,58),"✏ Dibujar la zona seleccionada")
    bw := (cw - 24 - 24) // 4
    bDib := g.Add("Button",uiP(x0 + 12,362,bw,28),"✏ Dibujar con lápiz")
    bCad := g.Add("Button",uiP(x0 + 12 + (bw + 8),362,bw,28),"⏩ Dibujar en cadena")
    bVer := g.Add("Button",uiP(x0 + 12 + 2 * (bw + 8),362,bw,28),"👁 Ver zonas")
    bDef := g.Add("Button",uiP(x0 + 12 + 3 * (bw + 8),362,bw,28),"↺ Por defecto")
    ; --- grupo: valores numéricos ---
    g.Add("GroupBox",uiP(x0,404,cw,60),"🔢 Valores de la zona seleccionada")
    yv := 428
    g.Add("Text",uiP(x0 + 14,yv,16,26) . " +0x200","X")
    eX := g.Add("Edit",uiP(x0 + 32,yv,86,26),"")
    g.Add("Text",uiP(x0 + 132,yv,16,26) . " +0x200","Y")
    eY := g.Add("Edit",uiP(x0 + 150,yv,86,26),"")
    g.Add("Text",uiP(x0 + 250,yv,50,26) . " +0x200","Ancho")
    eW := g.Add("Edit",uiP(x0 + 302,yv,86,26),"")
    g.Add("Text",uiP(x0 + 402,yv,36,26) . " +0x200","Alto")
    eH := g.Add("Edit",uiP(x0 + 440,yv,86,26),"")
    bAp := g.Add("Button",uiP(x0 + cw - 12 - 140,yv - 1,140,28),"✔ Aplicar valores")
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
    bLN1 := g.Add("Button",uiP(x0 + 126,yg2 - 1,120,28),"💾 Modo 1 (Norm)")
    bLE1 := g.Add("Button",uiP(x0 + 252,yg2 - 1,120,28),"💾 Modo 2 (Enf)")
    bLA1 := g.Add("Button",uiP(x0 + 378,yg2 - 1,90,28),"▶ Aplicar")
    bTog1 := g.Add("Button",uiP(x0 + 474,yg2 - 1,190,28),"🎯 Alternar (1 ⇄ 2)")
    bLN1.OnEvent("Click",(*) => _CapturarLayout("Normal"))
    bLE1.OnEvent("Click",(*) => _CapturarLayout("Enfoque"))
    bLA1.OnEvent("Click",(*) => _AplicarLayoutPaneles(ptsModo.edit ? ((ptsModo.sel = 2) ? "Enfoque" : "Normal") : (enfoque.activo ? "Enfoque" : "Normal")))
    bTog1.OnEvent("Click",(*) => AccionEnfoque())
    ; ---------------- Pestaña 2: eventos / HUD ----------------
    tb.UseTab(2)
    lyM.Push(_PtsLayCuenta(g))
    g.Add("Text",uiP(x0,52,360,22) . " +0x200","Elige formato, prioridad y opacidad por evento:")
    g.Add("Text",uiP(x0 + cw - 290,52,54,22) . " +0x200 Right","Grupo:")
    ddGrupo := g.Add("DropDownList",uiP(x0 + cw - 230,50,230) . " Choose1",["📁 Todos los grupos","Pinceles y Trazos","Borradores y Mezcla","Color y Paleta","Selección","Lienzo y Reglas","Capas y Archivo"])
    lvEv := g.Add("ListView",uiP(x0,80,cw,232) . " +Multi NoSortHdr Grid",["Acción (evento)","Grupo","Formato","Prioridad","Opac.","Duración"])
    lvEv.ModifyCol(1,uiS(262))
    lvEv.ModifyCol(2,uiS(110))
    lvEv.ModifyCol(3,uiS(78))
    lvEv.ModifyCol(4,uiS(78))
    lvEv.ModifyCol(5,uiS(58))
    lvEv.ModifyCol(6,uiS(80))
    ; --- grupo: configuración del evento ---
    g.Add("GroupBox",uiP(x0,320,cw,128),"⚙ Configuración del evento seleccionado")
    r1 := 344
    g.Add("Text",uiP(x0 + 14,r1,58,26) . " +0x200","Formato:")
    ddF := g.Add("DropDownList",uiP(x0 + 74,r1,90) . " Choose1",["Moderno","Bruto","Desactivado"])
    g.Add("Text",uiP(x0 + 172,r1,38,26) . " +0x200","Zona:")
    ddZ := g.Add("DropDownList",uiP(x0 + 212,r1,70) . " Choose3",["Alta","Media","Baja"])
    g.Add("Text",uiP(x0 + 290,r1,40,26) . " +0x200","Opac:")
    ddOp := g.Add("DropDownList",uiP(x0 + 332,r1,98) . " Choose2",["100% (Máx)","70% (Med)","40% (Bajo)"])
    bEvProbar := g.Add("Button",uiP(x0 + 438,r1 - 1,80,28),"🔔 Probar")
    bEvAnclar := g.Add("Button",uiP(x0 + 524,r1 - 1,80,28),"📌 Anclar")
    bEvReub   := g.Add("Button",uiP(x0 + 610,r1 - 1,80,28),"📍 Reubicar")
    r2 := 380
    g.Add("Text",uiP(x0 + 14,r2,82,26) . " +0x200","Texto evento:")
    eTxtEv := g.Add("Edit",uiP(x0 + 98,r2,380,26),"")
    bTxtEv := g.Add("Button",uiP(x0 + 486,r2 - 1,124,28),"✏ Guardar texto")
    bTxtReset := g.Add("Button",uiP(x0 + 616,r2 - 1,74,28),"↺ Reset")
    bTxtEv.OnEvent("Click",_PtsEvTextoGuardar)
    bTxtReset.OnEvent("Click",_PtsEvTextoReset)
    r3 := 416
    g.Add("Text",uiP(x0 + 14,r3,90,26) . " +0x200","Duración (ms):")
    eDurEv := g.Add("Edit",uiP(x0 + 106,r3,70,26),"")
    bDurEv := g.Add("Button",uiP(x0 + 184,r3 - 1,90,28),"⏱ Aplicar")
    lblDurEfec := g.Add("Text",uiP(x0 + 284,r3,400,26) . " +0x200 cGray","Efectiva: —")
    bDurEv.OnEvent("Click",_PtsEvDurAplicar)
    ; --- grupo: duraciones por prioridad (Alta: 3 ms/300 ms, Media: 5 ms/500 ms, Baja: 4 ms/400 ms) ---
    g.Add("GroupBox",uiP(x0,456,cw,62),"⏱ Duraciones de aviso por prioridad (ms / s)")
    rd := 480
    g.Add("Text",uiP(x0 + 14,rd,40,26) . " +0x200","Alta:")
    eDurA := g.Add("Edit",uiP(x0 + 56,rd,60,26), IniRead(_PosGuiIniPath(),"HudDuraciones" PERFIL,"duracion_alta","300"))
    g.Add("Text",uiP(x0 + 130,rd,50,26) . " +0x200","Media:")
    eDurM := g.Add("Edit",uiP(x0 + 182,rd,60,26), IniRead(_PosGuiIniPath(),"HudDuraciones" PERFIL,"duracion_media","500"))
    g.Add("Text",uiP(x0 + 256,rd,40,26) . " +0x200","Baja:")
    eDurB := g.Add("Edit",uiP(x0 + 298,rd,60,26), IniRead(_PosGuiIniPath(),"HudDuraciones" PERFIL,"duracion_baja","400"))
    bDurGuardar := g.Add("Button",uiP(x0 + 372,rd - 1,130,28),"💾 Guardar dur.")
    g.Add("Text",uiP(x0 + 512,rd,180,26) . " +0x200 cGray","(def: 3, 5, 4 ms/s)")
    bDurGuardar.OnEvent("Click", (*) => _GuardarDuracionesHUD(eDurA.Value, eDurM.Value, eDurB.Value))
    g.Add("Text",uiP(x0,524,cw,18) . " cGray","💡 Edita el texto o duración directamente arriba. Los desactivados bajan al final.")
    stEv := g.Add("Text",uiP(x0,546,cw,30) . " BackgroundE6E0F5 c2A2140 +0x200","▶ Selecciona un evento para ver su atajo real.")
    stEv.SetFont("s" fs " bold","Segoe UI")
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
    g.Add("GroupBox",uiP(xL,192,wL,124),"🧷 Botones del script y paneles de CSP")
    bMover := g.Add("Button",uiP(xL + 14,216,168,28),panelBlk.locked ? "🔓 Mover botones" : "🔒 Fijar botones")
    bReub := g.Add("Button",uiP(xL + 190,216,168,28),"↺ Reubicar botones")
    g.Add("Text",uiP(xL + 14,252,340,20) . " cGray","Layout de paneles de CSP (guardar / aplicar):")
    bLN := g.Add("Button",uiP(xL + 14,276,108,28),"💾 Normal")
    bLE := g.Add("Button",uiP(xL + 128,276,116,28),"💾 Enfoque")
    bLA := g.Add("Button",uiP(xL + 250,276,100,28),"▶ Aplicar")
    ; --- grupo: deslizador de estabilización ---
    g.Add("GroupBox",uiP(xL,324,wL,100),"🎚 Deslizador de estabilización")
    g.Add("Text",uiP(xL + 14,348,170,26) . " +0x200","Opacidad horizontal (%):")
    eAlpha := g.Add("Edit",uiP(xL + 188,348,60,26),Round(ESTAB_ALPHA_H / 2.55))
    g.Add("Text",uiP(xL + 256,348,108,26) . " +0x200 cGray","(ancha = horizontal)")
    g.Add("Text",uiP(xL + 14,382,170,26) . " +0x200","Opacidad de enfoque (%):")
    eAlphaF := g.Add("Edit",uiP(xL + 188,382,60,26),Round(ESTAB_ALPHA_F / 2.55))
    ; --- grupo: backup ---
    g.Add("GroupBox",uiP(xL,432,wL,112),"🗂 Copia de seguridad de posiciones_gui.ini")
    bBak := g.Add("Button",uiP(xL + 14,456,166,28),"💾 Crear backup")
    bRes := g.Add("Button",uiP(xL + 188,456,166,28),"↩ Restaurar último")
    lblBak := g.Add("Text",uiP(xL + 14,494,342,40) . " cGray","Sin backups todavía.")
    bBak.OnEvent("Click",_PtsBackupIni)
    bRes.OnEvent("Click",_PtsRestaurarIni)
    ; --- grupo (columna derecha): botón HUB ---
    g.Add("GroupBox",uiP(xR,50,wR,204),"🧩 Botón HUB — embeber botones")
    hubItems := [["lock","Bloquear"],["frente","Frente"],["puntos","Calibrador"],["estab","Estabilizador"],["reload","Recargar"],["ds","Slider"],["cc","Color"],["ar","Acceso R."],["hc","Hist. Color"],["flip","Voltear"],["enfoque","Enfoque"]]
    for i, it in hubItems {
        emb := (hubGui.embebidos.Has(it[1]) && hubGui.embebidos[it[1]]) ? 1 : 0
        chk := g.Add("CheckBox",uiP(xR + 16 + Mod(i - 1,2) * 150,78 + ((i - 1) // 2) * 28,140,24) . " Checked" emb,it[2])
        chk.OnEvent("Click",_PtsHubToggle.Bind(it[1]))
    }
    g.Add("Text",uiP(xR,260,wR,34) . " cGray","Acceso directo por clic derecho sobre el botón HUB.")
    ; ---------------- Pestaña 4: paleta de temas (lista única con scroll) ----------------
    tb.UseTab(4)
    lyM.Push(_PtsLayCuenta(g))
    g.Add("Text",uiP(x0,50,cw,34),"Elige la paleta de colores y estilos para los botones del script, los colores de acento y los avisos en pantalla. Se guarda en theme.ini y se aplica al instante.")
    temaLbl := g.Add("Text",uiP(x0,86,cw,22) . " +0x200","")
    temaLbl.SetFont("s" fs " bold","Segoe UI")
    temas := _TemaPerfiles()
    ; [TEMA-LISTA] Una sola lista desplazable (misma familia que Zonas y rangos), sin paginar.
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
    lyM.Push(_PtsLayCuenta(g))                       ; lyM[5] = fin de la pestana 4
    ; ---------------- Pestaña 5: nuevas ventanas ----------------
    tb.UseTab(5)
    g.Add("Text",uiP(x0,50,340,24) . " +0x200","Modo de visibilidad para ventanas:")
    ddNvModo := g.Add("DropDownList",uiP(x0 + 350,50,cw - 350) . " Choose" (NvEstado().modoGlobal = "desact_25" || NvEstado().modoGlobal = "total" ? 2 : 1),["Hover (aparece al pasar el lápiz)","Ocultar total (25 %, bloqueada)"])
    ddNvModo.OnEvent("Change",(c,*) => NvSetModo(c.Value = 2 ? "total" : "hover"))

    g.Add("GroupBox",uiP(x0,80,cw,218),"📐 Zonas de lienzos y punto de pestaña")
    lvNv := g.Add("ListView",uiP(x0 + 12,102,cw - 24,142) . " -Multi NoSortHdr Grid",["Elemento","Tipo","X","Y","Ancho","Alto","Estado"])
    lvNv.ModifyCol(1,uiS(190))
    lvNv.ModifyCol(2,uiS(80))
    Loop 4
        lvNv.ModifyCol(2 + A_Index,uiS(70))
    lvNv.ModifyCol(7,uiS(95))
    ptsEd.lvNv := lvNv
    lvNv.OnEvent("ItemSelect",_NvPanSel)
    lvNv.OnEvent("DoubleClick",_NvPanDobleClick)

    bwNv := (cw - 24 - 24) // 4
    bNvDib := g.Add("Button",uiP(x0 + 12,254,bwNv,28),"➕ Dibujar zona")
    bNvDib.OnEvent("Click",(*) => _NvPanDibujar())
    bNvBor := g.Add("Button",uiP(x0 + 12 + (bwNv + 8),254,bwNv,28),"🗑 Borrar zona")
    bNvBor.OnEvent("Click",(*) => _NvPanBorrar())
    bNvPes := g.Add("Button",uiP(x0 + 12 + 2 * (bwNv + 8),254,bwNv,28),"🎯 Calibrar pestaña")
    bNvPes.OnEvent("Click",(*) => _NvPanPestana())
    bNvVer := g.Add("Button",uiP(x0 + 12 + 3 * (bwNv + 8),254,bwNv,28),ptsEd.ovl.Length ? "❌ Ocultar zonas" : "👁 Ver zonas")
    bNvVer.OnEvent("Click",_PtsToggleVerZonas)
    ptsEd.bNvVer := bNvVer

    g.Add("GroupBox",uiP(x0,306,cw,60),"🔢 Valores de la zona seleccionada")
    yvNv := 330
    g.Add("Text",uiP(x0 + 14,yvNv,16,26) . " +0x200","X")
    eNvX := g.Add("Edit",uiP(x0 + 32,yvNv,86,26),"")
    g.Add("Text",uiP(x0 + 132,yvNv,16,26) . " +0x200","Y")
    eNvY := g.Add("Edit",uiP(x0 + 150,yvNv,86,26),"")
    g.Add("Text",uiP(x0 + 250,yvNv,50,26) . " +0x200","Ancho")
    eNvW := g.Add("Edit",uiP(x0 + 302,yvNv,86,26),"")
    g.Add("Text",uiP(x0 + 402,yvNv,36,26) . " +0x200","Alto")
    eNvH := g.Add("Edit",uiP(x0 + 440,yvNv,86,26),"")
    bNvAp := g.Add("Button",uiP(x0 + cw - 12 - 140,yvNv - 1,140,28),"✔ Aplicar valores")
    bNvAp.OnEvent("Click",_NvPanAplicarValores)
    ptsEd.eNvX := eNvX
    ptsEd.eNvY := eNvY
    ptsEd.eNvW := eNvW
    ptsEd.eNvH := eNvH

    stNvZonas := g.Add("Text",uiP(x0,372,cw,22) . " +0x200 cGray",_NvPanTexto())
    ptsEd.stNvZonas := stNvZonas
    g.Add("Text",uiP(x0,396,cw,40) . " cGray","💡 Doble clic en una fila = dibujar esa zona con el lápiz. '👁 Ver zonas' muestra los recuadros transparentes sobre la pantalla. 'Ctrl+Alt+Shift+F9' invoca y 'Ctrl+Alt+Shift+F8' alterna Hover/Ocultar.")
    ; ---------------- barra inferior ----------------
    tb.UseTab(0)
    lyM.Push(_PtsLayCuenta(g))                       ; lyM[6] = fin de la pestana 5
    st := g.Add("Text",uiP(12,12 + TH + 8,TW,36),"")
    byb := 12 + TH + 52
    bOk := g.Add("Button",uiP(12,byb,180,34) . " Default","💾 Guardar y cerrar")
    bRei := g.Add("Button",uiP(198,byb,170,34),"🔄 Reiniciar script")
    bPin := g.Add("Button",uiP(374,byb,190,34),ptsTop ? "📌 Al frente" : "🪟 Normal")
    bPin.OnEvent("Click",_PtsTopToggle)
    for par in [
        [bModoN, "Edita las zonas del modo Normal (1)"],
        [bModoE, "Edita las zonas del modo Enfoque (2)"],
        [lv, "Catálogo de zonas y rangos: selecciona una para editarla"],
        [bDib, "Dibuja con el lápiz la zona seleccionada"],
        [bCad, "Dibuja varias zonas seguidas sin volver al panel"],
        [bVer, "Muestra sobre la pantalla las zonas definidas"],
        [bDef, "Devuelve la zona seleccionada a su valor por defecto"],
        [eX, "Posición horizontal (X) de la zona, en píxeles"],
        [eY, "Posición vertical (Y) de la zona, en píxeles"],
        [eW, "Ancho de la zona, en píxeles"],
        [eH, "Alto de la zona, en píxeles"],
        [bAp, "Aplica los valores X, Y, ancho y alto escritos"],
        [dx, "Desplazamiento horizontal (ΔX) a sumar a la zona"],
        [dy, "Desplazamiento vertical (ΔY) a sumar a la zona"],
        [bDelta, "Mueve la zona seleccionada según ΔX y ΔY"],
        [bLN1, "Guarda el layout actual de CSP como modo 1 (Normal)"],
        [bLE1, "Guarda el layout actual de CSP como modo 2 (Enfoque)"],
        [bLA1, "Aplica a CSP el layout guardado del modo actual"],
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
        [eAlpha, "Opacidad horizontal del estabilizador (%)"],
        [eAlphaF, "Opacidad del estabilizador en modo enfoque (%)"],
        [bBak, "Crea una copia de seguridad de posiciones_gui.ini"],
        [bRes, "Restaura la última copia de seguridad del INI"],
        [lvTema, "Paletas de temas: selecciona una para previsualizarla"],
        [bTemaAp, "Aplica la paleta de temas seleccionada"]
    ]
        AyudaRegistrar(par[1], par[2])
    AyudaRegistrar(bOk, "Guarda los cambios y cierra el calibrador")
    AyudaRegistrar(bRei, "Reinicia el script para aplicar la configuración")
    AyudaRegistrar(bPin, "Alterna ventana Siempre al frente o Modo normal")
    AyudaRegistrar(ddNvModo, "Hover: la ventana aparece al pasar el lápiz. Ocultar total: queda al 25 % y bloqueada")
    AyudaRegistrar(bNvDib, "Dibuja con el lápiz la siguiente zona libre para una ventana de lienzo")
    AyudaRegistrar(bNvBor, "Borra la última zona dibujada")
    AyudaRegistrar(bNvPes, "Marca dónde aparece la pestaña nueva para desacoplarla sola")
    ptsEd.ly.bTop := bPin
    ptsEd.g := g
    ptsEd.lv := lv
    ptsEd.bVer := bVer
    ptsEd.eX := eX
    ptsEd.eY := eY
    ptsEd.eW := eW
    ptsEd.eH := eH
    ptsEd.dx := dx
    ptsEd.dy := dy
    ptsEd.eEsc := eEsc
    ptsEd.eEscAv := eEscAv
    ptsEd.eAlpha := eAlpha
    ptsEd.eAlphaF := eAlphaF
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
    st.Value := "Perfil activo: " PERFILES[PERFIL] ". Selecciona una zona."
    lv.OnEvent("ItemSelect",_PtsSel)
    lv.OnEvent("DoubleClick",(*) => _PtsDibujarSel(false))
    bDib.OnEvent("Click",(*) => _PtsDibujarSel(false))
    bCad.OnEvent("Click",(*) => _PtsDibujarSel(true))
    bVer.OnEvent("Click",_PtsToggleVerZonas)
    bDef.OnEvent("Click",_PtsDefecto)
    bAp.OnEvent("Click",_PtsAplicarCampos)
    bDelta.OnEvent("Click",_PtsDesplazar)
    ddGrupo.OnEvent("Change",(*) => _PtsEvFilas())
    lvEv.OnEvent("ItemSelect",_PtsEvSel)
    lvEv.OnEvent("DoubleClick",_PtsEvDobleClick)
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
    eAlpha.OnEvent("Change",_PtsAlphaChange)
    eAlphaF.OnEvent("Change",_PtsAlphaFChange)
    bRei.OnEvent("Click",_PtsReiniciar)
    bOk.OnEvent("Click",_PtsCerrar)
    g.OnEvent("Close",_PtsCerrar)
    g.OnEvent("Escape",_PtsCerrar)
    g.Show("AutoSize")
    ov := Map(bModoN.Hwnd,"mitad", bModoE.Hwnd,"mitad", ptsModo.barN.Hwnd,"mitad", ptsModo.barE.Hwnd,"mitad"
        , lv.Hwnd,"lv", lvEv.Hwnd,"lv", lvNv.Hwnd,"lv", lvTema.Hwnd,"lv", bDib.Hwnd,"fila4", bCad.Hwnd,"fila4", bVer.Hwnd,"fila4", bDef.Hwnd,"fila4"
        , bNvDib.Hwnd,"fila4", bNvBor.Hwnd,"fila4", bNvPes.Hwnd,"fila4", bNvVer.Hwnd,"fila4"
        , bAp.Hwnd,"der", bNvAp.Hwnd,"der", ddGrupo.Hwnd,"der")
    _PtsLayInit(g,lyM,tb,lv,lvEv,ov,{TW:TW,cw:cw,x0:x0,xR:xR,wL:wL,wR:wR})
    g.OnEvent("Size",_PtsLayRedim)
    _PtsAjustarVentana(g)                   ; cabe en el área útil del monitor de nacimiento y queda un poco sobre el centro
    _PtsFijarMinimo(g)                      ; mínimo = tamaño real de diseño, no el de nacimiento
    OnMessage(0x0232,_PtsFinMovimiento)     ; WM_EXITSIZEMOVE: re-encaja al soltar tras arrastrar
    OnMessage(0x007E,_PtsDisplayChange)     ; WM_DISPLAYCHANGE: cambio de topología
    SetTimer(_PtsAutoMin,250)
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
    lvNv.Modify(1,"Select Focus")
    _NvPanSel(lvNv,1,true)
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
    lv.GetPos(&lx,&lyy,&lw,&lh)
    lvEv.GetPos(&ex,&ey,&ew,&eh)
    bot1 := lyy + lh               ; borde inferior del ListView de la pestaña 1
    bot2 := ey + eh                ; borde inferior del ListView de la pestaña 2
    bot4 := 0
    if (HasProp(ptsEd, "temaLv") && IsObject(ptsEd.temaLv)) {
        ptsEd.temaLv.GetPos(, &t4y, , &t4h)
        bot4 := t4y + t4h
    }
    bot5 := 0
    if (HasProp(ptsEd, "lvNv") && IsObject(ptsEd.lvNv)) {
        ptsEd.lvNv.GetPos(, &nyy, , &nh)
        bot5 := nyy + nh
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
        t := (idx <= lyM[1]) ? 0 : (idx <= lyM[2]) ? 1 : (idx <= lyM[3]) ? 2 : (idx <= lyM[4]) ? 3 : (idx <= lyM[5]) ? 4 : (idx <= lyM[6]) ? 5 : 6
        r := {c: c, x: x, y: y, w: w, h: h, ax: 0, aw: 0, ay: 0, ah: 0, ps: 0, pb: 0}
        if (t = 0) {                                   ; el Tab3: crece en ancho y alto
            r.aw := 1
            r.ah := 1
        } else if (t = 1 || t = 2) {                   ; zonas / eventos: ListView absorbe el alto
            bot := (t = 1) ? bot1 : bot2
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
            } else if (t = 2 && typ = "Text" && y < ey - 1 && ux >= u.x0 + u.cw - 300) {
                r.ax := 1                              ; etiqueta "Grupo:" pegada a su desplegable
            }
            if (modo != "lv" && y >= bot - 1)
                r.ay := 1                              ; todo lo que está bajo la lista baja con la ventana
        } else if (t = 3) {                            ; sistema: dos columnas, se reparten el ancho extra
            if (ux >= u.xR - 1) {
                r.ax := 0.5
                if (uw >= u.wR - 1)
                    r.aw := 0.5
            } else if (uw >= u.wL - 1) {
                r.aw := 0.5
            }
        } else if (t = 4) {                            ; paleta de temas (lista desplazable)
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
        } else if (t = 5) {                            ; pestaña 5: nuevas ventanas
            if (modo = "lv") {
                r.aw := 1
                r.ah := 1
            } else if (modo = "fila4") {
                r.ps := (u.cw - 24) * k
                r.pb := (u.x0 + 12) * k
            } else if (modo = "der") {
                r.ax := 1
            } else if ((typ = "GroupBox" || typ = "Text") && uw >= u.cw - 1) {
                r.aw := 1
            }
            if (modo != "lv" && bot5 && y >= bot5 - 1)
                r.ay := 1
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
    dy := Max(-ly.dyMin, h - ly.ch0)                   ; negativo = ventana más baja que el diseño (los ListView ceden)
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
    if (ly.foco && WinActive("ahk_exe CLIPStudioPaint.exe")) {
        ly.foco := false
        try ptsEd.g.Minimize()
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
    defs.Push({k:"NvPestana",n:"Pestaña lienzo CSP",t:"rango",c:"FFD166"})
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
    avisoPes := _NvZonaVacia(pes) ? "⚠️ [CALIBRACIÓN OBLIGATORIA]: Delimita primero la franja de pestañas (Fila 1). | " : "⭐ Franja calibrada ✔ | "
    lista := ""
    Loop 8 {
        if (!_NvZonaVacia(IniRead(ini, sec, "NvZona" A_Index, "")))
            lista .= (lista = "" ? "" : ", ") A_Index
    }
    return avisoPes "Zonas configuradas: " (lista = "" ? "ninguna (se usará la zona segura)" : lista)
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

_NvPanSel(lv, row, sel) {
    if (!sel || row < 1)
        return
    ini := _PosGuiIniPath(), sec := _ZonaSec("Rangos")
    clave := (row = 1) ? "NvPestana" : "NvZona" (row - 1)
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
    if (!IsInteger(x) || !IsInteger(y) || !IsInteger(w) || !IsInteger(h) || Integer(w) <= 0 || Integer(h) <= 0) {
        ToolTip("Introduce números válidos (X, Y enteros; Ancho y Alto > 0)", , , 19)
        SetTimer(() => ToolTip(, , , 19), -1800)
        return
    }
    ini := _PosGuiIniPath(), sec := _ZonaSec("Rangos")
    clave := (row = 1) ? "NvPestana" : "NvZona" (row - 1)
    IniWrite(Format("{},{},{},{}", x, y, w, h), ini, sec, clave)
    if (clave = "NvPestana") {
        mH := WinExist("ahk_class " _NvCfg()["claseMarco"])
        if mH {
            WinGetPos(&fx, &fy, &fw, &fh, "ahk_id " mH)
            IniWrite(Format("{},{},{},{}", fx, fy, fw, fh), ini, sec, "NvPestanaMarco")
        }
    }
    CargarPuntos()
    _PtsRefrescar()
    _NvPanRefrescarTabla()
    if (IsObject(ptsEd) && HasProp(ptsEd, "stNvZonas") && IsObject(ptsEd.stNvZonas))
        ptsEd.stNvZonas.Text := _NvPanTexto()
    if (ptsEd.ovl.Length > 0)
        MostrarZonasCalibracion(0)
    ToolTip("Valores guardados para " clave, , , 19)
    SetTimer(() => ToolTip(, , , 19), -1200)
}

_NvPanDibujar(st := 0) {
    ini := _PosGuiIniPath(), sec := _ZonaSec("Rangos")
    ; Validación obligatoria para nuevos usuarios: primero debe estar delimitada la Franja de Pestañas
    if (_NvZonaVacia(IniRead(ini, sec, "NvPestana", ""))) {
        resp := MsgBox("⚠️ ATENCIÓN: Calibración requerida`n`nPara que el desacoplamiento de nuevas ventanas funcione, primero debes calibrar la Franja de Pestañas (Fila 1).`n`n¿Deseas delimitar la franja de pestañas ahora con el lápiz?", "Calibración inicial requerida", "YesNo IconExclamation")
        if (resp = "Yes")
            _NvPanPestana(st)
        return
    }
    libre := 0
    Loop 8 {
        if (_NvZonaVacia(IniRead(ini, sec, "NvZona" A_Index, ""))) {
            libre := A_Index
            break
        }
    }
    if !libre {
        if (IsObject(st))
            st.Text := "Máximo 8 zonas: borra alguna antes de dibujar otra."
        return
    }
    r := _PtsDibujarRango("Dibuja la zona para la nueva ventana " libre, "9A7BFF", false)
    if (!r)
        return
    IniWrite(Format("{},{},{},{}", r.x, r.y, r.w, r.h), ini, sec, "NvZona" libre)
    CargarPuntos()
    _PtsRefrescar()
    _NvPanRefrescarTabla()
    if (IsObject(ptsEd) && HasProp(ptsEd, "stNvZonas") && IsObject(ptsEd.stNvZonas))
        ptsEd.stNvZonas.Text := _NvPanTexto()
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
    CargarPuntos()
    _PtsRefrescar()
    _NvPanRefrescarTabla()
    if (IsObject(ptsEd) && HasProp(ptsEd, "stNvZonas") && IsObject(ptsEd.stNvZonas))
        ptsEd.stNvZonas.Text := _NvPanTexto()
    if (ptsEd.ovl.Length > 0)
        MostrarZonasCalibracion(0)
}

_NvPanPestana(st := 0) {
    ini := _PosGuiIniPath(), sec := _ZonaSec("Rangos")
    r := _PtsDibujarRango("Marca donde aparecerá la pestaña nueva (2.ª, con 1 sola abierta)", "FFD166", false)
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
    _NvPanRefrescarTabla()
    if (IsObject(ptsEd) && HasProp(ptsEd, "stNvZonas") && IsObject(ptsEd.stNvZonas))
        ptsEd.stNvZonas.Text := "Pestaña calibrada: (" r.x ", " r.y ") " r.w "x" r.h " px"
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
        ["smudge", "Dedo / Smudge (X alterno → P)", "Borradores y Mezcla"],
        ["smear", "Smear Mezcla (F → B / NumpadEnd)", "Borradores y Mezcla"],
        ["color_mix", "Mezcla de Color (X → D)", "Borradores y Mezcla"],
        ["color_primario", "Color Primario (Q doble)", "Color y Paleta"],
        ["color_secundario", "Color Secundario (Q doble alterno)", "Color y Paleta"],
        ["color_alpha", "Alpha Transparente (K)", "Color y Paleta"],
        ["relleno", "Bote de Pintura / Relleno (RButton + 1 → V)", "Color y Paleta"],
        ["area_color", "Área con Color (S doble)", "Color y Paleta"],
        ["lazo", "Herramienta Lazo (S)", "Selección"],
        ["seleccion", "Selección Marquee (M)", "Selección"],
        ["deseleccion", "Deselección (Ctrl + D)", "Selección"],
        ["reseleccion", "Reselección (Ctrl + Shift + D)", "Selección"],
        ["inv_seleccion", "Invertir Selección (Ctrl + Shift + I)", "Selección"],
        ["shift_sostenido", "Regla Recta · Shift Sostenido (RButton + F)", "Lienzo y Reglas"],
        ["flip_horizontal", "Volteo Horizontal del Lienzo (Space → Alt + G)", "Lienzo y Reglas"],
        ["rotar_lienzo", "Rotación de Lienzo (Z doble → R)", "Lienzo y Reglas"],
        ["zoom_lienzo", "Zoom de Lienzo (Z)", "Lienzo y Reglas"],
        ["regla_ocultar", "Reglas: mostrar / ocultar (RButton + − → T / Alt + T)", "Lienzo y Reglas"],
        ["capa_visibilidad", "Visibilidad de Capa (heredado · Space + E)", "Capas y Archivo"],
        ["capa_ocultar", "Ocultar Capa · Hide Layer (Space + E → Shift + D)", "Capas y Archivo"],
        ["capa_mostrar", "Mostrar Capa · Show Layer (Space + E → Shift + D)", "Capas y Archivo"],
        ["macro_capas", "Ciclo de Macros 1→2→3 (O / −)", "Capas y Archivo"],
        ["mascara_recorte", "Máscara de Capa / Recorte (RButton + S → M)", "Capas y Archivo"],
        ["capa_referencia", "Capa de Referencia · Ref Layer", "Capas y Archivo"],
        ["guardar", "Guardar Archivo .clip (Ctrl + S)", "Capas y Archivo"],
        ["deshacer", "Deshacer (Ctrl + Z)", "Capas y Archivo"],
        ["rehacer", "Rehacer (Ctrl + Y)", "Capas y Archivo"],
        ["copiar", "Copiar al Portapapeles (Ctrl + C)", "Capas y Archivo"],
        ["enfoque", "Modo Enfoque / Plegar Paneles (Tab / Shift + Esc / F3)", "Capas y Archivo"],
        ["hover_paneles", "Hover de Paneles Desplegables (+W)", "Capas y Archivo"],
        ["history_lock", "Bloqueo de Franja Historial", "Capas y Archivo"],
        ["bloque_gui", "Fijar / Mover Botones del Companion", "Capas y Archivo"],
        ["gui_frente", "Botones al Frente / Solo en CSP", "Capas y Archivo"],
        ["estab_slider", "Deslizador de Estabilización", "Capas y Archivo"],
        ["estab_sync", "Sincronización de Estabilizador", "Capas y Archivo"],
        ["layout", "Guardar / Aplicar Layout de Paneles", "Capas y Archivo"],
        ["reload", "Recargar Script", "Capas y Archivo"]
    ]
    return evs
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
    r := ObtenerRango(d.k)
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
    _PtsRefrescar()
    _PtsZonasVivo(d)                       ; P1: cajas en pantalla al instante
    ptsEd.st.Value := d.n " guardado: " msg
    _SonarUI("calib")
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
; ===== Dibujo con lápiz =====
_PtsDibujarRango(texto,color := "9A7BFF",permitirPunto := false) {
    if (ptsEd.dibujando)
        return 0
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
        mon := ObtenerMonitorCSP()
        tip := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale","")
        tip.BackColor := "1E1E2E"
        tip.SetFont("s11 bold cWhite","Segoe UI")
        tipTxt := tip.AddText("x12 y8 w900 h26 Center",texto)
        tip.Show("x" (mon.x + (mon.w - 924) // 2) " y" (mon.y + 40) " w924 h42 NoActivate")
        cur := Buffer(8,0)
        t0 := A_TickCount
        while !GetKeyState("LButton","P") {
            if (GetKeyState("Escape","P") || A_TickCount - t0 > 60000) {
                cancelado := true
                break
            }
            Sleep(10)
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
            while GetKeyState("LButton","P") {
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
                    tipTxt.Value := texto "   ·   " rw " × " rh
                }
                if GetKeyState("Escape","P") {
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
_PtsDibujarSel(encadenar := false) {
    defs := _PtsZonaDefs()
    i := ptsEd.sel
    if (i < 1 || i > defs.Length) {
        ptsEd.st.Value := "Selecciona primero una zona en la lista."
        return
    }
    Loop {
        d := defs[i]
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
}
; ===== Tabla de zonas =====
_PtsCamposDe(i) {
    defs := _PtsZonaDefs()
    if (i < 1 || i > defs.Length)
        return
    d := defs[i]
    r := _PtsRectDe(d)
    ptsEd.eX.Value := r.x
    ptsEd.eY.Value := r.y
    ptsEd.eW.Value := r.w
    ptsEd.eH.Value := r.h
    esPunto := (d.t = "punto")
    ptsEd.eW.Enabled := !esPunto
    ptsEd.eH.Enabled := !esPunto
}
_PtsSel(ctrl,item,selected) {
    if (!selected || item < 1)
        return
    ptsEd.sel := item
    _PtsCamposDe(item)
    d := _PtsZonaDefs()[item]
    ptsEd.st.Value := d.n " — " ((d.t = "punto") ? "punto" : "rango") ". Dibuja con el lápiz o escribe los valores."
}
_PtsAplicarCampos(*) {
    defs := _PtsZonaDefs()
    i := ptsEd.sel
    if (i < 1 || i > defs.Length)
        return
    d := defs[i]
    x := Trim(ptsEd.eX.Value)
    y := Trim(ptsEd.eY.Value)
    w := Trim(ptsEd.eW.Value)
    h := Trim(ptsEd.eH.Value)
    if (!IsInteger(x) || !IsInteger(y)) {
        ptsEd.st.Value := "X e Y deben ser enteros."
        return
    }
    if (d.t != "punto" && (!IsInteger(w) || !IsInteger(h))) {
        ptsEd.st.Value := "Ancho y Alto deben ser enteros."
        return
    }
    r := {x:Integer(x),y:Integer(y),w:(IsInteger(w) ? Integer(w) : 0),h:(IsInteger(h) ? Integer(h) : 0)}
    _PtsAplicarZona(d,r)
}
_PtsRefrescar() {
    RecalcularZonas()
    for i,d in _PtsZonaDefs() {
        r := _PtsRectDe(d)
        ptsEd.lv.Modify(i,"",d.n,(d.t = "punto") ? "Punto" : "Rango",r.x,r.y,r.w,r.h)
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
    ptsEd.lblDurEfec.Value := "Efectiva: " efectiva " ms · " origen
    filas := _PtsEvObtenerSeleccionados(ptsEd.lvEv)
    if (filas.Length > 1)
        ptsEd.stEv.Value := "▶ " filas.Length " eventos seleccionados  ·  " StrTitle(c.f) " · " _PtsZonaTxt(c.z) " · " c.op "% · " efectiva " ms"
    else
        ptsEd.stEv.Value := "▶ " ev[2] "  ·  " StrTitle(c.f) " · " _PtsZonaTxt(c.z) " · " c.op "% · " efectiva " ms"
}
_PtsZonaTxt(z) {
    return (z = "alta") ? "Alta" : ((z = "media") ? "Media" : "Baja")
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
    }
}
_PtsEvGuardar(k,f,z,op) {
    global PERFIL
    ini := _PosGuiIniPath()
    sec := "HudEventos" PERFIL
    IniWrite(f,ini,sec,"formato_" k)
    IniWrite(z,ini,sec,"zona_" k)
    IniWrite(op,ini,sec,"opacidad_" k)
    ptsEd.cfg[k] := {f:f,z:z,op:op}
}
_PtsEvFilas() {
    defs := _PtsEventosDefs()
    selIds := []
    for row in _PtsEvObtenerSeleccionados(ptsEd.lvEv) {
        if (ptsEd.mapFilas.Has(row))
            selIds.Push(defs[ptsEd.mapFilas[row]][1])
    }
    ptsEd.lvEv.Delete()
    ptsEd.mapFilas := []
    filtroGrupo := (IsObject(ptsEd.ddGrupo) && ptsEd.ddGrupo.Value > 1) ? ptsEd.ddGrupo.Text : ""
    orden := []
    for i, ev in defs {
        if (ptsEd.cfg[ev[1]].f != "desactivado")
            orden.Push(i)
    }
    for i, ev in defs {
        if (ptsEd.cfg[ev[1]].f = "desactivado")
            orden.Push(i)
    }
    for i in orden {
        ev := defs[i]
        grp := (ev.Length >= 3) ? ev[3] : "General"
        if (filtroGrupo != "" && grp != filtroGrupo)
            continue
        c := ptsEd.cfg[ev[1]]
        propia := _PtsDurPropia(ev[1])
        durTxt := (propia != "") ? propia " ms" : "(" _PtsDurEfectiva(ev[1],c.z) ")"
        nomEv := _PtsNomEvento(ev[1])
        ptsEd.mapFilas.Push(i)
        formatoTxt := (c.f = "desactivado") ? "🔴 OFF" : StrTitle(c.f)
        ptsEd.lvEv.Add("", nomEv, grp, formatoTxt, _PtsZonaTxt(c.z), c.op "%", durTxt)
    }
    primera := 0
    for row, idxReal in ptsEd.mapFilas {
        for sid in selIds {
            if (sid = defs[idxReal][1]) {
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
    filas := _PtsEvObtenerSeleccionados(ctrl)
    if (filas.Length > 1) {
        ptsEd.st.Value := filas.Length " eventos seleccionados. Cambia formato, prioridad u opacidad para aplicarlo a todos."
        _PtsEvDurRefrescar()
        return
    }
    c := ptsEd.cfg[_PtsEventosDefs()[idxReal][1]]
    ptsEd.ddF.Choose((c.f = "desactivado") ? 3 : ((c.f = "bruto") ? 2 : 1))
    ptsEd.ddZ.Choose((c.z = "alta") ? 1 : ((c.z = "media") ? 2 : 3))
    opIdx := (c.op = 100) ? 1 : ((c.op = 40) ? 3 : 2)
    ptsEd.ddOp.Choose(opIdx)
    _PtsEvDurRefrescar()
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
    if (IsObject(ptsEd) && HasProp(ptsEd, "guiAnclado") && IsObject(ptsEd.guiAnclado)) {
        try ptsEd.guiAnclado.Destroy()
        ptsEd.guiAnclado := 0
    }
    if (IsObject(ptsEd) && HasProp(ptsEd, "evAnclado")) {
        ptsEd.evAnclado := false
        if (HasProp(ptsEd, "bEvAnclar") && IsObject(ptsEd.bEvAnclar))
            ptsEd.bEvAnclar.Text := "📌 Anclar"
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

    if (IsObject(ptsEd) && HasProp(ptsEd, "guiAnclado") && IsObject(ptsEd.guiAnclado)) {
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

    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale", "HUD_Anclado_Calibrador")
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
        lbl := g.Add("Text", Format("x0 y{} w{} h{} cFFFFFF +0x200 +0x4000 Center", lblY, w, lblH), tit)
        lbl.SetFont("s" fSize " bold", "Segoe UI")
        bar := g.Add("Progress", Format("x0 y{} w{} h{}", h - barH, w, barH))
        bar.Opt("c" colAcento)
        bar.Value := 100
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
        g.SetFont("s" sSize " bold c9AA7C7", "Segoe UI")
        g.Add("Text", Format("x12 y{} w{} h18 Center BackgroundTrans +0x200 +0x4000", Max(4, tY - 18), ancho), "📌 ANCLADO · " StrUpper(_PtsZonaTxt(c.z)))
        g.SetFont("s" tSize " bold cFFFFFF", "Segoe UI")
        g.Add("Text", Format("x12 y{} w{} h{} Center BackgroundTrans +0x200 +0x4000", tY, ancho, tAlto), tit)
    }
    g.Show(Format("x{} y{} w{} h{} NoActivate", px, py, w, h))
    ptsEd.guiAnclado := g
    ptsEd.evAnclado := true
    ptsEd.bEvAnclar.Text := "📌 Quitar"
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

    r := _PtsDibujarRango("Dibuja la nueva posición exclusiva para: " tit, "00E5FF", false)
    if (!r)
        return

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
    ancho := _E(104) * 4 + _E(31) * 2 + PANEL_GAP * 5
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
    nuevo := ctrl.Value
    if (nuevo < 1 || nuevo = PERFIL)
        return
    GuardarPuntos(false)
    _RgGuardarMirror()
    ini := _PosGuiIniPath()
    IniWrite(nuevo,ini,"Perfil","actual")
    IniWrite(_FirmaMonitores(),ini,"Perfil","ultimaFirma")
    OcultarZonasCalibracion()
    ToolTip("🔄 Perfil: " PERFILES[nuevo])
    Sleep(300)
    Reload()
}
_PtsCerrar(*) {
    if (ptsEd.dibujando)
        return
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
MostrarZonasCalibracion(ms := 0) {
    OcultarZonasCalibracion()
    for i, z in ZONAS.izq
        ptsEd.ovl.Push(_CrearRectOverlay(z.x1,z.y1,z.x2 - z.x1 + 1,z.y2 - z.y1 + 1,"2ECC71","IZQ B" i))
    for i, z in ZONAS.der
        ptsEd.ovl.Push(_CrearRectOverlay(z.x1,z.y1,z.x2 - z.x1 + 1,z.y2 - z.y1 + 1,"3498DB","DER B" i))
    h := ZONAS.hist
    ptsEd.ovl.Push(_CrearRectOverlay(h.x1,h.y1,h.x2 - h.x1 + 1,h.y2 - h.y1 + 1,"E67E22","HISTORIAL"))
    nombresHud := Map("HUD_Alta","ZONA 1 · ALTA","HUD_Media","ZONA 2 · MEDIA","HUD_Baja","ZONA 3 · BAJA","Estab","ESTABILIZADOR","EstabFoco","ESTAB FOCO")
    for k in ["HUD_Alta","HUD_Media","HUD_Baja","Estab","EstabFoco"] {
        d := _PtsDefPorClave(k)
        if !IsObject(d)
            continue
        r := _PtsRectDe(d)
        if (IsInteger(r.x) && IsInteger(r.y) && IsInteger(r.w) && IsInteger(r.h) && r.w > 0 && r.h > 0)
            ptsEd.ovl.Push(_CrearRectOverlay(r.x,r.y,r.w,r.h,d.c,nombresHud.Has(k) ? nombresHud[k] : d.n))
    }
    ptsP := Map(1,"P1",2,"P2",29,"P29")
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
            ptsEd.ovl.Push(_CrearRectOverlay(r.x,r.y,r.w,r.h,dPes.c,"PESTAÑA CSP"))
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
    for g in ptsEd.ovl {
        try _OvlDestruir(g)
    }
    ptsEd.ovl := []
    if (IsObject(ptsEd) && HasProp(ptsEd,"bVer") && IsObject(ptsEd.bVer))
        ptsEd.bVer.Text := "👁 Ver zonas"
    if (IsObject(ptsEd) && HasProp(ptsEd,"bNvVer") && IsObject(ptsEd.bNvVer))
        ptsEd.bNvVer.Text := "👁 Ver zonas"
}
_CrearRectOverlay(x,y,w,h,color,texto := "") {
    ow := Max(w,4)
    oh := Max(h,4)
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale","")
    g.BackColor := color
    g.Show("x" x " y" y " w" ow " h" oh " NoActivate")
    WinSetTransparent(160,g)              ; solo la caja es translúcida
    if (texto != "")
        _OvlEtiqueta(g,x,y,ow,oh,color,texto)   ; la etiqueta va en su propia ventana, 100% opaca
    return g
}
_OvlEtiquetas() {
    static m := Map()                     ; hwnd de la caja -> ventana de su etiqueta
    return m
}
_OvlEtiqueta(gBox,x,y,ow,oh,color,texto) {
    fs := 10
    try fs := _FS(10)
    gl := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale","")
    gl.BackColor := "101018"
    gl.MarginX := 0
    gl.MarginY := 0
    gl.SetFont("s" fs " bold cFFFFFF","Segoe UI")
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

; [TEMA-LISTA] Pinta las celdas de color del ListView (NM_CUSTOMDRAW) y evita paginar.
_PtsTemaLvNotify(wParam, lParam, msg, hwnd) {
    global ptsEd
    if (!HasProp(ptsEd, "temaLvHwnd") || !ptsEd.temaLvHwnd || NumGet(lParam, 0, "Ptr") != ptsEd.temaLvHwnd)
        return
    try {
        if (!DllCall("IsWindow", "Ptr", ptsEd.temaLvHwnd))
            return
    } catch
        return
    if (NumGet(lParam, 16, "int") != -12)              ; NM_CUSTOMDRAW
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
