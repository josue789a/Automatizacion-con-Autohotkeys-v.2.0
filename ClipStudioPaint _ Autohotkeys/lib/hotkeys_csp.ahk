#Requires AutoHotkey v2.0
; [LIB] hotkeys_csp.ahk — fuente: XPPEN AHK VERSION ESTABLE.ahk L129–1250, L2480–2484, L2636–2676
; ==============================================================================
; DIRECTRICES CRÍTICAS DE HARDWARE Y PERIFÉRICOS (Keydial XP-Pen / Mandos):
; 1. ESTADO LÓGICO VS FÍSICO: NUNCA usar GetKeyState("Tecla", "P") para teclas
;    que puedan venir del mando (ej. Space de K7). Los drivers inyectan pulsaciones
;    por software y el flag "P" (físico) siempre devuelve FALSE, rompiendo los #HotIf.
;    Usar SIEMPRE GetKeyState("Tecla") (estado lógico de Windows).
; 2. MACROS MULTICADENA DEL DRIVER: Botones como K3 envían macros rápidas
;    (Shift↓ → E↓ → E↑ → Shift↑). Para anclar modificadores: esperar a que termine
;    el macro con KeyWait("Shift", "T0.3") y usar SetTimer reafirmador (-80 ms)
;    para que el Shift↑ inyectado por el driver no cancele el anclaje de AHK.
; 3. DESPACHADORES CENTRALIZADOS: Despachar teclas compartidas en funciones únicas
;    (ej. _SpaceE_Dispatch) para evitar carreras entre hotkeys nativos y macros.
; ==============================================================================
; ===== PAQUETE 2: SANITIZE DE MODIFICADORES =====
global _sftGui := 0
global _sftHud := 0   ; HUD anclado persistente de Shift Sostenido (ventana propia, fuera de floatGui)

_AltF_SoltarB(*) {
    global _bSmearAbajo
    if !_bSmearAbajo
        return
    _bSmearAbajo := false
    SendEvent("{b up}")
}

; Restaura Alt solo si el lápiz lo sigue sosteniendo Y CSP tiene el foco
_AltRestaurar(seguia) {
    if (seguia && stylus.altActive && WinActive("ahk_exe CLIPStudioPaint.exe"))
        SendEvent("{Alt down}")
}

; Suelta lo que Windows cree abajo pero tú no pulsas físicamente.
; Respeta los sostenidos intencionales (Alt del lápiz, Shift sostenido).
_LiberarFantasmas() {
    for k in ["Shift", "Alt", "Ctrl", "LWin", "RWin", "Space"] {
        if !GetKeyState(k) || GetKeyState(k, "P")
            continue
        if (k = "Alt" && stylus.altActive)
            continue
        if (k = "Shift" && shiftSostenido.activo)
            continue
        SendEvent("{" k " up}")
    }
}

; Limpieza de modificadores (foco o tecla de rescate).
; Shift sostenido SOLO se apaga con su propio toggle (~Space & -) o al salir del script.
_LiberarModificadores(esSalida := false, *) {
    SetTimer(_AltF_SoltarB, 0)
    _AltF_SoltarB()
    if (esSalida) {
        ShiftAnclado_Apagar(true)
        shiftSostenido.activo := false
    }
    for k in ["Shift", "Alt", "Ctrl", "LWin", "RWin", "Space"] {
        if (!esSalida && k = "Shift" && shiftSostenido.activo)
            continue
        if (!esSalida && k = "Alt" && stylus.altActive)
            continue
        if GetKeyState(k)
            SendEvent("{" k " up}")
    }
    if (esSalida)
        stylus.altActive := false
}
OnExit((*) => _LiberarModificadores(true))   ; libera el Shift anclado al salir o recargar

global _briefingLanzado := WinExist("ahk_exe CLIPStudioPaint.exe") ? true : false   ; recarga con CSP ya abierto = no relanza

LanzarBriefing() {
    DirOrganizador := "C:\Users\jbard\Downloads\Fase22_extraido\limpio\Orquestador\organizador-art"
    try Run('pythonw -m src.briefing --auto', DirOrganizador, "Hide")
}

_VigilaFocoCSP() {
    global _cspEraActiva, _briefingLanzado
    activa := WinActive("ahk_exe CLIPStudioPaint.exe") ? true : false
    if (_cspEraActiva && !activa)
        _LiberarModificadores()
    if (activa && !_briefingLanzado) {
        _briefingLanzado := true
        SetTimer(LanzarBriefing, -600)
    } else if (!WinExist("ahk_exe CLIPStudioPaint.exe")) {
        _briefingLanzado := false
    }
    _cspEraActiva := activa
}

; Pause::_LiberarModificadores()   ; tecla de rescate manual (unificada con _EscrituraSet en L111)

; ── E3: modulación de tecla (Bloque 3) ────────────────────
; INI [Particularidades], vía _CompIni:
;   <fila>_on_<idEv>=1
;   quick_a / quick_b / quick_ms_<idEv>   (corto / largo / umbral ms)
;   toggle_a / toggle_b_<idEv>
_ModEnviar(atajo, hud := "", colorHud := "00E5FF") {
    if (IsObject(atajo)) {
        atajo.Call()
        return true
    }
    if (atajo = "" || atajo = "off")
        return false
    atajo := _AtajoAEnvio(atajo)
    if !_CspEstadoEnviar(atajo)      ; k y ^2 mantienen colorEstado global; el resto se envía tal cual
        SendInput(atajo)
    if (hud != "")
        MostrarHUD(hud, colorHud, 900)
    return true
}
; Atajos de CSP que cambian el color global: misma lógica que $k:: y el doble toque de $q::,
; para que colorEstado (0 primario, 1 secundario, 2 alpha) siga siendo la única fuente de verdad.
_CspEstadoEnviar(seq) {
    global colorEstado
    s := StrLower(Trim(seq))
    if (s = "k") {
        if (colorEstado = 2) {
            SendInput("k")
            colorEstado := 0
        } else {
            if (colorEstado = 1)
                SendInput("^2")
            SendInput("k")
            colorEstado := 2
        }
        return true
    }
    if (s = "^2") {
        if (colorEstado = 2) {
            SendInput("k")
            colorEstado := 0
        }
        SendInput("^2")
        colorEstado := (colorEstado = 0) ? 1 : 0
        return true
    }
    return false
}
_ModAtajo(fila, campo, idEv, def) {
    v := _CompIni(fila, campo, idEv)
    return (v = "") ? def : v
}
_ModActivo(fila, idEv) {
    return IniRead(_PosGuiIniPath(), "Particularidades", fila "_" idEv, "0") = "1"
}

; Atajos cableados (legado): clave ausente = ACTIVO; solo "0" explícito lo desactiva.
; Difiere de _ModActivo (ausente = inactivo) para no romper el comportamiento histórico.
_ModActivoCab(fila, idEv) {
    return IniRead(_PosGuiIniPath(), "Particularidades", fila "_" idEv, "") != "0"
}
; Pulsación Rápida: máquina de estados universal (replica los despachadores a medida de pre-Companion).
;   1.er toque ........ envía A al instante (cero lag: sin KeyWait previo ni timers)
;   2.º toque < ms .... suelta A y envía B; la ventana se consume
;   toque posterior ... vuelve a A (restauración limpia)
; quick_modo_<id>=largo conserva el modo anterior: toque corto = A, mantener >= ms = B.
; quick_alphaout_<id>=1: si colorEstado=2, envía k antes de A/B (como E y Q del original).
_ModQuick(idEv, tecla, defBase, defParticular := "") {
    static ultimos := Map()
    global colorEstado
    cfg := _ModCfg(idEv)
    if (!cfg.quick)
        return _ModEnviar(defBase)
    ; Salvaguarda: B vacío u "off" = desactivación explícita (sin espera ni envío fantasma)
    bTecla := (cfg.b != "") ? cfg.b : Trim(defParticular)
    if (bTecla = "" || bTecla = "off")
        return _ModEnviar(defBase)
    aTecla := (cfg.a != "") ? cfg.a : defBase
    if (cfg.modo = "largo")
        return _ModQuickLargo(tecla, aTecla, bTecla, cfg, idEv)
    now := A_TickCount
    last := ultimos.Get(idEv, 0)
    if (last > 0 && now - last < cfg.ms) {
        ultimos[idEv] := 0
        _ModSoltar(aTecla)
        if (cfg.alphaOut && colorEstado = 2 && StrLower(bTecla) != "k") {
            SendInput("k")
            colorEstado := 0
        }
        _ModEnviar(bTecla, cfg.hud ? idEv : "")
    } else {
        ultimos[idEv] := now
        if (cfg.alphaOut && colorEstado = 2 && StrLower(aTecla) != "k") {
            SendInput("k")
            colorEstado := 0
        }
        _ModEnviar(aTecla)
    }
    KeyWait(tecla, "T10")   ; el auto-repeat del teclado no debe contar como doble toque
    return true
}
_ModQuickLargo(tecla, aTecla, bTecla, cfg, idEv) {
    if KeyWait(tecla, "T" (cfg.ms / 1000))
        return _ModEnviar(aTecla)
    _ModEnviar(bTecla, cfg.hud ? idEv : "")
    KeyWait(tecla)
    if (cfg.ret)
        _ModEnviar(bTecla)
    return true
}
; Equivale al {z up}/{e up} del original antes de la particularidad. Inocuo si la tecla no está abajo.
_ModSoltar(atajo) {
    if IsObject(atajo)
        return
    a := Trim(atajo)
    if RegExMatch(a, "^[A-Za-z0-9]$|^F\d{1,2}$")
        SendInput("{" StrLower(a) " up}")
}
; Config por evento cacheada (cero IniRead por pulsación). Se invalida al recargar el INI o si cambia su mtime.
_ModCfg(idEv, reset := false) {
    static cache := Map(), mt := ""
    if (reset) {
        cache := Map()
        mt := ""
        return ""
    }
    ini := _PosGuiIniPath()
    m := ""
    try m := FileGetTime(ini, "M")
    if (m != mt) {
        cache := Map()
        mt := m
    }
    if cache.Has(idEv)
        return cache[idEv]
    atajo := Trim(IniRead(ini, "Remapeos", "atajo_" idEv, ""))
    v := _CompIni("quick", "ms", idEv)
    ms := (IsInteger(v) && Integer(v) >= 50 && Integer(v) <= 2000) ? Integer(v) : 250
    cfg := {quick: _ModActivo("quick", idEv)
          , a: Trim(_ModAtajo("quick", "a", idEv, atajo))
          , b: Trim(_ModAtajo("quick", "b", idEv, ""))
          , ms: ms
          , modo: StrLower(Trim(_CompIni("quick", "modo", idEv)))
          , ret: (Trim(_CompIni("quick", "ret", idEv)) != "0")
          , alphaOut: (Trim(_CompIni("quick", "alphaout", idEv)) = "1")
          , hud: _ModActivo("hud", idEv)}
    cache[idEv] := cfg
    return cfg
}
_ModCfgInvalidar() => _ModCfg("", true)
_ModLado() {
    static lado := Map()
    return lado
}

_ModToggleReset(idEv) {
    lado := _ModLado()
    if lado.Has(idEv)
        lado[idEv] := false
}

_ModToggleResetPausados() {
    try {
        sec := IniRead(_PosGuiIniPath(), "EventosPausados")
        for lin in StrSplit(sec, "`n", "`r") {
            p := InStr(lin, "=")
            if (p && Trim(SubStr(lin, p + 1)) = "1")
                _ModToggleReset(Trim(SubStr(lin, 1, p - 1)))
        }
    }
}

; Cada pulsación alterna A ⇄ B.
_ModToggle(idEv, defA := "", defB := "") {
    lado := _ModLado()
    if (defA = "")
        defA := IniRead(_PosGuiIniPath(), "Remapeos", "atajo_" idEv, "")
    if (!_ModActivo("toggle", idEv))
        return _ModEnviar(defA)
    esB := lado.Get(idEv, false)
    if (esB) {
        atB := _ModAtajo("toggle", "b", idEv, defB)
        if (atB = "") {
            lado[idEv] := false                       ; sin B no hay alternancia: se vuelve a enviar A
            MostrarHUD("⚠️ Alternador: Falta Tecla B", "FF3366", 1200)
            return _ModEnviar(_ModAtajo("toggle", "a", idEv, defA))
        }
        lado[idEv] := false
        return _ModEnviar(atB, "🔁 B: " atB "  ▸ A", "FFB300")
    }
    lado[idEv] := true
    atA := _ModAtajo("toggle", "a", idEv, defA)
    return _ModEnviar(atA, "🔁 A: " atA "  ▸ B", "00E5FF")
}

; ============================================================
; DESPACHADOR DINÁMICO DE REMAPEOS Y MODULACIONES
; ============================================================
global _RemapRegistrados := []
global _RemapCtxCache := Map()

; "Space+G" / "Ctrl+Shift+Z" / "F5" -> {hk, mods, principal, held}
_RemapNormalizar(txt) {
    txt := Trim(txt)
    if (txt = "" || StrLower(txt) = "off")
        return ""
    txt := StrReplace(txt, "&", "+")
    partes := StrSplit(txt, "+", " `t")
    principal := _RemapNombreTecla(partes.Pop())
    if (principal = "")
        return ""
    mods := "", held := []
    for p in partes {
        switch StrLower(p) {
            case "ctrl", "control", "ctl": mods .= "^"
            case "shift":                  mods .= "+"
            case "alt":                    mods .= "!"
            case "win", "windows":         mods .= "#"
            default:                       held.Push(_RemapNombreTecla(p))
        }
    }
    return {hk: "$" mods principal, mods: mods, principal: principal, held: held}
}

_RemapNombreTecla(t) {
    t := Trim(t)
    return (StrLen(t) = 1) ? StrLower(t) : t
}

; Convierte sintaxis "humana" (Ctrl+G, Space+G, G) a cadena válida de Send.
_AtajoAEnvio(a) {
    if (IsObject(a))
        return a
    a := Trim(a)
    if (StrLen(a) = 1)
        return InStr("^!+#", a) ? "{" a "}" : StrLower(a)
    if (InStr(a, "+") && !RegExMatch(a, "[{}^!#]") && SubStr(a, 1, 1) != "+") {
        n := _RemapNormalizar(a)
        if !IsObject(n)
            return a
        pre := "", post := ""
        for k in n.held {
            pre .= "{" k " down}"
            post := "{" k " up}" post
        }
        p := (StrLen(n.principal) > 1) ? "{" n.principal "}" : n.principal
        return pre n.mods p post
    }
    return a
}

_RDiag(msg) {   ; TEMP-DIAG
    try FileAppend(A_Now "." A_MSec " " msg "`n", A_ScriptDir "\logs\remap_diag.log")
}

; Contexto HotIf: CSP activo + teclas sostenidas (Space, etc.) presionadas.
; Regla HW: GetKeyState(k) logico, sin "P", para soportar keydials/drivers sinteticos.
_RemapCtx(held) {
    global _RemapCtxCache
    clave := "-"
    for k in held
        clave .= k "|"
    if (_RemapCtxCache.Has(clave))
        return _RemapCtxCache[clave]
    fn := (*) => _RemapCtxOk(held)
    _RemapCtxCache[clave] := fn
    return fn
}

; Contexto del combo nativo ~RButton & <tecla>: AHK ya garantiza RButton abajo.
_RemapCtxNativo() {
    global _RemapCtxCache
    if (!_RemapCtxCache.Has("#nativo"))
        _RemapCtxCache["#nativo"] := (*) => CspLibre()
    return _RemapCtxCache["#nativo"]
}
; Alt físico O Alt del botón 1 del stylus (Alt+B); RButton físico O el del botón 2
_TeclaSostenida(k) {
    if GetKeyState(k)
        return true
    kl := StrLower(k)
    if (kl = "alt" || kl = "lalt" || kl = "ralt" || kl = "!")
        return !!stylus.altActive
    if (kl = "rbutton")
        return !!stylus.rButtonHeld
    return false
}

_RemapCtxOk(held) {
    if !CspLibre() {
        if (held.Length && WinActive("ahk_exe CLIPStudioPaint.exe"))   ; TEMP-DIAG
            _RDiag("CTX no: !CspLibre arm=" Cap_Armado())
        return false
    }
    for k in held {
        if !_TeclaSostenida(k) {
            _RDiag("CTX no: '" k "' no sostenida flag=" stylus.rButtonHeld " logico=" GetKeyState(k))   ; TEMP-DIAG
            return false
        }
    }
    return true
}

; Handler común de todos los hotkeys dinámicos.
_RemapDisparar(idEv, tecla, held, *) {
    p := "?"   ; TEMP-DIAG
    try p := GetKeyState(tecla, "P")
    _RDiag("DISPARO2 " idEv " P=" p " dt=" A_TimeSincePriorHotkey)
    try FileAppend(A_Now " DISPARO " idEv " tecla=" tecla " held=" held.Length " pausado=" _PtsEvPausado(idEv) "`n", A_ScriptDir "\logs\remap_diag.log") ; TEMP-DIAG
    if (stylus.rButtonHeld || GetKeyState("RButton"))
        stylus.comboUsado := true
    if _PtsEvPausado(idEv) {
        ; Pausado: la tecla conserva su función nativa. {Blind} respeta los modificadores físicos.
        ; El hotkey usa "$" (hook), así que este Send no reentra.
        _ModToggleReset(idEv)
        try SendInput("{Blind}{" tecla "}")
        return
    }
    for k in held {
        if (StrLower(k) = "rbutton")
            try stylus.comboUsado := true
    }
    for k in held {
        if (StrLower(k) = "rbutton")
            continue   ; combo nativo ~RButton &: no soltar el botón del lápiz (como el legado)
        SendInput("{" k " up}")
    }
    _FlushPendentes()   ; los despachadores originales vaciaban primero los pendientes (Q a 50 ms, Alt+S/A)
    if _ModActivo("toggle", idEv) {
        r := _ModToggle(idEv)
        KeyWait(tecla, "T10")   ; el auto-repeat no debe alternar A/B
        return r
    }
    atajo := IniRead(_PosGuiIniPath(), "Remapeos", "atajo_" idEv, "")
    if _ModActivo("quick", idEv)
        return _ModQuick(idEv, tecla, atajo)
    r := _ModEnviar(atajo)
    try _AvisoEvento(idEv)
    return r
}

_RemapDescargarHotkeys() {
    global _RemapRegistrados
    if (!IsSet(_RemapRegistrados) || !IsObject(_RemapRegistrados)) {
        _RemapRegistrados := []
        return
    }
    for r in _RemapRegistrados {
        try {
            HotIf(r.ctx)
            Hotkey(r.hk, "Off")
        }
    }
    HotIf()
    _RemapRegistrados := []
}

; Devuelve true solo si el texto parece un hotkey real de AHK (no una etiqueta de UI).
_RemapEsHotkeyReal(txt) {
    t := Trim(txt)
    if (t = "")
        return false
    ; Superíndices / subíndices decorativos (E², W², ³, ¹, ⁰-⁹, ₀-₉)
    if RegExMatch(t, "[\x{00B2}\x{00B3}\x{00B9}\x{2070}-\x{209F}]")
        return false
    ; Separadores de etiqueta de UI
    if InStr(t, "/") && !RegExMatch(t, "^/$")
        return false
    ; Compactar delimitadores válidos (+ y &) para comprobar si quedan espacios libres
    t_comp := RegExReplace(t, "\s*(\+|&)\s*", "$1")
    if InStr(t_comp, " ")
        return false
    ; Palabras de control de UI
    if RegExMatch(t, "i)píldora|pildora|slider|hover|menú|menu |panel")
        return false
    return true
}

; === INTERRUPTOR MAESTRO LEGADO ([Modo] legado=0|1; ausente = 1) ===
; static en vez de global: no depende del orden de auto-ejecución.
_LegadoEstado(nuevo?) {
    static on := true
    if IsSet(nuevo)
        on := !!nuevo
    return on
}
_LegadoActivo() => _LegadoEstado()
_LegadoRecargar() {
    try v := IniRead(_PosGuiIniPath(), "Modo", "legado", "1")
    catch
        v := "1"
    _LegadoEstado(Trim(v) != "0")
}

_RemapCargarHotkeys() {
    global _RemapRegistrados, _RButtonEvento
    if (!IsSet(_RemapRegistrados) || !IsObject(_RemapRegistrados))
        _RemapRegistrados := []
    _RemapDescargarHotkeys()
    _RButtonEvento := ""
    _LegadoRecargar()
    _ModCfgInvalidar()
    ini := _PosGuiIniPath()
    try sec := IniRead(ini, "Remapeos")
    catch
        return
    ids := Map()
    for linea in StrSplit(sec, "`n", "`r") {
        if RegExMatch(linea, "^(?:atajo|remap)_([^=]+)=", &m)
            ids[m[1]] := true
    }
    for idEv in ids {
        if (IniRead(ini, "EventosEliminados", idEv, "") = "1")   ; borrado en el Calibrador: sin hotkey
            continue
        remap := Trim(IniRead(ini, "Remapeos", "remap_" idEv, ""))
        atajo := Trim(IniRead(ini, "Remapeos", "atajo_" idEv, ""))
        if _ModActivo("quick", idEv) {
            bQuick := Trim(_ModAtajo("quick", "b", idEv, ""))
            aQuick := Trim(_ModAtajo("quick", "a", idEv, atajo))
            if (remap = "" || StrLower(remap) = StrLower(bQuick) || StrLower(remap) = StrLower(aQuick))
                disparo := (aQuick != "") ? aQuick : atajo
            else
                disparo := remap
        } else if _ModActivo("toggle", idEv) {
            bTog := Trim(_ModAtajo("toggle", "b", idEv, ""))
            aTog := Trim(_ModAtajo("toggle", "a", idEv, atajo))
            if (remap = "" || StrLower(remap) = StrLower(bTog) || StrLower(remap) = StrLower(aTog))
                disparo := (aTog != "") ? aTog : atajo
            else
                disparo := remap
        } else {
            disparo := (remap != "" && StrLower(remap) != "off") ? remap : atajo
        }
        if (disparo != "" && !_RemapEsHotkeyReal(disparo))
            continue
        n := _RemapNormalizar(disparo)
        if !IsObject(n)
            continue
        if (StrLower(n.principal) = "rbutton" && n.held.Length = 0) {
            _RButtonEvento := idEv   ; el RButton estático despacha en 'up'; el dinámico quedaría tapado
            continue
        }
        hk := n.hk
        if (n.held.Length = 1 && n.mods = "" && StrLower(n.held[1]) = "rbutton") {
            ; Combo de stylus: prefijo nativo con paso (misma semántica que el legado)
            hk := "~RButton & " n.principal
            ctx := _RemapCtxNativo()
        } else
            ctx := _RemapCtx(n.held)
        cb := _RemapDisparar.Bind(idEv, n.principal, n.held)
        try {
            HotIf(ctx)
            Hotkey(hk, cb, "On")
            _RemapRegistrados.Push({hk: hk, ctx: ctx})
            try FileAppend(A_Now " REG " idEv " hk=" hk "`n", A_ScriptDir "\logs\remap_diag.log") ; TEMP-DIAG
        } catch {
            static _ultHudInv := 0
            if (A_TickCount - _ultHudInv > 3000) {
                _ultHudInv := A_TickCount
                MostrarHUD("⚠️ Hotkey inválido '" disparo "' (" idEv ")", "FF3366", 1500)
            }
        }
    }
    HotIf()
}

global _PosGuiMuteTick := 0
_PosGuiMutearVigilante(ms := 1500) {
    global _PosGuiMuteTick
    _PosGuiMuteTick := A_TickCount + ms
}

; Vigilante: carga inicial + recarga en caliente cuando cambia el INI.
_RemapVigilarIni() {
    global _PosGuiMuteTick
    static ultimo := ""
    try m := FileGetTime(_PosGuiIniPath(), "M")
    catch
        return
    if (IsSet(_PosGuiMuteTick) && A_TickCount < _PosGuiMuteTick) {
        ultimo := m
        return
    }
    if (m != ultimo) {
        ultimo := m
        _CompInvalidar()          ; quick_a/b/ms, toggle, etc. se releen del INI
        _RemapCargarHotkeys()
    }
}

#HotIf
^!b:: LanzarBriefing()

EsEditorTexto() => WinActive("ahk_exe notepad++.exe") || WinActive("ahk_exe notepad.exe")

; ── Entorno CSP ampliado (CSP + Companion Python + GUIs AHK flotantes registradas) ──
EsCspDirecto() => WinActive("ahk_exe CLIPStudioPaint.exe")

EntornoMapa() {
    static m := Map()
    return m
}
EntornoRegistrar(hwnd) {
    if hwnd
        EntornoMapa()[hwnd] := true
}
_CspFoco() {
    SetWinDelay(-1)     ; solo afecta a este hilo; evita los 100 ms por defecto
    WinActivate("ahk_exe CLIPStudioPaint.exe")
}

; Garantiza CSP en primer plano ANTES de enviar teclas. true si CSP quedó activo.
_AsegurarCSP(timeoutS := 0.12) {
    if WinActive("ahk_exe CLIPStudioPaint.exe")
        return true
    _CspFoco()
    return (WinWaitActive("ahk_exe CLIPStudioPaint.exe", , timeoutS) != 0)
}

; Inicio común de todos los combos ~RButton & <tecla>
_ComboInicio() {
    stylus.comboUsado := true
    if !EsCspDirecto()
        _CspFoco()
    return true
}
_EntornoGuiAHK(hwnd) {
    if !hwnd
        return false
    try {
        class := WinGetClass("ahk_id " hwnd)
        return (class ~= "AutoHotkey") ; true for AHK GUI windows
    } catch {
        return false
    }
}

_RatonSobreCalibrador() {
    global ptsEd
    if !IsSet(ptsEd) || !IsObject(ptsEd) || !ptsEd.HasProp("g")
        return false
    try {
        MouseGetPos(,, &hw)
        if !hw
            return false
        calHwnd := ptsEd.g.Hwnd
        if (DllCall("user32\GetAncestor", "ptr", hw, "uint", 2, "ptr") = calHwnd)   ; GA_ROOT
            return true
        ; Menú contextual abierto desde el Calibrador (clase #32768)
        if (WinGetClass("ahk_id " hw) = "#32768")
            return (DllCall("user32\GetForegroundWindow", "ptr") = calHwnd)
    }
    return false
}

EntornoQuitar(hwnd) {
    m := EntornoMapa()
    if m.Has(hwnd)
        m.Delete(hwnd)
}

_EntornoPidCache() {
    static m := Map()
    return m
}

; Resuelve en un timer (no bloquea el hook) si un PID es el Companion de Python.
_EntornoResolverPid(pid) {
    ok := false
    try {
        for proc in ComObjGet("winmgmts:").ExecQuery("SELECT CommandLine FROM Win32_Process WHERE ProcessId=" pid) {
            if InStr(String(proc.CommandLine), "xppen_calibrador")
                ok := true
        }
    }
    _EntornoPidCache()[pid] := ok
    OutputDebug("[ENTORNO] pid " pid " companion=" ok)
}

_EntornoEsPython(hwnd, pid) {
    if !pid
        return false
    cache := _EntornoPidCache()
    if cache.Has(pid)
        return cache[pid]
    cache[pid] := false          ; evita relanzar mientras se resuelve
    nombre := ""
    try nombre := WinGetProcessName("ahk_id " hwnd)
    if (nombre = "python.exe" || nombre = "pythonw.exe")
        SetTimer(_EntornoResolverPid.Bind(pid), -1)
    return false
}

; Companion Python/Tk: 100 % síncrono (clase + proceso). Sin WMI, sin timers, sin caché.
EsCompanionTk(hwnd := 0) {
    static CLASE_TK := "i)^Tk"
    static PROC_PY  := "i)^(pythonw?|py|xppen_calibrador)\.exe$"
    static ultimo   := 0
    if !hwnd
        hwnd := DllCall("GetForegroundWindow", "ptr")
    if !hwnd
        return false
    ok := false
    try {
        if !(WinGetClass("ahk_id " hwnd) ~= CLASE_TK)
            return false
        ok := (WinGetProcessName("ahk_id " hwnd) ~= PROC_PY) ? true : false
    } catch {
        return false
    }
    if (ok && hwnd != ultimo) {
        ultimo := hwnd
        OutputDebug("[ENTORNO] companion Tk hwnd=" hwnd)
    }
    return ok
}

EsEntornoCSP() {
    global CALPY_PID
    if WinActive("ahk_exe CLIPStudioPaint.exe")
        return true
    hwnd := DllCall("GetForegroundWindow", "ptr")
    if !hwnd
        return false
    if EntornoMapa().Has(hwnd)
        return true
    if _EntornoGuiAHK(hwnd)
        return true
    pid := 0
    DllCall("GetWindowThreadProcessId", "ptr", hwnd, "uint*", &pid)
    if (IsSet(CALPY_PID) && CALPY_PID && pid = CALPY_PID)
        return true
    return EsCompanionTk(hwnd)
}
#HotIf EsEditorTexto()
^s:: {
    SendInput("^s")
    Sleep(200)
    Reload()
}
^g:: {
    if !(WinActive("ahk_exe notepad++.exe") || WinActive("ahk_exe notepad.exe"))
        return
    ts := FormatTime(,"yyyy-MM-dd_HH-mm-ss")
    ; El script vive en <repo>\ClipStudioPaint _ Autohotkeys\: el repo es el padre.
    repoPath := RegExReplace(A_ScriptDir,"\\[^\\]+$")
    cmd := 'git -C "' repoPath '" add -A && git -C "' repoPath '" commit -m "auto_' ts '" && git -C "' repoPath '" push'
    Run('cmd /k "' cmd ' && timeout /t 3 && exit"',,"")
    SetTimer(_CheckGitDone,-5000)
}
#HotIf
#SuspendExempt
; Control de Modo Escritura con tecla ` (o sc029):
; - Si ya está activo: pulsar ` (o Pause) SALE de inmediato.
; - Si está inactivo:
;     * 1 pulsación simple: Modo Escritura Temporal (Auto-salida tras 5s sin teclear).
;     * Doble pulsación rápida (``): Modo Escritura Anclado (Fijo, sin timer de inactividad).
; Pause alterna siempre y libera modificadores.
$`::
$sc029:: {
    global sys
    if (sys.modoEscritura) {
        _EscrituraSet(false)
        return
    }
    ; Detectar si hay un segundo toque en menos de 300 ms (doble pulsación)
    if (KeyWait(LTrim(A_ThisHotkey, "$~*"), "T0.28") && KeyWait(LTrim(A_ThisHotkey, "$~*"), "D T0.28")) {
        try KeyWait(LTrim(A_ThisHotkey, "$~*"))
        _EscrituraSet(true, false) ; Fijo / Anclado
    } else {
        _EscrituraSet(true, true)  ; Temporal (5 seg inactividad)
    }
}

Pause:: {
    _LiberarModificadores()
    _EscrituraSet(!sys.modoEscritura, false)
}
#SuspendExempt False

_EscrituraSet(on, conTimer := false) {
    global sys, shiftSostenido
    if (on = sys.modoEscritura)
        return
    sys.modoEscritura := on
    if (on) {
        if (shiftSostenido.activo)   ; no entrar a escribir con Shift clavado
            ShiftAnclado_Toggle()
        Suspend(1)
        if (conTimer) {
            SetTimer(_EscrituraInactividadCheck, 350)
            MostrarIndicador("🟡📝 MODO ESCRITURA (3.5s auto) — `` o Pause = salir 📝🟡")
        } else {
            SetTimer(_EscrituraInactividadCheck, 0)
            MostrarIndicador("🔴📝 MODO ESCRITURA ANCLADO — `` o Pause = salir 📝🔴")
        }
    } else {
        SetTimer(_EscrituraInactividadCheck, 0)
        Suspend(0)
        MostrarIndicador("🟢✅ MODO AHK ACTIVO — hotkeys habilitadas ✅🟢")
    }
}

_EscrituraInactividadCheck() {
    global sys
    if (!sys.modoEscritura) {
        SetTimer(_EscrituraInactividadCheck, 0)
        return
    }
    ; Si el usuario pasa >= 3.5 segundos sin tocar el teclado, auto-salir
    if (A_TimeIdleKeyboard >= 3500) {
        _EscrituraSet(false)
        MostrarHUD("⏱️ RETORNO A MODO DIBUJO", "00E5FF", 1800)
    }
}

#SuspendExempt
~*LWin::Send("{Blind}{vkE8}")
~*RWin::Send("{Blind}{vkE8}")
#SuspendExempt False

; === INFRA STYLUS: RButton universal (independiente del legado) ===
#HotIf CspLibre()
RButton:: {
    _RDiag("RB down csp=" WinActive("ahk_exe CLIPStudioPaint.exe") " arm=" Cap_Armado())
    stylus.rButtonHeld := true
    stylus.comboUsado := false
    stylus.upSinteticoTick := 0
}
RButton up:: {
    _RDiag("RB up ctx held=" stylus.rButtonHeld " combo=" stylus.comboUsado)
    elapsed := (stylus.upSinteticoTick > 0) ? (A_TickCount - stylus.upSinteticoTick) : 9999
    if (elapsed < UP_SINTETICO_MS) {
        stylus.rButtonHeld := true
        stylus.upSinteticoTick := 0
        return
    }
    stylus.rButtonHeld := false
    if (!stylus.comboUsado) {
        if (_RButtonEvento != "")
            _RemapDisparar(_RButtonEvento, "RButton", [])
        else
            SendInput("{RButton}")   ; cuentagotas al soltar en CSP
    }
}
Space & RButton:: {
    stylus.comboUsado := true
    _InvSeleccionConGUI()
}
#HotIf
~RButton up:: {
    if (stylus.rButtonHeld && !CspLibre()
        && (stylus.upSinteticoTick = 0 || A_TickCount - stylus.upSinteticoTick >= UP_SINTETICO_MS)) {
        _RDiag("RB up FUERA de contexto: reset rButtonHeld")
        stylus.rButtonHeld := false
        stylus.comboUsado := false
    }
}
#HotIf CspLibre()
Numpad0:: {
    hcOn := _ToggleHistorialColor()
    ActualizarHCGUI()
    MostrarHUD(hcOn ? "🟢 DYNAMIC HISTORY" : "🔒 HISTORY LOCKED",hcOn ? "00E5FF" : "FF6B00",5000)
}
_ToggleHistorialColor() {
    hist.modo := (hist.modo = 1) ? 2 : 1
    if (hist.modo = 2 && hist.abierto) {
        hist.abierto := false
        Send("{Numpad9}")
    }
    return (hist.modo = 1)
}
^s:: {
    SendInput("^s")
    _VigilarGuardado()
}

; ── Telemetría de guardado .clip: espera a que desaparezca el "*" del título ──
_VigilarGuardado() {
    global _svT0, _svVisto
    _svT0 := A_TickCount
    _svVisto := false
    SetTimer(_TickGuardado, 30)          ; reiniciar si se pulsa Ctrl+S de nuevo
}
_TickGuardado() {
    global _svT0, _svVisto
    t := WinExist("ahk_exe CLIPStudioPaint.exe")
        ? WinGetTitle("ahk_exe CLIPStudioPaint.exe") : ""
    dirty := InStr(t, "*") > 0
    if (dirty)
        _svVisto := true
    elapsed := A_TickCount - _svT0
    ; Guardado terminado: el asterisco se vio y ya no está
    ; (o no había cambios pendientes: tras 350 ms de gracia sin "*" el archivo ya está en disco)
    if ((_svVisto && !dirty) || (!_svVisto && !dirty && elapsed > 350)) {
        SetTimer(_TickGuardado, 0)
        _SonarUI("guardar")
        MostrarHUD("💾 GUARDADO Y MODIFICADO","44DD88",800)
        return
    }
    if (elapsed > 15000)                 ; timeout de seguridad: cancelado o CSP bloqueado
        SetTimer(_TickGuardado, 0)
}
~!b:: {
    elapsedB := (stylus.bSinteticoTick > 0) ? (A_TickCount - stylus.bSinteticoTick) : 9999
    if (elapsedB < UP_SINTETICO_MS) {
        stylus.bSinteticoTick := 0
        return
    }
    if (stylus.smearSend)
        return
    stylus.altActive := true
}
~!b up:: {
    elapsedB := (stylus.bSinteticoTick > 0) ? (A_TickCount - stylus.bSinteticoTick) : 9999
    if (elapsedB < UP_SINTETICO_MS) {
        stylus.bSinteticoTick := 0
        return
    }
    Send("{Alt up}")
    stylus.altActive := false
    if (stylus.smearSend) {
        stylus.smearSend := false
        SendInput("b")
        MostrarHUD("SMEAR","AA44FF",950)
    }
}
; Tecla huérfana "c" eliminada (alpha transparente pasa a $k, ver más abajo).
; El gesto Space + RButton conserva la inversión de selección.
_InvSeleccionConGUI() {
    if (sel.estadoC = 0) {
        MostrarMiniTexto("🔄 INV. ÁREA SELECC.","FF6F61",900)
        _SonarUI("seleccion")
        sel.estadoC := 1
        SetTimer(__ResetEstadoC,-2000)
    } else {
        MostrarMiniTexto("🔁 INV. ÁREA SELECC.","32CD32",900)
        sel.estadoC := 0
        SetTimer(__ResetEstadoC,0)
    }
    Send("c")
}
#HotIf CspLibre() && _LegadoActivo()
x:: {
    if stylus.altActive
        return
    if (sel.sRapido) {
        sel.sRapido := false
        MostrarMiniTexto("❌ DESELECCIÓN","C0392B",700)
        Send("x")
        sel.estado := 1
        return
    }
    if (sel.estado = 0) {
        MostrarMiniTexto("❌ DESELECCIÓN","C0392B",700)
        Send("x")
        sel.estado := 1
    } else {
        MostrarMiniTexto("✅ RESELECCIÓN","27AE60",1200)
        Send("{F10}")
        sel.estado := 0
    }
}
#HotIf CspLibre() && _LegadoActivo()
$^z:: _DeshacerRehacer()
$^y:: {
    SendInput("^y")
    ToolTipCS("🟢 REHACER",600)
    _RachaConteo("redo")
    _HapticoRacha("redo")
}
#HotIf CspLibre()
_MaskRButton() {
    stylus.comboUsado := true
    if (stylus.botonSostenido)
        return
    stylus.botonSostenido := true
    Send("!m")
    MostrarHUD("MASK (ALT+M)","00E5FF",900)
}
_RachaConteo(clave := "") {
    static n := 0, act := ""
    if (clave = "") {                                  ; vencimiento del timer: fin de racha
        if (n >= 2)
            ToolTipCS((act = "redo" ? "🟢 REHACER ×" : "🔴 DESHACER ×") n, 1200)
        n := 0, act := ""
        return
    }
    if (act != "" && act != clave)                     ; cambio Undo<->Redo: cierra la racha anterior
        _RachaConteo()
    act := clave
    n += 1
    SetTimer(_RachaConteo, -500)                       ; se reinicia con cada pulsación
}

_DeshacerRehacer() {
    static ultUndo := 0, ultRedo := 0
    ahora := A_TickCount
    if (stylus.rButtonHeld || stylus.altActive) {
        stylus.comboUsado := true
        if (!stylus.botonSostenido) {
            stylus.botonSostenido := true
            if (stylus.rButtonHeld) {
                stylus.upSinteticoTick := A_TickCount
                MouseGetPos(&origX,&origY)
                MouseMove(PUNTOS[29][1],PUNTOS[29][2],0)
                SendInput("{RButton up}")
                SendInput("^y")
                MouseMove(origX,origY,0)
            } else {
                SendInput("^y")
            }
        } else {
            SendInput("^y")
        }
        if (ahora - ultRedo > 120) {
            ToolTipCS("🟢 REHACER",600)
            ultRedo := ahora
        }
        _RachaConteo("redo")
        _HapticoRacha("redo")
    } else {
        SendInput("^z")
        if (ahora - ultUndo > 120) {
            ToolTipCS("🔴 DESHACER",300)
            ultUndo := ahora
        }
        _RachaConteo("undo")
        _HapticoRacha("undo")
    }
}
#HotIf CspLibre() && _LegadoActivo()
$^z up:: stylus.botonSostenido := false
#HotIf CspLibre() && _LegadoActivo()
!z:: {
    SendInput("^c")
    _SonarUI("copiar")
    ToolTipCS("📋 COPIAR",600)
}
!^z:: {
    stylus.botonSostenido := true
    SendInput("^y")
    ToolTipCS("🟢 REHACER",600)
    _RachaConteo("redo")
    _HapticoRacha("redo")
}
!^z up:: stylus.botonSostenido := false
#HotIf !Cap_Armado() && (IsSet(stylus) && stylus.altActive) && !WinActive("ahk_exe PureRef.exe") && _LegadoActivo()
z:: {
    SendInput("^c")
    _SonarUI("copiar")
    ToolTipCS("📋 COPIAR",600)
}
q:: {
    Send("y")
    MostrarBadgeCombo("ALT + Q","SOFT BRUSH","FF6B00",2200)
}
w:: {
    EnviarMenor()
    MostrarBadgeCombo("ALT + W","★ OPC PRESSURE 2","00E5FF",2200)
}
-:: _CicloO()
e:: {
    MostrarHUD("ALL LAYERS ERASER","FF4444",800)   ; solo visual
    Send("{F5}")
}
x:: {
    if (AltB_a_state.lastPress = 1) {
        AltB_a_state.lastPress := 0
        SendEvent("p")
        MostrarHUD("SMUDGE  (P)","FF6B00",950)
    } else {
        AltB_a_state.lastPress := 1
        SendEvent("d")
        MostrarHUD("COLOR MIX  (D)","FF8C42",950)
    }
}
a:: {
    now := A_TickCount
    if (now - AltB_a_state.lastPress < 2400) {
        AltB_a_state.lastPress := 0
        Send("p")
        MostrarHUD("SMUDGE  (P)","FF6B00",950)
    } else {
        AltB_a_state.lastPress := now
        Send("d")
        MostrarHUD("COLOR MIX  (D)","FF8C42",950)
    }
}
s:: {
    now := A_TickCount
    if (now - AltB_s_state.lastPress < 2400) {
        AltB_s_state.lastPress := 0
        SendInput("{F7}")
        MostrarHUD("ALL LAYERS (2)","FF6B00",3140)
    } else {
        AltB_s_state.lastPress := now
        SendInput("{Blind}a")
        MostrarHUD("LAYER CURRENT (1)","00E5FF",950)
    }
}
f:: {
    if AltF_state.held
        return
    AltF_state.held := true
    now := A_TickCount
    if (now - AltF_state.lastPress < 2400) {
        AltF_state.lastPress := 0
        SendInput("{NumpadEnd}")
        MostrarHUD("SMEAR SOFT  (2)","FF6B00",950)
    } else {
        AltF_state.lastPress := now
        stylus.bSinteticoTick := A_TickCount
        SendInput("{Blind}{b up}{b down}")
        MostrarHUD("SMEAR  (1)","00E5FF",950)
    }
}
f up:: AltF_state.held := false
$!Space::
$Space:: {
    stylus.comboUsado := true
    SendInput("!g")
    MostrarHUD("FLIP HORIZONTAL","888888",700)
    _SonarUI("flip")
}
#HotIf
#HotIf CspLibre() && _LegadoActivo()
$a:: {
    _FlushPendentes()
    if stylus.altActive
        return
    now := A_TickCount
    if (now - A_state.lastPress < 2400) {
        A_state.lastPress := 0
        SendInput("{F7}")
        MostrarHUD("ALL LAYERS (2)","FF6B00",3140)
    } else {
        A_state.lastPress := now
        SendInput("{Blind}a")
        MostrarHUD("LAYER CURRENT (1)","00E5FF",950)
    }
}
#HotIf CspLibre() && _LegadoActivo()
~RButton & a:: {
    if !_ComboInicio()
        return
    EnviarNtilde()
    MostrarHUD("REFERENCE LAYER","AA44FF",1680)
}
#HotIf CspLibre() && _LegadoActivo()
$e:: {
    _FlushPendentes()
    global colorEstado
    now := A_TickCount
    if GetKeyState("Shift") {
        Send("e")
        return
    }
    ; Borrador suave (doble toque) desactivado en Calibrador/INI: solo ERASER
    if (!_ModActivoCab("quick", "borrador_suave")) {
        E.last := now
        if (colorEstado = 2) {
            Send("k")
            colorEstado := 0
        }
        Send("e")
        Stab_ResetUniversal("e")
        MostrarToolTipE("ERASER  (1)")
        return
    }
    if (now - E.last < 300) {
        E.last := 0
        SendInput("{e up}")
        if (colorEstado = 2) {
            Send("k")
            colorEstado := 0
        }
        Send("l")
        Stab_ResetUniversal("l")
        MostrarToolTipE("SOFT ERASER  (2)")
        return
    }
    E.last := now
    if (colorEstado = 2) {
        Send("k")
        colorEstado := 0
    }
    Send("e")
    Stab_ResetUniversal("e")
    MostrarToolTipE("ERASER  (1)")
}
#HotIf CspLibre() && _LegadoActivo()
~RButton & e:: {
    if !_ComboInicio()
        return
    Send("{F12}")
    _SonarUI("borrador")
    MostrarHUD("ERASER LAZO","FF4444",1200)
}
#HotIf CspLibre() && _LegadoActivo()
^e:: {
    MostrarHUD("ALL LAYERS ERASER","FF4444",800)
    Send("{F5}")
}
!e:: {
    MostrarHUD("ALL LAYERS ERASER","FF4444",800)
    Send("{F5}")
}
!q:: {
    Send("y")
    MostrarBadgeCombo("ALT + Q","SOFT BRUSH","FF6B00",2200)
}
#HotIf CspLibre()
~LAlt & 1::
~RAlt & 1:: {
    opacidad.nivel := Min(opacidad.nivel + 10,100)
    _EnviarOpacidad()
}
~LAlt & 2::
~RAlt & 2:: {
    opacidad.nivel := Max(opacidad.nivel - 10,10)
    _EnviarOpacidad()
}
#HotIf CspLibre() && _LegadoActivo()
!Home:: {
    Send("{PageDown}")
    MostrarHUD("ACCESO RÁPIDO","AA8844",800)
}
!-:: _CicloO()
#HotIf CspLibre() && _LegadoActivo()
$w:: {
    if (GetKeyState("Alt") || stylus.altActive) {
        EnviarMenor()
        MostrarBadgeCombo("ALT + W","★ OPC PRESSURE 2","00E5FF",2200)
        return
    }
    _FlushPendentes()
    global colorEstado
    Stab_ResetUniversal("w")
    now := A_TickCount
    ; Aerógrafo alpha (doble toque) desactivable en Calibrador/INI con quick=0
    if (!_ModActivoCab("quick", "aerografo") && !_ModActivoCab("quick", "aerografo_alpha")) {
        W.last := now
        SendInput("{Blind}w")
        _SonarUI("aerografo")
        MostrarMiniTexto(colorEstado = 2 ? "⚪ AERÓGRAFO ALPHA" : "💨 AERÓGRAFO",colorEstado = 2 ? "1C6EA4" : "1A1A2E",1200)
        return
    }
    if (now - W.last < 300) {
        W.last := 0
        if (colorEstado = 2) {
            SendInput("k")
            colorEstado := 0
            SendInput("{Blind}w")
            _SonarUI("aerografo")
            MostrarMiniTexto("💨 AERÓGRAFO","1A1A2E",1200)
        } else {
            if (colorEstado = 1)
                SendInput("^2")
            SendInput("k")
            colorEstado := 2
            SendInput("{Blind}w")
            _SonarUI("aerografo")
            MostrarMiniTexto("⚪ AERÓGRAFO ALPHA","1C6EA4",1200)
        }
        return
    }
    W.last := now
    SendInput("{Blind}w")
    _SonarUI("aerografo")
    MostrarMiniTexto(colorEstado = 2 ? "⚪ AERÓGRAFO ALPHA" : "💨 AERÓGRAFO",colorEstado = 2 ? "1C6EA4" : "1A1A2E",1200)
}
$z:: {
    _FlushPendentes()
    now := A_TickCount
    if (Z.estaAbajo) {
        Z.last := now
        return
    }
    Z.estaAbajo := true
    ; Rotación de lienzo (Z doble -> R) desactivada en Calibrador/INI: solo Zoom
    if (!_ModActivoCab("quick", "rotar_lienzo")) {
        Z.last := now
        Z.timerRunning := 1
        SendInput("{Blind}z")
        if !(IsSet(LienzoHUD_Mostrar) && LienzoHUD_Mostrar("z", "z", 450))
            MostrarToolTipZ("🔍 Z",800)
        return
    }
    if (now - Z.last < 300) {
        Z.last := 0
        Z.timerRunning := 0
        SendInput("{z up}")
        SendInput("r")
        if !(IsSet(LienzoHUD_Mostrar) && LienzoHUD_Mostrar("r", "", 800))
            MostrarToolTipZ("✋ R",800)
        return
    }
    Z.last := now
    Z.timerRunning := 1
    SendInput("{Blind}z")
    if !(IsSet(LienzoHUD_Mostrar) && LienzoHUD_Mostrar("z", "z", 450))
        MostrarToolTipZ("🔍 Z",800)
}

$z up:: {
    Z.estaAbajo := false
}
#HotIf CspLibre()
~r:: SetTimer(LienzoHUD_ChequeoR, -140)
#HotIf CspLibre() && _LegadoActivo()
$q:: {
    if (GetKeyState("Alt") || stylus.altActive) {
        Send("y")
        MostrarBadgeCombo("ALT + Q","SOFT BRUSH","FF6B00",2200)
        return
    }
    now := A_TickCount
    ; Prioridad al botón del lápiz: toggle Stab Normal inmediato, sin pasar por la ventana de doble-toque
    if (stylus.rButtonHeld || GetKeyState("RButton")) {
        stylus.comboUsado := true              ; evita que RButton up emita un clic derecho
        AlternarEstabilizacion()
        return
    }
    ; Doble toque (color secundario) desactivable en Calibrador/INI con quick=0
    if (!_ModActivoCab("quick", "pluma") && !_ModActivoCab("quick", "color_primario")) {
        __Q_SEND_NORMAL()
        return
    }
    if (now - Q.last < 300) {
        Q.last := 0
        Q.pendiente := false
        SetTimer(__Q_SEND_NORMAL,0)
        global colorEstado
        if (colorEstado = 2) {
            Send("k")
            colorEstado := 0
        }
        SendInput("^2")
        if (colorEstado = 0) {
            colorEstado := 1
            _SonarUI("color_secundario")
            MostrarMiniTextoOscuro("🟡 COLOR SECUNDARIO","51D67B",1200)
        } else {
            colorEstado := 0
            _SonarUI("color_primario")
            MostrarMiniTexto("🔵 COLOR PRIMARIO", _Tema("color", "color_primario", "00E5FF"), 1200)
        }
        return
    }
    Q.last := now
    Q.pendiente := true
    SetTimer(__Q_SEND_NORMAL,-50)
}
#HotIf CspLibre()
_FlushPendentes() {
    if Q.pendiente {
        SetTimer(__Q_SEND_NORMAL,0)
        Q.pendiente := false
        Q.last := 0
        __Q_SEND_NORMAL()
    }
    if AltB_a_state.timerRunning {
        SetTimer(__AltX_SEND_NORMAL,0)
        __AltX_SEND_NORMAL()
    }
    if AltB_s_state.timerRunning {
        SetTimer(__AltS_SEND_NORMAL,0)
        __AltS_SEND_NORMAL()
    }
}
_ToggleLayerVis() {
    SendEvent("{Alt up}{Shift down}d{Shift up}")
    wasVisible := N6.layerVis
    N6.layerVis := !N6.layerVis
    if (wasVisible)
        _AvisoEvento("capa_ocultar", "🚫 HIDE LAYER", "SPACE + E", "FF4444", 0)
    else
        _AvisoEvento("capa_mostrar", "👁 SHOW LAYER", "SPACE + E", "44DD88", 0)
}
#HotIf CspLibre() && _LegadoActivo()
+q:: {
    Send("y")
    MostrarHUD("SOFT (Y)","00E5FF",800)
}
!j:: {
    hoverOn := _ToggleHoverPaneles()
    ActualizarDsGUI()
    ActualizarCcGUI()
    ActualizarArGUI()
    if (hoverOn)
        MostrarTooltipToggle("HOVER ACTIVO","▶","verde")
    else
        MostrarTooltipToggle("HOVER PAUSADO","⏸","rojo")
}
#HotIf CspLibre()
_FadeAlpha(hwnd,hasta,pasos := 6,delayMs := 0) {
    global g_sweepActivo
    if g_sweepActivo {
        try WinSetTransparent(hasta,"ahk_id " hwnd)
        return
    }
    if !HasProp(floatGui,"fade")
        floatGui.fade := Map()
    key := "" hwnd, actual := ""
    if floatGui.fade.Has(key) {
        SetTimer(floatGui.fade[key].fn,0)
        floatGui.fade.Delete(key)
    }
    try actual := WinGetTransparent("ahk_id " hwnd)
    if (actual = "" || !IsNumber(actual))
        actual := hasta
    if (actual = hasta)
        return
    tot := _Tema("motion","fast","60")
    tot := (IsInteger(tot) && Integer(tot) > 0) ? Integer(tot) : 60
    pasos := Max(1,pasos)
    ; Min(12,...) = contrato con los llamadores (rearman el bucle a 80 ms): NO quitar
    ms := (delayMs > 0) ? delayMs : Max(1,Min(12,Round(tot / pasos)))
    st := {desde: actual, hasta: hasta, total: pasos, i: 0, ms: ms, lin: (_Tema("motion","easing","out-cubic") = "linear"), fn: _FadePaso.Bind(key)}
    floatGui.fade[key] := st
    SetTimer(st.fn,-ms)
}
_FadePaso(key) {
    if !floatGui.fade.Has(key)
        return
    st := floatGui.fade[key]
    st.i += 1
    t := st.i / st.total
    v := (st.i >= st.total) ? st.hasta : Round(st.desde + (st.hasta - st.desde) * (st.lin ? t : 1 - (1 - t) ** 3))
    try WinSetTransparent(Max(0,Min(255,v)),"ahk_id " key)
    if (st.i >= st.total)
        floatGui.fade.Delete(key)
    else
        SetTimer(st.fn,-st.ms)
}
_SetColorV(on) {
    colorV.hover := on
    colorV.dsVis := !on
    if (on)
        colorV.supresionHasta := A_TickCount + 400
    if (colorV.dsID && WinExist("ahk_id " colorV.dsID)) {
        SetTimer(LoopColorV,0)
        if (on) {
            _FadeAlpha(colorV.dsID,5)
            try WinSetExStyle("+0x20","ahk_id " colorV.dsID)
        } else {
            if IsObject(colorV.bDS)
                colorV.bDS.Hide()
            try WinSetExStyle("-0x20","ahk_id " colorV.dsID)
            _FadeAlpha(colorV.dsID,255)
        }
        SetTimer(LoopColorV,80)
    }
    return on
}
_SetColorCC(on) {
    colorCC.hover := on
    colorCC.dsVis := !on
    if (on)
        colorCC.supresionHasta := A_TickCount + 400
    if (colorCC.id && WinExist("ahk_id " colorCC.id)) {
        SetTimer(LoopColorCC,0)
        if (on) {
            _FadeAlpha(colorCC.id,5)
            try WinSetExStyle("+0x20","ahk_id " colorCC.id)
        } else {
            if IsObject(colorCC.bCC)
                colorCC.bCC.Hide()
            try WinSetExStyle("-0x20","ahk_id " colorCC.id)
            _FadeAlpha(colorCC.id,255)
        }
        SetTimer(LoopColorCC,80)
    }
    return on
}
_SetAR(on) {
    ar.hover := on
    ar.dsVis := !on
    if (ar.id && WinExist("ahk_id " ar.id)) {
        SetTimer(LoopAccesoRapido,0)
        if (on) {
            _FadeAlpha(ar.id,5)
            try WinSetExStyle("+0x20","ahk_id " ar.id)
        } else {
            if IsObject(ar.bAR)
                ar.bAR.Hide()
            try WinSetExStyle("-0x20","ahk_id " ar.id)
            _FadeAlpha(ar.id,255)
        }
        SetTimer(LoopAccesoRapido,80)
    }
    return on
}
_ToggleColorV() => _SetColorV(!colorV.hover)
_ToggleColorCC() => _SetColorCC(!colorCC.hover)
_ToggleAR() => _SetAR(!ar.hover)
_ToggleHoverPaneles() {
    target := !colorV.hover
    _SetColorV(target)
    _SetColorCC(target)
    _SetAR(target)
    return target
}
#HotIf CspLibre() && (IsSet(stylus) && stylus.altActive) && _LegadoActivo()
$!x:: {
    now := A_TickCount
    if (now - AltB_a_state.lastPress < 300) {
        SetTimer(__AltX_SEND_NORMAL,0)
        AltB_a_state.timerRunning := 0
        AltB_a_state.lastPress := 0
        SendEvent("{Alt up}p")
        _AltRestaurar(stylus.altActive)
        Stab_ResetUniversal("p")
        MostrarHUD("SMUDGE  (P)","FF6B00",950)
        return
    }
    AltB_a_state.lastPress := now
    AltB_a_state.timerRunning := 1
    SetTimer(__AltX_SEND_NORMAL,-250)
}
#HotIf CspLibre()
__AltX_SEND_NORMAL() {
    if !AltB_a_state.timerRunning
        return
    AltB_a_state.timerRunning := 0
    seguiaSostenido := stylus.altActive
    SendEvent("{Alt up}d")
    _AltRestaurar(seguiaSostenido)
    Stab_ResetUniversal("d")
    MostrarHUD("COLOR MIX  (D)","FF8C42",950)
}
#HotIf CspLibre() && _LegadoActivo()
!s:: {
    if !stylus.altActive
        return
    now := A_TickCount
    if (now - AltB_s_state.lastPress < 300) {
        SetTimer(__AltS_SEND_NORMAL,0)
        AltB_s_state.timerRunning := 0
        AltB_s_state.lastPress := 0
        SendEvent("{Alt up}{F7}")
        _AltRestaurar(stylus.altActive)
        MostrarHUD("ALL LAYERS (2)","FF6B00",3140)
        return
    }
    AltB_s_state.lastPress := now
    AltB_s_state.timerRunning := 1
    SetTimer(__AltS_SEND_NORMAL,-250)
}
#HotIf CspLibre()
__AltS_SEND_NORMAL() {
    if !AltB_s_state.timerRunning
        return
    AltB_s_state.timerRunning := 0
    seguiaSostenido := stylus.altActive
    SendEvent("{Alt up}a")
    _AltRestaurar(seguiaSostenido)
    MostrarHUD("LAYER CURRENT (1)","00E5FF",950)
}
#HotIf CspLibre() && _LegadoActivo()
$s:: {
    if stylus.altActive
        return
    if GetKeyState("Alt","P")
        return
    _FlushPendentes()
    ahora := A_TickCount
    esRapido := (S.lastTick > 0 && ahora - S.lastTick < S_RAPIDO_MS)
    S.lastTick := esRapido ? 0 : ahora
    if (esRapido) {
        S.skipNext := true
        sel.sRapido := true
        MostrarMiniTexto("🟢 ÁREA CON COLOR","27AE60",1200)
        SendInput("^x")
        SendEvent("{F7}")
        Send("{Alt down}{x}{Alt up}")
        sel.guiActivo := true
        sel.estadoAltX := true
        SetTimer(ResetEstadoAltX,-3000)
        _SonarUI("lazo")
        return
    }
    if (GetKeyState("Space","P") || spc.selectArmed) {
        S.skipNext := true
        if (spc.selectArmed)
            SetTimer(_DesarmarSpaceSelect,-500)
        if (S.estadoCaracter = 0) {
            Send(",")
            MostrarTooltipToggle("AGREGAR A SELECCION","+","verde")
            S.estadoCaracter := 1
        } else {
            Send(".")
            MostrarTooltipToggle("ELIMINAR SELECCIÓN","–","rojo")
            S.estadoCaracter := 0
        }
        SetTimer(QuitarTooltipToggle,-1500)
        return
    }
    if S.skipNext {
        S.skipNext := false
        return
    }
    Send("s")
    Stab_ResetUniversal("s")
    SetTimer(() => MostrarHUD("LASSO","FF6B00",950),-1)
}
#HotIf CspLibre()
; Alpha transparente (CSP: applicationchangemaincolorandtransparent = K)
$k:: {
    global colorEstado
    _FlushPendentes()
    if (colorEstado = 2) {
        Send("k")
        colorEstado := 0
        _AvisoEvento("color_alpha", "⚪ ALPHA OFF", "COLOR PRIMARIO", "888888", 800)
    } else {
        if (colorEstado = 1)
            SendInput("^2")
        Send("k")
        colorEstado := 2
        _AvisoEvento("color_alpha", "⚪ ALPHA TRANSPARENTE", "COLOR SECUNDARIO → ALPHA", "1C6EA4", 800)
    }
}
$o:: _CicloO()
_CicloO() {
    O.ciclo := Mod(O.ciclo,3) + 1
    if (O.ciclo = 1) {
        Send("h")
        MostrarMiniTexto("🔍 BUSCAR CAPAS (1/3)","1A5276",1200)
    } else if (O.ciclo = 2) {
        SendInput("{Ctrl down}{Numpad1}{Ctrl up}")
        MostrarMiniTexto("🎨 COLOR CAPA (2/3)","6C3483",1200)
    } else {
        SendInput("{Ctrl down}{Numpad2}{Ctrl up}")
        MostrarMiniTexto("🗑 BORRAR COLOR CAPA (3/3)","424949",1200)
    }
}

; Contrato: paso 0 = cadena completa, 1 = buscar, 2 = cambiar color, 3 = borrar color.
; La cadena completa emite un solo HUD (macro_capas) al terminar.
MacroCapas_Ejecutar(paso := 0) {
    static titulos := Map(1, "🔍 BUSCAR CAPAS", 2, "🎨 COLOR CAPA", 3, "🗑 BORRAR COLOR CAPA")
    if (paso = 0) {
        MacroCapas_Paso(1)
        Sleep(140)
        MacroCapas_Paso(2)
        Sleep(140)
        MacroCapas_Paso(3)
        _AvisoEvento("macro_capas", "CICLO DE MACROS COMPLETO", "BUSCAR → COLOR → BORRAR COLOR", "AA44FF", 0)
        return
    }
    if !titulos.Has(paso)
        return
    MacroCapas_Paso(paso)
    _AvisoEvento("macro_capas", titulos[paso], "PASO " paso "/3", "AA44FF", 0)
}
MacroCapas_Paso(paso) {
    if (paso = 1)
        Send("h")
    else if (paso = 2)
        SendInput("{Ctrl down}{Numpad1}{Ctrl up}")
    else if (paso = 3)
        SendInput("{Ctrl down}{Numpad2}{Ctrl up}")
}
$Escape:: {
    if (O.ciclo != 0) {
        O.ciclo := 0
        MostrarMiniTexto("↺ CICLO O RESETADO","555555",900)
    }
    global colorEstado
    if (colorEstado = 2) {
        colorEstado := 0
        Send("k")
        MostrarMiniTexto("🎨 ALPHA RESETEADO","555555",900)
    }
    if (sel.guiActivo) {
        sel.guiActivo := false
        sel.estadoAltX := false
        sel.estado := 0
        Send("{Alt down}{x}{Alt up}")
        SetTimer(ResetEstadoAltX,0)
        MostrarMiniTexto("↩ SELECCIÓN CANCELADA","C0392B",700)
        Send("x")
        Send("{Escape}")
        return
    }
    Send("{Escape}")
}
#HotIf CspLibre() && _LegadoActivo()
+r:: {
    MostrarHUD("REFLEJAR HORIZONTAL","00E5FF",1500)
    Send("+r")
}
Tab::
+Escape::
F3:: AccionEnfoque()
~f:: {
}
#HotIf CspLibre()
; [DESACTIVADO] ~RButton & s retirado por solicitud: bloqueaba S (herramienta Lazo) del stylus.
#HotIf CspLibre() && _LegadoActivo()
~RButton & q:: {
    if !_ComboInicio()
        return
    Send("{F6}")
    MostrarBadgeCombo("RButton + Q","HARD BRUSH","FF6B00",2200)
}
#HotIf
#HotIf CspLibre()
; Shift sostenido: Space + -
#HotIf CspLibre() && _LegadoActivo()
~Space & -:: {
    if (!shiftSostenido.activo && !WinActive("ahk_exe CLIPStudioPaint.exe"))
        return   ; no anclar Shift fuera de CSP; sí permitir soltarlo
    _FlushPendentes()
    ShiftAnclado_Toggle()
}
#HotIf GetKeyState("Space") && CspLibre() && _LegadoActivo()
*e:: _SpaceE_Dispatch()
#HotIf CspLibre()

; Space+E: K7+K1 = Mostrar/Ocultar capa; K7+K3 (macro Shift+E del driver) = Shift anclado.
_SpaceE_Dispatch() {
    global shiftSostenido
    static tickUltimo := 0
    now := A_TickCount
    if (now - tickUltimo < 60)
        return
    tickUltimo := now
    _FlushPendentes()
    esMacro := shiftSostenido.activo ? InStr(A_PriorKey, "Shift") : GetKeyState("Shift")
    if (!esMacro) {
        _ToggleLayerVis()
        return
    }
    ShiftAnclado_Toggle()
    if (shiftSostenido.activo) {
        SetTimer(() => shiftSostenido.activo && !GetKeyState("LShift") && SendEvent("{LShift down}"), -60)
        SetTimer(() => shiftSostenido.activo && !GetKeyState("LShift") && SendEvent("{LShift down}"), -150)
    }
}

; Anclado de Shift — usado por los atajos y por los botones fijos de modificación.
ShiftAnclado_Toggle() {
    global shiftSostenido
    shiftSostenido.activo := !shiftSostenido.activo
    if (shiftSostenido.activo) {
        SendEvent("{LShift down}")
        _SonarUI("shift_on")
        _BadgeSFT(true)
        _HudSFTAnclado(true)
    } else {
        SendEvent("{LShift up}")
        _SonarUI("shift_off")
        _BadgeSFT(false)
        _AvisoCerrarBadge()
        _AvisoCerrarHUD()
        _AvisoEvento("shift_sostenido", "SHIFT LIBERADO", "SPACE + -", "888888", 1501)   ; 1501 evita el centinela 1500 de MostrarAvisoUI
    }
    return shiftSostenido.activo
}
; Apagado forzado (pérdida de foco, salida o botón fijo de modificación).
ShiftAnclado_Apagar(silencioso := false) {
    global shiftSostenido
    if !shiftSostenido.activo
        return false
    shiftSostenido.activo := false
    SendEvent("{LShift up}")
    if !silencioso
        _SonarUI("shift_off")
    _BadgeSFT(false)
    _AvisoCerrarBadge()
    _AvisoCerrarHUD()
    return true
}

; ── Micro-badge persistente "SFT" visible en la pantalla XP-Pen de dibujo ──
_BadgeSFT(on) {
    global _sftGui, AVISO_ESC
    if (!IsSet(_sftGui))
        _sftGui := 0
    if (!on) {
        _HudSFTAnclado(false)
        SetTimer(_BadgeSFTGuardia, 0)
        if (IsObject(_sftGui)) {
            try _sftGui.Destroy()
            _sftGui := 0
        }
        return
    }
    if (IsObject(_sftGui))
        return
    mon := ObtenerMonitorCSP()
    w := Round(90 * AVISO_ESC)
    h := Round(32 * AVISO_ESC)
    posX := mon.x + mon.w - w - 24
    posY := mon.y + mon.h - h - 44
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x80")
    g.BackColor := "12141A"
    g.MarginX := 0
    g.MarginY := 0
    WinSetTransparent(235, g)
    ; Acento izquierdo y base del estilo avanzado
    bLeft := g.Add("Progress", "x0 y0 w" Round(4 * AVISO_ESC) " h" h)
    bLeft.Opt("c00E5FF")
    bLeft.Value := 100
    bBot := g.Add("Progress", "x0 y" (h - Round(3 * AVISO_ESC)) " w" w " h" Round(3 * AVISO_ESC))
    bBot.Opt("c00E5FF")
    bBot.Value := 100
    lbl := g.Add("Text", "x" Round(8 * AVISO_ESC) " y0 w" (w - Round(12 * AVISO_ESC)) " h" h " c00E5FF Center +0x200 BackgroundTrans", "SFT  •  ON")
    lbl.SetFont("s" Max(7, Round(9 * AVISO_ESC)) " bold", "Segoe UI")
    g.Show("NoActivate x" posX " y" posY " w" w " h" h)
    _sftGui := g
    SetTimer(_BadgeSFTGuardia, 500)
}
_BadgeSFTGuardia() {                      ; red de seguridad si el Shift se libera por otra vía
    global _sftGui, shiftSostenido
    if (!IsSet(_sftGui))
        _sftGui := 0
    if (!IsSet(shiftSostenido) || !shiftSostenido.activo)
        _BadgeSFT(false)
    else
        _HudSFTReafirmar()
}

; ── HUD anclado de Shift Sostenido: ventana PROPIA y persistente ──
; Brackets a 90° con _DwmNoRedondear (sin recortes elípticos de Windows 11).
; Posición: _HudRangoEv("shift_sostenido") > rango de zona.
; No usa floatGui.badge, así que el watchdog de companion.ahk y los demás avisos no lo cierran.
_HudSFTAnclado(on) {
    global _sftHud, AVISO_ESC, PERFIL
    if (!IsSet(_sftHud))
        _sftHud := 0
    if (!on) {
        if (IsObject(_sftHud)) {
            try _DestruirGui(_sftHud)
            _sftHud := 0
        }
        return
    }
    if (IsObject(_sftHud))
        return
    c := HudConfigEvento("shift_sostenido")
    f := StrLower(String(c.formato))
    if (f = "desactivado" || f = "ninguno" || f = "off" || f = "sin gui" || f = "0")
        return
    zona := (c.zona = "alta") ? 1 : ((c.zona = "media") ? 2 : 3)

    textoPrincipal := "SHIFT SOSTENIDO"
    subtexto := "SPACE + -"
    try {
        txtCustom := IniRead(_PosGuiIniPath(), "HudTextos" PERFIL, "texto_shift_sostenido", "")
        if (txtCustom != "")
            textoPrincipal := Trim(RegExReplace(txtCustom, "\s*\(.*\)\s*$"))
    }

    ; Geometría: rango exclusivo del evento > rango de zona > posición calculada
    w := Round(240 * AVISO_ESC)
    h := Round(72  * AVISO_ESC)
    px := "", py := ""
    rgEv := _HudRangoEv("shift_sostenido")
    if (IsObject(rgEv) && IsInteger(rgEv.w) && IsInteger(rgEv.h) && rgEv.w >= 40 && rgEv.h >= 20) {
        w := Round(rgEv.w), h := Round(rgEv.h)
        px := Round(rgEv.x), py := Round(rgEv.y)
    } else {
        claveRango := (zona = 1) ? "HUD_Alta" : ((zona = 2) ? "HUD_Media" : "HUD_Baja")
        rg := ObtenerRango(claveRango)
        if (IsObject(rg) && IsInteger(rg.w) && IsInteger(rg.h) && rg.w >= 40 && rg.h >= 20) {
            w := Round(rg.w), h := Round(rg.h)
            px := Round(rg.x), py := Round(rg.y)
        }
    }
    if (px = "" || py = "") {
        p := _CalcularPosicionZona(zona, w, h)
        px := p.x, py := p.y
    }

    grande := (h >= 90)
    brazo := grande ? 16 : 10
    grosor := grande ? 3 : 2
    colorAcento := "00E5FF"

    g := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20 -DPIScale")
    g.BackColor := "12141A"
    g.MarginX := 0
    g.MarginY := 0
    if (IsSet(_DwmNoRedondear))
        _DwmNoRedondear(g.Hwnd)
    op := c.opacidad
    if (!IsNumber(op) || op = 0)
        op := 70
    alpha := (op <= 40) ? 102 : ((op <= 70) ? 178 : 255)
    WinSetTransparent(alpha, g)

    ; Esquinas luminosas a 90° (viewfinder brackets)
    xr := w - brazo, yb := h - brazo
    xr2 := w - grosor, yb2 := h - grosor
    cc := "Background" colorAcento
    g.Add("Text", Format("x0 y0 w{} h{} {}", brazo, grosor, cc))
    g.Add("Text", Format("x0 y0 w{} h{} {}", grosor, brazo, cc))
    g.Add("Text", Format("x{} y0 w{} h{} {}", xr, brazo, grosor, cc))
    g.Add("Text", Format("x{} y0 w{} h{} {}", xr2, grosor, brazo, cc))
    g.Add("Text", Format("x0 y{} w{} h{} {}", yb2, brazo, grosor, cc))
    g.Add("Text", Format("x0 y{} w{} h{} {}", yb, grosor, brazo, cc))
    g.Add("Text", Format("x{} y{} w{} h{} {}", xr, yb2, brazo, grosor, cc))
    g.Add("Text", Format("x{} y{} w{} h{} {}", xr2, yb, grosor, brazo, cc))
    mbw := Max(30, Round(w * 0.30))
    g.Add("Text", Format("x{} y{} w{} h3 {}", (w - mbw) // 2, h - 7, mbw, cc))

    tSize := Max(10, Min(36, Round(h * 0.16)))
    sSize := grande ? 10 : 8
    tAlto := tSize * 2
    tY := (h - tAlto) // 2 + 8
    ancho := Max(40, w - 24)
    g.SetFont("s" sSize " bold c9AA7C7", "Segoe UI")
    g.Add("Text", Format("x12 y{} w{} h18 Center BackgroundTrans +0x200 +0x4000", Max(4, tY - 18), ancho), subtexto)
    g.SetFont("s" tSize " bold cFFFFFF", "Segoe UI")
    g.Add("Text", Format("x12 y{} w{} h{} Center BackgroundTrans +0x200 +0x4000", tY, ancho, tAlto), textoPrincipal)

    _sftHud := g
    try g.Show(Format("x{} y{} w{} h{} NoActivate", px, py, w, h))
    if (IsSet(_DwmNoRedondear))
        _DwmNoRedondear(g.Hwnd)
    try WinSetRegion(Format("0-0 w{} h{}", w, h), g)
}
; Reafirma TOPMOST sin mover ni activar (CSP puede reclamar el z-order al recuperar foco)
_HudSFTReafirmar() {
    global _sftHud
    if (!IsSet(_sftHud) || !IsObject(_sftHud))
        return
    try DllCall("SetWindowPos", "Ptr", _sftHud.Hwnd, "Ptr", -1, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x0001 | 0x0002 | 0x0010)
}
#HotIf CspLibre() && _LegadoActivo()
~RButton & w:: {
    if !_ComboInicio()
        return
    EnviarNtilde()
    MostrarBadgeCombo("RButton + W","DIFU MIXER 2","00E5FF",2200)
}
#HotIf CspLibre() && _LegadoActivo()
!w:: {
    EnviarMenor()
    MostrarBadgeCombo("ALT + W","★ OPC PRESSURE 2","00E5FF",2200)
}
#HotIf CspLibre() && _LegadoActivo()
~RButton & -:: {
    if !_ComboInicio()
        return
    now := A_TickCount
    if (now - RM.last < 300) {
        RM.last := 0
        Send("!t")
        MostrarHUD("OCULTAR REGLA","1A1A2E",800)
        return
    }
    RM.last := now
    Send("t")
    MostrarHUD("Rule","1A1A2E",800)
}
~RButton & z:: {
    if !_ComboInicio()
        return
    Send("^v")
    _SonarUI("copiar")
    MostrarHUD("📋 PEGAR (CTRL+V)","44DD88",800)
}
~RButton & z up:: stylus.botonSostenido := false
~RButton & x:: {
    if !_ComboInicio()
        return
    Send("u")
    MostrarHUD("GRADIENT (U)","00E5FF",900)
}
~RButton & 1:: {
    if !_ComboInicio()
        return
    MostrarToolTipE("FILL  (V)")
    Send("v")
}
~RButton & 2:: {
    if !_ComboInicio()
        return
    Send("{F11}")
    MostrarHUD("Advanced fill","AA8844",800)
}
#HotIf CspLibre()
_EnviarOpacidad() {
    key := (opacidad.nivel = 100) ? "0" : String(opacidad.nivel // 10)
    SendInput("+" key)
    ActualizarDialGUI()
    MostrarHUD("OPACIDAD " opacidad.nivel "%","00E5FF",900)
}
#HotIf CspLibre() && _LegadoActivo()
~RButton & 3::
~RButton & 4::
~RButton & 5::
~RButton & 6::
~RButton & 7::
~RButton & 8::
~RButton & 9::
~RButton & 0:: {
    if !_ComboInicio()
        return
    key := SubStr(A_ThisHotkey,StrLen(A_ThisHotkey))
    porcentaje := (key = "0") ? 100 : Integer(key) * 10
    opacidad.nivel := porcentaje
    SendInput("+" key)
    ActualizarDialGUI()
    MostrarHUD("OPACIDAD " porcentaje "%","00E5FF",900)
}
#HotIf CspLibre()
~1:: {
    if (dial.modo != 1) {
        dial.modo := 1
        ActualizarDialGUI()
    }
}
~2:: {
    if (dial.modo != 1) {
        dial.modo := 1
        ActualizarDialGUI()
    }
}
~3:: {
    if (dial.modo != 2) {
        dial.modo := 2
        ActualizarDialGUI()
    }
}
~4:: {
    if (dial.modo != 2) {
        dial.modo := 2
        ActualizarDialGUI()
    }
}
#HotIf CspLibre() && _LegadoActivo()
NumpadDiv:: {
    dial.modo := (dial.modo = 1) ? 2 : 1
    ActualizarDialGUI()
}
Numpad8:: {
    _LimpiarGUIs()
    try dial.g.Destroy()
    dial.g := 0
    dial.icono := 0
    dial.label := 0
    dial.barra := 0
    IniciarDialGUI()
    try dsGui.g.Destroy()
    dsGui.g := 0
    dsGui.icono := 0
    dsGui.label := 0
    dsGui.barra := 0
    try OnMessage(0x0201,_DsGUI_WM_LBUTTONDOWN,0)
    IniciarDsGUI()
    try ccGui.g.Destroy()
    ccGui.g := 0
    ccGui.icono := 0
    ccGui.label := 0
    ccGui.barra := 0
    try OnMessage(0x0201,_CcGUI_WM_LBUTTONDOWN,0)
    IniciarCcGUI()
    try arGui.g.Destroy()
    arGui.g := 0
    arGui.icono := 0
    arGui.label := 0
    arGui.barra := 0
    try OnMessage(0x0201,_ArGUI_WM_LBUTTONDOWN,0)
    IniciarArGUI()
    try hcGui.g.Destroy()
    hcGui.g := 0
    hcGui.icono := 0
    hcGui.label := 0
    hcGui.barra := 0
    try OnMessage(0x0201,_HCGUI_WM_LBUTTONDOWN,0)
    IniciarHCGUI()
    try lockGui.g.Destroy()
    lockGui.g := 0
    lockGui.icono := 0
    lockGui.barra := 0
    try OnMessage(0x0201,_LockGUI_WM_LBUTTONDOWN,0)
    IniciarLockGUI()
    try frenteGui.g.Destroy()
    frenteGui.g := 0
    frenteGui.icono := 0
    frenteGui.barra := 0
    try OnMessage(0x0201,_FrenteGUI_WM_LBUTTONDOWN,0)
    IniciarFrenteGUI()
    try estabGui.g.Destroy()
    estabGui.g := 0
    estabGui.valorTxt := 0
    estabGui.grip := 0
    estabGui.foco := false
    estabGui.dibV := -1
    SetTimer(_EstabFocoVigilar,0)
    _GdipLiberarFuentes()
    try OnMessage(0x0201,_EstabGUI_WM_LBUTTONDOWN,0)
    try OnMessage(0x0207,_EstabGUI_WM_MBUTTONDOWN,0)
    IniciarEstabGUI()
    try estabBtnGui.g.Destroy()
    estabBtnGui.g := 0
    estabBtnGui.icono := 0
    estabBtnGui.label := 0
    estabBtnGui.barra := 0
    try OnMessage(0x0201,_EstabBtnGUI_WM_LBUTTONDOWN,0)
    IniciarEstabBtnGUI()
    try hubGui.g.Destroy()
    hubGui.g := 0
    hubGui.icono := 0
    hubGui.barra := 0
    try OnMessage(0x0201,_HubGUI_WM_LBUTTONDOWN,0)
    try OnMessage(0x0205,_Companion_WM_RBUTTON,0)
    IniciarHubGUI()
    ToolTip("🔄 GUIs reiniciadas")
    SetTimer(() => ToolTip(),-1000)
}
~Space & NumpadAdd:: {
    Send("+p")
    MostrarMiniTexto("SPACE  +  +","1E8449",700)
}
~Space & NumpadSub:: {
    Send("^+p")
    MostrarMiniTexto("SPACE  +  −","922B21",700)
}
~Space & w:: {
    _FlushPendentes()
    Send("+w")
    MostrarMiniTexto("Up","1E8449",700)
}
~Space & x:: {
    _FlushPendentes()
    Send("+s")
    MostrarMiniTexto("Down","1E8449",700)
}
~Space & e:: _SpaceE_Dispatch()
~Space & q:: {
    _FlushPendentes()
    AccionEnfoque()
}
~Space & s:: {
    _FlushPendentes()
    SendInput("!h")   ; CSP: Alt+H = ventana de capa
    _SonarUI("shift_on")
    MostrarHUD("🪟 VENTANA DE CAPA","00E5FF",900)
}
~Space & f:: {
    _FlushPendentes()
    static estado := 0
    Send("{Insert}")
    if (estado = 0) {
        MostrarHUD("Gray scale","888888",1000)
        estado := 1
    } else {
        MostrarHUD("color","FF4444",1000)
        estado := 0
    }
}
~Space & Numpad1::
~Space & Numpad2::
~Space & Numpad3::
~Space & Numpad4::
~Space & Numpad5::
~Space & Numpad6:: {
    tecla := SubStr(A_ThisHotkey,StrLen(A_ThisHotkey))
    tipos := Map("1","HSV","2","Brillo/Contraste","3","Equilibrio color","4","Curva tonos","5","Niveles","6","Degradado")
    MostrarHUD("Capa: " tipos[tecla],"AA44FF",500)
    Send("^!" tecla)
}
#HotIf CspLibre()
$Numpad6:: {
    Send("{Insert}")
    MostrarHUD("Grayscale Toggle","888888",800)
}
#HotIf CspLibre() && _LegadoActivo()
*Backspace:: {
    if GetKeyState("Space","P") {
        Send("8")
        MostrarHUD("BORRAR CAPA DE CORRECCIÓN","FF4444",1200)
        return
    }
    Send("{Backspace}")
}
#HotIf CspLibre()
~*Space:: {
    spc.downTick := A_TickCount
    LienzoHUD_ChequeoSpace()
}
~*Space up:: {
    held := A_TickCount - spc.downTick
    now := A_TickCount
    if (held <= 180) && (now - spc.last < 320) {
        spc.last := 0
        sel.guiActivo := true
        if sel.estadoAltX {
            MostrarMiniTexto("👁 MOSTRAR BORDE","2ECC71",1200)
            sel.estadoAltX := false
        } else {
            MostrarMiniTexto("🚫 OCULTAR BORDE","E74C3C",1200)
            sel.estadoAltX := true
        }
        Send("{Alt down}{x}{Alt up}")
        SetTimer(ResetEstadoAltX,-3000)
        return
    }
    if (held <= 180)
        spc.last := now
    if (held <= 450) {
        spc.selectArmed := true
        SetTimer(_DesarmarSpaceSelect,-500)
    }
}
_DesarmarSpaceSelect() => spc.selectArmed := false
#HotIf
$^F11:: _CapturarLayout("Normal")
$^F12:: _CapturarLayout("Enfoque")
$^F10:: (HasMethod(this, "AbrirCalibradorPy") ? AbrirCalibradorPy() : AbrirPanelPuntos())
$^!+c:: (HasMethod(this, "AbrirCalibradorPy") ? AbrirCalibradorPy() : AbrirPanelPuntos())
$^!+k:: AbrirPanelPuntos()
$^!+t:: _AbrirSelectorTema()
$^!+m:: ModoSel_Alternar()
$^!+F9:: {
    z := NvSiguienteZona()
    if (z = "") {
        try MostrarHUD("Nuevas ventanas: todas las zonas están ocupadas", "9A7BFF", 1400)
        return
    }
    r := NuevaVentanaEnZona(z)
    try MostrarHUD("Nueva ventana (" z "): " r, "9A7BFF", 1400)
}
$^!+F8:: NvToggleModo()
#HotIf CspLibre() && _LegadoActivo()
!f:: {
    global _bSmearAbajo
    if !stylus.altActive
        return
    if AltF_state.held
        return
    AltF_state.held := true
    now := A_TickCount
    if (now - AltF_state.lastPress < 300) {
        AltF_state.lastPress := 0
        seguiaSostenido := stylus.altActive
        SendEvent("{Alt up}{NumpadEnd}")
        _AltRestaurar(seguiaSostenido)
        MostrarHUD("SMEAR SOFT  (2)","FF6B00",950)
    } else {
        AltF_state.lastPress := now
        stylus.bSinteticoTick := A_TickCount
        seguiaSostenido := stylus.altActive
        _bSmearAbajo := true
        SendEvent("{Alt up}{b up}{b down}")
        SetTimer(_AltF_SoltarB, -3000)   ; failsafe: la b nunca queda más de 3 s
        _AltRestaurar(seguiaSostenido)
        MostrarHUD("SMEAR  (1)","00E5FF",950)
    }
}
!f up:: {
    AltF_state.held := false
    SetTimer(_AltF_SoltarB, 0)
    _AltF_SoltarB()
}
~b & k:: {
    global colorEstado
    if (colorEstado = 1)
        SendInput("^2")
    Send("k")
    Send("k")
    colorEstado := 0
    MostrarMiniTexto("🔄 RESET → COLOR PRIMARIO","1A1A2E",1200)
}
#HotIf
#HotIf

; === INFRA: Alt+Q -> pincel_suave (Y), sin fuga a CSP (bote de pintura) ===
#HotIf CspLibre() && !_LegadoActivo()
!q:: _AltQSoftBrush()

#HotIf CspLibre() && !_LegadoActivo() && stylus.altActive
$q:: _AltQSoftBrush()

#HotIf
_AltQSoftBrush() {
    Send("y")
    MostrarBadgeCombo("ALT + Q", "SOFT BRUSH", "FF6B00", 2200)
}
