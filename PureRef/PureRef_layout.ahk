; ┌─────────────────────────────────────────────────────────────┐
; │  🖼️ PUREREF LAYOUT — abre archivos .pur en su sitio y tamaño   │
; │                                                             │
; │  · CADA .pur TIENE SU PROPIO INI en la carpeta               │
; │    PureRef_layouts\ (junto al script): Eris.ini, etc.        │
; │  · GUARDADO AUTOMÁTICO: mueve o redimensiona un panel y, al  │
; │    quedarse quieto ~1 s, su posición se guarda sola en su    │
; │    ini (normal / enfoque / monitor grande según el caso).    │
; │    Un .pur nuevo (sin perfil) se registra solo.              │
; │  · Al abrirse una ventana de PureRef cuyo título contiene el │
; │    nombre del .pur, se coloca sola (también si la abres tú). │
; │                                                             │
; │  F             escala de grises a lo SELECCIONADO.           │
; │  Espacio + F   Ctrl+A (seleccionar todo) + "Toggle grayscale"   │
; │                → alterna el gris en TODO el archivo.         │
; │                (Espacio solo sigue siendo el pan de siempre) │
; │                                                             │
; │  Ctrl+Shift+Alt+G  guardar ahora (manual, ya no es necesario)│
; │  Ctrl+Shift+Alt+O  panel: abrir, modo, config global, ajustes     │
; │  Ctrl+Shift+Alt+R  recolocar las ventanas ya abiertas        │
; │  Alt+Espacio       alterna el panel (bajo el cursor o activo) │
; │              entre la TABLETA y el OTRO monitor, cada uno con │
; │              SU posición y tamaño guardados (sin ampliar), y │
; │              SIN escalar ni mandar atajos de vista: el encuadre   │
; │              (Alt+B, Alt+Shift+B…) lo manejas tú con tus atajos.  │
; │  ZoomHold= (botón del lápiz/keydial en [Config]): mientras lo │
; │        sostienes sobre un panel, mantiene la Z abajo → zoom  │
; │        nativo de PureRef. Vacío = desactivado.               │
; │                                                             │
; │  MODO ENFOQUE: cada panel puede tener 2 posiciones (normal y  │
; │  enfoque). El script de CSP avisa al alternar enfoque y los   │
; │  paneles se mueven solos.                                    │
; │                                                             │
; │  Ajustes opcionales en [Config] del .ini:                    │
; │    Proceso=PureRef.exe        (nombre del proceso)           │
; │    Exe=C:\ruta\PureRef.exe    (solo si el .pur no abre solo) │
; │    TeclaCapturar= / TeclaMenu= / TeclaRecolocar= / TeclaMonitor=  │
; │    MonitorTableta=N  MonitorExpandido=N  (salto de monitor)        │
; │    AutoGuardar=1              (0 = desactiva el guardado auto)│
; │    Debug=1                    registro en PureRef_layout_debug.log│
; │        (qué manda el script y qué atajos llegan de fuera).   │
; │    TeclaGris=f                (vacío = desactiva F / Espacio+F)│
; │    EnvioGrisSeleccion=^+!f    atajo que PureRef tiene en      │
; │        "Toggle grayscale" (asígnalo UNA vez en PureRef:      │
; │        Settings > Shortcuts). Es el de la SELECCIÓN.         │
; │    EnvioGrisTodo=^a|!g        secuencia de Espacio+F, separada │
; │        con |  (1.º seleccionar todo, 2.º "Toggle grayscale",  │
; │        Alt+G por defecto; ajústalo si tu atajo es otro).     │
; └─────────────────────────────────────────────────────────────┘
; v2: cada panel es independiente (estado por ventana); las minimizadas no se tocan. Menú: Avanzado ▸ agrupa lo poco usado.
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; Píxeles reales (sin escalado de Windows), igual que el script de CSP
DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
SetWinDelay(-1)
SetTitleMatchMode(2)
CoordMode("ToolTip", "Screen")
try TraySetIcon("shell32.dll", 307)

INI := A_ScriptDir "\PureRef_layout.ini"
GLOBALINI := A_ScriptDir "\PureRef_layout_global.ini"   ; config GLOBAL (aparte de los perfiles individuales)
LAYDIR := A_ScriptDir "\PureRef_layouts"     ; un .ini por cada .pur
if !FileExist(INI)
    FileAppend("[Config]`r`nProceso=PureRef.exe`r`n", INI, "UTF-16")   ; UTF-16 para rutas con tildes/ñ
if !DirExist(LAYDIR)
    DirCreate(LAYDIR)

; Auto-elevación: igual que el script de CSP para recibir mensajes y mover ventanas sin bloqueo de permisos (UIPI).
if !A_IsAdmin {
    try {
        Run('*RunAs "' A_ScriptFullPath '"')
    }
    ExitApp()
}

PROC      := IniRead(INI, "Config", "Proceso", "PureRef.exe")
EXE       := IniRead(INI, "Config", "Exe", "")
DEBUG     := (IniRead(INI, "Config", "Debug", "0") = "1")   ; registro en PureRef_layout_debug.log
modo      := Integer(IniRead(INI, "Estado", "Modo", "0"))   ; 0 = normal, 1 = enfoque (lo avisa el script de CSP)
entradas  := []          ; perfiles cargados (uno por .ini de PureRef_layouts)
colocadas := Map()       ; hwnd → true (ya colocadas, para no pelear con el usuario)
zoomSostenido := false  ; true mientras ZoomHold mantiene la Z abajo
panSostenido := false   ; true mientras Espacio mantiene el clic central (pan)
spaceCombo := false     ; true si con Espacio sostenido se pulsó F (no volver a iniciar el pan)
spaceAbajo := false     ; Espacio sostenido (teclado o keydial). NO se usa GetKeyState("Space","P"): el driver XP-Pen
                        ; inyecta la tecla y AHK la ve como "no física", lo que soltaba el pan a los 150 ms.
seguim    := Map()       ; hwnd → {x, y, w, h, t} para el guardado automático
ignorar   := Map()       ; hwnd → tick hasta el que NO se guarda (movimientos hechos por el script)
ultimoMover := Map()     ; hwnd → tick de la última ejecución de Alt+Espacio (anti auto-repeat, por ventana)
panelGui := 0, panelT := 0, hoverCtrl := 0, panelVisto := false   ; panel moderno (ventana oscura)
modoBtn := 0             ; botón "Modo:" del panel (para refrescar su texto sin cerrarlo)
botonesPanel := Map()    ; hwnd del botón → colores (reposo / hover)
ultimoPanel := 0         ; último panel de PureRef que estuvo activo (el menú de la bandeja le quita el foco al abrirse)
panHwnd := 0             ; ventana que tiene el pan en curso (solo ESA se deja quieta)
zoomHwnd := 0            ; ventana que tiene el zoom sostenido en curso

MigrarPerfilesAntiguos()   ; pasa las secciones del .ini único a un .ini por archivo (una sola vez)
CargarEntradas()
ConstruirMenu()
OnMessage(0x200, PanelRaton)     ; hover de los botones
OnMessage(0x404, TrayClic)       ; un solo clic en el icono de la bandeja abre el panel
OnMessage(0x201, PanelArrastrar) ; arrastrar el panel desde cualquier zona libre
OnMessage(0x232, PanelFinMover)  ; al soltar, recuerda dónde lo dejaste
SetTimer(AutoColocar, 400)
if (IniRead(INI, "Config", "AutoGuardar", "1") != "0")
    SetTimer(AutoGuardar, 500)
SetTimer(LimpiarSpaceCombo, 100)
OnMessage(0x5501, RecibirModo)   ; el script de CSP manda 0/1 al alternar modo enfoque

; ┌──────────────────────────────────────────────────────────────┐
; │  HOTKEYS — se leen del .ini [Config] para cambiarlos sin      │
; │  tocar el código (sintaxis AHK: ^=Ctrl  !=Alt  +=Shift).      │
; │  Por defecto Ctrl+Shift+Alt + G / O / R (combinación rara).   │
; └──────────────────────────────────────────────────────────────┘
tCap := RegistrarAtajo("TeclaCapturar",  "^+!g", (*) => CapturarVentanaActiva())
tMen := RegistrarAtajo("TeclaMenu",      "^+!o", (*) => MostrarPanel())
tRec := RegistrarAtajo("TeclaRecolocar", "^+!r", (*) => RecolocarTodas())
tMon := RegistrarAtajo("TeclaMonitor",   "q", (*) => MoverAlOtroMonitor(), (*) => (PureRefObjetivo() != 0))
tGris := RegistrarAtajo("TeclaGris",     "f", (*) => GrisPulsado()
                      , (*) => (PureRefObjetivo() != 0 && !GetKeyState("Alt", "P") && !GetKeyState("Ctrl", "P") && !GetKeyState("Shift", "P")))
tZoom := RegistrarZoomHold()
SetTimer(SoltarEstadosSiSalePanel, 150)
OnExit((*) => (SoltarZoom(), SoltarPan()))

; Confirmación visible de que el script cargó (si NO ves esto, el script no está corriendo)
msgInicio := "🖼 PureRef layout ACTIVO (" entradas.Length " perfiles, modo " (modo ? "ENFOQUE" : "normal") ")`n"
           . "Guardado automático: " (IniRead(INI, "Config", "AutoGuardar", "1") != "0" ? "SÍ" : "no") "   Gris: " tGris "`n"
           . "Guardar: " tCap "   Menú: " tMen "   Recolocar: " tRec "   Otro monitor: " tMon "   Zoom hold: " tZoom "`n"
           . "Proceso vigilado: " PROC (A_IsAdmin ? "   [admin]" : "")
Aviso(msgInicio, 6000)
try TrayTip(msgInicio, "PureRef layout")

; cond (opcional): función que decide si el atajo está activo. Con cond, el atajo
; solo existe mientras cond() sea verdadero; si no, la tecla pasa tal cual a Windows.
RegistrarAtajo(clave, defecto, accion, cond := "") {
    global INI
    tecla := Trim(IniRead(INI, "Config", clave, defecto))
    if (tecla = "")
        return "(sin asignar)"
    try {
        if (SubStr(tecla, 1, 1) != "$")
            tecla := "$" tecla          ; $ = forzar hook de teclado
        if (cond != "")
            HotIf(cond)
        Hotkey(tecla, accion, "On")
        HotIf()
    } catch as err {
        try HotIf()
        MsgBox("No pude registrar el atajo " clave "=" tecla "`n`n" err.Message
             . "`nCorrígelo en [Config] de PureRef_layout.ini.", "PureRef layout", 48)
        return "(inválida)"
    }
    return tecla
}

; ┌──────────────────────────────────────────────────────────────┐
; │  FUNCIONES                                                   │
; └──────────────────────────────────────────────────────────────┘
Log(texto) {
    global DEBUG
    if !DEBUG
        return
    try FileAppend(FormatTime(, "HH:mm:ss") "." Format("{:03}", A_MSec) "  " texto "`n", A_ScriptDir "\PureRef_layout_debug.log", "UTF-8")
}

Aviso(texto, ms := 1500) {
    ToolTip(texto)   ; junto al cursor, para verlo en la tableta o en el monitor principal
    SetTimer(() => ToolTip(), -ms)
}

; ── Perfiles: un .ini por archivo .pur ────────────────────────────
; PureRef_layouts\<nombre del .pur>.ini  con sección [Layout]:
;   Archivo=ruta (opcional)  X Y W H (normal)  XE YE WE HE (enfoque)  XM YM WM HM (monitor grande)

; Lee un rectángulo del ini de un perfil. sfx: "" normal, "E" enfoque, "M" monitor grande.
; Devuelve 0 si falta algún valor.
LeerRect(f, sfx) {
    v := []
    for k in ["X", "Y", "W", "H"] {
        n := IniRead(f, "Layout", k sfx, "")
        if !IsInteger(n)
            return 0
        v.Push(Integer(n))
    }
    return {x: v[1], y: v[2], w: v[3], h: v[4]}
}

CargarEntradas() {
    global entradas, LAYDIR
    entradas := []
    Loop Files, LAYDIR "\*.ini" {
        f := A_LoopFileFullPath
        SplitPath(f, , , , &base)
        n := LeerRect(f, "")
        if !n
            continue
        ee := LeerRect(f, "E")
        mm := LeerRect(f, "M")
        tieneE := IsObject(ee), tieneM := IsObject(mm)
        entradas.Push({ sec: base, ini: f, nombre: base
                      , archivo: IniRead(f, "Layout", "Archivo", "")
                      , x: n.x, y: n.y, w: n.w, h: n.h
                      , tieneE: tieneE
                      , xe: tieneE ? ee.x : 0, ye: tieneE ? ee.y : 0
                      , we: tieneE ? ee.w : 0, he: tieneE ? ee.h : 0
                      , tieneM: tieneM
                      , xm: tieneM ? mm.x : 0, ym: tieneM ? mm.y : 0
                      , wm: tieneM ? mm.w : 0, hm: tieneM ? mm.h : 0 })
    }
}

; Escribe una posición en el ini del perfil (lo crea si no existe).
; slot: "N" normal, "E" enfoque, "M" monitor grande.
GuardarPerfil(nombre, archivo, slot, x, y, w, h) {
    global LAYDIR
    f := LAYDIR "\" nombre ".ini"
    if !FileExist(f)
        FileAppend("[Layout]`r`n", f, "UTF-16")   ; UTF-16 para rutas con tildes/ñ
    if (archivo != "")
        IniWrite(archivo, f, "Layout", "Archivo")
    sfx := (slot = "N") ? "" : slot
    IniWrite(x, f, "Layout", "X" sfx)
    IniWrite(y, f, "Layout", "Y" sfx)
    IniWrite(w, f, "Layout", "W" sfx)
    IniWrite(h, f, "Layout", "H" sfx)
}

; Migración única: las secciones del PureRef_layout.ini antiguo pasan a su propio .ini
; (se deja copia de seguridad PureRef_layout.ini.bak).
MigrarPerfilesAntiguos() {
    global INI, LAYDIR
    migradas := []
    for sec in StrSplit(IniRead(INI), "`n", "`r") {
        if (sec = "" || sec = "Config" || sec = "Estado")
            continue
        if (IniRead(INI, sec, "X", "") = "" && IniRead(INI, sec, "Archivo", "") = "")
            continue
        destino := LAYDIR "\" sec ".ini"
        if !FileExist(destino) {
            try {
                FileAppend("[Layout]`r`n", destino, "UTF-16")
                for k in ["Archivo", "X", "Y", "W", "H", "XE", "YE", "WE", "HE", "XM", "YM", "WM", "HM"] {
                    v := IniRead(INI, sec, k, "")
                    if (v != "")
                        IniWrite(v, destino, "Layout", k)
                }
            }
        }
        if FileExist(destino)
            migradas.Push(sec)
    }
    if (migradas.Length) {
        if !FileExist(INI ".bak")
            try FileCopy(INI, INI ".bak")
        for sec in migradas
            try IniDelete(INI, sec)
    }
}

ConstruirMenu() {
    static listo := false
    if listo
        return                      ; el menú de la bandeja es fijo; todo lo demás vive en el panel
    listo := true
    A_TrayMenu.Delete()
    A_TrayMenu.Add("Abrir panel", (*) => MostrarPanel())
    A_TrayMenu.Add()
    A_TrayMenu.Add("Recargar script", (*) => Reload())
    A_TrayMenu.Add("Salir", (*) => ExitApp())
}

_MenuAbrir(e, *) => AbrirEntrada(e)

; ── Panel moderno ────────────────────────────────────────────────
; Ventana oscura y compacta, con esquinas redondeadas (Windows 11). Se abre con un clic en el icono de la
; bandeja o con TeclaMenu (Ctrl+Shift+Alt+O). Queda FIJO: no toma el foco, no se cierra al cambiar de
; pantalla ni al pulsar botones. Se mueve arrastrándolo (recuerda su posición) y se cierra con ×
; (o volviendo a pulsar el icono / la tecla).
MostrarPanel(*) {
    global panelGui, panelT, panelVisto, botonesPanel, hoverCtrl, entradas, modo, modoBtn, INI
    if panelGui {                   ; ya está abierto → el mismo gesto lo cierra
        CerrarPanel()
        return
    }
    CargarEntradas()
    botonesPanel := Map()
    hoverCtrl := 0
    g := Gui("-Caption +AlwaysOnTop +ToolWindow +Border +E0x08000000", "PureRef layout")   ; E0x08000000 = no activa: no le quita el foco a PureRef/CSP
    g.BackColor := "17171C"
    g.MarginX := 14
    g.MarginY := 12

    ; cabecera: título + iconos (recargar, cerrar)
    g.SetFont("s11 Bold cE8E8EE", "Segoe UI")
    g.AddText("x14 y12 w100 BackgroundTrans", "PureRef")   ; sin clic propio: arrastrar aquí mueve el panel
    g.SetFont("s12 Norm cE8E8EE", "Segoe UI Symbol")
    PanelBoton(g, "↻", 134, 10, 34, 28, () => Reload())
    g.SetFont("s12 Norm cE8E8EE", "Segoe UI")
    PanelBoton(g, "×", 172, 10, 34, 28, () => CerrarPanel())
    g.SetFont("s9 Norm cE8E8EE", "Segoe UI")
    modoBtn := PanelBoton(g, "Modo: " (modo ? "ENFOQUE" : "Normal"), 14, 46, 192, 30
        , () => CambiarModo(modo ? 0 : 1), modo ? true : false)

    g.SetFont("s8 c8B8D9B", "Segoe UI")
    g.AddText("x14 y86 w192 BackgroundTrans", "ARCHIVOS  (doble clic abre)")
    g.SetFont("s9 cE8E8EE", "Segoe UI")
    lv := g.AddListView("x14 y104 w192 h104 -Hdr -Multi Background22232B cE8E8EE", ["Archivo"])
    for e in entradas
        if (e.archivo != "")
            lv.Add(, e.nombre)
    lv.ModifyCol(1, 168)
    try DllCall("uxtheme\SetWindowTheme", "ptr", lv.Hwnd, "str", "DarkMode_Explorer", "ptr", 0)
    lv.OnEvent("DoubleClick", PanelAbrirFila)

    g.SetFont("s8 c8B8D9B", "Segoe UI")
    g.AddText("x14 y218 w192 BackgroundTrans", "CONFIG GLOBAL")
    g.AddText("x14 y234 w192 BackgroundTrans", "Guardar desde el panel")
    g.SetFont("s9 cE8E8EE", "Segoe UI")
    PanelBoton(g, "Enfoque",  14, 250, 60, 26, () => GuardarGlobalDesdePanel("E"))
    PanelBoton(g, "Manual",   80, 250, 60, 26, () => GuardarGlobalDesdePanel("N"))
    PanelBoton(g, "Pantalla", 146, 250, 60, 26, () => GuardarGlobalDesdePanel("M"))
    g.SetFont("s8 c8B8D9B", "Segoe UI")
    g.AddText("x14 y282 w192 BackgroundTrans", "Aplicar al panel")
    g.SetFont("s9 cE8E8EE", "Segoe UI")
    PanelBoton(g, "Todo",     14, 298, 192, 26, () => AplicarGlobalAPanel("T"), true)
    PanelBoton(g, "Enfoque",  14, 328, 60, 26, () => AplicarGlobalAPanel("E"))
    PanelBoton(g, "Manual",   80, 328, 60, 26, () => AplicarGlobalAPanel("N"))
    PanelBoton(g, "Pantalla", 146, 328, 60, 26, () => AplicarGlobalAPanel("M"))

    g.SetFont("s8 c8B8D9B", "Segoe UI")
    g.AddText("x14 y364 w192 BackgroundTrans", "AJUSTES")
    g.SetFont("s9 cE8E8EE", "Segoe UI")
    PanelBoton(g, "Recolocar",    14, 380, 93, 26, () => RecolocarTodas())
    PanelBoton(g, "Diagnóstico", 113, 380, 93, 26, () => Diagnostico())
    PanelBoton(g, "Carpeta",      14, 410, 60, 26, () => Run('explorer.exe "' LAYDIR '"'))
    PanelBoton(g, ".ini",         80, 410, 60, 26, () => Run('notepad.exe "' INI '"'))
    PanelBoton(g, "Salir",       146, 410, 60, 26, () => ExitApp())

    ; esquinas redondeadas, borde fino y barra oscura (Windows 11; en Windows 10 se ignora)
    try {
        v := Buffer(4, 0)
        NumPut("int", 1, v), DllCall("dwmapi\DwmSetWindowAttribute", "ptr", g.Hwnd, "int", 20, "ptr", v, "int", 4)
        NumPut("int", 2, v), DllCall("dwmapi\DwmSetWindowAttribute", "ptr", g.Hwnd, "int", 33, "ptr", v, "int", 4)
        NumPut("uint", 0x3A2F2E, v), DllCall("dwmapi\DwmSetWindowAttribute", "ptr", g.Hwnd, "int", 34, "ptr", v, "int", 4)
    }

    ; posición: la última donde lo dejaste (si sigue dentro de algún monitor); si no, junto al cursor
    g.Show("Hide")
    g.GetPos(, , &pw, &ph)
    px := "", py := ""
    gx := IniRead(INI, "Panel", "X", ""), gy := IniRead(INI, "Panel", "Y", "")
    if (IsInteger(gx) && IsInteger(gy) && MonitorDePunto(Integer(gx) + 30, Integer(gy) + 15)) {
        px := Integer(gx), py := Integer(gy)
    } else {
        MouseGetPos(&mx, &my)
        mon := MonitorDePunto(mx, my)
        if !mon
            mon := MonitorGetPrimary()
        MonitorGetWorkArea(mon, &l, &tp, &r, &b)
        px := Max(l, Min(mx - 24, r - pw))
        py := (my + 14 + ph <= b) ? my + 14 : Max(tp, my - ph - 12)
    }
    panelGui := g
    panelT := A_TickCount
    panelVisto := false
    g.Show("NoActivate x" px " y" py)
}

; Arrastrar el panel desde cualquier zona que no sea un botón/lista (los textos son transparentes al clic).
PanelArrastrar(wParam, lParam, msg, hwnd) {
    global panelGui
    if (panelGui && hwnd = panelGui.Hwnd) {
        DllCall("ReleaseCapture")
        PostMessage(0xA1, 2, 0, , "ahk_id " hwnd)      ; WM_NCLBUTTONDOWN + HTCAPTION
    }
}

; Al terminar de moverlo, guarda la posición en el .ini para la próxima vez.
PanelFinMover(wParam, lParam, msg, hwnd) {
    global panelGui, INI
    if (panelGui && hwnd = panelGui.Hwnd) {
        try {
            WinGetPos(&x, &y, , , "ahk_id " hwnd)
            IniWrite(x, INI, "Panel", "X")
            IniWrite(y, INI, "Panel", "Y")
        }
    }
}

; Refresca el botón "Modo:" cuando cambia el modo (desde el panel o desde CSP) sin cerrar el panel.
ActualizarPanelModo() {
    global panelGui, modoBtn, modo, botonesPanel
    if (!panelGui || !modoBtn)
        return
    try {
        bg := modo ? "6C5CE7" : "2A2B35"
        hov := modo ? "8173F0" : "3B3D50"
        modoBtn.Text := "Modo: " (modo ? "ENFOQUE" : "Normal")
        botonesPanel[modoBtn.Hwnd] := {bg: bg, hov: hov}
        PanelPintar(modoBtn.Hwnd, bg)
    }
}

CerrarPanel(*) {
    global panelGui, hoverCtrl, modoBtn
    hoverCtrl := 0
    modoBtn := 0
    if panelGui {
        g := panelGui
        panelGui := 0
        try g.Destroy()
    }
}

; Botón plano (Text con fondo). inmediato: accion() se llama al hacer clic, ANTES de cerrar el panel,
; y devuelve la acción real (o 0 para no hacer nada y dejar el panel abierto).
PanelBoton(g, texto, x, y, w, h, accion, acento := false, inmediato := false) {
    global botonesPanel
    bg := acento ? "6C5CE7" : "2A2B35"
    hov := acento ? "8173F0" : "3B3D50"
    c := g.AddText("x" x " y" y " w" w " h" h " +0x200 +0x100 Center Background" bg " cFFFFFF", texto)
    botonesPanel[c.Hwnd] := {bg: bg, hov: hov}
    c.OnEvent("Click", PanelClic.Bind(accion, inmediato))
    return c
}

PanelClic(accion, inmediato, *) {
    if inmediato {
        accion := accion()
        if !accion
            return
    }
    SetTimer(accion, -1)            ; el panel NO se cierra (salvo el botón ×); el foco sigue en PureRef/CSP
}

PanelAccionSeleccion(lv) {
    fila := lv.GetNext()
    if !fila
        return 0
    nombre := lv.GetText(fila)
    return () => AbrirPorNombre(nombre)
}

PanelAbrirFila(lv, fila) {
    if !fila
        return
    nombre := lv.GetText(fila)
    SetTimer(() => AbrirPorNombre(nombre), -1)
}

AbrirPorNombre(nombre) {
    global entradas
    for e in entradas
        if (e.nombre = nombre) {
            AbrirEntrada(e)
            return
        }
}

; Hover: el botón bajo el cursor se aclara.
PanelRaton(wParam, lParam, msg, hwnd) {
    global panelGui, botonesPanel, hoverCtrl
    if !panelGui
        return
    ctl := 0
    MouseGetPos(, , , &ctl, 2)
    if (ctl = hoverCtrl)
        return
    if (hoverCtrl && botonesPanel.Has(hoverCtrl))
        PanelPintar(hoverCtrl, botonesPanel[hoverCtrl].bg)
    hoverCtrl := ctl
    if (ctl && botonesPanel.Has(ctl))
        PanelPintar(ctl, botonesPanel[ctl].hov)
}

PanelPintar(hwndCtrl, color) {
    try {
        c := GuiCtrlFromHwnd(hwndCtrl)
        c.Opt("Background" color)
        c.Redraw()
    }
}

; Clic izquierdo (al soltar) en el icono de la bandeja → abre el panel de inmediato.
TrayClic(wParam, lParam, msg, hwnd) {
    if (lParam = 0x202) {           ; WM_LBUTTONUP
        SetTimer(MostrarPanel, -1)
        return 0
    }
}

; Muestra qué ve el script en cada ventana de PureRef (útil si algo no se guarda).
Diagnostico() {
    global PROC
    txt := ""
    for hwnd in WinGetList("ahk_exe " PROC) {
        titulo := ""
        try titulo := WinGetTitle("ahk_id " hwnd)
        if (titulo = "")
            continue
        nuevo := ""
        e := IdentificarPerfil(titulo, &nuevo)
        txt .= "• " titulo "`n     panel principal: " (EsPanelPrincipal(hwnd) ? "sí" : "no (se ignora)")
             . "   perfil: " (IsObject(e) ? e.nombre : (nuevo != "" ? "(nuevo) " nuevo : "—")) "`n"
    }
    MsgBox(txt != "" ? txt : "No hay ventanas de PureRef con título.", "PureRef layout — diagnóstico")
}

; Perfil cuyo nombre de archivo aparece en el título como palabra completa
; (gana el nombre más largo: "ref" no se come a "ref_anatomia").
EntradaDeTitulo(titulo) {
    global entradas
    mejor := 0
    for e in entradas {
        if (e.nombre = "" || !InStr(titulo, e.nombre))
            continue
        if !RegExMatch(titulo, "i)(?<!\w)\Q" e.nombre "\E(?!\w)")
            continue
        if (!mejor || StrLen(e.nombre) > StrLen(mejor.nombre))
            mejor := e
    }
    return mejor
}

; ¿El título tiene el formato "<archivo> - PureRef ..."?
TituloConFormato(t) {
    return RegExMatch(t, "i)\s[-–—]\s+PureRef") || RegExMatch(t, "i)^PureRef\s+[-–—]\s")
}

; Nombre del archivo según el título de la ventana ("" si no se puede deducir).
NombreDeTitulo(t) {
    t := RegExReplace(t, "i)\s+[-–—]\s+PureRef.*$", "")
    t := RegExReplace(t, "i)^PureRef\s+[-–—]\s+", "")
    t := Trim(t, " `t*")
    t := RegExReplace(t, "i)\.pur$", "")
    t := Trim(t, " `t*")
    t := RegExReplace(t, '[\\/:*?"<>|]', "_")
    if (t = "" || RegExMatch(t, "i)^(PureRef|untitled|settings|about|preferences|sin\s+t[ií]tulo)"))
        return ""
    return t
}

; Identifica el perfil de una ventana por su título. Devuelve el perfil existente,
; o 0 y en nombreNuevo el nombre deducido para crear uno.
IdentificarPerfil(titulo, &nombreNuevo) {
    global entradas
    nombreNuevo := ""
    parsed := NombreDeTitulo(titulo)
    if (parsed != "" && TituloConFormato(titulo)) {
        ; formato reconocido: coincidencia exacta (así "Eris copia" no pisa el perfil "Eris")
        for e in entradas
            if (StrLower(e.nombre) = StrLower(parsed))
                return e
        nombreNuevo := parsed
        return 0
    }
    e := EntradaDeTitulo(titulo)
    if e
        return e
    nombreNuevo := parsed
    return 0
}

; Ruta del .pur con el que se lanzó la ventana (línea de comandos del proceso),
; solo si su nombre aparece en el título. "" si no se conoce.
ArchivoDeProceso(hwnd, titulo) {
    try {
        pid := WinGetPID("ahk_id " hwnd)
        for p in ComObjGet("winmgmts:").ExecQuery("Select CommandLine from Win32_Process where ProcessId=" pid) {
            cl := p.CommandLine
            if (RegExMatch(cl, 'i)"([^"]+\.pur)"', &m) || RegExMatch(cl, 'i)([A-Za-z]:\\[^"]+?\.pur)', &m)) {
                SplitPath(m[1], , , , &base)
                if (FileExist(m[1]) && InStr(titulo, base))
                    return m[1]
            }
        }
    }
    return ""
}

; Panel real de PureRef (no diálogos de Ajustes, etc.: esos tienen ventana "dueña").
EsPanelPrincipal(hwnd) {
    try {
        if DllCall("GetWindow", "ptr", hwnd, "uint", 4, "ptr")   ; GW_OWNER
            return false
        return true
    }
    return false
}

; ¿La ventana está minimizada? (los comandos globales NO deben tocarla)
Minimizada(hwnd) {
    try return (WinGetMinMax("ahk_id " hwnd) = -1)
    return false
}

; ¿El panel está en un monitor distinto al de su "casa" (p. ej. ampliado en la pantalla grande)?
EnOtroMonitor(hwnd) {
    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        m := MonitorDePunto(x + w // 2, y + h // 2)
        return (m != 0 && m != MonitorCasa(hwnd))
    }
    return false
}

; Rectángulo del perfil según el modo. En enfoque, si el panel no tiene posición
; de enfoque guardada, usa la normal (no se mueve).
RectDe(e) {
    global modo
    if (modo = 1 && e.tieneE)
        return { x: e.xe, y: e.ye, w: e.we, h: e.he }
    return { x: e.x, y: e.y, w: e.w, h: e.h }
}

; Marca que el script está moviendo la ventana: el guardado automático no lo toma como cambio del usuario.
IgnorarMovimiento(hwnd, ms := 1800) {
    global ignorar
    ignorar[hwnd] := A_TickCount + ms
}

Colocar(hwnd, e) {
    r := RectDe(e)
    try {
        mm := WinGetMinMax("ahk_id " hwnd)
        if (mm = -1)
            return false            ; minimizada: no se toca
        IgnorarMovimiento(hwnd)
        if (mm = 1)
            WinRestore("ahk_id " hwnd)
        WinMove(r.x, r.y, r.w, r.h, "ahk_id " hwnd)
        return true
    }
    return false
}

; ── Guardado automático ───────────────────────────────────────────
; Cada 500 ms mira todas las ventanas de PureRef. Si una cambió de posición o tamaño
; y lleva ~1,2 s quieta (y no estás arrastrando), guarda en el ini de SU archivo:
;   · panel en la tableta → posición NORMAL (o ENFOQUE si estás en modo enfoque)
;   · panel en otro monitor → posición MONITOR GRANDE
;   · .pur sin perfil → crea PureRef_layouts\<nombre>.ini con la posición actual
AutoGuardar() {
    global PROC, seguim, ignorar, colocadas, panHwnd, zoomHwnd
    vivas := Map()
    ahora := A_TickCount
    for hwnd in WinGetList("ahk_exe " PROC) {
        if !EsPanelPrincipal(hwnd)
            continue
        vivas[hwnd] := true
        if (hwnd = panHwnd || hwnd = zoomHwnd)
            continue                ; solo esa ventana se deja quieta mientras haces pan/zoom
        titulo := ""
        x := 0, y := 0, w := 0, h := 0
        try {
            if (WinGetMinMax("ahk_id " hwnd) != 0)
                continue
            titulo := WinGetTitle("ahk_id " hwnd)
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        } catch {
            continue
        }
        if (titulo = "" || w < 80 || h < 80)
            continue
        if (ignorar.Has(hwnd) && ahora < ignorar[hwnd]) {
            seguim[hwnd] := {x: x, y: y, w: w, h: h, t: 0}
            continue
        }
        nuevoNombre := ""
        e := IdentificarPerfil(titulo, &nuevoNombre)
        if (IsObject(e) && !colocadas.Has(hwnd))
            continue                    ; AutoColocar todavía no la coloca
        if (!IsObject(e) && nuevoNombre = "")
            continue                    ; sin nombre (p. ej. escena sin guardar)
        if !seguim.Has(hwnd) {
            ; primera vez que la vemos: con perfil solo se anota; sin perfil se registrará al quedarse quieta
            seguim[hwnd] := {x: x, y: y, w: w, h: h, t: (IsObject(e) ? 0 : ahora)}
            continue
        }
        s := seguim[hwnd]
        if (s.x != x || s.y != y || s.w != w || s.h != h) {
            s.x := x, s.y := y, s.w := w, s.h := h, s.t := ahora
            continue
        }
        if (s.t = 0 || ahora - s.t < 1200 || GetKeyState("LButton", "P"))
            continue
        s.t := 0
        GuardarAuto(hwnd, e, nuevoNombre, titulo, x, y, w, h)
    }
    ; limpiar ventanas que ya no existen
    muertas := []
    for hwnd in seguim
        if !vivas.Has(hwnd)
            muertas.Push(hwnd)
    for hwnd in muertas
        seguim.Delete(hwnd)
    muertas := []
    for hwnd in ignorar
        if !vivas.Has(hwnd)
            muertas.Push(hwnd)
    for hwnd in muertas
        ignorar.Delete(hwnd)
}

GuardarAuto(hwnd, e, nuevoNombre, titulo, x, y, w, h) {
    global colocadas, modo
    if IsObject(e) {
        monAct := MonitorDePunto(x + w // 2, y + h // 2)
        casa := MonitorCasa(hwnd)
        if (monAct != 0 && monAct != casa)
            slot := "M"
        else
            slot := modo ? "E" : "N"
        ; si no cambió respecto a lo guardado en ese slot, no escribir
        if (slot = "N" && e.x = x && e.y = y && e.w = w && e.h = h)
            return
        if (slot = "E" && e.tieneE && e.xe = x && e.ye = y && e.we = w && e.he = h)
            return
        if (slot = "M" && e.tieneM && e.xm = x && e.ym = y && e.wm = w && e.hm = h)
            return
        GuardarPerfil(e.nombre, e.archivo, slot, x, y, w, h)
        CargarEntradas()
        ConstruirMenu()
        Aviso("📌 " e.nombre " (" (slot = "M" ? "monitor grande" : (slot = "E" ? "enfoque" : "normal")) "): " x ", " y "  " w "×" h, 1300)
    } else {
        archivo := ArchivoDeProceso(hwnd, titulo)
        ; solo se crean perfiles nuevos con un título reconocible "<archivo> - PureRef"
        ; o cuando la línea de comandos confirma el .pur (evita crear perfiles de ventanas raras)
        if (!TituloConFormato(titulo) && archivo = "")
            return
        GuardarPerfil(nuevoNombre, archivo, "N", x, y, w, h)
        if modo
            GuardarPerfil(nuevoNombre, archivo, "E", x, y, w, h)
        colocadas[hwnd] := true
        CargarEntradas()
        ConstruirMenu()
        SoundBeep(1000, 50)
        Aviso("📌 Perfil nuevo: " nuevoNombre "  " x ", " y "  " w "×" h, 1800)
    }
}

; ── Modo enfoque ──────────────────────────────────────────────────
; El script de CSP manda un mensaje (0x5501) con 0 = normal / 1 = enfoque.
RecibirModo(wParam, lParam, msg, hwnd) {
    CambiarModo(wParam ? 1 : 0)
    return 1
}

CambiarModo(m) {
    global modo, colocadas, PROC, INI
    modo := m
    Aviso("🖼 PureRef: modo " (modo ? "ENFOQUE" : "normal"), 1200)
    IniWrite(modo, INI, "Estado", "Modo")
    ConstruirMenu()
    ActualizarPanelModo()
    ; mover ahora todas las ventanas abiertas que tengan perfil
    for hwnd in WinGetList("ahk_exe " PROC) {
        if (!EsPanelPrincipal(hwnd) || Minimizada(hwnd))
            continue                        ; minimizadas: el cambio de modo no las toca
        titulo := ""
        try titulo := WinGetTitle("ahk_id " hwnd)
        e := EntradaDeTitulo(titulo)
        if (e) {
            colocadas[hwnd] := true
            if EnOtroMonitor(hwnd)
                continue                    ; en el monitor grande: ahí se queda
            Colocar(hwnd, e)
        }
    }
}

; Coloca cada ventana nueva de PureRef que tenga perfil. Si el título aún no
; coincide (PureRef a veces lo pone un instante después) no la marca y reintenta.
AutoColocar() {
    global colocadas, PROC, panHwnd, zoomHwnd, ultimoMover, ultimoPanel
    a := WinExist("A")
    if (a && PanelUsable(a) && EsPanelPrincipal(a))
        ultimoPanel := a
    vivas := Map()
    for hwnd in WinGetList("ahk_exe " PROC) {
        vivas[hwnd] := true
        if (colocadas.Has(hwnd) || hwnd = panHwnd || hwnd = zoomHwnd)
            continue
        if (!EsPanelPrincipal(hwnd) || Minimizada(hwnd))
            continue                ; minimizada: se coloca cuando la restaures
        titulo := ""
        try titulo := WinGetTitle("ahk_id " hwnd)
        if (titulo = "")
            continue
        e := EntradaDeTitulo(titulo)
        if !e
            continue
        colocadas[hwnd] := true
        Colocar(hwnd, e)
    }
    ; limpiar ventanas que ya no existen
    muertas := []
    for hwnd in colocadas
        if !vivas.Has(hwnd)
            muertas.Push(hwnd)
    for hwnd in muertas
        colocadas.Delete(hwnd)
    for mapa in [ultimoMover] {
        previas := []
        for hwnd in mapa
            if !vivas.Has(hwnd)
                previas.Push(hwnd)
        for hwnd in previas
            mapa.Delete(hwnd)
    }
}

AbrirEntrada(e) {
    global colocadas, PROC, EXE
    if (e.archivo = "")
        return
    if !FileExist(e.archivo) {
        MsgBox("No existe el archivo:`n" e.archivo, "PureRef layout", 48)
        return
    }
    ; Si ya estaba abierto, que el temporizador lo vuelva a colocar.
    for hwnd in WinGetList("ahk_exe " PROC) {
        titulo := ""
        try titulo := WinGetTitle("ahk_id " hwnd)
        m := EntradaDeTitulo(titulo)
        if (IsObject(m) && m.sec = e.sec && colocadas.Has(hwnd))
            colocadas.Delete(hwnd)
    }
    try {
        if (EXE != "")
            Run('"' EXE '" "' e.archivo '"')
        else
            Run('"' e.archivo '"')
    } catch as err {
        MsgBox("No pude abrir:`n" e.archivo "`n`n" err.Message
             . "`n`nSi el .pur no abre solo con doble clic, pon Exe=... en [Config] del .ini.", "PureRef layout", 48)
    }
}

AbrirTodos() {
    global entradas
    for e in entradas {
        if (e.archivo = "")
            continue
        AbrirEntrada(e)
        Sleep(250)
    }
}

; ── Zoom con un botón sostenido ───────────────────────────────────
; [Config] ZoomHold=<tecla AHK>  (ej. F13, XButton2, !b; vacío = desactivado).
; Mientras esa tecla/botón esté sostenida con el cursor sobre un panel de
; PureRef, se mantiene la Z abajo: PureRef hace zoom con Z + movimiento
; (necesita el atajo de zoom con Z; ver Ajustes > Atajos de PureRef).
RegistrarZoomHold() {
    global INI
    tecla := Trim(IniRead(INI, "Config", "ZoomHold", ""))
    if (tecla = "")
        return "(sin asignar)"
    try {
        if (SubStr(tecla, 1, 1) != "$")
            tecla := "$" tecla
        HotIf((*) => PureRefObjetivo() != 0)
        Hotkey(tecla, ZoomHoldBajar, "On")
        Hotkey(tecla " up", ZoomHoldSubir, "On")
        HotIf()
    } catch as err {
        try HotIf()
        MsgBox("No pude registrar ZoomHold=" tecla "`n`n" err.Message, "PureRef layout", 48)
        return "(inválida)"
    }
    return tecla
}

ZoomHoldBajar(nombre, *) {
    global zoomSostenido, zoomHwnd
    if zoomSostenido                 ; ignora el auto-repeat
        return
    zoomSostenido := true
    zoomHwnd := PureRefObjetivo()
    ; si el atajo lleva modificadores (! ^ +), soltarlos para que PureRef vea Z sola
    if InStr(nombre, "!")
        Send("{Alt up}")
    if InStr(nombre, "^")
        Send("{Ctrl up}")
    if InStr(nombre, "+")
        Send("{Shift up}")
    Send("{z down}")
}

ZoomHoldSubir(*) {
    SoltarZoom()
}

SoltarZoom() {
    global zoomSostenido, zoomHwnd
    if !zoomSostenido
        return
    zoomSostenido := false
    zoomHwnd := 0
    Send("{z up}")
}

SoltarPan() {
    global panSostenido, spaceCombo, panHwnd
    if !panSostenido
        return
    panSostenido := false
    panHwnd := 0
    spaceCombo := false
    Send("{MButton up}")
}

; Seguridad: si el cursor sale de PureRef o se suelta Space, soltar el clic central y la Z
SoltarEstadosSiSalePanel() {
    global zoomSostenido, panSostenido, spaceAbajo
    if (zoomSostenido && PureRefObjetivo() = 0)
        SoltarZoom()
    if (panSostenido && (!spaceAbajo || PureRefObjetivo() = 0))
        SoltarPan()
}

; ── Escala de grises: F (selección) y Espacio+F (todo el archivo) ─
; PureRef tiene dos acciones distintas:
;   · "Toggle grayscale" (Images > Selection)  → imágenes seleccionadas. No trae atajo:
;     asígnale UNA vez Ctrl+Shift+Alt+F en PureRef (Settings > Shortcuts), o cambia
;     EnvioGrisSeleccion= en [Config] por el atajo que prefieras.
;   · "Grayscale canvas" (Canvas > Grayscale)  → todo el archivo. Por defecto Ctrl+Alt+G.
; Como los atajos van al teclado, el panel de PureRef se activa un instante y
; luego se devuelve el foco a la ventana que estaba activa (p. ej. CSP).
GrisPulsado() {
    global INI, panSostenido, spaceCombo, spaceAbajo, panHwnd
    hwnd := PureRefObjetivo()
    if !hwnd
        return
    if spaceAbajo {
        ; Espacio + F → todo el archivo. Se suelta el pan (clic central) que Espacio había iniciado.
        if panSostenido {
            Send("{MButton up}")
            panSostenido := false
            panHwnd := 0
        }
        spaceCombo := true
        envio := Trim(IniRead(INI, "Config", "EnvioGrisTodo", "^a|!g"))
        txt := "◐ Alternar escala de grises: TODO el archivo"
    } else {
        envio := Trim(IniRead(INI, "Config", "EnvioGrisSeleccion", "^+!f"))
        txt := "◐ Escala de grises: selección"
    }
    if (envio != "") {
        EnviarAPureRef(hwnd, envio)
        Aviso(txt, 1000)
    }
    try KeyWait(LTrim(A_ThisHotkey, "$*~"))     ; el auto-repeat de F no alterna varias veces
}

; Manda teclas a un panel de PureRef: lo activa, envía y devuelve el foco a la ventana previa.
EnviarAPureRef(hwnd, teclas) {
    previa := WinExist("A")
    if (previa != hwnd) {
        try WinActivate("ahk_id " hwnd)
        try WinWaitActive("ahk_id " hwnd, , 0.4)
    }
    Sleep(50)
    ; Si Space estaba presionado por el usuario para el combo, enviar la tecla sin que Windows la vea como Space+tecla
    for t in StrSplit(teclas, "|") {          ; "a|b" = varias teclas en secuencia
        SendEvent("{Blind}{Space up}" Trim(t))
        Sleep(60)
    }
    if (previa && previa != hwnd) {
        Sleep(80)
        try WinActivate("ahk_id " previa)
    }
}

; Si Espacio se soltó con el cursor fuera del panel, no dejar el bloqueo de combo activo.
LimpiarSpaceCombo() {
    global spaceCombo, spaceAbajo
    if (spaceCombo && !spaceAbajo)
        spaceCombo := false
}

; ── Space: Pan nativo sobre PureRef ──────────────────────────────
; PureRef nativo hace Pan con Clic Central (MButton) o Alt + Clic Izquierdo.
; Usar MButton evita simular la tecla Alt y elimina por completo cualquier
; interferencia con Alt+Space (cambio de monitor).
; Espacio + F no pierde nada: F suelta el pan y manda "Grayscale canvas".

#HotIf (PureRefObjetivo() != 0 && !GetKeyState("Alt", "P"))
$Space:: {
    global panSostenido, spaceCombo, spaceAbajo, panHwnd
    fresca := !spaceAbajo           ; pulsación nueva (no auto-repeat)
    spaceAbajo := true              ; también con el auto-repeat: si el pan se soltó (cursor fuera), se reanuda
    if fresca
        spaceCombo := false         ; un combo Espacio+F que quedó pegado no debe bloquear el pan siguiente
    if (panSostenido && !GetKeyState("MButton"))
        panSostenido := false, panHwnd := 0     ; pan "pegado": el clic central ya no está abajo
    if (panSostenido || spaceCombo) {
        Log("PAN bloqueado (panSostenido=" panSostenido " spaceCombo=" spaceCombo ")")
        return
    }
    panSostenido := true
    panHwnd := PureRefObjetivo()
    Log("PAN inicio")
    Send("{MButton down}")
}

; Soporte simultáneo para Ctrl+1 y Ctrl+2 (para que funcionen ambos: Ctrl++/Ctrl+- y Ctrl+1/Ctrl+2)
$^1::Send("^{NumpadAdd}")
$^2::Send("^{NumpadSub}")
#HotIf

; La suelta de Espacio se atiende SIEMPRE (sin condición, y dejando pasar la tecla con ~),
; venga del teclado o de la keydial: así el pan nunca queda "pegado" ni se corta antes de tiempo.
~$Space up:: {
    global spaceAbajo, spaceCombo
    spaceAbajo := false
    spaceCombo := false
    if panSostenido
        Log("PAN fin")
    SoltarPan()
}

; ── Alt+Espacio: mandar el panel al otro monitor ─────────────────
; Ventana objetivo: la de PureRef bajo el cursor (lápiz/mouse); si no hay,
; la ventana activa si es de PureRef. 0 = ninguna (el atajo no se activa y
; Alt+Espacio funciona normal en el resto de programas).
PureRefObjetivo() {
    h := 0
    try MouseGetPos(, , &h)
    if (h && PanelUsable(h))
        return h
    h := WinExist("A")
    if (h && PanelUsable(h))
        return h
    return 0
}

; Ventana de PureRef existente y NO minimizada (a ella actúan Espacio, F, Q, etc.).
PanelUsable(h) {
    global PROC
    try {
        if (WinGetProcessName("ahk_id " h) != PROC)
            return false
        return (WinGetMinMax("ahk_id " h) != -1)     ; las minimizadas no cuentan
    }
    return false
}

; Índice del monitor que contiene el punto (0 si ninguno).
MonitorDePunto(px, py) {
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if (px >= l && px < r && py >= t && py < b)
            return A_Index
    }
    return 0
}

; Monitor de "la tableta" (donde vive el perfil del panel). Orden de decisión:
;   1) [Config] MonitorTableta=N   2) monitor del perfil guardado del panel
;   3) monitor de Clip Studio Paint   4) monitor principal.
MonitorCasa(hwnd) {
    global INI
    n := MonitorGetCount()
    cfg := IniRead(INI, "Config", "MonitorTableta", "")
    if (IsInteger(cfg) && Integer(cfg) >= 1 && Integer(cfg) <= n)
        return Integer(cfg)
    try {
        e := EntradaDeTitulo(WinGetTitle("ahk_id " hwnd))
        if (e) {
            r := RectDe(e)
            m := MonitorDePunto(r.x + r.w // 2, r.y + r.h // 2)
            if m
                return m
        }
    }
    try {
        c := WinExist("ahk_exe CLIPStudioPaint.exe")
        if c {
            WinGetPos(&cx, &cy, &cw, &ch, "ahk_id " c)
            m := MonitorDePunto(cx + cw // 2, cy + ch // 2)
            if m
                return m
        }
    }
    return MonitorGetPrimary()
}

; Mueve dos veces: al cruzar monitores con distinto escalado, Windows puede
; reescalar la ventana tras el primer movimiento y el segundo la deja exacta.
MoverVentana(hwnd, x, y, w, h) {
    IgnorarMovimiento(hwnd)
    try {
        WinMove(x, y, w, h, "ahk_id " hwnd)
        if !PosicionOk(hwnd, {x: x, y: y, w: w, h: h}) {
            Sleep(15)
            WinMove(x, y, w, h, "ahk_id " hwnd)
        }
    }
}

; ¿La ventana ya está exactamente en el rectángulo r? (si sí, no hace falta mover dos veces)
PosicionOk(hwnd, r) {
    try {
        WinGetPos(&px, &py, &pw, &ph, "ahk_id " hwnd)
        return (px = r.x && py = r.y && pw = r.w && ph = r.h)
    }
    return false
}

; Alt+Espacio/Q: salta el panel entre la TABLETA y el OTRO monitor. Sin escalar y sin mandar atajos de vista.
;   · Si el perfil tiene posición guardada para el destino (pantalla / normal-enfoque), va ahí.
;   · Si no, se traslada conservando su tamaño y su posición relativa (solo se recorta si no cabe).
; [Config] MonitorExpandido=N elige el destino si hay 3 o más monitores.
TrasladarA(hwnd, origen, destino) {
    WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    MonitorGetWorkArea(origen, &al, &at, &ar, &ab)
    MonitorGetWorkArea(destino, &dl, &dt, &dr, &db)
    aw := Max(1, ar - al), ah := Max(1, ab - at)
    dw := dr - dl, dh := db - dt
    nw := Min(w, dw), nh := Min(h, dh)
    nx := dl + Round((x - al) * dw / aw)
    ny := dt + Round((y - at) * dh / ah)
    nx := Max(dl, Min(nx, dr - nw))
    ny := Max(dt, Min(ny, db - nh))
    MoverVentana(hwnd, nx, ny, nw, nh)
}

MoverAlOtroMonitor() {
    global colocadas, INI, ultimoMover
    hwnd := PureRefObjetivo()
    if !hwnd
        return
    if (ultimoMover.Has(hwnd) && A_TickCount - ultimoMover[hwnd] < 700)
        return                      ; auto-repeat: una sola vez por pulsación (por ventana)
    ultimoMover[hwnd] := A_TickCount
    Log("Salto de monitor")
    n := MonitorGetCount()
    if (n < 2) {
        Aviso("Solo hay un monitor", 1000)
        return
    }
    try {
        if (WinGetMinMax("ahk_id " hwnd) != 0)
            WinRestore("ahk_id " hwnd)
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    } catch {
        return
    }
    actual := MonitorDePunto(x + w // 2, y + h // 2)
    if !actual
        actual := MonitorGetPrimary()
    casa := MonitorCasa(hwnd)
    titulo := ""
    try titulo := WinGetTitle("ahk_id " hwnd)
    e := EntradaDeTitulo(titulo)
    colocadas[hwnd] := true         ; que AutoColocar no la devuelva al perfil por su cuenta

    if (actual = casa) {
        otroCfg := IniRead(INI, "Config", "MonitorExpandido", "0")
        otro := IsInteger(otroCfg) ? Integer(otroCfg) : 0
        if (otro < 1 || otro > n || otro = casa)
            otro := Mod(casa, n) + 1
        if (IsObject(e) && e.tieneM)
            MoverVentana(hwnd, e.xm, e.ym, e.wm, e.hm)
        else
            TrasladarA(hwnd, actual, otro)
        Aviso("🖥 PureRef → monitor " otro, 1000)
    } else {
        if IsObject(e) {
            Colocar(hwnd, e)
            if !PosicionOk(hwnd, RectDe(e)) {
                Sleep(15)
                Colocar(hwnd, e)
            }
        } else {
            TrasladarA(hwnd, actual, casa)
        }
        Aviso("🖥 PureRef → tableta (monitor " casa ")", 1000)
    }
}

RecolocarTodas() {
    global colocadas
    colocadas.Clear()   ; AutoColocar las vuelve a colocar en el siguiente ciclo
    Aviso("Recolocando paneles de PureRef…", 1000)
}

; ── Config GLOBAL ───────────────────────────────────────────────
; Un solo juego de posiciones (manual / enfoque / pantalla) guardado en PureRef_layout_global.ini,
; INDEPENDIENTE de los perfiles de cada archivo (PureRef_layouts\<archivo>.ini).
;   · Guardar global: toma la posición actual del panel activo y la guarda en la ranura global elegida.
;   · Aplicar global: copia la(s) ranura(s) global(es) al perfil individual del panel activo
;     (solo ese panel; los demás no se tocan) y lo coloca si corresponde.
; El menú de la bandeja le quita el foco a PureRef, así que se usa el último panel que estuvo activo.
PanelActual() {
    global ultimoPanel
    if (ultimoPanel && WinExist("ahk_id " ultimoPanel) && PanelUsable(ultimoPanel))
        return ultimoPanel
    return PureRefObjetivo()
}

GuardarGlobalDesdePanel(slot) {
    global GLOBALINI
    hwnd := PanelActual()
    if !hwnd {
        Aviso("Activa primero un panel de PureRef", 2000)
        return
    }
    try {
        if (WinGetMinMax("ahk_id " hwnd) != 0) {
            Aviso("Restaura la ventana (no maximizada) antes de guardar", 2200)
            return
        }
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    } catch {
        return
    }
    if !FileExist(GLOBALINI)
        FileAppend("[Layout]`r`n", GLOBALINI, "UTF-16")
    sfx := (slot = "N") ? "" : slot
    IniWrite(x, GLOBALINI, "Layout", "X" sfx)
    IniWrite(y, GLOBALINI, "Layout", "Y" sfx)
    IniWrite(w, GLOBALINI, "Layout", "W" sfx)
    IniWrite(h, GLOBALINI, "Layout", "H" sfx)
    SoundBeep(1000, 50)
    Aviso("🌐 Global (" (slot = "M" ? "pantalla" : slot = "E" ? "enfoque" : "manual") "): " x ", " y "  " w "×" h, 1800)
}

; cual: "T" = las tres · "N" manual · "E" enfoque · "M" pantalla
AplicarGlobalAPanel(cual) {
    global GLOBALINI, modo, colocadas
    hwnd := PanelActual()
    if !hwnd {
        Aviso("Activa primero un panel de PureRef", 2000)
        return
    }
    titulo := ""
    try titulo := WinGetTitle("ahk_id " hwnd)
    nuevo := ""
    e := IdentificarPerfil(titulo, &nuevo)
    nombre := IsObject(e) ? e.nombre : nuevo
    if (nombre = "") {
        MsgBox("No pude deducir el nombre del archivo desde el título:`n`n" titulo
             . "`n`nGuarda la escena en PureRef primero.", "PureRef layout", 48)
        return
    }
    arch := IsObject(e) ? "" : ArchivoDeProceso(hwnd, titulo)     ; "" = no tocar el campo Archivo
    if (!IsObject(e) && cual != "T" && cual != "N") {
        ; perfil nuevo: necesita siempre su posición manual (la actual)
        try {
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            GuardarPerfil(nombre, arch, "N", x, y, w, h)
            arch := ""
        }
    }
    aplicadas := ""
    for s in (cual = "T" ? ["N", "E", "M"] : [cual]) {
        rr := LeerRect(GLOBALINI, s = "N" ? "" : s)
        if !rr
            continue
        GuardarPerfil(nombre, arch, s, rr.x, rr.y, rr.w, rr.h)
        arch := ""
        aplicadas .= (aplicadas = "" ? "" : ", ") (s = "M" ? "pantalla" : s = "E" ? "enfoque" : "manual")
    }
    if (aplicadas = "") {
        Aviso("El global no tiene guardada esa posición todavía", 2200)
        return
    }
    CargarEntradas()
    ConstruirMenu()
    ; colocar ahora lo que corresponda a la situación actual del panel
    e2 := IdentificarPerfil(titulo, &n2)
    if IsObject(e2) {
        colocadas[hwnd] := true
        if EnOtroMonitor(hwnd) {
            if (e2.tieneM && (cual = "T" || cual = "M"))
                MoverVentana(hwnd, e2.xm, e2.ym, e2.wm, e2.hm)
        } else if (cual = "T" || (cual = "N" && !modo) || (cual = "E" && modo)) {
            Colocar(hwnd, e2)
        }
    }
    SoundBeep(1000, 50)
    Aviso("🌐 Global → «" nombre "» (" aplicadas ")", 2200)
}

; Guardado MANUAL de la ventana de PureRef activa (con el guardado automático ya no hace falta,
; pero sirve para forzar un slot concreto: normal / enfoque / monitor grande).
CapturarVentanaActiva(destino := "") {
    global PROC, modo, colocadas

    if (destino = "")
        destino := modo        ; con el atajo: el modo en el que estés

    SoundBeep(600, 40)   ; confirma que el atajo llegó (aunque luego avise de un problema)
    hwnd := WinExist("A")
    if !hwnd
        return
    proc := WinGetProcessName("ahk_id " hwnd)
    if (proc != PROC) {
        MsgBox("La ventana activa no es la de PureRef para este script.`n`n"
             . "Proceso activo: " proc "`nTítulo: " WinGetTitle("ahk_id " hwnd)
             . "`n`nEl script espera: " PROC
             . "`nSi esa ventana ES PureRef, pon Proceso=" proc " en [Config] de PureRef_layout.ini y recarga el script.", "PureRef layout", 48)
        return
    }
    if (WinGetMinMax("ahk_id " hwnd) != 0) {
        Aviso("Restaura la ventana (no maximizada) antes de guardar su posición", 2500)
        return
    }
    titulo := WinGetTitle("ahk_id " hwnd)
    WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    nuevoNombre := ""
    e := IdentificarPerfil(titulo, &nuevoNombre)
    if IsObject(e) {
        nombre := e.nombre
        archivo := e.archivo
    } else {
        nombre := nuevoNombre
        if (nombre = "") {
            MsgBox("No pude deducir el nombre del archivo desde el título:`n`n" titulo
                 . "`n`nGuarda la escena en PureRef primero.", "PureRef layout", 48)
            return
        }
        archivo := ArchivoDeProceso(hwnd, titulo)
    }

    casa := MonitorCasa(hwnd)
    monAct := MonitorDePunto(x + w // 2, y + h // 2)
    if (destino = "M" || (IsObject(e) && monAct != casa && monAct != 0))
        slot := "M"
    else
        slot := destino ? "E" : "N"

    if !IsObject(e) {
        ; perfil nuevo: la posición normal siempre queda guardada (y enfoque/monitor si es el caso)
        GuardarPerfil(nombre, archivo, "N", x, y, w, h)
        colocadas[hwnd] := true
    }
    if (slot != "N" || IsObject(e))
        GuardarPerfil(nombre, archivo, slot, x, y, w, h)
    CargarEntradas()
    ConstruirMenu()
    SoundBeep(1000, 50)
    Aviso("📌 " nombre " (" (slot = "M" ? "monitor grande" : (slot = "E" ? "enfoque" : "normal")) "): " x ", " y "  " w "×" h, 1800)
}
