; ============================================================
;  lib/calibrador_panel.ahk
;  Panel flotante de calibración de zonas (Dibujar · Cadena · Ajustar)
;  Orquesta _PtsDibujarRango y _PtsEditarRangoInteractivo.
;  Sin globals: el estado vive en la sesión (objeto) y en _PtsSesActual().
; ============================================================

; ── Sesión activa (almacén estático, sin globals) ───────────
_PtsSesActual(nueva?) {
    static ses := 0
    if IsSet(nueva)
        ses := nueva
    return ses
}

_PtsSesActiva() => IsObject(_PtsSesActual())

; ── Orquestador ─────────────────────────────────────────────
; modoIni: "dibujar" | "cadena" | "ajustar" | "panel" (= ajustar)
; cola:    [{id:, titulo:}, ...] para el modo cadena
; guardar: callback opcional (idEv, rect) que persiste una zona dibujada
; Devuelve {x,y,w,h,modo,accion:"ok"} o 0 si se canceló sin confirmar nada.
_PtsCalibrarZona(titulo, idEv, rectIni := "", modoIni := "panel", cola := "", guardar := "", tipo := "hud") {
    static activa := false
    if (activa) {
        ses := _PtsSesActual()
        if (IsObject(ses) && ses.gui) {
            idEv := RegExReplace(idEv, "^(HUD_ev_)+", "")
            ses.idEv := idEv
            ses.titulo := titulo
            ses.tipo := tipo
            if (IsObject(guardar))
                ses.guardar := guardar

            colaArr := []
            if (IsObject(cola)) {
                for it in cola
                    colaArr.Push(it)
            }
            if (colaArr.Length = 0)
                colaArr.Push({id: ses.idEv, titulo: ses.titulo, rotulo: ses.titulo})
            ses.cola := colaArr
            ses.idx := 1

            rExistente := _PtsLeerRangoEvento(ses.idEv, ses.tipo)
            ses.rect := IsObject(rExistente) ? rExistente : ""

            nuevoModo := (modoIni = "panel") ? (IsObject(ses.rect) ? "ajustar" : "dibujar") : modoIni
            ses.modo := nuevoModo
            ses.cambio := nuevoModo
            _PtsPanelRefrescar(ses)
            return 1
        }
        return 0
    }
    activa := true

    idEv := RegExReplace(idEv, "^(HUD_ev_)+", "")

    ; Detectar si ya existe un rect válido en el INI para este idEv
    rExistente := ""
    if (IsObject(rectIni) && rectIni.HasProp("x") && rectIni.HasProp("y") && rectIni.HasProp("w") && rectIni.HasProp("h") && rectIni.w > 0 && rectIni.h > 0) {
        rExistente := rectIni
    } else {
        try {
            ini := _PosGuiIniPath(), sec := _ZonaSec("Rangos")
            if (tipo = "zona") {
                sx := IniRead(ini, sec, idEv "_x", ""), sy := IniRead(ini, sec, idEv "_y", "")
                sw := IniRead(ini, sec, idEv "_w", ""), sh := IniRead(ini, sec, idEv "_h", "")
                if (IsInteger(Trim(sx)) && IsInteger(Trim(sy)) && IsInteger(Trim(sw)) && IsInteger(Trim(sh))) {
                    if (Integer(Trim(sw)) > 0 && Integer(Trim(sh)) > 0)
                        rExistente := {x: Integer(Trim(sx)), y: Integer(Trim(sy)), w: Integer(Trim(sw)), h: Integer(Trim(sh))}
                }
            } else {
                v := IniRead(ini, sec, "HUD_ev_" . idEv, "")
                if (v = "")
                    v := IniRead(ini, sec, idEv, "")
                p := StrSplit(v, ",")
                if (p.Length >= 4 && IsInteger(Trim(p[1])) && IsInteger(Trim(p[2])) && IsInteger(Trim(p[3])) && IsInteger(Trim(p[4]))) {
                    if (Integer(Trim(p[3])) > 0 && Integer(Trim(p[4])) > 0)
                        rExistente := {x: Integer(Trim(p[1])), y: Integer(Trim(p[2])), w: Integer(Trim(p[3])), h: Integer(Trim(p[4]))}
                }
            }
        }
    }

    modoInicial := (IsObject(rExistente)) ? "ajustar" : "dibujar"
    if (modoIni = "dibujar" || modoIni = "cadena")
        modoInicial := modoIni

    ses := {titulo: titulo, idEv: idEv
          , rect: rExistente
          , modo: modoInicial, cambio: "", salir: false, afinar: false, tipo: tipo
          , cola: IsObject(cola) ? cola : [], idx: 1
          , guardar: guardar, resultado: 0
          , keepZonas: false, cerradoX: false, sinPanel: false
          , gui: 0, lblEvento: 0, lblInfo: 0, lblAyuda: 0, btns: Map()}
    if (ses.modo = "cadena" && ses.cola.Length < 2)
        ses.modo := (IsObject(rExistente)) ? "ajustar" : "dibujar"
    try {
        try _EspacialPausar(true)
        _PtsSesActual(ses)
        ses.sinPanel := _CalPySinPanel()
        _CalPySinPanel(false)
        if (!ses.sinPanel)
            _PtsPanelCrear(ses)
        while (!ses.salir) {
            ses.cambio := ""
            if (!ses.sinPanel)
                _PtsPanelRefrescar(ses)
            switch ses.modo {
                case "dibujar": _PtsSesDibujar(ses)
                case "cadena":  _PtsSesCadena(ses)
                default:        _PtsSesAjustar(ses)
            }
            if (ses.cambio != "")          ; el usuario pulsó otro modo en el panel
                ses.modo := ses.cambio
        }
    } finally {
        if (!ses.sinPanel)
            _PtsPanelDestruir(ses, ses.keepZonas && !ses.cerradoX)
        _PtsSesActual(0)
        try _EspacialPausar(false)
        activa := false
    }
    return ses.resultado
}

; ── Modos ───────────────────────────────────────────────────
_PtsSesDibujar(ses) {
    _PtsOcultarZonasEspaciales()
    if (!ses.sinPanel)
        _PtsPanelRefrescar(ses)
    r := _PtsDibujarRango(ses.titulo, "00E5FF", false, ses)
    if (ses.cambio != "")
        return
    if !IsObject(r) {                      ; Esc
        ses.salir := true
        return
    }
    ses.rect := r
    _PtsSesPersistir(ses, r)
    _CalPyRecargarIni()
    if (ses.sinPanel) {                    ; ZONAS Y RANGOS: persistir y cerrar (Enter)
        ses.resultado := {x: r.x, y: r.y, w: r.w, h: r.h, modo: "dibujar", accion: "ok"}
        ses.keepZonas := true
        ses.salir := true                  ; _PtsGuardarRangoZona ya reconstruyó los overlays
        return
    }
    ses.resultado := {x: r.x, y: r.y, w: r.w, h: r.h, modo: "dibujar", accion: "ok"}
    ses.keepZonas := true
    try _PtsMostrarZonasEspaciales()
    _PtsPanelPintarBtnVer(ses, true)
    ses.modo := "ajustar"
    _PtsPanelRefrescar(ses)
    _PtsPanelBucleEspera(ses)
}

_PtsSesCadena(ses) {
    _PtsOcultarZonasEspaciales()
    _PtsPanelRefrescar(ses)
    while (ses.idx <= ses.cola.Length) {
        it := ses.cola[ses.idx]
        ses.idEv := it.id
        ses.titulo := it.titulo
        _PtsPanelRefrescar(ses)
        r := _PtsDibujarRango(it.titulo, "00E5FF", false, ses)
        if (ses.cambio != "")
            return                         ; idx se conserva para retomar
        if !IsObject(r)                    ; Esc = terminar la cadena
            break
        ses.rect := r
        _PtsSesPersistir(ses, r)           ; cada zona se guarda al confirmarse
        ses.resultado := {x: r.x, y: r.y, w: r.w, h: r.h, modo: "cadena", accion: "ok"}
        ses.idx += 1
    }
    ses.salir := true
}

_PtsSesAjustar(ses) {
    _PtsOcultarZonasEspaciales()
    if (!ses.sinPanel)
        _PtsPanelRefrescar(ses)
    r := _PtsEditarRangoInteractivo(ses.titulo, ses.idEv, ses.rect, ses)
    if (ses.cambio != "")                  ; el editor ya dejó el rect vigente en ses.rect
        return
    if IsObject(r) {
        ses.rect := r
        _PtsSesPersistir(ses, r)
        _CalPyRecargarIni()
        ses.resultado := {x: r.x, y: r.y, w: r.w, h: r.h, modo: "ajustar", accion: "ok"}
        if (ses.sinPanel) {
            ses.keepZonas := true
            ses.salir := true
            return
        }
        ses.keepZonas := true
        try _PtsMostrarZonasEspaciales()
        _PtsPanelPintarBtnVer(ses, true)
        _PtsPanelRefrescar(ses)
        _PtsPanelBucleEspera(ses)
        return
    }
    if IsObject(ses.resultado) {
        if (ses.sinPanel) {
            ses.keepZonas := true
            ses.salir := true
            return
        }
        ses.keepZonas := true
        try _PtsMostrarZonasEspaciales()
        _PtsPanelPintarBtnVer(ses, true)
        _PtsPanelRefrescar(ses)
        _PtsPanelBucleEspera(ses)
        return
    }
    ses.salir := true
}

_PtsPanelBucleEspera(ses) {
    ses.enEspera := true
    while (!ses.salir && ses.cambio = "") {
        Sleep(50)
    }
    ses.enEspera := false
}

_PtsSesPersistir(ses, r) {
    try _DzLog("panel: persistir " ses.idEv " " r.x "," r.y " " r.w "x" r.h " tipo=" ses.tipo)
    if !IsObject(ses.guardar)
        return
    g := ses.guardar
    if (g.IsVariadic || g.MaxParams >= 3)
        g(ses.idEv, r, ses.tipo)
    else
        g(ses.idEv, r)                      ; guardadores heredados de 2 parámetros
}

; ── Panel ───────────────────────────────────────────────────
_PtsPanelCrear(ses) {
    mon := ObtenerMonitorCSP()
    w := _E(780), h := _E(100)
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000 -DPIScale", "")
    g.BackColor := "1E1E2E"
    g.SetFont("s10 bold cFFFFFF", "Segoe UI")
    ses.lblEvento := g.AddText("x" _E(14) " y" _E(8) " w" _E(480) " h" _E(22), "")
    g.SetFont("s10 norm cA8A8C0", "Segoe UI")
    ses.lblInfo := g.AddText("x" _E(500) " y" _E(8) " w" _E(230) " h" _E(22) " Right", "")

    ; Botón cerrar [ ✖ ] en la esquina superior derecha
    g.SetFont("s10 bold cA8A8C0", "Segoe UI")
    btnX := g.AddText("x" (w - _E(32)) " y" _E(6) " w" _E(24) " h" _E(24) " Center +0x200 +0x100 BackgroundTrans", "✕")
    btnX.OnEvent("Click", (*) => (ses.salir := true, ses.cambio := "cancelar"))

    g.SetFont("s10 bold cC9C9E0", "Segoe UI")
    bw := _E(180), bh := _E(34), gap := _E(8)
    margen := (w - (4 * bw + 3 * gap)) // 2
    defs := [["dibujar", "✎  Dibujar"], ["cadena", "⛓  En cadena"], ["ajustar", "📐  Ajustar zona"], ["ver", "👁  Ver zonas"]]
    for i, def in defs {
        bx := margen + (i - 1) * (bw + gap)
        b := g.AddText("x" bx " y" _E(34) " w" bw " h" bh " Center +0x200 +0x100 Background2B2B40", def[2])
        if (def[1] = "ver")
            b.OnEvent("Click", _PtsPanelToggleVerZonas.Bind(ses))
        else
            b.OnEvent("Click", _PtsPanelPulsar.Bind(ses, def[1]))
        ses.btns[def[1]] := b
    }
    g.SetFont("s9 norm cA8A8C0", "Segoe UI")
    ses.lblAyuda := g.AddText("x" _E(14) " y" _E(76) " w" (w - _E(28)) " h" _E(18), "")
    ses.gui := g

    ; Permitir arrastrar el panel haciendo clic en los textos informativos o captura WM_LBUTTONDOWN
    ses.lblEvento.OnEvent("Click", _PtsPanelArrastrar.Bind(ses))
    ses.lblAyuda.OnEvent("Click", _PtsPanelArrastrar.Bind(ses))

    g.Show("x" (mon.x + (mon.w - w) // 2) " y" (mon.y + _E(40)) " w" w " h" h " NoActivate")
    try _DwmRedondear(g.Hwnd)
}

_PtsPanelToggleVerZonas(ses, *) {
    visibles := _PtsAlternarZonasEspaciales()
    _PtsPanelPintarBtnVer(ses, visibles)
}

_PtsPanelPintarBtnVer(ses, visibles) {
    if !(IsObject(ses) && IsObject(ses.btns) && ses.btns.Has("ver"))
        return
    b := ses.btns["ver"]
    b.Value := visibles ? "👁  Ocultar zonas" : "👁  Ver zonas"
    b.Opt("Background" (visibles ? "7863A6" : "2B2B40"))
    b.SetFont("c" (visibles ? "FFFFFF" : "C9C9E0"))
    b.Redraw()
}

_PtsPanelArrastrar(ses, *) {
    if (IsObject(ses) && IsObject(ses.gui)) {
        try PostMessage(0xA1, 2, 0, ses.gui.Hwnd)   ; WM_NCLBUTTONDOWN, HTCAPTION
    }
}

_PtsPanelPulsar(ses, modo, *) {
    if (ses.cambio != "")
        return
    if (!ses.HasProp("enEspera") || !ses.enEspera) {
        if (ses.modo = modo)
            return
    }
    if (modo = "cadena" && ses.cola.Length < 2)
        return
    if (modo = "ajustar" && (!IsObject(ses.rect) || !ses.rect.HasProp("w") || ses.rect.w <= 0 || ses.rect.h <= 0))
        return
    ses.modo := modo
    ses.cambio := modo
}

_PtsPanelRefrescar(ses) {
    if !IsObject(ses.gui)
        return
    ev := ses.titulo
    if (ses.modo = "cadena" && ses.cola.Length >= 1) {
        it := ses.cola[Min(ses.idx, ses.cola.Length)]
        if (it.HasProp("rotulo") && it.rotulo != "")
            ev := it.rotulo
        ev .= "   ·   " Min(ses.idx, ses.cola.Length) " / " ses.cola.Length
    }
    ses.lblEvento.Value := ev
    ses.lblInfo.Value := ""
    for m, b in ses.btns {
        if (m = "ver") {
            vis := _PtsZonasEspacialesVisibles()
            b.Value := vis ? "👁  Ocultar zonas" : "👁  Ver zonas"
            b.Opt("Background" (vis ? "7863A6" : "2B2B40"))
            b.SetFont("c" (vis ? "FFFFFF" : "C9C9E0"))
            b.Redraw()
            continue
        }
        act := (m = ses.modo)
        off := (m = "cadena" && ses.cola.Length < 2)
            || (m = "ajustar" && (!IsObject(ses.rect) || !ses.rect.HasProp("w") || ses.rect.w <= 0 || ses.rect.h <= 0))
        b.Opt("Background" (act ? "7863A6" : "2B2B40"))
        b.SetFont("c" (act ? "FFFFFF" : (off ? "5A5A75" : "C9C9E0")))
        b.Redraw()
    }
    ses.lblAyuda.Value := _PtsPanelAyuda(ses.modo)
}

_PtsPanelAyuda(modo) {
    switch modo {
        case "dibujar": return "Arrastra con el lápiz para marcar la zona · Esc cancelar"
        case "cadena":  return "Arrastra cada zona en orden · Esc terminar"
        default:        return "Arrastra esquinas para estirar · Enter confirmar · Esc cancelar"
    }
}

; Texto vivo (medidas durante el arrastre) en la esquina del panel
_PtsPanelInfo(ses, txt) {
    if (IsObject(ses) && IsObject(ses.lblInfo))
        ses.lblInfo.Value := txt
}

; Re-eleva el panel sobre el overlay / el editor (ambos son TOPMOST)
_PtsPanelAlFrente(ses) {
    if (IsObject(ses) && IsObject(ses.gui))
        try DllCall("SetWindowPos", "Ptr", ses.gui.Hwnd, "Ptr", -1
                  , "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013)
}

; Hit-test en coordenadas físicas de pantalla (para que un toque en el panel no inicie un rectángulo)
_PtsPanelContiene(ses, x, y) {
    if (!IsObject(ses) || !IsObject(ses.gui))
        return false
    try {
        WinGetPos(&px, &py, &pw, &ph, "ahk_id " ses.gui.Hwnd)
        return (x >= px && x < px + pw && y >= py && y < py + ph)
    }
    return false
}

_PtsPanelDestruir(ses, keepZonas := false) {
    if (!keepZonas)
        try _PtsOcultarZonasEspaciales()
    if IsObject(ses.gui)
        try ses.gui.Destroy()
    ses.gui := 0
}

; Devuelve [{id, x, y, w, h}, ...] con todas las claves HUD_ev_* del .ini de zonas.
_PtsEventosRangos() {
    out := []
    ini := _PosGuiIniPath(), sec := _ZonaSec("Rangos")
    try {
        raw := IniRead(ini, sec)
    } catch {
        return out
    }
    if (raw = "")
        return out
    for linea in StrSplit(raw, "`n", "`r") {
        p := InStr(linea, "=")
        if (!p)
            continue
        k := SubStr(linea, 1, p - 1)
        if (SubStr(k, 1, 7) != "HUD_ev_")
            continue
        c := StrSplit(SubStr(linea, p + 1), ",")
        if (c.Length < 4 || !IsInteger(Trim(c[1])) || !IsInteger(Trim(c[2]))
            || !IsInteger(Trim(c[3])) || !IsInteger(Trim(c[4])))
            continue
        w := Integer(Trim(c[3])), h := Integer(Trim(c[4]))
        if (w <= 0 || h <= 0)
            continue
        out.Push({id: SubStr(k, 8), x: Integer(Trim(c[1])), y: Integer(Trim(c[2])), w: w, h: h})
    }
    return out
}

; Devuelve [{id, x, y, w, h}, ...] con todos los disparadores espaciales (<id>_x..h)
_PtsEventosEspacialesRangos() {
    out := []
    ini := _PosGuiIniPath(), sec := _ZonaSec("Rangos")
    try {
        raw := IniRead(ini, sec)
    } catch {
        return out
    }
    if (raw = "")
        return out
    mapa := Map()
    for linea in StrSplit(raw, "`n", "`r") {
        p := InStr(linea, "=")
        if (!p)
            continue
        k := Trim(SubStr(linea, 1, p - 1))
        v := Trim(SubStr(linea, p + 1))
        mapa[k] := v
    }
    vistos := Map()
    for k, v in mapa {
        if (SubStr(k, -2) = "_x") {
            idEv := SubStr(k, 1, -2)
            if vistos.Has(idEv)
                continue
            vistos[idEv] := true
            if (mapa.Has(idEv . "_y") && mapa.Has(idEv . "_w") && mapa.Has(idEv . "_h")) {
                x := mapa[k], y := mapa[idEv . "_y"], w := mapa[idEv . "_w"], h := mapa[idEv . "_h"]
                if (IsInteger(x) && IsInteger(y) && IsInteger(w) && IsInteger(h) && Integer(w) > 0 && Integer(h) > 0)
                    out.Push({id: idEv, x: Integer(x), y: Integer(y), w: Integer(w), h: Integer(h)})
            }
        }
    }
    return out
}

; ── Persistencia (mismo formato que el flujo existente) ─────
_PtsGuardarRangoEvento(idEv, r, tipo := "hud") {
    ini := _PosGuiIniPath(), sec := _ZonaSec("Rangos")
    idEv := RegExReplace(idEv, "^(HUD_ev_)+", "")          ; normaliza prefijo duplicado
    if (tipo = "zona") {                                    ; Disparador Espacial: formato de 99b6c31
        IniWrite(r.x, ini, sec, idEv "_x")
        IniWrite(r.y, ini, sec, idEv "_y")
        IniWrite(r.w, ini, sec, idEv "_w")
        IniWrite(r.h, ini, sec, idEv "_h")
        try _EspacialCargar()                               ; runtime activo al instante
    } else {                                                ; aviso HUD
        IniWrite(Format("{},{},{},{}", r.x, r.y, r.w, r.h), ini, sec, "HUD_ev_" . idEv)
    }
    try CargarPuntos()
    try RecalcularZonas()
    try _PtsMostrarZonasEspaciales()
}

_PtsGuardarRangoZona(idEv, r) {
    global PERFIL
    ini := _PosGuiIniPath(), sec := _ZonaSec("Rangos")
    IniWrite(Format("{},{},{},{}", r.x, r.y, r.w, r.h), ini, sec, idEv)
    _PtsSincronizarPuntosZona(ini, idEv, r)
    try _PtsCache(true)
    try CargarPuntos()
    try RecalcularZonas()
    try _PtsMostrarZonasEspaciales()
}

; Traduce el id de zona fija a su primer punto P y la cantidad de esquinas.
_PtsPuntosDeZona(idEv) {
    id := StrLower(idEv)
    if RegExMatch(id, "^izqb([1-3])$", &m)
        return {p: 3 + (Integer(m[1]) - 1) * 4, n: 4}
    if RegExMatch(id, "^derb([1-3])$", &m)
        return {p: 15 + (Integer(m[1]) - 1) * 4, n: 4}
    if (id = "historial")
        return {p: 27, n: 2}
    if (id = "toggleizq")
        return {p: 1, n: 1}
    if (id = "toggleder")
        return {p: 2, n: 1}
    if (id = "zonasegura")
        return {p: 29, n: 1}
    return 0
}

; Mantiene [Puntos<P>] alineado con [Rangos<P>] para que RecalcularZonas() no lea coordenadas viejas.
_PtsSincronizarPuntosZona(ini, idEv, r) {
    pz := _PtsPuntosDeZona(idEv)
    if !IsObject(pz)
        return
    secP := _ZonaSec("Puntos")
    x2 := r.x + r.w, y2 := r.y + r.h
    if (pz.n = 4) {
        xs := [r.x, x2, x2, r.x]
        ys := [r.y, r.y, y2, y2]
    } else if (pz.n = 2) {
        xs := [r.x, x2]
        ys := [r.y, y2]
    } else {
        xs := [r.x]
        ys := [r.y]
    }
    Loop pz.n {
        IniWrite(xs[A_Index], ini, secP, "P" (pz.p + A_Index - 1) "x")
        IniWrite(ys[A_Index], ini, secP, "P" (pz.p + A_Index - 1) "y")
    }
}

_CalPySeleccionarEvento(idEv, nombre := "") {
    ses := _PtsSesActual()
    if (!IsObject(ses) || !ses.gui)
        return
    idEv := RegExReplace(idEv, "^(HUD_ev_)+", "")
    ses.idEv := idEv
    ses.titulo := (nombre != "") ? nombre : idEv
    ses.cola := [{id: idEv, titulo: ses.titulo, rotulo: ses.titulo}]
    ses.idx := 1
    tipo := (ses.HasProp("tipo") && ses.tipo != "") ? ses.tipo : "zona"
    rExistente := _PtsLeerRangoEvento(idEv, tipo)
    ses.rect := IsObject(rExistente) ? rExistente : ""
    if (!IsObject(ses.rect) || !ses.rect.HasProp("w") || ses.rect.w <= 0) {
        ses.modo := "dibujar"
    } else {
        ses.modo := "ajustar"
    }
    _PtsPanelRefrescar(ses)
}
