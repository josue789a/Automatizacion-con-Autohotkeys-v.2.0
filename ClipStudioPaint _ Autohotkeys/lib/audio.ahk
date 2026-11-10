#Requires AutoHotkey v2.0
; [LIB] audio — motor háptico unificado (Ola 1)
; Cero pitidos de BIOS, cero alertas de Windows. Micro-tonos RAM y WAVs locales precargados.

_SonarUI(evento, val := 0) {
    if !_AudActivo()
        return
    if (_SonarFast(evento))              ; ruta RAM de latencia cero (pluma, aerógrafo, colores, shift)
        return
    switch evento {
        case "slider":
            _HapticoSlider(val)
        case "borrador", "lazo", "pincel", "reload":
            _SonarWav("alpha_loud", [900, 700, 18])
        case "relleno":
            _SonarWav("fill_loud", [640, 480, 22])
        case "guardar", "layout", "sync":
            _SonarWav("alpha_short", [1000, 1400, 24])
        case "enfoque_on", "color":
            _AudTonoRAM("t_on", 760, 860, 20)
        case "enfoque_off":
            _AudTonoRAM("t_off", 620, 520, 20)
        case "copiar", "flip", "calib":
            _AudTonoRAM("t_tick", 680, 720, 14)
        case "seleccion":
            _AudTonoRAM("t_sel", 580, 640, 16)
        default:
            return
    }
}

; WAV precargado en RAM; si falta el archivo, cae a un tono RAM [f0,f1,ms]. Sin sonidos de Windows.
_SonarWav(nombreWav, fb := "") {
    buf := _AudWavBuf(nombreWav)
    if (buf) {
        _AudPlay(buf)
        return
    }
    if IsObject(fb)
        _AudTonoRAM("fb_" nombreWav, fb[1], fb[2], fb[3])
}

_BeepEstabAlta() => _SonarUI("slider", 100)
_BeepEstabBaja() => _SonarUI("slider", 0)

; ── Micro-tonos en RAM: winmm\PlaySoundW con SND_MEMORY | SND_ASYNC | SND_NODEFAULT ──
_SonarFast(evento) {
    static perfil := Map(
        ; evento           [Hz inicio, Hz fin, ms, vol]
        "pluma",           [1400, 1750, 48, 0.85],   ; Q: plumilla tinta  → agudo claro
        "aerografo",       [ 550,  420, 56, 0.85],   ; W: aerógrafo       → grave definido
        "color_primario",  [ 950, 1250, 42, 0.80],   ; color frontal      → corto ascendente
        "color_secundario",[ 800,  620, 42, 0.80],   ; color alterno      → descendente
        "shift_on",        [ 850, 1150, 48, 0.80],
        "shift_off",       [1150,  850, 48, 0.80]
    )
    if (!perfil.Has(evento))
        return false                       ; no es mío: lo atiende _SonarUI original (WAVs alpha_loud/fill_loud/alpha_short)
    p := perfil[evento]
    _AudPlay(_AudTonoBuf("fast_" evento, p[1], p[2], p[3], (p.Length >= 4 ? p[4] : 0.85)))
    return true
}

_CrearTonoRAM(f0, f1, ms, vol := 0.85) {
    ; PCM 44100 Hz / 16-bit / ESTÉREO (mismo formato que alpha_loud.wav) + pre/post-roll de silencio
    static PREROLL_MS := 40, POSTROLL_MS := 80     ; ajustables: el driver "despierta" durante el pre-roll
    sr := 44100, pi := 3.14159265358979
    lead := Integer(sr * PREROLL_MS / 1000)
    n    := Integer(sr * ms / 1000)
    tail := Integer(sr * POSTROLL_MS / 1000)
    total := lead + n + tail
    dBytes := total * 4                           ; 2 canales x 2 bytes
    buf := Buffer(44 + dBytes, 0)                 ; Buffer en cero = silencio en pre/post-roll
    NumPut("UInt", 0x46464952, buf, 0)            ; "RIFF"
    NumPut("UInt", 36 + dBytes, buf, 4)
    NumPut("UInt", 0x45564157, buf, 8)            ; "WAVE"
    NumPut("UInt", 0x20746D66, buf, 12)           ; "fmt "
    NumPut("UInt", 16, buf, 16)
    NumPut("UShort", 1, buf, 20)                  ; PCM
    NumPut("UShort", 2, buf, 22)                  ; estéreo
    NumPut("UInt", sr, buf, 24)                   ; 44100
    NumPut("UInt", sr * 4, buf, 28)               ; ByteRate 176400
    NumPut("UShort", 4, buf, 32)                  ; BlockAlign
    NumPut("UShort", 16, buf, 34)
    NumPut("UInt", 0x61746164, buf, 36)           ; "data"
    NumPut("UInt", dBytes, buf, 40)
    a := Max(1, Min(n // 6, Integer(sr * 0.004))) ; ataque/release de 4 ms, el resto plano
    phase := 0.0
    loop n {
        i := A_Index - 1
        f := f0 + (f1 - f0) * i / n
        phase += 2 * pi * f / sr
        env := (i < a) ? i / a : (i >= n - a) ? (n - i) / a : 1.0
        s := Round(Sin(phase) * env * vol * 32767)
        p := 44 + (lead + i) * 4
        NumPut("Short", s, buf, p)                ; L
        NumPut("Short", s, buf, p + 2)            ; R
    }
    return buf
}

; === AUDIO-HAPTICO-BEGIN ===
_AudCache() {
    static c := Map()
    return c
}
_AudActivo() => (_Tema("audio","enabled","1") != "0")
_AudVol() {
    v := _Tema("audio","volume","100")
    return IsInteger(v) ? Max(0,Min(100,Integer(v))) / 100 : 1.0
}
; SND_ASYNC(1)|SND_NODEFAULT(2)|SND_MEMORY(4): sin hilos, sin cola, un sonido reemplaza al anterior
_AudPlay(buf) {
    if (!IsObject(buf) || buf.Size < 44)
        return
    try DllCall("winmm\PlaySoundW","Ptr",buf,"Ptr",0,"UInt",0x0007)
}

_AudTonoBuf(id, f0, f1, ms, vol := 0.50) {
    c := _AudCache()
    if !c.Has(id)
        c[id] := _CrearTonoRAM(f0, f1, ms, vol * _AudVol())
    return c[id]
}
_AudTonoRAM(id, f0, f1, ms, vol := 0.50) => _AudPlay(_AudTonoBuf(id, f0, f1, ms, vol))

_AudWavBuf(nombre) {
    c := _AudCache()
    k := "wav:" nombre
    if c.Has(k)
        return c[k]
    ruta := A_ScriptDir "\sonidos\" nombre ".wav"
    buf := 0
    if FileExist(ruta) {
        try {
            buf := FileRead(ruta, "RAW")
            _AudEscalarWav(buf, _AudVol())
        } catch
            buf := 0
    }
    c[k] := buf          ; caché negativa: si falta, no se reintenta el disco
    return buf
}
_AudEscalarWav(buf, vol) {
    if (vol >= 0.995 || buf.Size < 44)
        return
    if (NumGet(buf,0,"UInt") != 0x46464952 || NumGet(buf,8,"UInt") != 0x45564157)
        return
    pos := 12, bits := 0, tag := 0
    while (pos + 8 <= buf.Size) {
        id := NumGet(buf,pos,"UInt")
        sz := NumGet(buf,pos + 4,"UInt")
        if (id = 0x20746D66) {
            tag := NumGet(buf,pos + 8,"UShort")
            bits := NumGet(buf,pos + 22,"UShort")
        } else if (id = 0x61746164) {
            if (tag != 1 || bits != 16)
                return
            n := Min(sz, buf.Size - pos - 8) // 2
            p := pos + 8
            loop n {
                NumPut("Short", Round(NumGet(buf,p,"Short") * vol), buf, p)
                p += 2
            }
            return
        }
        pos += 8 + sz + (sz & 1)
    }
}

_SliderBuf(banda) {
    f := 650 + banda * 20                          ; ~750 Hz de centro, seco y ultracorto
    return _AudTonoBuf("hap_sl_" banda, f, f, 7, 0.24)
}
_HapticoSlider(v) {
    static ultV := -999, ultSnd := 0, ultCall := 0
    if !_AudActivo()
        return
    ahora := A_TickCount
    if (ahora - ultCall > 300)                     ; arrastre nuevo: el primer clic siempre suena
        ultV := -999
    ultCall := ahora
    if (Abs(v - ultV) < 3 || ahora - ultSnd < 12)  ; cada 3 unidades y mínimo 12 ms
        return
    ultV := v
    ultSnd := ahora
    _AudPlay(_SliderBuf(Min(10, Integer(v) // 10)))
}

_RachaBuf(clave, nivel) {
    static r := [1.0, 1.125, 1.25, 1.5, 1.667]     ; pentatónica mayor
    idx := Max(0, Min(4, Integer(nivel)))
    f := Round((clave = "redo" ? 760 : 520) * r[idx + 1])
    return _AudTonoBuf("rch_" clave "_" idx, f, Round(f * 1.05), 16, 0.22)
}
_HapticoRacha(clave) {
    static nivel := Map("undo",0,"redo",0), ult := Map("undo",0,"redo",0), ultSnd := Map("undo",0,"redo",0)
    try {
        if !_AudActivo()
            return
        ahora := A_TickCount
        if (ahora - ultSnd[clave] < 20)                 ; blindaje: mínimo 20 ms entre sonidos para no saturar WinMM
            return
        ultSnd[clave] := ahora
        gap := ahora - ult[clave]
        if (gap < 400 && ult[clave] > 0)
            nivel[clave] := Min(4, Integer(nivel[clave]) + 1)
        else                                           ; reseteo suave: un nivel por cada 500 ms de pausa
            nivel[clave] := Max(0, Integer(nivel[clave]) - ((gap - 400) // 500 + 1))
        ult[clave] := ahora
        idx := Max(0, Min(4, Integer(nivel[clave])))
        _AudPlay(_RachaBuf(clave, idx))
    }
}

_AudPrecargar() {
    Loop 11
        _SliderBuf(A_Index - 1)
    for clave in ["undo","redo"] {
        Loop 5
            _RachaBuf(clave, A_Index - 1)
    }
    for nombre in ["alpha_loud","alpha_short","fill_loud","recycle_loud"]
        _AudWavBuf(nombre)
}

_GdipRes() {
    static r := {fam:0, fnt:0, fmt:0, tam:0, tok:0}
    return r
}
_GdipLiberarFuentes() {
    gr := _GdipRes()
    if gr.fnt
        DllCall("gdiplus\GdipDeleteFont","ptr",gr.fnt,"int")
    if gr.fmt
        DllCall("gdiplus\GdipDeleteStringFormat","ptr",gr.fmt,"int")
    if gr.fam
        DllCall("gdiplus\GdipDeleteFontFamily","ptr",gr.fam,"int")
    gr.fnt := 0, gr.fmt := 0, gr.fam := 0, gr.tam := 0
}
_AudReiniciar() {
    try {
        _AudCache().Clear()
        _AudPrecargar()
        DllCall("winmm\waveOutGetNumDevs", "UInt")
    }
}
_AudAlSalir(*) {
    DllCall("winmm\PlaySoundW","Ptr",0,"Ptr",0,"UInt",0)   ; corta el sonido antes de liberar buffers
    _GdipLiberarFuentes()
    gr := _GdipRes()
    if gr.tok {
        DllCall("gdiplus\GdiplusShutdown","ptr",gr.tok)
        gr.tok := 0
    }
}
; === AUDIO-HAPTICO-END ===
