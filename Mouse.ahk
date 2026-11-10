#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir(A_ScriptDir)
TraySetIcon("C:\Users\jbard\Documents\@Otros\icons\mouse.ico")
A_IconTip := "Atajos de Mouse — Fin/Inicio, selección por palabra/línea (AHK)"



; ╔══════════════════════════════════════════════════════════════╗
; ║  BOTONES LATERALES DEL MOUSE                                   ║
; ╚══════════════════════════════════════════════════════════════╝
XButton1::Send("^j")          ; Ditto - abrir portapapeles

; XButton2: solo = ShareX fijar en pantalla | + click izq = ShareX captura con guardar como
xb2Combo := false

XButton2:: {
    global xb2Combo := false
    SetTimer(CheckComboXB2, 10)
}

XButton2 up:: {
    SetTimer(CheckComboXB2, 0)
    global xb2Combo
    if (!xb2Combo)
        Send("^!j")
}

CheckComboXB2() {
    global xb2Combo
    if (GetKeyState("LButton", "P") && !xb2Combo) {
        xb2Combo := true
        Send("+a")
        SetTimer(CheckComboXB2, 0)
    }
}

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

; --- Impr Pant ---
; La tecla "." y "Del" del numpad son la misma tecla física: AHK la ve como
; NumpadDot con Bloq Num activo y NumpadDel con Bloq Num apagado. Se cubren ambas.
NumpadDot::Send("{PrintScreen}")
NumpadDel::Send("{PrintScreen}")
Numpad0::Send("{PrintScreen}")
NumpadIns::Send("{PrintScreen}")

; ╔══════════════════════════════════════════════════════════════╗
; ║  XPPEN                                                         ║
; ╚══════════════════════════════════════════════════════════════╝
^+!h:: {
    Send("{Ctrl up}{Shift up}{Alt up}")
    Send("^{Escape}")
}

