; ┌─────────────────────────────────────────────────────────┐
; │  🎨 CSP ARTIST_PRO_14_GEN2 — SCRIPT TABLET ÚNICA          │
; │                                                         │
; │  1. DIRECTIVAS GLOBALES                                 │
; │  2. ESTADO (objetos agrupados)                          │
; │  3. TIMERS                                               │
; │  4. HOTKEYS GLOBALES                                     │
; │  5. HOTKEYS CSP                                          │
; │     a) Selección y reselección                          │
; │     b) Deshacer / Rehacer                               │
; │     c) Herramientas (A E W Q S O R)                      │
; │     d) Atajos con clic derecho                          │
; │     e) Modificadores de capa                             │
; │  6. CLASE BorderFrame                                    │
; │  7. FUNCIONES                                            │
; └─────────────────────────────────────────────────────────┘

; ┌───────────────────────────────────────────────────────┐
; │  1. DIRECTIVAS GLOBALES                               │
; └───────────────────────────────────────────────────────┘
#Requires AutoHotkey v2.0
#SingleInstance Force
; DPI awareness — coordenadas reales sin escalado de Windows
DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
SendMode("Input")
SetWorkingDir(A_ScriptDir)
SetKeyDelay(-1, -1)
SetMouseDelay(-1)
SetDefaultMouseSpeed(0)
CoordMode("Mouse",   "Screen")
CoordMode("ToolTip", "Screen")
SetTitleMatchMode(2)

; ┌──────────────────────────────────────────────────────────┐
; │  2. ESTADO  (objetos agrupados)                          │
; └──────────────────────────────────────────────────────────┘
sys := { lastModTime: "", modoEscritura: false }
stylus := { altActive: false, rButtonHeld: false, comboUsado: false, upSinteticoTick: 0, botonSostenido: false }
sel := { estado: 0, estadoAltX: false, estadoC: 0, guiActivo: false }
colorEstado     := 0   ; 0=primario  1=secundario  2=alpha
E := { last: 0, timerRunning: 0, procesando: false }
W := { last: 0, timerRunning: 0 }
Z := { last: 0, timerRunning: 0 }
Q := { last: 0, estadoEstab: 0 }
A_state := { lastPress: 0 }
AltS_state := { lastPress: 0 }
S := { estadoCaracter: 0, skipNext: false }
O := { ciclo: 0 }
N6 := { estadoEscala: 0, layerVis: 1 }
hist := { abierto: false, modo: 1 }
btn := { b1: false, b2: false, b3: false }
botDer := { b1: false, b2: false, b3: false }
colorV := {
    dsID: 0, dsVis: false, bDS: 0, hover: true, cspHwnd: 0,
    dsX: 0, dsY: 0, dsW: 0, dsH: 0,
    ccFromRight: 169, ccW: 169, ccFromTop: 50, ccH: 214
}
ar := { id: 0, dsVis: false, bAR: 0, hover: true }
floatGui := { miniTip: 0, miniGUI: 0, tooltipToggle: 0, enfoque: 0, miniTipTick: 0, miniTipID: 0, hud: 0 }
enfoque := { activo: false }
boost := { holdDelay: 300, maxBoost: 5 }
spc := { last: 0, downTick: 0 }
dial := { modo: 1, g: 0, icono: 0, label: 0, barra: 0 }

; ┌──────────────────────────────────────────────────────────────────────┐
; │  3. TIMERS                                                           │
; └──────────────────────────────────────────────────────────────────────┘
SetTimer(CheckReload,            600)
SetTimer(ChequearZonaHistorial,  200)
SetTimer(ChequearZonaAltA,        10)
SetTimer(ChequearZonaDerecha,     10)
SetTimer(LoopColorV,              80)
SetTimer(LoopAccesoRapido,        80)
SetTimer(ResetEnfoque,         10000)
SetTimer(ResetAlphaStates,       500)
IniciarDeteccion()
IniciarDialGUI()

; ┌──────────────────────────────────────────────────────┐
; │  4. HOTKEYS GLOBALES                                 │
; └──────────────────────────────────────────────────────┘
#HotIf WinActive("ahk_exe notepad++.exe")
^s:: {
    SendInput("^s")
    Sleep(200)
    Reload()
}
^g:: {
    ts       := FormatTime(, "yyyy-MM-dd_HH-mm-ss")
    repoPath := "C:\Users\JOSUE\Desktop\AHK-global-main"
    gitExe   := "git"
    cmd      := gitExe ' -C "' repoPath '" add -A'
             .  ' && ' gitExe ' -C "' repoPath '" commit -m "auto_' ts '"'
             .  ' && ' gitExe ' -C "' repoPath '" push'
    Run('cmd /k "' cmd ' && timeout /t 3 && exit"', , "")
    ToolTip("⏳ Enviando a GitHub...")
    SetTimer(_CheckGitDone, -5000)
}
#HotIf

#SuspendExempt
|:: {
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

; ┌──────────────────┐
; │  5. HOTKEYS CSP  │
; └──────────────────┘
#HotIf WinActive("ahk_exe CLIPStudioPaint.exe")

Numpad0:: {
    hist.modo := (hist.modo = 1) ? 2 : 1
    if (hist.modo = 2 && hist.abierto) {
        hist.abierto := false
        Send("{Numpad9}")
    }
    MostrarHUD(hist.modo = 1 ? "🟢 DYNAMIC HISTORY" : "🔒 HISTORY LOCKED", hist.modo = 1 ? "00E5FF" : "FF6B00", 5000)
}

^s:: {
    SendInput("^s")
    SoundBeep(600, 100)
    SoundBeep(900, 150)
    MostrarHUD("💾 GUARDADO Y MODIFICADO", "44DD88", 800)
}

Space & RButton:: {
    SendInput("!g")
    MostrarHUD("FLIP HORIZONTAL", "888888", 700)
    SoundBeep(800, 100)
}

; ══════════════════════════════════════════════════════════════════
; RButton del stylus — LÓGICA GENERAL
;
; El driver reporta el clic derecho del stylus como INSTANTÁNEO
; (0-15ms). La lógica es: armar rButtonHeld al presionar, diferir
; la acción al soltar según si hubo combo o no.
;   sin combo → soltar manda {RButton} → cuentagotas en CSP
;   con combo → soltar no manda nada → cuentagotas absorbido
;
; POR QUÉ SIN TILDE EN RButton:: Y RButton up::
; Con tilde, el down nativo pasa a CSP y activa el cuentagotas
; inmediatamente al presionar, antes de saber si viene combo.
; Sin tilde, AHK intercepta el down antes de que llegue a CSP.
; Los combos ~RButton & X tienen su propia tilde y funcionan
; independientemente — quitarla aquí no los afecta.
;
; POR QUÉ comboUsado := true EN CADA ~RButton & X
; Si un combo no lo marca, al soltar RButton up:: ve comboUsado=false
; y manda el cuentagotas igual, aunque se haya usado un combo.
; Regla: todo hotkey ~RButton & X debe tener esa línea al inicio.
;
; ── REHACER (RButton + Ctrl+Z del miniteclado) ──────────────────
;
; POR QUÉ {RButton up} SINTÉTICO ANTES DE ^y
; CSP ignora atajos de historial mientras RButton está físicamente
; sostenido — lo trata como herramienta temporal activa. Solución:
; mandar {RButton up} sintético para que CSP "vea" el botón soltado.
; Ese up sintético también dispara RButton up:: — hay que ignorarlo
; sin resetear rButtonHeld (de lo contrario se rompe rehacer múltiple).
;
; POR QUÉ EL CURSOR SE MUEVE A (2775, 11) ANTES DEL UP SINTÉTICO
; Sin tilde el down no llegó a CSP, pero el up sintético sí llegaría
; como un up huérfano que CSP podría interpretar de formas raras.
; Moverlo a zona segura fuera del lienzo lo hace inofensivo.
;
; CÓMO SE DISTINGUE UP SINTÉTICO VS UP REAL (upSinteticoTick)
; Se marca upSinteticoTick = A_TickCount justo antes del up sintético.
; En RButton up:: elapsed = A_TickCount - upSinteticoTick.
; Sintético llega en 20-40ms, real en ≥100ms. Umbral = UP_SINTETICO_MS.
; elapsed < umbral → sintético: re-afirmar rButtonHeld, ignorar.
; elapsed ≥ umbral → real: resetear y procesar normalmente.
;
; botonSostenido: evita mandar up sintético en cada repetición de
; key repeat de Ctrl+Z. Solo el primer tap lo manda; las repeticiones
; van directo a ^y porque CSP ya "vio" el botón soltado.
; Se resetea en $^z up:: al soltar la tecla.
;
; CAMINOS DESCARTADOS
; ignorarProximoUp — bandera consumible, se desincronizaba con
;   key repeat (varios ups sintéticos consecutivos).
; GetKeyState("RButton","P") — el up sintético también lo afecta,
;   reporta "soltado" aunque el físico siga abajo.
; MODO_REHACER_MS — timer de expiración, funcional pero con espera
;   artificial de 200-600ms antes de poder volver a deshacer.
; ══════════════════════════════════════════════════════════════════
UP_SINTETICO_MS := 70

; Pasos de la estabilización: antes 63 en cada sentido (subida y
; bajada simétricas). Ahora 15% más alto (63 × 1.15 ≈ 72.45 → 72) —
; sigue siendo simétrico, así que al bajar vuelve exactamente al
; punto de partida original. Para reajustar, solo cambia este número.
ESTABILIZACION_PASOS := 72

RButton:: {
    stylus.rButtonHeld     := true
    stylus.comboUsado      := false
    stylus.upSinteticoTick := 0
    ; Sin tilde — el down nativo NO pasa a CSP, así no activa cuentagotas.
    ; Los combos ~RButton & X tienen su propia tilde y siguen funcionando.
}
RButton up:: {
    elapsed := (stylus.upSinteticoTick > 0) ? (A_TickCount - stylus.upSinteticoTick) : 9999
    if (elapsed < UP_SINTETICO_MS) {
        ; Up sintético (20-40ms) — re-afirmar estado y continuar, no resetear
        stylus.rButtonHeld     := true
        stylus.upSinteticoTick := 0
        return
    }
    ; Up real (≥100ms) — procesar normalmente
    stylus.rButtonHeld := false
    if (!stylus.comboUsado)
        SendInput("{RButton}")   ; soltar sin combo → cuentagotas
}
~!b::    stylus.altActive := true
~!b up:: stylus.altActive := false

; ┌───────────────────────────────┐
; │  5a. SELECCIÓN Y RESELECCIÓN  │
; └───────────────────────────────┘

!x:: {
    if sel.estadoAltX {
        MostrarMiniTexto("👁 MOSTRAR BORDE", "2ECC71", 1200)
        sel.estadoAltX := false
    } else {
        MostrarMiniTexto("🚫 OCULTAR BORDE", "E74C3C", 1200)
        sel.estadoAltX := true
    }
    Send("{Alt down}{x}{Alt up}")
    SetTimer(ResetEstadoAltX, -3000)
}

c:: {
    if (sel.estadoC = 0) {
        MostrarMiniTexto("🔄 INV. ÁREA SELECC.", "FF6F61", 900)
        SoundBeep(280, 120)
        SoundBeep(220, 160)
        sel.estadoC := 1
        SetTimer(__ResetEstadoC, -2000)
    } else {
        MostrarMiniTexto("🔁 INV. ÁREA SELECC.", "000000", 900)
        sel.estadoC := 0
        SetTimer(__ResetEstadoC, 0)
    }
    Send("c")
}

x:: {
    if (sel.estado = 0) {
        MostrarMiniTexto("❌ DESELECCIÓN", "C0392B", 700)
        Send("x")
        sel.estado := 1
    } else {
        MostrarMiniTexto("✅ RESELECCIÓN", "27AE60", 1200)
        Send("{F10}")
        sel.estado := 0
    }
}

; ┌──────────────────────────┐
; │  5b. DESHACER / REHACER  │
; └──────────────────────────┘
$^z:: {
    if stylus.rButtonHeld {
        stylus.comboUsado := true
        if (!stylus.botonSostenido) {
            ; Primer tap — marcar tick y mandar up sintético para desbloquear CSP
            stylus.botonSostenido  := true
            stylus.upSinteticoTick := A_TickCount
            MouseGetPos(&origX, &origY)
            MouseMove(2775, 11, 0)            ; zona segura fuera del lienzo (P2) — no cambia color
            SendInput("{RButton up}")         ; libera RButton a nivel de CSP
            SendInput("^y")
            MouseMove(origX, origY, 0)
        } else {
            ; Key repeat — CSP ya "vio" el botón soltado, solo rehacer
            SendInput("^y")
        }
        ToolTipCS("🟢 REHACER", 600)
    } else {
        SendInput("^z")
        ToolTipCS("🔴 DESHACER", 300)
    }
}
$^z up:: {
    stylus.botonSostenido := false
}
!z:: {
    SendInput("^y")
    ToolTipCS("🟢 REHACER", 600)
}

#HotIf stylus.altActive
z:: {
    SendInput("^y")
    ToolTipCS("🟢 REHACER", 600)
}
#HotIf

#HotIf WinActive("ahk_exe CLIPStudioPaint.exe")

; ┌────────────────────┐
; │  5c. HERRAMIENTAS  │
; └────────────────────┘

; ╔═══╗
; ║ A ║
; ╚═══╝
$a:: {
    now := A_TickCount
    if (now - A_state.lastPress < 2400) {
        A_state.lastPress := 0
        SendInput("{F7}")
        MostrarHUD("ALL LAYERS (2)", "FF6B00", 3140)
    } else {
        A_state.lastPress := now
        SendInput("{Blind}a")
        MostrarHUD("LAYER CURRENT (1)", "00E5FF", 950)
    }
}

~RButton & a:: {
    stylus.comboUsado := true
    Send("ñ")
    MostrarHUD("REFERENCE LAYER", "AA44FF", 1680)
}

; ╔═══╗
; ║ E ║
; ╚═══╝
$e:: {
    now := A_TickCount
    if GetKeyState("Shift") {
        Send("e")
        return
    }
    if (now - E.last < 300) {
        SetTimer(__E_SEND_NORMAL, 0)
        E.timerRunning := 0
        Send("l")
        MostrarToolTipE("SOFT ERASER  (2)")
        E.last := 0
        return
    }
    E.last         := now
    E.timerRunning := 1
    SetTimer(__E_SEND_NORMAL, -250)
}

~RButton & e:: {
    stylus.comboUsado := true
    global colorEstado
    if (colorEstado = 2) {
        colorEstado := 0
        Send("k")
        MostrarMiniTexto("🎨 COLOR", "1A1A2E", 1200)
    } else {
        if (colorEstado = 1)
            SendInput("^2")
        colorEstado := 2
        Send("k")
        MostrarMiniTexto("⚪ ALPHA TRANSPARENTE", "1C6EA4", 1200)
        SoundPlay(A_WinDir "\Media\Windows Ding.wav")
    }
}

^e:: {
    MostrarHUD("BORRADOR TODAS LAS CAPAS", "FF4444", 800)
    Send("{F5}")
}

!q:: {
    MostrarToolTipE("FILL  (V)")
    Send("v")
}

!w:: {
    MostrarToolTipE("COLOR BLEND  (D)")
    Send("d")
}

; ╔═══╗
; ║ W ║
; ╚═══╝
$w:: {
    now := A_TickCount
    if (now - W.last < 300) {
        SetTimer(__W_SEND_NORMAL, 0)
        W.timerRunning := 0
        global colorEstado
        if (colorEstado = 2) {
            SendInput("k")
            colorEstado := 0
            SendInput("{Blind}w")
            MostrarMiniTexto("💨 AERÓGRAFO", "1A1A2E", 1200)
        } else {
            if (colorEstado = 1)
                SendInput("^2")
            SendInput("k")
            colorEstado := 2
            SendInput("{Blind}w")
            MostrarMiniTexto("⚪ AERÓGRAFO ALPHA", "1C6EA4", 1200)
            SoundPlay(A_WinDir "\Media\Windows Ding.wav")
        }
        W.last := 0
        return
    }
    W.last         := now
    W.timerRunning := 1
    SetTimer(__W_SEND_NORMAL, -250)
}

; ╔═══╗
; ║ Z ║
; ╚═══╝
; z normal (un solo tap) = z INSTANTÁNEO, con tooltip de lupa 🔍
; z rápido (doble-tap, <300ms) = cancela el z ya enviado con {z up}
;   y lanza r, con tooltip de mano ✋. El primer tap nunca espera.
; Solo aplica cuando stylus.altActive = false — cuando es true, el
; z:: bajo #HotIf stylus.altActive (rehacer) tiene prioridad y este
; ni se evalúa.
$z:: {
    now := A_TickCount
    if (now - Z.last < 300) {
        ; Doble-tap: cancelar el z ya enviado y lanzar r
        Z.last         := 0
        Z.timerRunning := 0
        SendInput("{z up}")
        SendInput("r")
        MostrarToolTipZ("✋ R", 800)
        return
    }
    ; Primer tap: disparar z inmediatamente, sin esperar
    Z.last         := now
    Z.timerRunning := 1
    SendInput("{Blind}z")
    MostrarToolTipZ("🔍 Z", 800)
}

; ╔═══╗
; ║ Q ║
; ╚═══╝
$q:: {
    if GetKeyState("Alt", "P") {
        Send("!q")
        return
    }
    now := A_TickCount
    if (now - Q.last < 300) {
        Q.last := 0
        SetTimer(__Q_SEND_NORMAL, 0)
        global colorEstado
        if (colorEstado = 2) {
            Send("k")
            colorEstado := 0
        }
        SendInput("^2")
        if (colorEstado = 0) {
            colorEstado := 1
            MostrarMiniTextoOscuro("🟡 COLOR SECUNDARIO", "51D67B", 1200)
            SoundPlay(A_WinDir "\Media\Windows Battery Low.wav")
        } else {
            colorEstado := 0
            MostrarMiniTexto("🔵 COLOR PRIMARIO", "2B3B32", 1200)
        }
        return
    }
    Q.last := now
    if GetKeyState("RButton", "P") {
        AlternarEstabilizacion()
        return
    }
    SetTimer(__Q_SEND_NORMAL, -50)
}

*-:: {
    if (stylus.altActive) {
        _ToggleLayerVis()
        return
    }
    AlternarEstabilizacion()
}

_ToggleLayerVis() {
    SendEvent("{Alt up}{Shift down}d{Shift up}")
    MostrarHUD(N6.layerVis ? "🚫 HIDE LAYER" : "👁 SHOW LAYER", N6.layerVis ? "FF4444" : "44DD88", 600)
    N6.layerVis := !N6.layerVis
}

+q:: {
    if (colorV.hover) {
        colorV.hover := false
        if (colorV.dsID && WinExist("ahk_id " colorV.dsID)) {
            colorV.bDS.Hide()
            WinSetTransparent(255,  "ahk_id " colorV.dsID)
            WinSetExStyle("-0x20", "ahk_id " colorV.dsID)
        }
        colorV.dsVis := true
        ar.hover := false
        if (ar.id && WinExist("ahk_id " ar.id)) {
            ar.bAR.Hide()
            WinSetTransparent(255,  "ahk_id " ar.id)
            WinSetExStyle("-0x20", "ahk_id " ar.id)
        }
        ar.dsVis := true
        MostrarMiniTexto("👁 HOVER OFF — paneles visibles", "1A5276", 1200)
    } else {
        colorV.hover := true
        colorV.dsVis := false
        if (colorV.dsID && WinExist("ahk_id " colorV.dsID)) {
            WinSetTransparent(5,    "ahk_id " colorV.dsID)
            WinSetExStyle("+0x20", "ahk_id " colorV.dsID)
        }
        ar.hover := true
        ar.dsVis := false
        if (ar.id && WinExist("ahk_id " ar.id)) {
            WinSetTransparent(5,    "ahk_id " ar.id)
            WinSetExStyle("+0x20", "ahk_id " ar.id)
        }
        MostrarMiniTexto("🟠 HOVER ON — deslizador + acceso rápido", "1E8449", 1200)
    }
}

; ╔═══╗
; ║ S ║
; ╚═══╝
; Alt+S (stylus Alt+B + S miniteclado) → mismo toggle que $s con stylus.altActive

!s:: {
    now := A_TickCount
    if (now - AltS_state.lastPress < 300) {
        AltS_state.lastPress := 0
        SendEvent("{F7}")
        MostrarHUD("ALL LAYERS (2)", "FF6B00", 3140)
    } else {
        AltS_state.lastPress := now
        SendEvent("{Alt up}")
        SendEvent("a")
        MostrarHUD("LAYER CURRENT (1)", "00E5FF", 950)
    }
}

$s:: {
    if (stylus.altActive) {
        now := A_TickCount
        if (now - AltS_state.lastPress < 300) {
            AltS_state.lastPress := 0
            SendEvent("{F7}")
            MostrarHUD("ALL LAYERS (2)", "FF6B00", 3140)
        } else {
            AltS_state.lastPress := now
            SendEvent("{Alt up}")
            SendEvent("a")
            MostrarHUD("LAYER CURRENT (1)", "00E5FF", 950)
        }
        return
    }
    if (A_PriorHotkey = "$s" && A_TimeSincePriorHotkey < 250) {
        S.skipNext := true
        MostrarMiniTexto("🟢 ÁREA CON COLOR", "27AE60", 1200)
        SendInput("^x")
        SendInput("!x")
        SoundPlay(A_WinDir "\Media\Windows Exclamation.wav")
        return
    }
    if GetKeyState("Space", "P") {
        S.skipNext := true
        if (S.estadoCaracter = 0) {
            Send(",")
            MostrarTooltipToggle("AGREGAR A SELECCION", "+", "verde")
            S.estadoCaracter := 1
        } else {
            Send(".")
            MostrarTooltipToggle("ELIMINAR SELECCIÓN", "–", "rojo")
            S.estadoCaracter := 0
        }
        SetTimer(QuitarTooltipToggle, -1500)
        return
    }
    if S.skipNext {
        S.skipNext := false
        return
    }
    Send("s")
}

; ╔═══╗
; ║ O ║
; ╚═══╝
$o:: {
    O.ciclo := Mod(O.ciclo, 3) + 1
    if (O.ciclo = 1) {
        Send("h")
        MostrarMiniTexto("🔍 BUSCAR CAPAS (1/3)", "1A5276", 1200)
    } else if (O.ciclo = 2) {
        SendInput("{Ctrl down}{Numpad1}{Ctrl up}")
        MostrarMiniTexto("🎨 COLOR CAPA (2/3)", "6C3483", 1200)
    } else {
        SendInput("{Ctrl down}{Numpad2}{Ctrl up}")
        MostrarMiniTexto("🗑 BORRAR COLOR CAPA (3/3)", "424949", 1200)
    }
}

$Escape:: {
    if (O.ciclo != 0) {
        O.ciclo := 0
        MostrarMiniTexto("↺ CICLO O RESETADO", "555555", 900)
    }
    global colorEstado
    if (colorEstado = 2) {
        colorEstado := 0
        Send("k")
        MostrarMiniTexto("🎨 ALPHA RESETEADO", "555555", 900)
    }
    if (sel.guiActivo) {
        sel.guiActivo  := false
        sel.estadoAltX := false
        sel.estado     := 0
        Send("{Alt down}{x}{Alt up}")
        SetTimer(ResetEstadoAltX, 0)
        MostrarMiniTexto("↩ SELECCIÓN CANCELADA", "C0392B", 700)
        Send("x")
        Send("{Escape}")
        return
    }
    Send("{Escape}")
}

+r:: {
    MostrarHUD("REFLEJAR HORIZONTAL", "00E5FF", 1500)
    Send("+r")
}

Tab:: AccionEnfoque()
F3::  AccionEnfoque()

; ┌─────────────────────────────────────┐
; │  5d. ATAJOS CON CLIC DERECHO        │
; └─────────────────────────────────────┘
~RButton & s:: {
    stylus.comboUsado := true
    MostrarHUD("LAZO CON AUTORELLENO", "FF6B00", 1200)
    Send("{F9}")
}

~RButton & q:: {
    stylus.comboUsado := true
    Send("!q")
    MostrarHUD("ACCESO RÁPIDO", "AA8844", 800)
}

~RButton & 1::
~RButton & 2::
~RButton & 3::
~RButton & 4::
~RButton & 5::
~RButton & 6::
~RButton & 7::
~RButton & 8::
~RButton & 9::
~RButton & 0:: {
    stylus.comboUsado := true
    key        := SubStr(A_ThisHotkey, StrLen(A_ThisHotkey))
    porcentaje := (key = "0") ? 100 : Integer(key) * 10
    MostrarHUD("OPACIDAD " porcentaje "%", "00E5FF", 1500)
    Send("+" key)
}

; ┌─────────────────────────────────────┐
; │  5e. DIAL — modo tamaño / opacidad  │
; └─────────────────────────────────────┘
; 1 y 2 = subir/bajar tamaño → modo 1
; 3 y 4 = subir/bajar opacidad → modo 2
; NumpadDiv = toggle manual entre modos
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

; ┌─────────────────────────────────────┐
; │  5f. MODIFICADORES DE CAPA          │
; └─────────────────────────────────────┘
~Space & NumpadAdd:: {
    Send("+p")
    MostrarMiniTexto("SPACE  +  +", "1E8449", 700)
}

~Space & NumpadSub:: {
    Send("^+p")
    MostrarMiniTexto("SPACE  +  −", "922B21", 700)
}

~Space & Numpad1::
~Space & Numpad2::
~Space & Numpad3::
~Space & Numpad4::
~Space & Numpad5::
~Space & Numpad6:: {
    tecla := SubStr(A_ThisHotkey, StrLen(A_ThisHotkey))
    tipos := Map("1", "HSV (Hue / Sat / Val)"
               , "2", "Brillo / Contraste"
               , "3", "Equilibrio de color"
               , "4", "Curva de tonos"
               , "5", "Corrección de nivel"
               , "6", "Degradado")
    MostrarHUD("Capa: " tipos[tecla], "AA44FF", 500)
    Send("^!" tecla)
}

$Numpad6:: {
    if (N6.estadoEscala = 0) {
        Send("7")
        MostrarHUD("CAPA ESCALA DE GRISES", "888888", 1200)
        N6.estadoEscala := 1
    } else {
        Send("8")
        MostrarHUD("BORRAR CAPA DE CORRECCIÓN", "FF4444", 1200)
        N6.estadoEscala := 0
    }
}

*Backspace:: {
    if GetKeyState("Space", "P") {
        Send("8")
        MostrarHUD("BORRAR CAPA DE CORRECCIÓN", "FF4444", 1200)
        N6.estadoEscala := 0
        return
    }
    Send("{Backspace}")
}

~Space:: {
    spc.downTick := A_TickCount
}

~Space up:: {
    held := A_TickCount - spc.downTick
    if (held > 180)
        return
    now := A_TickCount
    if (now - spc.last < 320) {
        spc.last := 0
        sel.guiActivo := true
        if sel.estadoAltX {
            MostrarMiniTexto("👁 MOSTRAR BORDE", "2ECC71", 1200)
            sel.estadoAltX := false
        } else {
            MostrarMiniTexto("🚫 OCULTAR BORDE", "E74C3C", 1200)
            sel.estadoAltX := true
        }
        Send("{Alt down}{x}{Alt up}")
        SetTimer(ResetEstadoAltX, -3000)
        return
    }
    spc.last := now
}

#HotIf

; ┌────────────────────────────────────────────────────────────────┐
; │  6. CLASE BorderFrame                                          │
; └────────────────────────────────────────────────────────────────┘
class BorderFrame {
    T := 0
    B := 0
    L := 0
    R := 0

    __New(color) {
        opts := "-Caption +AlwaysOnTop +ToolWindow +E0x20"
        for side in ["T", "B", "L", "R"] {
            g := Gui(opts)
            g.BackColor := color
            g.Show("w0 h0 NoActivate")
            this.%side% := g
        }
    }

    Show(x, y, w, h, g := 1) {
        this.T.Show("x" x           " y" y           " w" w " h" g " NoActivate")
        this.B.Show("x" x           " y" (y + h - g) " w" w " h" g " NoActivate")
        this.L.Show("x" x           " y" y           " w" g " h" h " NoActivate")
        this.R.Show("x" (x + w - g) " y" y           " w" g " h" h " NoActivate")
        WinSetTransparent(120, "ahk_id " this.T.Hwnd)
        WinSetTransparent(120, "ahk_id " this.B.Hwnd)
        WinSetTransparent(120, "ahk_id " this.L.Hwnd)
        WinSetTransparent(120, "ahk_id " this.R.Hwnd)
    }

    Hide() {
        this.T.Hide()
        this.B.Hide()
        this.L.Hide()
        this.R.Hide()
    }
}

; ┌────────────────────────────────────────────────────────────────┐
; │  7. FUNCIONES                                                  │
; └────────────────────────────────────────────────────────────────┘

; ══════════════════════════════════════════════════════════════════
; ObtenerMonitorCSP — devuelve {x, y, w, h} del monitor donde está
; la ventana principal de CSP. Fallback al monitor primario.
; ══════════════════════════════════════════════════════════════════
ObtenerMonitorCSP() {
    if (colorV.cspHwnd) {
        try {
            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " colorV.cspHwnd)
            cx := wx + ww // 2
            cy := wy + wh // 2
            loop MonitorGetCount() {
                MonitorGet(A_Index, &mL, &mT, &mR, &mB)
                if (cx >= mL && cx < mR && cy >= mT && cy < mB)
                    return { x: mL, y: mT, w: mR - mL, h: mB - mT }
            }
        }
    }
    ; Fallback: monitor primario
    pri := MonitorGetPrimary()
    MonitorGet(pri, &mL, &mT, &mR, &mB)
    return { x: mL, y: mT, w: mR - mL, h: mB - mT }
}

IniciarDeteccion() {
    bestHwnd := 0
    bestArea := 0
    for hwnd in WinGetList("ahk_exe CLIPStudioPaint.exe") {
        try {
            WinGetPos(&tx, &ty, &tw, &th, "ahk_id " hwnd)
            if (tw * th > bestArea) {
                bestArea := tw * th
                bestHwnd := hwnd
            }
        }
    }
    colorV.cspHwnd := bestHwnd
    colorV.dsID := BuscarVentanaCSP(0, "eslizador", "colores")
    if (colorV.dsID) {
        colorV.bDS   := BorderFrame("44AA66")
        colorV.hover := true
        colorV.dsVis := false
        WinSetTransparent(5,    "ahk_id " colorV.dsID)
        WinSetExStyle("+0x20", "ahk_id " colorV.dsID)
    }
    ar.id := BuscarVentanaCSP(0, "Acceso r", "pido")
    if (ar.id) {
        ar.bAR   := BorderFrame("AA8844")
        ar.hover := true
        ar.dsVis := false
        WinSetTransparent(5,    "ahk_id " ar.id)
        WinSetExStyle("+0x20", "ahk_id " ar.id)
    }
}

BuscarVentanaCSP(idActual, frag1, frag2) {
    if (idActual) {
        try {
            if WinExist("ahk_id " idActual)
                return idActual
        }
    }
    for hwnd in WinGetList("ahk_exe CLIPStudioPaint.exe") {
        try {
            t := WinGetTitle("ahk_id " hwnd)
            if InStr(t, frag1) && InStr(t, frag2)
                return hwnd
        }
    }
    return 0
}

CheckReload() {
    newTime := FileGetTime(A_ScriptFullPath, "M")
    if (sys.lastModTime = "") {
        sys.lastModTime := newTime
        return
    }
    if (newTime != sys.lastModTime) {
        sys.lastModTime := newTime
        mon := ObtenerMonitorCSP()
        x := mon.x + (mon.w // 2) - 120
        y := mon.y + (mon.h // 2) - 20
        ToolTip("💾 Script actualizado y recargado", x, y)
        SoundBeep(750, 180)
        SoundBeep(950, 180)
        SoundBeep(850, 180)
        Sleep(300)
        ToolTip()
        Reload()
    }
}

ChequearZonaHistorial() {
    if !WinActive("ahk_exe CLIPStudioPaint.exe")
        return
    if (hist.modo = 2)
        return
    MouseGetPos(&mx, &my)
    enZona := (mx >= 1632 && mx <= 3053 && my >= 1078 && my <= 1199)
    if (enZona && !hist.abierto) {
        hist.abierto := true
        Send("{Numpad9}")
    } else if (!enZona && hist.abierto) {
        hist.abierto := false
        Send("{Numpad9}")
    }
}

; ══════════════════════════════════════════════════════════════════
; ChequearZonaAltA — botones IZQUIERDA (3 zonas, recalibradas con
; CALIBRADOR_v3_DPI — DPI awareness correcto). Zonas exactas, sin
; margen, derivadas de los 4 puntos-esquina de cada icono.
;   Botón 1 (P3-P6)  :  x[1365,1403]  y[93,122]
;   Botón 2 (P7-P10) :  x[1363,1403]  y[128,158]
;   Botón 3 (P11-P14):  x[1365,1403]  y[164,197]
; ══════════════════════════════════════════════════════════════════
ChequearZonaAltA() {
    if !WinActive("ahk_exe CLIPStudioPaint.exe")
        return
    MouseGetPos(&mx, &my)
    enZona1 := (mx >= 1364 && mx <= 1404 && my >= 92  && my <= 124)
    if (enZona1 && !btn.b1) {
        btn.b1 := true
        SendEvent("{Click " mx " " my "}")
    } else if (!enZona1 && btn.b1)
        btn.b1 := false
    enZona2 := (mx >= 1361 && mx <= 1406 && my >= 127 && my <= 161)
    if (enZona2 && !btn.b2) {
        btn.b2 := true
        SendEvent("{Click " mx " " my "}")
    } else if (!enZona2 && btn.b2)
        btn.b2 := false
    enZona3 := (mx >= 1361 && mx <= 1405 && my >= 162 && my <= 196)
    if (enZona3 && !btn.b3) {
        btn.b3 := true
        SendEvent("{Click " mx " " my "}")
    } else if (!enZona3 && btn.b3)
        btn.b3 := false
}

; ══════════════════════════════════════════════════════════════════
; ChequearZonaDerecha — botones DERECHA (2 zonas, recalibradas con
; CALIBRADOR_v3_DPI — DPI awareness correcto).
;   Botón 1 (P15-P18): x[3235,3276]  y[90,122]
;   Botón 2 (P19-P22): x[3235,3275]  y[128,158]
; ══════════════════════════════════════════════════════════════════
ChequearZonaDerecha() {
    if !WinActive("ahk_exe CLIPStudioPaint.exe")
        return
    MouseGetPos(&mx, &my)
    enZona1 := (mx >= 3235 && mx <= 3276 && my >= 90  && my <= 122)
    if (enZona1 && !botDer.b1) {
        botDer.b1 := true
        SendEvent("{Click " mx " " my "}")
    } else if (!enZona1 && botDer.b1)
        botDer.b1 := false
    enZona2 := (mx >= 3235 && mx <= 3275 && my >= 128 && my <= 158)
    if (enZona2 && !botDer.b2) {
        botDer.b2 := true
        SendEvent("{Click " mx " " my "}")
    } else if (!enZona2 && botDer.b2)
        botDer.b2 := false
    enZona3 := (mx >= 3235 && mx <= 3275 && my >= 159 && my <= 191)
    if (enZona3 && !botDer.b3) {
        botDer.b3 := true
        SendEvent("{Click " mx " " my "}")
    } else if (!enZona3 && botDer.b3)
        botDer.b3 := false
}

LoopColorV() {
    if (!colorV.hover)
        return
    if !WinActive("ahk_exe CLIPStudioPaint.exe") {
        if (colorV.dsVis && colorV.dsID) {
            colorV.dsVis := false
            WinSetTransparent(5,   "ahk_id " colorV.dsID)
            WinSetExStyle("+0x20", "ahk_id " colorV.dsID)
        }
        if IsObject(colorV.bDS)
            colorV.bDS.Hide()
        return
    }
    if (!colorV.dsID) {
        colorV.dsID := BuscarVentanaCSP(0, "eslizador", "colores")
        if (colorV.dsID) {
            colorV.bDS   := BorderFrame("44AA66")
            colorV.dsVis := false
            WinSetTransparent(5,    "ahk_id " colorV.dsID)
            WinSetExStyle("+0x20", "ahk_id " colorV.dsID)
        }
        return
    }
    try {
        if !WinExist("ahk_id " colorV.dsID) {
            colorV.bDS.Hide()
            colorV.dsID  := 0
            colorV.dsVis := false
            return
        }
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " colorV.dsID)
        if (wx != colorV.dsX || wy != colorV.dsY) {
            colorV.dsX := wx
            colorV.dsY := wy
            colorV.dsW := ww
            colorV.dsH := wh
        } else {
            wx := colorV.dsX
            wy := colorV.dsY
            ww := colorV.dsW
            wh := colorV.dsH
        }
    } catch {
        colorV.bDS.Hide()
        colorV.dsID  := 0
        colorV.dsVis := false
        return
    }
    MouseGetPos(&mx, &my)
    enDS := (mx >= wx && mx <= wx+ww && my >= wy && my <= wy+wh)
    enCirculo := false
    if (!colorV.cspHwnd) {
        bestHwnd := 0
        bestArea := 0
        for hwnd in WinGetList("ahk_exe CLIPStudioPaint.exe") {
            try {
                WinGetPos(&tx, &ty, &tw, &th, "ahk_id " hwnd)
                if (tw * th > bestArea) {
                    bestArea := tw * th
                    bestHwnd := hwnd
                }
            }
        }
        colorV.cspHwnd := bestHwnd
    }
    if (colorV.cspHwnd) {
        try {
            WinGetPos(&cspX, &cspY, &cspW, , "ahk_id " colorV.cspHwnd)
            ccX1 := cspX + cspW - colorV.ccFromRight
            ccY1 := cspY + colorV.ccFromTop
            ccX2 := ccX1 + colorV.ccW
            ccY2 := ccY1 + colorV.ccH
            enCirculo := (mx >= ccX1 && mx <= ccX2 && my >= ccY1 && my <= ccY2)
        } catch {
            colorV.cspHwnd := 0
        }
    }
    if (enDS || enCirculo) {
        if (!colorV.dsVis) {
            colorV.dsVis := true
            WinSetTransparent(255,  "ahk_id " colorV.dsID)
            WinSetExStyle("-0x20", "ahk_id " colorV.dsID)
            colorV.bDS.Hide()
        }
    } else {
        if (colorV.dsVis) {
            colorV.dsVis := false
            WinSetTransparent(5,    "ahk_id " colorV.dsID)
            WinSetExStyle("+0x20", "ahk_id " colorV.dsID)
        }
        if IsObject(colorV.bDS)
            colorV.bDS.Show(wx, wy, ww, wh)
    }
}

LoopAccesoRapido() {
    if (!ar.hover)
        return
    if !WinActive("ahk_exe CLIPStudioPaint.exe") {
        if (ar.dsVis && ar.id) {
            ar.dsVis := false
            WinSetTransparent(5,   "ahk_id " ar.id)
            WinSetExStyle("+0x20", "ahk_id " ar.id)
        }
        if IsObject(ar.bAR)
            ar.bAR.Hide()
        return
    }
    if (!ar.id) {
        ar.id := BuscarVentanaCSP(0, "Acceso r", "pido")
        if (ar.id) {
            ar.bAR   := BorderFrame("AA8844")
            ar.dsVis := false
            WinSetTransparent(5,    "ahk_id " ar.id)
            WinSetExStyle("+0x20", "ahk_id " ar.id)
        }
        return
    }
    try {
        if !WinExist("ahk_id " ar.id) {
            ar.bAR.Hide()
            ar.id    := 0
            ar.dsVis := false
            return
        }
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " ar.id)
    } catch {
        ar.bAR.Hide()
        ar.id    := 0
        ar.dsVis := false
        return
    }
    MouseGetPos(&mx, &my)
    dentro := (mx >= wx && mx <= wx+ww && my >= wy && my <= wy+wh)
    if (dentro) {
        if (!ar.dsVis) {
            ar.dsVis := true
            WinSetTransparent(255,  "ahk_id " ar.id)
            WinSetExStyle("-0x20", "ahk_id " ar.id)
            ar.bAR.Hide()
        }
    } else {
        if (ar.dsVis) {
            ar.dsVis := false
            WinSetTransparent(5,    "ahk_id " ar.id)
            WinSetExStyle("+0x20", "ahk_id " ar.id)
        }
        if IsObject(ar.bAR)
            ar.bAR.Show(wx, wy, ww, wh)
    }
}

__E_SEND_NORMAL() {
    if E.timerRunning {
        global colorEstado
        if (colorEstado = 2) {
            Send("k")
            colorEstado := 0
        }
        Send("e")
        MostrarToolTipE("ERASER  (1)")
        E.timerRunning := 0
        E.last         := 0
    }
}

ResetProcesando() => E.procesando := false

__W_SEND_NORMAL() {
    if W.timerRunning {
        global colorEstado
        SendInput("{Blind}w")
        if (colorEstado = 2)
            MostrarMiniTexto("⚪ AERÓGRAFO ALPHA", "1C6EA4", 1200)
        else
            MostrarMiniTexto("💨 AERÓGRAFO", "1A1A2E", 1200)
        W.timerRunning := 0
        W.last         := 0
    }
}


__Q_SEND_NORMAL() {
    global colorEstado
    SendInput("q")
    if (colorEstado = 1)
        MostrarMiniTextoOscuro("🟡 COLOR SECUNDARIO", "51D67B", 800)
    else if (colorEstado = 2)
        MostrarMiniTexto("⚪ ALPHA TRANSPARENTE", "1C6EA4", 800)
    else
        MostrarMiniTexto("🔵 COLOR PRIMARIO", "2B3B32", 800)
}

AlternarEstabilizacion() {
    if (Q.estadoEstab = 0) {
        SendInput("{Blind}{- " ESTABILIZACION_PASOS "}")
        Q.estadoEstab := 1
        Sleep(10)
        MostrarMiniTexto("🟢 ESTABILIZACIÓN ALTA", "1A5C2A", 1000)
        Loop 3
            SoundBeep(700 + (A_Index * 130), 80)
    } else {
        SendInput("{Blind}{j " ESTABILIZACION_PASOS "}")
        Q.estadoEstab := 0
        Sleep(10)
        MostrarMiniTexto("🔵 ESTABILIZACIÓN BAJA", "1A2E5C", 1000)
    }
}

_CheckGitDone() {
    MostrarHUD("✅ GitHub actualizado", "44DD88", 2000)
    SoundPlay(A_WinDir "\Media\Windows Navigation Start.wav")
}

ResetEstadoAltX() {
    sel.estadoAltX := false
    sel.guiActivo  := false
}

__ResetEstadoC() {
    sel.estadoC := 0
}

; ── ToolTips / HUD ───────────────────────────────────────────────
; Slot 1 : ToolTip nativo — solo CheckReload y ^g (notepad++)
; HUD    : MostrarHUD — GUI estilo dial para todas las herramientas

; ══════════════════════════════════════════════════════════════════
; MostrarHUD — GUI unificada estilo dial para feedback de hotkeys
; Fondo oscuro 1a1a1a, texto bold blanco, barra de color abajo.
; Posición: centro horizontal, 25% desde arriba del monitor CSP.
; colorBarra: hex sin # (ej. "00E5FF"). duracion en ms.
; ══════════════════════════════════════════════════════════════════
MostrarHUD(texto, colorBarra := "00E5FF", duracion := 1200) {
    if IsObject(floatGui.hud) {
        try floatGui.hud.Destroy()
        floatGui.hud := 0
    }
    g := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20")
    g.BackColor := "1a1a1a"
    g.MarginX := 0
    g.MarginY := 0
    WinSetTransparent(210, g)
    lbl := g.Add("Text", "x0 y5 w160 h20 cWhite +0x200 Center", texto)
    lbl.SetFont("s9 bold", "Segoe UI")
    bar := g.Add("Progress", "x0 y27 w160 h4 Background333333")
    bar.Opt("c" colorBarra)
    bar.Value := 100
    g.Show("x2159 y130 w160 h31 NoActivate")
    floatGui.hud := g
    SetTimer(_OcultarHUD, -duracion)
}

_OcultarHUD() {
    if IsObject(floatGui.hud) {
        try floatGui.hud.Destroy()
        floatGui.hud := 0
    }
}

QuitarToolTip()      => ToolTip()
OcultarToolTip()     => ToolTip()
OcultarToolTipAltG() => ToolTip()
OcultarToolTipQ()    => ToolTip()
OcultarIndicador()   => ToolTip()
QuitarToolTipE()     => ToolTip(, , , 3)
QuitarToolTipZ()     => ToolTip(, , , 4)

MostrarIndicador(texto) {
    ToolTip(texto)
    SetTimer(OcultarIndicador, -2500)
}

; Slot 3 exclusivo — no interfiere con QuitarToolTip (slot 1)
MostrarToolTipE(texto, duracion := 2190) {
    MostrarHUD(texto, "FF4444", duracion)
}

; Slot 4 exclusivo — no interfiere con slot 1 ni con MostrarToolTipE (slot 3)
MostrarToolTipZ(texto, duracion := 800) {
    MostrarHUD(texto, "00E5FF", duracion)
}

ToolTipCS(texto, duracion := 800) {
    MostrarHUD(texto, texto = "🟢 REHACER" ? "44DD88" : "FF4444", duracion)
}

CustomToolTip(text, duration := 1500) {
    ToolTip(text, , , 2)
    SetTimer(RemoveCustomToolTip, -duration)
}

RemoveCustomToolTip() => ToolTip(, , , 2)

MostrarMiniTexto(texto, colorHex := "222222", duracion := 800, colorTexto := "FFFFFF") {
    try {
        if IsObject(floatGui.miniTip)
            floatGui.miniTip.Destroy()
    }
    floatGui.miniTip := 0
    thisID := A_TickCount
    floatGui.miniTipID   := thisID
    floatGui.miniTipTick := thisID
    g := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20")
    g.BackColor := colorHex
    g.SetFont("s9 Bold", "Segoe UI")
    g.AddText("c" colorTexto " Center w200", texto)
    g.Show("Hide AutoSize")
    g.GetPos(, , &w, &h)
    mon := ObtenerMonitorCSP()
    targetX := mon.x + (mon.w - w) // 2
    targetY := mon.y + Round(mon.h * 0.47)
    g.Show("x" targetX " y" targetY " w" w " h" h " NoActivate")
    WinSetTransparent(200, "ahk_id " g.Hwnd)
    floatGui.miniTip := g
    capturedID := thisID
    SetTimer(() => _OcultarMiniTipSi(capturedID), -duracion)
}

_OcultarMiniTipSi(id) {
    if (floatGui.miniTipID != id)
        return
    try {
        if IsObject(floatGui.miniTip)
            floatGui.miniTip.Destroy()
    }
    floatGui.miniTip     := 0
    floatGui.miniTipID   := 0
    floatGui.miniTipTick := 0
}

MostrarMiniTextoOscuro(texto, colorHex := "EEEEEE", duracion := 800) {
    MostrarMiniTexto(texto, colorHex, duracion, "000000")
}

OcultarMiniTip() {
    try {
        if IsObject(floatGui.miniTip)
            floatGui.miniTip.Destroy()
    }
    floatGui.miniTip     := 0
    floatGui.miniTipID   := 0
    floatGui.miniTipTick := 0
}

MostrarMiniGUI(texto, colorHex := "222222", duracion := 1200) {
    if IsObject(floatGui.miniGUI)
        floatGui.miniGUI.Destroy()
    g := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20")
    g.BackColor := colorHex
    g.SetFont("s9 Bold", "Segoe UI")
    g.AddText("cFFFFFF Center w200", texto)
    g.Show("Hide AutoSize")
    g.GetPos(, , &w, &h)
    mon := ObtenerMonitorCSP()
    g.Show("x" mon.x + (mon.w - w) // 2 " y" mon.y + Round(mon.h * 0.02) " w" w " h" h " NoActivate")
    WinSetTransparent(200, "ahk_id " g.Hwnd)
    floatGui.miniGUI := g
    SetTimer(OcultarMiniGUI, -duracion)
}

OcultarMiniGUI() {
    if IsObject(floatGui.miniGUI)
        floatGui.miniGUI.Destroy()
    floatGui.miniGUI := 0
}

MostrarTooltipToggle(titulo, simbolo, color) {
    if IsObject(floatGui.tooltipToggle)
        floatGui.tooltipToggle.Destroy()
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    if (color = "verde") {
        g.BackColor := "1F4D3A"
        g.SetFont("s9 Bold cWhite", "Segoe UI")
        simColor := "Lime"
    } else {
        g.BackColor := "D92B2B"
        g.SetFont("s9 Bold cWhite", "Segoe UI")
        simColor := "White"
    }
    g.AddText("x6 y4 w170 h18 Center", titulo)
    g.SetFont("s9 Bold c" simColor, "Segoe UI")
    g.AddText("x178 y3 w18 h18 Center", simbolo)
    mon := ObtenerMonitorCSP()
    g.Show("x" mon.x + (mon.w - 200) // 2 " y" mon.y + Round(mon.h * 0.47) " w200 h26 NoActivate")
    floatGui.tooltipToggle := g
}

QuitarTooltipToggle() {
    if IsObject(floatGui.tooltipToggle)
        floatGui.tooltipToggle.Destroy()
    floatGui.tooltipToggle := 0
}

SendKeyWithBoost(key, startTick) {
    elapsed := A_TickCount - startTick
    if (elapsed < boost.holdDelay)
        return
    ratio := Min((elapsed - boost.holdDelay) / 100, 1)
    b     := Max(Round(boost.maxBoost * (ratio ** 0.1)), 1)
    Loop b
        SendInput("{Blind}" key)
}

; ══════════════════════════════════════════════════════════════════
; AccionEnfoque — clicks de modo enfoque recalibrados con CALIBRADOR_v3_DPI
; (DPI awareness correcto): izquierdo en P1 (1399, 68),
; derecho en P2 (3238, 72).
; ══════════════════════════════════════════════════════════════════
AccionEnfoque() {
    enfoque.activo := !enfoque.activo
    if (enfoque.activo) {
        MostrarGUIEnfoque()
        SoundBeep(1200, 40)
        Sleep(30)
        SoundBeep(1500, 40)
    } else {
        OcultarGUIEnfoque()
    }
    ; Obtener posición del mouse para restaurar después
    MouseGetPos(&origX, &origY)
    ; Click izquierdo — absoluto (1399, 68)
    MouseMove(1399, 68, 0)
    Sleep(8)
    Click()
    Sleep(12)
    ; Click derecho — absoluto (3238, 72)
    MouseMove(3238, 72, 0)
    Sleep(8)
    Click()
    Sleep(12)
    MouseMove(origX, origY, 0)
}

MostrarGUIEnfoque() {
    if IsObject(floatGui.enfoque)
        floatGui.enfoque.Destroy()
    g := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20")
    g.BackColor := "1A1A2E"
    g.SetFont("s9 Bold", "Segoe UI")
    g.AddText("cFFFFFF Center", "🎯 MODO ENFOQUE")
    g.Show("Hide AutoSize")
    g.GetPos(, , &w, &h)
    mon := ObtenerMonitorCSP()
    g.Show("x" mon.x + (mon.w - w) // 2 " y" mon.y + Round(mon.h * 0.47) " w" w " h" h " NoActivate")
    WinSetTransparent(210, "ahk_id " g.Hwnd)
    floatGui.enfoque := g
}

OcultarGUIEnfoque() {
    if !IsObject(floatGui.enfoque)
        return
    g := floatGui.enfoque
    floatGui.enfoque := 0
    try {
        Loop 7 {
            transp := 210 - (A_Index * 30)
            if (transp < 0)
                transp := 0
            WinSetTransparent(transp, "ahk_id " g.Hwnd)
            Sleep(30)
        }
        g.Destroy()
    } catch {
        try g.Destroy()
    }
}

ResetEnfoque() {
    if (enfoque.activo) {
        enfoque.activo := false
        OcultarGUIEnfoque()
    }
}

ResetAlphaStates() {
    global colorEstado
    if !WinActive("ahk_exe CLIPStudioPaint.exe") {
        if (colorEstado = 2)
            Send("k")
        if (colorEstado = 1)
            SendInput("^2")
        colorEstado := 0
        if IsObject(dial.g)
            dial.g.Hide()
        return
    }
    ; Restaurar dial si CSP recuperó el foco
    if IsObject(dial.g) {
        try {
            if !DllCall("IsWindowVisible", "Ptr", dial.g.Hwnd)
                dial.g.Show("NoActivate")
        }
    }
    ; Watchdog miniTip
    if (floatGui.miniTipID != 0 && floatGui.miniTipTick != 0) {
        if (A_TickCount - floatGui.miniTipTick > 4000) {
            try {
                if IsObject(floatGui.miniTip)
                    floatGui.miniTip.Destroy()
            }
            floatGui.miniTip     := 0
            floatGui.miniTipID   := 0
            floatGui.miniTipTick := 0
        }
    }
}

#HotIf WinActive("ahk_exe CLIPStudioPaint.exe")
~RButton & f:: {
    stylus.comboUsado := true
    global colorEstado
    if (colorEstado = 1)
        SendInput("^2")
    Send("k")
    Send("k")
    colorEstado := 0
    MostrarMiniTexto("🔄 RESET → COLOR PRIMARIO", "1A1A2E", 1200)
}
#HotIf

; ┌──────────────────────────────────────────────────────────┐
; │  DIAL GUI — indicador permanente de modo del dial        │
; └──────────────────────────────────────────────────────────┘
IniciarDialGUI() {
    global dial
    dial.g := Gui("+AlwaysOnTop -Caption +ToolWindow", "")
    dial.g.BackColor := "1a1a1a"
    dial.g.MarginX := 0
    dial.g.MarginY := 0
    WinSetTransparent(128, dial.g)

    dial.icono := dial.g.Add("Text", "x6 y4 w24 h22 +0x200 cWhite", "")
    dial.icono.SetFont("s14 bold", "Segoe UI")

    dial.label := dial.g.Add("Text", "x34 y5 w88 h20 cWhite", "")
    dial.label.SetFont("s10 bold", "Segoe UI")

    dial.barra := dial.g.Add("Progress", "x0 y27 w130 h4 Background333333")

    OnMessage(0x0201, _DialWM_LBUTTONDOWN)

    ; P1: (2421, 21) — coordenada indicada
    dial.g.Show("x2356 y5 w130 h31 NoActivate")
    ActualizarDialGUI()
}

ActualizarDialGUI() {
    global dial
    if (dial.modo = 1) {
        dial.icono.Value := "🖌"
        dial.label.Value := "Tamaño"
        dial.barra.Opt("c00e5ff")
        dial.barra.Value := 100
    } else {
        dial.icono.Value := "◑"
        dial.label.Value := "Opacidad"
        dial.barra.Opt("cff6b00")
        dial.barra.Value := 100
    }
}

_DialWM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global dial
    if (hwnd = dial.g.Hwnd || dial.g.Hwnd = DllCall("GetParent", "Ptr", hwnd, "Ptr"))
        PostMessage(0x00A1, 2, 0,, "ahk_id " dial.g.Hwnd)
}
