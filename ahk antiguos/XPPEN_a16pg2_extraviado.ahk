; ┌─────────────────────────────────────────────────────────┐
; │  🎨 CSP ARTIST_PRO_16_GEN2 — SCRIPT TABLET ÚNICA  v52     │
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
; Auto-elevación: CSP puede correr como admin (tras updates); si el script
; no está al mismo nivel, WinSetTransparent/WinSetExStyle fallan con Error 5 (UIPI).
if !A_IsAdmin {
    try {
        Run('*RunAs "' A_ScriptFullPath '"')
    }
    ExitApp()
}
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
stylus := { altActive: false, rButtonHeld: false, comboUsado: false, upSinteticoTick: 0, botonSostenido: false, smearSend: false, ignorarUpSintetico: false, origX: 0, origY: 0 }
sel := { estado: 0, estadoAltX: false, estadoC: 0, guiActivo: false, sRapido: false }
colorEstado     := 0   ; 0=primario  1=secundario  2=alpha
E := { procesando: false, last: 0 }
W := { last: 0 }
Z := { last: 0, timerRunning: 0 }
Q := { last: 0, estadoEstab: 0 }
A_state := { lastPress: 0 }
AltS_state    := { lastPress: 0 }
AltB_s_state  := { lastPress: 0, timerRunning: 0 }
AltB_a_state  := { lastPress: 0, timerRunning: 0 }
AltF_state    := { lastPress: 0, timerRunning: 0 }
S := { estadoCaracter: 0, skipNext: false }
O := { ciclo: 0 }
N6 := { estadoEscala: 0, layerVis: 1 }
hist := { abierto: false, modo: 1 }
btn := { b1: false, b2: false, b3: false }
botDer := { b1: false, b2: false, b3: false }
colorV := {
    dsID: 0, dsVis: false, bDS: 0, hover: true, cspHwnd: 0,
    dsX: 0, dsY: 0, dsW: 0, dsH: 0
}
; Círculo de colores — ventana flotante independiente (igual que deslizador)
colorCC := {
    id: 0, dsVis: false, bCC: 0, hover: true,
    ccX: 0, ccY: 0, ccW: 0, ccH: 0
}
ar := { id: 0, dsVis: false, bAR: 0, hover: true }
floatGui := { miniTip: 0, miniGUI: 0, tooltipToggle: 0, enfoque: 0, miniTipTick: 0, miniTipID: 0, hud: 0 }
enfoque := { activo: false }
boost := { holdDelay: 300, maxBoost: 5 }
spc := { last: 0, downTick: 0 }
dial := { modo: 1, g: 0, icono: 0, label: 0, barra: 0 }
dsGui := { g: 0, icono: 0, label: 0, barra: 0 }
ccGui := { g: 0, icono: 0, label: 0, barra: 0 }
arGui := { g: 0, icono: 0, label: 0, barra: 0 }
hcGui := { g: 0, icono: 0, label: 0, barra: 0 }
reloadGui := { g: 0, icono: 0, label: 0, barra: 0 }
; Separación (px) entre paneles del bloque Slider/Circle/Quick. Antes se
; usaban offsets fijos (+84/+168) asumiendo 80px reales por panel; con
; escalado de Windows (DPI) eso no siempre se cumplía y los paneles
; terminaban pisándose. Ahora cada panel se coloca a partir del ancho
; REAL del anterior (medido con WinGetPos), y esta constante es solo el
; margen que se deja entre uno y el siguiente.
PANEL_GAP := 6

; ┌──────────────────────────────────────────────────────────────────────┐
; │  3. TIMERS                                                           │
; └──────────────────────────────────────────────────────────────────────┘
SetTimer(CheckReload,            600)
SetTimer(ChequearZonaHistorial,  200)
SetTimer(ChequearZonaAltA,        10)
SetTimer(ChequearZonaDerecha,     10)
SetTimer(LoopColorV,              80)
SetTimer(LoopColorCC,             80)
SetTimer(LoopAccesoRapido,        80)
SetTimer(ResetEnfoque,         10000)
SetTimer(ResetAlphaStates,       500)
IniciarDeteccion()
IniciarDialGUI()
IniciarDsGUI()
IniciarCcGUI()
IniciarArGUI()
IniciarHCGUI()
IniciarReloadGUI()

; ┌──────────────────────────────────────────────────────┐
; │  4. HOTKEYS GLOBALES                                 │
; └──────────────────────────────────────────────────────┘
EsEditorTexto() => WinActive("ahk_exe notepad++.exe") || WinActive("ahk_exe notepad.exe")

#HotIf EsEditorTexto()
^s:: {
    SendInput("^s")
    Sleep(200)
    Reload()
}
^g:: {
    ; Doble chequeo: abortar si no es un editor de texto permitido
    if !(WinActive("ahk_exe notepad++.exe") || WinActive("ahk_exe notepad.exe"))
        return
    ts       := FormatTime(, "yyyy-MM-dd_HH-mm-ss")
    repoPath := "C:\Users\JOSUE\Desktop\AHK-global-main"
    gitExe   := "git"
    cmd      := gitExe ' -C "' repoPath '" add -A'
             .  ' && ' gitExe ' -C "' repoPath '" commit -m "auto_' ts '"'
             .  ' && ' gitExe ' -C "' repoPath '" push'
    Run('cmd /k "' cmd ' && timeout /t 3 && exit"', , "")
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

; ── DEBUG TEMPORAL (F11) — quitar en producción ──────────────────
F11:: {
    info := "colorCC.id = " colorCC.id "`n`n"
    for hwnd in WinGetList("ahk_exe CLIPStudioPaint.exe") {
        try {
            t := WinGetTitle("ahk_id " hwnd)
            if (t = "")
                continue
            hit1 := InStr(t, "rculo de colores") ? "✓rculo " : "✗rculo "
            hit2 := InStr(t, "eslizador")        ? "✓esliz " : "✗esliz "
            info .= hit1 hit2 "[" t "]`n"
        }
    }
    MsgBox(info, "DEBUG colorCC", "OK")
}
; ─────────────────────────────────────────────────────────────────

; ┌──────────────────────────────────────────┐
; │  5a. RBUTTON GLOBAL — fuera de #HotIf   │
; │  Sin #HotIf para que Space & RButton    │
; │  no anule el standalone como prefix key │
; └──────────────────────────────────────────┘
; ┌──────────────────┐
; │  5. HOTKEYS CSP  │
; └──────────────────┘
#HotIf WinActive("ahk_exe CLIPStudioPaint.exe")

RButton:: {
    stylus.rButtonHeld     := true
    stylus.comboUsado      := false
    stylus.upSinteticoTick := 0
    ; Sin tilde — bloquea el down completamente, CSP no ve nada.
}
RButton up:: {
    elapsed := (stylus.upSinteticoTick > 0) ? (A_TickCount - stylus.upSinteticoTick) : 9999
    if (elapsed < UP_SINTETICO_MS) {
        stylus.rButtonHeld     := true
        stylus.upSinteticoTick := 0
        return
    }
    stylus.rButtonHeld := false
    if (!stylus.comboUsado)
        SendInput("{RButton}")   ; cuentagotas al soltar
}

Space & RButton:: {
    stylus.comboUsado := true
    SendInput("!g")
    MostrarHUD("FLIP HORIZONTAL", "888888", 700)
    SoundBeep(800, 100)
}

Numpad0:: {
    hcOn := _ToggleHistorialColor()
    ActualizarHCGUI()
    MostrarHUD(hcOn ? "🟢 DYNAMIC HISTORY" : "🔒 HISTORY LOCKED", hcOn ? "00E5FF" : "FF6B00", 5000)
}

; Devuelve true si el historial quedó dinámico (ON), false si bloqueado (OFF).
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
    SoundBeep(600, 100)
    SoundBeep(900, 150)
    MostrarHUD("💾 GUARDADO Y MODIFICADO", "44DD88", 800)
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

; Pasos de la estabilización: rango real 7→87. El comentario viejo decía
; "5 por pulsación" pero la prueba real (13 pulsaciones, 7→20) confirma
; que CSP mueve 1 unidad exacta por pulsación, no 5. Techo deseado: 75.
; Pulsar (75-7) = 68 veces desde el mínimo real (7) para aterrizar en 75.
; Para reajustar el techo, recalcula: objetivo - 7.
ESTABILIZACION_PASOS := 68


~!b:: {
    if (stylus.smearSend)
        return
    stylus.altActive := true
}
~!b up:: {
    ; Forzamos el estado real de Alt a "arriba" justo aquí, sin importar
    ; qué haya dejado cualquier SendEvent("{Alt up}X{Alt down}") de los
    ; handlers de arriba (x/w/-/e/s con Alt+B sostenido). Esto evita que
    ; stylus.altActive se quede pegado en true si el "up" físico llega
    ; justo en medio de uno de esos toggles sintéticos.
    Send("{Alt up}")
    stylus.altActive := false
    if (stylus.smearSend) {
        stylus.smearSend := false
        SendInput("b")
        MostrarHUD("SMEAR", "AA44FF", 950)
    }
}

; ┌───────────────────────────────┐
; │  5a. SELECCIÓN Y RESELECCIÓN  │
; └───────────────────────────────┘

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
    if stylus.altActive
        return
    if (sel.sRapido) {
        sel.sRapido := false
        MostrarMiniTexto("❌ DESELECCIÓN", "C0392B", 700)
        Send("x")
        sel.estado := 1
        return
    }
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
    if (stylus.rButtonHeld || stylus.altActive) {
        stylus.comboUsado := true
        if (!stylus.botonSostenido) {
            stylus.botonSostenido := true
            if (stylus.rButtonHeld) {
                ; RButton: mandar up sintético para desbloquear CSP
                stylus.upSinteticoTick := A_TickCount
                MouseGetPos(&origX, &origY)
                MouseMove(1589, 3, 0)         ; zona segura fuera del lienzo (P27, Artist Pro 16 Gen2) — no cambia color
                SendInput("{RButton up}")     ; libera RButton a nivel de CSP
                SendInput("^y")
                MouseMove(origX, origY, 0)
            } else {
                ; altActive (Alt+B): no hay RButton sostenido, rehacer directo
                SendInput("^y")
            }
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
; Alt+B (altActive) + Ctrl+Z — Alt físico sostenido intercepta antes de $^z,
; por eso se registra como !^z separado. botonSostenido comparte el mismo flag
; para que key repeat funcione igual que con RButton.
!^z:: {
    if (!stylus.botonSostenido) {
        stylus.botonSostenido := true
        SendInput("^y")
    } else {
        SendInput("^y")
    }
    ToolTipCS("🟢 REHACER", 600)
}
!^z up:: {
    stylus.botonSostenido := false
}

#HotIf stylus.altActive
z:: {
    SendInput("^y")
    ToolTipCS("🟢 REHACER", 600)
}
w:: {
    _ToggleLayerVis()
}
-:: {
    _CicloO()
}
e:: {
    MostrarHUD("ALL LAYERS ERASER", "FF4444", 800)
    Send("{F5}")
}
; SWAP: x/a ahora disparan color mix/smudge (antes era layer/all layers);
; s ahora dispara layer/all layers (antes era color mix/smudge).
x:: {
    if (AltB_a_state.lastPress = 1) {
        AltB_a_state.lastPress := 0
        SendEvent("p")
        MostrarHUD("SMUDGE  (P)", "FF6B00", 950)
    } else {
        AltB_a_state.lastPress := 1
        SendEvent("d")
        MostrarHUD("COLOR MIX  (D)", "FF8C42", 950)
    }
}
a:: {
    now := A_TickCount
    if (now - AltB_a_state.lastPress < 2400) {
        AltB_a_state.lastPress := 0
        Send("p")
        MostrarHUD("SMUDGE  (P)", "FF6B00", 950)
    } else {
        AltB_a_state.lastPress := now
        Send("d")
        MostrarHUD("COLOR MIX  (D)", "FF8C42", 950)
    }
}
s:: {
    now := A_TickCount
    if (now - AltB_s_state.lastPress < 2400) {
        AltB_s_state.lastPress := 0
        SendInput("{F7}")
        MostrarHUD("ALL LAYERS (2)", "FF6B00", 3140)
    } else {
        AltB_s_state.lastPress := now
        SendInput("{Blind}a")
        MostrarHUD("LAYER CURRENT (1)", "00E5FF", 950)
    }
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
    if stylus.altActive
        return
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
    global colorEstado
    now := A_TickCount
    if GetKeyState("Shift") {
        Send("e")
        return
    }
    ; Doble-tap (<300ms): cancelar el e ya enviado y lanzar l (soft eraser)
    if (now - E.last < 300) {
        E.last := 0
        SendInput("{e up}")
        if (colorEstado = 2) {
            Send("k")
            colorEstado := 0
        }
        Send("l")
        MostrarToolTipE("SOFT ERASER  (2)")
        return
    }
    ; Tap simple: mandar e inmediatamente
    E.last := now
    if (colorEstado = 2) {
        Send("k")
        colorEstado := 0
    }
    Send("e")
    MostrarToolTipE("ERASER  (1)")
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
    MostrarHUD("ALL LAYERS ERASER", "FF4444", 800)
    Send("{F5}")
}

!e:: {
    MostrarHUD("ALL LAYERS ERASER", "FF4444", 800)
    Send("{F5}")
}

!q:: {
    MostrarToolTipE("FILL  (V)")
    Send("v")
}

!Space:: {
    _ToggleLayerVis()
}

!-:: {
    _CicloO()
}

; ╔═══╗
; ║ W ║
; ╚═══╝
$w:: {
    global colorEstado
    now := A_TickCount
    ; Doble-tap (<300ms): toggle alpha y reseleccionar w
    if (now - W.last < 300) {
        W.last := 0
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
        return
    }
    ; Tap simple: mandar w inmediatamente
    W.last := now
    SendInput("{Blind}w")
    MostrarMiniTexto(colorEstado = 2 ? "⚪ AERÓGRAFO ALPHA" : "💨 AERÓGRAFO", colorEstado = 2 ? "1C6EA4" : "1A1A2E", 1200)
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
    AlternarEstabilizacion()
}

_ToggleLayerVis() {
    SendEvent("{Alt up}{Shift down}d{Shift up}")
    MostrarHUD(N6.layerVis ? "🚫 HIDE LAYER" : "👁 SHOW LAYER", N6.layerVis ? "FF4444" : "44DD88", 600)
    N6.layerVis := !N6.layerVis
}

+q:: {
    hoverOn := _ToggleHoverPaneles()
    ActualizarDsGUI()
    ActualizarCcGUI()
    ActualizarArGUI()
    if (hoverOn)
        MostrarMiniTexto("🟠 HOVER ON — deslizador + círculo + acceso rápido", "1E8449", 1200)
    else
        MostrarMiniTexto("👁 HOVER OFF — paneles visibles", "1A5276", 1200)
}

; ── Alt+J — mismo toggle que +q, refleja el estado en los 3 botones ──
!j:: {
    hoverOn := _ToggleHoverPaneles()
    ActualizarDsGUI()
    ActualizarCcGUI()
    ActualizarArGUI()
    if (hoverOn)
        MostrarTooltipToggle("HOVER ACTIVO", "▶", "verde")
    else
        MostrarTooltipToggle("HOVER PAUSADO", "⏸", "rojo")
}

; ══════════════════════════════════════════════════════════════════
; _SetColorV / _SetColorCC / _SetAR — fuerzan el panel correspondiente
; al estado "on" indicado (true=hover activo, false=panel fijo visible).
; Devuelven el mismo "on" recibido. Son la base de los toggles
; individuales (botones separados) y del toggle combinado (+q/Alt+J).
; ══════════════════════════════════════════════════════════════════
; ══════════════════════════════════════════════════════════════════
; _FadeAlpha — transición gradual de opacidad en vez de un salto
; instantáneo (5→255 o 255→5). El salto brusco es lo que se percibía
; como un "refresh"/destello al activar-desactivar el modo fijo-visible
; de estos paneles reales de CSP. Con 6 pasos de ~10ms (≈60ms total)
; el cambio se ve como un fundido rápido, no como un parpadeo.
; ══════════════════════════════════════════════════════════════════
_FadeAlpha(hwnd, hasta, pasos := 6, delayMs := 10) {
    try actual := WinGetTransparent("ahk_id " hwnd)
    if (actual = "" || !IsNumber(actual))
        actual := hasta
    if (actual = hasta)
        return
    paso := (hasta - actual) / pasos
    valor := actual
    Loop pasos {
        valor += paso
        v := Round(valor)
        v := (v < 0) ? 0 : (v > 255 ? 255 : v)
        try WinSetTransparent(v, "ahk_id " hwnd)
        Sleep(delayMs)
    }
    try WinSetTransparent(hasta, "ahk_id " hwnd)
}

_SetColorV(on) {
    colorV.hover := on
    colorV.dsVis := !on
    if (colorV.dsID && WinExist("ahk_id " colorV.dsID)) {
        SetTimer(LoopColorV, 0)
        if (on) {
            _FadeAlpha(colorV.dsID, 5)
            WinSetExStyle("+0x20", "ahk_id " colorV.dsID)
        } else {
            colorV.bDS.Hide()
            WinSetExStyle("-0x20", "ahk_id " colorV.dsID)
            _FadeAlpha(colorV.dsID, 255)
        }
        SetTimer(LoopColorV, 80)
    }
    return on
}

_SetColorCC(on) {
    colorCC.hover := on
    colorCC.dsVis := !on
    if (colorCC.id && WinExist("ahk_id " colorCC.id)) {
        SetTimer(LoopColorCC, 0)
        if (on) {
            _FadeAlpha(colorCC.id, 5)
            WinSetExStyle("+0x20", "ahk_id " colorCC.id)
        } else {
            colorCC.bCC.Hide()
            WinSetExStyle("-0x20", "ahk_id " colorCC.id)
            _FadeAlpha(colorCC.id, 255)
        }
        SetTimer(LoopColorCC, 80)
    }
    return on
}

_SetAR(on) {
    ar.hover := on
    ar.dsVis := !on
    if (ar.id && WinExist("ahk_id " ar.id)) {
        SetTimer(LoopAccesoRapido, 0)
        if (on) {
            _FadeAlpha(ar.id, 5)
            WinSetExStyle("+0x20", "ahk_id " ar.id)
        } else {
            ar.bAR.Hide()
            WinSetExStyle("-0x20", "ahk_id " ar.id)
            _FadeAlpha(ar.id, 255)
        }
        SetTimer(LoopAccesoRapido, 80)
    }
    return on
}

; Toggles individuales — usados por el click de cada botón GUI propio.
_ToggleColorV()  => _SetColorV(!colorV.hover)
_ToggleColorCC() => _SetColorCC(!colorCC.hover)
_ToggleAR()      => _SetAR(!ar.hover)

; ══════════════════════════════════════════════════════════════════
; _ToggleHoverPaneles — pausa/reactiva los 3 paneles flotantes juntos
; (deslizador de color, círculo de colores, acceso rápido), tomando
; colorV como referencia del estado actual. Devuelve true si quedaron
; ON, false si quedaron OFF. Compartida por +q y Alt+J.
; ══════════════════════════════════════════════════════════════════
_ToggleHoverPaneles() {
    target := !colorV.hover
    _SetColorV(target)
    _SetColorCC(target)
    _SetAR(target)
    return target
}

; ╔═══╗

; ║ S ║
; ╚═══╝
; Alt+S (stylus Alt+B + S miniteclado) → mismo toggle que $s con stylus.altActive

; SWAP: !x ahora dispara color mix/smudge (antes layer/all layers);
; !s ahora dispara layer/all layers (antes color mix/smudge).
!x:: {
    if !stylus.altActive
        return
    now := A_TickCount
    if (now - AltB_a_state.lastPress < 300) {
        SetTimer(__AltX_SEND_NORMAL, 0)
        AltB_a_state.timerRunning := 0
        AltB_a_state.lastPress := 0
        SendEvent("{Alt up}p{Alt down}")
        MostrarHUD("SMUDGE  (P)", "FF6B00", 950)
        return
    }
    AltB_a_state.lastPress     := now
    AltB_a_state.timerRunning  := 1
    SetTimer(__AltX_SEND_NORMAL, -250)
}

__AltX_SEND_NORMAL() {
    if !AltB_a_state.timerRunning
        return
    AltB_a_state.timerRunning := 0
    ; Mismo caso que __AltF_SEND_NORMAL — ver comentario ahí.
    seguiaSostenido := stylus.altActive
    SendEvent("{Alt up}d")
    if (seguiaSostenido)
        SendEvent("{Alt down}")
    MostrarHUD("COLOR MIX  (D)", "FF8C42", 950)
}

!s:: {
    if !stylus.altActive
        return
    now := A_TickCount
    if (now - AltB_s_state.lastPress < 300) {
        SetTimer(__AltS_SEND_NORMAL, 0)
        AltB_s_state.timerRunning := 0
        AltB_s_state.lastPress := 0
        SendEvent("{Alt up}{F7}{Alt down}")
        MostrarHUD("ALL LAYERS (2)", "FF6B00", 3140)
        return
    }
    AltB_s_state.lastPress     := now
    AltB_s_state.timerRunning  := 1
    SetTimer(__AltS_SEND_NORMAL, -250)
}

__AltS_SEND_NORMAL() {
    if !AltB_s_state.timerRunning
        return
    AltB_s_state.timerRunning := 0
    ; Mismo caso que __AltF_SEND_NORMAL — ver comentario ahí.
    seguiaSostenido := stylus.altActive
    SendEvent("{Alt up}a")
    if (seguiaSostenido)
        SendEvent("{Alt down}")
    MostrarHUD("LAYER CURRENT (1)", "00E5FF", 950)
}

$s:: {
    if stylus.altActive
        return
    ; Si Alt físico está presionado (!s lo maneja), no hacer nada
    if GetKeyState("Alt", "P")
        return
    if (stylus.altActive) {
        Send("d")
        MostrarHUD("COLOR MIX  (D)", "FF8C42", 950)
        return
    }
    if ((A_PriorHotkey = "$s" || A_PriorHotkey = "s") && A_TimeSincePriorHotkey < 250) {
        S.skipNext := true
        sel.sRapido := true
        MostrarMiniTexto("🟢 ÁREA CON COLOR", "27AE60", 1200)
        SendInput("^x")
        SendEvent("{F7}")
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
    SetTimer(() => MostrarHUD("LASSO", "FF6B00", 950), -1)
}

; ╔═══╗
; ║ O ║
; ╚═══╝
$o:: {
    _CicloO()
}

_CicloO() {
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

; f rápido (doble toque en <300ms) = mismo botón de modo enfoque.
; Con ~ para dejar pasar la f normal — solo actúa en el segundo toque rápido.
~f:: {
    static ultimoF := 0
    ahora := A_TickCount
    if (ahora - ultimoF < 300) {
        AccionEnfoque()
        ultimoF := 0
    } else {
        ultimoF := ahora
    }
}

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
    Send("{Shift}")
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

; ── PANIC BUTTON — reinicio de emergencia de todas las GUIs ──────
Numpad8:: {
    _LimpiarGUIs()
    ; Destruir dial incondicionalmente con fallback nuclear
    dialHwnd := 0
    try dialHwnd := dial.g.Hwnd
    try dial.g.Destroy()
    if (dialHwnd && DllCall("IsWindow", "Ptr", dialHwnd))
        DllCall("DestroyWindow", "Ptr", dialHwnd)
    dial.g     := 0
    dial.icono := 0
    dial.label := 0
    dial.barra := 0
    ; Desregistrar OnMessage antes de recrear, evita acumulación de handlers
    try OnMessage(0x0201, _DialWM_LBUTTONDOWN, 0)
    IniciarDialGUI()
    ; Mismo tratamiento para los botones SLIDER / CIRCLE / QUICK ON-OFF
    dsHwnd := 0
    try dsHwnd := dsGui.g.Hwnd
    try dsGui.g.Destroy()
    if (dsHwnd && DllCall("IsWindow", "Ptr", dsHwnd))
        DllCall("DestroyWindow", "Ptr", dsHwnd)
    dsGui.g     := 0
    dsGui.icono := 0
    dsGui.label := 0
    dsGui.barra := 0
    try OnMessage(0x0201, _DsGUI_WM_LBUTTONDOWN, 0)
    IniciarDsGUI()

    ccHwnd := 0
    try ccHwnd := ccGui.g.Hwnd
    try ccGui.g.Destroy()
    if (ccHwnd && DllCall("IsWindow", "Ptr", ccHwnd))
        DllCall("DestroyWindow", "Ptr", ccHwnd)
    ccGui.g     := 0
    ccGui.icono := 0
    ccGui.label := 0
    ccGui.barra := 0
    try OnMessage(0x0201, _CcGUI_WM_LBUTTONDOWN, 0)
    IniciarCcGUI()

    arHwnd := 0
    try arHwnd := arGui.g.Hwnd
    try arGui.g.Destroy()
    if (arHwnd && DllCall("IsWindow", "Ptr", arHwnd))
        DllCall("DestroyWindow", "Ptr", arHwnd)
    arGui.g     := 0
    arGui.icono := 0
    arGui.label := 0
    arGui.barra := 0
    try OnMessage(0x0201, _ArGUI_WM_LBUTTONDOWN, 0)
    IniciarArGUI()
    ; Mismo tratamiento para el botón HC ON/OFF
    hcHwnd := 0
    try hcHwnd := hcGui.g.Hwnd
    try hcGui.g.Destroy()
    if (hcHwnd && DllCall("IsWindow", "Ptr", hcHwnd))
        DllCall("DestroyWindow", "Ptr", hcHwnd)
    hcGui.g     := 0
    hcGui.icono := 0
    hcGui.label := 0
    hcGui.barra := 0
    try OnMessage(0x0201, _HCGUI_WM_LBUTTONDOWN, 0)
    IniciarHCGUI()
    ToolTip("🔄 GUIs reiniciadas")
    SetTimer(() => ToolTip(), -1000)
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
        ; Usar SetWindowPos directo (bypass del scaling de Gui.Show).
        ; Gui.Show interpreta coords como lógicas del monitor primario (dpi=120)
        ; y las escala — SetWindowPos recibe coords físicas del sistema directamente.
        SWP_NOACTIVATE := 0x10
        SWP_SHOWWINDOW := 0x40
        flags := SWP_NOACTIVATE | SWP_SHOWWINDOW
        DllCall("SetWindowPos", "Ptr", this.T.Hwnd, "Ptr", -1, "Int", x,       "Int", y,           "Int", w, "Int", g, "UInt", flags)
        DllCall("SetWindowPos", "Ptr", this.B.Hwnd, "Ptr", -1, "Int", x,       "Int", y + h - g,   "Int", w, "Int", g, "UInt", flags)
        DllCall("SetWindowPos", "Ptr", this.L.Hwnd, "Ptr", -1, "Int", x,       "Int", y,           "Int", g, "Int", h, "UInt", flags)
        DllCall("SetWindowPos", "Ptr", this.R.Hwnd, "Ptr", -1, "Int", x + w - g, "Int", y,         "Int", g, "Int", h, "UInt", flags)
        ; Opacidad reducida (120→85 de 255) para que el marco sea más sutil.
        WinSetTransparent(85, "ahk_id " this.T.Hwnd)
        WinSetTransparent(85, "ahk_id " this.B.Hwnd)
        WinSetTransparent(85, "ahk_id " this.L.Hwnd)
        WinSetTransparent(85, "ahk_id " this.R.Hwnd)
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
    colorCC.id := BuscarVentanaCSP(0, "rculo de colores", "olores")
    if (colorCC.id) {
        colorCC.bCC   := BorderFrame("AA6622")
        colorCC.hover := true
        colorCC.dsVis := false
        WinSetTransparent(5,    "ahk_id " colorCC.id)
        WinSetExStyle("+0x20", "ahk_id " colorCC.id)
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

; ══════════════════════════════════════════════════════════════════
; ChequearZonaHistorial — franja "peek" del panel Historial de color,
; recalibrada con CALIBRADOR_v3_DPI en la Artist Pro 16 Gen2.
;   Zona (P27-P30): x[314,2231]  y[1397,1599]
; ══════════════════════════════════════════════════════════════════
ChequearZonaHistorial() {
    if !WinActive("ahk_exe CLIPStudioPaint.exe")
        return
    if sys.modoEscritura
        return
    if (hist.modo = 2)
        return
    MouseGetPos(&mx, &my)
    enZona := (mx >= 314 && mx <= 2231 && my >= 1397 && my <= 1599)
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
; CALIBRADOR_v3_DPI en la Artist Pro 16 Gen2 — DPI awareness correcto).
; Zonas exactas, sin margen, derivadas de los 4 puntos-esquina de cada icono.
;   Botón 1 (P3-P6)   :  x[3,54]   y[108,146]
;   Botón 2 (P7-P10)  :  x[4,54]   y[149,189]
;   Botón 3 (P11-P14) :  x[3,54]   y[193,229]
; ══════════════════════════════════════════════════════════════════
ChequearZonaAltA() {
    if !WinActive("ahk_exe CLIPStudioPaint.exe")
        return
    if sys.modoEscritura
        return
    MouseGetPos(&mx, &my)
    enZona1 := (mx >= 3 && mx <= 54 && my >= 108 && my <= 146)
    if (enZona1 && !btn.b1) {
        btn.b1 := true
        SendEvent("{Click " mx " " my "}")
    } else if (!enZona1 && btn.b1)
        btn.b1 := false
    enZona2 := (mx >= 4 && mx <= 54 && my >= 149 && my <= 189)
    if (enZona2 && !btn.b2) {
        btn.b2 := true
        SendEvent("{Click " mx " " my "}")
    } else if (!enZona2 && btn.b2)
        btn.b2 := false
    enZona3 := (mx >= 3 && mx <= 54 && my >= 193 && my <= 229)
    if (enZona3 && !btn.b3) {
        btn.b3 := true
        SendEvent("{Click " mx " " my "}")
    } else if (!enZona3 && btn.b3)
        btn.b3 := false
}

; ══════════════════════════════════════════════════════════════════
; ChequearZonaDerecha — botones DERECHA (3 zonas, recalibradas con
; CALIBRADOR_v3_DPI en la Artist Pro 16 Gen2 — DPI awareness correcto).
;   Botón 1 (P15-P18): x[2504,2555]  y[107,145]
;   Botón 2 (P19-P22): x[2504,2554]  y[149,189]
;   Botón 3 (P23-P26): x[2503,2553]  y[192,231]
; ══════════════════════════════════════════════════════════════════
ChequearZonaDerecha() {
    if !WinActive("ahk_exe CLIPStudioPaint.exe")
        return
    if sys.modoEscritura
        return
    MouseGetPos(&mx, &my)
    enZona1 := (mx >= 2504 && mx <= 2555 && my >= 107 && my <= 145)
    if (enZona1 && !botDer.b1) {
        botDer.b1 := true
        SendEvent("{Click " mx " " my "}")
    } else if (!enZona1 && botDer.b1)
        botDer.b1 := false
    enZona2 := (mx >= 2504 && mx <= 2554 && my >= 149 && my <= 189)
    if (enZona2 && !botDer.b2) {
        botDer.b2 := true
        SendEvent("{Click " mx " " my "}")
    } else if (!enZona2 && botDer.b2)
        botDer.b2 := false
    enZona3 := (mx >= 2503 && mx <= 2553 && my >= 192 && my <= 231)
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
    ; Zona círculo de colores — usar posición real de la ventana flotante
    enCirculo := false
    if (colorCC.id && colorCC.ccW > 0)
        enCirculo := (mx >= colorCC.ccX && mx <= colorCC.ccX + colorCC.ccW
                   && my >= colorCC.ccY && my <= colorCC.ccY + colorCC.ccH)
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

; ══════════════════════════════════════════════════════════════════
; LoopColorCC — hover + borde para el Círculo de colores flotante.
; Detecta la ventana dinámica por título ("Circulo de colores"),
; actualiza su posición en colorCC.ccX/Y/W/H para que LoopColorV
; use esas coordenadas reales como zona de activación del deslizador.
; ══════════════════════════════════════════════════════════════════
LoopColorCC() {
    if (!colorCC.hover)
        return
    if !WinActive("ahk_exe CLIPStudioPaint.exe") {
        if (colorCC.dsVis && colorCC.id) {
            colorCC.dsVis := false
            WinSetTransparent(5,   "ahk_id " colorCC.id)
            WinSetExStyle("+0x20", "ahk_id " colorCC.id)
        }
        if IsObject(colorCC.bCC)
            colorCC.bCC.Hide()
        colorCC.ccW := 0
        return
    }
    if (!colorCC.id) {
        colorCC.id := BuscarVentanaCSP(0, "rculo de colores", "olores")
        if (colorCC.id) {
            colorCC.bCC   := BorderFrame("AA6622")
            colorCC.dsVis := false
            WinSetTransparent(5,    "ahk_id " colorCC.id)
            WinSetExStyle("+0x20", "ahk_id " colorCC.id)
        }
        return
    }
    try {
        if !WinExist("ahk_id " colorCC.id) {
            if IsObject(colorCC.bCC)
                colorCC.bCC.Hide()
            colorCC.id   := 0
            colorCC.dsVis := false
            colorCC.ccW  := 0
            return
        }
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " colorCC.id)
        colorCC.ccX := wx
        colorCC.ccY := wy
        colorCC.ccW := ww
        colorCC.ccH := wh
    } catch {
        if IsObject(colorCC.bCC)
            colorCC.bCC.Hide()
        colorCC.id   := 0
        colorCC.dsVis := false
        colorCC.ccW  := 0
        return
    }
    MouseGetPos(&mx, &my)
    dentro := (mx >= wx && mx <= wx+ww && my >= wy && my <= wy+wh)
    if (dentro) {
        if (!colorCC.dsVis) {
            colorCC.dsVis := true
            WinSetTransparent(255,  "ahk_id " colorCC.id)
            WinSetExStyle("-0x20", "ahk_id " colorCC.id)
            colorCC.bCC.Hide()
        }
    } else {
        if (colorCC.dsVis) {
            colorCC.dsVis := false
            WinSetTransparent(5,    "ahk_id " colorCC.id)
            WinSetExStyle("+0x20", "ahk_id " colorCC.id)
        }
        if IsObject(colorCC.bCC)
            colorCC.bCC.Show(wx, wy, ww, wh)
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

; ══════════════════════════════════════════════════════════════════
; VigilarAltPegado — red de seguridad contra el bug de "Alt atorado".
; Si stylus.altActive quedó en true pero el Alt físico ya no está
; realmente presionado (GetKeyState dice que no), lo corrige solo.
; Esto es lo que evitaba que E/-/W/Z/X/A/S se quedaran disparando la
; versión "Alt+B sostenido" de esas teclas para siempre.
; ══════════════════════════════════════════════════════════════════
; VigilarAltPegado eliminada — no existía en la Artist Pro 14 Gen2 y
; era la única causa real de que se cortara el hold-and-repeat de
; Alt+B con el keydial. Port 1:1 del comportamiento de la 14.

ResetProcesando() => E.procesando := false


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
        Q.estadoEstab := 1
        MostrarMiniTexto("🟢 ESTABILIZACIÓN ALTA", "1A5C2A", 1000)
        SendInput("{Blind}{- " ESTABILIZACION_PASOS "}")
        Sleep(250)
        SoundBeep(830, 80)
        SoundBeep(960, 80)
    } else {
        Q.estadoEstab := 0
        MostrarMiniTexto("🔵 ESTABILIZACIÓN BAJA", "1A2E5C", 1000)
        SendInput("{Blind}{j " ESTABILIZACION_PASOS "}")
        Sleep(250)
        SoundBeep(420, 80)
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
; Posición: dinámica vía ObtenerMonitorCSP() — centrada horizontal
; Y verticalmente en el monitor CSP. Esta es la caja de avisos rápidos
; (E, E rápido, Alt+Q/W/E, etc.) — distinta del GUI permanente del
; dial (Tamaño/Opacidad), que va arriba.
; colorBarra: hex sin # (ej. "00E5FF"). duracion en ms.
; ══════════════════════════════════════════════════════════════════
_DestruirGui(guiObj) {
    if !IsObject(guiObj)
        return
    hwnd := 0
    try hwnd := guiObj.Hwnd
    try guiObj.Destroy()
    ; Fallback nuclear: si la ventana sigue viva después de Destroy(), cerrarla por hwnd
    if (hwnd && DllCall("IsWindow", "Ptr", hwnd))
        DllCall("DestroyWindow", "Ptr", hwnd)
}

_LimpiarGUIs() {
    _DestruirGui(floatGui.hud)
    floatGui.hud := 0

    _DestruirGui(floatGui.miniTip)
    floatGui.miniTip     := 0
    floatGui.miniTipID   := 0
    floatGui.miniTipTick := 0

    _DestruirGui(floatGui.tooltipToggle)
    floatGui.tooltipToggle := 0

    _DestruirGui(floatGui.miniGUI)
    floatGui.miniGUI := 0

    _DestruirGui(floatGui.enfoque)
    floatGui.enfoque := 0
    enfoque.activo   := false
}

MostrarHUD(texto, colorBarra := "00E5FF", duracion := 1200) {
    _LimpiarGUIs()
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
    mon := ObtenerMonitorCSP()
    x := mon.x + (mon.w - 160) // 2
    y := mon.y + (mon.h - 31) // 2
    g.Show("x" x " y" y " w160 h31 NoActivate")
    floatGui.hud := g
    hwnd := g.Hwnd
    SetTimer(() => _OcultarHUDSi(hwnd), -duracion)
}

_OcultarHUDSi(hwnd) {
    try {
        if (IsObject(floatGui.hud) && floatGui.hud.Hwnd = hwnd) {
            floatGui.hud.Destroy()
            floatGui.hud := 0
        }
    } catch {
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
    _LimpiarGUIs()
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
        try floatGui.miniGUI.Destroy()
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
    hwndMG := g.Hwnd
    SetTimer(() => _OcultarMiniGUISi(hwndMG), -duracion)
}

_OcultarMiniGUISi(hwndMG) {
    try {
        if (IsObject(floatGui.miniGUI) && floatGui.miniGUI.Hwnd = hwndMG) {
            floatGui.miniGUI.Destroy()
            floatGui.miniGUI := 0
        }
    } catch {
        floatGui.miniGUI := 0
    }
}

OcultarMiniGUI() {
    if IsObject(floatGui.miniGUI)
        try floatGui.miniGUI.Destroy()
    floatGui.miniGUI := 0
}

MostrarTooltipToggle(titulo, simbolo, color) {
    _LimpiarGUIs()
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
    hwndT := g.Hwnd
    SetTimer(() => _OcultarToggleSi(hwndT), -1500)
}

_OcultarToggleSi(hwndT) {
    try {
        if (IsObject(floatGui.tooltipToggle) && floatGui.tooltipToggle.Hwnd = hwndT) {
            floatGui.tooltipToggle.Destroy()
            floatGui.tooltipToggle := 0
        }
    } catch {
        floatGui.tooltipToggle := 0
    }
}

QuitarTooltipToggle() {
    if IsObject(floatGui.tooltipToggle)
        try floatGui.tooltipToggle.Destroy()
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
; en la Artist Pro 16 Gen2 (DPI awareness correcto): izquierdo en P1
; (47, 85), derecho en P2 (2509, 87).
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
    ; Click izquierdo — absoluto (47, 85)
    MouseMove(47, 85, 0)
    Sleep(8)
    Click()
    Sleep(12)
    ; Click derecho — absoluto (2509, 87)
    MouseMove(2509, 87, 0)
    Sleep(8)
    Click()
    Sleep(12)
    MouseMove(origX, origY, 0)
}

MostrarGUIEnfoque() {
    if IsObject(floatGui.enfoque)
        try floatGui.enfoque.Destroy()
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
        if IsObject(dsGui.g)
            dsGui.g.Hide()
        if IsObject(ccGui.g)
            ccGui.g.Hide()
        if IsObject(arGui.g)
            arGui.g.Hide()
        if IsObject(hcGui.g)
            hcGui.g.Hide()
        if IsObject(reloadGui.g)
            reloadGui.g.Hide()
        return
    }
    ; Restaurar dial, dsGui/ccGui/arGui, hcGui y reloadGui si CSP recuperó el foco
    if IsObject(dial.g) {
        try {
            if !DllCall("IsWindowVisible", "Ptr", dial.g.Hwnd)
                dial.g.Show("NoActivate")
        }
    }
    if IsObject(dsGui.g) {
        try {
            if !DllCall("IsWindowVisible", "Ptr", dsGui.g.Hwnd)
                dsGui.g.Show("NoActivate")
        }
    }
    if IsObject(ccGui.g) {
        try {
            if !DllCall("IsWindowVisible", "Ptr", ccGui.g.Hwnd)
                ccGui.g.Show("NoActivate")
        }
    }
    if IsObject(arGui.g) {
        try {
            if !DllCall("IsWindowVisible", "Ptr", arGui.g.Hwnd)
                arGui.g.Show("NoActivate")
        }
    }
    if IsObject(hcGui.g) {
        try {
            if !DllCall("IsWindowVisible", "Ptr", hcGui.g.Hwnd)
                hcGui.g.Show("NoActivate")
        }
    }
    if IsObject(reloadGui.g) {
        try {
            if !DllCall("IsWindowVisible", "Ptr", reloadGui.g.Hwnd)
                reloadGui.g.Show("NoActivate")
        }
    }
    ; Watchdog miniTip
    if (floatGui.miniTipID != 0 && floatGui.miniTipTick != 0) {
        if (A_TickCount - floatGui.miniTipTick > 4000) {
            try {
                if IsObject(floatGui.miniTip)
                    try floatGui.miniTip.Destroy()
            }
            floatGui.miniTip     := 0
            floatGui.miniTipID   := 0
            floatGui.miniTipTick := 0
        }
    }
}

#HotIf WinActive("ahk_exe CLIPStudioPaint.exe")
!f:: {
    if !stylus.altActive
        return
    now := A_TickCount
    if (now - AltF_state.lastPress < 300) {
        SetTimer(__AltF_SEND_NORMAL, 0)
        AltF_state.timerRunning := 0
        AltF_state.lastPress := 0
        SendEvent("{Alt up}{NumpadEnd}{Alt down}")
        MostrarHUD("SMEAR SOFT  (2)", "FF6B00", 950)
        return
    }
    AltF_state.lastPress    := now
    AltF_state.timerRunning := 1
    SetTimer(__AltF_SEND_NORMAL, -250)
}

__AltF_SEND_NORMAL() {
    if !AltF_state.timerRunning
        return
    AltF_state.timerRunning := 0
    ; Este timer corre 250ms después del toque: si para cuando dispara ya
    ; soltaste el botón del lápiz (stylus.altActive ya en false), NO hay
    ; que volver a bajar Alt — hacerlo lo deja "pegado" y CSP lo interpreta
    ; como Alt sostenido (activa su función alterna de herramienta) hasta
    ; que tocas Alt de nuevo. stylus.altActive es la fuente de verdad
    ; correcta acá (GetKeyState no sirve: el driver de la tableta inyecta
    ; la tecla, así que Windows no siempre la reporta como "física").
    seguiaSostenido := stylus.altActive
    SendEvent("{Alt up}b")
    if (seguiaSostenido)
        SendEvent("{Alt down}")
    MostrarHUD("SMEAR  (1)", "00E5FF", 950)
}
~b & k:: {
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
; │  (tamaño 50% mayor y posición P5, Artist Pro 16 Gen2)     │
; └──────────────────────────────────────────────────────────┘
; ══════════════════════════════════════════════════════════════════
; GuardarPosicionGUI / LeerPosicionGUI — persisten la posición de los
; paneles arrastrables (dial, dsGui/ccGui/arGui) en un .ini junto al script,
; para que recuerden dónde los dejaste entre sesiones.
; ══════════════════════════════════════════════════════════════════
; Función en vez de variable global: una asignación suelta aquí nunca
; se ejecutaría, porque en AHK v2 la sección de auto-ejecución termina
; en el primer hotkey del script, y esto está muy por debajo de esa
; línea — quedaría vacía. Como función, se calcula cada vez que se llama.
_PosGuiIniPath() => A_ScriptDir "\posiciones_gui.ini"

GuardarPosicionGUI(nombre, hwnd) {
    rc := Buffer(16, 0)
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rc)
    IniWrite(NumGet(rc, 0, "int"), _PosGuiIniPath(), nombre, "x")
    IniWrite(NumGet(rc, 4, "int"), _PosGuiIniPath(), nombre, "y")
}

; Devuelve un objeto {x, y} si hay posición guardada, o 0 si no.
LeerPosicionGUI(nombre) {
    x := IniRead(_PosGuiIniPath(), nombre, "x", "")
    y := IniRead(_PosGuiIniPath(), nombre, "y", "")
    if (x = "" || y = "")
        return 0
    return { x: Integer(x), y: Integer(y) }
}

; Verdadero si el punto (x,y) cae dentro de algún monitor conectado.
; Protege contra posiciones guardadas que quedaron fuera de pantalla
; (monitor desconectado, resolución cambiada, guardado corrupto, etc.)
; — sin esto, un GUI "invisible" no tiene forma fácil de recuperarse.
_PosicionValidaEnPantalla(x, y) {
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if (x >= l && x <= r && y >= t && y <= b)
            return true
    }
    return false
}

; ══════════════════════════════════════════════════════════════════
; BLOQUE Slider + Circle + Quick — se comportan como una sola unidad.
; Arrastrar cualquiera de los tres mueve a los tres juntos. Solo se
; persiste el ancla (posición de dsGui); cc/ar se calculan siempre
; como offsets fijos desde el ancla, así que al reabrir el script
; SIEMPRE vuelven a quedar alineados en bloque, sin importar qué se
; haya hecho en la sesión anterior.
;
; Excepción: mantener Ctrl presionado al iniciar el arrastre mueve
; SOLO ese panel, independiente del resto — pensado para un ajuste
; puntual y ocasional. Ese movimiento independiente nunca se guarda,
; así que al recargar/reabrir el script el bloque se reagrupa (ojo:
; es intencional, no es un bug).
; ══════════════════════════════════════════════════════════════════
_AnclaBloquePaneles() {
    static ancla := 0
    if IsObject(ancla)
        return ancla
    mon := ObtenerMonitorCSP()
    ; Ancho total del bloque horizontal (estimado, solo para centrar el
    ; primer panel): 3 paneles de 80px lógicos + 2 separaciones. El
    ; posicionamiento real de ccGui/arGui ya no depende de este valor
    ; (ver PANEL_GAP e IniciarCcGUI/IniciarArGUI), así que un desajuste
    ; aquí como mucho descentra un poco el bloque, no lo superpone.
    anchoBloque := 80 + PANEL_GAP + 80 + PANEL_GAP + 80
    defX := mon.x + (mon.w - anchoBloque) // 2
    defY := mon.y + Round(mon.h * 0.02) + 32 + 4
    guardada := LeerPosicionGUI("PanelBlock")
    if IsObject(guardada) && _PosicionValidaEnPantalla(guardada.x, guardada.y) {
        ancla := guardada
        return ancla
    }
    ; Migración: si ya existía una posición individual guardada del
    ; slider (de antes de agrupar los paneles), se usa como ancla
    ; inicial para no perder la ubicación que ya se había encontrado.
    vieja := LeerPosicionGUI("Slider")
    if IsObject(vieja) && _PosicionValidaEnPantalla(vieja.x, vieja.y) {
        ancla := vieja
        return ancla
    }
    ancla := { x: defX, y: defY }
    return ancla
}

; Manejador compartido de arrastre para dsGui/ccGui/arGui. guiObj es
; el panel sobre el que se hizo clic; el resto del bloque lo acompaña.
_ArrastrarPanelBloque(hwndClick, lParam, guiObj) {
    global dsGui, ccGui, arGui
    static arrastrando := false
    if (arrastrando)
        return
    if !(hwndClick = guiObj.g.Hwnd || guiObj.g.Hwnd = DllCall("GetParent", "Ptr", hwndClick, "Ptr"))
        return
    arrastrando := true

    independiente := GetKeyState("Ctrl", "P")

    pt := Buffer(8, 0)
    NumPut("int", lParam & 0xFFFF,        pt, 0)
    NumPut("int", (lParam >> 16) & 0xFFFF, pt, 4)
    DllCall("ClientToScreen", "Ptr", hwndClick, "Ptr", pt)
    clickX := NumGet(pt, 0, "int")
    clickY := NumGet(pt, 4, "int")

    rc := Buffer(16, 0)
    DllCall("GetWindowRect", "Ptr", guiObj.g.Hwnd, "Ptr", rc)
    origX := NumGet(rc, 0, "int")
    origY := NumGet(rc, 4, "int")
    offX := clickX - origX
    offY := clickY - origY

    ; Posiciones originales de los otros dos paneles del bloque, para
    ; moverlos junto con el que se está arrastrando (salvo modo Ctrl).
    otros := []
    if !independiente {
        for g in [dsGui, ccGui, arGui] {
            if (g.g.Hwnd != guiObj.g.Hwnd) {
                DllCall("GetWindowRect", "Ptr", g.g.Hwnd, "Ptr", rc)
                otros.Push({ g: g, x0: NumGet(rc, 0, "int"), y0: NumGet(rc, 4, "int") })
            }
        }
    }

    SWP_NOSIZE := 0x0001, SWP_NOZORDER := 0x0004, SWP_NOACTIVATE := 0x0010
    cur := Buffer(8, 0)
    movido := false
    while GetKeyState("LButton", "P") {
        DllCall("GetCursorPos", "Ptr", cur)
        mx := NumGet(cur, 0, "int"), my := NumGet(cur, 4, "int")
        if (Abs(mx - clickX) > 4 || Abs(my - clickY) > 4) {
            movido := true
            newX := mx - offX
            newY := my - offY
            DllCall("SetWindowPos", "Ptr", guiObj.g.Hwnd, "Ptr", 0
                , "int", newX, "int", newY, "int", 0, "int", 0
                , "uint", SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE)
            if !independiente {
                dx := newX - origX
                dy := newY - origY
                for o in otros {
                    DllCall("SetWindowPos", "Ptr", o.g.g.Hwnd, "Ptr", 0
                        , "int", o.x0 + dx, "int", o.y0 + dy, "int", 0, "int", 0
                        , "uint", SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE)
                }
            }
        }
        Sleep(8)
    }

    if !movido {
        ; Click corto → toggle propio de este panel.
        if (guiObj.g.Hwnd = dsGui.g.Hwnd) {
            _ToggleColorV()
            ActualizarDsGUI()
        } else if (guiObj.g.Hwnd = ccGui.g.Hwnd) {
            _ToggleColorCC()
            ActualizarCcGUI()
        } else {
            _ToggleAR()
            ActualizarArGUI()
        }
    } else if !independiente {
        ; Se movió el bloque completo — se persiste solo el ancla
        ; (posición de dsGui); cc/ar se recalculan desde ahí al reabrir.
        GuardarPosicionGUI("PanelBlock", dsGui.g.Hwnd)
    }
    ; Si fue arrastre independiente (Ctrl) no se persiste nada: al
    ; recargar/reabrir el script el bloque vuelve a alinearse.
    arrastrando := false
}

IniciarDialGUI() {

    global dial
    dial.g := Gui("+AlwaysOnTop -Caption +ToolWindow", "")
    dial.g.BackColor := "1a1a1a"
    dial.g.MarginX := 0
    dial.g.MarginY := 0
    WinSetTransparent(128, dial.g)

    dial.icono := dial.g.Add("Text", "x5 y2 w26 h24 +0x200 cWhite", "")
    dial.icono.SetFont("s14 bold", "Segoe UI")

    dial.label := dial.g.Add("Text", "x33 y5 w100 h20 cWhite", "")
    dial.label.SetFont("s10", "Segoe UI Semilight")

    dial.barra := dial.g.Add("Progress", "x0 y28 w140 h4 Background333333")

    OnMessage(0x0201, _DialWM_LBUTTONDOWN)

    ; Posición: centro horizontal del monitor CSP, mismo criterio que
    ; MostrarHUD/MostrarMiniGUI — ya no depende de un punto fijo.
    ; Si hay una posición guardada de un arrastre anterior, se usa esa.
    mon := ObtenerMonitorCSP()
    x := mon.x + (mon.w - 140) // 2
    y := mon.y + Round(mon.h * 0.02)
    guardada := LeerPosicionGUI("Dial")
    if IsObject(guardada) && _PosicionValidaEnPantalla(guardada.x, guardada.y) {
        x := guardada.x
        y := guardada.y
    }
    dial.g.Show("x" x " y" y " w140 h32 NoActivate")
    ActualizarDialGUI()
}

ActualizarDialGUI() {
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

; ══════════════════════════════════════════════════════════════════
; _DialWM_LBUTTONDOWN — arrastre manual del dial GUI.
; El truco anterior (PostMessage WM_NCLBUTTONDOWN/HTCAPTION) delegaba
; el drag a Windows, pero al soltar el botón la posición se revertía
; (la ventana -ToolWindow +AlwaysOnTop nunca confirmaba el nuevo punto
; ante el propio sistema). Ahora se sigue el mouse a mano con WinMove
; en cada iteración y se corta al soltar el botón — la posición final
; queda fija de verdad, sin snap-back.
; ══════════════════════════════════════════════════════════════════
_DialWM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global dial
    static arrastrando := false
    if (arrastrando)
        return
    if (hwnd = dial.g.Hwnd || dial.g.Hwnd = DllCall("GetParent", "Ptr", hwnd, "Ptr")) {
        arrastrando := true
        ; Todo el arrastre usa API de Windows en crudo (Get/SetCursorPos,
        ; GetWindowRect, SetWindowPos) — antes se mezclaba ClientToScreen
        ; (crudo) con MouseGetPos/Gui.Move (con su propio ajuste de DPI de
        ; AHK), lo que dejaba un desfase residual. SWP_NOZORDER además evita
        ; que el dial reclame "encima" en cada tick, que era lo que hacía
        ; parpadear a los paneles de hover (deslizador/círculo/acceso rápido)
        ; mientras se arrastraba.
        pt := Buffer(8, 0)
        NumPut("int", lParam & 0xFFFF,        pt, 0)
        NumPut("int", (lParam >> 16) & 0xFFFF, pt, 4)
        DllCall("ClientToScreen", "Ptr", hwnd, "Ptr", pt)
        clickX := NumGet(pt, 0, "int")
        clickY := NumGet(pt, 4, "int")

        rc := Buffer(16, 0)
        DllCall("GetWindowRect", "Ptr", dial.g.Hwnd, "Ptr", rc)
        offX := clickX - NumGet(rc, 0, "int")
        offY := clickY - NumGet(rc, 4, "int")

        cur := Buffer(8, 0)
        SWP_NOSIZE := 0x0001, SWP_NOZORDER := 0x0004, SWP_NOACTIVATE := 0x0010
        while GetKeyState("LButton", "P") {
            DllCall("GetCursorPos", "Ptr", cur)
            mx := NumGet(cur, 0, "int"), my := NumGet(cur, 4, "int")
            DllCall("SetWindowPos", "Ptr", dial.g.Hwnd, "Ptr", 0
                , "int", mx - offX, "int", my - offY, "int", 0, "int", 0
                , "uint", SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE)
            Sleep(8)
        }
        GuardarPosicionGUI("Dial", dial.g.Hwnd)
        arrastrando := false
    }
}

; ┌──────────────────────────────────────────────────────────┐
; │  DS / CC / AR GUI — 3 botones permanentes (deslizador de   │
; │  color, círculo de colores, acceso rápido), mismo estilo    │
; │  visual que el dial (icono + label + barra). Un click corto │
; │  en cada uno alterna SOLO ese panel; +q / Alt+J siguen       │
; │  alternando los 3 juntos y refrescan los 3 botones.          │
; │  Se comportan como UN BLOQUE al arrastrarlos (ver             │
; │  _ArrastrarPanelBloque / _AnclaBloquePaneles más arriba):     │
; │  mover cualquiera mueve a los tres, y solo se persiste el     │
; │  ancla — así siempre se reagrupan al reabrir el script.        │
; │  Ctrl+arrastre mueve un panel suelto de forma puntual (no      │
; │  se guarda).                                                    │
; └──────────────────────────────────────────────────────────┘
IniciarDsGUI() {
    global dsGui
    dsGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow", "")
    dsGui.g.BackColor := "1a1a1a"
    dsGui.g.MarginX := 0
    dsGui.g.MarginY := 0
    WinSetTransparent(128, dsGui.g)

    dsGui.icono := dsGui.g.Add("Text", "x3 y1 w15 h15 +0x200 cWhite", "")
    dsGui.icono.SetFont("s9 bold", "Segoe UI")

    dsGui.label := dsGui.g.Add("Text", "x19 y2 w58 h14 cWhite", "")
    dsGui.label.SetFont("s7", "Segoe UI Semilight")

    dsGui.barra := dsGui.g.Add("Progress", "x0 y17 w80 h2 Background333333")

    OnMessage(0x0201, _DsGUI_WM_LBUTTONDOWN)

    ; Posición: ancla del bloque Slider+Circle+Quick (ver _AnclaBloquePaneles).
    ancla := _AnclaBloquePaneles()
    dsGui.g.Show("x" ancla.x " y" ancla.y " w80 h19 NoActivate")
    ActualizarDsGUI()
}

ActualizarDsGUI() {
    if (colorV.hover) {
        dsGui.icono.Value := "🎚"
        dsGui.label.Value := "SLIDER ON"
        dsGui.barra.Opt("c1E8449")
        dsGui.barra.Value := 100
    } else {
        dsGui.icono.Value := "⏸"
        dsGui.label.Value := "SLIDER OFF"
        dsGui.barra.Opt("cD92B2B")
        dsGui.barra.Value := 100
    }
}

_DsGUI_WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global dsGui
    _ArrastrarPanelBloque(hwnd, lParam, dsGui)
}

IniciarCcGUI() {
    global ccGui
    ccGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow", "")
    ccGui.g.BackColor := "1a1a1a"
    ccGui.g.MarginX := 0
    ccGui.g.MarginY := 0
    WinSetTransparent(128, ccGui.g)

    ccGui.icono := ccGui.g.Add("Text", "x3 y1 w15 h15 +0x200 cWhite", "")
    ccGui.icono.SetFont("s9 bold", "Segoe UI")

    ccGui.label := ccGui.g.Add("Text", "x19 y2 w58 h14 cWhite", "")
    ccGui.label.SetFont("s7", "Segoe UI Semilight")

    ccGui.barra := ccGui.g.Add("Progress", "x0 y17 w80 h2 Background333333")

    OnMessage(0x0201, _CcGUI_WM_LBUTTONDOWN)

    ; Posición: justo a la derecha de dsGui, medido con su rectángulo REAL
    ; en pantalla (no un ancho asumido) — así no se superpone aunque el
    ; escalado/DPI de Windows haga que dsGui ocupe físicamente más o menos
    ; de los 80px "lógicos".
    WinGetPos(&dsX, &dsY, &dsW, &dsH, "ahk_id " dsGui.g.Hwnd)
    ccGui.g.Show("x" (dsX + dsW + PANEL_GAP) " y" dsY " w80 h19 NoActivate")
    ActualizarCcGUI()
}

ActualizarCcGUI() {
    if (colorCC.hover) {
        ccGui.icono.Value := "🎨"
        ccGui.label.Value := "CIRCLE ON"
        ccGui.barra.Opt("c1E8449")
        ccGui.barra.Value := 100
    } else {
        ccGui.icono.Value := "⏸"
        ccGui.label.Value := "CIRCLE OFF"
        ccGui.barra.Opt("cD92B2B")
        ccGui.barra.Value := 100
    }
}

_CcGUI_WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global ccGui
    _ArrastrarPanelBloque(hwnd, lParam, ccGui)
}

IniciarArGUI() {
    global arGui
    arGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow", "")
    arGui.g.BackColor := "1a1a1a"
    arGui.g.MarginX := 0
    arGui.g.MarginY := 0
    WinSetTransparent(128, arGui.g)

    arGui.icono := arGui.g.Add("Text", "x3 y1 w15 h15 +0x200 cWhite", "")
    arGui.icono.SetFont("s9 bold", "Segoe UI")

    arGui.label := arGui.g.Add("Text", "x19 y2 w58 h14 cWhite", "")
    arGui.label.SetFont("s7", "Segoe UI Semilight")

    arGui.barra := arGui.g.Add("Progress", "x0 y17 w80 h2 Background333333")

    OnMessage(0x0201, _ArGUI_WM_LBUTTONDOWN)

    ; Posición: justo a la derecha de ccGui, medido con su rectángulo REAL
    ; en pantalla (mismo motivo que en IniciarCcGUI).
    WinGetPos(&ccX, &ccY, &ccW, &ccH, "ahk_id " ccGui.g.Hwnd)
    arGui.g.Show("x" (ccX + ccW + PANEL_GAP) " y" ccY " w80 h19 NoActivate")
    ActualizarArGUI()
}

ActualizarArGUI() {
    if (ar.hover) {
        arGui.icono.Value := "⚡"
        arGui.label.Value := "QUICK ON"
        arGui.barra.Opt("c1E8449")
        arGui.barra.Value := 100
    } else {
        arGui.icono.Value := "⏸"
        arGui.label.Value := "QUICK OFF"
        arGui.barra.Opt("cD92B2B")
        arGui.barra.Value := 100
    }
}

_ArGUI_WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global arGui
    _ArrastrarPanelBloque(hwnd, lParam, arGui)
}

; ┌──────────────────────────────────────────────────────────┐
; │  HC GUI — botón permanente HC ON/OFF (Historial de Color  │
; │  dinámico). Mismo tamaño/estilo que dsGui/ccGui/arGui. Un    │
; │  corto = mismo efecto que Numpad0. Se apila debajo de      │
; │  arGui y también se puede arrastrar para reposicionar.     │
; └──────────────────────────────────────────────────────────┘
IniciarHCGUI() {
    global hcGui
    hcGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow", "")
    hcGui.g.BackColor := "1a1a1a"
    hcGui.g.MarginX := 0
    hcGui.g.MarginY := 0
    WinSetTransparent(128, hcGui.g)

    hcGui.icono := hcGui.g.Add("Text", "x3 y1 w15 h15 +0x200 cWhite", "")
    hcGui.icono.SetFont("s9 bold", "Segoe UI")

    hcGui.label := hcGui.g.Add("Text", "x19 y2 w58 h14 cWhite", "")
    hcGui.label.SetFont("s7", "Segoe UI Semilight")

    hcGui.barra := hcGui.g.Add("Progress", "x0 y17 w80 h2 Background333333")

    OnMessage(0x0201, _HCGUI_WM_LBUTTONDOWN)

    ; Justo debajo de arGui (mismo centrado horizontal, tercer botón de
    ; hover), con 4px de separación, salvo que haya una posición guardada
    ; de un arrastre anterior.
    mon := ObtenerMonitorCSP()
    x := mon.x + (mon.w - 80) // 2
    y := mon.y + Round(mon.h * 0.02) + 32 + 4 + 19 + 4 + 19 + 4 + 19 + 4
    guardada := LeerPosicionGUI("HC")
    if IsObject(guardada) && _PosicionValidaEnPantalla(guardada.x, guardada.y) {
        x := guardada.x
        y := guardada.y
    }
    hcGui.g.Show("x" x " y" y " w80 h19 NoActivate")
    ActualizarHCGUI()
}

ActualizarHCGUI() {
    if (hist.modo = 1) {
        hcGui.icono.Value := "🟢"
        hcGui.label.Value := "HC ON"
        hcGui.barra.Opt("c1E8449")
        hcGui.barra.Value := 100
    } else {
        hcGui.icono.Value := "🔒"
        hcGui.label.Value := "HC OFF"
        hcGui.barra.Opt("cD92B2B")
        hcGui.barra.Value := 100
    }
}

; Click corto = toggle (como Numpad0). Arrastre = mover el botón.
_HCGUI_WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global hcGui
    static arrastrando := false
    if (arrastrando)
        return
    if (hwnd = hcGui.g.Hwnd || hcGui.g.Hwnd = DllCall("GetParent", "Ptr", hwnd, "Ptr")) {
        arrastrando := true
        pt := Buffer(8, 0)
        NumPut("int", lParam & 0xFFFF,        pt, 0)
        NumPut("int", (lParam >> 16) & 0xFFFF, pt, 4)
        DllCall("ClientToScreen", "Ptr", hwnd, "Ptr", pt)
        clickX := NumGet(pt, 0, "int")
        clickY := NumGet(pt, 4, "int")

        rc := Buffer(16, 0)
        DllCall("GetWindowRect", "Ptr", hcGui.g.Hwnd, "Ptr", rc)
        offX := clickX - NumGet(rc, 0, "int")
        offY := clickY - NumGet(rc, 4, "int")

        cur := Buffer(8, 0)
        SWP_NOSIZE := 0x0001, SWP_NOZORDER := 0x0004, SWP_NOACTIVATE := 0x0010
        movido := false
        while GetKeyState("LButton", "P") {
            DllCall("GetCursorPos", "Ptr", cur)
            mx := NumGet(cur, 0, "int"), my := NumGet(cur, 4, "int")
            if (Abs(mx - clickX) > 4 || Abs(my - clickY) > 4) {
                movido := true
                DllCall("SetWindowPos", "Ptr", hcGui.g.Hwnd, "Ptr", 0
                    , "int", mx - offX, "int", my - offY, "int", 0, "int", 0
                    , "uint", SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE)
            }
            Sleep(8)
        }
        if !movido {
            hcOn := _ToggleHistorialColor()
            ActualizarHCGUI()
        } else {
            GuardarPosicionGUI("HC", hcGui.g.Hwnd)
        }
        arrastrando := false
    }
}

; ┌──────────────────────────────────────────────────────────┐
; │  RELOAD GUI — botón permanente para recargar el script.   │
; │  Mismo tamaño/estilo que dsGui/hcGui. Un click corto        │
; │  llama a Reload() directo — NO es el botón de pánico       │
; │  (Numpad8), es un reload limpio y simple. Se apila debajo  │
; │  de hcGui y también se puede arrastrar para reposicionar.  │
; └──────────────────────────────────────────────────────────┘
IniciarReloadGUI() {
    global reloadGui
    reloadGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow", "")
    reloadGui.g.BackColor := "1a1a1a"
    reloadGui.g.MarginX := 0
    reloadGui.g.MarginY := 0
    WinSetTransparent(128, reloadGui.g)

    ; Solo el símbolo, centrado — botón ajustado al tamaño del icono.
    reloadGui.icono := reloadGui.g.Add("Text", "x0 y0 w24 h17 +0x201 cWhite", "🔄")
    reloadGui.icono.SetFont("s13 bold", "Segoe UI")

    reloadGui.barra := reloadGui.g.Add("Progress", "x0 y17 w24 h2 Background333333 c00A2E8")
    reloadGui.barra.Value := 100

    OnMessage(0x0201, _ReloadGUI_WM_LBUTTONDOWN)

    ; Justo debajo de hcGui, alineado a la izquierda de esa columna
    ; (mismo x que los otros paneles, sin recentrar por su propio ancho
    ; angosto), salvo que haya una posición guardada de un arrastre anterior.
    mon := ObtenerMonitorCSP()
    x := mon.x + (mon.w - 80) // 2
    y := mon.y + Round(mon.h * 0.02) + 32 + 4 + 19 + 4 + 19 + 4 + 19 + 4 + 19 + 4
    guardada := LeerPosicionGUI("Reload")
    if IsObject(guardada) && _PosicionValidaEnPantalla(guardada.x, guardada.y) {
        x := guardada.x
        y := guardada.y
    }
    reloadGui.g.Show("x" x " y" y " w24 h19 NoActivate")
}

; Click corto = Reload() directo. Arrastre = mover el botón.
_ReloadGUI_WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global reloadGui
    static arrastrando := false
    if (arrastrando)
        return
    if (hwnd = reloadGui.g.Hwnd || reloadGui.g.Hwnd = DllCall("GetParent", "Ptr", hwnd, "Ptr")) {
        arrastrando := true
        pt := Buffer(8, 0)
        NumPut("int", lParam & 0xFFFF,        pt, 0)
        NumPut("int", (lParam >> 16) & 0xFFFF, pt, 4)
        DllCall("ClientToScreen", "Ptr", hwnd, "Ptr", pt)
        clickX := NumGet(pt, 0, "int")
        clickY := NumGet(pt, 4, "int")

        rc := Buffer(16, 0)
        DllCall("GetWindowRect", "Ptr", reloadGui.g.Hwnd, "Ptr", rc)
        offX := clickX - NumGet(rc, 0, "int")
        offY := clickY - NumGet(rc, 4, "int")

        cur := Buffer(8, 0)
        SWP_NOSIZE := 0x0001, SWP_NOZORDER := 0x0004, SWP_NOACTIVATE := 0x0010
        movido := false
        while GetKeyState("LButton", "P") {
            DllCall("GetCursorPos", "Ptr", cur)
            mx := NumGet(cur, 0, "int"), my := NumGet(cur, 4, "int")
            if (Abs(mx - clickX) > 4 || Abs(my - clickY) > 4) {
                movido := true
                DllCall("SetWindowPos", "Ptr", reloadGui.g.Hwnd, "Ptr", 0
                    , "int", mx - offX, "int", my - offY, "int", 0, "int", 0
                    , "uint", SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE)
            }
            Sleep(8)
        }
        if !movido {
            SoundBeep(700, 60)
            Reload()
        } else {
            GuardarPosicionGUI("Reload", reloadGui.g.Hwnd)
        }
        arrastrando := false
    }
}
