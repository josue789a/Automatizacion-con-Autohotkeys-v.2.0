#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon                      ; Oculto del System Tray de Windows
Persistent(true)
#UseHook true                    ; LL keyboard hook: captura teclas incluso con menús modales abiertos
InstallKeybdHook(true)           ; fuerza la instalación del hook de teclado
InstallMouseHook(true)           ; fuerza la instalación del hook de mouse
SetWorkingDir(A_ScriptDir)

; Mutex de sesión para que el Watchdog lo detecte de forma instantánea y robusta (0% CPU)
global g_MouseMutex := DllCall("CreateMutexW", "ptr", 0, "int", 1, "str", "Local\AHK_AtajosMouse_Mutex", "ptr")

; Centinela cruzado: Mouse.ahk también vigila a Watchdog.ahk cada 3 segundos
targetWatchdog := "C:\Users\jbard\Desktop\AHK-global-main\Watchdog.ahk"
CheckWatchdogScript()
SetTimer(CheckWatchdogScript, 3000)

CheckWatchdogScript() {
    global targetWatchdog
    SYNCHRONIZE := 0x00100000
    hMutex := DllCall("OpenMutexW", "uint", SYNCHRONIZE, "int", 0, "str", "Local\AHK_Watchdog_Mutex", "ptr")
    if (hMutex != 0) {
        DllCall("CloseHandle", "ptr", hMutex)
        return
    }
    try Run('"' A_AhkPath '" "' targetWatchdog '"')
}

; ╔══════════════════════════════════════════════════════════════╗
; ║  BOTONES LATERALES DEL MOUSE                                   ║
; ╚══════════════════════════════════════════════════════════════╝
XButton1::Send("^j")          ; Ditto - abrir portapapeles

; XButton2: solo = ShareX fijar en pantalla (^!j) | + click izq = Captura directa de la pantalla actual
xb2Combo := false

XButton2:: {
    global xb2Combo := false
}

XButton2 up:: {
    global xb2Combo
    if (!xb2Combo)
        Send("^!j")
}

; Al mantener XButton2 y hacer click izquierdo, AHK intercepta el click para no cerrar menús abiertos
#HotIf GetKeyState("XButton2", "P")
*LButton:: {
    global xb2Combo := true
    _CapturaPantallaActual()
}
#HotIf

; ╔══════════════════════════════════════════════════════════════╗
; ║  WINDOWTOP                                                     ║
; ╚══════════════════════════════════════════════════════════════╝
#q::Send("^!1")               ; Win+Q → Ctrl+Alt+1 (lanza el Crop de WindowTop)

; ╔══════════════════════════════════════════════════════════════╗
; ║  RUEDA DEL MOUSE — NAVEGACIÓN Y SELECCIÓN DE TEXTO             ║
; ╚══════════════════════════════════════════════════════════════╝

; Shift + rueda = Fin / Inicio de línea (desde el cursor)
+WheelUp::Send("{Blind}{End}")       ; arriba = Fin de línea
+WheelDown::Send("{Blind}{Home}")    ; abajo  = Inicio de línea

; Ctrl + Shift + rueda = seleccionar palabra por palabra (como Ctrl+Shift+Flecha)
^+WheelUp::Send("{Blind}{Right}")    ; siguiente palabra
^+WheelDown::Send("{Blind}{Left}")   ; palabra anterior

; Shift + Alt + rueda = seleccionar la línea completa (sin importar la posición del cursor)
+!WheelUp::
+!WheelDown:: {
    Send("{Blind}{Shift Up}{Alt Up}{Home}{Shift Down}{End}{Shift Up}")
}

; ╔══════════════════════════════════════════════════════════════╗
; ║  ONECOMMANDER — SUPRIMIR                                       ║
; ╚══════════════════════════════════════════════════════════════╝
#HotIf WinActive("ahk_exe OneCommander.exe")
Backspace & =::Send("{Delete}")      ; Backspace + = equivale a Supr
Backspace::Send("{Backspace}")       ; necesario para que Backspace siga funcionando solo
#HotIf

; ╔══════════════════════════════════════════════════════════════╗
; ║  BLUEWOLF M96 — TECLADO INTERNACIONAL Y DELETE                 ║
; ╚══════════════════════════════════════════════════════════════╝

; --- Caracteres ---
+n::SendText("ñ")                    ; Shift + n → ñ
+!n::SendText("Ñ")                   ; Shift + Alt + n → Ñ

; Tildes con RShift (Shift Derecho) manteniendo su función normal como Shift
; RShift + vocal → á, é, í, ó, ú (y con LShift o Bloq Mayús → Á, É, Í, Ó, Ú)
>+a::SendText(GetKeyState("LShift", "P") || GetKeyState("CapsLock", "T") ? "Á" : "á")
>+e::SendText(GetKeyState("LShift", "P") || GetKeyState("CapsLock", "T") ? "É" : "é")
>+i::SendText(GetKeyState("LShift", "P") || GetKeyState("CapsLock", "T") ? "Í" : "í")
>+o::SendText(GetKeyState("LShift", "P") || GetKeyState("CapsLock", "T") ? "Ó" : "ó")
>+u::SendText(GetKeyState("LShift", "P") || GetKeyState("CapsLock", "T") ? "Ú" : "ú")

; Intercambio de = (usa scancode: sc00D = tecla "=")
;   sin Shift: = → +
;   con Shift: = → =
$sc00D::Send("{+}")
$+sc00D::Send("=")

; Intercambio de - y _ (usa scancode: sc00C = tecla "-")
;   sin Shift: escribe "-"
;   con Shift: escribe "_"
$sc00C::SendText("-")
$+sc00C::SendText("_")

; --- Supr / Delete ---
+Backspace::Send("{Delete}")         ; Shift + Backspace → Supr
NumpadDiv::Send("{Delete}")          ; / del numpad → Supr

#HotIf !WinActive("ahk_exe CLIPStudioPaint.exe")
F12::Send("{Delete}")                ; F12 → Supr en todo Windows, excepto Clip Studio Paint
#HotIf

; ╔══════════════════════════════════════════════════════════════╗
; ║  CAPTURAS DE PANTALLA (Inmunes a menús de tray/modales)        ║
; ╚══════════════════════════════════════════════════════════════╝

; Ctrl + NumpadDel/Dot = Captura directa de la pantalla actual vía GDI (BitBlt)
; Captura solo el monitor bajo el cursor, pasando por encima de menús abiertos,
; modales o interfaces, directo al portapapeles sin cerrar nada.
^NumpadDot::_CapturaPantallaActual()
^NumpadDel::_CapturaPantallaActual()

_CapturaDirecta() => _CapturaPantallaActual()

_CapturaPantallaActual() {
    ; Determinar el monitor actual bajo el cursor del mouse
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)

    x := 0, y := 0, w := A_ScreenWidth, h := A_ScreenHeight
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &mL, &mT, &mR, &mB)
        if (mx >= mL && mx < mR && my >= mT && my < mB) {
            x := mL, y := mT, w := mR - mL, h := mB - mT
            break
        }
    }

    ; Captura directa GDI (BitBlt) del monitor activo sin alterar foco ni cerrar menús
    hScrDC := DllCall("GetDC", "ptr", 0, "ptr")
    hMemDC := DllCall("CreateCompatibleDC", "ptr", hScrDC, "ptr")
    hBmp   := DllCall("CreateCompatibleBitmap", "ptr", hScrDC, "int", w, "int", h, "ptr")
    hOld   := DllCall("SelectObject", "ptr", hMemDC, "ptr", hBmp, "ptr")

    DllCall("BitBlt", "ptr", hMemDC, "int", 0, "int", 0, "int", w, "int", h
          , "ptr", hScrDC, "int", x, "int", y, "uint", 0x00CC0020)  ; SRCCOPY

    DllCall("SelectObject", "ptr", hMemDC, "ptr", hOld)

    ; Copiar al portapapeles como bitmap
    if DllCall("OpenClipboard", "ptr", 0) {
        DllCall("EmptyClipboard")
        DllCall("SetClipboardData", "uint", 2, "ptr", hBmp)  ; CF_BITMAP
        DllCall("CloseClipboard")
    }

    DllCall("DeleteDC", "ptr", hMemDC)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hScrDC)
    ; No borrar hBmp — el clipboard es dueño ahora

    ToolTip("📸 Pantalla actual copiada al portapapeles")
    SetTimer(() => ToolTip(), -1500)
}

_ShareXCaptura(modo := "-PrintScreen") {
    static exe := ""
    if (exe = "") {
        ; Buscar ShareX: primero proceso activo vía WMI
        try {
            for proc in ComObjGet("winmgmts:").ExecQuery("SELECT ExecutablePath FROM Win32_Process WHERE Name='ShareX.exe'") {
                if (proc.ExecutablePath != "") {
                    exe := proc.ExecutablePath
                    break
                }
            }
        }
        if (exe = "") {
            ; Rutas de fallback conocidas (Windows Store y clásica)
            for path in [
                "C:\Program Files\WindowsApps\19568ShareX.ShareX_21.0.0.0_x64__egrzcvs15399j\ShareX.exe",
                "C:\Program Files\ShareX\ShareX.exe",
                A_AppData "\..\Local\ShareX\ShareX.exe"
            ] {
                if FileExist(path) {
                    exe := path
                    break
                }
            }
        }
        if (exe = "") {
            ; Último recurso si no se encuentra ShareX
            Send("{PrintScreen}")
            return
        }
    }
    try Run('"' exe '" ' modo,, "Hide")
}
