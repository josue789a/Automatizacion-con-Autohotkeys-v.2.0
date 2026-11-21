; ═══════════ ④ COMPORTAMIENTOS (Fases C–E) ═══════════
_CompInit() {
    global COMP
    COMP := {filas: [], bloques: [], abierta: "", panel: 0, lblEv: 0, glob: [], globAbierta: false, lblGlob: 0}
}
; Registra un control de «Globales» con su desplazamiento (dy, px base) respecto a la cabecera
_CompGlobAdd(c, dy) {
    COMP.glob.Push({c: c, dy: dy})
    return c
}
; Alto de «Globales» abierto (px base): deslizador y enfoque (sin visibilidad ni clic).
_CompGlobH() => 100
_CompGlobToggle(*) {
    COMP.globAbierta := !COMP.globAbierta
    COMP.lblGlob.Text := "🌐 Globales (todo el script) " (COMP.globAbierta ? "▾" : "▸")
    _AccRelayout()
}
; Registra un control extra dentro de un bloque del acordeón (se muestra/oculta con el bloque).
_CompBloqueAddExtra(id, ctrl, h := 24) {
    global COMP
    bl := _CompBloqueDe(id)
    if (!bl)
        return ctrl
    if (!bl.HasOwnProp("ctrlsExtra"))
        bl.ctrlsExtra := []
    bl.ctrlsExtra.Push({c: ctrl, h: h})
    return ctrl
}
; Cabecera de sub-bloque (tarjeta colapsable estilo mockup).
_CompBloqueNuevo(id, num, titulo, subtitulo, yDis, abierto := false) {
    global ACC, COMP
    g := ACC.g, x0 := ACC.x0, uiP := ACC.uiP
    ; Número de bloque (ej: "01")
    lblNum := _R(g.Add("Text", uiP.Call(x0 + 14, yDis + 1, 24, 18) . " +0x200 +0x100", num))
    lblNum.SetFont("bold")
    ; Título del bloque en negrita
    hdr := _R(g.Add("Text", uiP.Call(x0 + 40, yDis + 1, ACC.cw - 100, 18) . " +0x200 +0x100", titulo))
    hdr.SetFont("bold")
    ; Subtítulo descriptivo en gris tenue
    lblSub := _R(g.Add("Text", uiP.Call(x0 + 40, yDis + 19, ACC.cw - 100, 16) . " +0x200 +0x100 cGray", subtitulo))
    ; Chevrón indicador de despliegue a la derecha
    chev := _R(g.Add("Text", uiP.Call(x0 + ACC.cw - 28, yDis + 8, 20, 20) . " +0x200 +0x100 +Center", abierto ? "⌃" : "⌄"))
    chev.SetFont("s11 bold")
    ; Línea divisoria inferior
    lin := _R(g.Add("Text", uiP.Call(x0 + 14, yDis + 37, ACC.cw - 28, 1) . " +0x10", ""))

    toggleFn := _CompBloqueToggle.Bind(id)
    lblNum.OnEvent("Click", toggleFn)
    hdr.OnEvent("Click", toggleFn)
    lblSub.OnEvent("Click", toggleFn)
    chev.OnEvent("Click", toggleFn)

    COMP.bloques.Push({id: id, num: num, titulo: titulo, sub: subtitulo
        , hdrNum: lblNum, hdr: hdr, hdrSub: lblSub, chev: chev, lin: lin, abierto: abierto})
    return hdr
}
_CompBloqueDe(id) {
    global COMP
    for bl in COMP.bloques
        if (bl.id = id)
            return bl
    return 0
}
_CompBloqueToggle(id, *) {
    global COMP
    bl := _CompBloqueDe(id)
    if (!bl)
        return
    bl.abierto := !bl.abierto
    bl.chev.Text := bl.abierto ? "⌃" : "⌄"
    _AccRelayout()
}
; ── E2: opacidad/borde por evento (Bloque 1). Sin clave en el ini = comportamiento de hoy ──
_CompIni(key, campo, idEv, reset := false) {          ; lectura cacheada (el loop de hover la llama cada tick)
    static cache := Map()
    if (reset) {
        cache.Clear()
        return ""
    }
    k := key "_" campo "_" idEv
    if (!cache.Has(k))
        cache[k] := IniRead(_PosGuiIniPath(), "Particularidades", k, "")
    return cache[k]
}

; Invalida la caché de particularidades (llamar ante cualquier cambio externo del INI).
_CompInvalidar() {
    _CompIni("", "", "", true)
}
_CompOp(key, campo, idEv, def) {                      ; opacidad Win32 0-255
    v := _CompIni(key, campo, idEv)
    return (IsInteger(v) && Integer(v) >= 1 && Integer(v) <= 255) ? Integer(v) : def
}
_CompBorde(key, idEv, def) {
    v := _CompIni(key, "borde", idEv)
    return (v = "") ? def : (v = "1")
}
_CompDefOp(key, campo) {
    if (key = "pildora")
        return _AlphaTema("pill", 235)
    return (campo = "op_rep") ? 5 : 255
}
_CompE2Activo(idEv) {                                 ; eventos con runtime cableado (E2b añade más)
    return InStr("|panel_ds|panel_cc|history_lock|gui_frente|estab_slider|reload|", "|" idEv "|") > 0
}
_CompAplicarVivo(key, idEv) {
    global dsGui, colorV, ccGui, colorCC, lockGui, hist, frenteGui, estabBtnGui, reloadGui
    _CompIni("", "", "", true)                        ; invalida la caché
    if (key = "pildora")
        try _CompPildoraAplicar(idEv)                 ; W1: tamaño/color
    if (idEv = "panel_ds") {
        if (key = "pildora") {
            try WinSetTransparent(_CompOp("pildora", "op_rep", idEv, _AlphaTema("pill", 235)), dsGui.g)
        } else if (key = "hover") {
            act := colorV.dsVis
            try WinSetTransparent(_CompOp("hover", act ? "op_act" : "op_rep", idEv, act ? 255 : 5), "ahk_id " colorV.dsID)
        }
    } else if (idEv = "panel_cc") {
        if (key = "pildora") {
            try WinSetTransparent(_CompOp("pildora", "op_rep", idEv, _AlphaTema("pill", 235)), ccGui.g)
        } else if (key = "hover") {
            act := colorCC.dsVis
            try WinSetTransparent(_CompOp("hover", act ? "op_act" : "op_rep", idEv, act ? 255 : 5), "ahk_id " colorCC.id)
        }
    } else if (idEv = "history_lock") {
        if (key = "pildora") {
            act := (IsSet(hist) && HasProp(hist, "abierto") && hist.abierto)
            try WinSetTransparent(_CompOp("pildora", act ? "op_act" : "op_rep", idEv, _AlphaTema("pill", 235)), lockGui.g)
        }
    } else if (idEv = "gui_frente") {
        if (key = "pildora") {
            try WinSetTransparent(_CompOp("pildora", "op_rep", idEv, _AlphaTema("pill", 235)), frenteGui.g)
        }
    } else if (idEv = "estab_slider") {
        if (key = "pildora") {
            try WinSetTransparent(_CompOp("pildora", "op_rep", idEv, _AlphaTema("pill", 235)), estabBtnGui.g)
        }
    } else if (idEv = "reload") {
        if (key = "pildora") {
            try WinSetTransparent(_CompOp("pildora", "op_rep", idEv, _AlphaTema("pill", 235)), reloadGui.g)
        }
    }
}
_CompModGuardar(key, campo, idEv, ctrl) {
    v := Trim(ctrl.Value)
    if (campo = "ms" && (!IsInteger(v) || Integer(v) < 50 || Integer(v) > 2000))
        return                                        ; inválido: no persiste
    if (campo = "a" && v != "" && idEv != "") {       ; A igual al atajo base = heredado: se guarda vacío
        baseA := IniRead(_PosGuiIniPath(), "Remapeos", "atajo_" idEv, _PtsEvAtajoDefault(idEv))
        if (v = baseA)
            v := ""
    }
    IniWrite(v, _PosGuiIniPath(), "Particularidades", key "_" campo "_" idEv)
    _CompAplicarVivo(key, idEv)                       ; solo invalida la caché
    try _RemapCargarHotkeys()
}

; ── W1: píldora táctil — tamaño (%) y color. Sin clave en el ini = comportamiento de hoy ──
_CompPildoraTam(idEv) {
    v := _CompIni("pildora", "tam", idEv)
    return (IsInteger(v) && Integer(v) >= 60 && Integer(v) <= 250) ? Integer(v) : 100
}
_CompPildoraColor(idEv) {                             ; "" = color del tema
    v := _CompIni("pildora", "color", idEv)
    return RegExMatch(v, "^[0-9A-Fa-f]{6}$") ? v : ""
}
_CompPildoraSwatch(c, col) {
    ok := RegExMatch(col, "^[0-9A-Fa-f]{6}$")
    try {
        c.swCol.Opt("Background" (ok ? col : _Tema("color", "surface.off", "424242")))
        c.swCol.Redraw()
    }
}
_CompPildoraGuardar(campo, idEv, ctrl) {
    ini := _PosGuiIniPath(), sec := "Particularidades", k := "pildora_" campo "_" idEv
    f := _CompFilaDe("pildora")
    c := (f && IsObject(f.campos)) ? f.campos : 0
    v := Trim(ctrl.Value)
    if (campo = "tam") {
        if (v = "") {
            try IniDelete(ini, sec, k)
        } else if (IsInteger(v) && Integer(v) >= 60 && Integer(v) <= 250) {
            IniWrite(Integer(v), ini, sec, k)
        } else {
            return                                    ; inválido: no persiste
        }
    } else {
        v := StrUpper(LTrim(v, "#"))
        if (v = "") {
            try IniDelete(ini, sec, k)
        } else if (RegExMatch(v, "^[0-9A-F]{6}$")) {
            IniWrite(v, ini, sec, k)
        } else {
            return                                    ; hex incompleto/inválido: no persiste
        }
        if (IsObject(c))
            _CompPildoraSwatch(c, v)
    }
    _CompAplicarVivo("pildora", idEv)
}
_CompPildoraReset(*) {
    idEv := _PtsSndIdEv()
    if (idEv = "")
        return
    for campo in ["tam", "color"]
        try IniDelete(_PosGuiIniPath(), "Particularidades", "pildora_" campo "_" idEv)
    _CompAplicarVivo("pildora", idEv)
    _CompCargarCampos(idEv)
}
_CompPildoraAplicar(idEv) {                           ; color: todas; tamaño: solo dinámicas
    pd := _PillDin()
    din := pd.Has(idEv)
    g := din ? pd[idEv].g : _PillGuiRigida(idEv)
    if (!IsObject(g) || !(g is Gui))
        return
    col := _CompPildoraColor(idEv)
    try g.BackColor := (col != "") ? col : _Tema("color", "surface.off", "424242")
    if (!din)
        return
    p := pd[idEv]
    fac := _CompPildoraTam(idEv) / 100
    w := Round(_PillAnchoPara(p.label.Text) * fac), h := Round(_E(25) * fac)
    p.icono.Move(Round(_E(4) * fac), Round(_E(2) * fac), Round(_E(20) * fac), Round(_E(20) * fac))
    p.label.Move(Round(_E(26) * fac), Round(_E(3) * fac), Max(10, w - Round(_E(28) * fac)), Round(_E(19) * fac))
    GbSetFont(p.label, Max(6, Round(_FS(9) * fac)), 700)
    p.barra.Move(0, Round(_E(22) * fac), w, Max(1, Round(_E(3) * fac)))
    p.g.Move(, , w, h)
    p.wPx := w
    _DwmRedondear(p.g.Hwnd)
}

_CompHeredadoPintar(cmp, *) {
    if !IsObject(cmp.eA)
        return
    v := Trim(cmp.eA.Value)
    cmp.eA.SetFont((cmp.baseA != "" && v = cmp.baseA) ? "cGray" : "cDefault")
}

_CompReqBRefrescar(cmp, *) {
    if IsObject(cmp.lblReqB)
        cmp.lblReqB.Visible := (cmp.eB.Enabled && Trim(cmp.eB.Value) = "")
}

_CompMsIcono(cmp, *) {
    if !IsObject(cmp.lblMs) || !IsObject(cmp.eMs)
        return
    v := Trim(cmp.eMs.Value)
    if (v != "" && (!IsInteger(v) || Integer(v) < 50 || Integer(v) > 2000)) {
        cmp.lblMs.Text := "⚠ Rango 50–2000 ms"
        cmp.lblMs.SetFont("cRed")
    } else if (v = "" || v = "250") {
        cmp.lblMs.Text := "⚡ 250 ms (predeterminado)"
        cmp.lblMs.SetFont("cGray")
    } else {
        cmp.lblMs.Text := "✎ personalizado (def. 250)"
        cmp.lblMs.SetFont("cDefault")
    }
}

_CompSliderLeer(campo) {                                ; E4
    global PERFIL, ESTAB_ALPHA_H, ESTAB_ALPHA_F
    v := IniRead(_PosGuiIniPath(), "Estab_p" PERFIL, campo, "")
    if (v != "")
        return v
    if (campo = "tecla_bajar")
        return "j"
    if (campo = "tecla_subir")
        return "-"
    if (campo = "snaps")
        return "7,15,35,55,75"
    if (campo = "modo")                                 ; W4: por defecto, la orientación vigente de la zona
        return (IsSet(estabGui) && IsObject(estabGui) && HasProp(estabGui, "horiz") && !estabGui.horiz) ? "v" : "h"
    if (campo = "rmin")
        return "0"
    if (campo = "rmax")
        return "100"
    if (campo = "paso_on")
        return "0"
    if (campo = "paso")
        return "5"
    return Round((campo = "alphaH" ? ESTAB_ALPHA_H : ESTAB_ALPHA_F) / 2.55)
}

_CompSliderExtraGuardar(campo, ctrl) {                  ; W4: modo / rango / snap por pasos -> [Estab_p<PERFIL>]
    global PERFIL
    ini := _PosGuiIniPath(), sec := "Estab_p" PERFIL
    f := _CompFilaDe("slider")
    c := (f && IsObject(f.campos)) ? f.campos : 0
    if (!IsObject(c))
        return
    if (campo = "modo") {
        IniWrite(ctrl.Value = 2 ? "v" : "h", ini, sec, "modo")
        return
    }
    if (campo = "paso_on") {
        IniWrite(ctrl.Value ? "1" : "0", ini, sec, "paso_on")
        return
    }
    v := Trim(ctrl.Value)
    ok := IsInteger(v)
    if (campo = "paso") {
        ok := ok && Integer(v) >= 1 && Integer(v) <= 50
    } else {                                            ; rmin / rmax: 0..100 y mín < máx
        ok := ok && Integer(v) >= 0 && Integer(v) <= 100
        otro := Trim((campo = "rmin" ? c.eRMax : c.eRMin).Value)
        if (ok && IsInteger(otro))
            ok := (campo = "rmin") ? (Integer(v) < Integer(otro)) : (Integer(otro) < Integer(v))
    }
    ctrl.Opt((ok || v = "") ? "cDefault" : "cFF4D4D")
    ctrl.Redraw()
    if (ok)
        IniWrite(Integer(v), ini, sec, campo)
}

_CompSliderVerificarTeclas(cmp) {
    if (!IsObject(cmp) || !HasProp(cmp, "eBajar") || !HasProp(cmp, "eSubir"))
        return
    baj := Trim(cmp.eBajar.Value)
    sub := Trim(cmp.eSubir.Value)
    faltan := (baj = "" || sub = "")
    if (HasProp(cmp, "lblReqTeclas") && IsObject(cmp.lblReqTeclas))
        cmp.lblReqTeclas.Visible := faltan
    if (HasProp(cmp, "otrosCtrls") && IsObject(cmp.otrosCtrls)) {
        for c in cmp.otrosCtrls {
            try c.Enabled := !faltan
        }
    }
}

_CompSnapsPintar(eSnaps, malIdx) {                      ; rojo solo en la caja inválida con texto; las demás en color normal
    for i, esn in eSnaps {
        esn.Opt((malIdx = i && Trim(esn.Value) != "") ? "cFF4D4D" : "cDefault")
        esn.Redraw()
    }
}

_CompSliderGuardar(campo, ctrl) {                       ; E4
    global PERFIL, ESTAB_ALPHA_H, ESTAB_ALPHA_F, ESTAB_MARCAS_C
    if (campo = "tecla_bajar" || campo = "tecla_subir") {
        v := Trim(ctrl.Value)
        IniWrite(v, _PosGuiIniPath(), "Estab_p" PERFIL, campo)
        f := _CompFilaDe("slider")
        if (f && IsObject(f.campos))
            _CompSliderVerificarTeclas(f.campos)
        return
    }
    if (campo = "snaps") {
        f := _CompFilaDe("slider")
        if (!f || !IsObject(f.campos) || !f.campos.HasProp("eSnaps"))
            return
        snapsArr := []
        ant := 0
        malIdx := 0
        for i, esn in f.campos.eSnaps {
            v := Trim(esn.Value)
            if (!IsInteger(v) || Integer(v) < 0 || Integer(v) > 100 || Integer(v) <= ant) {
                malIdx := i                           ; primer inválido: orden estrictamente creciente
                break
            }
            snapsArr.Push(Integer(v))
            ant := Integer(v)
        }
        _CompSnapsPintar(f.campos.eSnaps, malIdx)
        if (malIdx)
            return
        if (snapsArr.Length = 5) {
            strSnaps := snapsArr[1] "," snapsArr[2] "," snapsArr[3] "," snapsArr[4] "," snapsArr[5]
            IniWrite(strSnaps, _PosGuiIniPath(), "Estab_p" PERFIL, "snaps")
            if IsSet(ESTAB_MARCAS_C)
                ESTAB_MARCAS_C := snapsArr            ; actualiza en vivo
            _SonarUI("slider", snapsArr[1])
        }
        return
    }
    v := StrReplace(Trim(ctrl.Value), " ")
    if (!IsInteger(v) || Integer(v) < 10 || Integer(v) > 100)
        return
    IniWrite(v, _PosGuiIniPath(), "Estab_p" PERFIL, campo)
    if (campo = "alphaH")
        ESTAB_ALPHA_H := Round(Integer(v) * 2.55)
    else
        ESTAB_ALPHA_F := Round(Integer(v) * 2.55)
}

_CompCampoCambio(key, campo, ctrl, *) {
    global COMP
    if (HasProp(COMP, "cargando") && COMP.cargando)
        return
    idEv := _PtsSndIdEv()
    if (idEv = "")
        return
    if (campo = "snaps" || campo = "alphaH" || campo = "alphaF" || campo = "tecla_bajar" || campo = "tecla_subir") {   ; E4
        _CompSliderGuardar(campo, ctrl)
        return
    }
    if (key = "slider" && InStr("|modo|rmin|rmax|paso_on|paso|", "|" campo "|")) {   ; W4 (mismo destino [Estab_p%PERFIL%])
        _CompSliderExtraGuardar(campo, ctrl)
        return
    }
    if (campo = "a" || campo = "b" || campo = "ms") {   ; E3
        _CompModGuardar(key, campo, idEv, ctrl)
        return
    }
    if (key = "pildora" && (campo = "tam" || campo = "color")) {   ; W1: tamaño/color de píldora
        _CompPildoraGuardar(campo, idEv, ctrl)
        return
    }
    if (!_CompE2Activo(idEv) && !_PtsEvEsCustom(_PosGuiIniPath(), idEv))
        return
    ini := _PosGuiIniPath(), sec := "Particularidades"
    k := key "_" campo "_" idEv
    if (campo = "borde") {
        IniWrite(ctrl.Value ? "1" : "0", ini, sec, k)
    } else {
        v := Trim(ctrl.Value)
        if (!IsInteger(v) || Integer(v) < 1 || Integer(v) > 100)
            return                                    ; inválido: no persiste (patrón de _PtsAlphaChange)
        IniWrite(Round(Integer(v) * 2.55), ini, sec, k)
    }
    _CompAplicarVivo(key, idEv)
}
_CompCargarCampos(idEv) {                             ; se llama al seleccionar evento
    global COMP
    if (!IsSet(COMP) || !IsObject(COMP) || !HasProp(COMP, "filas"))
        return
    COMP.cargando := true
    try {
        for f in COMP.filas {
            c := f.campos
            if (!IsObject(c))
                continue
            if (HasProp(c, "sld")) {                          ; E4
                on := (idEv != "" && f.cb.Enabled)
                c.eBajar.Enabled := on
                c.eBajar.Value := on ? _CompSliderLeer("tecla_bajar") : ""
                c.eSubir.Enabled := on
                c.eSubir.Value := on ? _CompSliderLeer("tecla_subir") : ""
                rawSnaps := _CompSliderLeer("snaps")
                p := StrSplit(rawSnaps, ",")
                if (c.HasProp("eSnaps")) {
                    for i, esn in c.eSnaps {
                        esn.Value := (on && i <= p.Length) ? p[i] : ""
                    }
                }
                c.eAH.Value := on ? _CompSliderLeer("alphaH") : ""
                c.eAF.Value := on ? _CompSliderLeer("alphaF") : ""
                c.ddModoS.Choose(_CompSliderLeer("modo") = "v" ? 2 : 1)      ; W4
                c.eRMin.Value := on ? _CompSliderLeer("rmin") : ""
                c.eRMax.Value := on ? _CompSliderLeer("rmax") : ""
                c.cbPaso.Value := (on && _CompSliderLeer("paso_on") = "1") ? 1 : 0
                c.ePaso.Value := on ? _CompSliderLeer("paso") : ""
                _CompSliderVerificarTeclas(c)
                continue
            }
            if (HasProp(c, "pill")) {                         ; W1: píldora (tamaño/color)
                on := (idEv != "" && f.cb.Enabled)
                col := on ? _CompIni("pildora", "color", idEv) : ""
                c.eTam.Enabled := (on && !_PillIdsRigidos().Has(idEv))   ; rígidas: solo color
                c.eTam.Value := on ? _CompIni("pildora", "tam", idEv) : ""
                c.eCol.Enabled := on
                c.eCol.Value := col
                c.bReset.Enabled := on
                _CompPildoraSwatch(c, col)
                continue
            }
            if (HasProp(c, "mod")) {                      ; E3
                on := (idEv != "" && f.cb.Enabled)
                c.eA.Enabled := on
                valA := _CompIni(f.key, "a", idEv)
                baseA := ""
                if (idEv != "") {
                    baseA := IniRead(_PosGuiIniPath(), "Remapeos", "atajo_" idEv, _PtsEvAtajoDefault(idEv))
                    if (baseA = "—")
                        baseA := ""
                }
                if (valA = "" && idEv != "")
                    valA := baseA
                c.baseA := on ? baseA : ""
                c.eA.Value := on ? valA : ""
                _CompHeredadoPintar(c)
                c.eB.Enabled := on
                valB := _CompIni(f.key, "b", idEv)
                c.eB.Value := on ? valB : ""
                if (c.HasProp("lblReqB") && IsObject(c.lblReqB))
                    c.lblReqB.Visible := (on && f.key = "toggle" && valB = "")
                if (IsObject(c.eMs)) {
                    c.eMs.Enabled := on
                    ms := on ? _CompIni(f.key, "ms", idEv) : ""
                    c.eMs.Value := on ? (ms = "" ? "250" : ms) : ""
                    _CompMsIcono(c)
                }
                continue
            }
            if (HasProp(c, "stZonas") && IsObject(c.stZonas)) {
                c.stZonas.Text := _NvPanTexto()
                continue
            }
            if (!HasProp(c, "eRep") || !IsObject(c.eRep))
                continue
            on := (idEv != "" && (_CompE2Activo(idEv) || _PtsEvEsCustom(_PosGuiIniPath(), idEv)) && f.cb.Enabled)
            c.eRep.Enabled := on
            c.eRep.Value := on ? Round(_CompOp(f.key, "op_rep", idEv, _CompDefOp(f.key, "op_rep")) / 2.55) : ""
            if (IsObject(c.eAct)) {
                c.eAct.Enabled := on
                c.eAct.Value := on ? Round(_CompOp(f.key, "op_act", idEv, _CompDefOp(f.key, "op_act")) / 2.55) : ""
            }
            if (IsObject(c.cbB)) {
                c.cbB.Enabled := on
                c.cbB.Value := (on && _CompBorde(f.key, idEv, true)) ? 1 : 0
            }
        }
    } finally {
        COMP.cargando := false
    }
}

; ── W5: ubicación de la franja de pestañas (global, no por evento) ──
_CompNvFranjaUbic() {                                 ; "sup" (def.) | "inf"
    return (IniRead(_PosGuiIniPath(), "Particularidades", "ventanas_franja_ubic", "sup") = "inf") ? "inf" : "sup"
}
_CompNvFranjaUbicGuardar(ctrl, *) {
    IniWrite(ctrl.Value = 2 ? "inf" : "sup", _PosGuiIniPath(), "Particularidades", "ventanas_franja_ubic")
}

; Crea fila (checkbox + ⚙ + motivo) y su tarjeta. Devuelve el checkbox.
_CompFila(key, texto, yDis, lineas, bloque := "b1", pend := false, campos := "") {
    global ACC, COMP
    g := ACC.g, x0 := ACC.x0, uiP := ACC.uiP
    cb   := _R(g.Add("CheckBox", uiP.Call(x0 + 14,  yDis + 1, 210, 22), texto))
    gear := _R(g.Add("Text",     uiP.Call(x0 + 228, yDis + 1, 78,  22) . " +0x200 +0x100", "⚙ Ajustes ▸"))
    why  := _R(g.Add("Text",     uiP.Call(x0 + 312, yDis + 1, ACC.cw - 318, 22) . " +0x200 +0x4000 cGray", ""))
    card := {ctrls: [], alto: 6 + 22 * lineas.Length}
    for i, t in lineas {
        lbl := _R(g.Add("Text", uiP.Call(x0 + 34, yDis + 2, ACC.cw - 42, 20) . " +0x200 +0x4000" . (i = 1 ? "" : " cGray"), t))
        card.ctrls.Push(lbl)
        try _AyudaReg(lbl, t)
    }
    card.filas := Map()                              ; índice de ctrl -> fila visual (varios ctrls pueden compartir fila)
    cmp := false
    if (campos = "slider") {                                ; E4: deslizador virtual ; ===== BLOQUE_B_P4_BEGIN =====
        n := lineas.Length
        cmp := {eRep: "", eAct: "", cbB: "", sld: true, eBajar: "", eSubir: "", lblReqTeclas: "", eSnaps: [], eAH: "", eAF: "", bZona: "", bZonaF: "", otrosCtrls: []
            , ddModoS: "", eRMin: "", eRMax: "", cbPaso: "", ePaso: ""}
        ; Fila 1: Teclas obligatorias que suben y bajan
        card.ctrls.Push(_R(g.Add("Text", uiP.Call(x0 + 34, yDis + 2, 94, 20) . " +0x200", "Bajar estab (A):")))
        cmp.eBajar := _R(g.Add("Edit", uiP.Call(x0 + 130, yDis + 2, 70, 20), ""))
        _KgAttach(cmp.eBajar, (*) => _CompSliderVerificarTeclas(cmp))
        card.ctrls.Push(cmp.eBajar)
        card.ctrls.Push(_R(g.Add("Text", uiP.Call(x0 + 214, yDis + 2, 94, 20) . " +0x200", "Subir estab (B):")))
        cmp.eSubir := _R(g.Add("Edit", uiP.Call(x0 + 310, yDis + 2, 70, 20), ""))
        _KgAttach(cmp.eSubir, (*) => _CompSliderVerificarTeclas(cmp))
        card.ctrls.Push(cmp.eSubir)
        cmp.lblReqTeclas := _R(g.Add("Text", uiP.Call(x0 + 34, yDis + 2, 408, 20) . " +0x200 cRed", "⚠️ Teclas obligatorias"))
        card.ctrls.Push(cmp.lblReqTeclas)
        card.filas[n + 1] := n + 1, card.filas[n + 2] := n + 1
        card.filas[n + 3] := n + 1, card.filas[n + 4] := n + 1
        card.filas[n + 5] := n + 2

        ; Fila 2: Snap points
        txtSn := _R(g.Add("Text", uiP.Call(x0 + 34, yDis + 2, 112, 20) . " +0x200", "Snap P1 ▸ P5 (%):"))
        card.ctrls.Push(txtSn), cmp.otrosCtrls.Push(txtSn)
        card.filas[n + 6] := n + 3
        Loop 5 {
            esn := _R(g.Add("Edit", uiP.Call(x0 + 150 + (A_Index - 1) * 44, yDis + 2, 38, 20) . " Number Limit3", ""))
            cmp.eSnaps.Push(esn), cmp.otrosCtrls.Push(esn)
            cueSnap := "P" A_Index
            SendMessage(0x1501, 1, StrPtr(cueSnap), esn)
            card.ctrls.Push(esn)
            card.filas[n + 6 + A_Index] := n + 3
            esn.OnEvent("Change", _CompCampoCambio.Bind(key, "snaps"))
        }

        ; Fila 3: Opacidades
        txtAH := _R(g.Add("Text", uiP.Call(x0 + 34, yDis + 2, 112, 20) . " +0x200", "Hover (reposo) %:"))
        cmp.otrosCtrls.Push(txtAH), card.ctrls.Push(txtAH)
        cmp.eAH := _R(g.Add("Edit", uiP.Call(x0 + 150, yDis + 2, 48, 20), ""))
        cmp.otrosCtrls.Push(cmp.eAH), card.ctrls.Push(cmp.eAH)
        txtAF := _R(g.Add("Text", uiP.Call(x0 + 256, yDis + 2, 112, 20) . " +0x200", "Focus (activo) %:"))
        cmp.otrosCtrls.Push(txtAF), card.ctrls.Push(txtAF)
        cmp.eAF := _R(g.Add("Edit", uiP.Call(x0 + 372, yDis + 2, 48, 20), ""))
        cmp.otrosCtrls.Push(cmp.eAF), card.ctrls.Push(cmp.eAF)
        card.filas[n + 12] := n + 4, card.filas[n + 13] := n + 4
        card.filas[n + 14] := n + 4, card.filas[n + 15] := n + 4

        ; Fila 4: Botones para dibujar
        bZona := _R(g.Add("Button", uiP.Call(x0 + 34, yDis + 2, 160, 22), "✏ Dibujar deslizador"))
        bZonaF := _R(g.Add("Button", uiP.Call(x0 + 204, yDis + 2, 180, 22), "✏ Dibujar enfoque (Shift+E)"))
        bZona.OnEvent("Click", (*) => _PtsDibujarZonaEstab(false))
        bZonaF.OnEvent("Click", (*) => _PtsDibujarZonaEstab(true))
        cmp.bZona := bZona, cmp.bZonaF := bZonaF
        cmp.otrosCtrls.Push(bZona), cmp.otrosCtrls.Push(bZonaF)
        card.ctrls.Push(bZona), card.ctrls.Push(bZonaF)
        card.filas[n + 16] := n + 7, card.filas[n + 17] := n + 7          ; botones bajan a la fila 7

        ; Fila 5: Modo + Rango (ancho útil x0+34 .. x0+442)
        txtMd := _R(g.Add("Text", uiP.Call(x0 + 34, yDis + 2, 40, 20) . " +0x200", "Modo:"))
        cmp.ddModoS := _R(g.Add("DropDownList", uiP.Call(x0 + 76, yDis + 2, 106) . " Choose1", ["Horizontal", "Vertical"]))
        txtRg := _R(g.Add("Text", uiP.Call(x0 + 196, yDis + 2, 46, 20) . " +0x200", "Rango:"))
        cmp.eRMin := _R(g.Add("Edit", uiP.Call(x0 + 244, yDis + 2, 44, 20) . " Number Limit3", ""))
        txtA := _R(g.Add("Text", uiP.Call(x0 + 292, yDis + 2, 14, 20) . " +0x200 Center", "a"))
        cmp.eRMax := _R(g.Add("Edit", uiP.Call(x0 + 310, yDis + 2, 44, 20) . " Number Limit3", ""))
        txtPc := _R(g.Add("Text", uiP.Call(x0 + 358, yDis + 2, 84, 20) . " +0x200", "%"))
        try SendMessage(0x1501, 1, StrPtr("0"), cmp.eRMin)
        try SendMessage(0x1501, 1, StrPtr("100"), cmp.eRMax)
        for c2 in [txtMd, cmp.ddModoS, txtRg, cmp.eRMin, txtA, cmp.eRMax, txtPc] {
            card.ctrls.Push(c2), cmp.otrosCtrls.Push(c2)
        }
        card.filas[n + 18] := n + 5, card.filas[n + 19] := n + 5, card.filas[n + 20] := n + 5
        card.filas[n + 21] := n + 5, card.filas[n + 22] := n + 5, card.filas[n + 23] := n + 5
        card.filas[n + 24] := n + 5

        ; Fila 6: Snap a pasos (independiente de las marcas P1..P5)
        cmp.cbPaso := _R(g.Add("CheckBox", uiP.Call(x0 + 34, yDis + 2, 118, 20), "Snap a pasos"))
        txtPs := _R(g.Add("Text", uiP.Call(x0 + 160, yDis + 2, 40, 20) . " +0x200", "Paso:"))
        cmp.ePaso := _R(g.Add("Edit", uiP.Call(x0 + 202, yDis + 2, 44, 20) . " Number Limit2", ""))
        try SendMessage(0x1501, 1, StrPtr("5"), cmp.ePaso)
        txtPi := _R(g.Add("Text", uiP.Call(x0 + 254, yDis + 2, 188, 20) . " +0x200 cGray", "(1–50; las marcas P1–P5 se conservan)"))
        for c2 in [cmp.cbPaso, txtPs, cmp.ePaso, txtPi] {
            card.ctrls.Push(c2), cmp.otrosCtrls.Push(c2)
        }
        card.filas[n + 25] := n + 6, card.filas[n + 26] := n + 6
        card.filas[n + 27] := n + 6, card.filas[n + 28] := n + 6

        card.alto := 6 + 22 * (n + 7)
        cmp.ddModoS.OnEvent("Change", _CompCampoCambio.Bind(key, "modo"))
        cmp.eRMin.OnEvent("Change", _CompCampoCambio.Bind(key, "rmin"))
        cmp.eRMax.OnEvent("Change", _CompCampoCambio.Bind(key, "rmax"))
        cmp.cbPaso.OnEvent("Click", _CompCampoCambio.Bind(key, "paso_on"))
        cmp.ePaso.OnEvent("Change", _CompCampoCambio.Bind(key, "paso"))
        cmp.eBajar.OnEvent("Change", _CompCampoCambio.Bind(key, "tecla_bajar"))
        cmp.eSubir.OnEvent("Change", _CompCampoCambio.Bind(key, "tecla_subir"))
        cmp.eAH.OnEvent("Change", _CompCampoCambio.Bind(key, "alphaH"))
        cmp.eAF.OnEvent("Change", _CompCampoCambio.Bind(key, "alphaF"))
    } else if (campos = "ventanas") {                       ; Nuevas ventanas y lienzos integrados ; ===== BLOQUE_B_P5_BEGIN =====
        n := lineas.Length
        cmp := {ddModo: "", btnDib: "", btnPes: "", btnVer: "", btnBor: "", stZonas: "", ddUbic: ""}

        ; Fila 1: Visibilidad de ventanas
        card.ctrls.Push(_R(g.Add("Text", uiP.Call(x0 + 34, yDis + 2, 130, 20) . " +0x200", "Visibilidad lienzos:")))
        ddModo := _R(g.Add("DropDownList", uiP.Call(x0 + 168, yDis + 2, 250, 22) . " Choose" (NvEstado().modoGlobal = "desact_25" || NvEstado().modoGlobal = "total" ? 2 : 1), ["Hover (aparece al pasar el lápiz)", "Ocultar total (25 %, bloqueada)"]))
        ddModo.OnEvent("Change", (c, *) => NvSetModo(c.Value = 2 ? "total" : "hover"))
        cmp.ddModo := ddModo
        card.ctrls.Push(ddModo)
        card.filas[n + 1] := n + 1, card.filas[n + 2] := n + 1

        ; Fila 2: Botones directos en un solo toque
        btnDib := _R(g.Add("Button", uiP.Call(x0 + 34, yDis + 2, 170, 22), "➕ Dibujar lienzo 1–8"))
        btnDib.OnEvent("Click", (*) => _NvPanDibujar())
        btnPes := _R(g.Add("Button", uiP.Call(x0 + 212, yDis + 2, 205, 22), "🎯 Calibrar franja de arrastre"))
        btnPes.OnEvent("Click", (*) => _NvPanPestana())
        btnVer := _R(g.Add("Button", uiP.Call(x0 + 34, yDis + 2, 110, 22), "👁 Ver zonas"))
        btnVer.OnEvent("Click", _PtsToggleVerZonas)
        btnBor := _R(g.Add("Button", uiP.Call(x0 + 152, yDis + 2, 100, 22), "🗑 Borrar todo"))
        btnBor.OnEvent("Click", (*) => _NvPanBorrar())
        card.ctrls.Push(btnDib), card.ctrls.Push(btnPes), card.ctrls.Push(btnVer), card.ctrls.Push(btnBor)
        card.filas[n + 3] := n + 2, card.filas[n + 4] := n + 2, card.filas[n + 5] := n + 3, card.filas[n + 6] := n + 3

        ; Fila 3: Ubicación de franja (global; [Particularidades] ventanas_franja_ubic = sup | inf)
        card.ctrls.Push(_R(g.Add("Text", uiP.Call(x0 + 262, yDis + 2, 40, 20) . " +0x200", "Franja:")))
        ddUbic := _R(g.Add("DropDownList", uiP.Call(x0 + 304, yDis + 2, 138) . " Choose" (_CompNvFranjaUbic() = "inf" ? 2 : 1), ["Superior", "Inferior"]))
        ddUbic.OnEvent("Change", (c, *) => _CompNvFranjaUbicGuardar(c))
        cmp.ddUbic := ddUbic
        card.ctrls.Push(ddUbic)
        card.filas[n + 7] := n + 3, card.filas[n + 8] := n + 3

        ; Fila 4: Estado informativo
        stZ := _R(g.Add("Text", uiP.Call(x0 + 34, yDis + 2, 408, 20) . " +0x200 +0x4000 cGray", _NvPanTexto()))
        cmp.stZonas := stZ
        ptsEd.stNvZonas := stZ
        card.ctrls.Push(stZ)
        card.filas[n + 9] := n + 4

        card.alto := 6 + 22 * (n + 4)
    } else if (campos = "quick" || campos = "toggle") {     ; E3: modulación de tecla ; ===== BLOQUE_B_P3_BEGIN =====
        n := lineas.Length
        cmp := {eRep: "", eAct: "", cbB: "", mod: true, eA: "", eB: "", eMs: "", lblReqB: "", lblMs: "", baseA: ""}
        et := (campos = "quick") ? ["Toque corto (A):", "Toque rápido (B):"] : ["Tecla A:", "Tecla B:"]
        isQ := (campos = "quick")
        card.ctrls.Push(_R(g.Add("Text", uiP.Call(x0 + 34, yDis + 2, isQ ? 100 : 54, 20) . " +0x200", et[1])))
        cmp.eA := _R(g.Add("Edit", uiP.Call(x0 + (isQ ? 138 : 90), yDis + 2, 70, 20), ""))
        _KgAttach(cmp.eA, (*) => _CompHeredadoPintar(cmp))
        card.ctrls.Push(cmp.eA)
        card.ctrls.Push(_R(g.Add("Text", uiP.Call(x0 + (isQ ? 218 : 170), yDis + 2, isQ ? 100 : 54, 20) . " +0x200", et[2])))
        cmp.eB := _R(g.Add("Edit", uiP.Call(x0 + (isQ ? 320 : 226), yDis + 2, 70, 20), ""))
        _KgAttach(cmp.eB, (*) => (campos = "toggle" ? _CompReqBRefrescar(cmp) : ""))
        card.ctrls.Push(cmp.eB)
        card.filas[n + 1] := n + 1, card.filas[n + 2] := n + 1
        card.filas[n + 3] := n + 1, card.filas[n + 4] := n + 1
        m := n + 4
        if (campos = "toggle") {
            cmp.lblReqB := _R(g.Add("Text", uiP.Call(x0 + 34, yDis + 2, 408, 20) . " +0x200 cRed", "⚠️ Requiere Tecla B"))
            cmp.lblReqB.Visible := false
            card.ctrls.Push(cmp.lblReqB)
            card.filas[m + 1] := n + 2
            m++
        }
        nFilas := 1
        if (campos = "quick") {
            card.ctrls.Push(_R(g.Add("Text", uiP.Call(x0 + 34, yDis + 2, 100, 20) . " +0x200", "Umbral (ms):")))
            cmp.eMs := _R(g.Add("Edit", uiP.Call(x0 + 138, yDis + 2, 54, 20) . " Number Limit4", ""))
            card.ctrls.Push(cmp.eMs)
            cmp.lblMs := _R(g.Add("Text", uiP.Call(x0 + 200, yDis + 2, 242, 20) . " +0x200 cGray", "⚡ 250 ms (predeterminado)"))
            card.ctrls.Push(cmp.lblMs)
            card.filas[m + 1] := n + 2, card.filas[m + 2] := n + 2, card.filas[m + 3] := n + 2
            nFilas := 2
        }
        card.alto := 6 + 22 * (n + nFilas + (campos = "toggle" ? 1 : 0))
        cmp.eA.OnEvent("Change", _CompCampoCambio.Bind(key, "a"))
        cmp.eA.OnEvent("Change", _CompHeredadoPintar.Bind(cmp))
        cmp.eB.OnEvent("Change", _CompCampoCambio.Bind(key, "b"))
        if (campos = "toggle")
            cmp.eB.OnEvent("Change", _CompReqBRefrescar.Bind(cmp))
        if (IsObject(cmp.eMs)) {
            cmp.eMs.OnEvent("Change", _CompCampoCambio.Bind(key, "ms"))
            cmp.eMs.OnEvent("Change", _CompMsIcono.Bind(cmp))
        }
    } else if (campos = "pildora") {                        ; E1: Píldora Táctil ; ===== BLOQUE_B_P1_BEGIN =====
        n := lineas.Length
        cmp := {btnUbic: "", eTam: "", eCol: "", swCol: "", bReset: "", pill: true}
        btnUbic := _R(g.Add("Button", uiP.Call(x0 + 312, yDis + 1, 130, 24), "⌖ Ubicar en pantalla"))
        btnUbic.OnEvent("Click", (*) => _PtsPildoraUbicar())
        cmp.btnUbic := btnUbic
        ptsEd.bPildora := btnUbic
        card.ctrls.Push(btnUbic)
        card.filas[n + 1] := n + 1

        ; Fila 1: Tamaño + Color + Ubicar (ancho útil x0+34 .. x0+442)
        card.ctrls.Push(_R(g.Add("Text", uiP.Call(x0 + 34, yDis + 2, 56, 20) . " +0x200", "Tamaño %:")))
        cmp.eTam := _R(g.Add("Edit", uiP.Call(x0 + 92, yDis + 2, 38, 20) . " Limit3", ""))
        try SendMessage(0x1501, 1, StrPtr("100"), cmp.eTam)
        card.ctrls.Push(cmp.eTam)
        card.ctrls.Push(_R(g.Add("Text", uiP.Call(x0 + 140, yDis + 2, 34, 20) . " +0x200", "Color:")))
        cmp.eCol := _R(g.Add("Edit", uiP.Call(x0 + 176, yDis + 2, 62, 20) . " Limit7", ""))
        try SendMessage(0x1501, 1, StrPtr("7863A6"), cmp.eCol)
        card.ctrls.Push(cmp.eCol)
        cmp.swCol := _R(g.Add("Text", uiP.Call(x0 + 244, yDis + 2, 20, 18) . " +Border Background7863A6", ""))
        card.ctrls.Push(cmp.swCol)
        cmp.bReset := _R(g.Add("Button", uiP.Call(x0 + 270, yDis + 1, 34, 22), "↺"))
        card.ctrls.Push(cmp.bReset)
        card.filas[n + 2] := n + 1, card.filas[n + 3] := n + 1, card.filas[n + 4] := n + 1
        card.filas[n + 5] := n + 1, card.filas[n + 6] := n + 1, card.filas[n + 7] := n + 1
        card.alto := 6 + 22 * (n + 1)
        cmp.eTam.OnEvent("Change", _CompCampoCambio.Bind(key, "tam"))
        cmp.eCol.OnEvent("Change", _CompCampoCambio.Bind(key, "color"))
        cmp.bReset.OnEvent("Click", (*) => _CompPildoraReset())
    } else if (campos = "rango") {                          ; Dibujo directo de zona
        n := lineas.Length
        cmp := {btnDib: ""}
        btnDib := _R(g.Add("Button", uiP.Call(x0 + 34, yDis + 2, 180, 22), "✏ Dibujar zona / rango"))
        btnDib.OnEvent("Click", (*) => _PtsDibujarZonaEvento(key))
        cmp.btnDib := btnDib
        card.ctrls.Push(btnDib)
        card.filas[n + 1] := n + 1
        card.alto := 6 + 22 * (n + 1)
    } else if (campos != "") {                              ; E2: "rep" [+ " act"] [+ " borde"]
        n := lineas.Length
        cmp := {eRep: "", eAct: "", cbB: ""}
        card.ctrls.Push(_R(g.Add("Text", uiP.Call(x0 + 34, yDis + 2, 84, 20) . " +0x200", "Opac. reposo %:")))
        cmp.eRep := _R(g.Add("Edit", uiP.Call(x0 + 120, yDis + 2, 40, 20), ""))
        card.ctrls.Push(cmp.eRep)
        card.filas[n + 1] := n + 1, card.filas[n + 2] := n + 1
        m := n + 2
        if (InStr(campos, "act")) {
            card.ctrls.Push(_R(g.Add("Text", uiP.Call(x0 + 170, yDis + 2, 84, 20) . " +0x200", "Opac. activa %:")))
            cmp.eAct := _R(g.Add("Edit", uiP.Call(x0 + 256, yDis + 2, 40, 20), ""))
            card.ctrls.Push(cmp.eAct)
            card.filas[m + 1] := n + 1, card.filas[m + 2] := n + 1
            m += 2
        }
        nFilas := 1
        if (InStr(campos, "borde")) {
            cmp.cbB := _R(g.Add("CheckBox", uiP.Call(x0 + (InStr(campos, "act") ? 306 : 170), yDis + 2, 70, 20), "Borde"))
            card.ctrls.Push(cmp.cbB)
            card.filas[m + 1] := n + 1
            nFilas := 1
        }
        card.alto := 6 + 22 * (n + nFilas)
        cmp.eRep.OnEvent("Change", _CompCampoCambio.Bind(key, "op_rep"))
        if (IsObject(cmp.eAct))
            cmp.eAct.OnEvent("Change", _CompCampoCambio.Bind(key, "op_act"))
        if (IsObject(cmp.cbB))
            cmp.cbB.OnEvent("Click", _CompCampoCambio.Bind(key, "borde"))
    }
    COMP.filas.Push({key: key, bloque: bloque, pend: pend, cb: cb, gear: gear, why: why, card: card, campos: cmp})
    if (pend) {                                      ; fila reservada: visible pero inerte hasta su fase
        cb.Enabled := false
        gear.Text := ""
        why.Text := "Próximamente"
    }
    cb.OnEvent("Click", _CompCbClick.Bind(key))     ; se ejecuta ANTES del handler existente (_PtsEvPartToggle)
    gear.OnEvent("Click", _CompGear.Bind(key))
    return cb
}
_CompFilaDe(key) {
    global COMP
    for f in COMP.filas
        if (f.key = key)
            return f
    return 0
}
; Fuente única de altura del cuerpo de cada bloque abierto (la usan _CompAlto y _CompPos)
_CompAltoBloque(id) {
    switch (id) {
        case "b1": return _AccPx(32)
        case "b2": return _AccPx(140)    ; 3 columnas + opacidades + borde (ajustar tras prueba visual)
        case "b3": return _AccPx(105)    ; pulsación/alternador + umbral + toque largo
        case "b4": return _AccPx(54)
        case "b5": return _AccPx(54)
        default:   return _AccPx(30)
    }
}
_CompAlto() {
    global ACC, COMP
    h := _AccPx(34)                                  ; espacio inicial tras lblEv
    for bl in COMP.bloques {
        h += _AccPx(40)                              ; cabecera de tarjeta (número + título + subtítulo + divisor)
        if (!bl.abierto)
            continue
        h += _CompAltoBloque(bl.id)
    }
    return h + ACC.pad
}
_CompPos(y, yTop := 0, yBottom := 99999) {   ; y = tope del panel; recorta visibilidad al viewport
    global ACC, COMP
    x0 := ACC.x0
    vis := (cy, ch := 20) => (cy >= yTop && cy + _AccPx(ch) <= yBottom)
    COMP.lblEv.Move(, y + _AccPx(16))
    COMP.lblEv.Visible := vis(y + _AccPx(16), 18)
    ry := y + _AccPx(36)
    for bl in COMP.bloques {
        ; Cabecera estilo mockup: número + título + subtítulo + chevrón
        bl.hdrNum.Move(, ry + _AccPx(1)),  bl.hdrNum.Visible := vis(ry, 18)
        bl.hdr.Move(, ry + _AccPx(1)),     bl.hdr.Visible := vis(ry, 18)
        bl.hdrSub.Move(, ry + _AccPx(19)), bl.hdrSub.Visible := vis(ry + _AccPx(19), 16)
        bl.chev.Move(, ry + _AccPx(8)),    bl.chev.Visible := vis(ry + _AccPx(8), 20)
        bl.lin.Move(, ry + _AccPx(37)),    bl.lin.Visible := vis(ry + _AccPx(37), 2)
        ry += _AccPx(40)

        if (!bl.abierto) {
            for f in COMP.filas {
                if (f.bloque != bl.id)
                    continue
                f.cb.Visible := false, f.gear.Visible := false, f.why.Visible := false
                for c in f.card.ctrls
                    c.Visible := false
            }
            continue
        }

        ; Renderizado expandido según el bloque
        switch (bl.id) {
            case "b1":                               ; 01 · Presencia y superficie (fila única horizontal)
                f := _CompFilaDe("pildora")
                if (f) {
                    f.cb.Move(x0 + _AccPx(34), ry + _AccPx(2), _AccPx(140), _AccPx(22))
                    f.cb.Visible := vis(ry, 22)
                    f.gear.Visible := false, f.why.Visible := false
                    for c in f.card.ctrls {
                        c.Move(, ry + _AccPx(2))
                        c.Visible := vis(ry + _AccPx(2), 22)
                    }
                    ry += _AccPx(32)
                }
            case "b2":                               ; 02 · Disparador espacial (3 columnas horizontales)
                cCruzar := _CompFilaDe("cruzar")
                cAuto   := _CompFilaDe("auto")
                cHover  := _CompFilaDe("hover")
                ; Columna 1: Paso ➔ Tecla
                if (cCruzar) {
                    xCol := x0 + _AccPx(34)
                    cCruzar.cb.Move(xCol, ry, _AccPx(125), _AccPx(20))
                    cCruzar.cb.Visible := vis(ry, 20)
                    cCruzar.gear.Visible := false, cCruzar.why.Visible := false
                    if (cCruzar.card.ctrls.Length >= 2) {
                        cCruzar.card.ctrls[1].Move(xCol, ry + _AccPx(22), _AccPx(125), _AccPx(28))  ; descripción
                        cCruzar.card.ctrls[1].Visible := vis(ry + _AccPx(22), 28)
                        cCruzar.card.ctrls[2].Move(xCol, ry + _AccPx(54), _AccPx(125), _AccPx(24))  ; botón dibujar
                        cCruzar.card.ctrls[2].Visible := vis(ry + _AccPx(54), 24)
                    }
                }
                ; Columna 2: Paso ➔ Clic
                if (cAuto) {
                    xCol := x0 + _AccPx(168)
                    cAuto.cb.Move(xCol, ry, _AccPx(125), _AccPx(20))
                    cAuto.cb.Visible := vis(ry, 20)
                    cAuto.gear.Visible := false, cAuto.why.Visible := false
                    if (cAuto.card.ctrls.Length >= 2) {
                        cAuto.card.ctrls[1].Move(xCol, ry + _AccPx(22), _AccPx(125), _AccPx(28))
                        cAuto.card.ctrls[1].Visible := vis(ry + _AccPx(22), 28)
                        cAuto.card.ctrls[2].Move(xCol, ry + _AccPx(54), _AccPx(125), _AccPx(24))
                        cAuto.card.ctrls[2].Visible := vis(ry + _AccPx(54), 24)
                    }
                }
                ; Columna 3: Hover por rango
                if (cHover) {
                    xCol := x0 + _AccPx(302)
                    cHover.cb.Move(xCol, ry, _AccPx(140), _AccPx(20))
                    cHover.cb.Visible := vis(ry, 20)
                    cHover.gear.Visible := false, cHover.why.Visible := false
                    if (cHover.card.ctrls.Length >= 1) {
                        cHover.card.ctrls[1].Move(xCol, ry + _AccPx(22), _AccPx(140), _AccPx(16))
                        cHover.card.ctrls[1].Visible := vis(ry + _AccPx(22), 16)
                    }
                    for i, c in cHover.card.ctrls {
                        if (i > 1) {
                            c.Move(, ry + _AccPx(42))
                            c.Visible := vis(ry + _AccPx(42), 20)
                        }
                    }
                }
                ry += _CompAltoBloque("b2")
            case "b3":                               ; 03 · Modulación de tecla (2 columnas horizontales)
                cQ := _CompFilaDe("quick")
                cT := _CompFilaDe("toggle")
                if (cQ) {
                    xCol := x0 + _AccPx(34)
                    cQ.cb.Move(xCol, ry, _AccPx(190), _AccPx(20))
                    cQ.cb.Visible := vis(ry, 20)
                    cQ.gear.Visible := false, cQ.why.Visible := false
                    for c in cQ.card.ctrls {
                        c.Move(, ry + _AccPx(24))
                        c.Visible := vis(ry + _AccPx(24), 22)
                    }
                }
                if (cT) {
                    xCol := x0 + _AccPx(232)
                    cT.cb.Move(xCol, ry, _AccPx(190), _AccPx(20))
                    cT.cb.Visible := vis(ry, 20)
                    cT.gear.Visible := false, cT.why.Visible := false
                    for c in cT.card.ctrls {
                        c.Move(, ry + _AccPx(24))
                        c.Visible := vis(ry + _AccPx(24), 22)
                    }
                }
                ry += _CompAltoBloque("b3")
            default:                                 ; b4 y b5: filas horizontales
                for f in COMP.filas {
                    if (f.bloque != bl.id)
                        continue
                    f.cb.Move(x0 + _AccPx(34), ry, _AccPx(200), _AccPx(20))
                    f.cb.Visible := vis(ry, 20)
                    f.gear.Visible := false, f.why.Visible := false
                    for i, c in f.card.ctrls {
                        cy := ry + _AccPx(22 + ((f.card.filas.Has(i) ? f.card.filas[i] : i) - 1) * 22)
                        c.Move(, cy)
                        c.Visible := vis(cy, 20)
                    }
                    ry += _AccPx(f.card.alto)
                }
        }
    }
}
_CompTextos() {
    global COMP
    idEv := _PtsSndIdEv()
    caps := _PtsEvCaps(idEv)
    for f in COMP.filas {
        cOk := (HasProp(caps, f.key) && caps.%f.key%)
        if (f.pend) {                                ; reservada: solo informa si aplicará a este evento
            ok := (idEv != "" && cOk)
            f.why.Text := idEv = "" ? "Selecciona un evento" : (ok ? "Próximamente" : "No aplica a este evento")
            f.gear.Text := ""
            continue
        }
        ok := (idEv != "" && cOk)
        f.why.Text := ok ? "" : (idEv = "" ? "Selecciona un evento" : "No aplica a este evento")
        f.gear.Text := "⚙ Ajustes " (COMP.abierta = f.key ? "▾" : "▸")
    }
}
_CompCbClick(key, ctrl, *) {
    global COMP
    if (ctrl.Value)
        COMP.abierta := key                          ; activar abre su tarjeta (cierra la otra)
    else if (COMP.abierta = key)
        COMP.abierta := ""                           ; desactivar cierra, conserva la config
    if (ctrl.Value && (key = "cruzar" || key = "auto")
        && ptsEd.evSel && ptsEd.mapFilas.Has(ptsEd.evSel))
        _PtsExcluirOpuesto(key, _PtsEventosDefs()[ptsEd.mapFilas[ptsEd.evSel]][1])
    if (key = "pildora") && HasProp(ptsEd, "bPildora")
        ptsEd.bPildora.Enabled := (ctrl.Value = 1)
    _CompTextos()
    _AccRelayout()
}
_CompGear(key, *) {
    global COMP
    f := _CompFilaDe(key)
    if (!f || !f.cb.Enabled)
        return
    COMP.abierta := (COMP.abierta = key) ? "" : key
    _CompTextos()
    _AccRelayout()
}
; Llamado desde _AccRefrescarResumen (cambio de evento): cierra tarjetas de filas que ya no aplican
_CompRefrescar() {
    global COMP
    if (!IsSet(COMP) || !IsObject(COMP) || !COMP.panel)
        return
    idEv := _PtsSndIdEv()
    caps := _PtsEvCaps(idEv)
    antes := COMP.abierta
    if (COMP.abierta != "") {
        f := _CompFilaDe(COMP.abierta)
        if (!f || idEv = "" || !HasProp(caps, f.key) || !caps.%f.key%)
            COMP.abierta := ""
    }
    _CompTextos()
    if (HasProp(ptsEd, "bPildora") && IsObject(ptsEd.bPildora) && HasProp(ptsEd, "cbPill") && IsObject(ptsEd.cbPill))
        ptsEd.bPildora.Enabled := (ptsEd.cbPill.Value = 1)
    if (COMP.abierta != antes)
        _AccRelayout()                               ; solo si cambió el alto
}
