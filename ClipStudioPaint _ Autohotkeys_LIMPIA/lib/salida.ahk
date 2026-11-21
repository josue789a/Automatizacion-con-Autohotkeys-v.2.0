#Requires AutoHotkey v2.0
; ============================================================================
; lib/salida.ahk  --  Paquete P0: sesion, restauracion de paneles y salida
; ----------------------------------------------------------------------------
; REGLAS DE ESTE MODULO:
;  - Aditivo: restaura paneles de CSP (alpha 5 / click-through) al arrancar y salir.
;  - Sin codigo libre de nivel superior: inicializacion controlada via funciones.
;  - Todo corre en try/finally sin bloquear ni lanzar excepciones no controladas.
;  - Orquestador unico OnExit con prioridad numerica estricta.
; ============================================================================

_Sesion() {
    static s := 0
    if !IsObject(s)
        s := {arranqueSucio: false, pid: 0, iniPath: A_ScriptDir "\logs\sesion.ini"}
    return s
}

global sesion := _Sesion()

_SalidaFases() {
    static fases := []
    return fases
}

; ---------------------------------------------------------------------------
; Sesion_Iniciar: detecta si la sesion anterior termino de forma anormal
; ---------------------------------------------------------------------------
Sesion_Iniciar() {
    s := _Sesion()
    try {
        logsDir := A_ScriptDir "\logs"
        if !DirExist(logsDir)
            DirCreate(logsDir)
        
        ini := s.iniPath
        limpioPrevio := IniRead(ini, "sesion", "limpio", "1")
        pidPrevio := IniRead(ini, "sesion", "pid", "0")
        inicioPrevio := IniRead(ini, "sesion", "inicio", "")
        
        s.arranqueSucio := (limpioPrevio = "0")
        s.pid := DllCall("GetCurrentProcessId", "UInt")
        
        tsActual := IsSet(_DiagTs) ? _DiagTs() : FormatTime(, "yyyy-MM-dd HH:mm:ss")
        IniWrite("0", ini, "sesion", "limpio")
        IniWrite(String(s.pid), ini, "sesion", "pid")
        IniWrite(tsActual, ini, "sesion", "inicio")
        
        if (s.arranqueSucio) {
            msg := "[Sesion] Arranque tras caida o cierre abrupto previo (PID=" pidPrevio " inicio=" inicioPrevio ")"
            if IsSet(DiagLog)
                DiagLog("salida.log", tsActual " " msg)
        }
    }
    return s.arranqueSucio
}

; ---------------------------------------------------------------------------
; RestaurarPanelesCSP: barre ventanas de CSP con alpha 5 y click-through (+0x20)
; y las devuelve a estado visible interactivo (alpha 255, -0x20).
; ---------------------------------------------------------------------------
RestaurarPanelesCSP() {
    restaurados := 0
    prevDH := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    try {
        ts := IsSet(_DiagTs) ? _DiagTs() : FormatTime(, "yyyy-MM-dd HH:mm:ss")
        for hwnd in WinGetList("ahk_exe CLIPStudioPaint.exe") {
            key := 0, alpha := 0, flags := 0
            ; LWA_ALPHA = 0x2
            ok := DllCall("user32\GetLayeredWindowAttributes", "Ptr", hwnd, "UInt*", &key, "UChar*", &alpha, "UInt*", &flags, "Int")
            if (ok && (flags & 0x2) && (alpha = 5)) {
                try WinSetTransparent(255, "ahk_id " hwnd)
                try WinSetExStyle("-0x20", "ahk_id " hwnd)
                tit := ""
                try tit := WinGetTitle("ahk_id " hwnd)
                if IsSet(DiagLog)
                    DiagLog("salida.log", ts " [Paneles] Restaurado hwnd=" hwnd " '" tit "'")
                restaurados++
            }
        }
    } finally {
        DetectHiddenWindows(prevDH)
    }
    return restaurados
}

; ---------------------------------------------------------------------------
; Salida_Registrar: registra una fase de cierre con prioridad numerica
; Menor numero = mayor prioridad (ej: paneles=10, mods=20, audio=50, gdip=90)
; ---------------------------------------------------------------------------
Salida_Registrar(nombre, prioridad, fn) {
    fases := _SalidaFases()
    ; Evitar duplicados por nombre
    for i, it in fases {
        if (it.nombre = nombre) {
            fases[i] := {nombre: nombre, prioridad: prioridad, fn: fn}
            return
        }
    }
    fases.Push({nombre: nombre, prioridad: prioridad, fn: fn})
    
    ; Ordenar de menor a mayor prioridad
    Loop fases.Length - 1 {
        i := A_Index
        loop fases.Length - i {
            j := i + A_Index
            if (fases[j].prioridad < fases[i].prioridad) {
                tmp := fases[i]
                fases[i] := fases[j]
                fases[j] := tmp
            }
        }
    }
}

; ---------------------------------------------------------------------------
; Salir: Orquestador unico de OnExit.
; Bloquea interrupciones (Critical), ejecuta fases en orden y garantiza retorno 0.
; ---------------------------------------------------------------------------
Salir(motivo := "desconocido", codigo := 0) {
    Critical("On")
    static saliendo := false
    if saliendo
        return 0
    saliendo := true
    
    global sesion
    t0 := IsSet(_DiagMs) ? _DiagMs() : 0
    ts := IsSet(_DiagTs) ? _DiagTs() : FormatTime(, "yyyy-MM-dd HH:mm:ss")
    
    if IsSet(DiagLog)
        DiagLog("salida.log", ts " [Salir] Inicio de cierre motivo=" motivo " codigo=" codigo)
        
    fases := _SalidaFases()
    for it in fases {
        tFase := IsSet(_DiagMs) ? _DiagMs() : 0
        try {
            fnFase := it.fn
            (fnFase.MaxParams = 0) ? fnFase() : fnFase(motivo, codigo)
            durFase := IsSet(_DiagMs) ? Round(_DiagMs() - tFase, 2) : 0
            if IsSet(DiagLog)
                DiagLog("salida.log", ts "   -> Fase [" it.nombre "] pri=" it.prioridad " ok (" durFase " ms)")
        } catch as err {
            durFase := IsSet(_DiagMs) ? Round(_DiagMs() - tFase, 2) : 0
            if IsSet(DiagLog)
                DiagLog("salida.log", ts "   -> Fase [" it.nombre "] ERROR: " err.Message " (" durFase " ms)")
        }
    }
    
    ; Marcar sesion limpia en ini
    try {
        s := _Sesion()
        IniWrite("1", s.iniPath, "sesion", "limpio")
    }
    
    durTotal := IsSet(_DiagMs) ? Round(_DiagMs() - t0, 2) : 0
    if IsSet(DiagLog)
        DiagLog("salida.log", ts " [Salir] Cierre finalizado con exito (" durTotal " ms)")
        
    return 0
}
