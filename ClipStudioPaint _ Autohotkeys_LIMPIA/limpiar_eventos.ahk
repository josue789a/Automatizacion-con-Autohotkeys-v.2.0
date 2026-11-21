#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, OutputDebug

try {
    _EjecutarLimpieza()
} catch as err {
    DirCreate(A_ScriptDir "\logs")
    FileAppend("ERROR CRITICO [" err.Line "]: " err.Message "`n" err.Stack "`n", A_ScriptDir "\logs\limpiar_err.log", "UTF-8")
    ExitApp(1)
}

_EjecutarLimpieza() {
    aplicar := false, incSonido := false, incCustom := false, legado := "", silencioso := false
    ini := A_ScriptDir "\posiciones_gui.ini"
    for a in A_Args {
        if (a = "--aplicar")
            aplicar := true
        else if (a = "--sonido")
            incSonido := true
        else if (a = "--custom")
            incCustom := true
        else if (a = "--silencioso" || a = "-s")
            silencioso := true
        else if (SubStr(a, 1, 6) = "--ini=")
            ini := Trim(SubStr(a, 7), ' "`t')
        else if (SubStr(a, 1, 9) = "--legado=")
            legado := Trim(SubStr(a, 10), ' "`t')
    }
    if !FileExist(ini) {
        if !silencioso
            MsgBox("No existe el INI:`n" ini)
        try FileAppend("No existe el INI: " ini "`n", "*")
        ExitApp(1)
    }
    if (legado != "") {
        if (legado != "0" && legado != "1") {
            if !silencioso
                MsgBox("--legado debe ser 0 o 1")
            try FileAppend("--legado debe ser 0 o 1`n", "*")
            ExitApp(1)
        }
        IniWrite(legado, ini, "Modo", "legado")
        msg := "[Modo] legado=" legado " escrito. Reinicia el script CSP."
        try FileAppend(msg "`n", "*")
        if !silencioso
            MsgBox(msg)
        ExitApp(0)
    }

    patron := "i)^(Remapeos|HudEventos.*|Particularidades.*|HudTextos.*"
    if incSonido
        patron .= "|HudSonido.*|HudDuraciones.*"
    if incCustom
        patron .= "|EventosCustom"
    patron .= ")$"
    protegidas := "i)^(Puntos|Rangos|Layout|Estab|NvConfig|Avisos|Modo)"

    ts := FormatTime(, "yyyyMMdd_HHmmss")
    DirCreate(A_ScriptDir "\logs")
    log := A_ScriptDir "\logs\limpieza_" ts ".log"
    objetivo := [], prot := Map()
    for s in StrSplit(IniRead(ini, , , ""), "`n", "`r") {
        if (s = "")
            continue
        if RegExMatch(s, protegidas)
            prot[s] := IniRead(ini, s, , "")
        else if RegExMatch(s, patron)
            objetivo.Push(s)
    }

    txt := (aplicar ? "APLICAR" : "SIMULACRO") " - " ini "`n`nSe borrarian:`n"
    for s in objetivo {
        contenidoSec := IniRead(ini, s, , "")
        lineas := StrSplit(contenidoSec, "`n", "`r")
        n := (contenidoSec = "") ? 0 : lineas.Length
        txt .= "  [" s "] (" n " claves)`n"
        FileAppend("[" s "]`n" contenidoSec "`n`n", log, "UTF-8")
    }
    txt .= "`nProtegidas (intactas):`n"
    for s in prot
        txt .= "  [" s "]`n"
    txt .= "`nLog con las claves: " log

    try FileAppend(txt "`n", "*")

    if !aplicar {
        if !silencioso
            MsgBox(txt "`n`nRevisa el log (claves que no sean de eventos) antes de usar --aplicar.")
        ExitApp(0)
    }

    bak := ini ".bak-" ts
    FileCopy(ini, bak)
    for s in objetivo
        IniDelete(ini, s)

    ok := true
    for s, antes in prot
        if (IniRead(ini, s, , "") != antes)
            ok := false
    for s in StrSplit(IniRead(ini, , , ""), "`n", "`r")
        if (s != "" && !RegExMatch(s, protegidas) && RegExMatch(s, patron))
            ok := false
    if !ok {
        FileCopy(bak, ini, true)
        err := "Verificacion fallida: INI restaurado desde`n" bak
        try FileAppend(err "`n", "*")
        if !silencioso
            MsgBox(err)
        ExitApp(1)
    }
    finMsg := txt "`n`nHECHO. Respaldo: " bak "`nReinicia el script CSP."
    try FileAppend(finMsg "`n", "*")
    if !silencioso
        MsgBox(finMsg)
    ExitApp(0)
}
