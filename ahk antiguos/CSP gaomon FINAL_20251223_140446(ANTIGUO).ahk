; =============================================================
; 🔄 AHK GUARDADO + RECARGA AUTOMATICA + SONIDO DE CONFIRMACION
; =============================================================

#SingleInstance Force
#Persistent
#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%

FVKPath := "C:\Users\JOSUE BG\Downloads\FreeVK\FreeVK.exe"
toggle := false
CSPWindowTitle := "CLIP STUDIO PAINT"

; ------------------------------------------------------------
; AUTO-RECARGA + NOTIFICACIÓN (TOOLTIP + SONIDO)
; ------------------------------------------------------------
SetTimer, CheckReload, 600
global lastModTime := ""

CheckReload:
{
    FileGetTime, newTime, %A_ScriptFullPath%, M

    if (lastModTime = "") {
        lastModTime := newTime
        return
    }

    if (newTime != lastModTime) {
        lastModTime := newTime

        ; 🔵 Tooltip centrado
        x := (A_ScreenWidth // 2) - 120
        y := (A_ScreenHeight // 2) - 20
        ToolTip, 💾 Script actualizado y recargado, %x%, %y%

        ; 🔔 Sonido fuerte y claro (tres pitidos Windows)
        SoundBeep, 750, 180
        SoundBeep, 950, 180
        SoundBeep, 850, 180

        Sleep, 300      ; deja respirar el tooltip 0.3s (lo máximo que permitirá AHK)
        ToolTip        ; lo limpia

        Reload
    }
}
return

; ------------------------------------------------------------
; RESTO DE TU SCRIPT (IDÉNTICO)
; ------------------------------------------------------------
comboUsed := false

~Space & w::
    Gosub, ToggleKeyboard
return

RButton & q::
    comboUsed := true
    Gosub, ToggleKeyboard
return

RButton Up::
    if (!comboUsed)
        Click Right
    comboUsed := false
return

ToggleKeyboard:
{
    global toggle, FVKPath, CSPWindowTitle

    IfWinNotExist, %CSPWindowTitle%
        return

    toggle := !toggle

    if (toggle) {
        Run, %FVKPath%
        WinWait, Free Virtual Keyboard,, 2
        if ErrorLevel {
            MsgBox, No se pudo abrir FreeVK
            toggle := false
            Return
        }
        WinMove, Free Virtual Keyboard,, 1920, 0
        WinSet, AlwaysOnTop, On, Free Virtual Keyboard
    } else {
        IfWinExist, Free Virtual Keyboard
            WinClose, Free Virtual Keyboard
    }
return
}

; -------------------------------------------------------------
; 🔄 Alternar entre modo escritura y modo AHK con  |
; -------------------------------------------------------------
|::
    Suspend, Permit
    modoEscritura := !modoEscritura

    if (modoEscritura) {
        Suspend, On
        MostrarIndicador("🔴📝📝📝 MODO ESCRITURA — puedes escribir libremente📝📝📝🔴")
    } else {
        Suspend, Off
        MostrarIndicador("🟢✅✅✅ MODO AHK ACTIVO — hotkeys habilitadas✅✅✅🟢")
    }
return


MostrarIndicador(texto) {
    ToolTip, %texto%
    SetTimer, OcultarIndicador, -2500
}

OcultarIndicador:
    ToolTip
return

; -------------------------------------------------------------
; PUNTO DE INICIO DE HOTKEYS FUNCIONANDO🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻
; -------------------------------------------------------------


;===========================================================================
;                CONFIGURACIÓN PARA CLIP STUDIO PAINT                      |
;===========================================================================
#IfWinActive ahk_exe CLIPStudioPaint.exe ; Para que esta configuracion solo funcione dentro de CSP
;✅✅Para que funcionen todos los scripts deben estar asignados los siguientes botones: 1)Alt + b(abajo)  y 2)Click derecho(arriba)


;===========================================================================
;@@@@@@@@@@@@@@@@@@@@@@@@ VARIABLES GLOBALES @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@  (No modificar a menos que se plantee crear una nueva tecla con nuevas funciones personalizadas
;===========================================================================

lastSPress := 0
lastDPress := 0
lastAPress := 0
lastWPress := 0
lastEPress := 0
lastQPress := 0
lastCtrlQPress := 0
lastCtrlWPress := 0s
lastOPress := 0 
global estadoCaracter := 0

;▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
;			 SELECCION Y RESELECCION
;▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

; Teclas asignadas para SELECCION, RESELECCION Y CONTROL DE BORDE INTERNO Y EXTERNO:
;   [X]         => SELECCIONAR / RESELECCIONAR
;   [Alt+X]     => MOSTRAR  BORDE / OCULTAR BORDE
;   [C] 		=> INVERTIR ÁREA SELECCIONADA 	

#SingleInstance Force
SendMode Input
SetWorkingDir %A_ScriptDir%
SetTitleMatchMode, 2

; ------------------- Variables Globales -------------------
estado := 0           ; Alternancia de selección / reselección
estadoAltX := false   ; Estado del borde
estadoC := 0          ; Alternancia de color [C]

; =========================================================
; [Alt + X] ===> MOSTRAR / OCULTAR BORDE DE SELECCIÓN
; =========================================================
!x::AlternarEstadoAltX()
return

AlternarEstadoAltX() {
    global estadoAltX
    if estadoAltX {
        MostrarMiniTexto("👁 MOSTRAR BORDE", "2ECC71", 1200) ; verde
        estadoAltX := false
    } else {
        MostrarMiniTexto("🚫 OCULTAR BORDE", "E74C3C", 1200) ; rojo
        estadoAltX := true
    }
    Send, {Alt down}{x}{Alt up}
    SetTimer, ResetEstadoAltX, -3000
}

ResetEstadoAltX:
    estadoAltX := false
return

; =========================================================
; [C] => INVERTIR ÁREA SELECCIONADAXX
; =========================================================
c::
    if (estadoC = 0) {
        MostrarMiniTexto("🔄 INV. ÁREA SELECC.", "FF6F61", 900)  ; rojo coral
        estadoC := 1
    } else {
        MostrarMiniTexto("🔁 INV. ÁREA SELECC.", "000000", 900)  ; negro
        estadoC := 0
    }
    Send, c
return

; =========================================================
; [X] ===> SELECCIONAR / RESELECCIONAR
; =========================================================
x::
if (estado = 0) {
    MostrarMiniTexto("❌ DESELECCIÓN", "C0392B", 700) ; rojo suave
    Send, x
    estado := 1
} else {
    MostrarMiniTexto("✅ RESELECCIÓN", "27AE60", 1200) ; verde suave
    Send, {F10}
    estado := 0
}
return

; =========================================================
; FUNCIÓN VISUAL UNIFICADA
; =========================================================
MostrarMiniTexto(texto, colorHex := "222222", duracion := 800) {
    Gui, MiniTip:Destroy
    Gui, MiniTip:-Caption +AlwaysOnTop +ToolWindow +E0x20
    Gui, MiniTip:Color, %colorHex%
    Gui, MiniTip:Font, s6.5 Bold, Segoe UI
    Gui, MiniTip:Add, Text, cFFFFFF Center, %texto%
    Gui, MiniTip:Show, NoActivate AutoSize
    WinSet, Transparent, 200, MiniTip  ; ligera transparencia (igual que los otros)

    ; Centrado inferior, un poco elevado
    SysGet, sw, 78
    SysGet, sh, 79
    WinGetPos, , , w, h, MiniTip
    x := (sw - w) // 2
    y := (sh * 0.82)
    WinMove, MiniTip,, x, y

    ; Limitar ancho si es demasiado largo
    if (w > 300)
        Gui, MiniTip:Show, w300, h%h%

    SetTimer, OcultarMiniTip, -%duracion%
}

OcultarMiniTip:
    Gui, MiniTip:Destroy
return
;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■

; [Ctrl+Z] ===> "DESHACER"
; [Alt+Z] o [Stylus Alt+B+Z] ===> "REHACER"

#NoEnv
#UseHook
#SingleInstance Force
SendMode Input
SetKeyDelay, -1, -1
global stylusAltActive := false

~!b:: stylusAltActive := true
~!b up:: stylusAltActive := false

#If !stylusAltActive
z::
    SendInput, z
return
#If

; Ctrl+Z → DESHACER
^z::
    SendInput, ^z
    MostrarToolTipCS("🔴 DESHACER", 300)
return

; Alt+Z → REHACER
!z::
    SendInput, ^y
    MostrarToolTipCS("🟢 REHACER", 600)
return

; Stylus Alt+B+Z → REHACER
#If stylusAltActive
z::
    SendInput, ^y
    MostrarToolTipCS("🟢 REHACER", 600)
return
#If

; =========================
; Función ToolTip centrado sobre ventana activa (Clip Studio)
; =========================
MostrarToolTipCS(texto, duracion := 800) {
    CoordMode, ToolTip, Screen  ; Coordenadas absolutas

    ; Obtener posición y tamaño de la ventana activa
    WinGetPos, wx, wy, ww, wh, A

    ; Ajustar tooltip: centrado horizontal y un poco abajo del borde superior
    x := wx + (ww // 2)
    y := wy + 125 ; ajustar según la barra de herramientas

    ToolTip, %texto%, %x%, %y%
    SetTimer, OcultarToolTipCS, -%duracion%
}

OcultarToolTipCS:
    ToolTip
return


;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
; [A Normal]= A ===> "SELECCION aut.de UNA CAPA"
; [A Rápido]= F7 ===> "SELECCION aut. de TODAS LAS CAPAS)
; [Shift+A ]= ñ ===> "CAPA REFERIDA"-- Funcion: Seleccion automatica para la capa establecida como capa de referencia

lastAPress := 0
$a::
    now := A_TickCount
    if (now - lastAPress < 2400) {
        Send, {F7}
        ToolTip, "TODAS LAS CAPAS     (2)"
        SetTimer, QuitarToolTip, -4300
        lastAPress := 0
    } else {
        Send, a
        ToolTip, "CAPA ACTUAL     (1)"
        SetTimer, QuitarToolTip, -1300
        lastAPress := now
    }
return
;___________________
+a::
    Send, ñ
    ToolTip, "CAPA REFERIDA"
    SetTimer, QuitarToolTip, -2300
return


;▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
;				HERRAMIENTAS  
;▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
; E normal ===> E (BORRADOR NORMAL)  [con pequeño buffer]
; E rápido (doble tap) ===> L (BORRADOR SUAVE)
; CLIC DERECHO + E ===> K (COLOR TRANSPARENTE / PRINCIPAL)

lastE := 0
eTimerRunning := 0
colorTransparente := false

; =========================
; TECLA E
; =========================
$e::
now := A_TickCount

; Shift + E → enviar E normal
if (GetKeyState("Shift")) {
    Send, e
    return
}

; Doble tap → BORRADOR SUAVE
if (now - lastE < 300) {
    SetTimer, __E_SEND_NORMAL, Off
    eTimerRunning := 0
    Send, l
    MostrarToolTipE("BORRADOR SUAVE  (2)")
    lastE := 0
    return
}

; Primer toque → esperar
lastE := now
eTimerRunning := 1
SetTimer, __E_SEND_NORMAL, -250
return

; =========================
; E NORMAL → BORRADOR NORMAL
; =========================
__E_SEND_NORMAL:
if (eTimerRunning) {
    Send, e
    MostrarToolTipE("BORRADOR NORMAL  (1)")
    eTimerRunning := 0
    lastE := 0
}
return

; =========================
; CLIC DERECHO + E → Alterna COLOR / ALPHA
; =========================
colorTransparente := false
procesando := false  ; evita alternancia rápida que desincroniza

RButton & e::
    if (procesando)
        return  ; si aún se procesa un cambio, ignorar

    procesando := true

    if (colorTransparente) {
        colorTransparente := false
        MostrarToolTipE("🔴🔴COLOR🔴🔴")   ; Tooltip COLOR
    } else {
        colorTransparente := true
        MostrarToolTipE("⚪ ALPHA⚪")          ; Tooltip ALPHA
        
        ; Sonido agradable al activar ALPHA
        SoundPlay, %A_WinDir%\Media\chimes.wav
    }

    Send, k

    ; Pequeño retardo para estabilizar estado
    SetTimer, ResetProcesando, -50
return

ResetProcesando:
    procesando := false
return

; =========================
; FUNCIÓN TOOLTIP
; Arriba - centro de la pantalla
; =========================
MostrarToolTipE(texto, duracion := 10050) {
    CoordMode, ToolTip, Screen

    x := A_ScreenWidth // 2
    y := 115

    ToolTip, %texto%, %x%, %y%
    SetTimer, QuitarToolTip, -%duracion%
}

    ToolTip
return



;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■


; [CTRL + E] ===> F5 (Borrador de todas las capas) 
^e::
{
    ToolTip, "BORRADOR DE TODAS LAS CAPAS"
    Send, {F5}
    SetTimer, QuitarToolTip, -800
    return
}

;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
;EMULAR BOTONES 1 Y 2 DEL TECLADO EN LOS BOTONES DE TABLETA (H y J)

#SingleInstance Force
#Persistent
SendMode Input
SetWorkingDir %A_ScriptDir%

; CONFIGURACIÓN
TimerInterval := 1    ; ms entre envíos → ritmo natural del teclado
HoldDelay     := 300   ; retardo inicial para clics rápidos (0.5 s)
MaxBoost      := 500      ; máximo envíos por tick → aumenta velocidad al mantener presionado

; ===========================================
; FUNCIONES GENERALES
; ===========================================
SendKeyWithBoost(key, startTick) {
    global HoldDelay, MaxBoost
    elapsed := A_TickCount - startTick

    if (elapsed < HoldDelay)
        return

    ; Factor de aceleración progresivo (exponente 0.8)
    ratio := (elapsed - HoldDelay) / 100  ; tiempo desde el retardo inicial
    if (ratio > 1)
        ratio := 1

    boost := Round(MaxBoost * (ratio ** 0.1))
    if (boost < 1)
        boost := 1

    Loop % boost
        SendInput {Blind}%key%
}

; ===========================================
; BOTÓN H — Reducir tamaño
; ===========================================
~h::
    if GetKeyState("RButton", "P")
        return
    hStart := A_TickCount
    repH := true
    SetTimer, HoldH, %TimerInterval%
return

~h up::
    elapsed := A_TickCount - hStart
    SetTimer, HoldH, Off
    repH := false
    if (elapsed < HoldDelay)
        SendInput {Blind}h
return

HoldH:
if repH
    SendKeyWithBoost("h", hStart)
return

; ===========================================
; BOTÓN J — Aumentar tamaño
; ===========================================
~j::
    if GetKeyState("RButton", "P")
        return
    jStart := A_TickCount
    repJ := true
    SetTimer, HoldJ, %TimerInterval%
return

~j up::
    elapsed := A_TickCount - jStart
    SetTimer, HoldJ, Off
    repJ := false
    if (elapsed < HoldDelay)
        SendInput {Blind}j
return

HoldJ:
if repJ
    SendKeyWithBoost("j", jStart)
return 


;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
; [ESPACIO + S] → Alterna entre “AGREGAR A SELECCIÓN” / “ELIMINAR DE SELECCIÓN”
; ———————————————————————————————————————————————————————————————————
estadoCaracter := 0 S
$s::
    if GetKeyState("Space", "P") {
        ; No enviar la letra S
        if (estadoCaracter = 0) {
            Send, ,
            MostrarTooltipToggle("AGREGAR A SELECCION", "+", "verde")
            estadoCaracter := 1
        } else {
            Send, .
            MostrarTooltipToggle("ELIMINAR SELECCIÓN", "–", "rojo")
            estadoCaracter := 0
        }
        SetTimer, QuitarTooltipToggle, -1500
    } else {
        Send, s
    }
return

; ————————————————————————————————————————————————
; FUNCIÓN PARA TOGGLE (más compacta)
; ————————————————————————————————————————————————

MostrarTooltipToggle(titulo, simbolo, color)
{
    Gui, TooltipToggle:Destroy
    Gui, TooltipToggle:+AlwaysOnTop -Caption +ToolWindow +E0x20

    if (color = "verde") {
        Gui, TooltipToggle:Color, 0x1F4D3A
        Gui, TooltipToggle:Font, s7.5 Bold cWhite, Segoe UI
        simboloColor := "Lime"
    } else {
        Gui, TooltipToggle:Color, 0xD92B2B
        Gui, TooltipToggle:Font, s7.5 Bold cWhite, Segoe UI
        simboloColor := "White"
    }

    ; === Texto más ceñido al borde y menor altura ===
    Gui, TooltipToggle:Add, Text, x6 y4 w130 h14 Center, %titulo%
    Gui, TooltipToggle:Font, s8.5 Bold c%simboloColor%
    Gui, TooltipToggle:Add, Text, x140 y2 w14 h14 Center, %simbolo%

    Gui, TooltipToggle:Show, w155 h20 Center NoActivate
}

QuitarTooltipToggle:
Gui, TooltipToggle:Destroy
return


; ————————————————————————————————————————————————
; FUNCIÓN PARA SELECCIÓN (más compacta)
; ————————————————————————————————————————————————

MostrarTooltipSeleccion(titulo, simbolo, color)
{
    Gui, TooltipSel:Destroy
    Gui, TooltipSel:+AlwaysOnTop -Caption +ToolWindow +E0x20
    Gui, TooltipSel:Color, 0x3A4B7A
    Gui, TooltipSel:Font, s7.5 Bold cWhite, Segoe UI

    simboloColor := (color = "verde") ? "Lime" : "Red"

    Gui, TooltipSel:Add, Text, x6 y4 w120 h14 Center, %titulo%
    Gui, TooltipSel:Font, s8.5 Bold c%simboloColor%
    Gui, TooltipSel:Add, Text, x132 y2 w14 h14 Center, %simbolo%

    Gui, TooltipSel:Show, w145 h20 Center NoActivate
}

QuitarTooltipSel:
Gui, TooltipSel:Destroy
return


;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
; ==================================
; Q normal ===> Q
; Q rápido (doble tap) ===> Ctrl + 2
; Alterna COLOR PRINCIPAL / SECUNDARIO
; ==================================

lastQ := 0
qTimerRunning := 0

$q::
now := A_TickCount

; Doble tap → CTRL + 2 (toggle)
if (now - lastQ < 300) {
    SetTimer, __Q_SEND_NORMAL, Off
    qTimerRunning := 0

    ; Enviar atajo real
    Send, ^2

    ; Alternar estado espejo
    qColorSecundario := !qColorSecundario

    if (qColorSecundario) {
        MostrarToolTipE("🟡 COLOR SECUNDARIO")
        SoundPlay, %A_WinDir%\Media\ding.wav
    } else {
        MostrarToolTipE("🔵 COLOR PRINCIPAL")
    }

    lastQ := 0
    return
}

; Primer toque → esperar
lastQ := now
qTimerRunning := 1
SetTimer, __Q_SEND_NORMAL, -250
return

; =========================
; Q NORMAL
; =========================
__Q_SEND_NORMAL:
if (qTimerRunning) {
    Send, q
    qTimerRunning := 0
    lastQ := 0
}
return
;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
; ==================================
; W normal ===> AERÓGRAFO COLOR
; W rápido (doble tap) ===> AERÓGRAFO ALPHA
; ==================================

lastW := 0
wTimerRunning := 0
wAlpha := false  ; estado espejo

$w::
now := A_TickCount

; -------------------------
; DOBLE TAP → AERÓGRAFO ALPHA
; -------------------------
if (now - lastW < 300) {
    SetTimer, __W_SEND_NORMAL, Off
    wTimerRunning := 0

    ; Forzar ALPHA
    if (!wAlpha) {
        Send, k
        wAlpha := true
    }

    Send, w
    MostrarToolTipE("⚪ AERÓGRAFO ALPHA")
    SoundPlay, %A_WinDir%\Media\chimes.wav

    lastW := 0
    return
}

; -------------------------
; PRIMER TAP → esperar
; -------------------------
lastW := now
wTimerRunning := 1
SetTimer, __W_SEND_NORMAL, -250
return

; =========================
; W NORMAL → AERÓGRAFO COLOR
; =========================
__W_SEND_NORMAL:
if (wTimerRunning) {

    ; Forzar COLOR
    if (wAlpha) {
        Send, k
        wAlpha := false
    }

    Send, w
    MostrarToolTipE("💨 AERÓGRAFO")

    wTimerRunning := 0
    lastW := 0
}
return

;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
; [ESPACIO] + (+) ===> Ctrl+p (AMPLIAR AREA SELECCIONADA) 
; [ESPACIO] + (-) ===> Ctrl+shift+p (REDUCIR AREA SELECCIONADA)

~Space & NumpadAdd::Send, +p        ; para Espacio + [+] del Numpad
~Space & NumpadSub::Send, ^+p      ; para Espacio + [-] del Numpad


;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
; [SHIFT + V] ===> F12 ("DESLIZADOR DE COLORES")
+v::
{
    ToolTip, "DESLIZADOR DE COLORES"
    Send, {F12}
    SetTimer, QuitarToolTip, -300
    return
}


;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
; [Shift + R] ===> Voltear horizontalmente
+r::
    CustomToolTip("REFLEJAR HORIZONTALMENTE")
    Send, +r
return


;▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
;			 ATAJOS CON CLIC DERECHO(arriba) E IZQ(abajo)  	
;▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
; Alt + B(Click izquierda) + S → ÁREA CON COLOR (Ctrl+X + Alt+X)
; ——————————————————————————————————————————————————————————————————————————

!s::
{
    MostrarMiniGUI("🟢 ÁREA CON COLOR", "27AE60") ; Verde
    SendInput, ^x
    SendInput, !x
return
}

; ————————————————————————
; Mini GUI flotante compacta (30% más pequeña y duradera)
; ————————————————————————

MostrarMiniGUI(texto, colorHex := "222222", duracion := 1200) {
    Gui, MiniGUI:Destroy
    Gui, MiniGUI:-Caption +AlwaysOnTop +ToolWindow +E0x20
    Gui, MiniGUI:Color, %colorHex%
    Gui, MiniGUI:Font, s6.5 Bold, Segoe UI
    Gui, MiniGUI:Add, Text, cFFFFFF Center, %texto%
    Gui, MiniGUI:Show, NoActivate AutoSize
    WinSet, Transparent, 200, MiniGUI

    ; Centrado superior dinámico
    SysGet, sw, 78
    SysGet, sh, 79
    WinGetPos, , , w, h, MiniGUI
    x := (sw - w) // 2
    y := (sh * 0.02)
    WinMove, MiniGUI,, x, y

    if (w > 300)
        Gui, MiniGUI:Show, w300, h%h%

    SetTimer, OcultarMiniGUI, -%duracion%
}

OcultarMiniGUI:
    Gui, MiniGUI:Destroy
return


;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
; [CLIC DERECHO + V] ===> F11 (RELLENO DE COLOR) 
RButton & v::
{
    ToolTip, "RELLENO DE COLOR"
    Send, {F11} 
    SetTimer, QuitarToolTip, -800
    return
} 


;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 
; [CLIC DERECHO + S] ===> F9 (Lazo con autorelleno)
RButton & s::
{
    ToolTip, "LAZO CON AUTORELLENO"
    Send, {F9}
    SetTimer, QuitarToolTip, -1200
    return
}


;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
; [CLIC DERECHO + NÚMEROS (1 al 0)] ===> Control de nivel de opacidad (10 a 100%)
;——————————————————————————————————————————————————————————————————————————
; Asigna el mismo hotkey para todos los números usando un comodín (*)
#UseHook
RButton & 1::
RButton & 2::
RButton & 3::
RButton & 4::
RButton & 5::
RButton & 6::
RButton & 7::
RButton & 8::
RButton & 9::
RButton & 0::
{
    key := SubStr(A_ThisHotkey, 0)          ; Obtiene el último carácter del hotkey (el número)
    porcentaje := (key = 0 ? 100 : key * 10) ; Si es 0 ===> 100%, si no ===> número * 10
    ToolTip, OPACIDAD %porcentaje% Porciento
    Send, +%key%                            ; Envía Shift + número
    SetTimer, QuitarToolTip, -1500
    return
}

;▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
;			 MODIFICADORES DE SELECCIÓN Y CAPAS 	
;▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
; [ESPACIO + NUMPAD 1–6] → Tipos de capa de corrección
;——————————————————————————————————————————————————————
#UseHook
#NoEnv
SendMode Input
SetKeyDelay, -1, -1

~Space & Numpad1::
~Space & Numpad2::
~Space & Numpad3::
~Space & Numpad4::
~Space & Numpad5::
~Space & Numpad6::
{
    ; Captura el número presionado
    tecla := SubStr(A_ThisHotkey, 0)

    ; Diccionario con los nombres de cada capa
    tipos := {1: "HSV (Hue / Saturation / Value)"
            , 2: "Brillo / Contraste"
            , 3: "Equilibrio de color"
            , 4: "Curva de tonos"
            , 5: "Corrección de nivel"
            , 6: "Degradado"}

    ; Muestra el tooltip
    ToolTip, % "Capa: " tipos[tecla]

    ; Envía el comando correspondiente (Ctrl+Alt+número)
    Send, ^!%tecla%

    ; Oculta el tooltip después de 500 ms
    SetTimer, QuitarToolTip, -500
    return
}


;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
; [NUMPAD 6] ===> i)CREAR Capa Escala de grises (7) / ii) BORRAR capa de correción (8) 
;——————————————————————————————————————————————————————————————————————————
;Explicacion: "FUNCIONA ALTERNANDO ENTRE  DOS ACCIONES AUTOMÁTICAS"
;i) Crea una capa HSV con Saturacion  y reduce la saturación a 0
;ii) Es la acción automática que la borra 

estadoEscala := 0 ;variable que define si está activado o no

$Numpad6::
if (estadoEscala = 0) {
    Send, 7
    ToolTip, "CAPA ESCALA DE GRISES" ;la crea
    estadoEscala := 1
} else {
    Send, 8
    ToolTip, "BORRAR CAPA DE CORRECION" ;sino la destruye
    estadoEscala := 0
}
SetTimer, QuitarToolTip, -1200
return


;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
;[ESPACIO + BACKSPACE] ===> 8 (BORRAR CAPA DE CORRECCIÓN)
;——————————————————————————————————————————————————————
*Backspace::
if GetKeyState("Space", "P") {
    ; Si Espacio está presionado, no ejecutar Backspace, sino enviar 8
    Send, 8
    ToolTip, BORRAR CAPA DE CORRECCIÓN
    SetTimer, QuitarToolTip, -1200
    estadoEscala := 0
    return  ; ← Impide que Backspace borre texto
} else {
    Send, {Backspace}  ; ← Comportamiento normal si no hay Espacio presionado
}
return  

;▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
;						OBJETO Y MOVER CAPA  	
;▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
; FUNCIONALIDAD:
; - Pulsar "o" normalmente     → escribe "o" y muestra "MOVER CAPA"
; - Pulsar "o" dos veces rápido → envía F8 y muestra "OBJETO"
; - Pulsar Alt+o o stylus+o   → envía Numpad9 y muestra "SELECCIONAR CAPAS"
; ————————————————————————

$*o::
    currentTime := A_TickCount ; Tiempo actual para detectar pulsaciones rápidas


;CASO 1: Alt presionado o stylusAltActive → F3

    ; === 1) Alt (o stylusAltActive) + O → F3
    if ( GetKeyState("Alt", "P") || stylusAltActive ) {
        Send, {F3}
        ToolTip, "SELECCIONAR CAPAS"
        SetTimer, QuitarToolTip, -1500
        return
    }

;CASO 2: Doble pulsación rápida → F8

    ; === 2) Doble toque rápido → F8
    if ( currentTime - lastOPress < 540 ) {
        Send, {F8}
        ToolTip, "OBJETO"
        SetTimer, QuitarToolTip, -1500
        lastOPress := 0

;CASO 3: Pulsación normal → o
    }
    else {
        ; === 3) Toque normal → letra o
        Send, o
        ToolTip, "MOVER CAPA"
        SetTimer, QuitarToolTip, -1500
        lastOPress := currentTime
    }
return
; ————————————————————————

;Función para quitar el tooltip después del tiempo definido
QuitarToolTip() {
    ToolTip
}




;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
; Función para quitar ToolTips
QuitarToolTip:
    ToolTip  ; Quita el mensaje
return

;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
; Restaura funcionalidad normal de la tecla espacio
~Space::return						

;▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
;               FUNCIÓN PARA TOOLTIPS PERSONALIZADOS                        |(No modificar)
;▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
CustomToolTip(text, duration := 1500) {
    ToolTip, % text, , , 2 ; Usa la posición 2 para ToolTips personalizados
    SetTimer, RemoveCustomToolTip, % -duration ; Elimina el ToolTip después del tiempo especificado
    return

    RemoveCustomToolTip:
        ToolTip, , , , 2 ; Elimina el ToolTip personalizado
    return
}
#IfWinActive




; -------------------------------------------------------------
; PUNTO DE FIN DE HOTKEYS FUNCIONANDO🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻
; -------------------------------------------------------------
