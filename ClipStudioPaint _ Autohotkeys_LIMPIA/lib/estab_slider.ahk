#Requires AutoHotkey v2.0
; [LIB] estab_slider.ahk — fuente: XPPEN AHK VERSION ESTABLE.ahk L3488–4098, L5717–5869, L6059–6118
IniciarEstabGUI() {
    global PERFIL,panelBlk,ESTAB_ALPHA_H,ESTAB_ALPHA_F
    ini := _PosGuiIniPath()
    v := IniRead(ini,"Estab_p" PERFIL,"valor","")
    estabGui.valor := (IsInteger(v) && Integer(v) >= 0 && Integer(v) <= 100) ? Integer(v) : 50
    estabGui.previsto := estabGui.valor
    pidGuardado := IniRead(ini,"Estab_p" PERFIL,"pid","")
    pidCSP := ProcessExist("CLIPStudioPaint.exe")
    estabGui.sincronizado := (pidCSP && pidGuardado != "" && String(pidCSP) = pidGuardado)
    estabGui.visible := (IniRead(ini,"Estab_p" PERFIL,"visible","1") = "1")
    estabGui.arrastrando := false
    a := IniRead(ini,"Estab_p" PERFIL,"alphaH","")
    if (IsInteger(a) && Integer(a) >= 10 && Integer(a) <= 100)
        ESTAB_ALPHA_H := Round(Integer(a) * 2.55)
    a := IniRead(ini,"Estab_p" PERFIL,"alphaF","")
    if (IsInteger(a) && Integer(a) >= 10 && Integer(a) <= 100)
        ESTAB_ALPHA_F := Round(Integer(a) * 2.55)
    r := _EstabRectGuardada()
    if IsObject(r) {
        w := r.w
        h := r.h
        px := r.x
        py := r.y
    } else {
        mon0 := ObtenerMonitorCSP()
        w := _E(420)
        h := _E(44)
        posE := LeerPosicionGUI("Estab")
        if (IsObject(posE) && _PosicionValidaEnPantalla(posE.x,posE.y)) {
            px := posE.x
            py := posE.y
        } else {
            px := mon0.x + (mon0.w - w) // 2
            py := mon0.y + Round(mon0.h * 0.14)
        }
    }
    mon := _EstabMonitorEn(px + w // 2,py + h // 2)
    w := Max(14,Min(w,mon.w))
    h := Max(14,Min(h,mon.h))
    px := Max(mon.x,Min(px,mon.x + mon.w - w))
    py := Max(mon.y,Min(py,mon.y + mon.h - h))
    _EstabCalcular(w,h)
    estabGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000 -DPIScale","")
    estabGui.g.BackColor := panelBlk.locked ? _Tema("color","surface.estabLocked","2B2B2B") : _Tema("color","surface.estabOpen","3A4260")
    estabGui.g.MarginX := 0
    estabGui.g.MarginY := 0
    _EstabSoloLineaCargar()
    _EstabAlpha(false)
    ; track + relleno + knob: una sola capa pintada por GDI+ sobre el cliente del panel
    _EstabGdipIniciar()
    estabGui.valorTxt := estabGui.g.Add("Text","x0 y0 w" w " h" estabGui.txtH " Center +0x200 c" ESTAB_COLOR,"")
    estabGui.valorTxt.SetFont("s" estabGui.fuente " bold",_TemaFuente("valor"))
    estabGui.grip := estabGui.g.Add("Text","x" Max(0,w - _E(15)) " y" (h - _E(15)) " w" _E(15) " h" _E(15) " Right +0x200 BackgroundTrans c" _Tema("color","track.pillOff","6A6A6A"),"◢")
    estabGui.grip.SetFont("s" Max(7,Round(9 * ESC)),"Segoe UI")
    estabGui.grip.Visible := !panelBlk.locked
    estabGui.ultimoDibujo := 0
    estabGui.syncPendiente := false
    try estabGui.g.OnEvent("ContextMenu", (*) => _EstabSoloLineaAlternar())
    OnMessage(0x0201,_EstabGUI_WM_LBUTTONDOWN)
    OnMessage(0x0204,_EstabGUI_WM_RBUTTONDOWN)
    OnMessage(0x0207,_EstabGUI_WM_MBUTTONDOWN)
    HotIf(_EstabZonaRueda)
    try Hotkey("WheelUp",_EstabWheelUp,"On")
    try Hotkey("WheelDown",_EstabWheelDown,"On")
    HotIf(_EstabCSPActivo)
    try Hotkey("~j",_EstabTeclaJ,"On")
    try Hotkey("~-",_EstabTeclaMenos,"On")
    try Hotkey("~LButton",_EstabInvalidarConfianza,"On")
    HotIf(_EstabShiftEActivo)
    try Hotkey("$+e",_EstabFocoTecla,"On")
    try Hotkey("$#+e",_EstabFocoTecla,"On")   ; Win fantasma: no se escapa al SO
    HotIf()
    try Hotkey("~*e up",_EstabTeclaMenosUp,"On")
    try Hotkey("~*Shift up",_EstabTeclaMenosUp,"On")
    HotIf()
    estabGui.g.Show("x" px " y" py " w" w " h" h " NoActivate")
    if (!estabGui.visible || !enfoque.activo)
        estabGui.g.Hide()
    _EstabRegion(w,h)
    _DwmRedondear(estabGui.g.Hwnd)
    _EstabLayout(w,h)
    ActualizarEstabBtnGUI()
}
_EstabMonitorEn(x,y) {
    Loop MonitorGetCount() {
        MonitorGet(A_Index,&mL,&mT,&mR,&mB)
        if (x >= mL && x < mR && y >= mT && y < mB)
            return {x:mL,y:mT,w:mR - mL,h:mB - mT}
    }
    return ObtenerMonitorCSP()
}
_EstabTamanoValido(w,h) => (Min(w,h) >= 14 && Max(w,h) >= 60)
_EstabAlpha(activo := false) {
    global estabSoloLinea
    if !IsObject(estabGui.g)
        return
    if estabGui.foco
        a := activo ? ESTAB_ALPHA_ACT : ESTAB_ALPHA_F
    else
        a := estabGui.horiz ? (activo ? ESTAB_ALPHA_ACT : ESTAB_ALPHA_H) : 235
    if (IsSet(estabSoloLinea) && estabSoloLinea) {
        estabGui.alphaSolo := a
        _EstabDibujar()
    } else {
        try WinSetTransparent(a,"ahk_id " estabGui.g.Hwnd)
    }
}
_EstabCalcular(w,h) {
    estabGui.ancho := w
    estabGui.alto := h
    estabGui.horiz := (w > h)
    if estabGui.horiz {
        estabGui.knobSize := Max(12,Round(h * 0.86))
        ; Mismo criterio que en vertical: si el knob da para la cifra dentro
        ; (>= 30 px), no se reserva franja lateral y el texto de apoyo se apaga
        ; para no duplicar el numero. Si el knob es pequeño, se usa el lateral.
        estabGui.txtW := (estabGui.knobSize >= 30) ? 0 : Max(34,Round(h * 1.4))
        if IsObject(estabGui.valorTxt)
            estabGui.valorTxt.Visible := (estabGui.txtW > 0)
        estabGui.txtH := h
        estabGui.trackH := Max(6,Round(h * 0.46))
        estabGui.trackY := Round((h - estabGui.trackH) / 2)
        k := Round(estabGui.knobSize / 2)
        estabGui.trackX := k + 3
        estabGui.trackW := Max(20,w - estabGui.txtW - estabGui.trackX - k - 3)
        estabGui.fuente := Max(8,Round(h * 0.30))
    } else {
        dentro := (w >= 30)
        estabGui.txtH := 0
        estabGui.txtW := w
        estabGui.knobSize := dentro ? 36 : Max(30,Round(w * 1.15))
        if IsObject(estabGui.valorTxt)
            estabGui.valorTxt.Visible := false
        k := Round(estabGui.knobSize / 2)
        estabGui.trackW := Max(6,Round(w * 0.22))
        estabGui.trackX := Round((w - estabGui.trackW) / 2)
        estabGui.trackY := Max(k + 3,Round(h * 0.03))
        estabGui.trackH := Max(24,h - estabGui.txtH - 2 * estabGui.trackY)
        estabGui.fuente := Max(7,Round(w * 0.26))
    }
}
_EstabLayout(w,h) {
    _EstabCalcular(w,h)
    if !IsObject(estabGui.valorTxt)
        return
    try {
        estabGui.valorTxt.SetFont("s" estabGui.fuente " bold",_TemaFuente("valor"))
        if estabGui.horiz {
            if (estabGui.txtW > 0)
                estabGui.valorTxt.Move(w - estabGui.txtW,0,estabGui.txtW,h)
        } else
            estabGui.valorTxt.Move(0,h - estabGui.txtH,w,estabGui.txtH)
        estabGui.grip.Move(Max(0,w - _E(15)),h - _E(15),_E(15),_E(15))
        estabGui.grip.Visible := (!panelBlk.locked && !estabGui.foco)
    }
    _EstabAlpha(false)
    ActualizarEstabGUI(-1,true)
}
_EstabRegion(w,h) {
    if !IsObject(estabGui.g)
        return
    try {
        rad := Max(6,Round(Min(w,h) * 0.50))
        rgn := DllCall("Gdi32\CreateRoundRectRgn","int",0,"int",0,"int",w + 1,"int",h + 1,"int",rad,"int",rad,"Ptr")
        DllCall("SetWindowRgn","Ptr",estabGui.g.Hwnd,"Ptr",rgn,"int",1)
    }
}
ActualizarEstabGUI(v := -1,forzar := false) {
    if !IsObject(estabGui.g)
        return
    if (v < 0)
        v := estabGui.valor
    sig := estabGui.ancho "x" estabGui.alto "x" estabGui.horiz "x" panelBlk.locked "x" _Tema("color","accent.estab","") "x" (HasProp(estabGui,"estabTrackOn") ? estabGui.estabTrackOn : "")
    if (!forzar && v = estabGui.dibV && sig = estabGui.dibG)
        return
    try {
        estabGui.valorTxt.Value := String(v)
        estabGui.dibV := v
        estabGui.dibG := sig
        _EstabDibujar()
        if !estabGui.arrastrando
            ActualizarEstabBtnGUI()
    }
}
_EstabCSPActivo(*) => WinActive("ahk_exe CLIPStudioPaint.exe")
_EstabShiftEActivo(*) => WinActive("ahk_exe CLIPStudioPaint.exe") && !GetKeyState("Space")
_EstabZonaRueda(*) => _EstabCSPActivo() && _EstabBajoMouse()
_EstabBajoMouse() {
    if !IsObject(estabGui.g) || !DllCall("IsWindowVisible","Ptr",estabGui.g.Hwnd)
        return false
    MouseGetPos(&mx,&my)
    rc := Buffer(16,0)
    DllCall("GetWindowRect","Ptr",estabGui.g.Hwnd,"Ptr",rc)
    return (mx >= NumGet(rc,0,"int") && mx <= NumGet(rc,8,"int") && my >= NumGet(rc,4,"int") && my <= NumGet(rc,12,"int"))
}
_EstabWheelUp(*) {
    _EstabAplicarValor(estabGui.valor + 5)
    _SonarUI("slider", estabGui.valor)
    MostrarHUD("ESTABILIZACIÓN " estabGui.valor,"9A7BFF",600)
}
_EstabWheelDown(*) {
    _EstabAplicarValor(estabGui.valor - 5)
    _SonarUI("slider", estabGui.valor)
    MostrarHUD("ESTABILIZACIÓN " estabGui.valor,"9A7BFF",600)
}
_EstabTeclaJ() => _EstabTeclaLocal(-1)
_EstabTeclaMenos() => _EstabTeclaLocal(1)
_EstabFocoCond(*) => enfoque.activo && WinActive("ahk_exe CLIPStudioPaint.exe")
_EstabFocoTecla(*) {
    _LiberarFantasmas()   ; suelta Win/Space/Ctrl/Alt anclados antes de actuar
    ; K3 = macro del driver (Shift down, E, E up, Shift up): su Shift up suelta el Shift anclado.
    ; Reafirmar de forma diferida y sin bloquear el hilo (activo=false => no hace nada).
    if (shiftSostenido.activo) {
        _reafShift := () => shiftSostenido.activo && !GetKeyState("LShift") && SendEvent("{LShift down}")
        SetTimer(_reafShift, -90)
        SetTimer(() => _reafShift(), -220)
    }
    if (estabGui.foco && !estabGui.fAbajo) {
        _EstabFocoOcultar()
        return
    }
    _EstabFocoMostrar()
}
_EstabTeclaMenosUp(*) {
    if !estabGui.foco
        return
    estabGui.fAbajo := false
    estabGui.fSoltado := A_TickCount
}
_EstabFocoRect() {
    global PERFIL
    ini := _PosGuiIniPath()
    sec := "Estab_p" PERFIL
    x := IniRead(ini,sec,"fx","")
    y := IniRead(ini,sec,"fy","")
    w := IniRead(ini,sec,"fw","")
    h := IniRead(ini,sec,"fh","")
    if (IsInteger(x) && IsInteger(y) && IsInteger(w) && IsInteger(h)) {
        if (_EstabTamanoValido(Integer(w),Integer(h)) && _PosicionValidaEnPantalla(Integer(x),Integer(y)))
            return {x:Integer(x),y:Integer(y),w:Integer(w),h:Integer(h)}
    }
    mon := ObtenerMonitorCSP()
    w := Min(mon.w - 40,Round(mon.w * 0.45))
    h := _E(64)
    return {x:mon.x + (mon.w - w) // 2,y:mon.y + mon.h - h - Round(mon.h * 0.10),w:w,h:h}
}
_EstabFocoGuardarRect(x,y,w,h) {
    global PERFIL
    ini := _PosGuiIniPath()
    sec := "Estab_p" PERFIL
    IniWrite(x,ini,sec,"fx")
    IniWrite(y,ini,sec,"fy")
    IniWrite(w,ini,sec,"fw")
    IniWrite(h,ini,sec,"fh")
}
_EstabFocoMostrar() {
    if !IsObject(estabGui.g)
        return
    estabGui.fAbajo := true
    estabGui.fTick := A_TickCount
    estabGui.fPrevHasta := 0
    if estabGui.foco
        return
    rc := Buffer(16,0)
    DllCall("GetWindowRect","Ptr",estabGui.g.Hwnd,"Ptr",rc)
    nx := NumGet(rc,0,"int")
    ny := NumGet(rc,4,"int")
    estabGui.rectNormal := {x:nx,y:ny,w:NumGet(rc,8,"int") - nx,h:NumGet(rc,12,"int") - ny}
    r := _EstabFocoRect()
    estabGui.foco := true
    DllCall("SetWindowPos","Ptr",estabGui.g.Hwnd,"Ptr",-1,"int",r.x,"int",r.y,"int",r.w,"int",r.h,"uint",0x0010)
    _EstabRegion(r.w,r.h)
    _EstabLayout(r.w,r.h)
    if !DllCall("IsWindowVisible","Ptr",estabGui.g.Hwnd)
        estabGui.g.Show("NoActivate")
    _EstabDibujar()
    _EstabAlpha(false)
    SetTimer(_EstabFocoVigilar,10)  ; Reducir agresivamente a 10ms para máxima reactividad
}
_EstabFocoOcultar(*) {
    if !estabGui.foco
        return
    SetTimer(_EstabFocoVigilar,0)
    estabGui.foco := false
    estabGui.fAbajo := false
    estabGui.fPrevHasta := 0
    if !IsObject(estabGui.g)
        return
    r := estabGui.rectNormal
    if IsObject(r) {
        DllCall("SetWindowPos","Ptr",estabGui.g.Hwnd,"Ptr",0,"int",r.x,"int",r.y,"int",r.w,"int",r.h,"uint",0x0004 | 0x0010)
        _EstabRegion(r.w,r.h)
        _EstabLayout(r.w,r.h)
    }
    if (!enfoque.activo || !estabGui.visible)
        estabGui.g.Hide()
    else
        _EstabDibujar()
    _EstabAlpha(false)
}
_EstabFocoVigilar(*) {
    if !estabGui.foco {
        SetTimer(_EstabFocoVigilar,0)
        return
    }
    if (A_TickCount < estabGui.fPrevHasta)
        return
    if estabGui.arrastrando {
        estabGui.fTick := A_TickCount
        return
    }
    if estabGui.fPrevHasta != 0 {
        _EstabFocoOcultar()
        return
    }
    if (!WinActive("ahk_exe CLIPStudioPaint.exe") || GetKeyState("Escape","P") || A_TickCount - estabGui.fTick > FOCO_TIMEOUT_MS) {
        _EstabFocoOcultar()
        return
    }
}
_EstabFocoPrevisualizar() {
    if estabGui.foco
        return
    _EstabFocoMostrar()
    estabGui.fAbajo := false
    estabGui.fSoltado := 0
    estabGui.fPrevHasta := A_TickCount + 2500
    r := _EstabFocoRect()
    ori := (r.w > r.h) ? "HORIZONTAL" : "VERTICAL"
    MostrarHUD("🎚 ENFOQUE " r.w "×" r.h " · " ori,"FF8800",2200)
}
_EstabTeclaLocal(d) {
    if !IsObject(estabGui.g) || !estabGui.sincronizado
        return
    estabGui.valor := Max(0,Min(100,estabGui.valor + d))
    ActualizarEstabGUI()
    _GuardarValorEstab()
}
_EstabEnviarRaw(envio) {
    if !WinActive("ahk_exe CLIPStudioPaint.exe")
        return false
    SendInput(envio)
    return true
}
_EstabEmitir(tecla,n,pausa := 0) {
    static CHUNK := 300  ; Aumentar tamaño de trozo para reducir overhead de envío
    static _res := DllCall("winmm\timeBeginPeriod","UInt",1)
    if !WinActive("ahk_exe CLIPStudioPaint.exe")
        return false
    
    ; Si el envío es pequeño, omitimos el Sleep para máxima velocidad
    if (n < 5) {
        SendInput("{" tecla " " n "}")
        return true
    }
    
    while (n > 0) {
        k := (n > CHUNK) ? CHUNK : n
        SendInput("{" tecla " " k "}")
        n -= k
        if (n > 0 && pausa > 0)
            Sleep(0)  ; Eliminar delay para máximo rendimiento
    }
    return true
}
_EstabTeclaSubir() => IniRead(_PosGuiIniPath(), "Estab_p" PERFIL, "tecla_subir", "-")
_EstabTeclaBajar() => IniRead(_PosGuiIniPath(), "Estab_p" PERFIL, "tecla_bajar", "j")

_EstabFijarAbsoluto(target) {
    ; Baja al piso con la tecla Bajar y sube hasta target con la tecla Subir
    tb := _EstabTeclaBajar(), ts := _EstabTeclaSubir()
    return _EstabEmitir(tb,100,5) && (target <= 0 || _EstabEmitir(ts,target,5))
}
_EstabConfiable() => (estabGui.sincronizado && (A_TickCount - stabU.syncTick) < STAB_CONFIANZA_MS)
_EstabInvalidarConfianza(*) {
    ; cualquier clic/toque en CSP pudo cambiar la sub-herramienta (paleta): la base de AHK deja de ser fiable
    if _EstabBajoMouse()
        return
    stabU.syncTick := 0
}
_EstabEnviarDelta(nuevo) {
    if (STAB_ABSOLUTO && !_EstabConfiable()) {
        if !_EstabFijarAbsoluto(nuevo) {
            estabGui.sincronizado := false
            return false
        }
        estabGui.valor := nuevo
        stabU.syncTick := A_TickCount
        _Stab_Recordar(nuevo)
        return true
    }
    d := nuevo - estabGui.valor
    if (d = 0)
        return true
    ok := (d > 0) ? _EstabEmitir(_EstabTeclaSubir(),d) : _EstabEmitir(_EstabTeclaBajar(),Abs(d))
    if !ok {
        estabGui.sincronizado := false
        return false
    }
    estabGui.valor := nuevo
    stabU.syncTick := A_TickCount
    _Stab_Recordar(nuevo)
    return true
}
; Magnetismo suave hacia las marcas fijas del slider.
; entrada = radio de anclaje total; salida = radio donde termina la atracción (continuo, sin saltos).
_EstabMarcas() {                                        ; E4: marcas desde INI, cacheadas
    global PERFIL, ESTAB_MARCAS_C
    if (!IsSet(ESTAB_MARCAS_C) || !IsObject(ESTAB_MARCAS_C)) {
        m := [7, 15, 35, 55, 75]
        s := IniRead(_PosGuiIniPath(), "Estab_p" PERFIL, "snaps", "")
        if (s != "") {
            p := StrSplit(s, ","), t := [], ok := (p.Length = 5)
            for x in p {
                if (!ok || !IsInteger(x)) {
                    ok := false
                    break
                }
                t.Push(Integer(x))
            }
            if (ok)
                m := t
        }
        ESTAB_MARCAS_C := m
    }
    return ESTAB_MARCAS_C
}

_EstabMagneto(v, entrada := 1.5, salida := 3.0) {
    marcas := _EstabMarcas()   ; mantener igual a puntosCSP
    mejor := marcas[1], dMin := Abs(v - mejor)
    for p in marcas {
        d := Abs(v - p)
        if (d < dMin)
            mejor := p, dMin := d
    }
    ; límite por vecino: evita saltos o solapamientos entre marcas cercanas (7 <-> 15)
    vec := 999
    for p in marcas
        if (p != mejor)
            vec := Min(vec, Abs(p - mejor))
    sal := Min(salida, vec / 2)
    ent := Min(entrada, sal - 0.3)  ; Reducir entrada para mayor reactividad
    if (dMin >= sal)
        return v
    if (dMin <= ent)
        return mejor
    signo := (v > mejor) ? 1 : -1
    return mejor + signo * (sal * (dMin - ent) / (sal - ent))
}

_EstabPrevisualizar(cx,cy) {
    if estabGui.horiz
        nuevo := Round(((cx - estabGui.trackX) / estabGui.trackW) * 100)
    else
        nuevo := Round(((estabGui.trackY + estabGui.trackH - cy) / estabGui.trackH) * 100)
    
    nuevo_mag := Max(0, Min(100, Round(_EstabMagneto(Max(0, Min(100, nuevo))))))
    
    if (nuevo_mag != estabGui.previsto) {
        estabGui.previsto := nuevo_mag
        _HapticoSlider(nuevo_mag)
        
        ; LIMITADOR DE FPS (90 FPS aprox) para evitar lag en el lápiz
        if (A_TickCount - (HasProp(estabGui, "ultimoDibujo") ? estabGui.ultimoDibujo : 0) > 11) {
            ActualizarEstabGUI(nuevo_mag)
            estabGui.ultimoDibujo := A_TickCount
        }
    }
}
_EstabEnBarra(rx,ry) {
    k := Round(estabGui.knobSize / 2)
    if estabGui.horiz
        return (rx >= estabGui.trackX - k - 2 && rx <= estabGui.trackX + estabGui.trackW + k + 2)
    return (rx >= estabGui.trackX - _E(10) && rx <= estabGui.trackX + estabGui.trackW + _E(10) && ry >= estabGui.trackY - k && ry <= estabGui.trackY + estabGui.trackH + k)
}
_EstabRectGuardada() {
    global PERFIL
    ini := _PosGuiIniPath()
    sec := "Estab_p" PERFIL
    x := IniRead(ini,sec,"x","")
    y := IniRead(ini,sec,"y","")
    w := IniRead(ini,sec,"w","")
    h := IniRead(ini,sec,"h","")
    if (IsInteger(x) && IsInteger(y) && IsInteger(w) && IsInteger(h)) {
        if (_EstabTamanoValido(Integer(w),Integer(h)) && _PosicionValidaEnPantalla(Integer(x),Integer(y)))
            return {x:Integer(x),y:Integer(y),w:Integer(w),h:Integer(h)}
    }
    return _EstabRectCalibrada()
}
_EstabRectCalibrada() {
    global PUNTOS,PUNTOS_DEF
    if (PUNTOS.Length < 32)
        return 0
    if (PUNTOS[31][1] = PUNTOS_DEF[31][1] && PUNTOS[31][2] = PUNTOS_DEF[31][2] && PUNTOS[32][1] = PUNTOS_DEF[32][1] && PUNTOS[32][2] = PUNTOS_DEF[32][2])
        return 0
    w := Abs(PUNTOS[32][1] - PUNTOS[31][1])
    h := Abs(PUNTOS[32][2] - PUNTOS[31][2])
    if !_EstabTamanoValido(w,h)
        return 0
    return {x:Min(PUNTOS[31][1],PUNTOS[32][1]),y:Min(PUNTOS[31][2],PUNTOS[32][2]),w:w,h:h}
}
_EstabGuardarRect() {
    global PERFIL
    if (!IsObject(estabGui.g) || estabGui.foco)
        return
    ini := _PosGuiIniPath()
    sec := "Estab_p" PERFIL
    rc := Buffer(16,0)
    DllCall("GetWindowRect","Ptr",estabGui.g.Hwnd,"Ptr",rc)
    x := NumGet(rc,0,"int")
    y := NumGet(rc,4,"int")
    IniWrite(x,ini,sec,"x")
    IniWrite(y,ini,sec,"y")
    IniWrite(NumGet(rc,8,"int") - x,ini,sec,"w")
    IniWrite(NumGet(rc,12,"int") - y,ini,sec,"h")
}
_EstabAplicarRect(x,y,w,h) {
    global PUNTOS,PERFIL
    if !IsObject(estabGui.g)
        return false
    DllCall("SetWindowPos","Ptr",estabGui.g.Hwnd,"Ptr",0,"int",x,"int",y,"int",w,"int",h,"uint",0x0004 | 0x0010)
    _EstabLayout(w,h)
    _EstabRegion(w,h)
    if !estabGui.visible {
        estabGui.visible := true
        IniWrite(1,_PosGuiIniPath(),"Estab_p" PERFIL,"visible")
        ActualizarEstabBtnGUI()
    }
    estabGui.g.Show("NoActivate")
    _EstabDibujar()
    _EstabAlpha(false)
    _EstabGuardarRect()
    if (PUNTOS.Length >= 32) {
        PUNTOS[31] := [x,y]
        PUNTOS[32] := [x + w,y + h]
    }
    ori := estabGui.horiz ? "HORIZONTAL" : "VERTICAL"
    MostrarHUD("🎚 DESLIZADOR " w "×" h " · " ori,"9A7BFF",1500)
    return true
}
_EstabGUI_WM_LBUTTONDOWN(wParam,lParam,msg,hwnd) {
    global panelBlk
    if (estabGui.arrastrando || !IsObject(estabGui.g))
        return
    if !(hwnd = estabGui.g.Hwnd || estabGui.g.Hwnd = DllCall("GetParent","Ptr",hwnd,"Ptr"))
        return
    estabGui.arrastrando := true
    pt := Buffer(8,0)
    NumPut("int",lParam & 0xFFFF,pt,0)
    NumPut("int",(lParam >> 16) & 0xFFFF,pt,4)
    DllCall("ClientToScreen","Ptr",hwnd,"Ptr",pt)
    clickX := NumGet(pt,0,"int"), clickY := NumGet(pt,4,"int")
    rc := Buffer(16,0)
    DllCall("GetWindowRect","Ptr",estabGui.g.Hwnd,"Ptr",rc)
    winX := NumGet(rc,0,"int"), winY := NumGet(rc,4,"int")
    rx := clickX - winX, ry := clickY - winY
    winW := NumGet(rc,8,"int") - winX, winH := NumGet(rc,12,"int") - winY
    grip := _E(15)
    enGrip := !panelBlk.locked && (rx >= winW - grip && ry >= winH - grip)
    enBarra := !enGrip && _EstabEnBarra(rx,ry)
    mon := _EstabMonitorEn(clickX,clickY)
    _EstabAlpha(true)
    cur := Buffer(8,0)
    
    ; Variables para la lógica de "Salto Inteligente"
    ultimoEnvioTick := A_TickCount
    ultimoValorEnviado := estabGui.valor
    UMBRAL_SALTO := 12  ; Solo envía a CSP si el cambio es > 12 unidades (evita ráfagas)
    CADENCIA_MAX := 60  ; Máximo un envío cada 60ms para no saturar el buffer de CSP
    
    try {
        if (estabGui.foco || enBarra) {
            if (estabGui.foco) estabGui.fTick := A_TickCount
            _EstabPrevisualizar(rx,ry)
            
            while GetKeyState("LButton","P") {
                DllCall("GetCursorPos","Ptr",cur)
                mx := NumGet(cur,0,"int"), my := NumGet(cur,4,"int")
                
                ; 1. Actualización Visual (Prioridad Lápiz)
                _EstabPrevisualizar(mx - winX,my - winY)
                
                ; 2. Lógica de Envío Anticipado / Por Bloques (Batching)
                if (estabGui.sincronizado) {
                    delta := Abs(estabGui.previsto - ultimoValorEnviado)
                    tiempoTranscurrido := A_TickCount - ultimoEnvioTick
                    
                    ; DISPARAR SALTO si:
                    ; - El movimiento es grande (Salto detectado > 12)
                    ; - O ha pasado tiempo (60ms) y el cambio es moderado (> 3)
                    if (delta >= UMBRAL_SALTO || (tiempoTranscurrido > CADENCIA_MAX && delta > 3)) {
                        _EstabEnviarDelta(estabGui.previsto)
                        ultimoValorEnviado := estabGui.previsto
                        ultimoEnvioTick := A_TickCount
                    }
                }
                
                if (estabGui.foco) estabGui.fTick := A_TickCount
                Sleep(1)
            }
            ; Sincronización final al soltar
            _EstabAplicarValor(estabGui.previsto)
            if (!estabGui.foco) {
                MostrarHUD("ESTABILIZACIÓN " estabGui.valor, "9A7BFF", 700)
            }
        } else if (enGrip) {
            while GetKeyState("LButton","P") {
                DllCall("GetCursorPos","Ptr",cur)
                mx := NumGet(cur,0,"int"), my := NumGet(cur,4,"int")
                nw := Max(14,Min(mon.w,winW + (mx - clickX)))
                nh := Max(14,Min(mon.h,winH + (my - clickY)))
                DllCall("SetWindowPos","Ptr",estabGui.g.Hwnd,"Ptr",0,"int",0,"int",0,"int",nw,"int",nh,"uint",0x0002 | 0x0004 | 0x0010)
                _EstabLayout(nw,nh)
                _EstabRegion(nw,nh)
                Sleep(1)
            }
            _EstabGuardarRect()
        } else if (!panelBlk.locked) {
            movido := false
            while GetKeyState("LButton","P") {
                DllCall("GetCursorPos","Ptr",cur)
                mx := NumGet(cur,0,"int"), my := NumGet(cur,4,"int")
                if (Abs(mx - clickX) > 4 || Abs(my - clickY) > 4) {
                    movido := true
                }
                if (movido) {
                    DllCall("SetWindowPos","Ptr",estabGui.g.Hwnd,"Ptr",0,"int",mx - rx,"int",my - ry,"int",0,"int",0,"uint",0x0001 | 0x0004 | 0x0010)
                }
                Sleep(1)
            }
            if (movido) {
                _EstabGuardarRect()
            }
        }
    } finally {
        _EstabAlpha(false)
        estabGui.arrastrando := false
        if (estabGui.foco) {
            _EstabFocoOcultar()
        }
    }
}
_EstabGUI_WM_RBUTTONDOWN(wParam,lParam,msg,hwnd) {
    if !IsObject(estabGui.g)
        return
    if !(hwnd = estabGui.g.Hwnd || estabGui.g.Hwnd = DllCall("GetParent","Ptr",hwnd,"Ptr"))
        return
    _EstabSoloLineaAlternar()
}
_EstabGUI_WM_MBUTTONDOWN(wParam,lParam,msg,hwnd) {
    if !IsObject(estabGui.g)
        return
    if !(hwnd = estabGui.g.Hwnd || estabGui.g.Hwnd = DllCall("GetParent","Ptr",hwnd,"Ptr"))
        return
    estabGui.sincronizado := false
    _EstabAplicarValor(estabGui.valor)
    MostrarHUD("🔄 ESTAB. RESINCRONIZADA","44DD88",900)
}
_EstabAplicarValor(nuevo) {
    nuevo := Max(0,Min(100,Round(nuevo)))
    if !WinActive("ahk_exe CLIPStudioPaint.exe") {
        MostrarHUD("⚠ ACTIVA CLIP STUDIO PAINT","FF4444",1200)
        estabGui.sincronizado := false
        ActualizarEstabGUI()
        return
    }
    desfasado := !estabGui.sincronizado || Abs(nuevo - estabGui.valor) > 25 || (STAB_ABSOLUTO && !_EstabConfiable())
    if (nuevo = estabGui.valor && !desfasado) {
        ActualizarEstabGUI()
        _GuardarValorEstab()
        return
    }
    base := estabGui.valor
    ok := true
    t0 := A_TickCount
    try {
        BlockInput(true)
        if desfasado {
            tb := _EstabTeclaBajar(), ts := _EstabTeclaSubir()
            if (nuevo > 50)
                envio := "{" ts " 100}" (nuevo < 100 ? "{" tb " " (100 - nuevo) "}" : "")
            else
                envio := "{" tb " 100}" (nuevo > 0 ? "{" ts " " nuevo "}" : "")
            ok := _EstabEnviarRaw(envio)
        } else {
            d := nuevo - base
            if (d > 0)
                ok := _EstabEmitir(_EstabTeclaSubir(),d)
            else if (d < 0)
                ok := _EstabEmitir(_EstabTeclaBajar(),Abs(d))
        }
    } finally {
        BlockInput(false)
    }
    if ok {
        estabGui.sincronizado := true
        if desfasado
            MostrarHUD("🔄 SINCRONIZADO","9A7BFF",600)
    }
    OutputDebug("[StabUniv] desfasado=" desfasado " nuevo=" nuevo " ms=" (A_TickCount - t0))
    if !ok {
        estabGui.sincronizado := false
        MostrarHUD("⚠ SINCRONIZACIÓN INTERRUMPIDA","FFAA33",1300)
        ActualizarEstabGUI()
        return
    }
    estabGui.valor := nuevo
    estabGui.previsto := nuevo
    stabU.syncTick := A_TickCount
    ActualizarEstabGUI()
    _GuardarValorEstab()
}
_GuardarValorEstab() {
    global PERFIL
    ini := _PosGuiIniPath()
    IniWrite(estabGui.valor,ini,"Estab_p" PERFIL,"valor")
    pid := ProcessExist("CLIPStudioPaint.exe")
    try {
        if pid
            IniWrite(pid,ini,"Estab_p" PERFIL,"pid")
        else
            IniDelete(ini,"Estab_p" PERFIL,"pid")
    }
    
    ; Guardar estado del Modo Universal
    try {
        p := (IsSet(PERFIL) && PERFIL != "") ? PERFIL : "1"
        IniWrite(g_ModoUniversal ? 1 : 0, ini, "Estab_p" p, "modoUniversal")
    } catch {
    }
}
; === F3-BEGIN ===
; F3: el slider del panel se pinta con GDI+ sobre el propio cliente: píldora hundida,
;     relleno de valor y knob con borde, todo con antialias real. Los únicos hijos son
;     valorTxt y grip, que se repintan tras el canvas.
;     Se dibuja a demanda con GetDC (valor, bloqueo, visibilidad, foco) y se rehace
;     cuando algo cambia; sin WM_PAINT (ver la nota de la ola 7 arriba). Coste ~34 ms.
;     El panel se repinta con _EstabDibujar() tras cada cambio de estado.
_EstabGdipIniciar() {
    static iniciado := false
    if iniciado
        return
    info := Buffer(A_PtrSize = 8 ? 24 : 16,0)
    NumPut("uint",1,info,0)
    tok := 0
    if (DllCall("gdiplus\GdiplusStartup","ptr*", &tok,"ptr",info,"ptr",0,"int") = 0) {
        iniciado := true
        _GdipRes().tok := tok
    }
}
_ArgbDeHex(hex,alfa) => (alfa << 24) | Integer("0x" hex)
_EstabPildora(x,y,an,al,radio) {
    ruta := 0
    DllCall("gdiplus\GdipCreatePath","int",0,"ptr*", &ruta,"int")
    d := radio * 2.0
    DllCall("gdiplus\GdipAddPathArc","ptr",ruta,"float",x,"float",y,"float",d,"float",d,"float",180,"float",90,"int")
    DllCall("gdiplus\GdipAddPathArc","ptr",ruta,"float",x + an - d,"float",y,"float",d,"float",d,"float",270,"float",90,"int")
    DllCall("gdiplus\GdipAddPathArc","ptr",ruta,"float",x + an - d,"float",y + al - d,"float",d,"float",d,"float",0,"float",90,"int")
    DllCall("gdiplus\GdipAddPathArc","ptr",ruta,"float",x,"float",y + al - d,"float",d,"float",d,"float",90,"float",90,"int")
    DllCall("gdiplus\GdipClosePathFigure","ptr",ruta,"int")
    return ruta
}
_EstabRellenar(gfx,ruta,hex,alfa := 255) {
    pincel := 0
    DllCall("gdiplus\GdipCreateSolidFill","uint",_ArgbDeHex(hex,alfa),"ptr*", &pincel,"int")
    DllCall("gdiplus\GdipFillPath","ptr",gfx,"ptr",pincel,"ptr",ruta,"int")
    DllCall("gdiplus\GdipDeleteBrush","ptr",pincel,"int")
}
_EstabTrazar(gfx,ruta,hex,grosor) {
    lapiz := 0
    DllCall("gdiplus\GdipCreatePen1","uint",_ArgbDeHex(hex,255),"float",grosor,"int",2,"ptr*", &lapiz,"int")
    DllCall("gdiplus\GdipDrawPath","ptr",gfx,"ptr",lapiz,"ptr",ruta,"int")
    DllCall("gdiplus\GdipDeletePen","ptr",lapiz,"int")
}
    _EstabTextoCentrado(gfx,txt,cx,cy,lado,em,colorHex) {
        DllCall("gdiplus\GdipSetTextRenderingHint","ptr",gfx,"int",4,"int")
        fam := 0, fnt := 0, fmt := 0, br := 0
        if (DllCall("gdiplus\GdipCreateFontFamilyFromName","wstr","Bahnschrift","ptr",0,"ptr*", &fam,"int") != 0 || !fam)
            if (DllCall("gdiplus\GdipCreateFontFamilyFromName","wstr","Segoe UI Semibold","ptr",0,"ptr*", &fam,"int") != 0 || !fam)
                DllCall("gdiplus\GdipCreateFontFamilyFromName","wstr","Segoe UI","ptr",0,"ptr*", &fam,"int")
        DllCall("gdiplus\GdipCreateFont","ptr",fam,"float",em,"int",0,"int",2,"ptr*", &fnt,"int")
        DllCall("gdiplus\GdipCreateStringFormat","int",0x5000,"int",0,"ptr*", &fmt,"int")
        DllCall("gdiplus\GdipSetStringFormatAlign","ptr",fmt,"int",1,"int")
        DllCall("gdiplus\GdipSetStringFormatLineAlign","ptr",fmt,"int",1,"int")
        DllCall("gdiplus\GdipCreateSolidFill","uint",_ArgbDeHex(colorHex,255),"ptr*", &br,"int")
        rc := Buffer(16,0)
        NumPut("float",cx - lado / 2.0,"float",cy - lado / 2.0,"float",lado,"float",lado,rc)
        DllCall("gdiplus\GdipDrawString","ptr",gfx,"wstr",txt,"int",-1,"ptr",fnt,"ptr",rc,"ptr",fmt,"ptr",br,"int")
        DllCall("gdiplus\GdipDeleteBrush","ptr",br,"int")
        DllCall("gdiplus\GdipDeleteStringFormat","ptr",fmt,"int")
        DllCall("gdiplus\GdipDeleteFont","ptr",fnt,"int")
        DllCall("gdiplus\GdipDeleteFontFamily","ptr",fam,"int")
    }
; ===== Modo "Solo Línea" (sin contenedor exterior) =====
_EstabSoloSeccion() {
    global PERFIL
    return "Estab_p" . (IsSet(PERFIL) ? PERFIL : "1")
}

_EstabSoloLineaCargar() {
    global estabSoloLinea
    ini := _PosGuiIniPath()
    try estabSoloLinea := Integer(IniRead(ini, _EstabSoloSeccion(), "soloLinea", "0"))
    catch
        estabSoloLinea := 0
    _EstabSoloLineaAplicar()
}

_EstabSoloLineaAplicar() {
    global estabGui, estabSoloLinea
    if !IsSet(estabGui) || !IsObject(estabGui) || !estabGui.g
        return
    hwnd := estabGui.g.Hwnd
    try {
        ; Re-layerizar la ventana para cambiar limpiamente entre SetLayeredWindowAttributes y UpdateLayeredWindow
        exStyle := WinGetExStyle("ahk_id " hwnd)
        if (IsSet(estabSoloLinea) && estabSoloLinea) {
            try WinSetTransColor("Off", "ahk_id " hwnd)
            try WinSetTransparent("Off", "ahk_id " hwnd)
            DllCall("user32\SetWindowLong","ptr",hwnd,"int",-20,"int",exStyle & ~0x80000)
            DllCall("user32\SetWindowLong","ptr",hwnd,"int",-20,"int",exStyle | 0x80000)
        } else {
            DllCall("user32\SetWindowLong","ptr",hwnd,"int",-20,"int",exStyle & ~0x80000)
            DllCall("user32\SetWindowLong","ptr",hwnd,"int",-20,"int",exStyle | 0x80000)
        }
    }
    _EstabAlpha(false)
}

_EstabSoloLineaAlternar(*) {
    global estabSoloLinea
    if !IsSet(estabSoloLinea)
        estabSoloLinea := 0
    estabSoloLinea := estabSoloLinea ? 0 : 1
    try IniWrite(estabSoloLinea, _PosGuiIniPath(), _EstabSoloSeccion(), "soloLinea")
    _EstabSoloLineaAplicar()
    _EstabDibujar()
    try MostrarMiniTexto(estabSoloLinea ? "➖ SLIDER: SOLO LÍNEA" : "🔲 SLIDER: MODO COMPLETO", "9A7BFF", 900)
}

_EstabColoresPorPerfil() {
    global PERFIL, estabGui
    p := (IsSet(PERFIL) && IsInteger(PERFIL) && PERFIL >= 1 && PERFIL <= 3) ? Integer(PERFIL) : 1
    ini := _PosGuiIniPath()
    sec := "Estab_p" p

    ; Tokens dinámicos de la paleta de tema activa:
    acento := HasProp(estabGui, "estabTrackOn") ? estabGui.estabTrackOn : _Tema("color", "accent.estab", "9A7BFF")
    acentoSoft := _Tema("color", "accent.estabSoft", acento)
    fondoOff := HasProp(estabGui, "estabTrackOff") ? estabGui.estabTrackOff : _Tema("color", "track.off", _Tema("color", "surface.off", "3E4452"))
    bordeBase := _Tema("color", "track.pillOff", "5A5A5A")
    knobBorde := HasProp(estabGui, "estabKnob") ? estabGui.estabKnob : acento

    ; Fallback base armónico por perfil de hardware si el tema no define acentos:
    def := {
        railOn: acentoSoft,
        railOff: fondoOff,
        railEdge: bordeBase,
        knobFace: _Tema("color", "knob.face", "ECEEFA"),
        knobEdge: knobBorde,
        markOn: _Tema("color", "text.primary", "FFFFFF"),
        markOff: _Tema("color", "text.idle", "8A92BC"),
        knobText: _Tema("color", "knob.text", "1A1A1A")
    }

    col := {}
    for k, v in def.OwnProps() {
        val := IniRead(ini, sec, k, "")
        if (val = "" || !RegExMatch(val, "^[0-9A-Fa-f]{6}$"))
            val := _Tema("color", "estab." k, "")
        if (val = "" || !RegExMatch(val, "^[0-9A-Fa-f]{6}$"))
            val := v
        col.%k% := StrUpper(val)
    }
    return col
}

_EstabPanelPintar(gfx) {
    global estabGui, panelBlk, ESTAB_COLOR, estabSoloLinea, PERFIL
    static rc := Buffer(16,0)
    static puntosCSP := [7, 15, 35, 55, 75]
    static soloCargado := false
    if !soloCargado {
        soloCargado := true
        _EstabSoloLineaCargar()
    }
    solo := IsSet(estabSoloLinea) && estabSoloLinea
    gr := _GdipRes()
    fam := gr.fam, fnt := gr.fnt, fmt := gr.fmt, fntTam := gr.tam
    val := estabGui.dibV
    if (val < 0)
        val := estabGui.valor
    val := Min(100,Max(0,Integer(val)))
    tx := Float(estabGui.trackX)
    ty := Float(estabGui.trackY)
    tw := Float(estabGui.trackW)
    th := Float(estabGui.trackH)
    bo := Float(estabGui.knobSize)
    plano := estabGui.horiz ? th : tw
    radio := plano / 2.0
    acento := _Tema("color","accent.estab",ESTAB_COLOR)
    surf := panelBlk.locked ? _Tema("color","surface.estabLocked","2B2B2B") : _Tema("color","surface.estabOpen","3A4260")
    bw := Float(_Tema("metric","estab.borderW","2"))
    estabGui.g.GetClientPos(,, &cw, &ch)
    if (solo) {
        DllCall("gdiplus\GdipGraphicsClear","ptr",gfx,"uint",0x00000000,"int")
    } else {
        DllCall("gdiplus\GdipGraphicsClear","ptr",gfx,"uint",_ArgbDeHex(_Tema("color","surface.estabEdge","15151B"),255),"int")
        ruta := _EstabPildora(bw,bw,cw - 2 * bw,ch - 2 * bw,8.0)
        _EstabRellenar(gfx,ruta,surf)
        DllCall("gdiplus\GdipDeletePath","ptr",ruta,"int")
    }
    ; ── Frontera activa/inactiva (knob primero) ──
    kx := estabGui.horiz ? (tx + tw * val / 100.0) : (tx + tw / 2.0)
    ky := estabGui.horiz ? (ty + th / 2.0) : (ty + th - th * val / 100.0)

    ; ── Riel píldora dual-tone (adaptativo por perfil) ──
    cp := _EstabColoresPorPerfil()
    bd := 1.5
    colBorde := cp.railEdge
    colInact := cp.railOff
    colActiv := cp.railOn
    ruta := _EstabPildora(tx,ty,tw,th,radio)
    _EstabRellenar(gfx,ruta,colBorde)
    DllCall("gdiplus\GdipDeletePath","ptr",ruta,"int")
    ix := tx + bd, iy := ty + bd, iw := tw - 2 * bd, ih := th - 2 * bd
    ir := Max(0.5, radio - bd)
    ruta := _EstabPildora(ix,iy,iw,ih,ir)
    _EstabRellenar(gfx,ruta,colInact)
    DllCall("gdiplus\GdipDeletePath","ptr",ruta,"int")
    largo := estabGui.horiz ? (kx - ix) : ((iy + ih) - ky)
    largo := Min(largo, estabGui.horiz ? iw : ih)
    if (largo >= 2) {
        rr := Min(largo / 2.0, ir)
        ruta := estabGui.horiz ? _EstabPildora(ix,iy,largo,ih,rr) : _EstabPildora(ix,(iy + ih) - largo,iw,largo,rr)
        _EstabRellenar(gfx,ruta,colActiv)
        DllCall("gdiplus\GdipDeletePath","ptr",ruta,"int")
    }

    ; ── Snap points P1..P5 tipo squircle ──
    sm := Max(6.0, Min(10.0, plano * 0.45))
    sm := Max(4.0, Min(sm, plano - 2 * bd - 2.0))
    smR := Min(2.5, sm / 3.0)
    colMOn := cp.markOn
    colMOff := cp.markOff
    for p in puntosCSP {
        if estabGui.horiz {
            mx := tx + tw * p / 100.0
            mx := Max(tx + bd + sm / 2.0, Min(mx, tx + tw - bd - sm / 2.0))
            mxl := mx - sm / 2.0
            myl := ty + (th - sm) / 2.0
            activa := (mx <= kx)
        } else {
            my := ty + th - th * p / 100.0
            my := Max(ty + bd + sm / 2.0, Min(my, ty + th - bd - sm / 2.0))
            mxl := tx + (tw - sm) / 2.0
            myl := my - sm / 2.0
            activa := (my >= ky)
        }
        if (activa && !solo && !estabGui.arrastrando) {
            ruta := _EstabPildora(mxl - 1.5,myl - 1.5,sm + 3.0,sm + 3.0,smR + 1.5)
            _EstabRellenar(gfx,ruta,"FFFFFF",45)
            DllCall("gdiplus\GdipDeletePath","ptr",ruta,"int")
        }
        ruta := _EstabPildora(mxl,myl,sm,sm,smR)
        _EstabRellenar(gfx,ruta,activa ? colMOn : colMOff,activa ? 255 : 215)
        DllCall("gdiplus\GdipDeletePath","ptr",ruta,"int")
    }

    ; ── Knob circular esculpido ──
    dd := bo - 2.0
    if (!solo) {
        ruta := _EstabPildora(kx - dd / 2.0,ky - dd / 2.0 + 1.5,dd,dd,dd / 2.0)
        _EstabRellenar(gfx,ruta,"1B1E2B",70)
        DllCall("gdiplus\GdipDeletePath","ptr",ruta,"int")
    }
    ruta := _EstabPildora(kx - dd / 2.0,ky - dd / 2.0,dd,dd,dd / 2.0)
    _EstabRellenar(gfx,ruta,cp.knobEdge)
    DllCall("gdiplus\GdipDeletePath","ptr",ruta,"int")
    bz := 1.2
    ruta := _EstabPildora(kx - dd / 2.0 + bz,ky - dd / 2.0 + bz,dd - 2 * bz,dd - 2 * bz,dd / 2.0 - bz)
    _EstabRellenar(gfx,ruta,cp.knobFace)
    DllCall("gdiplus\GdipDeletePath","ptr",ruta,"int")
    if (!solo && dd >= 22) {
        ruta := _EstabPildora(kx - dd * 0.32,ky - dd / 2.0 + bz + 1.0,dd * 0.64,dd * 0.22,dd * 0.11)
        _EstabRellenar(gfx,ruta,"FFFFFF",90)
        DllCall("gdiplus\GdipDeletePath","ptr",ruta,"int")
    }
    if (bo >= 24) {
        txt := String(Round(val))
        escalaModo := (HasProp(estabGui, "foco") && estabGui.foco) ? 1.0 : 0.88
        em := Min(dd * 0.46, dd * 0.78 / (StrLen(txt) * 0.58)) * escalaModo
        _EstabTextoCentrado(gfx,txt,kx,ky,dd,em,cp.knobText)
    }
}
_EstabDibujar() {
    global estabGui, estabSoloLinea
    if !IsObject(estabGui.g)
        return
    hwnd := estabGui.g.Hwnd
    if !DllCall("IsWindowVisible","ptr",hwnd)
        return
    estabGui.g.GetClientPos(,, &cw, &ch)
    if (cw <= 0 || ch <= 0)
        return
    solo := IsSet(estabSoloLinea) && estabSoloLinea
    hdc := DllCall("user32\GetDC","ptr",hwnd,"ptr")
    memDC := DllCall("gdi32\CreateCompatibleDC","ptr",hdc,"ptr")
    hbm := DllCall("gdi32\CreateCompatibleBitmap","ptr",hdc,"int",cw,"int",ch,"ptr")
    obm := DllCall("gdi32\SelectObject","ptr",memDC,"ptr",hbm,"ptr")
    gfx := 0
    if (DllCall("gdiplus\GdipCreateFromHDC","ptr",memDC,"ptr*", &gfx,"int") = 0) {
        DllCall("gdiplus\GdipSetSmoothingMode","ptr",gfx,"int",4,"int")
        DllCall("gdiplus\GdipSetPixelOffsetMode","ptr",gfx,"int",2,"int")
        _EstabPanelPintar(gfx)
        DllCall("gdiplus\GdipDeleteGraphics","ptr",gfx,"int")
        DllCall("gdi32\BitBlt","ptr",hdc,"int",0,"int",0,"int",cw,"int",ch,"ptr",memDC,"int",0,"int",0,"uint",0x00CC0020)
    }
    DllCall("gdi32\SelectObject","ptr",memDC,"ptr",obm,"ptr")
    DllCall("gdi32\DeleteObject","ptr",hbm)
    DllCall("gdi32\DeleteDC","ptr",memDC)
    DllCall("user32\ReleaseDC","ptr",hwnd,"ptr",hdc,"int")
    DllCall("user32\ValidateRect","ptr",hwnd,"ptr",0,"int")
}
; _EstabOnPaint se retiro en la ola 7 (D): nunca se ejecutaba (ESTAB_REPINTADO := false).
; El codigo del handler se conserva en el .bak-ola7 si hubiera que recuperar WM_PAINT.
; === F3-END ===
; === STAB-UNIVERSAL-BEGIN ===
Stab_ResetUniversal(herramienta := "", forzar := false) {
    global stabU, Q, estabGui, STAB_RESET_FISICO, STAB_RESET_DELAY_MS, ESTAB_MAX, ESTAB_MIN, g_ModoUniversal
    ; Misma herramienta -> no reiniciar, a menos que el Modo Universal esté activo (queremos forzar la carga)
    if (!forzar && herramienta != "" && herramienta = stabU.tool && !g_ModoUniversal)
        return
    
    stabU.abortar := true
    stabU.tool := herramienta
    clave := _Stab_Clave(herramienta)
    
    ; Si el modo universal está activo, forzamos que use el valor del "Universal" (objetivo)
    if (g_ModoUniversal && stabU.objetivo != -1) {
        estabGui.valor := stabU.objetivo
    } else if (clave != "" && stabU.known.Has(clave)) {
        estabGui.valor := stabU.known[clave]
    } else {
        estabGui.sincronizado := false
    }
    
    estabGui.previsto := estabGui.valor
    estabGui.sincronizado := true
    stabU.syncTick := A_TickCount
    
    Q.estadoEstab := (estabGui.valor >= (ESTAB_MAX + ESTAB_MIN) / 2) ? 1 : 0
    if (!STAB_RESET_FISICO || herramienta = "s") {
        SetTimer(_Stab_ResetFisico, 0)
        return
    }
    if _Stab_NecesitaEmitir(herramienta)
        SetTimer(_Stab_ResetFisico, -STAB_RESET_DELAY_MS)
    else
        SetTimer(_Stab_ResetFisico, 0)
}
_Stab_Clave(id) {
    global STAB_ALIAS
    return (id != "" && IsSet(STAB_ALIAS) && STAB_ALIAS.Has(id)) ? STAB_ALIAS[id] : id
}
_Stab_Recordar(v) {
    global stabU
    stabU.objetivo := v                         ; el ultimo valor elegido por el usuario es el universal
    if (stabU.tool = "" || stabU.tool = "s")
        return
    stabU.known[_Stab_Clave(stabU.tool)] := v
    SetTimer(_Stab_GuardarKnown, -3000)
}
_Stab_NecesitaEmitir(id) {
    global stabU
    clave := _Stab_Clave(id)
    return !(stabU.known.Has(clave) && stabU.known[clave] = _Stab_ValorUniversal(id))
}
_Stab_ValorUniversal(id) {
    global STAB_POR_HERRAMIENTA, estabGui, stabU
    if STAB_POR_HERRAMIENTA.Has(id)
        v := STAB_POR_HERRAMIENTA[id]
    else
        v := (stabU.objetivo >= 0) ? stabU.objetivo : estabGui.valor
    return Max(0, Min(100, Integer(v)))
}
_Stab_Olvidar(clave) {
    global stabU
    if stabU.known.Has(clave)
        stabU.known.Delete(clave)
    SetTimer(_Stab_GuardarKnown, -3000)
}
_Stab_CargarKnown() {
    global stabU, STAB_KNOWN_INI, g_ModoUniversal
    try
        s := IniRead(STAB_KNOWN_INI, "known", "data", "")
    catch
        return
    for par in StrSplit(s, ";") {
        p := StrSplit(par, "=")
        if (p.Length = 2 && IsInteger(p[2]))
            stabU.known[p[1]] := Max(0, Min(100, Integer(p[2])))
    }
    
    ; Cargar estado del Modo Universal desde INI
    global PERFIL
    ini := _PosGuiIniPath()
    p := (IsSet(PERFIL) && PERFIL != "") ? PERFIL : "1"
    sec := "Estab_p" p
    try {
        modo := IniRead(ini, sec, "modoUniversal", "0")
        g_ModoUniversal := (modo = "1")
    } catch {
        g_ModoUniversal := false
    }
}
_Stab_GuardarKnown() {
    global stabU, STAB_KNOWN_INI
    s := ""
    for k, v in stabU.known
        s .= (s = "" ? "" : ";") k "=" v
    try IniWrite(s, STAB_KNOWN_INI, "known", "data")
}
_Stab_ResetFisico() {
    global stabU, estabGui, stylus, STAB_RESET_DELAY_MS
    if stabU.ocupado {
        stabU.rearmar := true
        return
    }
    if !WinActive("ahk_exe CLIPStudioPaint.exe")
        return
    if (estabGui.arrastrando || GetKeyState("LButton","P")) {
        SetTimer(_Stab_ResetFisico, -150)
        return
    }
    tool := stabU.tool
    if (tool = "" || tool = "s")
        return
    clave := _Stab_Clave(tool)
    target := _Stab_ValorUniversal(tool)
    if (stabU.known.Has(clave) && stabU.known[clave] = target) {
        estabGui.valor := target
        estabGui.previsto := target
        estabGui.sincronizado := true
        return
    }
    stabU.ocupado := true
    stabU.abortar := false
    t0 := A_TickCount
    modo := stabU.known.Has(clave) ? "delta" : "absoluto"
    alt := stylus.altActive
    ok := false
    try {
        if alt
            SendEvent("{Alt up}")
        ok := true
        if !stabU.known.Has(clave)
            ok := _Stab_EmitirAbortable("j", 100, tool, clave)      ; al completar deja known[clave] := 0
        if ok {
            d := target - stabU.known[clave]
            if (d != 0)
                ok := _Stab_EmitirAbortable(d > 0 ? "-" : "j", Abs(d), tool, clave)
        }
    } finally {
        _AltRestaurar(alt)
        stabU.ocupado := false
    }
    if ok {
        estabGui.valor := target
        estabGui.previsto := target
        estabGui.sincronizado := true
        stabU.syncTick := A_TickCount
        SetTimer(_Stab_PostReset, -1)
        OutputDebug("[StabUniv] " tool " -> " target " (" modo ") ms=" (A_TickCount - t0))
    } else if (!stabU.abortar && stabU.tool = tool) {
        SetTimer(_Stab_ResetFisico, -150)        ; interrumpido por el trazo: reintentar en la pausa
    }
    if stabU.rearmar {
        stabU.rearmar := false
        SetTimer(_Stab_ResetFisico, -STAB_RESET_DELAY_MS)
    }
}
_Stab_PostReset() {
    global estabGui
    ActualizarEstabGUI(-1, true)
    SetTimer(_GuardarValorEstab, -2000)        ; IniWrite/ProcessExist diferido y agrupado
    SetTimer(_Stab_GuardarKnown, -3000)
}
; Emite en trozos; actualiza known[clave] tras cada trozo, asi abortar nunca pierde el progreso.
_Stab_EmitirAbortable(tecla, n, tool, clave) {
    global stabU
    static CHUNK := 80  ; Aumentar significativamente para reducir overhead de envío
    static _res := DllCall("winmm\timeBeginPeriod", "UInt", 1)
    hechos := 0
    absoluto := !stabU.known.Has(clave)
    while (n > 0) {
        if (stabU.abortar || stabU.tool != tool
            || !WinActive("ahk_exe CLIPStudioPaint.exe") || GetKeyState("LButton","P"))
            return false
        k := (n > CHUNK) ? CHUNK : n
        SendInput("{" tecla " " k "}")
        hechos += k
        n -= k
        if !absoluto
            stabU.known[clave] := Max(0, Min(100, stabU.known[clave] + ((tecla = "-") ? k : -k)))
        else if (hechos >= 100)
            stabU.known[clave] := 0              ; 100 'j' completadas: piso conocido
        if (n > 0)
            Sleep(0)  ; Eliminar delay para máximo rendimiento (puede aumentar CPU)
    }
    return true
}
; === STAB-UNIVERSAL-END ===