; ============================================================================
; lib/diag.ahk  --  Paquete P0: diagnostico (logs, salud, perfilador, OnError)
; ----------------------------------------------------------------------------
; REGLAS DE ESTE MODULO
;  - Aditivo: no cambia el comportamiento del dibujo. Se revierte quitando el
;    #Include y las lineas de integracion (ver INTEGRACION_P0.txt).
;  - SIN codigo de nivel superior: este archivo se incluye al FINAL del script
;    principal, asi que todo el estado vive en _DS() (inicializacion perezosa).
;  - Nada aqui lanza excepciones hacia el llamador ni bloquea (sin Sleep/KeyWait).
;  - Solo ASCII en comentarios y logs (evita problemas de codificacion).
; Config opcional en diag.ini, seccion [diag]:
;   salud_min=5  log_max_kb=2048  errores_max_min=20  prof_activo=1
; ============================================================================

; ---------------------------------------------------------------------------
; Estado interno (init perezoso)
; ---------------------------------------------------------------------------
_DS() {
    static s := 0
    if !IsObject(s) {
        s := {}
        s.dir := A_ScriptDir "\logs"
        s.cfg := A_ScriptDir "\diag.ini"
        s.saludMin := 5
        s.logMaxKB := 2048
        s.erroresMaxMin := 20
        s.profActivo := true
        s.iniciado := false
        s.inicioTick := A_TickCount
        s.errores := 0
        s.errVentana := 0
        s.errEnVentana := 0
        s.errUltClave := ""
        s.errUltTick := 0
        s.bf := 0
        s.muestras := 0
        s.enFoco := 0
        s.prof := Map()
        s.wraps := Map()
    }
    return s
}

_DiagCfg(clave, def) {
    try {
        v := IniRead(_DS().cfg, "diag", clave, def)
        return Integer(v)
    }
    return def
}

_DiagMs() {
    static f := 0
    if !f
        DllCall("QueryPerformanceFrequency", "Int64*", &f)
    c := 0
    DllCall("QueryPerformanceCounter", "Int64*", &c)
    return c * 1000.0 / f
}

_DiagTs() {
    return FormatTime(, "yyyy-MM-dd HH:mm:ss")
}

; ---------------------------------------------------------------------------
; Inicio: lee config y registra OnError. Llamar UNA vez, justo tras la
; auto-elevacion del script principal.
; ---------------------------------------------------------------------------
Diag_Iniciar() {
    s := _DS()
    if s.iniciado
        return
    s.iniciado := true
    try {
        if !DirExist(s.dir)
            DirCreate(s.dir)
    }
    s.saludMin := Max(1, _DiagCfg("salud_min", 5))
    s.logMaxKB := Max(64, _DiagCfg("log_max_kb", 2048))
    s.erroresMaxMin := Max(1, _DiagCfg("errores_max_min", 20))
    s.profActivo := (_DiagCfg("prof_activo", 1) != 0)
    OnError(Diag_OnError, 1)
    prof := s.profActivo ? 1 : 0
    DiagLog("salida.log", _DiagTs() " diag iniciado salud_min=" s.saludMin " prof=" prof)
}

; ---------------------------------------------------------------------------
; Log con rotacion. Nunca lanza.
; ---------------------------------------------------------------------------
DiagLog(archivo, linea, cabecera := "") {
    try {
        s := _DS()
        if !DirExist(s.dir)
            DirCreate(s.dir)
        ruta := s.dir "\" archivo
        if (FileExist(ruta) && FileGetSize(ruta) > s.logMaxKB * 1024) {
            try FileDelete(ruta ".1")
            FileMove(ruta, ruta ".1", 1)
        }
        if (cabecera != "" && !FileExist(ruta))
            FileAppend(cabecera "`n", ruta, "UTF-8-RAW")
        FileAppend(linea "`n", ruta, "UTF-8-RAW")
    }
}

; ---------------------------------------------------------------------------
; OnError global: registra y evita el dialogo modal sobre CSP.
; Nota: confirmar en la doc de la version instalada la semantica exacta del
; valor de retorno (1 = error manejado, sin dialogo).
; ---------------------------------------------------------------------------
Diag_OnError(err, modo) {
    try {
        s := _DS()
        s.errores += 1
        ahora := A_TickCount
        msg := "", que := "", archivo := "", lin := 0, pila := ""
        try msg := err.Message
        try que := err.What
        try archivo := err.File
        try lin := err.Line
        try pila := err.Stack
        clave := msg "|" archivo "|" lin
        repetido := (clave = s.errUltClave && ahora - s.errUltTick < 60000)
        if !repetido {
            s.errUltClave := clave
            s.errUltTick := ahora
            if (ahora - s.errVentana > 60000) {
                s.errVentana := ahora
                s.errEnVentana := 0
            }
            s.errEnVentana += 1
            if (s.errEnVentana <= s.erroresMaxMin) {
                txt := _DiagTs() " [" modo "] " msg " | what=" que " | " archivo ":" lin
                if (pila != "")
                    txt .= "`n    " StrReplace(pila, "`n", "`n    ")
                DiagLog("errores.log", txt)
            }
        }
    }
    return (modo = "ExitApp") ? 0 : 1
}

; ---------------------------------------------------------------------------
; Contador de instancias vivas de BorderFrame (para H8)
; ---------------------------------------------------------------------------
Diag_BFCambio(delta := 0) {
    s := _DS()
    s.bf += delta
    return s.bf
}

; ---------------------------------------------------------------------------
; PERFILADOR (histograma por intervalo; se reinicia en cada fila de salud)
; ---------------------------------------------------------------------------
_ProfRec(nombre, periodo := 0) {
    s := _DS()
    if s.prof.Has(nombre) {
        r := s.prof[nombre]
        if (periodo > 0 && r.periodo = 0)
            r.periodo := periodo
        return r
    }
    r := {nombre: nombre, periodo: periodo, n: 0, maxMs: 0, bins: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], lastStart: 0, retrasos: 0, maxGap: 0}
    s.prof[nombre] := r
    return r
}

_ProfRegistrar(r, ms) {
    static bordes := [0.25, 0.5, 1, 2, 4, 8, 16, 32, 64]
    r.n += 1
    if (ms > r.maxMs)
        r.maxMs := ms
    i := 1
    while (i <= 9 && ms >= bordes[i])
        i += 1
    r.bins[i] += 1
}

_ProfP95(r) {
    static bordes := [0.25, 0.5, 1, 2, 4, 8, 16, 32, 64]
    objetivo := Ceil(r.n * 0.95)
    acum := 0
    Loop 10 {
        acum += r.bins[A_Index]
        if (acum >= objetivo)
            return (A_Index <= 9) ? bordes[A_Index] : r.maxMs
    }
    return r.maxMs
}

; Cuerpo del wrapper de timers: mide intervalo entre inicios y duracion.
_ProfLlamar(r, fn) {
    t0 := _DiagMs()
    if (r.periodo > 0) {
        if (r.lastStart > 0) {
            gap := t0 - r.lastStart
            if (gap <= 3000) {
                if (gap > r.maxGap)
                    r.maxGap := gap
                if (gap > r.periodo * 2 + 30)
                    r.retrasos += 1
            }
        }
        r.lastStart := t0
    }
    try {
        return fn()
    } finally {
        try _ProfRegistrar(r, _DiagMs() - t0)
    }
}

; Envuelve un timer. MISMO wrapper por funcion (memoizado): usarlo en TODOS los
; SetTimer de esa funcion, incluidos los que la apagan (SetTimer(Prof_T(f), 0)).
; Con prof_activo=0 devuelve la funcion original (rollback por config).
Prof_T(fn, periodo := 0) {
    s := _DS()
    if !s.profActivo
        return fn
    if s.wraps.Has(fn) {
        w := s.wraps[fn]
        _ProfRec(w.nombre, periodo)
        return w.f
    }
    nombre := fn.Name
    r := _ProfRec(nombre, periodo)
    w := {nombre: nombre, f: (*) => _ProfLlamar(r, fn)}
    s.wraps[fn] := w
    return w.f
}

; Para funciones llamadas por hotkeys/timers one-shot: la funcion publica pasa a
; ser un envoltorio fino que llama a Prof_Llamar("nombre", _Impl).
Prof_Llamar(nombre, fn, args*) {
    t0 := _DiagMs()
    try {
        return fn(args*)
    } finally {
        Prof_Fin(nombre, t0)
    }
}

Prof_Ini(nombre := "") {
    return _DiagMs()
}

Prof_Fin(nombre, t0) {
    try {
        if !_DS().profActivo
            return
        _ProfRegistrar(_ProfRec(nombre), _DiagMs() - t0)
    }
}

; Devuelve {txt, retrasos, gapMax} del intervalo y reinicia contadores.
_ProfResumen() {
    s := _DS()
    lista := []
    ret := 0
    gapMax := 0
    for nombre, r in s.prof {
        ret += r.retrasos
        if (r.maxGap > gapMax)
            gapMax := r.maxGap
        if (r.n > 0)
            lista.Push({nombre: nombre, p95: _ProfP95(r), maxMs: r.maxMs, n: r.n})
    }
    Loop lista.Length - 1 {
        i := A_Index + 1
        x := lista[i]
        j := i - 1
        while (j >= 1 && (lista[j].p95 < x.p95 || (lista[j].p95 = x.p95 && lista[j].maxMs < x.maxMs))) {
            lista[j + 1] := lista[j]
            j -= 1
        }
        lista[j + 1] := x
    }
    txt := ""
    for i, it in lista {
        if (i > 5)
            break
        sep := (txt = "") ? "" : ";"
        txt .= sep it.nombre "=" Round(it.p95, 2) "/" Round(it.maxMs, 2) "(n" it.n ")"
    }
    for nombre, r in s.prof {
        r.n := 0
        r.maxMs := 0
        r.retrasos := 0
        r.maxGap := 0
        r.bins := [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    }
    return {txt: txt, retrasos: ret, gapMax: Round(gapMax)}
}

; ---------------------------------------------------------------------------
; SALUD: una fila CSV cada salud_min minutos (+ fila a los 10 s y al salir)
; ---------------------------------------------------------------------------
Salud_Iniciar() {
    s := _DS()
    SetTimer(_Salud_Tick, s.saludMin * 60000)
    SetTimer(_Salud_Muestreo, 1000)
    SetTimer(_Salud_Primera, -10000)
}

_Salud_Tick() {
    Salud_Fila("periodico")
}

_Salud_Primera() {
    Salud_Fila("inicio")
}

_Salud_Muestreo() {
    s := _DS()
    s.muestras += 1
    try {
        if WinActive("ahk_exe CLIPStudioPaint.exe")
            s.enFoco += 1
    }
}

_DiagWorkingSetMB(h) {
    tam := (A_PtrSize = 8) ? 72 : 40
    b := Buffer(tam, 0)
    NumPut("UInt", tam, b, 0)
    if !DllCall("kernel32\K32GetProcessMemoryInfo", "Ptr", h, "Ptr", b, "UInt", tam, "Int")
        return -1
    off := (A_PtrSize = 8) ? 16 : 12
    return Round(NumGet(b, off, "UPtr") / 1048576, 1)
}

_DiagVentanasPropias() {
    prev := A_DetectHiddenWindows
    n := -1
    DetectHiddenWindows(true)
    try n := WinGetList("ahk_pid " DllCall("GetCurrentProcessId")).Length
    DetectHiddenWindows(prev)
    return n
}

Salud_Fila(motivo := "") {
    try {
        s := _DS()
        h := DllCall("GetCurrentProcess", "Ptr")
        gdi := DllCall("user32\GetGuiResources", "Ptr", h, "UInt", 0, "UInt")
        usr := DllCall("user32\GetGuiResources", "Ptr", h, "UInt", 1, "UInt")
        ws := _DiagWorkingSetMB(h)
        ven := _DiagVentanasPropias()
        pidCsp := ProcessExist("CLIPStudioPaint.exe")
        foco := s.muestras ? Round(100 * s.enFoco / s.muestras) : 0
        s.muestras := 0
        s.enFoco := 0
        res := _ProfResumen()
        minAct := Round((A_TickCount - s.inicioTick) / 60000, 1)
        linea := _DiagTs() "," minAct "," pidCsp "," gdi "," usr "," ws "," ven "," s.bf "," s.errores "," foco "," res.retrasos "," res.gapMax "," res.txt "," motivo
        DiagLog("salud.csv", linea, "ts,min_activo,pid_csp,gdi,user,ws_mb,ventanas,bf_vivos,errores,foco_pct,retrasos,gap_max_ms,prof,motivo")
    }
}
