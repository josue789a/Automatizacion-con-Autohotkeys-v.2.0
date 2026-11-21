#Requires AutoHotkey v2.0
; [LIB] core_config — fuente: XPPEN AHK VERSION ESTABLE.ahk L1283–1299, L2677–2795, L4158–4296 y L4884–4909
; POSGUI_INI_OVERRIDE, SANDBOX_ACTIVO y _gDurCache se declaran en el encabezado de cada script principal

ObtenerMonitorCSP() {
    ; Regla forzada: >1 monitor -> siempre la tableta; 1 monitor -> el único (primario)
    mon := (MonitorGetCount() > 1) ? CmpMonitorTableta() : MonitorGetPrimary()
    MonitorGet(mon, &mL, &mT, &mR, &mB)
    return {x:mL, y:mT, w:mR - mL, h:mB - mT}
}
_PosGuiIniPath() => (IsSet(POSGUI_INI_OVERRIDE) && POSGUI_INI_OVERRIDE != "")
    ? POSGUI_INI_OVERRIDE
    : (A_ScriptDir "\posiciones_gui.ini")
GuardarPosicionGUI(nombre,hwnd) {
    global PERFIL
    sec := nombre "_p" PERFIL
    rc := Buffer(16,0)
    DllCall("GetWindowRect","Ptr",hwnd,"Ptr",rc)
    IniWrite(NumGet(rc,0,"int"),_PosGuiIniPath(),sec,"x")
    IniWrite(NumGet(rc,4,"int"),_PosGuiIniPath(),sec,"y")
}
LeerPosicionGUI(nombre) {
    global PERFIL
    for sec in [nombre "_p" PERFIL,nombre] {
        x := IniRead(_PosGuiIniPath(),sec,"x","")
        y := IniRead(_PosGuiIniPath(),sec,"y","")
        if (x != "" && y != "")
            return {x:Integer(x),y:Integer(y)}
    }
    return 0
}
_PosicionValidaEnPantalla(x,y) {
    Loop MonitorGetCount() {
        MonitorGet(A_Index,&l,&t,&r,&b)
        if (x >= l && x <= r && y >= t && y <= b)
            return true
    }
    return false
}
_MonitorDePunto(x,y) {
    Loop MonitorGetCount() {
        MonitorGet(A_Index,&l,&t,&r,&b)
        if (x >= l && x < r && y >= t && y < b)
            return A_Index
    }
    return 0
}
_RectaDentroDeMonitor(x,y,w,h) {
    Loop MonitorGetCount() {
        MonitorGet(A_Index,&l,&t,&r,&b)
        if (x >= l && x + w <= r && y >= t && y + h <= b)
            return true
    }
    return false
}
_RectaFijaEnPantalla(x,y,w,h) {
    ; Posicion donde el rectangulo ENTERO cabe en un monitor; si el punto no esta en
    ; ninguno, se elige el monitor mas cercano y se recorta hacia dentro.
    n := MonitorGetCount()
    if (n = 0)
        return {x:Integer(x),y:Integer(y)}
    idx := _MonitorDePunto(x,y)
    if (idx = 0) {
        mejor := 1, dist := -1
        Loop n {
            MonitorGet(A_Index,&l,&t,&r,&b)
            dx := Max(l - (x + w),x - r,0)
            dy := Max(t - (y + h),y - b,0)
            d := dx * dx + dy * dy
            if (dist < 0 || d < dist)
                dist := d, mejor := A_Index
        }
        idx := mejor
    }
    MonitorGet(idx,&l,&t,&r,&b)
    return {x: Max(l,Min(x,r - Min(w,r - l))),y: Max(t,Min(y,b - Min(h,b - t)))}
}
_EsquinaPanelBloque(i) {
    global PANEL_GAP
    ; Casilla visible y predecible para un panel cuyo puesto calculado no cabe.
    ; i = 0,1,2... evita montar dos paneles en la misma casilla.
    mon := ObtenerMonitorCSP()
    gap := IsSet(PANEL_GAP) ? PANEL_GAP : 6
    return {x: mon.x + 4,y: mon.y + 4 + i * (_E(25) + gap)}
}
_PanelFijaEnPantalla(gui) {
    try {
        WinGetPos(&x,&y,&w,&h,"ahk_id " gui.Hwnd)
    } catch
        return
    if (w < 2 || h < 2)
        return
    if (_RectaDentroDeMonitor(x,y,w,h))
        return
    s := _RectaFijaEnPantalla(x,y,w,h)
    if (s.x != x || s.y != y)
        DllCall("SetWindowPos","Ptr",gui.Hwnd,"Ptr",0,"int",s.x,"int",s.y,"int",0,"int",0,"uint",0x0001 | 0x0004 | 0x0010)
}
_AnclaBloquePaneles() {
    static ancla := 0
    if IsObject(ancla)
        return ancla
    mon := ObtenerMonitorCSP()
    anchoBloque := _AnchoBtn("SLIDER") + PANEL_GAP + _AnchoBtn("CIRCLE") + PANEL_GAP + _AnchoBtn("QUICK")
    defX := mon.x + (mon.w - anchoBloque) // 2
    defY := mon.y + Round(mon.h * 0.02) + 42 + 4
    guardada := LeerPosicionGUI("PanelBlock")
    if IsObject(guardada) && _PosicionValidaEnPantalla(guardada.x,guardada.y) {
        ancla := guardada
        return ancla
    }
    vieja := LeerPosicionGUI("Slider")
    if IsObject(vieja) && _PosicionValidaEnPantalla(vieja.x,vieja.y) {
        ancla := vieja
        return ancla
    }
    ancla := {x:defX,y:defY}
    return ancla
}

; ── Ancho dinámico de pills (icono + texto + margen derecho) ──
_AnchoTextoPill(txt) {
    static cache := Map()
    if cache.Has(txt)
        return cache[txt]
    gm := Gui("-Caption +ToolWindow")
    gm.MarginX := 0
    gm.MarginY := 0
    gm.SetFont("s" _FS(9) " bold", "Segoe UI")
    t := gm.Add("Text", "x0 y0", txt)
    t.GetPos(, , &tw)
    gm.Destroy()
    cache[txt] := tw
    return tw
}

_PillAnchoPara(txt, xTexto := 26, margenDer := 8) {
    return _E(xTexto) + _AnchoTextoPill(txt) + _E(margenDer)
}

_AnchoBtn(clave) {
    static cache := Map()
    if cache.Has(clave)
        return cache[clave]
    if (clave = "ESTAB")
        w := Max(_PillAnchoPara("STAB ON"), _PillAnchoPara("STAB OFF"))   ; el más ancho de sus dos estados
    else
        w := _PillAnchoPara(clave)   ; "SLIDER" | "CIRCLE" | "QUICK" | "HC"
    cache[clave] := w
    return w
}

GuardarIniDiferido(archivo, seccion, clave, valor) {
    global _iniPend
    _iniPend[archivo "|" seccion "|" clave] := valor
    SetTimer(_FlushIni, -400)
}
_FlushIni() {
    global _iniPend, _gDurCache
    for k, v in _iniPend {
        p := StrSplit(k, "|")
        IniWrite(v, p[1], p[2], p[3])
    }
    _gDurCache.Clear()
    _iniPend := Map()
}

PuntosPorDefecto() {
    global PUNTOS_DEF
    r := []
    if (!IsSet(PUNTOS_DEF) || !IsObject(PUNTOS_DEF))
        return r
    for p in PUNTOS_DEF
        r.Push([p[1],p[2]])
    return r
}
; ---- Zonas duales: Modo 1 Normal / Modo 2 Enfoque ----
; Contexto = modo elegido en el panel (mientras está abierto) o, si no, el modo vivo de CSP.
_ZonaModo() {
    global enfoque,ptsModo
    if (ptsModo.edit)
        return (ptsModo.sel = 2) ? 2 : 1
    return enfoque.activo ? 2 : 1
}
_ZonaSuf(modo := 0) {
    if (modo = 0)
        modo := _ZonaModo()
    return (modo = 2) ? "_Enfoque" : ""
}
_ZonaSec(base, modo := 0) {
    global PERFIL
    return base . PERFIL . _ZonaSuf(modo)
}
_PtsCache(reset := false) {
    static m := Map()
    if (reset)
        m.Clear()
    return m
}
CargarPuntos(modo := 0) {
    global PUNTOS,HIST_ALTO,PERFIL,PUNTOS_DEF
    ini := _PosGuiIniPath()
    suf := _ZonaSuf(modo)
    sec := _ZonaSec("Puntos",modo)
    PUNTOS := []
    if (!IsSet(PUNTOS_DEF) || !IsObject(PUNTOS_DEF))
        return
    cache := _PtsCache()
    key := ini "|" sec "|" PUNTOS_DEF.Length    ; sec ya incluye PERFIL y sufijo de modo
    if (!cache.Has(key)) {
        c := {xy: [], h: ""}
        for i,p in PUNTOS_DEF {
            x := IniRead(ini,sec,"P" i "x","")
            y := IniRead(ini,sec,"P" i "y","")
            if ((x = "" || y = "") && suf != "") {
                x := IniRead(ini,_ZonaSec("Puntos",1),"P" i "x","")
                y := IniRead(ini,_ZonaSec("Puntos",1),"P" i "y","")
            }
            if ((x = "" || y = "") && PERFIL = 1) {
                x := IniRead(ini,"Puntos","P" i "x","")
                y := IniRead(ini,"Puntos","P" i "y","")
            }
            c.xy.Push([x,y])
        }
        h := IniRead(ini,sec,"HistAlto","")
        if (h = "" && suf != "")
            h := IniRead(ini,_ZonaSec("Puntos",1),"HistAlto","")
        if (h = "" && PERFIL = 1)
            h := IniRead(ini,"Puntos","HistAlto","")
        c.h := h
        cache[key] := c
    }
    c := cache[key]
    for i,p in PUNTOS_DEF {
        x := c.xy[i][1], y := c.xy[i][2]
        if (IsInteger(x) && IsInteger(y))
            PUNTOS.Push([Integer(x),Integer(y)])
        else
            PUNTOS.Push([p[1],p[2]])
    }
    HIST_ALTO := IsInteger(c.h) ? Integer(c.h) : 104
    RecalcularZonas()
}
GuardarPuntos(conFirma := true) {
    global PUNTOS,HIST_ALTO,PERFIL
    ini := _PosGuiIniPath()
    sec := _ZonaSec("Puntos")
    for i,p in PUNTOS {
        IniWrite(p[1],ini,sec,"P" i "x")
        IniWrite(p[2],ini,sec,"P" i "y")
    }
    IniWrite(HIST_ALTO,ini,sec,"HistAlto")
    if (conFirma)
        IniWrite(_FirmaMonitores(),ini,sec,"firma")
    _PtsCache(true)
}
CargarEscala() {
    global ESC,PERFIL
    v := IniRead(_PosGuiIniPath(),"Puntos" PERFIL,"escala","")
    if (!IsNumber(v) || Number(v) < 40 || Number(v) > 200)
        v := (PERFIL = 1) ? 75 : 100
    ESC := Number(v) / 100
}
CargarEscalaAvisos() {
    global AVISO_ESC,ESC,PERFIL
    v := IniRead(_PosGuiIniPath(),"Puntos" PERFIL,"escalaAvisos","")
    if (!IsNumber(v) || Number(v) < 40 || Number(v) > 250)
        v := Round(ESC * 110)
    AVISO_ESC := Number(v) / 100
}
_E(n) => Max(1,Round(n * ESC))
_FS(n) => Max(6,Round(n * ESC))
_FirmaMonitores() {
    f := ""
    Loop MonitorGetCount() {
        MonitorGet(A_Index,&l,&t,&r,&b)
        f .= (f = "" ? "" : ";") l "," t "," r "," b
    }
    f := Sort(f,"D;")
    return f
}
_DetectarMonitoresHardware() {
    try {
        wmi := ComObjGet("winmgmts:\\.\root\wmi")
        col := wmi.ExecQuery("SELECT MaxHorizontalImageSize, InstanceName FROM WmiMonitorBasicDisplayParams WHERE Active=True")
        tieneMonitorGrande := false
        tieneLaptop := false
        tieneTableta := false
        nMon := 0
        for item in col {
            nMon++
            w := item.MaxHorizontalImageSize
            inst := StrUpper(item.InstanceName)
            if (InStr(inst, "UGD") || InStr(inst, "XP-PEN") || (w >= 33 && w <= 38))
                tieneTableta := true
            else if (w >= 45)             ; Pantalla externa >= 21" (ej: Teros 24" mide 53 cm)
                tieneMonitorGrande := true
            else if (w > 0 && w < 40)      ; Pantalla compacta (laptop 14" mide ~31 cm)
                tieneLaptop := true
        }
        if (nMon = 1)
            return 3  ; PC (1 monitor)
        if (tieneMonitorGrande)
            return 2  ; Monitor + tableta
        if (tieneLaptop && tieneTableta)
            return 1  ; Laptop + tableta
    } catch {
    }
    return 0
}

ElegirPerfil() {
    global PERFIL,PERFILES
    if (!IsSet(PERFILES) || !IsObject(PERFILES))
        return
    ini := _PosGuiIniPath()

    ; 1. Prioridad Absoluta: Perfil forzado por el usuario
    forzar := IniRead(ini,"Perfil","forzar","")
    if (IsInteger(forzar) && Integer(forzar) >= 1 && Integer(forzar) <= PERFILES.Length) {
        PERFIL := Integer(forzar)
        IniWrite(PERFIL,ini,"Perfil","actual")
        return
    }

    ; 2. Detección Inteligente por Hardware (EDID / Dimensiones físicas reales en cm)
    hw := _DetectarMonitoresHardware()
    if (hw >= 1 && hw <= PERFILES.Length) {
        PERFIL := hw
        IniWrite(PERFIL,ini,"Perfil","actual")
        return
    }

    ; 3. Fallback por coincidencia de firma de coordenadas
    act := IniRead(ini,"Perfil","actual","1")
    PERFIL := (IsInteger(act) && Integer(act) >= 1 && Integer(act) <= PERFILES.Length) ? Integer(act) : 1
    firma := _FirmaMonitores()
    manual := IniRead(ini,"Perfil","firmaManual","")
    if (manual != "" && manual = firma) {
        IniWrite(firma,ini,"Perfil","ultimaFirma")
        return
    }
    previa := IniRead(ini,"Perfil","ultimaFirma","")
    if (previa = firma)
        return
    IniWrite(firma,ini,"Perfil","ultimaFirma")
    primera := (previa = "")
    for i,nombre in PERFILES {
        if (IniRead(ini,"Puntos" i,"firma","") = firma) {
            PERFIL := i
            IniWrite(i,ini,"Perfil","actual")
            try IniDelete(ini,"Perfil","firmaManual")
            msg := "PERFIL AUTO: " nombre
            try SetTimer(() => %'MostrarHUD'%(msg,"9AA7C7",2500),-1800)
            return
        }
    }
    ; --- Perfil 3 "PC": un solo monitor => selección automática ---
    if (MonitorGetCount() = 1 && PERFILES.Length >= 3) {
        PERFIL := 3
        IniWrite(3,ini,"Perfil","actual")
        if (IniRead(ini,"Puntos3","firma","") = "")
            IniWrite(firma,ini,"Puntos3","firma")
        OutputDebug("ElegirPerfil: 1 monitor -> PERFIL 3")
        msg := "PERFIL AUTO: " PERFILES[3]
        try SetTimer(() => %'MostrarHUD'%(msg,"9AA7C7",2500),-1800)
        return
    }
    if (primera)
        return
    msg := "MONITORES CAMBIARON — elige perfil en 📍 (actual: " PERFILES[PERFIL] ")"
    try SetTimer(() => %'MostrarHUD'%(msg,"9AA7C7",3500),-1800)
}

; --- Helpers para Perfil 3 "PC (1 monitor)" ---
PerfilEsPC() => (PERFIL = 3)

ClampPrimario(&x, &y, w := 0, h := 0) {
    if (!PerfilEsPC())
        return
    pri := MonitorGetPrimary()
    MonitorGetWorkArea(pri, &L, &T, &R, &B)
    if (w > 0)
        x := Max(L, Min(x, R - w))
    else
        x := Max(L, Min(x, R))
    if (h > 0)
        y := Max(T, Min(y, B - h))
    else
        y := Max(T, Min(y, B))
}

CambiarPerfil(nuevo) {
    global PERFIL, PERFILES
    static enCurso := false
    if (enCurso || !IsSet(PERFIL) || !IsSet(PERFILES) || !IsObject(PERFILES))
        return
    if !IsInteger(nuevo)
        return
    nuevo := Integer(nuevo)
    if (nuevo < 1 || nuevo > PERFILES.Length || nuevo = PERFIL)
        return
    enCurso := true
    Critical("On")
    try GuardarPuntos(false)
    try _RgGuardarMirror()
    ini := _PosGuiIniPath()
    firma := _FirmaMonitores()
    IniWrite(nuevo, ini, "Perfil", "actual")
    IniWrite(nuevo, ini, "Perfil", "forzar")
    IniWrite(firma, ini, "Perfil", "ultimaFirma")
    IniWrite(firma, ini, "Perfil", "firmaManual")
    IniWrite(firma, ini, "Puntos" nuevo, "firma")
    for i in [1, 2, 3] {
        if (i != nuevo && IniRead(ini, "Puntos" i, "firma", "") = firma)
            try IniDelete(ini, "Puntos" i, "firma")
    }
    try OcultarZonasCalibracion()
    Reload()
    Critical("Off")
    Sleep(2000)
    OutputDebug("CambiarPerfil: Reload no reinicio el script; se libera enCurso")
    enCurso := false
}
_AplicarCambioPerfil(nuevo) => CambiarPerfil(nuevo)
_ZonaDePuntos(desde,n) {
    global PUNTOS
    x1 := PUNTOS[desde][1]
    x2 := x1
    y1 := PUNTOS[desde][2]
    y2 := y1
    Loop n - 1 {
        p := PUNTOS[desde + A_Index]
        x1 := Min(x1,p[1])
        x2 := Max(x2,p[1])
        y1 := Min(y1,p[2])
        y2 := Max(y2,p[2])
    }
    return {x1:x1,y1:y1,x2:x2,y2:y2}
}
RecalcularZonas() {
    global ZONAS,HIST_ALTO
    izq := []
    der := []
    Loop 3 {
        izq.Push(_ZonaDePuntos(3 + (A_Index - 1) * 4,4))
        der.Push(_ZonaDePuntos(15 + (A_Index - 1) * 4,4))
    }
    h := _ZonaDePuntos(27,2)
    if (HIST_ALTO >= 0)
        h.y2 := h.y2 + HIST_ALTO
    else
        h.y1 := h.y1 + HIST_ALTO
    ZONAS := {izq:izq,der:der,hist:h}
}
_NombrePunto(i) {
    if (i <= 2)
        return "Ocultar/mostrar · " (i = 1 ? "izq" : "der")
    if (i <= 14)
        return "Izq B" ((i - 3) // 4 + 1) " · esq " (Mod(i - 3,4) + 1)
    if (i <= 26)
        return "Der B" ((i - 15) // 4 + 1) " · esq " (Mod(i - 15,4) + 1)
    if (i = 27)
        return "Historial · izq"
    if (i = 28)
        return "Historial · der"
    if (i = 29)
        return "Zona segura (rehacer)"
    if (i = 30)
        return "Avisos · esq. sup. izq. (HUD)"
    return "Punto " i
}

; ===== API pública para el motor de avisos (Claude 2 puede adoptarla sin tocar esta zona) =====
ObtenerRango(nombre, modo := 0, ignorarPausa := false) {
    global PERFIL
    if (!ignorarPausa && SubStr(nombre, 1, 4) = "HUD_" && ZonaPausada(nombre))
        return 0                                      ; HUD pausada: los consumidores caen a su fallback existente
    v := IniRead(_PosGuiIniPath(),_ZonaSec("Rangos",modo),nombre,"")
    if (v = "" && _ZonaSuf(modo) != "")
        v := IniRead(_PosGuiIniPath(),_ZonaSec("Rangos",1),nombre,"")
    m := []
    if (v != "" && RegExMatch(v,"^\s*(-?\d+)\s*,\s*(-?\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*$",&m))
        return {x:Integer(m[1]),y:Integer(m[2]),w:Integer(m[3]),h:Integer(m[4])}
    return 0
}

; ===== Pausa de zonas (Paquete 2) =====
; Estado en [ZonasEstado<PERFIL>]  clave=pausada  (se borra la clave al reanudar).
; La zona conserva todos sus valores: solo sus consumidores la ignoran.
_ZonasPausadasMapa() {
    global PERFIL
    static m := 0, perfilCache := ""
    if (!IsObject(m) || perfilCache != PERFIL) {
        m := Map()
        m.CaseSense := "Off"
        perfilCache := PERFIL
        txt := ""
        try txt := IniRead(_PosGuiIniPath(), "ZonasEstado" PERFIL)
        for linea in StrSplit(txt, "`n", "`r") {
            p := InStr(linea, "=")
            if (p && SubStr(linea, p + 1) = "pausada")
                m[SubStr(linea, 1, p - 1)] := true
        }
    }
    return m
}

ZonaPausada(clave) {
    return _ZonasPausadasMapa().Has(clave)
}

ZonaPausar(clave, pausar := true) {
    global PERFIL
    m := _ZonasPausadasMapa()
    ini := _PosGuiIniPath()
    try {
        if (pausar) {
            IniWrite("pausada", ini, "ZonasEstado" PERFIL, clave)
            m[clave] := true
        } else {
            IniDelete(ini, "ZonasEstado" PERFIL, clave)
            if m.Has(clave)
                m.Delete(clave)
        }
    }
}
HudConfigEvento(ev) {
    global PERFIL
    ini := _PosGuiIniPath()
    sec := "HudEventos" PERFIL
    f := StrLower(IniRead(ini,sec,"formato_" ev,"moderno"))
    z := StrLower(IniRead(ini,sec,"zona_" ev,"baja"))
    op := Trim(IniRead(ini,sec,"opacidad_" ev,""))
    if (f = "desactivado" || f = "ninguno" || f = "off" || f = "sin gui")
        f := "desactivado"
    else if (f != "bruto")
        f := "moderno"
    if (z != "alta" && z != "media")
        z := "baja"
    if (op != "100" && op != "70" && op != "40")
        op := (z = "alta") ? "70" : "70"
    return {formato:f,zona:z,opacidad:Integer(op)}
}
HudDuracionZona(z) {
    global PERFIL
    ini := _PosGuiIniPath()
    sec := "HudDuraciones" PERFIL
    dStr := ""
    if (z = 1 || z = "alta")
        dStr := IniRead(ini, sec, "duracion_alta", "300")
    else if (z = 2 || z = "media")
        dStr := IniRead(ini, sec, "duracion_media", "500")
    else
        dStr := IniRead(ini, sec, "duracion_baja", "400")
    val := Integer(dStr)
    if (val <= 10 && val > 0)
        val := val * 100
    return Max(50, val)
}

; Duración de ocultado (ms) de un aviso, por ID de evento.
; Resolución: duracion_<id> en [HudEventos2] → [HudDuracion] por zona (alta/media/baja) → valor por defecto.
; La caché se invalida al guardar (ver _FlushIni).
HudDuracionDe(id) {
    global PERFIL, _gDurCache
    if (_gDurCache.Has(id))
        return _gDurCache[id]
    ini := _PosGuiIniPath()
    ; 1. duracion_<id> explícito por evento en [HudEventos<PERFIL>] o fallbacks
    d := Trim(IniRead(ini, "HudEventos" PERFIL, "duracion_" id, ""))
    if (d = "")
        d := Trim(IniRead(ini, "HudEventos2", "duracion_" id, ""))
    if (d = "")
        d := Trim(IniRead(ini, "HudEventos", "duracion_" id, ""))
    if (d != "" && IsNumber(d)) {
        val := d * 1
        if (val <= 10 && val > 0)
            val := val * 100
        if (val > 0)
            return _gDurCache[id] := val
    }
    ; 1.5 Buscar en [Duraciones] si existe dur_<id> calibrado
    d := Trim(IniRead(ini, "Duraciones", "dur_" id, ""))
    if (d != "" && IsNumber(d)) {
        val := d * 1
        if (val > 0)
            return _gDurCache[id] := val
    }
    ; 2. [HudDuracion] por zona del evento (alta/media/baja)
    z := _HudDuracionZonaDeId(id)
    if (z != 0) {
        clave := (z = 1) ? "alta" : (z = 2) ? "media" : "baja"
        d := Trim(IniRead(ini, "HudDuracion" PERFIL, clave, ""))
        if (d = "")
            d := Trim(IniRead(ini, "HudDuraciones" PERFIL, "duracion_" clave, ""))
        if (d = "")
            d := Trim(IniRead(ini, "HudDuracion", clave, ""))
        if (d != "" && IsNumber(d)) {
            val := d * 1
            if (val <= 10 && val > 0)
                val := val * 100
            if (val > 0)
                return _gDurCache[id] := val
        }
        return _gDurCache[id] := _HudDuracionPorZona(z)
    }
    ; 3. valor por defecto actual
    return _gDurCache[id] := _HudDuracionDefecto(id)
}

_HudDuracionZonaDeId(id) {
    global PERFIL
    ini := _PosGuiIniPath()
    z := Trim(IniRead(ini, "HudEventos" PERFIL, "zona_" id, ""))
    if (z = "")
        z := Trim(IniRead(ini, "HudEventos2", "zona_" id, ""))
    if (z = "")
        z := Trim(IniRead(ini, "HudEventos", "zona_" id, ""))
    z := StrLower(z)
    if (z = "alta" || z = "1")
        return 1
    if (z = "media" || z = "2")
        return 2
    if (z = "baja" || z = "3")
        return 3
    return 0
}

_HudDuracionPorZona(z) {
    if (z = 1)
        return 300
    if (z = 2)
        return 500
    return 400
}

_HudDuracionDefecto(id) {
    static def := Map(
        "capa_ocultar", 1200,
        "capa_mostrar", 1200,
        "macro_capas", 2500,
        "mascara_recorte", 1500,
        "shift_sostenido", 1500,
        "shift_anclado", 1500
    )
    return def.Has(id) ? def[id] : 1500
}
