#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, OutputDebug

; if !A_IsAdmin {
;     try Run('*RunAs "' A_ScriptFullPath '"')
;     ExitApp()
; }
for _ic in [A_ScriptDir "\iconos\clipstudio.ico", A_ScriptDir "\clipstudio.ico"] {
    if FileExist(_ic) {
        try TraySetIcon(_ic)
        break
    }
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
stylus := {altActive:false,rButtonHeld:false,comboUsado:false,upSinteticoTick:0,botonSostenido:false,smearSend:false,ignorarUpSintetico:false,bSinteticoTick:0,origX:0,origY:0,spaceFlipTimerRunning:0}
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
STAB_BASE := ESTAB_MIN            ; base de toda herramienta (0 = piso absoluto)
STAB_RESET_FISICO := true         ; true: manda j×100 + «-»×base a CSP; false: solo marca desincronizado
STAB_RESET_DELAY_MS := 30         ; espera a que CSP termine de cambiar de herramienta
STAB_POR_HERRAMIENTA := Map()     ; override opcional, ej: Map("q",40,"w",0,"e",0,"l",0)
STAB_ABSOLUTO := true             ; true: el valor de AHK manda (j x100 + «-» x valor) cuando la base es dudosa; false: comportamiento relativo anterior
STAB_CONFIANZA_MS := 1500         ; ventana (>=500) en que AHK confía en su base tras sincronizar/mover; un clic en CSP la anula
stabU := {tool:"",ocupado:false,rearmar:false,syncTick:0,abortar:false,known:Map(),objetivo:-1}
STAB_KNOWN_INI := A_ScriptDir "\estab_known.ini"
; Herramientas que comparten el mismo estabilizador interno en CSP (ajustar si x y q NO son la misma sub-herramienta)
STAB_ALIAS := Map("x","q")
E := {procesando:false,last:0}
W := {last:0}
Z := {last:0,timerRunning:0}
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
frenteGui := {g:0,icono:0,barra:0}
hubGui := {g:0,icono:0,barra:0,embebidos:Map()}
estabBtnGui := {g:0,icono:0,label:0,barra:0}
estabGui := {g:0,valorTxt:0,grip:0,valor:50,previsto:50,sincronizado:false,arrastrando:false,visible:true,ancho:0,alto:0,txtH:0,trackW:0,trackX:0,trackY:0,trackH:0,knobSize:0,horiz:false,txtW:0,fuente:9,foco:false,rectNormal:0,fAbajo:false,fSoltado:0,fTick:0,fPrevHasta:0,dibV:-1,dibG:""}
_Stab_CargarKnown()
panelBlk := {locked:true,frente:false}
global g_sweepActivo := false
global g_sweepAtomico := true   ; true = congelar/aplicar/redibujar al conmutar el barrido (false = comportamiento anterior)
global _iniPend := Map()
PANEL_GAP := 6
LAYOUT_NORMAL := {ds:{x:-1059,y:143,w:383,h:185},cc:{x:-676,y:143,w:359,h:295},ar:{x:-537,y:438,w:220,h:483},hc:{x:-2240,y:1253,w:1905,h:104}}
LAYOUT_ENFOQUE := {ds:{x:-836,y:136,w:383,h:185},cc:{x:-453,y:118,w:359,h:295},ar:{x:-317,y:413,w:223,h:483},hc:{x:-2240,y:1253,w:1905,h:104}}
PUNTOS_DEF := [[1970,-154],[4437,-154],[1924,-132],[1976,-130],[1923,-95],[1973,-94],[1925,-91],[1973,-89],[1926,-55],[1975,-55],[1927,-47],[1974,-46],[1924,-15],[1976,-10],[4423,-132],[4473,-131],[4423,-99],[4476,-98],[4425,-90],[4474,-89],[4423,-55],[4473,-55],[4426,-47],[4472,-47],[4424,-13],[4475,-10],[2246,1158],[4136,1156],[2011,-225],[2239,-98],[1900,500],[1940,700]]
PUNTOS := []
AVISO_ESC := 1.0
HIST_ALTO := 104
ZONAS := {}
PERFILES := ["Laptop + tableta","Monitor + tableta"]
PERFIL := 1
ElegirPerfil()
ESC := 1.0
CargarEscala()
CargarEscalaAvisos()
CargarPuntos()
; --- [P0] Diagnóstico, Sesión y Restauración preventiva ---
Diag_Iniciar()
Sesion_Iniciar()
RestaurarPanelesCSP()
SetTimer(Prof_T(CheckReload,600),600)
SetTimer(Prof_T(ChequearZonaHistorial,200),200)
SetTimer(Prof_T(ChequearZonaAltA,35),35)
SetTimer(Prof_T(ChequearZonaDerecha,35),35)
SetTimer(Prof_T(LoopColorV,80),80)
SetTimer(Prof_T(LoopColorCC,80),80)
SetTimer(Prof_T(LoopAccesoRapido,80),80)
SetTimer(Prof_T(ResetAlphaStates,500),500)
SetTimer(Prof_T(LimpiarAltPegadoPureRef,150),150)
IniciarDeteccion()
IniciarDsGUI()
IniciarCcGUI()
IniciarArGUI()
IniciarHCGUI()
IniciarNVGUI()
IniciarLockGUI()
IniciarFrenteGUI()
IniciarEstabGUI()
IniciarEstabBtnGUI()
IniciarReloadGUI()
IniciarPuntosGUI()
IniciarHubGUI()
A_TrayMenu.Add("🎨 Paleta del tema",(*) => _AbrirSelectorTema())

global _cspEraActiva := false
global _bSmearAbajo := false
SetTimer(_VigilaFocoCSP, 150)
; --- [P0] Orquestador de Salida Seguro y Registro de Fases ---
Salida_Registrar("paneles", 10, RestaurarPanelesCSP)
Salida_Registrar("modificadores", 20, (*) => _LiberarModificadores(true))
Salida_Registrar("audio", 50, _AudAlSalir)
Salida_Registrar("timer_res", 60, (*) => DllCall("winmm\timeEndPeriod", "UInt", 1))
Salida_Registrar("gdip_tema", 90, _GfxGdipAlSalir)
OnExit(Salir)
Salud_Iniciar()
SetTimer(_AudPrecargar, -400)
#Include %A_ScriptDir%\lib\core_config.ahk
#Include %A_ScriptDir%\lib\theme_gfx.ahk
#Include %A_ScriptDir%\lib\audio.ahk
#Include %A_ScriptDir%\lib\hud_badges.ahk
#Include %A_ScriptDir%\lib\companion.ahk
#Include %A_ScriptDir%\lib\estab_slider.ahk
#Include %A_ScriptDir%\lib\calibrador.ahk
#Include %A_ScriptDir%\lib\hotkeys_csp.ahk
#Include %A_ScriptDir%\lib\diag.ahk
#Include %A_ScriptDir%\lib\salida.ahk

; --- Atajo de Cierre de Pruebas Universal ---
#HotIf
^!+q:: {
    TrayTip("Companion No-Admin", "Finalizadas las pruebas en Companion. Proceso de pruebas cerrado.")
    Sleep(800)
    ExitApp()
}




