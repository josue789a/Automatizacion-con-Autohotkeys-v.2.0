#SingleInstance Force
#NoEnv
SetWorkingDir %A_ScriptDir%

; --- CONFIGURACIÓN ---
EnvGet, PerfilUsuario, USERPROFILE
CarpetaDescarga := PerfilUsuario . "\Downloads"

; Busca yt-dlp en varias ubicaciones posibles
Candidatas := []
Candidatas.Push(PerfilUsuario . "\Documents\@Otros\Descargador_yt-dlp")
Candidatas.Push(A_MyDocuments . "\@Otros")
Candidatas.Push(PerfilUsuario . "\Documents\@Otros")
Candidatas.Push(A_ScriptDir)

CarpetaBase := ""
for i, c in Candidatas
{
    if FileExist(c . "\yt-dlp.exe")
    {
        CarpetaBase := c
        break
    }
}

if (CarpetaBase = "")
{
    Probadas := ""
    for i, c in Candidatas
        Probadas .= c . "\yt-dlp.exe`n"
    MsgBox, 16, Error, yt-dlp.exe no encontrado. Rutas probadas:`n`n%Probadas%
    ExitApp
}

RutaYtDlp  := CarpetaBase . "\yt-dlp.exe"
RutaIcono  := "C:\Users\jbard\Documents\@Otros\icons\DWNL.ico"
if !FileExist(RutaIcono)
    RutaIcono := CarpetaBase . "\icons\DWNL.ico"
ArchivoLog := CarpetaBase . "\log.txt"
UsarIcono  := FileExist(RutaIcono) ? true : false
if (UsarIcono)
    Menu, Tray, Icon, %RutaIcono%
; ---------------------

#If !WinActive("ahk_exe ClipStudioPaint.exe")

^+d::
    url := Trim(Clipboard)
    if (url = "")
    {
        MsgBox, 48, Aviso, Clipboard is empty.`n1. Copy a link.`n2. Press Ctrl+Shift+D
        return
    }

    PosX := A_ScreenWidth - 220
    PosY := A_ScreenHeight - 70

    ; --- Notificación: descargando ---
    Gui, DownloadNotify:Destroy
    Gui, DownloadNotify:New, +AlwaysOnTop -Caption +ToolWindow
    Gui, DownloadNotify:Color, 1a1a1a
    if (UsarIcono)
    {
        Gui, DownloadNotify:Add, Picture, x12 y10 w20 h20, %RutaIcono%
    }
    else
    {
        Gui, DownloadNotify:Font, s12 w300 cAAAAAA, Segoe UI Emoji
        Gui, DownloadNotify:Add, Text, x12 y8, 📥
    }
    Gui, DownloadNotify:Font, s10 w300 cFFFFFF, Segoe UI
    Gui, DownloadNotify:Add, Text, x40 y12, Downloading...
    Gui, DownloadNotify:Show, x%PosX% y%PosY% w200 h40 NoActivate, DownloadNotify
    DllCall("MessageBeep", "UInt", 0xFFFFFFFF)

    ; --- Comando (comillas envueltas para cmd /c) ---
    q := Chr(34)
    interno := q . RutaYtDlp . q
        . " -f " . q . "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best" . q
        . " --merge-output-format mp4"
        . " -P " . q . CarpetaDescarga . q
        . " " . q . url . q
        . " > " . q . ArchivoLog . q . " 2>&1"
    comando := ComSpec . " /c " . q . interno . q

    RunWait, %comando%, , Hide
    CodigoSalida := ErrorLevel

    Gui, DownloadNotify:Destroy

    if (CodigoSalida != 0)
    {
        Gui, ErrorNotify:Destroy
        Gui, ErrorNotify:New, +AlwaysOnTop -Caption +ToolWindow
        Gui, ErrorNotify:Color, 8B0000
        Gui, ErrorNotify:Font, s10 w300 cFFFFFF, Segoe UI
        Gui, ErrorNotify:Add, Text, x12 y12, Download failed
        Gui, ErrorNotify:Show, x%PosX% y%PosY% w200 h40 NoActivate, ErrorNotify
        DllCall("MessageBeep", "UInt", 0x10)
        SetTimer, CerrarError, -4000
    }
    else
    {
        Gui, SuccessNotify:Destroy
        Gui, SuccessNotify:New, +AlwaysOnTop -Caption +ToolWindow
        Gui, SuccessNotify:Color, 1a1a1a
        if (UsarIcono)
        {
            Gui, SuccessNotify:Add, Picture, x12 y10 w20 h20, %RutaIcono%
        }
        else
        {
            Gui, SuccessNotify:Font, s12 w300 cAAAAAA, Segoe UI Emoji
            Gui, SuccessNotify:Add, Text, x12 y8, ✅
        }
        Gui, SuccessNotify:Font, s10 w300 cFFFFFF, Segoe UI
        Gui, SuccessNotify:Add, Text, x40 y12, Downloaded
        Gui, SuccessNotify:Show, x%PosX% y%PosY% w200 h40 NoActivate, SuccessNotify
        DllCall("MessageBeep", "UInt", 0x40)
        SetTimer, CerrarSuccess, -2500
    }
return

#If

CerrarSuccess:
    Gui, SuccessNotify:Destroy
return

CerrarError:
    Gui, ErrorNotify:Destroy
return