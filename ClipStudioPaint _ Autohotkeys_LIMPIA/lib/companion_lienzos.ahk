#Requires AutoHotkey v2.0
; ============================================================================
; lib/companion_lienzos.ahk - Lienzos CSP (prefijo Nv / _Nv)
; Extraido de companion.ahk L3117-4277 (Frente 2 - Modularizacion)
; API publica: NvRehidratar, NvEstado, _NvEstadoVisual, NvAlternarInteractivo,
;   NvSiguienteZona, _NvDocsLibres, _NvDocsRetomables, _NvModoEfectivo,
;   NvSetGlobal, NvSetIndividual, NvReposicionarVentanas, NuevaVentanaEnZona
; ============================================================================

; === NUEVA-VENTANA-RANGO-BEGIN ===
; Cadena optimizada: Nueva ventana -> desacoplar pestaña -> ubicar y verificar en 1 solo lanzamiento ágil.
_NvCfg() {
    static c := Map(
        "claseMarco", "742DEA58-ED6B-4402-BC11-20DFC6D08040",
        "claseDoc",   "742DEA58-ED6B-4402-BC11-20DFC6D08040-E583090D-0E1A-43a2-977A-5266782BDE30",
        "tabX", -2118, "tabY", -88,     ; LEGADO (ya no se usan; deteccion dinamica)
        "tabYRel", 132,                 ; Y de la franja relativa al borde superior del marco (fy=-227, Y=-95 medido con Calibrador/ShareX)
        "colorTab", 0x6A748A,           ; 0xRRGGBB del fondo de la pestana ACTIVA (azul grisáceo Qt verificado en vivo)
        "varColor", 16,                 ; tolerancia por canal (bajar si hay falsos positivos)
        "margenIzq", 110, "margenDer", 700, ; recorte del rango de busqueda (toolbox / paletas flotantes)
        "huecoMax", 40, "anchoMin", 25, ; tolera texto dentro de la pestana; ancho minimo valido
        "agarrePct", 0.30, "agarreMin", 30, "agarreMax", 60,
        "esperaManual", 8000,
        "detectarMax", 3500,            ; ms de polling hasta que aparezca la pestana NUEVA
        "caida", 280,                   ; cuanto se arrastra hacia abajo
        "espera", 150,                  ; ms entre crear la ventana y arrastrar la pestana (150 ms para atajo)
        "metodo", "atajo",              ; Shift+N nativo en CSP (Ventana > Lienzo > Nueva ventana)
        "postAtajo", 150,
        "menuDown", 1,                  ; Down antes de Enter; -1 = legado (tecla n)
        "keyDelay", 20,                 ; SetKeyDelay para el menu
        "abrirMax", 2600,               ; el submenu Lienzo tarda 1.5-2 s en Qt
        "reintentos", 3,                ; reintentos del disparo (solo antes del Enter)
        "menuMs", 300,
        "detectarIntento", 1300,
        "detectarAtajo", 3000,          ; polling único tras Shift+N (no se repite el atajo)
        "pasos", 10, "pasoMs", 18,      ; arrastre (subir si Qt deja de reconocer el drag)
        "asentarMs", 200,               ; la geometria debe mantenerse este tiempo
        "colocarMax", 2500)             ; tope total de colocacion
    return c
}

NuevaVentanaEnZona(rango := "ZonaSegura") {
    static ocupado := false
    if ocupado
        return "ocupado"
    ocupado := true
    try {
        return _NvEjecutar(rango)
    } finally {
        ocupado := false
    }
}

_NvEjecutar(rango) {
    SetWinDelay(-1)
    t0 := A_TickCount
    if !A_IsAdmin
        return _NvLog("no-admin")
    cspPid := ProcessExist("CLIPStudioPaint.exe")
    if !cspPid
        return _NvLog("no-csp")
    static CLS_MAIN := "742DEA58-ED6B-4402-BC11-20DFC6D08040"
    main := WinExist("ahk_pid " cspPid " ahk_class " CLS_MAIN)
    if !main
        return _NvLog("no-main")
    try WinActivate("ahk_id " main)
    Sleep(300)
    if !WinActive("ahk_id " main) {
        _NvLog("main-no-activo")
        return "main-no-activo"
    }
    r := _NvRangoRect(rango)
    if !IsObject(r) {
        _NvLog("no-rango:" rango)
        return "no-rango"
    }
    antes := _NvDocs(cspPid)
    _NvLog("mods-pre ctrl=" GetKeyState("Ctrl") " alt=" GetKeyState("Alt") " shift=" GetKeyState("Shift"))
    _NvSoltarMods()
    nuevo := 0
    e := NvEstado()

    ; Snapshot de TODAS las CLS_DOC existentes (registradas o no): nunca se adoptan ni se tocan.
    ; Siempre se dispara Shift+N; la ventana nueva es la que NO estaba aquí.
    previas := Map()
    for h in antes
        previas[h] := true
    _NvLog("previas=" previas.Count " registradas=" e.ventanas.Count)

    ; 1ª pulsación: creación + desacople automático de pestaña
    if !nuevo {
        c := _NvCfg()
        _NvForzarFocoMarco(main)                  ; foco al marco ANTES de medir y de disparar
        gPrev := 0
        Loop 5 {                                  ; la pestaña activa previa debe leerse bien
            gPrev := _NvTabActivaAgarre(main)
            if IsObject(gPrev)
                break
            Sleep(80)
        }
        xPrev := IsObject(gPrev) ? gPrev["px"] : ""
        _NvLog("xPrev=" xPrev)
        g := 0
        esAtajo := (c["metodo"] = "atajo")
        nIntentos := esAtajo ? 1 : c["reintentos"]            ; atajo: Shift+N JAMÁS se repite
        msDet := esAtajo ? c["detectarAtajo"] : c["detectarIntento"]
        Loop nIntentos {
            _NvDisparar(c["metodo"], cspPid, A_Index)
            Sleep(c["espera"])
            limDet := A_TickCount + msDet
            while (A_TickCount < limDet) {
                g := _NvTabActivaAgarre(main)
                if IsObject(g) && (xPrev = "" || Abs(g["px"] - xPrev) > 8)
                    break
                g := 0
                Sleep(60)
            }
            if IsObject(g)
                break
            _NvLog("disparo-sin-pestana intento=" A_Index)
            _NvLimpiarMenu(main)
        }
        if IsObject(g) {
            _NvLog("agarre x=" g["x"] " y=" g["y"] " ancho=" g["ancho"])
            Sleep(c["asentarMs"])
            _NvArrastrarPestana(g["x"], g["y"], g["x"], g["y"] + c["caida"])
            limite := A_TickCount + 1800
        } else {
            _NvLog("pestana-activa-no-detectada: fallback manual")
            ToolTip("Arrastra la pestaña hacia abajo: yo la coloco")
            SetTimer(() => ToolTip(), -3000)
            limite := A_TickCount + c["esperaManual"]
        }
        while (A_TickCount < limite) {
            for h in _NvDocs(cspPid) {
                if !_NvEnLista(h, antes) {
                    nuevo := h
                    break
                }
            }
            if nuevo
                break
            Sleep(30)
        }
        if !nuevo && IsObject(g) {
            g2 := _NvTabActivaAgarre(main)
            if IsObject(g2) {
                _NvLog("re-arrastre x=" g2["x"] " y=" g2["y"])
                _NvArrastrarPestana(g2["x"], g2["y"], g2["x"], g2["y"] + Round(c["caida"] * 1.6))
                limite := A_TickCount + 1500
                while (A_TickCount < limite && !nuevo) {
                    for h in _NvDocs(cspPid) {
                        if !_NvEnLista(h, antes) {
                            nuevo := h
                            break
                        }
                    }
                    Sleep(30)
                }
            }
        }
    }
    ; (la adopción de ventanas libres vive en _NvBotonEmbeber / _NvAdoptarLibres)
    if !nuevo {
        _NvLog("desacople-o-creacion-fallida" (IsObject(g) ? " (timeout 1.8s)" : "-manual"))
        return "sin-ventana-nueva"
    }

    Sleep(900)                                   ; CSP recoloca la ventana justo tras crearla
    final := nuevo
    for h in _NvDocs(cspPid) {
        if !_NvEnLista(h, antes)
            final := h                           ; el último detectado es el definitivo
    }
    ok := false
    try {
        if (WinGetMinMax("ahk_id " final) != 0)
            WinRestore("ahk_id " final)
    }
    ; Guard anti-recaptura: una ventana previa o ya registrada jamás se arrastra ni se recoloca
    if (!final || previas.Has(final) || e.ventanas.Has(final)) {
        _NvLog("ABORTA: final=" final " es previa/registrada; no se toca")
        return
    }

    ; Colocación final:
    Loop 3 {
        try WinMove(r.x, r.y, r.w, r.h, "ahk_id " final)
        Sleep(350)
        try {
            WinGetPos(&gx, &gy, &gw, &gh, "ahk_id " final)
            if (Abs(gx - r.x) <= 16 && Abs(gy - r.y) <= 16 && Abs(gw - r.w) <= 24 && Abs(gh - r.h) <= 24) {
                ok := true
                break
            }
        }
    }
    ; Registro robusto: se registra si la ventana existe y su centro cae dentro de la zona,
    ; aunque DWM haya añadido márgenes y la tolerancia estricta no haya cuadrado.
    if !ok && WinExist("ahk_id " final) {
        try {
            WinGetPos(&gx, &gy, &gw, &gh, "ahk_id " final)
            cx := gx + gw // 2, cy := gy + gh // 2
            if (cx >= r.x && cx <= r.x + r.w && cy >= r.y && cy <= r.y + r.h)
                ok := true
        }
    }
    _NvLog("registro final=" final " ok=" ok " rango=" rango)
    if (ok || WinExist("ahk_id " final))
        NvRegistrarVentana(final, rango)
    _NvLog((ok ? "ok " : "puesto-pero-recolocado ") r.x "," r.y " " r.w "x" r.h " hwnd=" final " ms=" (A_TickCount - t0))
    return ok ? "ok" : "recolocado"
}

_NvSnapshot() {
    s := Map("ids", Map(), "titulo", "")
    for h in WinGetList("ahk_exe CLIPStudioPaint.exe")
        s["ids"][h] := true
    if WinActive("ahk_exe CLIPStudioPaint.exe")
        s["titulo"] := WinGetTitle("A")
    return s
}

_NvEsperarCambio(s, ms := 2500) {
    t0 := A_TickCount
    while (A_TickCount - t0 < ms) {
        for h in WinGetList("ahk_exe CLIPStudioPaint.exe")
            if !s["ids"].Has(h)
                return "hwnd:" h
        if (WinActive("ahk_exe CLIPStudioPaint.exe") && s["titulo"] != "" && WinGetTitle("A") != s["titulo"])
            return "titulo"
        Sleep(50)
    }
    return ""
}

NvEstado() {
    static e := {modoGlobal: _NvIniModoGlobal(), fijas: Map(), ventanas: Map()}
    return e
}

_NvIniModoGlobal() {
    m := IniRead(_PosGuiIniPath(), "NvConfig", "modoGlobal", "")
    if (m = "")   ; migración desde la clave antigua "modo"
        m := (IniRead(_PosGuiIniPath(), "NvConfig", "modo", "hover") = "total") ? "desact_25" : "h_on"
    return (m = "h_off" || m = "desact_25") ? m : "h_on"
}

; Modo efectivo: individual > global > h_on (si el global está roto y la ventana no tiene fija)
_NvModoEfectivo(e, h) {
    if e.fijas.Has(h)
        return e.fijas[h]
    return (e.modoGlobal != "") ? e.modoGlobal : "h_on"
}

; "on" = todas en Hover ON | "off" = todas en Hover OFF/Desact | "mixto"
_NvEstadoVisual(e) {
    if (e.ventanas.Count = 0)
        return (e.modoGlobal = "") ? "mixto" : (e.modoGlobal = "h_on" ? "on" : "off")
    primero := ""
    for h in e.ventanas {
        m := _NvModoEfectivo(e, h)
        if (primero = "")
            primero := m
        else if (m != primero)
            return "mixto"
    }
    return (primero = "h_on") ? "on" : "off"
}

NvSetGlobal(modo) {
    e := NvEstado()
    e.modoGlobal := modo
    e.fijas.Clear()
    _NvPersistirTodo()                                ; fijas vaciadas: limpia modos individuales del INI
    try IniWrite(modo, _PosGuiIniPath(), "NvConfig", "modoGlobal")
    _NvRefrescar()
}

NvSetIndividual(h, modo) {
    e := NvEstado()
    if (e.modoGlobal != "") {
        ; congelar el modo efectivo de las demás antes de romper el Global:
        ; un cambio individual no debe propagarse a las otras ventanas
        for hh in e.ventanas {
            if (hh != h && !e.fijas.Has(hh))
                e.fijas[hh] := _NvModoEfectivo(e, hh)
        }
        e.modoGlobal := ""          ; ruptura del Global
    }
    e.fijas[h] := modo
    _NvPersistirTodo()
    _NvRefrescar()
}

; Clic corto: Hover ON -> Hover OFF; Hover OFF / Desact / mixto -> Hover ON (siempre global)
NvAlternarInteractivo() {
    NvSetGlobal(_NvEstadoVisual(NvEstado()) = "on" ? "h_off" : "h_on")
}

_NvRefrescar() {
    LoopNuevasVentanas()
    ActualizarNVGUI()
}

NvSetModo(m) {
    NvSetGlobal(m = "total" ? "desact_25" : "h_on")
}

NvToggleModo() {
    NvAlternarInteractivo()
    vis := _NvEstadoVisual(NvEstado())
    ToolTip("WINDOW: " (vis = "on" ? "HOVER ON (5 %)" : (vis = "off" ? "HOVER OFF / 25 %" : "MIXTO")), , , 18)
    SetTimer(() => ToolTip(, , , 18), -1200)
}

NvRegistrarVentana(hwnd, zona := "") {
    NvEstado().ventanas[hwnd] := zona                 ; hwnd -> nombre de zona
    _NvPersistir(hwnd)                                ; punto de cambio: registro
    SetTimer(LoopNuevasVentanas, 80)
}

; ---- Persistencia de ventanas WINDOW: [NvVentanas] en posiciones_gui.ini ----
; Formato: <hwnd>=<zona>|<modo individual o vacio>
; Se escribe SOLO en: registro, borrado de muertas, cambio individual y cambio global.
; NUNCA dentro del tick de 80 ms.
_NvPersistir(h) {
    e := NvEstado()
    try {
        if (e.ventanas.Has(h))
            IniWrite(e.ventanas[h] "|" (e.fijas.Has(h) ? e.fijas[h] : ""), _PosGuiIniPath(), "NvVentanas", String(h))
        else
            IniDelete(_PosGuiIniPath(), "NvVentanas", String(h))
    }
}

_NvPersistirTodo() {
    for h in NvEstado().ventanas
        _NvPersistir(h)
}

_NvClsDoc() {
    return "742DEA58-ED6B-4402-BC11-20DFC6D08040-E583090D-0E1A-43a2-977A-5266782BDE30"
}

; ¿Es un documento CSP (proceso + clase CLS_DOC)? Evita tocar hwnd reutilizados.
_NvEsDocCsp(h) {
    try return (WinGetProcessName("ahk_id " h) = "CLIPStudioPaint.exe"
        && WinGetClass("ahk_id " h) = _NvClsDoc())
    return false
}

; Firma de gestión: alpha 38/64 y/o click-through. 255 sin +0x20 NO es firma.
_NvFirmaGestion(h) {
    key := 0, alpha := 0, flags := 0, ex := 0
    try ex := WinGetExStyle("ahk_id " h)
    ok := DllCall("user32\GetLayeredWindowAttributes", "Ptr", h, "UInt*", &key, "UChar*", &alpha, "UInt*", &flags, "Int")
    capa := (ok && (flags & 0x2)) ? alpha : 255
    return ((ex & 0x20) || capa = 38 || capa = 64)
}

; CLS_DOC de CSP con firma de gestión (registradas o no).
_NvDocsFirma() {
    r := []
    try {
        for h in WinGetList("ahk_exe CLIPStudioPaint.exe ahk_class " _NvClsDoc()) {
            if _NvFirmaGestion(h)
                r.Push(h)
        }
    }
    return r
}

; Restauración idempotente en OnExit (ExitApp, ^!+q, Reload). No toca el INI:
; las entradas siguen para que NvRehidratar re-gestione tras Reload.
NvRestaurarAlSalir(*) {
    static hecho := false
    if hecho
        return 0
    hecho := true
    n := 0
    prevDH := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    try {
        lista := Map()
        for h in NvEstado().ventanas
            lista[h] := true
        for h in _NvDocsFirma()
            lista[h] := true
        for h in lista {
            if (!WinExist("ahk_id " h) || !_NvEsDocCsp(h))
                continue
            try WinSetTransparent(255, "ahk_id " h)
            try WinSetExStyle("-0x20", "ahk_id " h)
            n++
        }
    } finally {
        DetectHiddenWindows(prevDH)
    }
    if IsSet(DiagLog)
        DiagLog("salida.log", FormatTime(, "yyyy-MM-dd HH:mm:ss") " [NvWindow] Restauradas " n " ventana(s)")
    return 0
}

; Re-adopta CLS_DOC sueltas. Sobrevive a ventanas.Count = 0 (timer propio).
_NvSondeoSueltas() {
    _NvAdoptarLibres(true)                  ; mismo camino que el botón "Retomar control"
}

; CLS_DOC visibles de CSP que NO están registrados y sin firma de gestión
; (las que quedaron desactivadas/click-through las cubre "Retomar control").
_NvDocsLibres() {
    r := []
    pid := ProcessExist("CLIPStudioPaint.exe")
    if !pid
        return r
    e := NvEstado()
    for h in _NvDocs(pid) {
        if (!e.ventanas.Has(h) && !_NvFirmaGestion(h))
            r.Push(h)
    }
    return r
}

; CLS_DOC con firma de gestión (38/64 y/o +0x20) y sin registrar.
_NvDocsRetomables() {
    r := []
    e := NvEstado()
    for h in _NvDocsFirma() {
        if !e.ventanas.Has(h)
            r.Push(h)
    }
    return r
}

; Adopción única (timer + botones). Sin WinActivate.
; firmaSolo=true : sólo CLS_DOC con firma de gestión (como el sondeo; incluye ocultas).
; firmaSolo=false: todas las libres visibles ("Embeber").
; soloH: adopta únicamente ese hwnd. mover: coloca cada adoptada en una zona libre.
; Devuelve cuántas registró.
_NvAdoptarLibres(firmaSolo := true, soloH := 0, mover := false) {
    e := NvEstado()
    n := 0
    prevDH := A_DetectHiddenWindows
    DetectHiddenWindows(firmaSolo)
    try {
        if soloH
            lista := [soloH]
        else
            lista := firmaSolo ? _NvDocsFirma() : _NvDocsLibres()
        for h in lista {
            if (e.ventanas.Has(h) || !_NvEsDocCsp(h))
                continue
            _NvOlvidarCache(h)              ; hwnd reutilizado: forzar reaplicación de alfa
            zona := ""
            if mover
                _NvColocarEnZonaLibre(h, &zona)
            NvRegistrarVentana(h, zona)     ; persiste [NvVentanas] + reactiva el tick de 80 ms
            _NvProbarEfecto(h)
            n++
        }
    } finally {
        DetectHiddenWindows(prevDH)
    }
    return n
}

; Zona libre para una ventana adoptada; "" si no hay (o si ZonaSegura ya está ocupada).
_NvZonaParaEmbeber() {
    z := NvSiguienteZona()
    if (z = "")
        return ""
    if (z = "ZonaSegura") {
        for h, zz in NvEstado().ventanas
            if (zz = "ZonaSegura" && WinExist("ahk_id " h))
                return ""                        ; no apilar varias ventanas en ZonaSegura
    }
    return z
}

; Coloca h en la primera zona libre (restaura si está minimizada/maximizada).
; Escribe el nombre de zona sólo si la colocación se confirma.
_NvColocarEnZonaLibre(h, &zona) {
    z := _NvZonaParaEmbeber()
    if (z = "")
        return false
    r := 0
    try r := _NvRangoRect(z)
    if (!IsObject(r) || r.w < 1)
        return false
    try {
        if (WinGetMinMax("ahk_id " h) != 0)
            WinRestore("ahk_id " h)
    }
    Loop 2 {
        try WinMove(r.x, r.y, r.w, r.h, "ahk_id " h)
        Sleep(250)
        try {
            WinGetPos(&gx, &gy, &gw, &gh, "ahk_id " h)
            if (Abs(gx - r.x) <= 16 && Abs(gy - r.y) <= 16 && Abs(gw - r.w) <= 24 && Abs(gh - r.h) <= 24) {
                zona := z
                return true
            }
        }
    }
    ; DWM puede añadir márgenes: si el centro cae dentro de la zona, se da por colocada
    try {
        WinGetPos(&gx, &gy, &gw, &gh, "ahk_id " h)
        cx := gx + gw // 2, cy := gy + gh // 2
        if (cx >= r.x && cx <= r.x + r.w && cy >= r.y && cy <= r.y + r.h) {
            zona := z
            return true
        }
    }
    return false
}

NvReposicionarVentanas() {
    SetWinDelay(-1)
    muertas := []
    for h, zona in NvEstado().ventanas {
        if (!WinExist("ahk_id " h)) {
            muertas.Push(h)
            continue
        }
        r := 0
        try r := _NvRangoRect(zona, zona = "ZonaSegura")
        if (!IsObject(r) || r.w < 1)
            continue
        mm := 0
        try mm := WinGetMinMax("ahk_id " h)
        if (mm = -1)
            continue
        if (mm = 1)
            try WinRestore("ahk_id " h)
        gx := 0, gy := 0, gw := 0, gh := 0
        try WinGetPos(&gx, &gy, &gw, &gh, "ahk_id " h)
        if (Abs(gx - r.x) <= 2 && Abs(gy - r.y) <= 2 && Abs(gw - r.w) <= 2 && Abs(gh - r.h) <= 2)
            continue
        try WinMove(r.x, r.y, r.w, r.h, "ahk_id " h)
    }
    for h in muertas
        NvEstado().ventanas.Delete(h)
}

; Diagnóstico UIPI: reescribe el mismo bit 0x20 (sin cambio visible). Si falla, log único.
_NvProbarEfecto(h) {
    static avisados := Map()
    if avisados.Has(h)
        return
    try {
        ex := WinGetExStyle("ahk_id " h)
        WinSetExStyle((ex & 0x20) ? "+0x20" : "-0x20", "ahk_id " h)
    } catch {
        avisados[h] := true
        _NvLog("adopcion-sin-efecto hwnd=" h)
    }
}

_NvBotonEmbeber(*) {
    if !ProcessExist("CLIPStudioPaint.exe") {
        try MostrarHUD("Embeber: sin CSP", "9A7BFF", 1400)
        return
    }
    n := _NvAdoptarLibres(false, 0, true)
    try MostrarHUD(n ? (n = 1 ? "1 ventana embebida" : n " ventanas embebidas") : "0 libres", "9A7BFF", 1400)
}

_NvBotonRetomar(*) {
    n := _NvAdoptarLibres(true)
    try MostrarHUD(n ? "Control retomado: " n : "Nada que retomar", "9A7BFF", 1400)
}

_NvIniciarVigilancia() {
    static ok := false
    if ok
        return
    ok := true
    OnExit(NvRestaurarAlSalir, -1)          ; -1: corre ANTES que _AudAlSalir / Salir
    SetTimer(_NvSondeoSueltas, 1500)
}

; Rehidrata tras recargar el script. Una entrada solo sobrevive si el hwnd existe,
; pertenece a CLIPStudioPaint.exe Y su clase es CLS_DOC; el resto se descarta y se borra del INI.
NvRehidratar() {
    _NvIniciarVigilancia()
    ini := _PosGuiIniPath()
    txt := ""
    try txt := IniRead(ini, "NvVentanas")
    if (txt = "")
        return
    e := NvEstado()
    hayFija := false
    for linea in StrSplit(txt, "`n", "`r") {
        p := InStr(linea, "=")
        if (!p)
            continue
        k := SubStr(linea, 1, p - 1)
        v := SubStr(linea, p + 1)
        h := IsInteger(k) ? Integer(k) : 0
        ok := false
        if (h && WinExist("ahk_id " h)) {
            try ok := (WinGetProcessName("ahk_id " h) = "CLIPStudioPaint.exe"
                && WinGetClass("ahk_id " h) = _NvClsDoc())
        }
        if (!ok) {
            try IniDelete(ini, "NvVentanas", k)
            continue
        }
        partes := StrSplit(v, "|")
        e.ventanas[h] := partes.Length ? partes[1] : ""
        if (partes.Length >= 2 && (partes[2] = "h_on" || partes[2] = "h_off" || partes[2] = "desact_25")) {
            e.fijas[h] := partes[2]
            hayFija := true
        }
    }
    if (hayFija)
        e.modoGlobal := ""                            ; replica la ruptura del Global de NvSetIndividual
    if (e.ventanas.Count)
        SetTimer(LoopNuevasVentanas, 80)
}

NvSiguienteZona() {
    e := NvEstado()
    hay := 0
    Loop 8 {
        z := "NvZona" A_Index
        r := 0
        try r := _NvRangoRect(z)
        if (!IsObject(r) || r.w < 1)
            continue
        hay++
        if ZonaPausada(z)
            continue                                  ; pausada: existe pero no recibe nuevas ventanas
        ocupada := false
        for h, zz in e.ventanas
            if (zz = z && WinExist("ahk_id " h))
                ocupada := true
        if !ocupada
            return z
    }
    return hay ? "" : "ZonaSegura"                    ; "" = todas ocupadas; sin zonas Nv: comportamiento anterior
}

LoopNuevasVentanas() {
    e := NvEstado()
    if (e.ventanas.Count = 0) {
        SetTimer(LoopNuevasVentanas, 0)
        return
    }
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    muertos := []
    for h in e.ventanas {
        if !WinExist("ahk_id " h) {
            muertos.Push(h)
            continue
        }
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " h)
        dentro := (mx >= wx && mx <= wx + ww && my >= wy && my <= wy + wh)
        _NvAplicarModo(h, _NvModoEfectivo(e, h), dentro)
    }
    for h in muertos {                                ; no se borra durante el for
        e.ventanas.Delete(h)
        _NvOlvidarCache(h)
        if e.fijas.Has(h)
            e.fijas.Delete(h)                         ; no reaplicar un modo a un hwnd reutilizado
        _NvPersistir(h)                               ; punto de cambio: borra la entrada (solo si murió algo)
    }
}

_NvCacheModo() {
    static c := Map()
    return c
}

_NvOlvidarCache(h) {
    c := _NvCacheModo()
    if c.Has(h)
        c.Delete(h)
}

; Opacidad configurada de la zona de una ventana: {hover, desact} en %, o 0 si no hay clave.
_NvOpacZona(hwnd) {
    e := NvEstado()
    if (!e.ventanas.Has(hwnd))
        return 0
    v := IniRead(_PosGuiIniPath(), _ZonaSec("Rangos"), e.ventanas[hwnd] "_Opac", "")
    if (v = "")
        return 0
    p := StrSplit(Trim(v), ",")
    if (p.Length < 2 || !IsInteger(Trim(p[1])) || !IsInteger(Trim(p[2])))
        return 0
    return { hover: Min(100, Max(0, Integer(Trim(p[1])))), desact: Min(100, Max(0, Integer(Trim(p[2])))) }
}

; Fuerza reaplicar el modo actual a todas las ventanas Nv abiertas (tras editar opacidades).
_NvReaplicarOpacidad() {
    e := NvEstado()
    _NvCacheModo().Clear()
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    for hwnd, zona in e.ventanas {
        if (!WinExist("ahk_id " hwnd))
            continue
        dentro := false
        try {
            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
            dentro := (mx >= wx && mx < wx + ww && my >= wy && my < wy + wh)
        }
        _NvAplicarModo(hwnd, _NvModoEfectivo(e, hwnd), dentro)
    }
}

_NvAplicarModo(hwnd, modo, dentro := false) {
    ultimo := _NvCacheModo()
    switch modo {
        case "h_off":     fis := "v"                  ; 100% fija
        case "desact_25", "desact_15": fis := "t"     ; 15% bloqueada
        default:          fis := dentro ? "o" : "r"   ; h_on: hover / reposo
    }
    if (ultimo.Has(hwnd) && ultimo[hwnd] = fis)
        return
    ultimo[hwnd] := fis
    op := _NvOpacZona(hwnd)                           ; 0 = sin configurar → fallback
    switch fis {
        case "t":                                     ; desactivada: Desact % + click-through
            alfa := op ? Min(255, Max(0, Round(op.desact * 2.55))) : 38   ; 0% permitido (invisible, sigue click-through por +0x20)
            try WinSetTransparent(alfa, "ahk_id " hwnd)
            try WinSetExStyle("+0x20", "ahk_id " hwnd)
        case "v", "o":                                ; fija / hover: 100% + interactiva
            try WinSetTransparent(255, "ahk_id " hwnd)
            try WinSetExStyle("-0x20", "ahk_id " hwnd)
        default:                                      ; h_on en reposo (cursor fuera): Hover % (op.hover) + click-through
            alfa := op ? Min(255, Max(0, Round(op.hover * 2.55))) : 64   ; 0% permitido
            try WinSetTransparent(alfa, "ahk_id " hwnd)
            try WinSetExStyle("+0x20", "ahk_id " hwnd)
    }
}

; Espera a que aparezca un CLS_DOC que no estaba en "antes"
_NvEsperarNueva(cspPid, antes, timeoutMs := 4000) {
    t0 := A_TickCount
    while (A_TickCount - t0 < timeoutMs) {
        Sleep(100)
        for h in _NvDocs(cspPid) {
            if !_NvEnLista(h, antes)
                return h
        }
    }
    return 0
}

; Menú Ventana(W) > Lienzo(V) > "Nueva ventana" (1ª opción, sin acelerador)
; Tiempos Qt tomados del backup 02:04:30 (ABRIR = 400 ms)
_NvDispararMenu(mainHwnd) {
    static ABRIR := 400
    if !WinActive("ahk_id " mainHwnd) {
        try WinActivate("ahk_id " mainHwnd)
        if !WinWaitActive("ahk_id " mainHwnd, , 1)
            return false
    }
    _NvSoltarMods()
    OutputDebug("[Nv] menu: Alt+W -> v -> Enter")
    SendEvent("{Alt down}w{Alt up}")    ; abre Ventana
    Sleep(ABRIR)
    SendEvent("v")                      ; abre Lienzo
    Sleep(ABRIR)
    SendEvent("{Enter}")                ; Nueva ventana = opción 1
    return true
}

_NvDocs(pid) {
    static CLS_DOC := _NvClsDoc()
    out := []
    for h in WinGetList("ahk_pid " pid) {
        try {
            if (WinGetClass("ahk_id " h) = CLS_DOC)
                out.Push(h)
        }
    }
    return out
}

_NvTodas(pid) {
    out := []
    for h in WinGetList("ahk_pid " pid) {
        try {
            if DllCall("IsWindowVisible", "Ptr", h)
                out.Push(h)
        }
    }
    return out
}

_NvEnLista(h, lista) {
    for x in lista
        if (x = h)
            return true
    return false
}

_NvLog(s) {
    try FileAppend(A_Now " " s "`n", EnvGet("TEMP") "\_nv_ultimo.txt")
    return s
}

_NvSoltarMods() {
    static mods := ["LCtrl", "RCtrl", "LAlt", "RAlt", "LShift", "RShift", "LWin", "RWin"]
    t0 := A_TickCount
    while (A_TickCount - t0 < 600) {                   ; un solo plazo; sin espera si nada esta pulsado
        fisico := false
        for k in mods {
            if GetKeyState(k, "P") {
                fisico := true
                break
            }
        }
        if !fisico
            break
        Sleep(10)
    }
    for k in mods
        if GetKeyState(k)                              ; estado logico pegado
            SendEvent("{Blind}{" k " up}")
}

_NvDispararAtajo(mainHwnd) {
    c := _NvCfg()
    if !WinActive("ahk_id " mainHwnd) {
        try WinActivate("ahk_id " mainHwnd)
        if !WinWaitActive("ahk_id " mainHwnd, , 1) {
            _NvLog("atajo-sin-foco")
            return false
        }
    }
    _NvSoltarMods()
    SetKeyDelay(c["keyDelay"], c["keyDelay"])
    SendEvent("{Shift down}n{Shift up}")
    Sleep(c["postAtajo"])
    _NvLog("atajo-enviado")
    return true
}

; Devuelve el foco al marco principal de CSP (puede haber quedado en una ventana desacoplada)
_NvForzarFocoMarco(main) {
    try WinActivate("ahk_id " main)
    if !WinWaitActive("ahk_id " main, , 1) {
        try DllCall("AllowSetForegroundWindow", "UInt", -1)
        try WinActivate("ahk_id " main)
        WinWaitActive("ahk_id " main, , 1)
    }
    Sleep(60)
    ok := WinActive("ahk_id " main) ? true : false
    _NvLog("foco-marco ok=" ok)
    return ok
}

_NvDisparar(modo, pid := 0, intento := 1) {
    c := _NvCfg()
    SetKeyDelay(c["keyDelay"], c["keyDelay"])
    if (modo = "atajo") {
        _NvEsperarSoltarFisico()
        _NvSoltarMods()
        SendEvent("{Shift down}n{Shift up}")
        return
    }
    _NvEsperarSoltarFisico()
    _NvSoltarMods()
    ; Rotación por intento: configurado -> mnemónico "n" -> solo Enter
    variantes := [c["menuDown"], -1, 0]
    vd := variantes[Min(intento, 3)]
    SendEvent("{Alt down}")
    Sleep(40)
    SendEvent("w")                                     ; menu Ventana
    Sleep(40)
    SendEvent("{Alt up}")
    Sleep(c["menuMs"])
    try _NvLog("menu-W cls=" WinGetClass("A") " intento=" intento)
    SendEvent("v")                                     ; submenu Lienzo
    Sleep(c["menuMs"])
    try _NvLog("menu-V cls=" WinGetClass("A") " vd=" vd)
    if (vd >= 0)
        SendEvent((vd > 0 ? "{Down " vd "}" : "") "{Enter}")
    else
        SendEvent("n")
}

_NvEsperarSoltarFisico() {
    for k in ["Ctrl", "Shift", "Alt", "LWin", "RWin"]
        try KeyWait(k, "T1.5")
    k := RegExReplace(A_ThisHotkey, "^[~*$<>^+!#]+")
    if (k != "" && !InStr(k, " & "))
        try KeyWait(k, "T1.5")
}

_NvLimpiarMenu(main) {
    SendEvent("{Escape 3}")
    Sleep(120)
    try WinActivate("ahk_id " main)
    Sleep(150)
}

_NvEsperarPopup(pid, antes, ms) {
    t0 := A_TickCount
    if !pid {
        Sleep(ms)
        return false
    }
    while (A_TickCount - t0 < ms) {
        if (WinGetList("ahk_pid " pid).Length > antes) {
            Sleep(40)                                  ; deja que el menu pinte y seleccione
            return true
        }
        Sleep(15)
    }
    return false
}

_NvEsperarMas(pid, n, ms) {
    t := A_TickCount
    while (A_TickCount - t < ms) {
        if (WinGetList("ahk_pid " pid).Length > n)
            return true
        Sleep(30)
    }
    return false
}

_NvEsperarHasta(pid, n, ms) {
    t := A_TickCount
    while (A_TickCount - t < ms) {
        if (WinGetList("ahk_pid " pid).Length <= n)
            return true
        Sleep(30)
    }
    return false
}

_NvDispararVerificado(pid) {
    c := _NvCfg()
    if (c["metodo"] = "atajo" || !pid) {
        _NvDisparar(c["metodo"], pid)
        return true
    }
    SetKeyDelay(c["keyDelay"], c["keyDelay"])
    Loop c["reintentos"] {
        base := WinGetList("ahk_pid " pid).Length
        SendEvent("{Alt down}w{Alt up}")                  ; menu Ventana
        ok := _NvEsperarMas(pid, base, c["abrirMax"])
        if ok {
            n1 := WinGetList("ahk_pid " pid).Length
            SendEvent("v")                                ; submenu Lienzo
            ok := _NvEsperarMas(pid, n1, c["abrirMax"])
        }
        if ok {
            if (c["menuDown"] >= 0)
                SendEvent((c["menuDown"] > 0 ? "{Down " c["menuDown"] "}" : "") "{Enter}")
            else
                SendEvent("n")
            ; Enter enviado: no se reintenta (evita documentos duplicados)
            ok2 := _NvEsperarHasta(pid, base, c["abrirMax"])
            OutputDebug("[Nv] disparo " A_Index ": enter enviado, menus cerrados=" ok2)
            if !ok2
                Loop 3
                    SendEvent("{Esc}")
            return true
        }
        OutputDebug("[Nv] disparo " A_Index ": el menu no abrio, reintento")
        Loop 3
            SendEvent("{Esc}")
        Sleep(250)
    }
    return false
}

_NvRangoRect(nombre := "zonasegura", usarDefault := true) {
    global PERFIL
    static DEF := [-2437, 819, 315, 535]
    ini := _PosGuiIniPath()                           ; usa la ruta oficial del proyecto
    orden := [IsSet(PERFIL) ? PERFIL : 2, 2, 1]
    for p in orden {
        try {
            v := IniRead(ini, "Rangos" p . _ZonaSuf(), nombre, "")
            if (v = "" && _ZonaModo() = 2)
                v := IniRead(ini, "Rangos" p, nombre, "")
        }
        catch
            continue
        n := StrSplit(Trim(v), ",")
        if (n.Length != 4)
            continue                                  ; un punto (2 coords) no es un rect
        ok := true
        for i, t in n {
            n[i] := Trim(t)
            if !IsInteger(n[i])
                ok := false
        }
        if (ok && Integer(n[3]) > 0 && Integer(n[4]) > 0
            && _NvRectVisible(Integer(n[1]), Integer(n[2]), Integer(n[3]), Integer(n[4])))
            return {x: Integer(n[1]), y: Integer(n[2]), w: Integer(n[3]), h: Integer(n[4])}
    }
    if !usarDefault
        return 0
    if _NvRectVisible(DEF[1], DEF[2], DEF[3], DEF[4])
        return {x: DEF[1], y: DEF[2], w: DEF[3], h: DEF[4]}
    MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b)
    return {x: l + (r - l - DEF[3]) // 2, y: t + (b - t - DEF[4]) // 2, w: DEF[3], h: DEF[4]}
}

_NvArrastrarPestana(x1, y1, x2, y2) {
    c := _NvCfg()
    pasos := c["pasos"]
    bloqueado := false
    CoordMode("Mouse", "Screen")
    try {
        BlockInput("MouseMove")
        bloqueado := true
    }
    try {
        MouseMove(x1, y1, 0)
        Sleep(40)
        Click("Down")
        Sleep(40)
        Loop pasos {
            MouseMove(x1 + (x2 - x1) * A_Index // pasos, y1 + (y2 - y1) * A_Index // pasos, 0)
            Sleep(c["pasoMs"])
        }
        MouseMove(x2, y2, 0)
        Sleep(40)
        Click("Up")
    } catch {
        try Click("Up")
    }
    if (bloqueado)
        try BlockInput("MouseMoveOff")
}

; Compara dos colores 0xRRGGBB con tolerancia por canal.
_NvColorCerca(a, b, tol) {
    a := Integer(a), b := Integer(b)
    return Abs(((a >> 16) & 255) - ((b >> 16) & 255)) <= tol
        && Abs(((a >> 8) & 255) - ((b >> 8) & 255)) <= tol
        && Abs((a & 255) - (b & 255)) <= tol
}

; Prueba la fila medida y filas cercanas (tolera borde/gradiente de Qt). Map(x, y, ancho) o 0.
_NvTabActivaAgarre(main) {
    ; Si el usuario calibró NvPestana en el Calibrador visual, usamos ese rectángulo exacto
    rg := 0
    try rg := ObtenerRango("NvPestana")
    fx := fy := fw := fh := 0
    try WinGetPos(&fx, &fy, &fw, &fh, "ahk_id " main)
    ; NvPestana solo vale si se solapa con el marco actual; si no, se usa el respaldo
    if (IsObject(rg) && IsInteger(rg.w) && rg.w > 40 && IsInteger(rg.h) && rg.h > 10
        && rg.x < fx + fw && rg.x + rg.w > fx && rg.y < fy + fh && rg.y + rg.h > fy) {
        yCentro := rg.y + (rg.h // 2)
        xFinR := Min(rg.x + rg.w, fx + fw)      ; no barrer fuera del marco
        for dy in [0, 3, -3, 6, -6] {
            g := _NvTabActivaEnRango(Max(rg.x, fx), yCentro + dy, xFinR)
            if IsObject(g) {
                _NvLog("detectada-en-NvPestana dy=" dy)
                return g
            }
        }
        _NvLog("no-detectada-en-NvPestana")
        return 0
    }

    ; Fallback: cálculo relativo al marco si no estuviera calibrada NvPestana
    for dy in [0, 4, -4, 8, -8] {
        g := _NvTabActivaEnFila(main, dy)
        if IsObject(g) {
            _NvLog("detectada dy=" dy)
            return g
        }
    }
    _NvLog("no-detectada: revisar colorTab/tabYRel/margenes (usar NvDiagBarra)")
    return 0
}

_NvTabActivaEnRango(xIni, y, xFin) {
    c := _NvCfg()
    col := c["colorTab"]
    if (col = "")
        return 0
    CoordMode("Pixel", "Screen")
    tol := c["varColor"]
    paso := 3
    intentos := 0
    while (intentos++ < 8 && xIni < xFin) {
        px := py := 0
        hallado := false
        try hallado := PixelSearch(&px, &py, xIni, y, xFin, y, col, tol)
        if !hallado
            return 0
        xr := px, huecos := 0, x := px + paso
        while (x < xFin && huecos < c["huecoMax"]) {
            if _NvColorCerca(PixelGetColor(x, y), col, tol) {
                xr := x, huecos := 0
            } else
                huecos += paso
            x += paso
        }
        ancho := xr - px
        if (ancho >= c["anchoMin"]) {
            off := Min(c["agarreMax"], Max(c["agarreMin"], Round(ancho * c["agarrePct"])))
            off := Max(12, Min(off, ancho - 40))
            return Map("x", px + off, "y", y, "ancho", ancho, "px", px)
        }
        xIni := xr + paso + 1
    }
    return 0
}

_NvTabActivaEnFila(main, dy) {
    c := _NvCfg()
    fx := fy := fw := fh := 0
    try {
        WinGetPos(&fx, &fy, &fw, &fh, "ahk_id " main)
    } catch
        return 0
    return _NvTabActivaEnRango(fx + c["margenIzq"], fy + c["tabYRel"] + dy, fx + fw - c["margenDer"])
}

; Calibracion: poner el cursor sobre el FONDO de la pestana activa (sin texto) y lanzar.
; Copia el color al portapapeles y muestra tabYRel.
NvMedirColorTab() {
    CoordMode("Mouse", "Screen")
    CoordMode("Pixel", "Screen")
    MouseGetPos(&mx, &my)
    col := PixelGetColor(mx, my)
    fy := 0
    try WinGetPos(, &fy, , , "ahk_class " _NvCfg()["claseMarco"])
    A_Clipboard := col
    ToolTip("colorTab=" col "  tabYRel=" (my - fy) "  (color copiado)")
    SetTimer(() => ToolTip(), -4000)
}

; Copia al portapapeles el color cada 40 px a lo largo de la franja de pestanas.
NvDiagBarra() {
    c := _NvCfg()
    CoordMode("Pixel", "Screen")
    main := WinExist("ahk_class " c["claseMarco"])
    if !main
        return
    fx := fy := fw := 0
    WinGetPos(&fx, &fy, &fw, , "ahk_id " main)
    y := fy + c["tabYRel"]
    s := "y=" y "  fx=" fx "  fw=" fw "`n"
    x := fx + c["margenIzq"]
    while (x < fx + fw - c["margenDer"]) {
        s .= x ": " PixelGetColor(x, y) "`n"
        x += 40
    }
    A_Clipboard := s
    ToolTip("diagnostico copiado al portapapeles")
    SetTimer(() => ToolTip(), -3000)
}

_NvRectVisible(x, y, w, h) {
    cx := x + w // 2, cy := y + h // 2
    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
        if (cx >= l && cx < r && cy >= t && cy < b)
            return true
    }
    return false
}
; === NUEVA-VENTANA-RANGO-END ===
