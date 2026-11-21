#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ============================================================================
; spike_noactivate.ahk  -  PAQUETE 0 (S0)  -  NO toca producción
;
; Uso:  AutoHotkey64.exe spike_noactivate.ahk [modo] [monitor]
;   modo 1 = WS_EX_NOACTIVATE + WM_MOUSEACTIVATE -> MA_NOACTIVATE  (diseño final)
;   modo 2 = solo WS_EX_NOACTIVATE
;   modo 3 = CONTROL: ventana normal (DEBE robar foco -> el driver salta a General)
;   monitor = índice de monitor (por defecto el principal; usa el de la tableta)
;
; Salida: spike_noactivate.log (junto al script) + OutputDebug.
; Pánico: Ctrl+Alt+Shift+Q
;
; PROTOCOLO
;  A) Haz clic en CSP. Lanza el spike en modo 1. Haz 20 clics en la píldora con el
;     mouse y 20 con el lápiz. Esperado: el log NO muestra transición de FG a
;     AutoHotkey64.exe y el driver sigue en el perfil de CSP (pulsa una K y verifica
;     que ejecuta la macro de CSP).
;  B) Repite con modo 3. Esperado: FG pasa a AutoHotkey64.exe y el driver salta a
;     General. Eso confirma la hipótesis "el driver conmuta por ventana activa".
;  C) Settle: pon cualquier otra app en primer plano (p. ej. el calibrador), haz clic
;     en "Medir settle". Se activa CSP y arranca el cronómetro. Pulsa la MISMA K cada
;     ~100 ms durante 1 s. En el log, el tiempo (+Nms) de la primera tecla que ya
;     emite la macro de CSP es el settle_ms a usar.
; ============================================================================

ObtenerMonitorTableta() {
    prim := MonitorGetPrimary()
    loop MonitorGetCount() {
        if (A_Index != prim)
            return A_Index
    }
    return prim
}

global gModo := A_Args.Length >= 1 ? Integer(A_Args[1]) : 1
global gMon := A_Args.Length >= 2 ? Integer(A_Args[2]) : ((MonitorGetCount() > 1) ? ObtenerMonitorTableta() : MonitorGetPrimary())
global gLog := A_ScriptDir "\spike_noactivate.log"
global gClicks := 0
global gT0 := 0
global gFgPrev := ""
global gRobos := 0

P(n) => Round(n * A_ScreenDPI / 96)

Q() {
    static f := 0
    c := 0
    if !f
        DllCall("QueryPerformanceFrequency", "Int64*", &f)
    DllCall("QueryPerformanceCounter", "Int64*", &c)
    return c * 1000.0 / f
}

Log(txt) {
    OutputDebug("[SPIKE] " txt)
    try FileAppend(Round(Q(), 1) " ms | " txt "`n", gLog, "UTF-8")
}

; ---------------------------------------------------------------- ventana
opciones := "+AlwaysOnTop -Caption +ToolWindow -DPIScale"
if (gModo <= 2)
    opciones .= " +E0x08000000"          ; WS_EX_NOACTIVATE
g := Gui(opciones, "spike_noactivate")
g.BackColor := "1E1E2E"
g.SetFont("s10 cFFFFFF", "Segoe UI")
txtModo := (gModo = 1) ? "NOACTIVATE + MA_NOACTIVATE" : (gModo = 2) ? "solo estilo NOACTIVATE" : "CONTROL (ventana normal)"
g.AddText("x" P(12) " y" P(8) " w" P(280) " h" P(22) " +0x200", "S0 · m" gModo " · Mon " gMon " · " txtModo)
bSwap := g.AddText("x" P(298) " y" P(8) " w" P(90) " h" P(22) " +0x100 +0x200 Center Background4A4A6A", "⇆ Pantalla")
bSwap.OnEvent("Click", OnSwapMonitor)
bClic := g.AddText("x" P(12) " y" P(36) " w" P(376) " h" P(34) " +0x100 +0x200 Center Background7C4DFF", "Clic aquí (mouse / lápiz)")
bClic.OnEvent("Click", OnClic)
tFg := g.AddText("x" P(12) " y" P(78) " w" P(376) " h" P(22) " +0x200", "FG: -")
bSet := g.AddText("x" P(12) " y" P(106) " w" P(376) " h" P(34) " +0x100 +0x200 Center Background3B3B52", "⏱ Medir settle (activa CSP y arranca cronómetro)")
bSet.OnEvent("Click", OnSettle)

MonitorGet(gMon, &mL, &mT, &mR, &mB)
wV := P(400), hV := P(150)
xV := mL + ((mR - mL) - wV) // 2
yV := mT + P(60)

if (gModo = 1)
    OnMessage(0x21, MouseActivate)       ; WM_MOUSEACTIVATE

g.Show("NA x" xV " y" yV " w" wV " h" hV)
try WinSetRegion("0-0 w" wV " h" hV " R" P(16) "-" P(16), "ahk_id " g.Hwnd)

; Evita que Windows Ink convierta "apoyar la punta" en un RButton falso sobre la píldora
; (TABLET_DISABLE_PRESSANDHOLD 0x1 | PENTAPFEEDBACK 0x8 | PENBARRELFEEDBACK 0x10)
atomo := DllCall("GlobalAddAtom", "str", "MicrosoftTabletPenServiceProperty", "ushort")
DllCall("SetProp", "ptr", g.Hwnd, "ptr", atomo, "ptr", 0x19, "int")

; ---------------------------------------------------------------- logger pasivo
ih := InputHook("V L9999")
ih.KeyOpt("{All}", "N")
ih.OnKeyDown := OnKD
ih.OnEnd := (*) => ih.Start()
ih.Start()

SetTimer(PollFg, 50)
OnExit(SpikeSalir)
Log("INICIO modo=" gModo " monitor=" gMon " hwnd=" Format("0x{:X}", g.Hwnd))

; ---------------------------------------------------------------- callbacks
MouseActivate(wParam, lParam, msg, hwnd) {
    if DllCall("GetAncestor", "ptr", hwnd, "uint", 2, "ptr") = g.Hwnd    ; GA_ROOT
        return 3                                                          ; MA_NOACTIVATE
}

OnClic(*) {
    global gClicks
    gClicks += 1
    bClic.Text := "Clic aquí (mouse / lápiz) · " gClicks
    Log("CLICK #" gClicks " fg=" gFgPrev)
}

OnSettle(*) {
    global gT0
    gT0 := Q()
    Log("SETTLE t0: WinActivate(CSP)")
    try WinActivate("ahk_exe CLIPStudioPaint.exe")
    tFg.Text := "Pulsa la misma K cada ~100 ms durante 1 s"
}

OnKD(ihObj, vk, sc) {
    dt := gT0 ? "+" Round(Q() - gT0) "ms" : "-"
    nombre := GetKeyName(Format("vk{:02X}sc{:03X}", vk, sc))
    mods := (GetKeyState("Ctrl") ? "C" : "-") (GetKeyState("Shift") ? "S" : "-") (GetKeyState("Alt") ? "A" : "-") ((GetKeyState("LWin") || GetKeyState("RWin")) ? "W" : "-")
    Log("KEY " nombre " vk=" Format("{:02X}", vk) " mods=" mods " " dt)
}

PollFg() {
    global gFgPrev, gRobos
    h := DllCall("GetForegroundWindow", "ptr")
    exe := "?"
    try exe := WinGetProcessName("ahk_id " h)
    if (h = g.Hwnd) {
        gRobos += 1
        Log("!! LA PILDORA ES FOREGROUND (#" gRobos ")")
    }
    if (exe != gFgPrev) {
        Log("FG " gFgPrev " -> " exe " hwnd=" Format("0x{:X}", h))
        gFgPrev := exe
        tFg.Text := "FG: " exe
    }
}

OnSwapMonitor(*) {
    global gMon
    tot := MonitorGetCount()
    if (tot <= 1)
        return
    gMon := (gMon = 1) ? 2 : 1
    MonitorGet(gMon, &mL, &mT, &mR, &mB)
    wV := P(400), hV := P(150)
    xV := mL + ((mR - mL) - wV) // 2
    yV := mT + P(60)
    g.Move(xV, yV)
    Log("SWAP_MONITOR -> " gMon)
}

SpikeSalir(*) {
    SetTimer(PollFg, 0)
    try ih.Stop()
    try DllCall("RemoveProp", "ptr", g.Hwnd, "ptr", atomo, "ptr")
    try DllCall("GlobalDeleteAtom", "ushort", atomo)
    try g.Destroy()
    return 0
}

^!+q:: ExitApp()
