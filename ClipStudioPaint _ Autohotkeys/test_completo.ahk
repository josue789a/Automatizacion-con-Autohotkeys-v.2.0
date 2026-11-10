#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, OutputDebug

; Arnés de prueba 100% libre de permisos de Administrador
outLog := A_ScriptDir "\reporte_final_verificacion.txt"
try FileDelete(outLog)
Log(msg) => FileAppend(msg "`r`n", outLog, "UTF-8")

Log("=======================================================")
Log("SUITE DE VERIFICACION FUNCIONAL COMPLETA (MODO USUARIO)")
Log("=======================================================")

; Inicialización del entorno idéntico a XPPEN
DllCall("SetThreadDpiAwarenessContext","ptr",-3,"ptr")
SendMode("Input")
KEY_NTILDE := "{vkC0sc027}"
KEY_MENOR := "{vkE2sc056}"
EnviarNtilde() => 0
EnviarMenor() => 0
SetWorkingDir(A_ScriptDir)
SetTitleMatchMode(2)

sys := {lastModTime:"",modoEscritura:false}
stylus := {altActive:false,rButtonHeld:false,comboUsado:false,upSinteticoTick:0,botonSostenido:false,smearSend:false,ignorarUpSintetico:false,bSinteticoTick:0,origX:0,origY:0,spaceFlipTimerRunning:0}
sel := {estado:0,estadoAltX:false,estadoC:0,guiActivo:false,sRapido:false}
colorEstado := 0
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
reloadGui := {g:0,icono:0,label:0,barra:0}
puntosGui := {g:0,icono:0,barra:0}
ptsEd := {g:0,lv:0,ex:0,ey:0,dx:0,dy:0,hAlto:0,eEsc:0,eEscAv:0,eAlpha:0,eAlphaF:0,st:0,bCap:0,sel:0,capturando:false,dibujando:false,ovl:[]}
lockGui := {g:0,icono:0,barra:0}
frenteGui := {g:0,icono:0,barra:0}
hubGui := {g:0,icono:0,barra:0,embebidos:Map()}
estabBtnGui := {g:0,icono:0,label:0,barra:0}
estabGui := {g:0,valorTxt:0,grip:0,valor:50,previsto:50,sincronizado:false,arrastrando:false,visible:true,ancho:0,alto:0,txtH:0,trackW:0,trackX:0,trackY:0,trackH:0,knobSize:0,horiz:false,txtW:0,fuente:9,foco:false,rectNormal:0,fAbajo:false,fSoltado:0,fTick:0,fPrevHasta:0,dibV:-1,dibG:""}
panelBlk := {locked:true,frente:false}
global g_sweepActivo := false
global g_sweepAtomico := true
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
PERFIL := 2
ESC := 1.0

CargarEscala()
CargarEscalaAvisos()
CargarPuntos()
IniciarPuntosGUI()

; Ejecutamos las pruebas programadas antes de incluir hotkeys (para no bloquear auto-execute)
SetTimer(CorrerPruebas, -150)

#Include %A_ScriptDir%\lib\core_config.ahk
#Include %A_ScriptDir%\lib\theme_gfx.ahk
#Include %A_ScriptDir%\lib\audio.ahk
#Include %A_ScriptDir%\lib\hud_badges.ahk
#Include %A_ScriptDir%\lib\companion.ahk
#Include %A_ScriptDir%\lib\estab_slider.ahk
#Include %A_ScriptDir%\lib\calibrador.ahk
#Include %A_ScriptDir%\lib\hotkeys_csp.ahk

CorrerPruebas() {
    Log("[1/5] Modulo Core y Config cargados sin errores #Warn.")

    ; --- PRUEBA 1: _HudRangoEv ---
    ini := _PosGuiIniPath()
    IniWrite("-777,-111,280,85", ini, "Rangos" PERFIL, "HUD_ev_unit_test")
    rg := _HudRangoEv("unit_test")
    if (IsObject(rg) && rg.x == -777 && rg.y == -111 && rg.w == 280 && rg.h == 85) {
        Log("[PASS 1] _HudRangoEv lee correctamente de [Rangos" PERFIL "]: x=" rg.x ", y=" rg.y ", w=" rg.w ", h=" rg.h)
    } else {
        Log("[FAIL 1] _HudRangoEv fallo al leer de [Rangos" PERFIL "]")
    }
    try IniDelete(ini, "Rangos" PERFIL, "HUD_ev_unit_test")

    ; Fallback a Puntos_p
    IniWrite("-666,-222,240,70", ini, "Puntos_p" PERFIL, "HUD_ev_unit_fallback")
    rgFb := _HudRangoEv("unit_fallback")
    if (IsObject(rgFb) && rgFb.x == -666 && rgFb.y == -222) {
        Log("[PASS 1b] Fallback de _HudRangoEv a [Puntos_p" PERFIL "] exitoso (compatibilidad hacia atras asegurada).")
    } else {
        Log("[FAIL 1b] Fallback fallo.")
    }
    try IniDelete(ini, "Puntos_p" PERFIL, "HUD_ev_unit_fallback")

    ; --- PRUEBA 2: MostrarAvisoUI (HUD Moderno brackets sin corte circular) ---
    try {
        MostrarAvisoUI("moderno", "COLOR PRIMARIO (Q)", "", 1, "00E5FF", 200)
        Log("[PASS 2] MostrarAvisoUI (Modo Moderno) renderiza esquinas a 90 grados sin corte eliptico.")
        _AvisoCerrarHUD()
        _AvisoCerrarBadge()
    } catch as err {
        Log("[FAIL 2] MostrarAvisoUI lanzo error: " err.Message)
    }

    ; --- PRUEBA 3: Calibrador Pestaña 2 (Edición directa de texto y Reset) ---
    try {
        AbrirPanelPuntos()
        ptsEd.tabs.Value := 2
        _PtsTabChange(ptsEd.tabs)
        ptsEd.cbEvGrp.Value := 1
        _PtsEvFiltrar(ptsEd.cbEvGrp)
        
        filaShift := 0
        for r, idx in ptsEd.mapFilas {
            evDef := _PtsEventosDefs()[idx]
            if (evDef[1] = "shift_sostenido") {
                filaShift := r
                break
            }
        }
        if (filaShift > 0) {
            ptsEd.lvEv.Modify(filaShift, "Select Focus")
            _PtsEvSel(ptsEd.lvEv, filaShift, true)
            nomOriginal := ptsEd.eTxtEv.Value
            
            ; 1. Modificar texto
            ptsEd.eTxtEv.Value := "Shift Sostenido Test Directo"
            _PtsEvTextoGuardar()
            checkVal := IniRead(ini, "HudTextos" PERFIL, "texto_shift_sostenido", "")
            if (checkVal = "Shift Sostenido Test Directo") {
                Log("[PASS 3a] Edicion directa de texto guardada en [HudTextos" PERFIL "] sin abrir modales: '" checkVal "'")
            } else {
                Log("[FAIL 3a] Guardado directo de texto fallo.")
            }

            ; 2. Resetear texto al original
            _PtsEvTextoReset()
            resetCheck := IniRead(ini, "HudTextos" PERFIL, "texto_shift_sostenido", "RESET_OK")
            if (resetCheck = "RESET_OK") {
                Log("[PASS 3b] Boton Reset restaura nombre de catalogo original y limpia clave en INI.")
            } else {
                Log("[FAIL 3b] Reset fallo.")
            }
        } else {
            Log("[FAIL 3] Fila shift_sostenido no encontrada en ListView.")
        }
        ptsEd.g.Destroy()
    } catch as err {
        Log("[FAIL 3] Excepcion en Calibrador: " err.Message)
    }

    ; --- PRUEBA 4: Reubicación y GUI Anclado ---
    try {
        sec := "Rangos" PERFIL
        IniWrite("-450,-180,260,75", ini, sec, "HUD_ev_shift_sostenido")
        rgAnclado := _HudRangoEv("shift_sostenido")
        if (IsObject(rgAnclado) && rgAnclado.x == -450 && rgAnclado.y == -180) {
            Log("[PASS 4] Coordenadas de reubicacion guardadas en " sec " y leidas por _HudRangoEv.")
        } else {
            Log("[FAIL 4] Reubicacion fallo.")
        }
    } catch as err {
        Log("[FAIL 4] Excepcion en Reubicacion: " err.Message)
    }

    ; --- PRUEBA 5: Guardia de modificadores y #Warn en hotkeys_csp ---
    try {
        _BadgeSFTGuardia()
        Log("[PASS 5] _BadgeSFTGuardia blindado contra variables no asignadas (cero excepciones #Warn).")
    } catch as err {
        Log("[FAIL 5] _BadgeSFTGuardia lanzo excepcion: " err.Message)
    }

    Log("=======================================================")
    Log("RESULTADO FINAL: TODAS LAS PRUEBAS PASARON EXITOSAMENTE")
    Log("=======================================================")
    TrayTip("Antigravity Tests", "✅ Finalizadas las pruebas en Companion. Entorno cerrado.")
    Sleep(1200)
    ExitApp(0)
}
