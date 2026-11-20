#Requires AutoHotkey v2.0
; ============================================================
; lib/espacial.ahk · Motor Espacial (cruzar / auto / hover)
; Sin código ejecutable a nivel raíz. Arranque: _EspacialIniciar()
; ============================================================

_EspEstado() {
    static e := Map("zonas", [], "pausa", false, "primar", true
                  , "mtime", "", "ini", "", "iniciado", false)
    return e
}

_EspacialIniciar() {
    e := _EspEstado()
    if e["iniciado"]
        return
    e["iniciado"] := true
    _EspacialCargar()
    SetTimer(_EspacialVigilarIni, 1500)
    OnExit(_EspacialSalir)
}

_EspacialSalir(*) {
    SetTimer(_EspacialTick, 0)
    SetTimer(_EspacialVigilarIni, 0)
    return 0   ; 0 = permitir la salida (no bloquear otros OnExit)
}

_EspacialPausar(estado := true) {
    e := _EspEstado()
    e["pausa"] := !!estado
    e["primar"] := true   ; al reanudar, re-sincroniza sin disparar
}

; Lee zonas activas del INI una sola vez y las deja en memoria.
_EspacialCargar() {
    e := _EspEstado()
    ini := _PosGuiIniPath()
    e["ini"] := ini
    try e["mtime"] := FileGetTime(ini, "M")

    txt := ""
    try txt := IniRead(ini, "Particularidades")

    flags := Map()
    Loop Parse txt, "`n", "`r" {
        p := InStr(A_LoopField, "=")
        if !p
            continue
        k := Trim(SubStr(A_LoopField, 1, p - 1))
        v := Trim(SubStr(A_LoopField, p + 1))
        if (v != "1" || !RegExMatch(k, "^(cruzar|auto|hover)_(.+)$", &m))
            continue
        if !flags.Has(m[2])
            flags[m[2]] := Map()
        flags[m[2]][m[1]] := true
    }

    sec := "Rangos" PERFIL
    nuevas := []
    for id, f in flags {
        x := IniRead(ini, sec, id "_x", ""), y := IniRead(ini, sec, id "_y", "")
        w := IniRead(ini, sec, id "_w", ""), h := IniRead(ini, sec, id "_h", "")
        if !(IsNumber(x) && IsNumber(y) && IsNumber(w) && IsNumber(h))
            continue
        x := Integer(x), y := Integer(y), w := Integer(w), h := Integer(h)
        if (w < 8 || h < 8)
            continue
        cruzar := f.Has("cruzar"), auto := f.Has("auto"), hover := f.Has("hover")
        atajo := Trim(IniRead(ini, "Remapeos", "atajo_" id, ""))
        if (cruzar && atajo = "" && !auto && !hover)
            continue
        nom := id
        try {
            n := _PtsNomEvento(id)
            if (n != "")
                nom := n
        }
        nuevas.Push({idEv: id, nombre: nom, x: x, y: y, w: w, h: h
                   , cruzar: cruzar, auto: auto, hover: hover
                   , atajo: atajo, dentro: false})
    }
    e["zonas"] := nuevas
    e["primar"] := true
    SetTimer(_EspacialTick, nuevas.Length ? 40 : 0)
}

; Detecta cambios del INI (incluye ediciones externas / _RemapVigilarIni).
_EspacialVigilarIni() {
    e := _EspEstado()
    try {
        m := FileGetTime(_PosGuiIniPath(), "M")
        if (m != e["mtime"])
            _EspacialCargar()
    }
}

; Polling ligero: cero lecturas de disco.
_EspacialTick() {
    static pt := Buffer(8, 0)
    e := _EspEstado()
    zonas := e["zonas"]
    if (e["pausa"] || !zonas.Length || A_IsSuspended)
        return
    if !WinActive("ahk_exe CLIPStudioPaint.exe") {
        e["primar"] := true
        return
    }
    if !DllCall("GetCursorPos", "Ptr", pt)
        return
    mx := NumGet(pt, 0, "Int"), my := NumGet(pt, 4, "Int")
    ; Trazo en curso o re-sincronización: actualizar estado sin disparar
    silencio := e["primar"] || GetKeyState("LButton")
    e["primar"] := false
    for z in zonas {
        dentro := (mx >= z.x && mx < z.x + z.w && my >= z.y && my < z.y + z.h)
        if (dentro && !z.dentro && !silencio)
            _EspacialDisparar(z)
        z.dentro := dentro
    }
}

_EspacialDisparar(z) {
    if (HasProp(z, "idEv") && _PtsEvPausado(z.idEv))
        return
    if (z.hover && !z.cruzar)
        try MostrarHUD("🎯 " z.nombre, "00E5FF", 700)
    if (z.cruzar) {
        try _ModEnviar(z.atajo, "⌨ " z.nombre)
    } else if (z.auto)
        Click()
}
