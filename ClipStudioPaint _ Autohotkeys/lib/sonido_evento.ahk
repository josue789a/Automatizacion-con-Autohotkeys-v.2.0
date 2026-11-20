; ═══════════ SONIDO DE EVENTOS · Fase B ═══════════
; INI [HudSonido<PERFIL>]: global_activo/tipo/vol · ev_<id>_activo/tipo/vol (vacío = hereda)

_SndTiposDef() {
    static d := {claves: ["clic","suave","agudo","grave","doble","pluma","aerografo","color_primario","color_secundario","borrador","lazo","relleno","guardar","mute"], nombres: ["Clic","Clic suave","Beep agudo","Beep grave","Doble beep","Plumilla (Q)","Aerógrafo (W)","Color Primario","Color Secundario","Borrador","Lazo / Sel","Relleno","Guardar","Silencio"]}
    return d
}

; Tipo por defecto por evento cuando el INI no define ev_<id>_tipo.
; 1) subcadena temática  2) hash estable del id -> rotación de tonos distintos
_SndTipoPorDefecto(idEv) {
    static pat := [["pluma", "pluma"], ["aero", "aerografo"]
                 , ["primari", "color_primario"], ["secundari", "color_secundario"]
                 , ["borrador", "borrador"], ["goma", "borrador"]
                 , ["lazo", "lazo"], ["selec", "lazo"]
                 , ["relleno", "relleno"], ["cubeta", "relleno"]
                 , ["guardar", "guardar"], ["save", "guardar"]]
    static rot := ["clic", "agudo", "grave", "doble"]
    id := StrLower(idEv)
    for p in pat {
        if InStr(id, p[1])
            return p[2]
    }
    h := 0
    Loop Parse id
        h += Ord(A_LoopField)
    return rot[Mod(h, rot.Length) + 1]
}
_SndIdxTipo(tipo) {
    for i, k in _SndTiposDef().claves
        if (k = tipo)
            return i
    return 1
}
_SndCacheMap() {
    static m := Map()
    return m
}

; Config efectiva. idEv="" → global; idEv dado → global + override del evento (por campo)
_SndLeer(idEv := "") {
    global PERFIL
    m := _SndCacheMap()
    kc := PERFIL "|" idEv
    if (m.Has(kc))
        return m[kc]
    ini := _PosGuiIniPath()
    sec := "HudSonido" PERFIL
    act := IniRead(ini, sec, "global_activo", "0")
    tipo := IniRead(ini, sec, "global_tipo", "clic")
    vol := IniRead(ini, sec, "global_vol", "60")
    propio := false
    if (idEv != "") {
        a := IniRead(ini, sec, "ev_" idEv "_activo", "")
        t := IniRead(ini, sec, "ev_" idEv "_tipo", "")
        v := IniRead(ini, sec, "ev_" idEv "_vol", "")
        if (a != "") {
            act := a
            propio := true
        }
        if (t != "") {
            tipo := t
            propio := true
        } else if (IniRead(ini, sec, "snd_ambito_" idEv, "") != "global") {
            tipo := _SndTipoPorDefecto(idEv)   ; derivado: propio sigue en false
        }
        if (v != "") {
            vol := v
            propio := true
        }
    }
    idx := _SndIdxTipo(tipo)
    vol := IsInteger(vol) ? Min(100, Max(0, Integer(vol))) : 60
    r := {act: (act = "1"), tipo: _SndTiposDef().claves[idx], nombre: _SndTiposDef().nombres[idx], vol: vol, propio: propio}
    m[kc] := r
    return r
}

; ── Motor: WAV en memoria + PlaySound asíncrono ──
_SndWav(tipo, vol) {
    static cache := Map()
    k := tipo "|" vol
    if (cache.Has(k))
        return cache[k]
    sr := 22050
    switch tipo {
        case "suave": segs := [[1800, 10]]
        case "agudo": segs := [[1500, 90]]
        case "grave": segs := [[520, 120]]
        case "doble": segs := [[1100, 55], [0, 45], [1100, 55]]
        default:      segs := [[2300, 14]]
    }
    n := 0
    for s in segs
        n += Integer(sr * s[2] / 1000)
    buf := Buffer(44 + n * 2, 0)
    NumPut("UInt", 0x46464952, "UInt", 36 + n * 2, "UInt", 0x45564157, "UInt", 0x20746D66, "UInt", 16
         , "UShort", 1, "UShort", 1, "UInt", sr, "UInt", sr * 2, "UShort", 2, "UShort", 16
         , "UInt", 0x61746164, "UInt", n * 2, buf, 0)
    amp := 32000 * (vol / 100) ** 2
    twoPi := 8 * ATan(1)
    att := Max(1, Integer(sr * 0.002))
    off := 44
    for s in segs {
        m := Integer(sr * s[2] / 1000)
        if (s[1] > 0) {
            Loop m {
                i := A_Index - 1
                env := Min(1, i / att) * (1 - i / m) ** 1.5
                NumPut("Short", Round(amp * env * Sin(twoPi * s[1] * i / sr)), buf, off + i * 2)
            }
        }
        off += m * 2
    }
    cache[k] := buf              ; el buffer debe seguir vivo mientras suena (async)
    return buf
}
_SndTocar(tipo, vol) {
    if (vol <= 0 || tipo = "mute")
        return
    switch tipo {
        case "pluma", "aerografo", "color_primario", "color_secundario":
            try _SonarFast(tipo)
        case "borrador", "lazo", "relleno", "guardar":
            try _SonarUI(tipo)
        default:
            DllCall("winmm\PlaySoundW", "Ptr", _SndWav(tipo, vol), "Ptr", 0, "UInt", 0x7)  ; MEMORY|ASYNC|NODEFAULT
    }
}

; ── Hook (lo llama _AvisoEvento) ──
_SndEvento(clave) {
    try {
        c := _SndLeer(clave)
        if (c.act && c.vol > 0)
            _SndTocar(c.tipo, c.vol)
    }
}

; ── UI de la pestaña 1 ──
_PtsSndIdEv() {
    if (!IsObject(ptsEd) || !ptsEd.evSel || !ptsEd.mapFilas.Has(ptsEd.evSel))
        return ""
    return _PtsEventosDefs()[ptsEd.mapFilas[ptsEd.evSel]][1]
}
_PtsSndRefrescar(*) {
    if (!IsObject(ptsEd) || !HasProp(ptsEd, "ddSndAmb"))
        return
    idEv := _PtsSndIdEv()
    if (idEv = "" && ptsEd.ddSndAmb.Value = 2)
        ptsEd.ddSndAmb.Choose(1)
    evSc := (ptsEd.ddSndAmb.Value = 2 && idEv != "")
    c := _SndLeer(evSc ? idEv : "")
    ptsEd.sndBusy := true
    try {
        ptsEd.cbSndAct.Value := c.act ? 1 : 0
        ptsEd.ddSndTipo.Choose(_SndIdxTipo(c.tipo))
        ptsEd.slSndVol.Value := c.vol
        ptsEd.lblSndVol.Text := c.vol "%"
        ptsEd.bSndHeredar.Enabled := (evSc && c.propio)
        ptsEd.lblSndEfec.Text := evSc
            ? "Efectivo: " (c.act ? c.nombre " · " c.vol "%" : "silenciado") " · " (c.propio ? "propio del evento" : "heredado de Global")
            : "Global · rige en todo evento sin ajuste propio"
    } finally
        ptsEd.sndBusy := false
}
_PtsSndCambio(prev := false, *) {
    if (ptsEd.sndBusy)
        return
    global PERFIL
    act := ptsEd.cbSndAct.Value ? "1" : "0"
    tipo := _SndTiposDef().claves[Max(1, ptsEd.ddSndTipo.Value)]
    vol := ptsEd.slSndVol.Value
    ini := _PosGuiIniPath()
    sec := "HudSonido" PERFIL
    idEv := _PtsSndIdEv()
    if (ptsEd.ddSndAmb.Value = 2 && idEv != "") {
        IniWrite(act, ini, sec, "ev_" idEv "_activo")
        IniWrite(tipo, ini, sec, "ev_" idEv "_tipo")
        IniWrite(vol, ini, sec, "ev_" idEv "_vol")
        if (IsSet(_PtsEvLimpiarPend))
            _PtsEvLimpiarPend(idEv)
    } else {
        IniWrite(act, ini, sec, "global_activo")
        IniWrite(tipo, ini, sec, "global_tipo")
        IniWrite(vol, ini, sec, "global_vol")
    }
    _SndCacheMap().Clear()
    _AccRefrescarResumen()                 ; incluye _PtsSndRefrescar()
    if (prev)
        _SndTocar(tipo, vol)
}
_PtsSndVolChange(*) {
    static f := _PtsSndCambio.Bind(true)
    ptsEd.lblSndVol.Text := ptsEd.slSndVol.Value "%"
    SetTimer(f, -250)                      ; debounce: escribe y previsualiza al soltar
}
_PtsSndHeredar(*) {
    global PERFIL
    idEv := _PtsSndIdEv()
    if (idEv = "")
        return
    for k in ["activo", "tipo", "vol"]
        try IniDelete(_PosGuiIniPath(), "HudSonido" PERFIL, "ev_" idEv "_" k)
    _SndCacheMap().Clear()
    _AccRefrescarResumen()
}
_PtsSndProbar(*) {
    _SndTocar(_SndTiposDef().claves[Max(1, ptsEd.ddSndTipo.Value)], ptsEd.slSndVol.Value)
}
_AccResumenSnd() {
    c := _SndLeer(_PtsSndIdEv())
    return c.act ? c.nombre " · " c.vol "%" : "Silencio"
}
