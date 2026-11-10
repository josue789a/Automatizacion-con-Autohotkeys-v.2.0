#Requires AutoHotkey v2.0
; [LIB] hotkeys_csp.ahk — fuente: XPPEN AHK VERSION ESTABLE.ahk L129–1250, L2480–2484, L2636–2676
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
; Shift sostenido SOLO se apaga con su propio toggle (~RButton & f) o al salir del script.
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

global _briefingLanzado := false

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

Pause::_LiberarModificadores()   ; tecla de rescate manual

#HotIf
^!b:: LanzarBriefing()

EsEditorTexto() => WinActive("ahk_exe notepad++.exe") || WinActive("ahk_exe notepad.exe")
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
$`:: {
    sys.modoEscritura := !sys.modoEscritura
    if (sys.modoEscritura) {
        Suspend(1)
        MostrarIndicador("🔴📝 MODO ESCRITURA — puedes escribir libremente 📝🔴")
    } else {
        Suspend(0)
        MostrarIndicador("🟢✅ MODO AHK ACTIVO — hotkeys habilitadas ✅🟢")
    }
}
#SuspendExempt False
#HotIf WinActive("ahk_exe CLIPStudioPaint.exe")
RButton:: {
    stylus.rButtonHeld := true
    stylus.comboUsado := false
    stylus.upSinteticoTick := 0
}
RButton up:: {
    elapsed := (stylus.upSinteticoTick > 0) ? (A_TickCount - stylus.upSinteticoTick) : 9999
    if (elapsed < UP_SINTETICO_MS) {
        stylus.rButtonHeld := true
        stylus.upSinteticoTick := 0
        return
    }
    stylus.rButtonHeld := false
    if (!stylus.comboUsado)
        SendInput("{RButton}")
}
Space & RButton:: {
    stylus.comboUsado := true
    _InvSeleccionConGUI()
}
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
$^z:: _DeshacerRehacer()
_MaskRButton() {
    stylus.comboUsado := true
    if (stylus.botonSostenido)
        return
    stylus.botonSostenido := true
    Send("!m")
    MostrarHUD("MASK (ALT+M)","00E5FF",900)
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
        _HapticoRacha("redo")
    } else {
        SendInput("^z")
        if (ahora - ultUndo > 120) {
            ToolTipCS("🔴 DESHACER",300)
            ultUndo := ahora
        }
        _HapticoRacha("undo")
    }
}
$^z up:: stylus.botonSostenido := false
!z:: {
    SendInput("^c")
    _SonarUI("copiar")
    ToolTipCS("📋 COPIAR",600)
}
!^z:: {
    stylus.botonSostenido := true
    SendInput("^y")
    ToolTipCS("🟢 REHACER",600)
    _HapticoRacha("redo")
}
!^z up:: stylus.botonSostenido := false
#HotIf stylus.altActive && !WinActive("ahk_exe PureRef.exe")
z:: {
    SendInput("^c")
    _SonarUI("copiar")
    ToolTipCS("📋 COPIAR",600)
}
w:: {
    Send("+s")
    MostrarHUD("SHIFT+S","00E5FF",800)   ; solo visual, sin llamada a _SonarUI
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
#HotIf WinActive("ahk_exe CLIPStudioPaint.exe")
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
~RButton & a:: {
    stylus.comboUsado := true
    EnviarNtilde()
    MostrarHUD("REFERENCE LAYER","AA44FF",1680)
}
$e:: {
    _FlushPendentes()
    global colorEstado
    now := A_TickCount
    if GetKeyState("Shift") {
        Send("e")
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
~RButton & e:: {
    stylus.comboUsado := true
    Send("{F12}")
    _SonarUI("borrador")
    MostrarHUD("ERASER LAZO","FF4444",1200)
}
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
!Home:: {
    Send("{PageDown}")
    MostrarHUD("ACCESO RÁPIDO","AA8844",800)
}
!-:: _CicloO()
$w:: {
    _FlushPendentes()
    global colorEstado
    Stab_ResetUniversal("w")
    now := A_TickCount
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
~r:: SetTimer(LienzoHUD_ChequeoR, -140)
$q:: {
    if GetKeyState("Alt","P") {
        Send("!q")
        return
    }
    now := A_TickCount
    ; Prioridad al botón del lápiz: toggle Stab Normal inmediato, sin pasar por la ventana de doble-toque
    if (stylus.rButtonHeld || GetKeyState("RButton","P")) {
        stylus.comboUsado := true              ; evita que RButton up emita un clic derecho
        AlternarEstabilizacion()
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
    if (N6.layerVis)
        _AvisoEvento("capa_ocultar", "🚫 HIDE LAYER", "SHIFT + D", "FF4444", 0)
    else
        _AvisoEvento("capa_mostrar", "👁 SHOW LAYER", "SHIFT + D", "44DD88", 0)
    N6.layerVis := !N6.layerVis
}
+w:: {
    hoverOn := _ToggleHoverPaneles()
    ActualizarDsGUI()
    ActualizarCcGUI()
    ActualizarArGUI()
    if (hoverOn)
        MostrarMiniTexto("🟠 HOVER ON — deslizador + círculo + acceso rápido","1E8449",1200)
    else
        MostrarMiniTexto("👁 HOVER OFF — paneles visibles","1A5276",1200)
}
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
#HotIf WinActive("ahk_exe CLIPStudioPaint.exe") && stylus.altActive
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
#HotIf WinActive("ahk_exe CLIPStudioPaint.exe")
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
__AltS_SEND_NORMAL() {
    if !AltB_s_state.timerRunning
        return
    AltB_s_state.timerRunning := 0
    seguiaSostenido := stylus.altActive
    SendEvent("{Alt up}a")
    _AltRestaurar(seguiaSostenido)
    MostrarHUD("LAYER CURRENT (1)","00E5FF",950)
}
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
+r:: {
    MostrarHUD("REFLEJAR HORIZONTAL","00E5FF",1500)
    Send("+r")
}
Tab::
+Escape::
F3:: AccionEnfoque()
~f:: {
}
~RButton & s:: {
    stylus.comboUsado := true
    ; Capa > Máscara (layerinmask = M). Tu CSP no tiene atajo para
    ; layerchangebelowclip (recorte real); si se lo asignas, cámbialo aquí.
    Send("m")
    _SonarUI("seleccion")
    _AvisoEvento("mascara_recorte", "MÁSCARA DE RECORTE", "PEN + S", "00E5FF", 0)
}
~RButton & q:: {
    stylus.comboUsado := true
    Send("{F6}")
    MostrarBadgeCombo("PEN + Q","HARD BRUSH","FF6B00",2200)
}
~RButton & f:: {
    if (!shiftSostenido.activo && !WinActive("ahk_exe CLIPStudioPaint.exe"))
        return   ; no anclar Shift fuera de CSP; sí permitir soltarlo
    stylus.comboUsado := true
    ShiftAnclado_Toggle()
}

; Anclado de Shift — usado por ~RButton & f y por los botones fijos de modificación.
ShiftAnclado_Toggle() {
    global shiftSostenido
    shiftSostenido.activo := !shiftSostenido.activo
    if (shiftSostenido.activo) {
        Send("{Shift down}")
        _SonarUI("shift_on")
        _BadgeSFT(true)
        _HudSFTAnclado(true)
    } else {
        Send("{Shift up}")
        _SonarUI("shift_off")
        _BadgeSFT(false)
        _AvisoCerrarBadge()
        _AvisoCerrarHUD()
        _AvisoEvento("shift_sostenido", "SHIFT LIBERADO", "PEN + F", "888888", 1501)   ; 1501 evita el centinela 1500 de MostrarAvisoUI
    }
    return shiftSostenido.activo
}
; Apagado forzado (pérdida de foco, salida o botón fijo de modificación).
ShiftAnclado_Apagar(silencioso := false) {
    global shiftSostenido
    if !shiftSostenido.activo
        return false
    shiftSostenido.activo := false
    Send("{Shift up}")
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
    subtexto := "PEN + F"
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
~RButton & w:: {
    stylus.comboUsado := true
    EnviarNtilde()
    MostrarBadgeCombo("PEN + W","DIFU MIXER 2","00E5FF",2200)
}
!w:: {
    EnviarMenor()
    MostrarBadgeCombo("ALT + W","★ OPC PRESSURE 2","00E5FF",2200)
}
~RButton & -:: {
    stylus.comboUsado := true
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
    stylus.comboUsado := true
    Send("^v")
    _SonarUI("copiar")
    MostrarHUD("📋 PEGAR (CTRL+V)","44DD88",800)
}
~RButton & z up:: stylus.botonSostenido := false
~RButton & x:: {
    stylus.comboUsado := true
    Send("u")
    MostrarHUD("GRADIENT (U)","00E5FF",900)
}
~RButton & 1:: {
    stylus.comboUsado := true
    MostrarToolTipE("FILL  (V)")
    Send("v")
}
~RButton & 2:: {
    stylus.comboUsado := true
    Send("{F11}")
    MostrarHUD("Advanced fill","AA8844",800)
}
_EnviarOpacidad() {
    key := (opacidad.nivel = 100) ? "0" : String(opacidad.nivel // 10)
    SendInput("+" key)
    ActualizarDialGUI()
    MostrarHUD("OPACIDAD " opacidad.nivel "%","00E5FF",900)
}
~RButton & 3::
~RButton & 4::
~RButton & 5::
~RButton & 6::
~RButton & 7::
~RButton & 8::
~RButton & 9::
~RButton & 0:: {
    stylus.comboUsado := true
    key := SubStr(A_ThisHotkey,StrLen(A_ThisHotkey))
    porcentaje := (key = "0") ? 100 : Integer(key) * 10
    opacidad.nivel := porcentaje
    SendInput("+" key)
    ActualizarDialGUI()
    MostrarHUD("OPACIDAD " porcentaje "%","00E5FF",900)
}
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
~Space & e:: {
    _FlushPendentes()
    _ToggleLayerVis()
}
~Space & q:: {
    _FlushPendentes()
    AccionEnfoque()
}
~Space & s:: {
    _FlushPendentes()
    SendInput("+f")
    _SonarUI("shift_on")
    MostrarHUD("🔒 BLOQUEO TRANSPARENCIA","00E5FF",900)
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
$Numpad6:: {
    Send("{Insert}")
    MostrarHUD("Grayscale Toggle","888888",800)
}
*Backspace:: {
    if GetKeyState("Space","P") {
        Send("8")
        MostrarHUD("BORRAR CAPA DE CORRECCIÓN","FF4444",1200)
        return
    }
    Send("{Backspace}")
}
~Space:: {
    spc.downTick := A_TickCount
    SetTimer(LienzoHUD_ChequeoSpace, -150)
}
~Space up:: {
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
$^F10:: AbrirPanelPuntos()
$^!+c:: AbrirPanelPuntos()
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
#HotIf WinActive("ahk_exe CLIPStudioPaint.exe")
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
