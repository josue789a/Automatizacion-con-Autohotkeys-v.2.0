; ============================================================================
; lib/captura_overlay.ahk  -  PAQUETE 1 (Fase 1: arquitectura "Pulsar y Listo")
;
; Píldora de captura SIN robo de foco (WS_EX_NOACTIVATE + WM_MOUSEACTIVATE ->
; MA_NOACTIVATE) + captura temporal de la combinación que emite el driver XP-Pen
; mientras CLIPStudioPaint.exe conserva el foreground (el driver mantiene el perfil 3).
;
; REGLAS DE ESTE ARCHIVO
;  - Se incluye AL FINAL del script principal (después de ^!+q). NO contiene código
;    ejecutable a nivel superior: todo es lazy (primera llamada a Cap_Preparar/Cap_Armar).
;  - Único escritor del INI = Python (Draft). Aquí solo se LEE [Captura] en
;    posiciones_gui.ini y se notifica el resultado por callback (Cap_FijarCallback).
;  - GetKeyState lógico (nunca "P"). Un tracker propio de modificadores lo complementa
;    porque los modificadores se suprimen mientras la captura está armada.
;  - Una sola puerta de salida: Cap_Terminar(motivo).
;
; API
;   Cap_Preparar(target, etiqueta, seq)   muestra la píldora con [Asignar] (entrada A)
;   Cap_Armar(seq, target, etiqueta)      arma directo (entrada B, p. ej. desde Python)
;   Cap_Cancelar(motivo)                  cancela limpiamente
;   Cap_Armado()                          true mientras captura/armando/gracia (para #HotIf)
;   Cap_FijarCallback(fn)                 fn(seq, estado, combo, target)
;
; Estados: IDLE -> [PREP] -> ARMING -> ARMED -> SWALLOW -> IDLE
; INI opcional  [Captura]: timeout_ms=5000, settle_ms=250, permitir_esc=0,
;               cancelar_fuera=1, log=0, pill_x=, pill_y=, demo=0
; ============================================================================

; ------------------------------------------------------------------ estado
_CapEstado() {
    static e := {
        fase: "IDLE",
        swallowHasta: 0,
        seq: 0, target: "", etiqueta: "",
        gui: 0, tTitulo: 0, estado: 0, bX: 0, bUndo: 0, bHist: 0, bar: 0,
        prevVal: "", historial: 0,
        modsLR: 0, pico: 0, espera: 0, sawKey: false,
        tInicio: 0, tFocoOk: 0, tReact: 0, tUlt: 0,
        cfg: 0, hkOn: false, hkLista: 0, atom: 0, salidaReg: false,
        alResultado: 0, focoRobado: 0
    }
    if !e.espera
        _CapReset(e)
    if !e.cfg
        e.cfg := {timeoutMs: 5000, settleMs: 250, permitirEsc: false, cancelarFuera: true, log: false, pillX: "", pillY: ""}
    return e
}

_CapReset(e) {
    e.modsLR := Map("LCtrl", false, "RCtrl", false, "LShift", false, "RShift", false, "LAlt", false, "RAlt", false, "LWin", false, "RWin", false)
    e.pico := Map()
    e.espera := []
    e.sawKey := false
    e.tFocoOk := 0
    e.tReact := 0
    e.tUlt := A_TickCount
    e.prevVal := ""
    e.historial := []
    try {
        histFile := A_Temp "\_ahk_cap_hist.txt"
        if FileExist(histFile) {
            txt := FileRead(histFile, "UTF-8")
            lineas := StrSplit(txt, "`n", "`r")
            if (lineas.Length >= 1)
                e.prevVal := Trim(lineas[1])
            loop lineas.Length - 1 {
                it := Trim(lineas[A_Index + 1])
                if (it != "")
                    e.historial.Push(it)
            }
        }
    }
}

_CapQ() {
    static f := 0
    c := 0
    if !f
        DllCall("QueryPerformanceFrequency", "Int64*", &f)
    DllCall("QueryPerformanceCounter", "Int64*", &c)
    return c * 1000.0 / f
}

_CapEsCSP() {
    if WinActive("ahk_exe CLIPStudioPaint.exe")
        return true
    h := DllCall("GetForegroundWindow", "ptr")
    if !h
        return false
    ro := DllCall("GetAncestor", "ptr", h, "uint", 3, "ptr")   ; GA_ROOTOWNER
    try return (ro && WinGetProcessName("ahk_id " ro) = "CLIPStudioPaint.exe")
    return false
}
_CapGraciaFocoMs() {
    return 450
}
_CapFgInfo() {
    h := DllCall("GetForegroundWindow", "ptr")
    if !h
        return "(sin foreground)"
    try return WinGetProcessName("ahk_id " h) " | " WinGetClass("ahk_id " h) " | " WinGetTitle("ahk_id " h)
    return "(?)"
}

Cap_Armado(*) {
    e := _CapEstado()
    return (e.fase = "ARMING" || e.fase = "ARMED" || A_TickCount < e.swallowHasta)
}

; Contexto para TODOS los #HotIf de CSP: activo en CSP y sin captura en curso
CspLibre(*) => WinActive("ahk_exe CLIPStudioPaint.exe") && !Cap_Armado()

Cap_FijarCallback(fn) {
    _CapEstado().alResultado := fn
}

Cap_Cancelar(motivo := "api") {
    Cap_Terminar(motivo)
}

_CapPyActivo() {
    try return _CalPyCapEstado().on
    return false
}

_CapCfgLeer() {
    e := _CapEstado()
    c := {timeoutMs: 5000, settleMs: 30, permitirEsc: false, cancelarFuera: true, log: false, pillX: "", pillY: ""}
    ini := _PosGuiIniPath()
    try c.timeoutMs := Max(1000, Integer(IniRead(ini, "Captura", "timeout_ms", "5000")))
    try c.settleMs := Max(0, Integer(IniRead(ini, "Captura", "settle_ms", "30")))
    try c.permitirEsc := (IniRead(ini, "Captura", "permitir_esc", "0") = "1")
    try c.cancelarFuera := (IniRead(ini, "Captura", "cancelar_fuera", "1") = "1")
    try c.log := (IniRead(ini, "Captura", "log", "0") = "1")
    try c.pillX := Integer(IniRead(ini, "Captura", "pill_x", ""))
    try c.pillY := Integer(IniRead(ini, "Captura", "pill_y", ""))
    e.cfg := c
}

; ------------------------------------------------------------------ GUI
_CapCrearGui() {
    e := _CapEstado()
    if e.gui
        return
    s := A_ScreenDPI / 96
    px := (n) => Round(n * s)
    g := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000", "XPPEN_CapturaPildora")
    g.BackColor := "1E1E2E"
    g.SetFont("s10 cFFFFFF", "Segoe UI")
    e.tTitulo := g.AddText("x" px(14) " y" px(8) " w" px(140) " h" px(22) " +0x200", "")
    e.estado := g.AddText("x" px(156) " y" px(8) " w" px(240) " h" px(22) " +0x200 +0x100 Center", "")
    e.bX := g.AddText("x" px(405) " y" px(8) " w" px(32) " h" px(22) " +0x200 +0x100 Center cEF5350", "✕")
    
    g.SetFont("s9 cD1C4E9", "Segoe UI")
    e.bUndo := g.AddText("x" px(14) " y" px(34) " w" px(205) " h" px(22) " +0x200 +0x100 Center Background2A2A3E", "↺ Deshacer a cambio anterior")
    e.bHist := g.AddText("x" px(228) " y" px(34) " w" px(210) " h" px(22) " +0x200 +0x100 Center Background2A2A3E", "▾ Ver historial de asignaciones")
    
    e.bar := g.AddProgress("x" px(14) " y" px(60) " w" px(424) " h" px(4) " -Smooth -Theme Background2A2A3E c7C4DFF Range0-100")
    e.estado.OnEvent("Click", _CapOnEstadoClick)
    e.bX.OnEvent("Click", _CapOnXClick)
    e.bUndo.OnEvent("Click", _CapOnUndoClick)
    e.bHist.OnEvent("Click", _CapOnHistClick)
    e.gui := g
    ; Windows Ink: sin press-and-hold / feedback sobre la píldora (evita RButton falso del lápiz)
    e.atom := DllCall("GlobalAddAtom", "str", "MicrosoftTabletPenServiceProperty", "ushort")
    DllCall("SetProp", "ptr", g.Hwnd, "ptr", e.atom, "ptr", 0x19, "int")
    OnMessage(0x21, Cap_MouseActivate)          ; WM_MOUSEACTIVATE
    if !e.salidaReg {
        OnExit(Cap_Salir)
        e.salidaReg := true
    }
}

Cap_MouseActivate(wParam, lParam, msg, hwnd) {
    e := _CapEstado()
    if (e.gui && DllCall("GetAncestor", "ptr", hwnd, "uint", 2, "ptr") = e.gui.Hwnd)    ; GA_ROOT
        return 3                                                                          ; MA_NOACTIVATE
}

_CapMostrar(e) {
    s := A_ScreenDPI / 96
    W := Round(452 * s)
    H := Round(70 * s)
    x := 0
    y := 0
    if (e.cfg.pillX != "" && e.cfg.pillY != "") {
        x := e.cfg.pillX
        y := e.cfg.pillY
    } else {
        try {
            m := ObtenerMonitorCSP()
            x := m.x + (m.w - W) // 2
            y := m.y + Round(60 * s)
        } catch {
            x := (A_ScreenWidth - W) // 2
            y := Round(60 * s)
        }
    }
    e.gui.Show("NA x" x " y" y " w" W " h" H)
    try WinSetRegion("0-0 w" W " h" H " R" Round(14 * s) "-" Round(14 * s), "ahk_id " e.gui.Hwnd)
}

_CapPunteroEnPildora() {
    e := _CapEstado()
    if !e.gui
        return false
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " e.gui.Hwnd)
    } catch {
        return false
    }
    return (mx >= x && mx < x + w && my >= y && my < y + h)
}

_CapOnEstadoClick(*) {
    e := _CapEstado()
    if (e.fase = "PREP")
        Cap_Armar(e.seq, e.target, e.etiqueta)
}

_CapOnXClick(*) {
    Cap_Terminar("cancel_x")
}

_CapOnUndoClick(*) {
    e := _CapEstado()
    if (e.fase != "ARMED" && e.fase != "ARMING")
        return
    Cap_Terminar("ok", e.prevVal)
}

_CapOnHistClick(*) {
    e := _CapEstado()
    if (e.fase != "ARMED" && e.fase != "ARMING")
        return
    if (!e.historial || e.historial.Length = 0) {
        ToolTip("Sin historial previo en esta sesión")
        SetTimer(() => ToolTip(), -1500)
        return
    }
    m := Menu()
    for item in e.historial {
        if (item != "")
            m.Add(item, (nom, *) => Cap_Terminar("ok", nom))
    }
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    m.Show(mx, my)
}

; ------------------------------------------------------------------ entradas
Cap_Preparar(target := "", etiqueta := "", seq := 0) {
    e := _CapEstado()
    if (e.fase = "ARMING" || e.fase = "ARMED")
        Cap_Terminar("reemplazado")
    SetTimer(_CapOcultar, 0)
    SetTimer(_CapPrepTimeout, 0)
    _CapCfgLeer()
    _CapCrearGui()
    _CapReset(e)
    e.seq := seq ? seq : e.seq + 1
    e.target := target
    e.etiqueta := etiqueta
    e.fase := "PREP"
    e.tTitulo.Text := (etiqueta != "") ? etiqueta : "Asignar"
    e.estado.SetFont("cA78BFA")
    e.estado.Text := "▶ Asignar"
    e.bar.Value := 0
    _CapMostrar(e)
    SetTimer(_CapPrepTimeout, -15000)
}

Cap_Armar(seq := 0, target := "", etiqueta := "") {
    e := _CapEstado()
    if _CapPyActivo() {
        OutputDebug("[CAP] rechazado: captura de Python activa")
        SetTimer(_CapNotificar.Bind(seq, "error_ocupado", "", 0), -1)
        return false
    }
    if (e.fase = "ARMING" || e.fase = "ARMED")
        Cap_Terminar("reemplazado")
    SetTimer(_CapOcultar, 0)
    SetTimer(_CapPrepTimeout, 0)
    SetTimer(_CapHotkeysOff, 0)
    _CapCfgLeer()
    _CapCrearGui()
    _CapReset(e)
    if (seq || e.fase != "PREP")
        e.seq := seq ? seq : e.seq + 1
    if (target != "")
        e.target := target
    if (etiqueta != "")
        e.etiqueta := etiqueta
    e.tTitulo.Text := (e.etiqueta != "") ? e.etiqueta : "Asignar"
    e.fase := "ARMING"
    e.tInicio := A_TickCount
    _CapHotkeys("On")                 ; primero suprimir, luego (si hace falta) devolver foco
    if !_CapEsCSP()
        try _CspFoco()
    _CapMostrar(e)
    if _CapEsCSP() {
        _CapPasarAArmed(e)
    } else {
        e.estado.SetFont("cFFD54F")
        e.estado.Text := "Volviendo a CSP…"
        e.bar.Value := 100
        e.tReact := A_TickCount
        SetTimer(_CapArmingPoll, 20)
    }
    return true
}

_CapArmingPoll() {
    e := _CapEstado()
    if (e.fase != "ARMING") {
        SetTimer(_CapArmingPoll, 0)
        return
    }
    if _CapEsCSP() {
        if !e.tFocoOk
            e.tFocoOk := A_TickCount
        if (A_TickCount - e.tFocoOk >= e.cfg.settleMs) {
            SetTimer(_CapArmingPoll, 0)
            _CapPasarAArmed(e)
        }
        return
    }
    e.tFocoOk := 0
    if (A_TickCount - e.tInicio > 1200) {
        SetTimer(_CapArmingPoll, 0)
        Cap_Terminar("error_foco")
        return
    }
    if (A_TickCount - e.tReact > 200) {
        e.tReact := A_TickCount
        try _CspFoco()
    }
}

_CapPasarAArmed(e) {
    e.fase := "ARMED"
    e.tUlt := A_TickCount
    e.pend := false
    e.pTipo := ""
    e.pNombre := ""
    e.pCombo := ""
    e.pHook := 0
    e.pT0 := 0
    e.tPerdido := 0
    e.tReact := 0
    e.estado.SetFont("cFFD54F")
    e.estado.Text := "⏺ Pulsa la tecla…"
    if (e.bUndo) {
        if (e.prevVal != "")
            e.bUndo.Text := "↺ Deshacer a: " e.prevVal
        else
            e.bUndo.Text := "↺ Deshacer a cambio anterior"
    }
    e.bar.Value := 100
    SetTimer(_CapTick, 100)
}

_CapTick() {
    e := _CapEstado()
    if (e.fase != "ARMED") {
        SetTimer(_CapTick, 0)
        return
    }
    if !_CapEsCSP() {
        if (e.gui && WinActive("ahk_id " e.gui.Hwnd)) {
            e.focoRobado += 1
            OutputDebug("[CAP] !! la píldora tomó el foreground (#" e.focoRobado ")")
            try _CspFoco()
            return
        }
        if e.cfg.cancelarFuera {
            OutputDebug("[CAP] foco fuera de CSP (cancel_fuera): " _CapFgInfo())
            Cap_Terminar("cancel_fuera")
            return
        }
        if !e.tPerdido {
            e.tPerdido := A_TickCount
            e.tReact := 0
            OutputDebug("[CAP] foco fuera de CSP: " _CapFgInfo())
        }
        if (A_TickCount - e.tReact > 150) {
            e.tReact := A_TickCount
            try _CspFoco()
        }
        if (A_TickCount - e.tPerdido < _CapGraciaFocoMs())
            return
        OutputDebug("[CAP] abort_foco confirmado: " _CapFgInfo())
        Cap_Terminar("abort_foco")
        return
    }
    e.tPerdido := 0
    resto := e.cfg.timeoutMs - (A_TickCount - e.tUlt)
    if (resto <= 0) {
        Cap_Terminar("timeout")
        return
    }
    e.bar.Value := Round(resto * 100 / e.cfg.timeoutMs)
}

_CapPrepTimeout() {
    Cap_Terminar("timeout_prep")
}

; ---------------------------------------------------- ensamblado de combo (quiescencia)
_CapQuietMs() {
    return 140          ; ajustable 100-180 ms según la ráfaga del driver
}
_CapHardMs() {
    return 1200         ; techo: cierra aunque algo quede sostenido
}
_CapPendIniciar(e, tipo, nombre := "") {
    if !e.pend {
        e.pend := true
        e.pT0 := A_TickCount
        SetTimer(_CapCierrePoll, 25)
    }
    e.pTipo := tipo
    e.pNombre := nombre
    _CapPendActualizar(e)
}
_CapPendActualizar(e) {
    if (e.pTipo = "mod")
        e.pCombo := _CapCombo(e, e.pico)
    else
        e.pCombo := _CapCombo(e, _CapModsActivos(e), e.pNombre)
    e.pHook := _CapQ()
    e.tUlt := A_TickCount
}
_CapCierrePoll() {
    e := _CapEstado()
    if (e.fase != "ARMED" || !e.pend) {
        SetTimer(_CapCierrePoll, 0)
        return
    }
    ahora := A_TickCount
    if (ahora - e.pT0 < _CapHardMs()) {
        if (ahora - e.tUlt < _CapQuietMs())
            return                                    ; la ráfaga sigue llegando
        if _CapAlgunModTracker(e)
            return                                    ; modificador aún abajo
    }
    SetTimer(_CapCierrePoll, 0)
    e.pend := false
    Cap_Terminar("ok", e.pCombo, e.pHook)
}

; ------------------------------------------------------------------ salida única
Cap_Terminar(motivo, combo := "", tHook := 0) {
    e := _CapEstado()
    prev := e.fase
    if (prev != "ARMED" && prev != "ARMING" && prev != "PREP")
        return
    SetTimer(_CapTick, 0)
    SetTimer(_CapArmingPoll, 0)
    SetTimer(_CapPrepTimeout, 0)
    SetTimer(_CapCierrePoll, 0)
    e.pend := false
    SetTimer(_CapOcultar, 0)
    ok := (motivo = "ok")
    if ok {
        e.fase := "SWALLOW"
        if (prev != "PREP") {
            e.swallowHasta := A_TickCount + 150          ; traga los restos del combo del driver
            SetTimer(_CapHotkeysOff, -160)
        }
        SetTimer(_CapOcultar, -700)
    } else {
        e.fase := "IDLE"
        e.swallowHasta := 0
        _CapHotkeys("Off")
        SetTimer(_CapOcultar, -100)
    }
    try {                                            ; UI al vuelo (camino crítico)
        if ok {
            e.estado.SetFont("c66BB6A")
            e.estado.Text := "✓ " combo
            e.bar.Value := 100
        } else {
            e.estado.SetFont("cEF5350")
            e.estado.Text := "✕ " _CapMotivoTxt(motivo)
            e.bar.Value := 0
        }
    }
    dt := tHook ? Round(_CapQ() - tHook, 2) : 0
    SetTimer(_CapNotificar.Bind(e.seq, ok ? "ok" : motivo, combo, dt), -1)
}

_CapMotivoTxt(motivo) {
    switch motivo {
        case "timeout", "timeout_prep": return "Tiempo agotado"
        case "cancel_esc", "cancel_fuera", "cancel_x", "api": return "Cancelado"
        case "abort_foco": return "CSP perdió el foco"
        case "error_foco": return "No pude volver a CSP"
        case "reemplazado": return "Reemplazado"
        default: return motivo
    }
}

_CapOcultar() {
    e := _CapEstado()
    if (e.fase = "SWALLOW" || e.fase = "PREP" || e.fase = "IDLE") {
        try e.gui.Hide()
        e.fase := "IDLE"
    }
}

_CapHotkeysOff() {
    e := _CapEstado()
    if (e.fase = "ARMING" || e.fase = "ARMED")
        return
    _CapHotkeys("Off")
}

_CapNotificar(seq, estado, combo, dt) {
    e := _CapEstado()
    linea := Format("[CAP] seq={} estado={} combo={} dt={}ms target={}", seq, estado, combo, dt, e.target)
    OutputDebug(linea)
    if e.cfg.log {
        try DirCreate(A_ScriptDir "\logs")
        try FileAppend(A_Now " " linea "`n", A_ScriptDir "\logs\captura.log", "UTF-8")
    }
    if e.alResultado
        try e.alResultado.Call(seq, estado, combo, e.target)
}

Cap_Salir(exitReason := "", exitCode := 0) {
    e := _CapEstado()
    SetTimer(_CapTick, 0)
    SetTimer(_CapArmingPoll, 0)
    SetTimer(_CapPrepTimeout, 0)
    SetTimer(_CapCierrePoll, 0)
    e.pend := false
    SetTimer(_CapOcultar, 0)
    SetTimer(_CapHotkeysOff, 0)
    try _CapHotkeys("Off")
    e.fase := "IDLE"
    e.swallowHasta := 0
    if e.gui {
        try DllCall("RemoveProp", "ptr", e.gui.Hwnd, "ptr", e.atom, "ptr")
        try e.gui.Destroy()
        e.gui := 0
    }
    if e.atom
        try DllCall("GlobalDeleteAtom", "ushort", e.atom)
    return 0
}

; ------------------------------------------------------------------ hotkeys temporales (On/Off)
; Se activan SOLO mientras la captura está armada: así no se evalúa nada en cada tecla
; del sistema fuera de la captura. Medir el coste de "On" (log [CAP] hotkeys On en N ms).
_CapConstruirLista(e) {
    lista := []
    omitir := Map(0x10, 1, 0x11, 1, 0x12, 1, 0x5B, 1, 0x5C, 1, 0xA0, 1, 0xA1, 1, 0xA2, 1, 0xA3, 1, 0xA4, 1, 0xA5, 1, 0xE5, 1, 0xE7, 1)
    loop 246 {
        vk := A_Index + 7                            ; 0x08 .. 0xFD
        if omitir.Has(vk)
            continue
        nombreVk := Format("vk{:02X}", vk)
        if (GetKeyName(nombreVk) = "")
            continue
        lista.Push({nombre: "*" nombreVk, cb: Cap_OnKey.Bind(vk)})
    }
    lista.Push({nombre: "*vk20 up", cb: Cap_OnUp.Bind("Space")})
    lista.Push({nombre: "*RButton", cb: Cap_OnRButton})
    lista.Push({nombre: "*RButton up", cb: Cap_OnUp.Bind("RButton")})
    for n in ["LCtrl", "RCtrl", "LShift", "RShift", "LAlt", "RAlt", "LWin", "RWin"] {
        lista.Push({nombre: "*" n, cb: Cap_OnModDown.Bind(n)})
        lista.Push({nombre: "*" n " up", cb: Cap_OnModUp.Bind(n)})
    }
    e.hkLista := lista
}

_CapHotkeys(modo) {
    e := _CapEstado()
    if ((modo = "On") = e.hkOn)
        return
    t := _CapQ()
    if !e.hkLista
        _CapConstruirLista(e)
    HotIf()
    for it in e.hkLista {
        try {
            if (modo = "On")
                Hotkey(it.nombre, it.cb, "On")
            else
                Hotkey(it.nombre, "Off")
        }
    }
    HotIf(Cap_HotIfFuera)
    try {
        if (modo = "On")
            Hotkey("*LButton", Cap_OnClicFuera, "On")
        else
            Hotkey("*LButton", "Off")
    }
    HotIf()
    e.hkOn := (modo = "On")
    OutputDebug("[CAP] hotkeys " modo " en " Round(_CapQ() - t, 1) " ms")
}

Cap_HotIfFuera(*) {
    e := _CapEstado()
    return (e.fase = "ARMED" && e.cfg.cancelarFuera && !_CapPunteroEnPildora())
}

Cap_OnClicFuera(hk := "") {
    Cap_Terminar("cancel_fuera")            ; el clic se CONSUME (no llega a CSP)
}

; ------------------------------------------------------------------ captura
_CapNombreVk(vk) {
    n := GetKeyName(Format("vk{:02X}", vk))
    return (StrLen(n) = 1) ? StrUpper(n) : n
}

_CapModsActivos(e) {
    m := Map()
    if (e.modsLR["LCtrl"] || e.modsLR["RCtrl"] || GetKeyState("Ctrl"))
        m["Ctrl"] := true
    if (e.modsLR["LShift"] || e.modsLR["RShift"] || GetKeyState("Shift"))
        m["Shift"] := true
    if (e.modsLR["LAlt"] || e.modsLR["RAlt"] || GetKeyState("Alt"))
        m["Alt"] := true
    if (e.modsLR["LWin"] || e.modsLR["RWin"] || GetKeyState("LWin") || GetKeyState("RWin"))
        m["Win"] := true
    return m
}

_CapAlgunModTracker(e) {
    for k, v in e.modsLR
        if v
            return true
    return false
}

; Formato canónico: Ctrl+Shift+Alt+Win, luego teclas de espera (Space/RButton), luego la principal
_CapCombo(e, modsSet, principal := "") {
    partes := []
    for tok in ["Ctrl", "Shift", "Alt", "Win"]
        if modsSet.Has(tok)
            partes.Push(tok)
    for x in e.espera
        partes.Push(x)
    if (principal != "")
        partes.Push(principal)
    res := ""
    for p in partes
        res .= (A_Index > 1 ? "+" : "") p
    return res
}

Cap_OnKey(vk, hk := "") {
    e := _CapEstado()
    t := _CapQ()
    if (vk = 0x51) {                                  ; pánico ^!+Q siempre vivo
        m := _CapModsActivos(e)
        if (m.Has("Ctrl") && m.Has("Alt") && m.Has("Shift"))
            ExitApp()
    }
    if (e.fase != "ARMED")
        return                                        ; ARMING / gracia: tragar sin actuar
    mods := _CapModsActivos(e)
    if (vk = 0x1B && mods.Count = 0 && e.espera.Length = 0 && !e.cfg.permitirEsc) {
        Cap_Terminar("cancel_esc")
        return
    }
    e.sawKey := true
    if (vk = 0x20) {                                  ; Space = tecla de espera (¿Space+RButton?)
        _CapEsperaDown(e, "Space", t)
        return
    }
    if (mods.Count = 0 && e.espera.Length = 0 && !e.pend) {
        Cap_Terminar("ok", _CapCombo(e, mods, _CapNombreVk(vk)), t)   ; tecla suelta: sin latencia
        return
    }
    _CapPendIniciar(e, "key", _CapNombreVk(vk))
}

Cap_OnRButton(hk := "") {
    e := _CapEstado()
    if (e.fase != "ARMED")
        return
    if _CapPunteroEnPildora()
        return                                        ; ignora el "mantener pulsado" sobre la píldora
    e.sawKey := true
    _CapEsperaDown(e, "RButton", _CapQ())
}

_CapEsperaDown(e, tok, t) {
    for x in e.espera
        if (x = tok)
            return                                    ; auto-repeat
    e.tUlt := A_TickCount
    e.espera.Push(tok)
    if (e.espera.Length >= 2)                         ; Space+RButton / RButton+Space: combo inmediato
        _CapPendIniciar(e, "key", "")
}

Cap_OnUp(tok, hk := "") {
    e := _CapEstado()
    if (e.fase != "ARMED")
        return
    if e.pend {                                       ; combo ya armado: soltar la tecla de espera lo completa
        SetTimer(_CapCierrePoll, 0)
        e.pend := false
        Cap_Terminar("ok", e.pCombo, e.pHook)
        return
    }
    if (e.espera.Length = 1 && e.espera[1] = tok) {   ; RButton/Space con o sin modificadores
        mods := e.pico.Count ? e.pico : _CapModsActivos(e)   ; pico: aunque el modificador se suelte antes
        Cap_Terminar("ok", _CapCombo(e, mods), _CapQ())
    }
}

Cap_OnModDown(nombre, hk := "") {
    e := _CapEstado()
    if (e.fase != "ARMED")
        return
    e.modsLR[nombre] := true
    e.pico[SubStr(nombre, 2)] := true
    e.tUlt := A_TickCount
    if e.pend
        _CapPendActualizar(e)
}

Cap_OnModUp(nombre, hk := "") {
    e := _CapEstado()
    e.modsLR[nombre] := false
    if (e.fase != "ARMED")
        return
    ; modificador(es) solos: ninguna otra tecla durante la pulsación y ya no queda ninguno abajo
    if (!e.sawKey && e.pico.Count && !_CapAlgunModTracker(e))
        _CapPendIniciar(e, "mod")
}

; ------------------------------------------------------------------ demo (solo pruebas P1)
; Activar con [Captura] demo=1 en posiciones_gui.ini. Ctrl+Alt+Shift+F11 muestra la píldora.
; (grep previo: confirmar que ^!+F11 no existe ya en lib\*.ahk)
Cap_DemoOn(*) {
    static v := -1
    if (v = -1) {
        v := false
        try v := (IniRead(_PosGuiIniPath(), "Captura", "demo", "0") = "1")
    }
    return v
}

#HotIf Cap_DemoOn()
^!+F11:: Cap_Preparar("demo_target", "K? · demo")
#HotIf
