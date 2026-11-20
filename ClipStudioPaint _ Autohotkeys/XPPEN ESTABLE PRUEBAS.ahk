#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, OutputDebug

; --- Entorno de Pruebas: Auto-elevación opcional y tolerante ---
if !A_IsAdmin {
    try {
        Run('*RunAs "' A_ScriptFullPath '"')
        ExitApp()
    } catch {
        ; Si el usuario cancela o no hay admin, continúa en modo usuario para pruebas
    }
}

_icOk := false
for _ic in [A_ScriptDir "\iconos\clipstudio.ico", A_ScriptDir "\clipstudio.ico"] {
    if FileExist(_ic) {
        try {
            TraySetIcon(_ic)
            _icOk := true
        }
        break
    }
}
if !_icOk {
    try TraySetIcon(A_WinDir "\System32\mspaint.exe", 1)
    catch
        try TraySetIcon("shell32.dll", 71)
}

DllCall("SetThreadDpiAwarenessContext","ptr",-3,"ptr")
SendMode("Input")
KEY_NTILDE := "{vkC0sc027}"
KEY_MENOR := "{vkE2sc056}"
EnviarNtilde() => SendInput(KEY_NTILDE)
EnviarMenor() => SendInput(KEY_MENOR)
SetWorkingDir(A_ScriptDir)
SetKeyDelay(-1,-1)
SetMouseDelay(-1)
SetDefaultMouseSpeed(0)
CoordMode("Mouse","Screen")
CoordMode("ToolTip","Screen")
SetTitleMatchMode(2)

sys := {lastModTime:"",modoEscritura:false}
stylus := {altActive:false,rButtonHeld:false,comboUsado:false,upSinteticoTick:0,botonSostenido:false,smearSend:false,ignorarUpSintetico:false,bSinteticoTick:0,origX:0,origY:0,spaceFlipTimerRunning:0,origenCompanion:false}
sel := {estado:0,estadoAltX:false,estadoC:0,guiActivo:false,sRapido:false}
colorEstado := 0
UP_SINTETICO_MS := 70
S_RAPIDO_MS := 400
ESTAB_MIN := 7
ESTAB_MAX := 75
ESTAB_RACHA := 10
ESTAB_RITMO := 18
ESTAB_COLOR := "9A7BFF"
ESTAB_ALPHA_H := 128
ESTAB_ALPHA_ACT := 235
ESTAB_ALPHA_F := 150
FOCO_GRACIA_MS := 200
FOCO_TIMEOUT_MS := 10000

; --- Estabilizador universal ---
STAB_BASE := ESTAB_MIN
STAB_RESET_FISICO := true
STAB_RESET_DELAY_MS := 30
STAB_POR_HERRAMIENTA := Map()
STAB_ABSOLUTO := true
STAB_CONFIANZA_MS := 1500
stabU := {tool:"",ocupado:false,rearmar:false,syncTick:0,abortar:false,known:Map(),objetivo:-1}
STAB_KNOWN_INI := A_ScriptDir "\estab_known.ini"
STAB_ALIAS := Map("x","q")

E := {procesando:false,last:0}
W := {last:0}
Z := {last:0,timerRunning:0,estaAbajo:false}
Q := {last:0,estadoEstab:0,pendiente:false}
RM := {last:0}
A_state := {lastPress:0}
AltS_state := {lastPress:0}
AltB_s_state := {lastPress:0,timerRunning:0}
AltB_a_state := {lastPress:0,timerRunning:0}
AltF_state := {lastPress:0,timerRunning:0,held:false}
S := {estadoCaracter:0,skipNext:false,lastTick:0}
O := {ciclo:0}
N6 := {estadoEscala:0,layerVis:1}
hist := {abierto:false,modo:1,id:0}
btn := {b1:false,b2:false,b3:false}
botDer := {b1:false,b2:false,b3:false}
colorV := {dsID:0,dsVis:false,bDS:0,hover:true,cspHwnd:0,dsX:0,dsY:0,dsW:0,dsH:0,supresionHasta:0}
colorCC := {id:0,dsVis:false,bCC:0,hover:false,ccX:0,ccY:0,ccW:0,ccH:0,supresionHasta:0}
ar := {id:0,dsVis:false,bAR:0,hover:false}
global floatGui := {miniTip:0,miniGUI:0,tooltipToggle:0,enfoque:0,miniTipTick:0,miniTipID:0,hud:0,hudLabel:0,hudBar:0,hudHwnd:0,hudID:0,hudTick:0,overlayIcon:0,overlayIconID:0,badge:0,badgeHwnd:0,badgeSub:0,badgeMain:0,badgeSubBar:0,badgeBar:0,badgeID:0,badgeTick:0}
global _AvisoBadgesActivos := []
enfoque := {activo:false}
shiftSostenido := {activo:false}
opacidad := {nivel:100}
boost := {holdDelay:300,maxBoost:5}
spc := {last:0,downTick:0,selectArmed:false,rotOn:false}
dial := {modo:1,g:0,icono:0,label:0,barra:0}
dsGui := {g:0,icono:0,label:0,barra:0}
ccGui := {g:0,icono:0,label:0,barra:0}
arGui := {g:0,icono:0,label:0,barra:0}
hcGui := {g:0,icono:0,label:0,barra:0}
nvGui := {g:0,label:0,barra:0}
reloadGui := {g:0,icono:0,label:0,barra:0}
puntosGui := {g:0,icono:0,barra:0}
ptsEd := {g:0,lv:0,ex:0,ey:0,dx:0,dy:0,hAlto:0,eEsc:0,eEscAv:0,eAlpha:0,eAlphaF:0,st:0,bCap:0,sel:0,capturando:false,dibujando:false,ovl:[]}
ptsModo := {sel:1,edit:false,recreando:false,pos:0,btnN:0,btnE:0,barN:0,barE:0}
lockGui := {g:0,icono:0,barra:0}

_ConstruirMenuTray()

_ConstruirMenuTray() {
    A_TrayMenu.Delete()
    A_TrayMenu.Add("⚡ XPPEN ESTABLE PRUEBAS", (*) => MostrarAvisoUI("moderno", "XPPEN ESTABLE PRUEBAS", "ENTORNO ACTIVO", 2, "00E5FF", 1500))
    A_TrayMenu.Default := "⚡ XPPEN ESTABLE PRUEBAS"
    A_TrayMenu.Add()
    mPerfiles := Menu()
    mPerfiles.Add("1. PC (1 Monitor)", (*) => _CambiarPerfilTray(1))
    mPerfiles.Add("2. Laptop", (*) => _CambiarPerfilTray(2))
    mPerfiles.Add("3. PC (2 Monitores)", (*) => _CambiarPerfilTray(3))
    A_TrayMenu.Add("Perfil de Pantalla", mPerfiles)
    A_TrayMenu.Add("Calibrador Moderno (Python)", (*) => AbrirCalibradorPy())
    A_TrayMenu.Add("Calibrador Clásico (Antiguo)", (*) => AbrirPanelPuntos())
    A_TrayMenu.Add()
    A_TrayMenu.Add("Recargar Script (Ctrl+Alt+Shift+R)", (*) => Reload())
    A_TrayMenu.Add("Salir (Ctrl+Alt+Shift+Q)", (*) => ExitApp())
}

_CambiarPerfilTray(nuevo, *) {
    _AplicarCambioPerfil(nuevo)
}

global _cspEraActiva := false
global _bSmearAbajo := false
SetTimer(_VigilaFocoCSP, 150)

; Vigilante de INI en tiempo real ultra-rápido (300 ms) para pruebas inmediatas
SetTimer(_RemapVigilarIniPruebas, 300)
SetTimer(_RemapCargarHotkeys, -200)

_RemapVigilarIniPruebas() {
    static ultimo := ""
    try m := FileGetTime(_PosGuiIniPath(), "M")
    catch
        return
    if (m != ultimo) {
        if (ultimo != "") {
            ; Cambio detectado en caliente: recargar particularidades, teclas y HUD
            try _CalPyRecargarIni()
            try _RemapCargarHotkeys()
            MostrarAvisoUI("moderno", "AJUSTES ACTUALIZADOS", "RECARGA EN TIEMPO REAL OK", 1, "00E5FF", 1200)
        }
        ultimo := m
    }
}

OnExit(_AudAlSalir)
CalPyInit()
SetTimer(_AudPrecargar, -400)

#Include %A_ScriptDir%\lib\core_config.ahk
#Include %A_ScriptDir%\lib\theme_gfx.ahk
#Include %A_ScriptDir%\lib\audio.ahk
#Include %A_ScriptDir%\lib\sonido_evento.ahk
#Include %A_ScriptDir%\lib\comportamientos.ahk
#Include %A_ScriptDir%\lib\hud_badges.ahk
#Include %A_ScriptDir%\lib\gui_builder.ahk
#Include %A_ScriptDir%\lib\companion.ahk
#Include %A_ScriptDir%\lib\estab_slider.ahk
#Include %A_ScriptDir%\lib\calibrador.ahk
#Include %A_ScriptDir%\lib\calibrador_panel.ahk
#Include %A_ScriptDir%\lib\calibrador_py.ahk
#Include %A_ScriptDir%\lib\hotkeys_csp.ahk
#Include %A_ScriptDir%\lib\espacial.ahk
#Include %A_ScriptDir%\lib\diag.ahk

^+!h:: {
    Send("{Ctrl up}{Shift up}{Alt up}")
    Send("^{Escape}")
}

; --- Atajo de Pánico Universal y Recarga de Pruebas ---
#HotIf
^!+q:: ExitApp()
^!+r:: Reload()
