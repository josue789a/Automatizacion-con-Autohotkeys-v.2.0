#Requires AutoHotkey v2.0
; ═══════════════════════════════════════════════════════════════════════════
;  lib\calibrador_py.ahk — puente AHK ⇄ Calibrador Python (customtkinter)
;  Incluir UNA vez:  #Include lib\calibrador_py.ahk
;  Y llamar CalPyInit() al arrancar el script. Abrir con AbrirCalibradorPy().
;
;  Python → AHK: WM_COPYDATA (0x4A), dwData = 0x58504E01, texto UTF-16 "CMD|arg|arg".
;  AHK → Python: argumentos de línea de comandos (--ini, --perfil, --modo, --ahk-hwnd).
;  Los comandos se despachan con SetTimer(-1) para devolver 1 al instante y no
;  bloquear a Python (SendMessageTimeout de 1.5 s).
; ═══════════════════════════════════════════════════════════════════════════

global CALPY_DIR := A_ScriptDir "\calibrador_py"
global CALPY_PID := 0
global CALPY_HWND := 0

_CalPyEnviarPython(texto) {
    global CALPY_HWND
    if (!CALPY_HWND || !DllCall("IsWindow", "ptr", CALPY_HWND))
        return false
    MARKER := 0x58504E01
    cb := StrPut(texto, "UTF-16") * 2
    cds := Buffer(A_PtrSize * 3, 0)
    NumPut("UPtr", MARKER, cds, 0)
    NumPut("UInt", cb, cds, A_PtrSize)
    buf := Buffer(cb)
    StrPut(texto, buf, "UTF-16")
    NumPut("Ptr", buf.Ptr, cds, A_PtrSize * 2)
    res := 0
    ok := DllCall("SendMessageTimeoutW", "ptr", CALPY_HWND, "uint", 0x4A, "ptr", A_ScriptHwnd, "ptr", cds.Ptr, "uint", 2, "uint", 1500, "uptr*", &res)
    return ok
}

_CalPyCapResultado(seq, estado, combo, target) {
    _CalPyLog("CAP_RESULT -> " seq " | " estado " | " combo " | " target)
    try FileDelete(A_Temp "\_ahk_cap_result.txt")
    try FileAppend(estado "|" combo "|" target, A_Temp "\_ahk_cap_result.txt", "UTF-8-RAW")
    _CalPyEnviarPython("CAP_RESULT|" seq "|" estado "|" combo "|" target)
}
global CALPY_PYW := CALPY_DIR "\.venv\Scripts\pythonw.exe"
global CALPY_PYW_REAL := "C:\Users\jbard\AppData\Local\Python\pythoncore-3.14-64\pythonw.exe"
global CALPY_LOG := A_Temp "\_calibrador_py_ahk.log"

CalPyInit() {
    try FileDelete(A_Temp "\_ahk_bridge_hwnd.txt")
    try FileAppend(String(A_ScriptHwnd), A_Temp "\_ahk_bridge_hwnd.txt", "UTF-8-RAW")
    OnMessage(0x4A, _CalPyOnCopyData)
    OnExit(_CalPyCerrarInstancia)
    try Cap_FijarCallback(_CalPyCapResultado)
}

_CalPyCerrarInstancia(*) {
    try FileDelete(A_Temp "\_ahk_bridge_hwnd.txt")
    _CalPyCerrarProceso()
}

; Prioridad: 1) Python real instalado, 2) .venv del proyecto, 3) PATH ignorando el alias de Microsoft Store.
_CalPyResolverExe() {
    for ruta in [CALPY_PYW_REAL, CALPY_PYW]
        if FileExist(ruta)
            return ruta
    for dir in StrSplit(EnvGet("PATH"), ";") {
        if (dir = "" || InStr(dir, "\WindowsApps"))
            continue
        cand := RTrim(dir, "\") "\pythonw.exe"
        if FileExist(cand)
            return cand
    }
    return ""
}

AbrirCalibradorPy(*) {
    global PERFIL, CALPY_PID
    pyExe := _CalPyResolverExe()
    if (pyExe = "") {
        _CalPyLog("no se encontró pythonw.exe real (ni instalado, ni .venv, ni PATH)")
        throw Error("Python real no encontrado")   ; companion_flotantes.ahk lo captura y cae al clásico solo en este caso
    }
    try _CalPyExportarCatalogo()
    catch as e
        _CalPyLog("exportar catálogo: " e.Message)
    perfil := IsSet(PERFIL) ? PERFIL : 1
    cmd := '"' pyExe '" -m xppen_calibrador'
        . ' --ini "' _PosGuiIniPath() '"'
        . ' --perfil ' perfil
        . ' --modo ' _CalPyModoActual()
        . ' --ahk-hwnd ' A_ScriptHwnd
    try {
        Run(cmd, CALPY_DIR, , &CALPY_PID)
    } catch as e {
        _CalPyLog("Run falló: " e.Message " | cmd: " cmd)
        ; Fallback con consola (mismo intérprete, python.exe) para ver el traceback
        Run('"' StrReplace(pyExe, "pythonw.exe", "python.exe") '" -m xppen_calibrador --ini "' _PosGuiIniPath()
            . '" --perfil ' perfil ' --ahk-hwnd ' A_ScriptHwnd, CALPY_DIR, , &CALPY_PID)
    }
}

_CalPyModoActual() {
    try return (enfoque.activo ? "enfoque" : "normal")      ; ANCLA: 0 = Normal, 1 = Enfoque
    return "normal"
}

; ── Catálogo: AHK es dueño de ids / nombres / grupos ──────────────────────
_CalPyExportarCatalogo() {
    defs := _PtsEventosDefs()                               ; ANCLA: lista de [id, nombre, grupo]
    out := '{"eventos":['
    sep := ""
    for d in defs {
        atajo := ""
        try atajo := _PtsEvAtajoDefault(d[1])               ; ANCLA: atajo por defecto del evento
        out .= sep '{"id":' _CalPyJ(d[1]) ',"nombre":' _CalPyJ(d[2]) ',"grupo":' _CalPyJ(d[3])
            . ',"atajo":' _CalPyJ(atajo) '}'
        sep := ","
    }
    out .= "]}"
    DirCreate(CALPY_DIR "\data")
    f := FileOpen(CALPY_DIR "\data\catalogo.json", "w", "UTF-8")
    f.Write(out)
    f.Close()
}

_CalPyJ(s) {
    s := String(s)
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`t", "\t")
    return '"' s '"'
}

; ── Receptor de comandos ──────────────────────────────────────────────────
_CalPyOnCopyData(wParam, lParam, msg, hwnd) {
    if NumGet(lParam, 0, "UPtr") != 0x58504E01
        return 0
    global CALPY_HWND := wParam
    EntornoRegistrar(wParam)
    try EntornoRegistrar(DllCall("GetAncestor", "ptr", wParam, "uint", 2, "ptr"))
    texto := StrGet(NumGet(lParam, 2 * A_PtrSize, "Ptr"), "UTF-16")
    SetTimer(_CalPyDespachar.Bind(StrSplit(texto, "|")), -1)
    return 1
}

_CalPyDespachar(p) {
    cmd := p[1]
    if (cmd != "CAPTURE_PING")
        _CalPyLog("← " cmd (p.Length > 1 ? " | " p[2] : "") (p.Length > 2 ? " | " p[3] : ""))
    try {
        switch cmd {
            case "RELOAD_INI":
                _CalPyRecargarIni()
            case "RESTART_SCRIPT":
                _CalPyReiniciarSeguro()
            case "SET_MODE":
                ; ANCLA 1 — cambio de modo vía EstablecerModoTrabajo ("Normal" / "Enfoque")
                _CalPyLlamar(["EstablecerModoTrabajo"], p[2] = "enfoque" ? "Enfoque" : "Normal")
            case "DRAW_ZONE":
                ; ANCLA 2 — dibujar zona con el lápiz: p[2] = idEv, p[3] = cruzar | auto | hover
                ; C2: p[3]="zona" → p[2] = prefijo de la zona (p1…p7), p[4] = modo (1 Normal | 2 Enfoque)
                _CalPyLlamar(["_CalPyDibujarZona"], p[2], p.Length > 2 ? p[3] : "cruzar", p.Length > 3 ? p[4] : 1)
            case "CAL_ZONE":
                _CalPyLlamar(["_CalPyCalibrarZona"], p[2], p.Length > 2 ? p[3] : "panel", p.Length > 3 ? p[4] : "cruzar", p.Length > 4 ? p[5] : "evento", p.Length > 5 ? p[6] : "")
            case "SELECT_EVENT":
                _CalPyLlamar(["_CalPySeleccionarEvento"], p[2], p.Length > 2 ? p[3] : "")
            case "DRAW_SLIDER":
                ; ANCLA 2b — dibujar deslizador o enfoque
                _CalPyLlamar(["_PtsDibujarZonaEstab"], (p.Length > 2 && p[2] = "enfoque") ? true : false)
            case "SHOW_PILL":
                ; ANCLA 3 — "Ubicar en pantalla" de la píldora del evento p[2]
                _CalPyLlamar(["_PtsPildoraUbicar"], p[2])
            case "TEST_HUD":
                ; ANCLA 4 — probar el aviso HUD del evento p[2]
                _CalPyLlamar(["_CalPyProbarHud"], p[2]
                    , (p.Length > 2 && p[3] != "") ? p[3] : "00E5FF"
                    , p.Length > 3 ? p[4] : ""      ; formato (vivo)
                    , p.Length > 4 ? p[5] : ""      ; zona (viva)
                    , p.Length > 5 ? p[6] : ""      ; opacidad (viva)
                    , p.Length > 6 ? p[7] : ""      ; texto (vivo)
                    , p.Length > 7 ? p[8] : "")     ; duración (viva)
            case "TEST_SND":
                ; ANCLA 5 — probar sonido: p[2] = tipo, p[3] = volumen 0-100
                ; p[4] = id del evento (opcional): habilita el sonido nativo
                _CalPyProbarSnd(p.Length > 1 ? p[2] : "clic", p.Length > 2 ? p[3] : 60
                    , p.Length > 3 ? p[4] : "")
            case "OPEN_LEGACY":
                ; ANCLA 6 — abrir el calibrador clásico en la pestaña p[2] (1-4)
                _CalPyLlamar(["AbrirPanelPuntos"], p.Length > 1 ? p[2] : 1)
            ; ── Corrida 2 · ANCLAS REALES ENLAZADAS CON AHK ──
            case "SHOW_ZONES":      ; 👁 Ver zonas del modo p[2]
                _CalPyLlamar(["_PtsToggleVerZonas", "_PtsVerRangos", "_PtsVerZonas"], p[2])
            case "LOCK_BUTTONS":    ; 🔒 Fijar botones (alterna el candado)
                _CalPyToggleLockButtons()
            case "RELOCATE_BUTTONS": ; ↻ Reubicar botones
                _CalPyLlamar(["ReubicarBotones", "_PtsReubicar"])
            case "LAYOUT_SAVE":     ; 💾 guardar layout de paneles CSP: p[2] = normal | enfoque
                _CalPyLayoutSave(p.Length > 1 ? p[2] : "normal")
            case "LAYOUT_APPLY":    ; ▶ aplicar layout de paneles CSP: p[2] = normal | enfoque
                _CalPyLayoutApply(p.Length > 1 ? p[2] : "normal")
            case "RELOAD_THEME":    ; ✔ Aplicar tema: theme.ini ya está escrito; p[2] = nombre del tema
                _CalPyReloadTheme(p.Length > 1 ? p[2] : "")
            case "CAPTURE_ON":
                _CalPyCapturaOn()
            case "CAPTURE_OFF":
                _CalPyCapturaOff()
            case "CAPTURE_PING":
                _CalPyCapturaLatido()
            case "CAP_ARM":
                _CalPyCapEstado().on := false
                seq := (p.Length > 1 && IsInteger(p[2])) ? Integer(p[2]) : 0
                target := (p.Length > 1 && !IsInteger(p[2])) ? p[2] : (p.Length > 2 ? p[3] : "")
                etiqueta := (p.Length > 2 && !IsInteger(p[2])) ? p[3] : (p.Length > 3 ? p[4] : "")
                Cap_Armar(seq, target, etiqueta)
            case "CAP_PREP":
                Cap_Preparar(p.Length > 1 ? p[2] : "", p.Length > 2 ? p[3] : "", p.Length > 3 ? Integer(p[4]) : 0)
            case "CAP_CANCEL":
                Cap_Cancelar(p.Length > 1 ? p[2] : "cancel_remoto")
            default:
                _CalPyLog("comando desconocido: " cmd)
        }
    } catch as e {
        _CalPyLog("ERROR en " cmd ": " e.Message " (" e.What ")")
    }
}

_CalPyCerrarProceso() {
    global CALPY_PID
    if (CALPY_PID && ProcessExist(CALPY_PID)) {
        ; /T mata el árbol: el stub pythonw de un venv deja un hijo si solo se mata el PID.
        try RunWait('taskkill /PID ' CALPY_PID ' /T /F', , 'Hide')
        try ProcessWaitClose(CALPY_PID, 2)
        if ProcessExist(CALPY_PID)
            OutputDebug("_CalPyCerrarProceso: PID " CALPY_PID " sigue vivo tras taskkill")
    }
    try RunWait('taskkill /F /IM pythonw.exe', , 'Hide')
    CALPY_PID := 0
}

_CalPyReiniciarSeguro() {
    _CalPyCerrarProceso()
    try {
        cmd := A_IsCompiled
            ? '"' A_ScriptFullPath '" /restart'
            : '"' A_AhkPath '" /restart "' A_ScriptFullPath '"'
        Run(cmd, A_ScriptDir)   ; hereda la elevación actual: sin prompt UAC extra ni *RunAs
    } catch as e {
        OutputDebug("_CalPyReiniciarSeguro: Run falló -> " e.Message)
        Reload()
        return
    }
    ExitApp()   ; libera mutex/handles para que /restart tome el relevo
}

_CalPyRecargarIni() {
    ; Relectura en caliente SIN Reload(): cada gancho va en try; si no existe se registra y se sigue.
    ; Orden: caché de puntos -> puntos -> zonas -> escalas -> HUD -> hotkeys -> reset toggles pausados -> espacial/pill -> audio -> lock.
    for nombre in ["_PtsCache", "_CompInvalidar", "CargarPuntos", "RecalcularZonas", "CargarEscala", "CargarEscalaAvisos"
                 , "_HudLimpiarCache", "_RemapCargarHotkeys", "_ModToggleResetPausados", "_EspacialCargar", "_PillSincronizarDinamicas"
                 , "_CompanionRestaurarAudio", "ActualizarLockGUI"] {
        if !_CalPyLlamar([nombre])
            OutputDebug("_CalPyRecargarIni: gancho no disponible -> " nombre)
    }
}

; Llama a la primera función existente de `candidatos`; registra si no hay ancla.
_CalPyLlamar(candidatos, args*) {
    for nombre in candidatos {
        try {
            fn := %nombre%
        } catch {
            continue
        }
        fn(args*)
        return true
    }
    _CalPyLog("SIN ANCLA: " candidatos[1])
    return false
}

_CalPyToggleLockButtons() {
    global panelBlk
    if IsSet(panelBlk) {
        panelBlk.locked := !panelBlk.locked
        try _EscribirEstadoBloque("locked", panelBlk.locked ? 1 : 0)
        try ActualizarLockGUI()
        try MostrarHUD(panelBlk.locked ? "🔒 BLOQUE FIJADO" : "🔓 BLOQUE LIBRE", panelBlk.locked ? "44DD88" : "FFAA00")
        return true
    }
    return false
}

_CalPyLayoutSave(modo := "normal") {
    m := (StrLower(modo) = "enfoque") ? "Enfoque" : "Normal"
    try _CapturarLayout(m)
    return true
}

_CalPyLayoutApply(modo := "normal") {
    m := (StrLower(modo) = "enfoque") ? "Enfoque" : "Normal"
    try _AplicarLayoutPaneles(m)
    return true
}

; Reproduce el sonido NATIVO de un evento existente (_SonarFast / _SonarUI).
; Devuelve true si el evento tiene sonido nativo y lo tocó.
_CalPySndNativo(idEv) {
    k := StrLower(Trim(idEv))
    switch k {
        case "pluma", "q":
            try _SonarFast("pluma")
            return true
        case "aerografo", "w", "aerografo_alpha":
            try _SonarFast("aerografo")
            return true
        case "color_primario":
            try _SonarFast("color_primario")
            return true
        case "color_secundario":
            try _SonarFast("color_secundario")
            return true
        case "shift_sostenido", "shift_on":
            try _SonarFast("shift_on")
            return true
        case "shift_off":
            try _SonarFast("shift_off")
            return true
        case "borrador", "borrador_capas", "borrador_suave", "borrador_lazo", "e":
            try _SonarUI("borrador")
            return true
        case "lazo", "area_color", "s":
            try _SonarUI("lazo")
            return true
        case "pincel", "pincel_suave", "pincel_duro", "difu_mixer", "opc_presion", "smudge", "smear", "smear_soft", "color_mix":
            try _SonarUI("pincel")
            return true
        case "relleno":
            try _SonarUI("relleno")
            return true
        case "guardar":
            try _SonarUI("guardar")
            return true
        case "layout", "sync":
            try _SonarUI(k)
            return true
        case "enfoque":
            try _SonarUI("enfoque_on")
            return true
        case "deseleccion", "reseleccion", "inv_seleccion":
            try _SonarUI("seleccion")
            return true
        case "copiar":
            try _SonarUI("copiar")
            return true
        case "flip_horizontal", "rotar_lienzo", "zoom_lienzo":
            try _SonarUI("flip")
            return true
        case "estab_slider":
            try _SonarUI("slider", 50)
            return true
        case "reload":
            try _SonarUI("reload")
            return true
        case "calib":
            try _SonarUI("calib")
            return true
    }
    return false
}

_CalPyProbarSnd(tipo := "clic", vol := 60, idEv := "") {
    t := StrLower(tipo)
    v := IsInteger(vol) ? Integer(vol) : 60

    ; 1) Sin override activo, un evento existente suena con su sonido real nativo.
    if (idEv != "") {
        ov := ""
        try ov := _SndLeer(idEv)
        if ((!IsObject(ov) || !ov.propio) && _CalPySndNativo(idEv))
            return true
    }

    ; 2) Eventos nuevos o con opción sonora elegida en la interfaz:
    if (t = "suave" || t = "clic")
        t := "clic"
    else if (t = "beep" || t = "agudo")
        t := "agudo"
    else if (t = "grave")
        t := "grave"
    else if (t = "doble")
        t := "doble"

    if (t != "mute" && v > 0) {
        try {
            _SndTocar(t, v)
            return true
        }
    }
    return false
}

_CalPyReloadTheme(nombreTema := "") {
    global estabGui
    perfiles := []
    try perfiles := _TemaPerfiles()
    encontrado := 0
    if (nombreTema != "") {
        for p in perfiles {
            if (p.nombre = nombreTema || InStr(p.nombre, nombreTema)) {
                encontrado := p
                break
            }
        }
    }
    if (encontrado) {
        try _TemaSelAplicarPerfil(encontrado)
        try IniWrite(encontrado.nombre, A_ScriptDir "\theme.ini", "meta", "nombre")
    }
    try _TemaRecargar()
    try _TemaRefrescarPaneles()
    if (IsSet(estabGui) && IsObject(estabGui)) {
        colAcento := _Tema("color", "accent.estab", "9A7BFF")
        colTrackOff := _Tema("color", "surface.on", "636C82")
        estabGui.estabTrackOn := colAcento
        estabGui.estabKnob := colAcento
        estabGui.estabTrackOff := colTrackOff
        try ActualizarEstabGUI(-1, true)
        try _EstabDibujar()
    }
    colBadge := _Tema("color", "accent.estab", "00E5FF")
    nom := (nombreTema != "") ? nombreTema : "Tema actualizado"
    try MostrarAvisoUI("moderno", nom, "PALETA APLICADA", 2, colBadge, 1500)
    try _SonarUI("calib")
    return true
}

_CalPyDibujarZona(idEv, tipo := "cruzar", modo := 1) {
    _DzLog("ENTRA _CalPyDibujarZona idEv=" idEv " tipo=" tipo " modo=" modo)
    if (tipo = "zona") {      ; C2: zona de la pestaña «Zonas y rangos»; AHK guarda en [Rangos<modo>]
        try {
            _PtsEditarRangoInteractivo(idEv, idEv)
            return
        }
        try {
            _PtsDibujarRango(idEv)
            return
        }
    }
    tit := idEv
    try tit := _PtsNomEvento(idEv)
    tit := Trim(RegExReplace(tit, "\s*\(.*\)\s*$"))
    _DzLog("ANTES de llamar _PtsEditarRangoInteractivo tit=" tit " idEv=" idEv)
    try {
        _PtsEditarRangoInteractivo(tit, idEv)
        _DzLog("DESPUES de llamar _PtsEditarRangoInteractivo exito")
    } catch as e {
        _DzLog("FALLO en llamada _PtsEditarRangoInteractivo: " e.Message " @" e.What " L" e.Line)
    }
}

_CalPyCalibrarZona(idEv, modo := "panel", tipo := "cruzar", clase := "evento", rotulo := "") {
    cola := []
    for id in StrSplit(idEv, ",", " ") {   ; "A01" o "A01,A02,A03" (cadena)
        if (id = "")
            continue
        t := id
        if (clase != "zona") {              ; zonas: el título ES el prefijo (clave de búsqueda del editor)
            try t := _PtsNomEvento(id)
            t := Trim(RegExReplace(t, "\s*\(.*\)\s*$"))
        }
        cola.Push({id: id, titulo: t, rotulo: (clase = "zona" && rotulo != "") ? rotulo : t})
    }
    if (cola.Length = 0)
        return
    guardar := (clase = "zona" && SubStr(cola[1].id, 1, 7) != "HUD_ev_") ? _PtsGuardarRangoZona : _PtsGuardarRangoEvento
    idReal := (SubStr(cola[1].id, 1, 7) = "HUD_ev_") ? SubStr(cola[1].id, 8) : cola[1].id
    tipoDestino := (clase = "evento" && (tipo = "cruzar" || tipo = "auto")) ? "zona" : "hud"
    _CalPySinPanel(clase = "zona" && (modo = "dibujar" || modo = "ajustar"))
    _PtsCalibrarZona(cola[1].titulo, idReal, "", modo, cola, guardar, tipoDestino)
}

; Bandera de un solo uso: el que la consume (_PtsCalibrarZona) la deja en false.
_CalPySinPanel(v?) {
    static f := false
    if IsSet(v)
        f := v ? true : false
    return f
}

_CalPyProbarHud(idEv, color := "00E5FF", fmt := "", zona := "", opac := "", texto := "", dur := "") {
    tit := idEv
    try tit := _PtsNomEvento(idEv)
    tit := Trim(RegExReplace(tit, "\s*\(.*\)\s*$"))

    ; Base persistida en el INI; lo editado en vivo en Python tiene prioridad.
    cfg := ""
    try cfg := HudConfigEvento(idEv)
    fmtF  := Trim(fmt)  != "" ? Trim(fmt)  : (IsObject(cfg) ? cfg.formato  : "moderno")
    zonaF := Trim(zona) != "" ? Trim(zona) : (IsObject(cfg) ? cfg.zona     : "baja")
    opacF := Trim(opac) != "" ? Trim(opac) : (IsObject(cfg) ? cfg.opacidad : 70)

    fmtF := StrLower(Trim(fmtF))
    zonaF := StrLower(Trim(zonaF))
    zNum := (zonaF = "alta") ? 1 : ((zonaF = "media") ? 2 : 3)

    ; La UI manda "70 % (Med)": se extrae el número y se limita a 0..100.
    opN := RegExMatch(opacF, "\d+", &mo) ? Integer(mo[0]) : 70
    opN := Max(0, Min(100, opN))

    ; "auto" o vacío → 1800 ms; número → limitado a 100..10000 (rango de la UI).
    durF := Trim(dur)
    durMs := RegExMatch(durF, "^\d+$") ? Max(100, Min(10000, Integer(durF))) : 1800

    txt := Trim(texto) != "" ? Trim(texto) : tit

    ; Color de acento según evento / zona (idéntico al calibrador oficial de AHK)
    colAcento := (color != "" && color != "00E5FF") ? color : ((idEv = "color_primario") ? "00E5FF" : ((zNum = 1) ? "FF6F61" : ((zNum = 2) ? "00E5FF" : "9A7BFF")))

    if (fmtF = "desactivado" || fmtF = "off") {
        ; Sin popup modal: tooltip breve y no bloqueante.
        ToolTip("HUD desactivado en este evento")
        SetTimer(() => ToolTip(), -1200)
    } else {
        try MostrarAvisoUI(fmtF, txt, (zNum = 3 ? "" : "PRUEBA"), zNum, colAcento, durMs, opN, idEv)
    }
    if (idEv = "estab_slider") {
        try _EstabFocoMostrar()
        SetTimer(_EstabFocoOcultar, -2500)
    }
    ; Feedback sonoro coordinado al probar HUD
    _CalPyProbarSnd("clic", 60, idEv)
}

_CalPyLog(msg) {
    try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") "  " msg "`n", CALPY_LOG, "UTF-8")
}

; ── Modo captura: suspende hotkeys mientras el Calibrador captura teclas ──
_CalPyCapEstado() {
    static e := {on: false, tick: 0}
    return e
}

_CalPyCapturaOn() {
    e := _CalPyCapEstado()
    e.on := true
    e.tick := A_TickCount
    Suspend(true)
    SetTimer(_CalPyCapturaVigilar, 500)
    _CalPyLog("captura ON (hotkeys suspendidos)")
}

_CalPyCapturaOff() {
    e := _CalPyCapEstado()
    e.on := false
    SetTimer(_CalPyCapturaVigilar, 0)
    Suspend(false)
    Send("{F24 up}")   ; por si el botón seguía "pulsado" al salir
    _CalPyLog("captura OFF (hotkeys reanudados)")
}

; Puente RButton -> F24 mientras el box de captura está armado.
; #SuspendExempt: el Suspend(true) de CAPTURE_ON no debe desactivarlos.
#SuspendExempt
#HotIf _CalPyCapEstado().on
*RButton::{
    _CalPyLog("AHK RButton down -> F24")
    Send("{Blind}{F24 down}")
}
*RButton up::{
    _CalPyLog("AHK RButton up -> F24")
    Send("{Blind}{F24 up}")
}
#HotIf
#SuspendExempt False

_CalPyCapturaLatido() {
    _CalPyCapEstado().tick := A_TickCount
}

_CalPyCapturaVigilar() {
    e := _CalPyCapEstado()
    if (!e.on) {
        SetTimer(_CalPyCapturaVigilar, 0)
        return
    }
    if (A_TickCount - e.tick > 3000) {
        _CalPyLog("captura: sin latido 3 s, reanudando hotkeys")
        _CalPyCapturaOff()
    }
}
