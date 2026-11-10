; ┌─────────────────────────────────────────────────────────┐
; │  🎨 CSP XPPEN_DECO.01V2 — SCRIPT PRINCIPAL              │
; │                                                         │
; │  1. DIRECTIVAS GLOBALES                                 │
; │  2. ESTADO (objetos agrupados)                          │
; │  3. TIMERS                                              │
; │  4. HOTKEYS GLOBALES                                    │
; │  5. HOTKEYS CSP                                         │
; │     a) Selección y reselección                          │
; │     b) Deshacer / Rehacer                               │
; │     c) Herramientas (A E W Q S O R)                     │
; │     d) Atajos con clic derecho                          │
; │     e) Modificadores de capa                            │
; │  6. CLASE BorderFrame                                   │
; │  7. FUNCIONES                                           │
; └─────────────────────────────────────────────────────────┘

; ┌───────────────────────────────────────────────────────┐
; │  1. DIRECTIVAS GLOBALES                               │
; └───────────────────────────────────────────────────────┘
#Requires AutoHotkey v2.0
#SingleInstance Force
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
stylus := { altActive: false }
sel := { estado: 0, estadoAltX: false, estadoC: 0, guiActivo: false }
colorEstado     := 0   ; 0=primario  1=secundario  2=alpha
E := { last: 0, timerRunning: 0, procesando: false }
W := { last: 0, timerRunning: 0 }
Q := { last: 0, estadoEstab: 0 }
A_state := { lastPress: 0 }
S := { estadoCaracter: 0, skipNext: false }
O := { ciclo: 0 }
N6 := { estadoEscala: 0 }
hist := { abierto: false, modo: 1 }
btn := { b1: false, b2: false, b3: false }
botDer := { b1: false, b2: false, b3: false, b4: false }
colorV := {
    dsID: 0, dsVis: false, bDS: 0, hover: true, cspHwnd: 0,
    dsX: 0, dsY: 0, dsW: 0, dsH: 0,
    ccFromRight: 203, ccW: 191, ccFromTop: 95, ccH: 490
}
ar := { id: 0, dsVis: false, bAR: 0, hover: true }
floatGui := { miniTip: 0, miniGUI: 0, tooltipToggle: 0, enfoque: 0, miniTipTick: 0, miniTipID: 0 }
enfoque := { activo: false }
boost := { holdDelay: 300, maxBoost: 5 }
spc := { last: 0, downTick: 0 }

; ┌──────────────────────────────────────────────────────────────────────┐
; │  3. TIMERS                                                           │
; └──────────────────────────────────────────────────────────────────────┘
SetTimer(CheckReload,            600)
SetTimer(ChequearZonaHistorial,  200)
SetTimer(ChequearZonaAltA,        30)
SetTimer(ChequearZonaDerecha,     30)
SetTimer(LoopColorV,              80)
SetTimer(LoopAccesoRapido,        80)
SetTimer(ResetEnfoque,         10000)
IniciarDeteccion()

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
    ToolTip(hist.modo = 1 ? "🟢 HISTORIAL INTERACTIVO" : "🔒 HISTORIAL FIJO")
    SetTimer(QuitarToolTip, -10000)
}

^s:: {
    SendInput("^s")
    SoundBeep(600, 100)
    SoundBeep(900, 150)
    ToolTip("💾 GUARDADO Y MODIFICADO 💾")
    SetTimer(QuitarToolTip, -800)
}

Space & RButton:: {
    SendInput("!g")
    ToolTip("🎨 Space + RButton")
    SoundBeep(800, 100)
    SetTimer(QuitarToolTip, -700)
}

RButton:: SendInput("{RButton}")
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
^z:: {
    SendInput("^z")
    ToolTipCS("🔴 DESHACER", 300)
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
        ToolTip("TODAS LAS CAPAS (2)")
        SetTimer(QuitarToolTip, -4300)
    } else {
        A_state.lastPress := now
        SendInput("{Blind}a")
        ToolTip("CAPA ACTUAL (1)")
        SetTimer(QuitarToolTip, -1300)
    }
}

RButton & a:: {
    Send("ñ")
    ToolTip("CAPA REFERIDA")
    SetTimer(QuitarToolTip, -2300)
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

RButton & e:: {
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
    ToolTip("BORRADOR DE TODAS LAS CAPAS")
    Send("{F5}")
    SetTimer(QuitarToolTip, -800)
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

-:: AlternarEstabilizacion()

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
$s:: {
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
    CustomToolTip("REFLEJAR HORIZONTALMENTE")
    Send("+r")
}

Tab:: AccionEnfoque()
F3::  AccionEnfoque()

; ┌─────────────────────────────────────┐
; │  5d. ATAJOS CON CLIC DERECHO        │
; └─────────────────────────────────────┘
RButton & s:: {
    ToolTip("LAZO CON AUTORELLENO")
    Send("{F9}")
    SetTimer(QuitarToolTip, -1200)
}

RButton & q:: {
    Send("!q")
    ToolTip("ACCESO RÁPIDO")
    SetTimer(QuitarToolTip, -800)
}

RButton & 1::
RButton & 2::
RButton & 3::
RButton & 4::
RButton & 5::
RButton & 6::
RButton & 7::
RButton & 8::
RButton & 9::
RButton & 0:: {
    key        := SubStr(A_ThisHotkey, StrLen(A_ThisHotkey))
    porcentaje := (key = "0") ? 100 : Integer(key) * 10
    ToolTip("OPACIDAD " porcentaje "%")
    Send("+" key)
    SetTimer(QuitarToolTip, -1500)
}

; ┌─────────────────────────────────────┐
; │  5e. MODIFICADORES DE CAPA          │
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
    ToolTip("Capa: " tipos[tecla])
    Send("^!" tecla)
    SetTimer(QuitarToolTip, -500)
}

$Numpad6:: {
    if (N6.estadoEscala = 0) {
        Send("7")
        ToolTip("CAPA ESCALA DE GRISES")
        N6.estadoEscala := 1
    } else {
        Send("8")
        ToolTip("BORRAR CAPA DE CORRECCIÓN")
        N6.estadoEscala := 0
    }
    SetTimer(QuitarToolTip, -1200)
}

*Backspace:: {
    if GetKeyState("Space", "P") {
        Send("8")
        ToolTip("BORRAR CAPA DE CORRECCIÓN")
        SetTimer(QuitarToolTip, -1200)
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
        x := (A_ScreenWidth  // 2) - 120
        y := (A_ScreenHeight // 2) - 20
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
    enZona := (mx >= 79 && mx <= 1168 && my >= 626 && my <= 762)
    if (enZona && !hist.abierto) {
        hist.abierto := true
        Send("{Numpad9}")
    } else if (!enZona && hist.abierto) {
        hist.abierto := false
        Send("{Numpad9}")
    }
}

ChequearZonaAltA() {
    if !WinActive("ahk_exe CLIPStudioPaint.exe")
        return
    MouseGetPos(&mx, &my)
    enZona1 := (mx >= 5 && mx <= 34 && my >= 73 && my <= 95)
    if (enZona1 && !btn.b1) {
        btn.b1 := true
        Click()
    } else if (!enZona1 && btn.b1)
        btn.b1 := false
    enZona2 := (mx >= 5 && mx <= 34 && my >= 105 && my <= 125)
    if (enZona2 && !btn.b2) {
        btn.b2 := true
        Click()
    } else if (!enZona2 && btn.b2)
        btn.b2 := false
    enZona3 := (mx >= 5 && mx <= 31 && my >= 132 && my <= 150)
    if (enZona3 && !btn.b3) {
        btn.b3 := true
        Click()
    } else if (!enZona3 && btn.b3)
        btn.b3 := false
}

ChequearZonaDerecha() {
    if !WinActive("ahk_exe CLIPStudioPaint.exe")
        return
    MouseGetPos(&mx, &my)
    enZona1 := (mx >= 1339 && mx <= 1367 && my >= 84 && my <= 101)
    if (enZona1 && !botDer.b1) {
        botDer.b1 := true
        Click()
    } else if (!enZona1 && botDer.b1)
        botDer.b1 := false
    enZona2 := (mx >= 1339 && mx <= 1368 && my >= 110 && my <= 128)
    if (enZona2 && !botDer.b2) {
        botDer.b2 := true
        Click()
    } else if (!enZona2 && botDer.b2)
        botDer.b2 := false
    enZona3 := (mx >= 1342 && mx <= 1365 && my >= 138 && my <= 159)
    if (enZona3 && !botDer.b3) {
        botDer.b3 := true
        Click()
    } else if (!enZona3 && botDer.b3)
        botDer.b3 := false
    enZona4 := (mx >= 1342 && mx <= 1368 && my >= 167 && my <= 185)
    if (enZona4 && !botDer.b4) {
        botDer.b4 := true
        Click()
    } else if (!enZona4 && botDer.b4)
        botDer.b4 := false
}

LoopColorV() {
    if (!colorV.hover || !WinActive("ahk_exe CLIPStudioPaint.exe"))
        return
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
    if (!ar.hover || !WinActive("ahk_exe CLIPStudioPaint.exe"))
        return
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
        SendInput("{Blind}{- 63}")
        Q.estadoEstab := 1
        Sleep(10)
        ToolTip("🟢 Estabilización Alta")
        SetTimer(QuitarToolTip, -800)
        Loop 3
            SoundBeep(700 + (A_Index * 130), 80)
    } else {
        SendInput("{Blind}{j 63}")
        Q.estadoEstab := 0
        Sleep(10)
        ToolTip("🔵 Estabilización Baja")
        SetTimer(QuitarToolTip, -800)
    }
}

_CheckGitDone() {
    ToolTip("✅ GitHub actualizado")
    SoundPlay(A_WinDir "\Media\Windows Navigation Start.wav")
    SetTimer(QuitarToolTip, -2000)
}

ResetEstadoAltX() {
    sel.estadoAltX := false
    sel.guiActivo  := false
}

__ResetEstadoC() {
    sel.estadoC := 0
}

; ── ToolTips ─────────────────────────────────────────────────────
; Slot 1 : tooltips generales
; Slot 2 : CustomToolTip (shift+r etc.)
; Slot 3 : MostrarToolTipE — AISLADO, nunca cancelado por slot 1

QuitarToolTip()      => ToolTip()
OcultarToolTip()     => ToolTip()
OcultarToolTipAltG() => ToolTip()
OcultarToolTipQ()    => ToolTip()
OcultarIndicador()   => ToolTip()
QuitarToolTipE()     => ToolTip(, , , 3)

MostrarIndicador(texto) {
    ToolTip(texto)
    SetTimer(OcultarIndicador, -2500)
}

; Slot 3 exclusivo — no interfiere con QuitarToolTip (slot 1)
MostrarToolTipE(texto, duracion := 3000) {
    ToolTip(texto, A_ScreenWidth // 2, 115, 3)
    SetTimer(QuitarToolTipE, -duracion)
}

ToolTipCS(texto, duracion := 800) {
    WinGetPos(&wx, &wy, &ww, , "A")
    ToolTip(texto, wx + (ww // 2), wy + 125)
    SetTimer(QuitarToolTip, -duracion)
}

CustomToolTip(text, duration := 1500) {
    ToolTip(text, , , 2)
    SetTimer(RemoveCustomToolTip, -duration)
}

RemoveCustomToolTip() => ToolTip(, , , 2)

MostrarMiniTexto(texto, colorHex := "222222", duracion := 800, colorTexto := "FFFFFF") {
    ; Destruir GUI anterior si existe
    try {
        if IsObject(floatGui.miniTip)
            floatGui.miniTip.Destroy()
    }
    floatGui.miniTip := 0

    ; Generar ID único para esta instancia
    thisID := A_TickCount
    floatGui.miniTipID   := thisID
    floatGui.miniTipTick := thisID

    g := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20")
    g.BackColor := colorHex
    g.SetFont("s6.5 Bold", "Segoe UI")
    g.AddText("c" colorTexto " Center", texto)
    g.Show("NoActivate AutoSize")
    WinSetTransparent(200, "ahk_id " g.Hwnd)
    g.GetPos(, , &w, &h)
    sw := SysGet(78)
    sh := SysGet(79)
    g.Move((sw - w) // 2, Round(sh * 0.47))
    if (w > 300)
        g.Show("w300 h" h)
    floatGui.miniTip := g

    ; Capturar ID en closure — solo destruye si sigue siendo el GUI activo
    capturedID := thisID
    SetTimer(() => _OcultarMiniTipSi(capturedID), -duracion)
}

_OcultarMiniTipSi(id) {
    if (floatGui.miniTipID != id)
        return                          ; ya fue reemplazado, no tocar
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
    g.SetFont("s6.5 Bold", "Segoe UI")
    g.AddText("cFFFFFF Center", texto)
    g.Show("AutoSize NoActivate")
    WinSetTransparent(200, "ahk_id " g.Hwnd)
    g.GetPos(, , &w, &h)
    g.Move((A_ScreenWidth - w) // 2, Round(A_ScreenHeight * 0.02))
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
        g.SetFont("s7.5 Bold cWhite", "Segoe UI")
        simColor := "Lime"
    } else {
        g.BackColor := "D92B2B"
        g.SetFont("s7.5 Bold cWhite", "Segoe UI")
        simColor := "White"
    }
    g.AddText("x6 y4 w130 h14 Center", titulo)
    g.SetFont("s8.5 Bold c" simColor, "Segoe UI")
    g.AddText("x140 y2 w14 h14 Center", simbolo)
    g.Show("w155 h20 Center NoActivate")
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
    MouseGetPos(&origX, &origY)
    MouseMove(32, 64, 0)
    Sleep(8)
    Click()
    Sleep(12)
    MouseMove(1339, 65, 0)
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
    g.SetFont("s7 Bold", "Segoe UI")
    g.AddText("cFFFFFF Center", "🎯 MODO ENFOQUE")
    g.Show("NoActivate AutoSize")
    WinSetTransparent(210, "ahk_id " g.Hwnd)
    g.GetPos(, , &w, &h)
    sw := SysGet(78)
    sh := SysGet(79)
    g.Move((sw - w) // 2, Round(sh * 0.47))
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
    ; Si CSP no está activo, resetear estado
    if !WinActive("ahk_exe CLIPStudioPaint.exe") {
        if (colorEstado = 2)
            Send("k")
        if (colorEstado = 1)
            SendInput("^2")
        colorEstado := 0
        return
    }
    ; Watchdog: si miniTip lleva más de 4s visible, destruirlo por ID
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
SetTimer(ResetAlphaStates, 500)

#HotIf WinActive("ahk_exe CLIPStudioPaint.exe")
RButton & f:: {
    global colorEstado
    ; Reset duro — no confía en colorEstado, fuerza CSP a primario sin importar el estado
    if (colorEstado = 1)
        SendInput("^2")         ; salir de secundario si aplica
    Send("k")                   ; k siempre: si estaba en alpha sale, si no estaba es no-op en CSP
    Send("k")                   ; segunda k por si había doble desfase
    colorEstado := 0
    MostrarMiniTexto("🔄 RESET → COLOR PRIMARIO", "1A1A2E", 1200)
}
#HotIf
