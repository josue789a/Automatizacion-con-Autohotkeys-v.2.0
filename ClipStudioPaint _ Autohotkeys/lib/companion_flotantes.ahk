#Requires AutoHotkey v2.0
; [LIB] companion_flotantes - paneles flotantes, pildoras OSD, ventana WINDOW, Hub y Puntos (extraido de companion.ahk, Frente 2)
; Solo funciones. Usa super-globals declarados en los lanzadores (hubGui, panelBlk, nvGui, ...).
ResetAlphaStates() {
    global colorEstado,panelBlk,floatGui
    if _HubMenuAbierto() || _LBtnAbajo()
        return
    activeHwnd := WinActive("A")
    esCsp := WinActive("ahk_exe CLIPStudioPaint.exe")
    esPropio := (activeHwnd && WinGetPID(activeHwnd) = ProcessExist())
    if (!esCsp && !esPropio) {
        if panelBlk.frente {
            _MostrarPaneles()
            _TraerPanelesAlFrente()
            return
        }
        for g in [dial,dsGui,ccGui,arGui,hcGui,nvGui,lockGui,frenteGui,estabBtnGui,reloadGui,estabGui,puntosGui] {
            if IsObject(g.g)
                g.g.Hide()
        }
        _AvisoCerrarBadge()
        _AvisoCerrarHUD()
        _AvisoCerrarAuxiliares()
        return
    }
    _MostrarPaneles()
    ; Watchdog anti-atasco para HUD y Badge
    if (IsObject(floatGui)) {
        if (floatGui.badgeHwnd && DllCall("IsWindow", "Ptr", floatGui.badgeHwnd)) {
            if (floatGui.badgeTick > 0 && (A_TickCount - floatGui.badgeTick > 3000))
                _AvisoCerrarBadge()
        }
        if (floatGui.hudHwnd && DllCall("IsWindow", "Ptr", floatGui.hudHwnd)) {
            if (floatGui.hudTick > 0 && (A_TickCount - floatGui.hudTick > 3500))
                _AvisoCerrarHUD()
        }
        if (floatGui.miniTipID != 0 && floatGui.miniTipTick != 0) {
            if (A_TickCount - floatGui.miniTipTick > 4000) {
                try {
                    if IsObject(floatGui.miniTip)
                        floatGui.miniTip.Destroy()
                }
                floatGui.miniTip := 0
                floatGui.miniTipID := 0
                floatGui.miniTipTick := 0
            }
        }
    }
}
_EsPanelEmbebido(g) {
    global hubGui, lockGui, frenteGui, puntosGui, estabBtnGui, reloadGui, dsGui, ccGui, arGui, hcGui, nvGui
    if !IsObject(g) || !IsObject(g.g) || !IsSet(hubGui) || !IsObject(hubGui) || !hubGui.HasOwnProp("embebidos")
        return false
    h := g.g.Hwnd
    if (IsObject(lockGui.g) && h = lockGui.g.Hwnd)
        return (hubGui.embebidos.Has("lock") && hubGui.embebidos["lock"])
    if (IsObject(frenteGui.g) && h = frenteGui.g.Hwnd)
        return (hubGui.embebidos.Has("frente") && hubGui.embebidos["frente"])
    if (IsObject(puntosGui.g) && h = puntosGui.g.Hwnd)
        return (hubGui.embebidos.Has("puntos") && hubGui.embebidos["puntos"])
    if (IsObject(estabBtnGui.g) && h = estabBtnGui.g.Hwnd)
        return (hubGui.embebidos.Has("estab") && hubGui.embebidos["estab"])
    if (IsObject(reloadGui.g) && h = reloadGui.g.Hwnd)
        return (hubGui.embebidos.Has("reload") && hubGui.embebidos["reload"])
    if (IsObject(dsGui.g) && h = dsGui.g.Hwnd)
        return (hubGui.embebidos.Has("ds") && hubGui.embebidos["ds"])
    if (IsObject(ccGui.g) && h = ccGui.g.Hwnd)
        return (hubGui.embebidos.Has("cc") && hubGui.embebidos["cc"])
    if (IsObject(arGui.g) && h = arGui.g.Hwnd)
        return (hubGui.embebidos.Has("ar") && hubGui.embebidos["ar"])
    if (IsObject(hcGui.g) && h = hcGui.g.Hwnd)
        return (hubGui.embebidos.Has("hc") && hubGui.embebidos["hc"])
    if (IsObject(nvGui.g) && h = nvGui.g.Hwnd)
        return (hubGui.embebidos.Has("nv") && hubGui.embebidos["nv"])
    return false
}

_TraerPanelesAlFrente() {
    for g in [dsGui,ccGui,arGui,hcGui,nvGui,lockGui,frenteGui,estabBtnGui,reloadGui,puntosGui,estabGui] {
        if !IsSet(g) || !IsObject(g) || !HasProp(g, "g") || !IsObject(g.g) || _EsPanelEmbebido(g)
            continue
        try {
            if (g.g.Hwnd && DllCall("IsWindow", "Ptr", g.g.Hwnd) && DllCall("IsWindowVisible", "Ptr", g.g.Hwnd))
                DllCall("SetWindowPos","Ptr",g.g.Hwnd,"Ptr",-1,"int",0,"int",0,"int",0,"int",0,"uint",0x0001 | 0x0002 | 0x0010)
        }
    }
}
_MostrarPaneles() {
    estabHwnd := IsObject(estabGui.g) ? estabGui.g.Hwnd : 0
    for g in [dial,dsGui,ccGui,arGui,hcGui,nvGui,lockGui,frenteGui,estabBtnGui,reloadGui,estabGui,puntosGui] {
        if !IsObject(g.g) || _EsPanelEmbebido(g)
            continue
        if (g.g.Hwnd = estabHwnd && (!estabGui.visible || !enfoque.activo))
            continue
        try {
            if !DllCall("IsWindowVisible","Ptr",g.g.Hwnd) {
                g.g.Show("NoActivate")
                if (g.g.Hwnd = estabHwnd)
                    _EstabDibujar()
            }
        }
    }
    ; Sanado de posicion: va aparte del show porque puntosGui no participa del ciclo
    ; de alpha, y estabGui se excluye (ya se autorrecorta con _EstabMonitorEn).
    for g in [dsGui,ccGui,arGui,hcGui,nvGui,lockGui,frenteGui,estabBtnGui,reloadGui,puntosGui,estabGui] {
        if !IsObject(g.g) || _EsPanelEmbebido(g)
            continue
        if (g.g.Hwnd = estabHwnd)
            continue
        _PanelSanarAmortiguado(g.g)
    }
}
; [FIX-PARPADEO] Sanado de posición amortiguado (watchdog de 500 ms). Solo corrige si la ventana se movió desde la
; última verificación; si tras 3 correcciones en 3 s sigue "peleando" con otro mover, deja de corregirla 15 s.
_PanelSanarAmortiguado(gp) {
    if _LBtnAbajo()
        return
    static est := Map()                       ; hwnd -> {rect, n, t0, hasta}
    try {
        hw := gp.Hwnd
        rc := Buffer(16, 0)
        if !DllCall("GetWindowRect", "Ptr", hw, "Ptr", rc)
            return
        ahora := A_TickCount
        antes := NumGet(rc, 0, "Int") "," NumGet(rc, 4, "Int") "," NumGet(rc, 8, "Int") "," NumGet(rc, 12, "Int")
        if !est.Has(hw)
            est[hw] := {rect: "", n: 0, t0: 0, hasta: 0}
        st := est[hw]
        if (ahora < st.hasta || antes = st.rect)
            return
        _PanelFijaEnPantalla(gp)
        DllCall("GetWindowRect", "Ptr", hw, "Ptr", rc)
        despues := NumGet(rc, 0, "Int") "," NumGet(rc, 4, "Int") "," NumGet(rc, 8, "Int") "," NumGet(rc, 12, "Int")
        st.rect := despues
        if (despues != antes) {
            if (ahora - st.t0 > 3000) {
                st.t0 := ahora
                st.n := 0
            }
            st.n += 1
            if (st.n >= 3) {
                st.hasta := ahora + 15000
                st.n := 0
            }
        }
    }
}
_ArrastrarPanelBloque(hwndClick,lParam,guiObj) {
    global panelBlk
    static arrastrando := false
    if (arrastrando)
        return
    if !IsObject(guiObj.g)
        return
    if !(hwndClick = guiObj.g.Hwnd || guiObj.g.Hwnd = DllCall("GetParent","Ptr",hwndClick,"Ptr"))
        return
    arrastrando := true
    try {
        if panelBlk.locked
            _SweepToggle(guiObj)
        else
            _ClickOArrastre(hwndClick,lParam,guiObj)
    } finally {
        arrastrando := false
    }
}

_GetPanelEstado(guiObj) {
    h := guiObj.g.Hwnd
    if (h = dsGui.g.Hwnd)
        return colorV.hover
    if (h = ccGui.g.Hwnd)
        return colorCC.hover
    if (h = arGui.g.Hwnd)
        return ar.hover
    if (h = hcGui.g.Hwnd)
        return (hist.modo = 1)
    if (h = frenteGui.g.Hwnd)
        return panelBlk.frente
    if (h = estabBtnGui.g.Hwnd)
        return estabGui.visible
    return ""
}

_SetPanelEstado(guiObj, target) {
    h := guiObj.g.Hwnd
    if (h = dsGui.g.Hwnd) {
        if (colorV.hover != target) {
            _SetColorV(target)
            ActualizarDsGUI()
        }
    } else if (h = ccGui.g.Hwnd) {
        if (colorCC.hover != target) {
            _SetColorCC(target)
            ActualizarCcGUI()
        }
    } else if (h = arGui.g.Hwnd) {
        if (ar.hover != target) {
            _SetAR(target)
            ActualizarArGUI()
        }
    } else if (h = hcGui.g.Hwnd) {
        if ((hist.modo = 1) != target) {
            _ToggleHistorialColor()
            ActualizarHCGUI()
        }
    } else if (h = frenteGui.g.Hwnd) {
        if (panelBlk.frente != target) {
            _ToggleFrente()
        }
    } else if (h = estabBtnGui.g.Hwnd) {
        if (estabGui.visible != target) {
            _ToggleEstabVisible()
        }
    }
}

_PanelesSweep() {
    lista := []
    for p in [dsGui, ccGui, arGui, hcGui, frenteGui, estabBtnGui] {
        if (IsObject(p) && IsObject(p.g) && p.g.Hwnd)
            lista.Push(p)
    }
    return lista
}

; Rect cerrado en pixeles [l, r-1] x [t, b-1] (GetWindowRect es exclusivo en r/b).
; Liang-Barsky: true si el segmento (x0,y0)-(x1,y1) toca el rectangulo.
_SegCruzaRect(x0,y0,x1,y1,l,t,r,b) {
    r -= 1
    b -= 1
    dx := x1 - x0
    dy := y1 - y0
    t0 := 0.0
    t1 := 1.0
    for pq in [[-dx, x0 - l], [dx, r - x0], [-dy, y0 - t], [dy, b - y0]] {
        p := pq[1]
        q := pq[2]
        if (p = 0) {
            if (q < 0)
                return false
            continue
        }
        u := q / p
        if (p < 0) {
            if (u > t1)
                return false
            if (u > t0)
                t0 := u
        } else {
            if (u < t0)
                return false
            if (u < t1)
                t1 := u
        }
    }
    return true
}

; Estado LÓGICO del clic izquierdo: válido para ratón y para pluma (XP-Pen/Windows Ink inyecta).
_LBtnAbajo() {
    return GetKeyState("LButton") || (DllCall("GetAsyncKeyState", "Int", 0x01, "Short") & 0x8000)
}

; ── Pulsación larga con la punta del lápiz sobre una píldora → menú del Hub ──
; El toque corto sigue haciendo la acción normal de la píldora. Si la punta se
; queda apoyada sin moverse, la acción se cancela y en su lugar se abre el menú.
_HubLPSt() {
    static st := Map("tLapiz", 0)
    return st
}

; Interruptor único. Para llevarlo a Opciones basta con que esa opción haga
; hubGui.lpLapiz := true/false (por defecto está activo).
_HubLPActivo() {
    global hubGui
    if (IsObject(hubGui) && hubGui.HasOwnProp("lpLapiz"))
        return hubGui.lpLapiz
    return true
}

; 0x0246 = WM_POINTERDOWN. Solo marca las pulsaciones hechas con lápiz (PT_PEN=3);
; el dedo (PT_TOUCH=2) y el ratón no activan la pulsación larga.
_HubLP_WM_POINTERDOWN(wParam, lParam, msg, hwnd) {
    if !_VentanaDelProceso(hwnd)
        return
    tipo := 0
    if !DllCall("GetPointerType", "UInt", wParam, "Int*", &tipo)
        return
    if (tipo != 3)
        return
    _HubLPSt()["tLapiz"] := A_TickCount
}

; ¿La pulsación que empieza ahora viene de la punta del lápiz?
_HubLPFueLapiz() {
    t := _HubLPSt()["tLapiz"]
    return (t && A_TickCount - t < 150)
}

; Umbral de pulsación larga (550 ms), sin movimiento y solo con lápiz.
_HubLPHecha(t0, movido, esLapiz) {
    return (esLapiz && !movido && _HubLPActivo() && A_TickCount - t0 >= 550)
}

; Cierra el gesto: abre el menú y evita que la píldora ejecute su acción.
_HubLPDisparar() {
    _HubLPSt()["tLapiz"] := 0
    SetTimer(_MostrarMenuContextualHub, -10)
}

; WM_SETREDRAW (0x000B). Al descongelar: RedrawWindow sincrono
; (INVALIDATE|ERASE|ALLCHILDREN|UPDATENOW = 0x0185) = un solo repintado por boton.
_CongelarPanel(h, congelar) {
    try {
        DllCall("SendMessage","Ptr",h,"UInt",0x000B,"Ptr",congelar ? 0 : 1,"Ptr",0)
        if !congelar
            DllCall("RedrawWindow","Ptr",h,"Ptr",0,"Ptr",0,"UInt",0x0185)
    }
}

; Aplica el estado a los botones barridos. frenteGui va en un segundo lote porque
; _ToggleFrente() llama _MostrarPaneles()/_TraerPanelesAlFrente() (usan IsWindowVisible).
_SweepAplicar(tocados, target) {
    global g_sweepAtomico
    grupo := []
    grupoFrente := []
    for p in tocados {
        if (p.g.Hwnd = frenteGui.g.Hwnd)
            grupoFrente.Push(p)
        else
            grupo.Push(p)
    }
    for lote in [grupo, grupoFrente] {
        if g_sweepAtomico {
            for p in lote
                _CongelarPanel(p.g.Hwnd, true)
        }
        try {
            for p in lote
                _SetPanelEstado(p, target)
        } finally {
            if g_sweepAtomico {
                for p in lote
                    _CongelarPanel(p.g.Hwnd, false)
            }
        }
    }
}

_SweepToggle(g0) {
    global g_sweepActivo
    if (!IsObject(g0) || !IsObject(g0.g))
        return
    if (g0.g.Hwnd = lockGui.g.Hwnd) {
        t0 := A_TickCount
        lp := _HubLPFueLapiz(), largo := false
        while _LBtnAbajo() {
            if (!largo && _HubLPHecha(t0, false, lp))
                largo := true
            Sleep(5)
        }
        if (largo) {
            _HubLPDisparar()
            return
        }
        _ToggleBloqueo()
        return
    }
    est := _GetPanelEstado(g0)
    if (est == "")
        return
    target := !est
    visitados := Map()
    visitados[g0.g.Hwnd] := true
    tocados := [g0]
    lp := _HubLPFueLapiz()
    Thread("NoTimers", true)   ; ningun timer interrumpe el muestreo ni repinta paneles durante el gesto
    DllCall("winmm\timeBeginPeriod","UInt",1)
    try {
        paneles := _PanelesSweep()
        cur := Buffer(8,0), rc := Buffer(16,0)
        ; Rects cacheados una vez: con el bloqueo puesto los paneles no se mueven durante el barrido.
        rects := []
        for p in paneles {
            h := p.g.Hwnd
            if visitados.Has(h) || !DllCall("IsWindowVisible","Ptr",h)
                continue
            DllCall("GetWindowRect","Ptr",h,"Ptr",rc)
            rects.Push({p:p, h:h, l:NumGet(rc,0,"int"), t:NumGet(rc,4,"int"), r:NumGet(rc,8,"int"), b:NumGet(rc,12,"int")})
        }
        DllCall("GetCursorPos","Ptr",cur)
        px := NumGet(cur,0,"int"), py := NumGet(cur,4,"int")
        t0 := A_TickCount
        movidoGesto := false, largo := false
        Loop {
            if GetKeyState("Escape","P") {   ; Esc = cancelar el gesto sin aplicar nada
                tocados := []
                break
            }
            soltado := !_LBtnAbajo() || (A_TickCount - t0 > 3000)   ; failsafe 3 s: aplica lo barrido
            DllCall("GetCursorPos","Ptr",cur)
            mx := NumGet(cur,0,"int"), my := NumGet(cur,4,"int")
            if (mx != px || my != py) {
                movidoGesto := true
                for rr in rects {
                    if visitados.Has(rr.h)
                        continue
                    if _SegCruzaRect(px,py,mx,my,rr.l,rr.t,rr.r,rr.b) {
                        visitados[rr.h] := true
                        tocados.Push(rr.p)
                    }
                }
                px := mx, py := my
            }
            if (!largo && _HubLPHecha(t0, movidoGesto, lp)) {
                largo := true            ; pulsación larga: no se barre, se abre al soltar
                tocados := []
            }
            if soltado
                break
            Sleep(1)
        }
        if (largo) {
            _HubLPDisparar()
            return
        }
        g_sweepActivo := true
        _SweepAplicar(tocados, target)
    } finally {
        DllCall("winmm\timeEndPeriod","UInt",1)
        g_sweepActivo := false
    }
}

_ClickOArrastre(hwndClick,lParam,guiObj) {
    global panelBlk
    pt := Buffer(8,0)
    NumPut("int",lParam & 0xFFFF,pt,0)
    NumPut("int",(lParam >> 16) & 0xFFFF,pt,4)
    DllCall("ClientToScreen","Ptr",hwndClick,"Ptr",pt)
    clickX := NumGet(pt,0,"int"), clickY := NumGet(pt,4,"int")
    rc := Buffer(16,0)
    DllCall("GetWindowRect","Ptr",guiObj.g.Hwnd,"Ptr",rc)
    offX := clickX - NumGet(rc,0,"int")
    offY := clickY - NumGet(rc,4,"int")
    cur := Buffer(8,0)
    movido := false
    lp := _HubLPFueLapiz(), t0 := A_TickCount, largo := false
    while _LBtnAbajo() {
        DllCall("GetCursorPos","Ptr",cur)
        mx := NumGet(cur,0,"int"), my := NumGet(cur,4,"int")
        if (Abs(mx - clickX) > 4 || Abs(my - clickY) > 4) {
            movido := true
            DllCall("SetWindowPos","Ptr",guiObj.g.Hwnd,"Ptr",0,"int",mx-offX,"int",my-offY
                ,"int",0,"int",0,"uint",0x0001|0x0004|0x0010)
        }
        if (!largo && _HubLPHecha(t0, movido, lp))
            largo := true
        else if (largo && movido)     ; si empieza a arrastrar, se cancela el menú
            largo := false
        Sleep(8)
    }
    if (largo) {
        _HubLPDisparar()
        return
    }
    if !movido {
        if (guiObj.g.Hwnd = lockGui.g.Hwnd)
            _ToggleBloqueo()
        else {
            est := _GetPanelEstado(guiObj)
            if (est != "")
                _SetPanelEstado(guiObj, !est)
        }
    } else {
        if (IsSet(_PosGuiMutearVigilante))
            _PosGuiMutearVigilante(2000)
        if (guiObj.g.Hwnd = dsGui.g.Hwnd) {
            GuardarPosicionGUI("Slider",dsGui.g.Hwnd)
            GuardarPosicionGUI("PanelBlock",dsGui.g.Hwnd)
        } else if (guiObj.g.Hwnd = ccGui.g.Hwnd) {
            GuardarPosicionGUI("Circle",ccGui.g.Hwnd)
        } else if (guiObj.g.Hwnd = arGui.g.Hwnd) {
            GuardarPosicionGUI("Quick",arGui.g.Hwnd)
        } else if (guiObj.g.Hwnd = hcGui.g.Hwnd) {
            GuardarPosicionGUI("HC",hcGui.g.Hwnd)
            _GuardarOffsetHC()
        } else if (guiObj.g.Hwnd = lockGui.g.Hwnd) {
            GuardarPosicionGUI("Lock",lockGui.g.Hwnd)
        } else if (guiObj.g.Hwnd = frenteGui.g.Hwnd) {
            GuardarPosicionGUI("Frente",frenteGui.g.Hwnd)
        } else if (guiObj.g.Hwnd = estabBtnGui.g.Hwnd) {
            GuardarPosicionGUI("EstabBtn",estabBtnGui.g.Hwnd)
        }
    }
}
_GuardarOffsetHC() {
    global PERFIL
    ini := _PosGuiIniPath()
    sec := "PanelBlock_p" PERFIL
    rd := Buffer(16,0)
    rh := Buffer(16,0)
    DllCall("GetWindowRect","Ptr",dsGui.g.Hwnd,"Ptr",rd)
    DllCall("GetWindowRect","Ptr",hcGui.g.Hwnd,"Ptr",rh)
    IniWrite(NumGet(rh,0,"int") - NumGet(rd,0,"int"),ini,sec,"hcdx")
    IniWrite(NumGet(rh,4,"int") - NumGet(rd,4,"int"),ini,sec,"hcdy")
}
_LeerEstadoBloque(clave,defecto) {
    global PERFIL
    ini := _PosGuiIniPath()
    v := IniRead(ini,"PanelBlock_p" PERFIL,clave,"")
    if (v = "")
        v := IniRead(ini,"PanelBlock",clave,defecto)
    return v
}
_EscribirEstadoBloque(clave,valor) {
    global PERFIL
    GuardarIniDiferido(_PosGuiIniPath(),"PanelBlock_p" PERFIL,clave,valor)
}
_ToggleBloqueo() {
    panelBlk.locked := !panelBlk.locked
    _EscribirEstadoBloque("locked",panelBlk.locked ? 1 : 0)
    ActualizarLockGUI()
    ActualizarHubGUI()
    MostrarHUD(panelBlk.locked ? "🔒 BLOQUE FIJADO" : "🔓 BLOQUE LIBRE",panelBlk.locked ? "44DD88" : "FF6B00",1200)
}
_HcOffsetBloque() {
    global ESC
    ini := _PosGuiIniPath()
    sec := "PanelBlock_p" PERFIL
    dx := IniRead(ini,sec,"hcdx","")
    dy := IniRead(ini,sec,"hcdy","")
    if (dx != "" && dy != "")
        return {dx:Integer(dx),dy:Integer(dy)}
    dx := IniRead(ini,"PanelBlock","hcdx","")
    dy := IniRead(ini,"PanelBlock","hcdy","")
    if (dx != "" && dy != "") {
        dx := Round(Integer(dx) * ESC)
        dy := Round(Integer(dy) * ESC)
        IniWrite(dx,ini,sec,"hcdx")
        IniWrite(dy,ini,sec,"hcdy")
        return {dx:dx,dy:dy}
    }
    rc := Buffer(16,0)
    DllCall("GetWindowRect","Ptr",dsGui.g.Hwnd,"Ptr",rc)
    ah := NumGet(rc,12,"int") - NumGet(rc,4,"int")
    return {dx:0,dy:ah + PANEL_GAP}
}
IniciarDialGUI() => 0
ActualizarDialGUI() {
    global opacidad
    if (!IsObject(dial.g) || !dial.icono)
        return
    if (dial.modo = 1) {
        dial.icono.Value := "🖌"
        dial.label.Value := "Tamaño"
        dial.barra.Opt("c00e5ff")
        dial.barra.Value := 100
    } else {
        dial.icono.Value := "◑"
        dial.label.Value := "Opacidad " opacidad.nivel "%"
        dial.barra.Opt("cff6b00")
        dial.barra.Value := opacidad.nivel
    }
}

; p = objeto con .g .label .barra (dsGui, ccGui, arGui, hcGui, estabBtnGui...)
; Devuelve el ancho final en px. Idempotente: no hace nada si el ancho no cambió.
_PillAjustar(p, txt, xTexto := 26, margenDer := 8) {
    w := _PillAnchoPara(txt, xTexto, margenDer)
    if (p.HasProp("wPx") && p.wPx = w)
        return w
    p.wPx := w
    p.label.Move(, , _AnchoTextoPill(txt) + _E(2))
    p.barra.Move(, , w)
    p.g.Move(, , w, _E(25))
    _DwmRedondear(p.g.Hwnd)
    return w
}

_PillW(p) {
    if (p.HasProp("wPx"))
        return p.wPx
    GetWindowRectSize(p.g.Hwnd, &w, &h)
    return w
}

IniciarDsGUI() {
    dsGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow","")
    dsGui.g.BackColor := _Tema("color","surface.off","424242")
    dsGui.g.MarginX := 0
    dsGui.g.MarginY := 0
    WinSetTransparent(_CompOp("pildora","op_rep","panel_ds",_AlphaTema("pill",235)),dsGui.g)
    dsGui.icono := dsGui.g.Add("Picture","x" _E(4) " y" _E(2) " w" _E(20) " h" _E(20) " BackgroundTrans","")
    dsGui.label := dsGui.g.Add("Text","x" _E(26) " y" _E(3) " w" (_AnchoBtn("SLIDER") - _E(28)) " h" _E(19) " cWhite","")
    GbSetFont(dsGui.label, _FS(9), 700)
    dsGui.barra := dsGui.g.Add("Progress","x0 y" _E(22) " w" _AnchoBtn("SLIDER") " h" _E(3))
    dsGui.barra.Visible := _PillFranja()
    OnMessage(0x0201,_DsGUI_WM_LBUTTONDOWN)
    dsGui.g.OnEvent("ContextMenu", (*) => _MostrarMenuContextualHub())
    posDs := LeerPosicionGUI("Slider")
    if !(IsObject(posDs) && _PosicionValidaEnPantalla(posDs.x,posDs.y))
        posDs := _AnclaBloquePaneles()
    _dsX := posDs.x, _dsY := posDs.y
    ClampPrimario(&_dsX, &_dsY, _AnchoBtn("SLIDER"), _E(25))
    dsGui.g.Show("x" _dsX " y" _dsY " w" _AnchoBtn("SLIDER") " h" _E(25) " NoActivate")
    _PillAjustar(dsGui, "SLIDER")
    ActualizarDsGUI()
}
ActualizarDsGUI() {
    if (colorV.hover) {
        _SetIcono(dsGui.icono,"slider_on",true)
        dsGui.label.Value := "SLIDER"
        dsGui.barra.Opt("c" _Tema("color","accent.estabSoft","B4C0DE"))
        dsGui.g.BackColor := _Tema("color","surface.on","636D83")
        GbSetFont(dsGui.label, _FS(9), 700, "Segoe UI", "c" _Tema("color","text.primary","FFFFFF"))
    } else {
        _SetIcono(dsGui.icono,"slider_off",false)
        dsGui.label.Value := "SLIDER"
        dsGui.barra.Opt("c" _Tema("color","track.pillOff","6A6A6A"))
        dsGui.g.BackColor := _Tema("color","surface.off","424242")
        GbSetFont(dsGui.label, _FS(9), 700, "Segoe UI", "c" _Tema("color","text.idle","B2B2B2"))
    }
    dsGui.barra.Value := 100
}
_DsGUI_WM_LBUTTONDOWN(wParam,lParam,msg,hwnd) => _ArrastrarPanelBloque(hwnd,lParam,dsGui)
IniciarCcGUI() {
    ccGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow","")
    ccGui.g.BackColor := _Tema("color","surface.off","424242")
    ccGui.g.MarginX := 0
    ccGui.g.MarginY := 0
    WinSetTransparent(_CompOp("pildora","op_rep","panel_cc",_AlphaTema("pill",235)),ccGui.g)
    ccGui.icono := ccGui.g.Add("Picture","x" _E(4) " y" _E(2) " w" _E(20) " h" _E(20) " BackgroundTrans","")
    ccGui.label := ccGui.g.Add("Text","x" _E(26) " y" _E(3) " w" (_AnchoBtn("CIRCLE") - _E(28)) " h" _E(19) " cWhite","")
    GbSetFont(ccGui.label, _FS(9), 700)
    ccGui.barra := ccGui.g.Add("Progress","x0 y" _E(22) " w" _AnchoBtn("CIRCLE") " h" _E(3))
    ccGui.barra.Visible := _PillFranja()
    OnMessage(0x0201,_CcGUI_WM_LBUTTONDOWN)
    ccGui.g.OnEvent("ContextMenu", (*) => _MostrarMenuContextualHub())
    posCc := LeerPosicionGUI("Circle")
    if (IsObject(posCc) && _PosicionValidaEnPantalla(posCc.x,posCc.y)) {
        ccX := posCc.x
        ccY := posCc.y
    } else {
        try {
            WinGetPos(&dsX,&dsY,&dsW,&dsH,"ahk_id " dsGui.g.Hwnd)
        } catch {
            ancla := _AnclaBloquePaneles()
            dsX := ancla.x
            dsY := ancla.y
            dsW := _AnchoBtn("SLIDER")
        }
        ccX := dsX + dsW + PANEL_GAP
        ccY := dsY
    }
    ClampPrimario(&ccX, &ccY, _AnchoBtn("CIRCLE"), _E(25))
    ccGui.g.Show("x" ccX " y" ccY " w" _AnchoBtn("CIRCLE") " h" _E(25) " NoActivate")
    _DwmRedondear(ccGui.g.Hwnd)
    ActualizarCcGUI()
}
ActualizarCcGUI() {
    if (colorCC.hover) {
        _SetIcono(ccGui.icono,"circle_on",true)
        ccGui.label.Value := "CIRCLE"
        ccGui.barra.Opt("c" _Tema("color","accent.estabSoft","B4C0DE"))
        ccGui.g.BackColor := _Tema("color","surface.on","636D83")
        GbSetFont(ccGui.label, _FS(9), 700, "Segoe UI", "c" _Tema("color","text.primary","FFFFFF"))
    } else {
        _SetIcono(ccGui.icono,"circle_off",false)
        ccGui.label.Value := "CIRCLE"
        ccGui.barra.Opt("c" _Tema("color","track.pillOff","6A6A6A"))
        ccGui.g.BackColor := _Tema("color","surface.off","424242")
        GbSetFont(ccGui.label, _FS(9), 700, "Segoe UI", "c" _Tema("color","text.idle","B2B2B2"))
    }
    ccGui.barra.Value := 100
}
_CcGUI_WM_LBUTTONDOWN(wParam,lParam,msg,hwnd) => _ArrastrarPanelBloque(hwnd,lParam,ccGui)
IniciarArGUI() {
    arGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow","")
    arGui.g.BackColor := _Tema("color","surface.off","424242")
    arGui.g.MarginX := 0
    arGui.g.MarginY := 0
    WinSetTransparent(_AlphaTema("pill",235),arGui.g)
    arGui.icono := arGui.g.Add("Picture","x" _E(4) " y" _E(2) " w" _E(20) " h" _E(20) " BackgroundTrans","")
    arGui.label := arGui.g.Add("Text","x" _E(26) " y" _E(3) " w" (_AnchoBtn("QUICK") - _E(28)) " h" _E(19) " cWhite","")
    GbSetFont(arGui.label, _FS(9), 700)
    arGui.barra := arGui.g.Add("Progress","x0 y" _E(22) " w" _AnchoBtn("QUICK") " h" _E(3))
    arGui.barra.Visible := _PillFranja()
    OnMessage(0x0201,_ArGUI_WM_LBUTTONDOWN)
    arGui.g.OnEvent("ContextMenu", (*) => _MostrarMenuContextualHub())
    posAr := LeerPosicionGUI("Quick")
    if (IsObject(posAr) && _PosicionValidaEnPantalla(posAr.x,posAr.y)) {
        arX := posAr.x
        arY := posAr.y
    } else {
        try {
            WinGetPos(&ccX,&ccY,&ccW,&ccH,"ahk_id " ccGui.g.Hwnd)
        } catch {
            ancla := _AnclaBloquePaneles()
            ccX := ancla.x + _AnchoBtn("SLIDER") + PANEL_GAP
            ccY := ancla.y
            ccW := _AnchoBtn("CIRCLE")
        }
        arX := ccX + ccW + PANEL_GAP
        arY := ccY
    }
    ClampPrimario(&arX, &arY, _AnchoBtn("QUICK"), _E(25))
    arGui.g.Show("x" arX " y" arY " w" _AnchoBtn("QUICK") " h" _E(25) " NoActivate")
    _DwmRedondear(arGui.g.Hwnd)
    ActualizarArGUI()
}
ActualizarArGUI() {
    if (ar.hover) {
        _SetIcono(arGui.icono,"quick_on",true)
        arGui.label.Value := "QUICK"
        arGui.barra.Opt("c" _Tema("color","accent.estabSoft","B4C0DE"))
        arGui.g.BackColor := _Tema("color","surface.on","636D83")
        GbSetFont(arGui.label, _FS(9), 700, "Segoe UI", "c" _Tema("color","text.primary","FFFFFF"))
    } else {
        _SetIcono(arGui.icono,"quick_off",false)
        arGui.label.Value := "QUICK"
        arGui.barra.Opt("c" _Tema("color","track.pillOff","6A6A6A"))
        arGui.g.BackColor := _Tema("color","surface.off","424242")
        GbSetFont(arGui.label, _FS(9), 700, "Segoe UI", "c" _Tema("color","text.idle","B2B2B2"))
    }
    arGui.barra.Value := 100
}
_ArGUI_WM_LBUTTONDOWN(wParam,lParam,msg,hwnd) => _ArrastrarPanelBloque(hwnd,lParam,arGui)
IniciarHCGUI() {
    hcGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow","")
    hcGui.g.BackColor := _Tema("color","surface.off","424242")
    hcGui.g.MarginX := 0
    hcGui.g.MarginY := 0
    WinSetTransparent(_AlphaTema("pill",235),hcGui.g)
    hcGui.icono := hcGui.g.Add("Picture","x" _E(4) " y" _E(2) " w" _E(20) " h" _E(20) " BackgroundTrans","")
    hcGui.label := hcGui.g.Add("Text","x" _E(26) " y" _E(3) " w" (_AnchoBtn("HC") - _E(28)) " h" _E(19) " cWhite","")
    GbSetFont(hcGui.label, _FS(9), 700)
    hcGui.barra := hcGui.g.Add("Progress","x0 y" _E(22) " w" _AnchoBtn("HC") " h" _E(3))
    hcGui.barra.Visible := _PillFranja()
    OnMessage(0x0201,_HCGUI_WM_LBUTTONDOWN)
    hcGui.g.OnEvent("ContextMenu", (*) => _MostrarMenuContextualHub())
    posHc := LeerPosicionGUI("HC")
    if (IsObject(posHc) && _PosicionValidaEnPantalla(posHc.x,posHc.y)) {
        x := posHc.x
        y := posHc.y
    } else {
        try {
            WinGetPos(&aX,&aY,,,"ahk_id " dsGui.g.Hwnd)
        } catch {
            ancla := _AnclaBloquePaneles()
            aX := ancla.x
            aY := ancla.y
        }
        off := _HcOffsetBloque()
        x := aX + off.dx
        y := aY + off.dy
    }
    ClampPrimario(&x, &y, _AnchoBtn("HC"), _E(25))
    hcGui.g.Show("x" x " y" y " w" _AnchoBtn("HC") " h" _E(25) " NoActivate")
    _DwmRedondear(hcGui.g.Hwnd)
    ActualizarHCGUI()
}
ActualizarHCGUI() {
    if (hist.modo = 1) {
        _SetIcono(hcGui.icono,"hist_on",true)
        hcGui.label.Value := "HC"
        hcGui.barra.Opt("c" _Tema("color","accent.estabSoft","B4C0DE"))
        hcGui.g.BackColor := _Tema("color","surface.on","636D83")
        GbSetFont(hcGui.label, _FS(9), 700, "Segoe UI", "c" _Tema("color","text.primary","FFFFFF"))
    } else {
        _SetIcono(hcGui.icono,"hist_on",false)
        hcGui.label.Value := "HC"
        hcGui.barra.Opt("c" _Tema("color","track.pillOff","6A6A6A"))
        hcGui.g.BackColor := _Tema("color","surface.off","424242")
        GbSetFont(hcGui.label, _FS(9), 700, "Segoe UI", "c" _Tema("color","text.idle","B2B2B2"))
    }
    hcGui.barra.Value := 100
}
_HCGUI_WM_LBUTTONDOWN(wParam,lParam,msg,hwnd) => _ArrastrarPanelBloque(hwnd,lParam,hcGui)

IniciarNVGUI() {
    global nvGui
    nvGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow", "")
    nvGui.g.BackColor := _Tema("color", "surface.off", "424242")
    WinSetTransparent(_AlphaTema("pill", 235), nvGui.g)
    nvGui.label := nvGui.g.Add("Text", "x" _E(8) " y" _E(3) " w" _E(54) " h" _E(19) " cWhite BackgroundTrans", "WINDOW")
    GbSetFont(nvGui.label, _FS(9), 700)
    nvGui.btnCrear := nvGui.g.Add("Text", "x" _E(64) " y" _E(1) " w" _E(16) " h" _E(20) " Center cWhite BackgroundTrans", "➕")
    GbSetFont(nvGui.btnCrear, _FS(9), 700)
    nvGui.barra := nvGui.g.Add("Progress", "x0 y" _E(22) " w" _E(88) " h" _E(3))
    nvGui.barra.Visible := _PillFranja()
    nvGui.g.OnEvent("ContextMenu", (*) => SetTimer(_NvMostrarMenu, -15))
    OnMessage(0x0201, _NvGUI_WM_LBUTTONDOWN)
    ActualizarNVGUI()
    x := 20, y := 140
    _nvp := LeerPosicionGUI("NV")
    if (IsObject(_nvp) && _PosicionValidaEnPantalla(_nvp.x, _nvp.y))
        x := _nvp.x, y := _nvp.y
    nvGui.g.Show("x" x " y" y " w" _E(88) " h" _E(25) " NoActivate")
    _DwmRedondear(nvGui.g.Hwnd)
    nvGui.g.Hide()
    NvRehidratar()                                    ; ventanas separadas sobreviven a la recarga del script
    SetTimer(ActualizarNVGUI, 500)
}

ActualizarNVGUI(forzar := false) {
    global nvGui
    static clave := ""
    if !IsObject(nvGui.g)
        return
    e := NvEstado()
    vis := _NvEstadoVisual(e)
    nueva := nvGui.g.Hwnd "|" vis "|" e.modoGlobal "|" e.ventanas.Count "|" e.fijas.Count
    if (!forzar && nueva = clave)
        return                       ; sin cambio visual: no tocar BackColor/fuente
    nvGui.label.Text := "WINDOW"
    if (vis = "on") {
        nvGui.barra.Opt("c" _Tema("color", "accent.estabSoft", "B4C0DE"))
        nvGui.g.BackColor := _Tema("color", "surface.on", "636D83")
        GbSetFont(nvGui.label, _FS(9), 700, "Segoe UI", "c" _Tema("color", "text.primary", "FFFFFF"))
    } else if (vis = "off") {
        nvGui.barra.Opt("c" _Tema("color", "track.pillOff", "6A6A6A"))
        nvGui.g.BackColor := _Tema("color", "surface.off", "424242")
        GbSetFont(nvGui.label, _FS(9), 700, "Segoe UI", "c" _Tema("color", "text.idle", "B2B2B2"))
    } else {                                          ; mixto
        nvGui.barra.Opt("c" _Tema("color", "accent.estabSoft", "B4C0DE"))
        nvGui.g.BackColor := _Tema("color", "surface.off", "424242")
        GbSetFont(nvGui.label, _FS(9), 700, "Segoe UI", "c" _Tema("color", "text.idle", "B2B2B2"))
    }
    nvGui.barra.Value := 100
    clave := nueva
}

_NvGUI_WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global nvGui, panelBlk
    if !IsObject(nvGui.g)
        return
    if (DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr") != nvGui.g.Hwnd)
        return
    ; Clic en el botón ➕ para crear ventana sin necesidad de atajos complejos
    if (HasProp(nvGui, "btnCrear") && IsObject(nvGui.btnCrear) && hwnd = nvGui.btnCrear.Hwnd) {
        _NvBotonCrearVentana()
        return 0
    }
    st := _NvClicSt()
    if st["trk"]
        return 0
    pt := Buffer(8, 0)
    DllCall("GetCursorPos", "Ptr", pt)
    st["x0"] := NumGet(pt, 0, "Int")
    st["y0"] := NumGet(pt, 4, "Int")
    st["t0"] := A_TickCount
    st["lp"] := _HubLPFueLapiz()
    st["largo"] := false
    st["trk"] := true
    SetTimer(_NvClicPoll, 15)
    return 0
}

_NvClicSt() {
    static st := Map("trk", false, "pend", false, "x0", 0, "y0", 0, "t0", 0, "tPrev", 0, "lp", false, "largo", false)
    return st
}

_NvClicFin() {
    SetTimer(_NvClicPoll, 0)
    _NvClicSt()["trk"] := false
}

; Sondeo del gesto (hilo propio, el handler de mensajes ya retornó)
_NvClicPoll() {
    global nvGui, panelBlk
    st := _NvClicSt()
    if !st["trk"] {
        SetTimer(_NvClicPoll, 0)
        return
    }
    if _LBtnAbajo() {
        pt := Buffer(8, 0)
        DllCall("GetCursorPos", "Ptr", pt)
        if (Abs(NumGet(pt, 0, "Int") - st["x0"]) > 4 || Abs(NumGet(pt, 4, "Int") - st["y0"]) > 4) {
            _NvClicFin()
            SetTimer(_NvClicSimple, 0)
            st["pend"] := false
            if (IsSet(panelBlk) && IsObject(panelBlk) && panelBlk.locked)
                return
            DllCall("ReleaseCapture")
            PostMessage(0xA1, 2, , , nvGui.g)
            SetTimer(_NvGUI_EsperarSoltar, 100)
        } else if (_HubLPHecha(st["t0"], false, st["lp"])) {   ; pulsación larga: se abre al soltar
            st["largo"] := true
        } else if (A_TickCount - st["t0"] > 5000) {   ; seguridad: contacto atascado
            _NvClicFin()
            st["pend"] := false
        }
        return
    }
    _NvClicFin()                                       ; botón soltado sin arrastre
    if st["largo"] {
        st["largo"] := false
        st["pend"] := false
        _HubLPDisparar()
        return
    }
    dbl := Min(Max(DllCall("GetDoubleClickTime", "UInt"), 200), 500)
    if (st["pend"] && st["t0"] - st["tPrev"] <= dbl) { ; 2.º clic dentro del intervalo
        SetTimer(_NvClicSimple, 0)
        st["pend"] := false
        SetTimer(_NvMostrarMenu, -1)
        return
    }
    st["pend"] := true
    st["tPrev"] := st["t0"]
    SetTimer(_NvClicSimple, -dbl)
}

_NvClicSimple() {
    st := _NvClicSt()
    if st["trk"]            ; hay un 2.º gesto en curso: que él decida
        return
    st["pend"] := false
    NvAlternarInteractivo()
}

_NvGUI_EsperarSoltar() {
    global nvGui
    if _LBtnAbajo()
        return
    SetTimer(_NvGUI_EsperarSoltar, 0)
    WinGetPos(&x, &y, , , nvGui.g)
    if (x < -10000 || y < -10000)
        return
    static _ux := "", _uy := ""
    if (x = _ux && y = _uy)
        return
    _ux := x, _uy := y
    if (IsSet(_PosGuiMutearVigilante))
        _PosGuiMutearVigilante(2000)
    GuardarPosicionGUI("NV", nvGui.g.Hwnd)
}

_NvBotonCrearVentana(*) {
    z := NvSiguienteZona()
    if (z = "") {
        try MostrarHUD("Nuevas ventanas: todas las zonas están ocupadas", "9A7BFF", 1400)
        return
    }
    r := NuevaVentanaEnZona(z)
    try MostrarHUD("Nueva ventana (" z "): " r, "9A7BFF", 1400)
}

; ── Panel emergente WINDOW (reemplaza Menu() nativo; compatible con stylus) ──
_NvPanelSt() {
    static st := Map("g", 0, "acc", Map(), "t", 0)
    return st
}

_NvPanelAplicarGlobal(modo, *) => _NvMenuGlobal(modo, "", 0, "")
_NvPanelAplicarIndiv(h, modo, *) => _NvMenuIndividual(h, modo, "", 0, "")

_NvPanelBoton(g, acc, x, y, w, h, txt, fn, activo := false) {
    bg := activo ? _Tema("color", "accent.on", "3D7EDB") : _Tema("color", "surface.on", "525252")
    t := g.Add("Text", "x" x " y" y " w" w " h" h " 0x200 0x100 Center cWhite Background" bg, txt)
    acc[t.Hwnd] := fn
    return t
}

_NvPanelClamp(&x, &y, w, h) {
    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
        if (x >= l && x < r && y >= t && y < b) {
            x := Max(l, Min(x, r - w))
            y := Max(t, Min(y, b - h))
            return
        }
    }
}

_NvPanelCerrar() {
    st := _NvPanelSt()
    SetTimer(_NvPanelVigilar, 0)
    OnMessage(0x0201, _NvPanel_WM_LBUTTONDOWN, 0)
    OnMessage(0x0246, _NvPanel_WM_POINTERDOWN, 0)
    g := st["g"]
    st["g"] := 0
    st["acc"] := Map()
    if IsObject(g)
        try g.Destroy()
}

_NvPanelEjecutarEn(hwnd) {
    st := _NvPanelSt()
    if (!IsObject(st["g"]) || !st["acc"].Has(hwnd))
        return false
    fn := st["acc"][hwnd]
    _NvPanelCerrar()
    SetTimer(fn, -30)
    return true
}

_NvPanel_WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    if _NvPanelEjecutarEn(hwnd)
        return 0
}

_NvPanel_WM_POINTERDOWN(wParam, lParam, msg, hwnd) {
    px := lParam << 48 >> 48
    py := lParam << 32 >> 48
    hw := DllCall("WindowFromPoint", "Int64", (py << 32) | (px & 0xFFFFFFFF), "Ptr")
    if _NvPanelEjecutarEn(hw)
        return 0
}

_NvPanelVigilar() {
    static ultElev := 0
    st := _NvPanelSt()
    g := st["g"]
    if !IsObject(g) {
        SetTimer(_NvPanelVigilar, 0)
        return
    }
    ; [Z-ORDER] las píldoras del companion son topmost: si alguna queda encima, re-elevar el menú
    prev := DllCall("GetWindow", "Ptr", g.Hwnd, "UInt", 3)   ; GW_HWNDPREV
    if (prev && A_TickCount - ultElev > 250 && DllCall("IsWindowVisible", "Ptr", prev) && _VentanaDelProceso(prev)) {
        ultElev := A_TickCount
        ; HWND_TOP (0): sube dentro de la banda topmost; HWND_TOPMOST sobre ventana ya topmost puede no reordenar
        DllCall("SetWindowPos", "Ptr", g.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
    }
    if GetKeyState("Escape", "P") {
        _NvPanelCerrar()
        return
    }
    CoordMode("Mouse", "Screen")
    MouseGetPos(, , &win)
    if (win = g.Hwnd) {
        st["t"] := A_TickCount
        return
    }
    if (GetKeyState("LButton", "P") || GetKeyState("RButton", "P") || A_TickCount - st["t"] > 6000)
        _NvPanelCerrar()
}

; ¿La ventana pertenece a este script? (para detectar píldoras propias en el z-order)
_VentanaDelProceso(h) {
    pid := 0
    try DllCall("GetWindowThreadProcessId", "Ptr", h, "UInt*", &pid)
    return (pid != 0 && pid = DllCall("GetCurrentProcessId", "UInt"))
}

_NvMostrarMenu() {
    global stylus, nvGui
    e := NvEstado()
    st0 := _NvPanelSt()
    if (IsObject(st0["g"]) && A_TickCount - st0["t"] < 600)
        return                       ; antirrebote: 2.ª apertura no destruye/recrea
    _NvPanelCerrar()
    _HubPanelCerrar()               ; nunca dos paneles propios a la vez
    if (IsSet(stylus) && IsObject(stylus)) {
        stylus.rButtonHeld := false
        stylus.comboUsado := true
    }
    KeyWait("RButton", "T0.25")
    KeyWait("LButton", "T0.25")
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)

    GP := _E(2), RH := _E(24), PADB := _E(16)
    bw := (t) => _AnchoTextoPill(t) + PADB
    lblNueva := "1)  + VENTANA"
    lblHovOn := "2)  HOOVER ON"
    lblHovOff := "2)  HOOVER OFF"
    lblDesOn := "3)  DESACTIVADO"
    lblDesOff := "3)  ACTIVADO"
    wTog := Max(bw(lblHovOn), bw(lblHovOff))
    wDes := Max(bw(lblDesOn), bw(lblDesOff))
    wHov := Max(bw("HOOVER ON"), bw("HOOVER OFF"))
    wDi := Max(bw("🚫"), bw("✔"), _E(18))
    wNum := Max(_AnchoTextoPill("88)") + _E(6), _E(18))
    wNeed := Max(bw(lblNueva), wTog, wDes)
    filas := []
    i := 0
    for h, zona in e.ventanas {
        i++
        filas.Push({h: h, n: i})
        wNeed := Max(wNeed, wNum + GP + wHov + GP + wDi + _E(10))
    }
    ; [P-WINDOW-2] filas condicionales: sólo existen si hay libres / retomables
    libres := _NvDocsLibres()
    retom := _NvDocsRetomables()
    nL := libres.Length
    nR := retom.Length
    txtL := (nL = 1) ? "📥 Embeber ventana libre (1)" : "📥 Embeber " nL " ventanas libres"
    txtR := "🧲 Retomar control (" nR ")"
    if nL
        wNeed := Max(wNeed, bw(txtL))
    if nR
        wNeed := Max(wNeed, bw(txtR))
    CWd := wNeed
    W := CWd + 2 * GP

    acc := Map()
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +Border +E0x08000000", "")
    g.BackColor := _Tema("color", "surface.off", "424242")
    g.MarginX := 0
    g.MarginY := 0
    GbSetFont(g, _FS(9))

    y := GP
    ; Fila 1: Primer panel nueva ventana
    _NvPanelBoton(g, acc, GP, y, CWd, RH, lblNueva, _NvBotonCrearVentana)
    y += RH + GP

    ; Fila 2: HOOVER ON / HOOVER OFF (toggle que alterna entre los 2)
    hoverOn := (e.modoGlobal = "h_on" || e.modoGlobal = "")
    _NvPanelBoton(g, acc, GP, y, CWd, RH, hoverOn ? lblHovOn : lblHovOff
        , _NvPanelAplicarGlobal.Bind(hoverOn ? "h_off" : "h_on"), hoverOn)
    y += RH + GP

    ; Fila 3: DESACTIVADO / ACTIVADO (toggle que alterna entre desactivado 15% y activo)
    desG := (e.modoGlobal = "desact_25" || e.modoGlobal = "desact_15")
    _NvPanelBoton(g, acc, GP, y, CWd, RH, desG ? lblDesOn : lblDesOff
        , _NvPanelAplicarGlobal.Bind(desG ? "h_on" : "desact_25"), desG)
    y += RH + GP

    ; [P-WINDOW-2] Fila 4: embeber libres (sólo si hay)
    if nL {
        _NvPanelBoton(g, acc, GP, y, CWd, RH, txtL, _NvBotonEmbeber)
        y += RH + GP
    }
    ; [P-WINDOW-2] Fila 5: retomar control (sólo si hay con firma sin registrar)
    if nR {
        _NvPanelBoton(g, acc, GP, y, CWd, RH, txtR, _NvBotonRetomar)
        y += RH + GP
    }

    ; Separador blanco y filas individuales
    if (filas.Length) {
        g.Add("Text", "x" GP " y" y " w" CWd " h1 BackgroundWhite")
        y += 1 + GP
        for f in filas {
            ef := _NvModoEfectivo(e, f.h)
            act := (ef = "h_on")
            desF := (ef = "desact_25" || ef = "desact_15")
            xNum := GP + _E(6)
            num := g.Add("Text", "x" xNum " y" y " w" wNum " h" RH
                " 0x4000 cWhite BackgroundTrans", f.n ")")
            GbSetFont(num, _FS(9), 700)
            xHov := xNum + wNum + GP
            xIcon := xHov + wHov + GP
            _NvPanelBoton(g, acc, xHov, y, wHov, RH, act ? "HOOVER ON" : "HOOVER OFF"
                , _NvPanelAplicarIndiv.Bind(f.h, act ? "h_off" : "h_on"), act)
            _NvPanelBoton(g, acc, xIcon, y, wDi, RH, desF ? "🚫" : "✔"
                , _NvPanelAplicarIndiv.Bind(f.h, desF ? "h_on" : "desact_25"), desF)
            y += RH + GP
        }
    }

    H := y
    px := mx, py := my
    if (IsObject(nvGui.g) && DllCall("IsWindowVisible", "Ptr", nvGui.g.Hwnd)) {
        WinGetPos(&gx, &gy, &gw, &gh, "ahk_id " nvGui.g.Hwnd)
        px := gx                                   ; nace en la esquina inferior izquierda
        py := gy + gh                              ; y crece hacia abajo/derecha
        Loop MonitorGetCount() {
            MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
            if (gx >= l && gx < r && gy >= t && gy < b) {
                if (px + W > r)                    ; sin sitio a la derecha: lado opuesto
                    px := gx + gw - W
                break
            }
        }
    }
    _NvPanelClamp(&px, &py, W, H)
    st := _NvPanelSt()
    st["g"] := g
    st["acc"] := acc
    st["t"] := A_TickCount
    g.Show("x" px " y" py " w" W " h" H " NoActivate Hide")
    _DwmRedondear(g.Hwnd)
    ; topmost mientras está oculto: no existe ningún fotograma con una píldora encima del menú
    DllCall("SetWindowPos", "Ptr", g.Hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
    g.Show("NoActivate")
    DllCall("SetWindowPos", "Ptr", g.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
    OnMessage(0x0201, _NvPanel_WM_LBUTTONDOWN)
    OnMessage(0x0246, _NvPanel_WM_POINTERDOWN)
    SetTimer(_NvPanelVigilar, 50)
}

_NvMenuGlobal(modo, *) {
    NvSetGlobal(modo)
}

_NvMenuIndividual(h, modo, *) {
    NvSetIndividual(h, modo)
}

IniciarLockGUI() {
    global panelBlk
    panelBlk.locked := (_LeerEstadoBloque("locked","1") = "1")
    panelBlk.clicAuto := (_LeerEstadoBloque("clicAuto","1") = "1")
    lockGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow","")
    lockGui.g.BackColor := _Tema("color","surface.off","424242")
    lockGui.g.MarginX := 0
    lockGui.g.MarginY := 0
    WinSetTransparent(_CompOp("pildora","op_rep","history_lock",_AlphaTema("pill",235)),lockGui.g)
    lockGui.icono := lockGui.g.Add("Picture","x" _E(6) " y" _E(2) " w" _E(19) " h" _E(19) " BackgroundTrans","")
    lockGui.barra := lockGui.g.Add("Progress","x0 y" _E(22) " w" _E(31) " h" _E(3))
    lockGui.barra.Visible := _PillFranja()
    OnMessage(0x0201,_LockGUI_WM_LBUTTONDOWN)
    OnMessage(0x0205,_Companion_WM_RBUTTON)
    lockGui.g.OnEvent("ContextMenu", (*) => _MostrarMenuContextualHub())
    posLock := LeerPosicionGUI("Lock")
    if (IsObject(posLock) && _PosicionValidaEnPantalla(posLock.x,posLock.y)) {
        lockX := posLock.x
        lockY := posLock.y
    } else {
        try {
            WinGetPos(&arX,&arY,&arW,&arH,"ahk_id " arGui.g.Hwnd)
        } catch {
            ancla := _AnclaBloquePaneles()
            arX := ancla.x + _AnchoBtn("SLIDER") + _AnchoBtn("CIRCLE") + 2 * PANEL_GAP
            arY := ancla.y
            arW := _AnchoBtn("QUICK")
        }
        lockX := arX + arW + PANEL_GAP
        lockY := arY
    }
    ClampPrimario(&lockX, &lockY, _E(31), _E(25))
    lockGui.g.Show("x" lockX " y" lockY " w" _E(31) " h" _E(25) " NoActivate")
    _DwmRedondear(lockGui.g.Hwnd)
    ActualizarLockGUI()
}
ActualizarLockGUI() {
    if (panelBlk.locked) {
        _SetIcono(lockGui.icono,"lock_closed",false)
        lockGui.barra.Opt("c" _Tema("color","track.pillOff","6A6A6A"))
        lockGui.g.BackColor := _Tema("color","surface.off","424242")
    } else {
        _SetIcono(lockGui.icono,"lock_open",true)
        lockGui.barra.Opt("c" _Tema("color","accent.estabSoft","B4C0DE"))
        lockGui.g.BackColor := _Tema("color","surface.on","636D83")
    }
    lockGui.barra.Value := 100
    if IsObject(estabGui.grip)
        estabGui.grip.Visible := !panelBlk.locked
    if IsObject(estabGui.g)
        try {
            estabGui.g.BackColor := panelBlk.locked ? _Tema("color","surface.estabLocked","2B2B2B") : _Tema("color","surface.estabOpen","3A4260")
            ActualizarEstabGUI(-1)
        }
}
_LockGUI_WM_LBUTTONDOWN(wParam,lParam,msg,hwnd) => _ArrastrarPanelBloque(hwnd,lParam,lockGui)
IniciarFrenteGUI() {
    global panelBlk
    panelBlk.frente := (_LeerEstadoBloque("frente","0") = "1")
    frenteGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow","")
    frenteGui.g.BackColor := _Tema("color","surface.off","424242")
    frenteGui.g.MarginX := 0
    frenteGui.g.MarginY := 0
    WinSetTransparent(_CompOp("pildora","op_rep","gui_frente",_AlphaTema("pill",235)),frenteGui.g)
    frenteGui.icono := frenteGui.g.Add("Picture","x" _E(6) " y" _E(2) " w" _E(19) " h" _E(19) " BackgroundTrans","")
    frenteGui.barra := frenteGui.g.Add("Progress","x0 y" _E(22) " w" _E(31) " h" _E(3))
    frenteGui.barra.Visible := _PillFranja()
    OnMessage(0x0201,_FrenteGUI_WM_LBUTTONDOWN)
    frenteGui.g.OnEvent("ContextMenu", (*) => _MostrarMenuContextualHub())
    posF := LeerPosicionGUI("Frente")
    if (IsObject(posF) && _PosicionValidaEnPantalla(posF.x,posF.y)) {
        fX := posF.x
        fY := posF.y
    } else {
        try {
            WinGetPos(&lX,&lY,&lW,&lH,"ahk_id " lockGui.g.Hwnd)
        } catch {
            ancla := _AnclaBloquePaneles()
            lX := ancla.x + _AnchoBtn("SLIDER") + _AnchoBtn("CIRCLE") + _AnchoBtn("QUICK") + 3 * PANEL_GAP
            lY := ancla.y
            lW := _E(31)
        }
        fX := lX + lW + PANEL_GAP
        fY := lY
    }
    sf := _RectaDentroDeMonitor(fX,fY,_E(31),_E(25)) ? {x:fX,y:fY} : _EsquinaPanelBloque(0)
    _sfX := sf.x, _sfY := sf.y
    ClampPrimario(&_sfX, &_sfY, _E(31), _E(25))
    frenteGui.g.Show("x" _sfX " y" _sfY " w" _E(31) " h" _E(25) " NoActivate")
    _DwmRedondear(frenteGui.g.Hwnd)
    ActualizarFrenteGUI()
}
ActualizarFrenteGUI() {
    if !IsObject(frenteGui.icono)
        return
    if panelBlk.frente {
        _SetIcono(frenteGui.icono,"pin_on",true)
        frenteGui.barra.Opt("c" _Tema("color","accent.estabSoft","B4C0DE"))
        frenteGui.g.BackColor := _Tema("color","surface.on","636D83")
    } else {
        _SetIcono(frenteGui.icono,"pin_off")
        frenteGui.barra.Opt("c" _Tema("color","track.pillOff","6A6A6A"))
        frenteGui.g.BackColor := _Tema("color","surface.off","424242")
    }
    frenteGui.barra.Value := 100
}
_FrenteGUI_WM_LBUTTONDOWN(wParam,lParam,msg,hwnd) => _ArrastrarPanelBloque(hwnd,lParam,frenteGui)
_ToggleFrente() {
    global panelBlk
    panelBlk.frente := !panelBlk.frente
    _EscribirEstadoBloque("frente",panelBlk.frente ? 1 : 0)
    ActualizarFrenteGUI()
    ActualizarHubGUI()
    if panelBlk.frente {
        _MostrarPaneles()
        _TraerPanelesAlFrente()
    } else {
        if !WinActive("ahk_exe CLIPStudioPaint.exe") {
            for g in [dial,dsGui,ccGui,arGui,hcGui,nvGui,lockGui,frenteGui,estabBtnGui,reloadGui,estabGui] {
                if IsObject(g.g)
                    g.g.Hide()
            }
        }
    }
    MostrarHUD(panelBlk.frente ? "📌 GUI AL FRENTE" : "📌 GUI SOLO EN CSP",panelBlk.frente ? _Tema("color","accent.success","44DD88") : _Tema("color","accent.warn","FF6B00"),1200)
}
IniciarEstabBtnGUI() {
    estabBtnGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow","")
    estabBtnGui.g.BackColor := _Tema("color","surface.off","424242")
    estabBtnGui.g.MarginX := 0
    estabBtnGui.g.MarginY := 0
    WinSetTransparent(_CompOp("pildora","op_rep","estab_slider",_AlphaTema("pill",235)),estabBtnGui.g)
    estabBtnGui.icono := estabBtnGui.g.Add("Picture","x" _E(4) " y" _E(2) " w" _E(20) " h" _E(20) " BackgroundTrans","")
    estabBtnGui.label := estabBtnGui.g.Add("Text","x" _E(26) " y" _E(3) " w" (_AnchoBtn("ESTAB") - _E(28)) " h" _E(19) " cWhite","")
    GbSetFont(estabBtnGui.label, _FS(9), 700)
    estabBtnGui.barra := estabBtnGui.g.Add("Progress","x0 y" _E(22) " w" _AnchoBtn("ESTAB") " h" _E(3))
    estabBtnGui.barra.Visible := _PillFranja()
    OnMessage(0x0201,_EstabBtnGUI_WM_LBUTTONDOWN)
    estabBtnGui.g.OnEvent("ContextMenu", (*) => _MostrarMenuContextualHub())
    posB := LeerPosicionGUI("EstabBtn")
    if (IsObject(posB) && _PosicionValidaEnPantalla(posB.x,posB.y)) {
        eX := posB.x
        eY := posB.y
    } else {
        try {
            WinGetPos(&fX,&fY,&fW,&fH,"ahk_id " frenteGui.g.Hwnd)
        } catch {
            ancla := _AnclaBloquePaneles()
            fX := ancla.x + _AnchoBtn("SLIDER") + _AnchoBtn("CIRCLE") + _AnchoBtn("QUICK") + 4 * PANEL_GAP + _E(31)
            fY := ancla.y
            fW := _E(31)
        }
        eX := fX + fW + PANEL_GAP
        eY := fY
    }
    se := _RectaDentroDeMonitor(eX,eY,_AnchoBtn("ESTAB"),_E(25)) ? {x:eX,y:eY} : _EsquinaPanelBloque(1)
    _seX := se.x, _seY := se.y
    ClampPrimario(&_seX, &_seY, _AnchoBtn("ESTAB"), _E(25))
    estabBtnGui.g.Show("x" _seX " y" _seY " w" _AnchoBtn("ESTAB") " h" _E(25) " NoActivate")
    _DwmRedondear(estabBtnGui.g.Hwnd)
    ActualizarEstabBtnGUI()
}
ActualizarEstabBtnGUI() {
    if !IsObject(estabBtnGui.g) || !IsObject(estabBtnGui.label)
        return
    v := estabGui.valor
    if estabGui.visible {
        _SetIcono(estabBtnGui.icono,"slider_on",true)
        estabBtnGui.label.Value := "STAB ON"
        estabBtnGui.barra.Opt("c" _Tema("color","accent.estabSoft","B4C0DE"))
        estabBtnGui.g.BackColor := _Tema("color","surface.on","636D83")
        GbSetFont(estabBtnGui.label, _FS(9), 700, "Segoe UI", "c" _Tema("color","text.primary","FFFFFF"))
    } else {
        _SetIcono(estabBtnGui.icono,"slider_on",false)
        estabBtnGui.label.Value := "STAB OFF"
        estabBtnGui.barra.Opt("c" _Tema("color","track.pillOff","6A6A6A"))
        estabBtnGui.g.BackColor := _Tema("color","surface.off","424242")
        GbSetFont(estabBtnGui.label, _FS(9), 700, "Segoe UI", "c" _Tema("color","text.idle","B2B2B2"))
    }
    estabBtnGui.barra.Value := estabGui.visible ? v : 0
}
_EstabBtnGUI_WM_LBUTTONDOWN(wParam,lParam,msg,hwnd) => _ArrastrarPanelBloque(hwnd,lParam,estabBtnGui)
_ToggleEstabVisible() {
    global PERFIL
    estabGui.visible := !estabGui.visible
    GuardarIniDiferido(_PosGuiIniPath(),"Estab_p" PERFIL,"visible",estabGui.visible ? 1 : 0)
    if estabGui.visible {
        _AplicarEstabVisibilidadBase()
        ActualizarEstabGUI()
    } else if (IsObject(estabGui.g) && !estabGui.foco)
        estabGui.g.Hide()
    ActualizarEstabBtnGUI()
    ActualizarHubGUI()
    MostrarHUD(estabGui.visible ? "🎚 DESLIZADOR VISIBLE" : "🎚 DESLIZADOR OCULTO",estabGui.visible ? _Tema("color","accent.success","44DD88") : _Tema("color","accent.warn","FF6B00"),1100)
}
IniciarReloadGUI() {
    reloadGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow","")
    reloadGui.g.BackColor := _Tema("color","surface.reload","3B7A4B")
    reloadGui.g.MarginX := 0
    reloadGui.g.MarginY := 0
    WinSetTransparent(_CompOp("pildora","op_rep","reload",_AlphaTema("pill",235)),reloadGui.g)
    reloadGui.icono := reloadGui.g.Add("Picture","x" _E(6) " y" _E(2) " w" _E(19) " h" _E(19) " BackgroundTrans","")
    _SetIcono(reloadGui.icono,"reload_g",true)
    reloadGui.barra := reloadGui.g.Add("Progress","x0 y" _E(22) " w" _E(31) " h" _E(3))
    reloadGui.barra.Visible := _PillFranja()
    reloadGui.barra.Value := 100
    OnMessage(0x0201,_ReloadGUI_WM_LBUTTONDOWN)
    mon := ObtenerMonitorCSP()
    x := mon.x + (mon.w - _E(104)) // 2
    y := mon.y + Round(mon.h * 0.02) + 42 + 4 + _E(25) + 4 + _E(25) + 4 + _E(25) + 4 + _E(25) + 4
    guardada := LeerPosicionGUI("Reload")
    if IsObject(guardada) && _PosicionValidaEnPantalla(guardada.x,guardada.y) {
        x := guardada.x
        y := guardada.y
    }
    ClampPrimario(&x, &y, _E(31), _E(25))
    reloadGui.g.Show("x" x " y" y " w" _E(31) " h" _E(25) " NoActivate")
    _DwmRedondear(reloadGui.g.Hwnd)
}
_ReloadGUI_WM_LBUTTONDOWN(wParam,lParam,msg,hwnd) {
    static arrastrando := false
    if (arrastrando)
        return
    if (hwnd = reloadGui.g.Hwnd || reloadGui.g.Hwnd = DllCall("GetParent","Ptr",hwnd,"Ptr")) {
        arrastrando := true
        pt := Buffer(8,0)
        NumPut("int",lParam & 0xFFFF,pt,0)
        NumPut("int",(lParam >> 16) & 0xFFFF,pt,4)
        DllCall("ClientToScreen","Ptr",hwnd,"Ptr",pt)
        clickX := NumGet(pt,0,"int")
        clickY := NumGet(pt,4,"int")
        rc := Buffer(16,0)
        DllCall("GetWindowRect","Ptr",reloadGui.g.Hwnd,"Ptr",rc)
        offX := clickX - NumGet(rc,0,"int")
        offY := clickY - NumGet(rc,4,"int")
        cur := Buffer(8,0)
        movido := false
        lp := _HubLPFueLapiz(), t0 := A_TickCount, largo := false
        while _LBtnAbajo() {
            DllCall("GetCursorPos","Ptr",cur)
            mx := NumGet(cur,0,"int")
            my := NumGet(cur,4,"int")
            if (Abs(mx - clickX) > 4 || Abs(my - clickY) > 4) {
                movido := true
                DllCall("SetWindowPos","Ptr",reloadGui.g.Hwnd,"Ptr",0,"int",mx - offX,"int",my - offY,"int",0,"int",0,"uint",0x0001 | 0x0004 | 0x0010)
            }
            if (!largo && _HubLPHecha(t0, movido, lp))
                largo := true
            else if (largo && movido)
                largo := false
            Sleep(8)
        }
        if (largo) {
            arrastrando := false
            _HubLPDisparar()
            return
        }
        if !movido {
            try _AudReiniciar()
            _SonarUI("reload")
            Sleep(130)   ; deja sonar el micro-tono antes de que Reload() mate el proceso
            Reload()
        } else
            GuardarPosicionGUI("Reload",reloadGui.g.Hwnd)
        arrastrando := false
    }
}
; ══════════════════════════════════════════════════════════════════
; 🧩 BOTÓN HUB: Contenedor Inteligente de Botones Auxiliares (Camaleón)
; ══════════════════════════════════════════════════════════════════
IniciarHubGUI() {
    global hubGui, panelBlk, PERFIL
    ini := _PosGuiIniPath()
    sec := "Hub_p" PERFIL
    ; Migración única del modelo viejo (embeber_ = ocultar) al nuevo (mostrar_ = mostrar).
    ; Sin historial en el perfil, las píldoras nacen ocultas.
    if (IniRead(ini,sec,"pills_migrado","0") != "1") {
        lista := ""
        try lista := IniRead(ini, sec)
        usado := (Trim(lista) != "")
        for k in ["lock","puntos","reload","hc","nv","ar","ds","cc"] {
            viejo := IniRead(ini,sec,"embeber_" k,"")
            most := (viejo != "") ? ((viejo = "1") ? "0" : "1") : (usado ? "1" : "0")
            IniWrite(most,ini,sec,"mostrar_" k)
        }
        ; Frente y Estabilizador dejan de ser píldoras: su acción pasa al menú.
        for k in ["frente","estab"]
            IniWrite(1,ini,sec,"rapida_" k)
        IniWrite(1,ini,sec,"pills_migrado")
    }
    for k in ["lock","puntos","reload","hc","nv","ar","ds","cc"]
        hubGui.embebidos[k] := (IniRead(ini,sec,"mostrar_" k,"0") != "1")
    for k in ["frente","estab"]
        hubGui.embebidos[k] := true
    hubGui.rapidas := Map()
    for k in ["frente","estab","flip","enfoque","layout","rapidas","audio"] {
        def := (k = "frente" || k = "estab") ? "1" : "0"
        hubGui.rapidas[k] := (IniRead(ini,sec,"rapida_" k,def) = "1")
    }
    hubGui.menuTick := 0

    ; El boton solitario Hub en la barra superior se retira por peticion del usuario:
    ; se mantiene 'QUICK' (arGui) con su icono y texto, y se accede a todo mediante click derecho en los companion.
    hubGui.g := 0
    hubGui.icono := 0
    hubGui.barra := 0

    OnMessage(0x0205,_Companion_WM_RBUTTON)
    OnMessage(0x0246,_HubLP_WM_POINTERDOWN)   ; pulsación larga con la punta del lápiz
    _AplicarVisibilidadEmbebidos()
}

_HayBotonesEmbebidos() {
    global hubGui
    if !IsObject(hubGui) || !hubGui.HasOwnProp("embebidos")
        return false
    for k, v in hubGui.embebidos {
        if (v)
            return true
    }
    return false
}

ActualizarHubGUI() {
    global hubGui
    if !IsObject(hubGui.g) || !IsObject(hubGui.icono)
        return
    hay := _HayBotonesEmbebidos()
    if (hay) {
        ; Azul marino leve para activado
        hubGui.g.BackColor := "2A3D5E"
        hubGui.barra.Opt("c" "688ECC")
        _SetIcono(hubGui.icono,"quick_on",true)
    } else {
        ; Como está ahora para no marcado
        hubGui.g.BackColor := _Tema("color","surface.off","424242")
        hubGui.barra.Opt("c" _Tema("color","track.pillOff","6A6A6A"))
        _SetIcono(hubGui.icono,"quick_on",false)
    }
    hubGui.barra.Value := 100
}

_AplicarVisibilidadEmbebidos() {
    global hubGui, lockGui, frenteGui, puntosGui, estabBtnGui, reloadGui, dsGui, ccGui, arGui, hcGui, nvGui
    _SetVis(gObj, k) {
        if IsObject(gObj) && IsObject(gObj.g) {
            emb := (hubGui.HasOwnProp("embebidos") && hubGui.embebidos.Has(k) && hubGui.embebidos[k])
            emb ? gObj.g.Hide() : gObj.g.Show("NoActivate")
        }
    }
    _SetVis(lockGui, "lock")
    _SetVis(frenteGui, "frente")
    _SetVis(puntosGui, "puntos")
    _SetVis(estabBtnGui, "estab")
    _SetVis(reloadGui, "reload")
    _SetVis(dsGui, "ds")
    _SetVis(ccGui, "cc")
    _SetVis(arGui, "ar")
    _SetVis(hcGui, "hc")
    _SetVis(nvGui, "nv")
}

_HubGUI_WM_LBUTTONDOWN(wParam,lParam,msg,hwnd) {
    global hubGui, panelBlk
    if !IsObject(hubGui.g)
        return
    if !(hwnd = hubGui.g.Hwnd || hubGui.g.Hwnd = DllCall("GetParent","Ptr",hwnd,"Ptr"))
        return
    pt := Buffer(8,0)
    NumPut("int",lParam & 0xFFFF,pt,0)
    NumPut("int",(lParam >> 16) & 0xFFFF,pt,4)
    DllCall("ClientToScreen","Ptr",hwnd,"Ptr",pt)
    clickX := NumGet(pt,0,"int"), clickY := NumGet(pt,4,"int")
    rc := Buffer(16,0)
    DllCall("GetWindowRect","Ptr",hubGui.g.Hwnd,"Ptr",rc)
    offX := clickX - NumGet(rc,0,"int")
    offY := clickY - NumGet(rc,4,"int")
    cur := Buffer(8,0)
    movido := false
    while _LBtnAbajo() {
        DllCall("GetCursorPos","Ptr",cur)
        mx := NumGet(cur,0,"int"), my := NumGet(cur,4,"int")
        if (!panelBlk.locked && (Abs(mx - clickX) > 4 || Abs(my - clickY) > 4)) {
            movido := true
            DllCall("SetWindowPos","Ptr",hubGui.g.Hwnd,"Ptr",0,"int",mx-offX,"int",my-offY,"int",0,"int",0,"uint",0x0001|0x0004|0x0010)
        }
        Sleep(8)
    }
    if (movido) {
        GuardarPosicionGUI("Hub",hubGui.g.Hwnd)
    } else {
        _MostrarMenuContextualHub()
    }
}

_Companion_WM_RBUTTON(wParam,lParam,msg,hwnd) {
    global hubGui, lockGui, frenteGui, puntosGui, estabBtnGui, reloadGui, dsGui, ccGui, arGui, hcGui
    hwnds := []
    for o in [hubGui, lockGui, frenteGui, puntosGui, estabBtnGui, reloadGui, dsGui, ccGui, arGui, hcGui] {
        if IsObject(o) && IsObject(o.g)
            hwnds.Push(o.g.Hwnd)
    }
    esValido := false
    for h in hwnds {
        if (hwnd = h || h = DllCall("GetParent","Ptr",hwnd,"Ptr")) {
            esValido := true
            break
        }
    }
    if (!esValido)
        return
    _MostrarMenuContextualHub()
    return 0
}

_EjecutarAccionHub(act, *) {
    global hubGui, panelBlk, estabGui, colorV, colorCC, ar, hist, enfoque
    switch act {
        case "lock":
            _ToggleBloqueo()
        case "frente":
            _ToggleFrente()
        case "puntos":
            try AbrirCalibradorPy()
            catch
                AbrirPanelPuntos()
        case "estab":
            _ToggleEstabVisible()
        case "estabsolo":
            _EstabSoloLineaAlternar()
        case "ds":
            _ToggleColorV()
            ActualizarDsGUI()
        case "cc":
            _ToggleColorCC()
            ActualizarCcGUI()
        case "ar":
            _ToggleAR()
            ActualizarArGUI()
        case "hc":
            _ToggleHistorialColor()
            ActualizarHCGUI()
        case "nv":
            SetTimer(_NvMostrarMenu, -15)
        case "flip":
            SendInput("!g")
            MostrarHUD("FLIP HORIZONTAL","888888",700)
            _SonarUI("flip")
        case "enfoque":
            AccionEnfoque()
        case "reload":
            try _AudReiniciar()
            Reload()
        case "rapidas":
            MostrarAccionesRapidasGUI()
        case "audio_reset":
            _CompanionRestaurarAudio()
    }
    ActualizarHubGUI()
}

_MostrarMenuContextualHub() {
    global hubGui, panelBlk, estabGui, colorV, colorCC, ar, hist, enfoque
    static ultMenuTick := 0
    if (A_TickCount - ultMenuTick < 400)
        return
    ultMenuTick := A_TickCount

    filas := []

    cat := [
        ["lock", "🔒 Bloquear Companion", () => panelBlk.locked ? "🔓 Desbloquear Companion" : "🔒 Fijar Companion"],
        ["frente", "📌 Modo Frente (AlwaysOnTop)", () => panelBlk.frente ? "📌 Modo Frente: Desactivar (Solo en CSP)" : "📌 Modo Frente: Activar (AlwaysOnTop)"],
        ["puntos", "📍 Calibrador de Zonas y Rangos", () => "📍 Calibrador de Zonas y Rangos"],
        ["estab", "🎚 Deslizador Estabilización", () => estabGui.visible ? "🎚 Deslizador: Ocultar" : "🎚 Deslizador: Mostrar"],
        ["estabsolo", "➖ Slider: Solo Línea", () => (IsSet(estabSoloLinea) && estabSoloLinea) ? "🔲 Slider: Modo Completo" : "➖ Slider: Solo Línea"],
        ["ds", "🎚 Botón Slider / Pincel (DS)", () => colorV.hover ? "🎚 Slider / Pincel: Ocultar" : "🎚 Slider / Pincel: Mostrar"],
        ["cc", "🎨 Botón Círculo de Color (CC)", () => colorCC.hover ? "🎨 Círculo de Color: Ocultar" : "🎨 Círculo de Color: Mostrar"],
        ["ar", "⚡ Botón Acceso Rápido (AR)", () => ar.hover ? "⚡ Acceso Rápido: Ocultar" : "⚡ Acceso Rápido: Mostrar"],
        ["hc", "🕒 Botón Historial de Color (HC)", () => (hist.modo = 1) ? "🕒 Historial Color: Cambiar a Fijo" : "🕒 Historial Color: Cambiar a Dinámico"],
        ["nv", "🪟 Botón Ventana (WINDOW)", () => "🪟 Ventana: Menú / Opciones"],
        ["flip", "🪞 Voltear Lienzo Horizontal", () => "🪞 Voltear Lienzo Horizontal"],
        ["enfoque", "🔍 Modo Enfoque", () => enfoque.activo ? "🔍 Salir de Modo Enfoque" : "🔍 Activar Modo Enfoque"],
        ["reload", "🔄 Recargar Script", () => "🔄 Recargar Script"]
    ]

    ; ── 1) Acciones de las píldoras VISIBLES (embeber = píldora oculta → no aparece) ──
    puestos := Map()
    for k in ["lock","frente","estab","ds","cc","ar","hc","nv"] {
        if (hubGui.embebidos.Has(k) && hubGui.embebidos[k])
            continue
        for item in cat {
            if (item[1] = k) {
                filas.Push({t: item[3](), f: _EjecutarAccionHub.Bind(k)})
                puestos[k] := true
                break
            }
        }
    }

    ; ── 2) Siempre presentes ──
    filas.Push({t: (IsSet(estabSoloLinea) && estabSoloLinea) ? "🔲 Slider: Modo Completo" : "➖ Slider: Solo Línea", f: (*) => _EjecutarAccionHub("estabsolo")})
    filas.Push({t: "📍 Actualizar calibrador", f: (*) => _EjecutarAccionHub("puntos")})
    filas.Push({t: "🔄 Reiniciar script", f: (*) => _EjecutarAccionHub("reload")})

    ; ── 3) Solo extras marcados en "Acceso rápido" ──
    extras := []
    for k in ["frente","estab","flip","enfoque","layout","rapidas","audio"] {
        if _HubRapidaActiva(k)
            extras.Push(k)
    }
    if (extras.Length) {
        sepPuesto := false
        for k in extras {
            ; ya salió como píldora visible en el bloque 1: no duplicar
            if puestos.Has(k)
                continue
            if !sepPuesto {
                filas.Push({sep: true})
                sepPuesto := true
            }
            switch k {
                case "frente":
                    filas.Push({t: panelBlk.frente ? "📌 Modo Frente: Desactivar (Solo en CSP)" : "📌 Modo Frente: Activar (AlwaysOnTop)", f: _EjecutarAccionHub.Bind("frente")})
                case "estab":
                    filas.Push({t: estabGui.visible ? "🎚 Deslizador: Ocultar" : "🎚 Deslizador: Mostrar", f: _EjecutarAccionHub.Bind("estab")})
                case "flip":
                    filas.Push({t: "🪞 Voltear Lienzo Horizontal", f: _EjecutarAccionHub.Bind("flip")})
                case "enfoque":
                    filas.Push({t: enfoque.activo ? "🔍 Salir de Modo Enfoque" : "🔍 Activar Modo Enfoque", f: _EjecutarAccionHub.Bind("enfoque")})
                case "layout":
                    filas.Push({t: "📐 Layout Paneles CSP (Modo 1 y 2)  ▸", f: _HubPanelLayout})
                case "rapidas":
                    filas.Push({t: "⚡ Acciones Rápidas (Capas y Lienzo)", f: _EjecutarAccionHub.Bind("rapidas")})
                case "audio":
                    filas.Push({t: "🔊 Restaurar Audio (Sin Reiniciar)", f: _EjecutarAccionHub.Bind("audio_reset")})
            }
        }
    }

    ; Flag de menú abierto: pausa ResetAlphaStates mientras el panel está visible (Req. B)
    hubGui.menuTick := A_TickCount
    _HubPanelMostrar(filas)
}

; ══════════════════════════════════════════════════════════════════
; Panel emergente del MENÚ DEL COMPANION (reemplaza Menu() nativo;
; compatible con stylus). Misma mecánica probada en _NvMostrarMenu (WINDOW):
;  · Gui propio + controles Text (una fila = un botón)
;  · WM_LBUTTONDOWN (ratón) y WM_POINTERDOWN 0x0246 (lápiz/dedo) ejecutan
;    la acción sin depender del mensaje de menú nativo
;  · Vigilante: Esc / clic fuera / 6 s de inactividad cierran el panel
; ══════════════════════════════════════════════════════════════════
_HubPanelSt() {
    static st := Map("g", 0, "acc", Map(), "t", 0)
    return st
}

_HubPanelCerrar() {
    global hubGui
    st := _HubPanelSt()
    SetTimer(_HubPanelVigilar, 0)
    OnMessage(0x0201, _HubPanel_WM_LBUTTONDOWN, 0)
    OnMessage(0x0246, _HubPanel_WM_POINTERDOWN, 0)
    g := st["g"]
    st["g"] := 0
    st["acc"] := Map()
    if IsObject(g)
        try g.Destroy()
    if (IsObject(hubGui) && hubGui.HasOwnProp("menuTick"))
        hubGui.menuTick := 0
}

_HubPanelEjecutarEn(hwnd) {
    st := _HubPanelSt()
    if (!IsObject(st["g"]) || !st["acc"].Has(hwnd))
        return false
    fn := st["acc"][hwnd]
    _HubPanelCerrar()
    SetTimer(fn, -30)
    return true
}

_HubPanel_WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    if _HubPanelEjecutarEn(hwnd)
        return 0
}

_HubPanel_WM_POINTERDOWN(wParam, lParam, msg, hwnd) {
    px := lParam << 48 >> 48
    py := lParam << 32 >> 48
    hw := DllCall("WindowFromPoint", "Int64", (py << 32) | (px & 0xFFFFFFFF), "Ptr")
    if _HubPanelEjecutarEn(hw)
        return 0
}

_HubPanelVigilar() {
    static ultElev := 0
    st := _HubPanelSt()
    g := st["g"]
    if !IsObject(g) {
        SetTimer(_HubPanelVigilar, 0)
        return
    }
    ; [Z-ORDER] las píldoras del companion son topmost: si alguna queda encima, re-elevar el panel
    prev := DllCall("GetWindow", "Ptr", g.Hwnd, "UInt", 3)   ; GW_HWNDPREV
    if (prev && A_TickCount - ultElev > 250 && DllCall("IsWindowVisible", "Ptr", prev) && _VentanaDelProceso(prev)) {
        ultElev := A_TickCount
        DllCall("SetWindowPos", "Ptr", g.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
    }
    if GetKeyState("Escape", "P") {
        _HubPanelCerrar()
        return
    }
    CoordMode("Mouse", "Screen")
    MouseGetPos(, , &win)
    if (win = g.Hwnd) {
        st["t"] := A_TickCount
        return
    }
    if (GetKeyState("LButton", "P") || GetKeyState("RButton", "P") || A_TickCount - st["t"] > 6000)
        _HubPanelCerrar()
}

_HubPanelMostrar(filas) {
    global stylus, hubGui
    if !filas.Length
        return
    st0 := _HubPanelSt()
    if (IsObject(st0["g"]) && A_TickCount - st0["t"] < 600)
        return                       ; antirrebote: 2.ª apertura no destruye/recrea
    _HubPanelCerrar()
    _NvPanelCerrar()                 ; nunca dos paneles propios a la vez
    if (IsSet(stylus) && IsObject(stylus)) {
        stylus.rButtonHeld := false
        stylus.comboUsado := true
    }
    KeyWait("RButton", "T0.25")
    KeyWait("LButton", "T0.25")
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)

    GP := _E(2), RH := _E(24), PADB := _E(16)
    wNeed := _E(120)
    for f in filas {
        if (f.HasProp("sep") && f.sep)
            continue
        wNeed := Max(wNeed, _AnchoTextoPill(f.t) + PADB)
    }
    CWd := wNeed
    W := CWd + 2 * GP

    acc := Map()
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +Border +E0x08000000", "")
    g.BackColor := _Tema("color", "surface.off", "424242")
    g.MarginX := 0
    g.MarginY := 0
    GbSetFont(g, _FS(9), 600, "Segoe UI Semibold")

    y := GP
    for f in filas {
        if (f.HasProp("sep") && f.sep) {
            g.Add("Text", "x" GP " y" y " w" CWd " h1 BackgroundWhite")
            y += 1 + GP
        } else {
            _NvPanelBoton(g, acc, GP, y, CWd, RH, f.t, f.f, f.HasProp("a") ? f.a : false)
            y += RH + GP
        }
    }

    H := y
    px := mx, py := my
    _NvPanelClamp(&px, &py, W, H)
    st := _HubPanelSt()
    st["g"] := g
    st["acc"] := acc
    st["t"] := A_TickCount
    hubGui.menuTick := A_TickCount
    g.Show("x" px " y" py " w" W " h" H " NoActivate Hide")
    _DwmRedondear(g.Hwnd)
    ; topmost mientras está oculto: no existe ningún fotograma con una píldora encima del panel
    DllCall("SetWindowPos", "Ptr", g.Hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
    g.Show("NoActivate")
    DllCall("SetWindowPos", "Ptr", g.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
    OnMessage(0x0201, _HubPanel_WM_LBUTTONDOWN)
    OnMessage(0x0246, _HubPanel_WM_POINTERDOWN)
    SetTimer(_HubPanelVigilar, 50)
}

; Submenú "📐 Layout Paneles CSP (Modo 1 y 2)" como segundo panel (también con stylus)
_HubPanelLayout(*) {
    global enfoque
    filas := []
    filas.Push({t: "🖥 Modo 1 · Normal", f: (*) => EstablecerModoTrabajo("Normal"), a: !enfoque.activo})
    filas.Push({t: "🔍 Modo 2 · Enfoque", f: (*) => EstablecerModoTrabajo("Enfoque"), a: enfoque.activo})
    filas.Push({sep: true})
    filas.Push({t: "🎛 Selector flotante: Mostrar/Ocultar", f: (*) => ModoSel_Alternar()})
    filas.Push({t: "💾 Guardar ubicaciones en el modo activo", f: (*) => _ModoGuardarActivo()})
    filas.Push({t: "💾 Guardar posición actual como Modo 1 (Normal)", f: (*) => _CapturarLayout("Normal")})
    filas.Push({t: "💾 Guardar posición actual como Modo 2 (Enfoque)", f: (*) => _CapturarLayout("Enfoque")})
    _HubPanelMostrar(filas)
}

_MenuToggleEmbebido(k, *) {
    global hubGui, PERFIL
    if !hubGui.embebidos.Has(k)
        hubGui.embebidos[k] := false
    hubGui.embebidos[k] := !hubGui.embebidos[k]
    IniWrite(hubGui.embebidos[k] ? 0 : 1,_PosGuiIniPath(),"Hub_p" PERFIL,"mostrar_" k)
    _AplicarVisibilidadEmbebidos()
    ActualizarHubGUI()
    MostrarAvisoUI("moderno",hubGui.embebidos[k] ? "PÍLDORA OCULTA" : "PÍLDORA VISIBLE",StrUpper(k),2,"00E5FF",1200)
}

; ¿Extra marcado en "Acceso rápido"? (k: frente|estab|flip|enfoque|layout|rapidas|audio)
_HubRapidaActiva(k) {
    global hubGui
    return (hubGui.HasOwnProp("rapidas") && hubGui.rapidas.Has(k) && hubGui.rapidas[k])
}

; Alterna un extra del menú clic derecho; el menú se reconstruye en cada apertura, efecto inmediato.
_HubToggleRapida(k, *) {
    global hubGui, PERFIL
    if !hubGui.HasOwnProp("rapidas")
        hubGui.rapidas := Map()
    hubGui.rapidas[k] := !(hubGui.rapidas.Has(k) && hubGui.rapidas[k])
    IniWrite(hubGui.rapidas[k] ? 1 : 0, _PosGuiIniPath(), "Hub_p" PERFIL, "rapida_" k)
    ActualizarHubGUI()
    MostrarAvisoUI("moderno", hubGui.rapidas[k] ? "EN MENÚ CLIC DERECHO" : "SOLO EN CALIBRADOR", StrUpper(k), 2, "00E5FF", 1200)
}

; ¿Hay un menú propio abierto (panel WINDOW o menú nativo)? Pausa ResetAlphaStates.
_HubMenuAbierto() {
    global hubGui
    if (IsObject(hubGui) && hubGui.HasOwnProp("menuTick") && hubGui.menuTick && A_TickCount - hubGui.menuTick < 30000)
        return true
    st := _NvPanelSt()
    if IsObject(st["g"])
        return true
    stH := _HubPanelSt()
    return IsObject(stH["g"])
}

IniciarPuntosGUI() {
    global reloadGui
    SetTimer(_ModoSelArranque, -900)
    puntosGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow","")
    puntosGui.g.BackColor := _Tema("color","surface.off","424242")
    puntosGui.g.MarginX := 0
    puntosGui.g.MarginY := 0
    WinSetTransparent(_AlphaTema("pill",235),puntosGui.g)
    puntosGui.icono := puntosGui.g.Add("Picture","x" _E(6) " y" _E(2) " w" _E(19) " h" _E(19) " BackgroundTrans","")
    _SetIcono(puntosGui.icono,"calib",true)
    puntosGui.barra := puntosGui.g.Add("Progress","x0 y" _E(22) " w" _E(31) " h" _E(3))
    puntosGui.barra.Visible := _PillFranja()
    puntosGui.barra.Value := 100
    OnMessage(0x0201,_PuntosGUI_WM_LBUTTONDOWN)
    puntosGui.g.OnEvent("ContextMenu", (*) => _MostrarMenuContextualHub())
    mon := ObtenerMonitorCSP()
    x := mon.x + (mon.w - _E(104)) // 2 + _E(31) + PANEL_GAP
    y := mon.y + Round(mon.h * 0.02)
    try {
        WinGetPos(&rX,&rY,&rW,&rH,"ahk_id " reloadGui.g.Hwnd)
        x := rX + rW + PANEL_GAP
        y := rY
    }
    guardada := LeerPosicionGUI("PuntosBtn")
    if IsObject(guardada) && _PosicionValidaEnPantalla(guardada.x,guardada.y) {
        x := guardada.x
        y := guardada.y
    }
    puntosGui.g.Show("x" x " y" y " w" _E(31) " h" _E(25) " NoActivate")
    _DwmRedondear(puntosGui.g.Hwnd)
}
_PuntosGUI_WM_LBUTTONDOWN(wParam,lParam,msg,hwnd) {
    global panelBlk
    static arrastrando := false
    if (arrastrando)
        return
    if !IsObject(puntosGui.g)
        return
    if (hwnd = puntosGui.g.Hwnd || puntosGui.g.Hwnd = DllCall("GetParent","Ptr",hwnd,"Ptr")) {
        arrastrando := true
        pt := Buffer(8,0)
        NumPut("int",lParam & 0xFFFF,pt,0)
        NumPut("int",(lParam >> 16) & 0xFFFF,pt,4)
        DllCall("ClientToScreen","Ptr",hwnd,"Ptr",pt)
        clickX := NumGet(pt,0,"int")
        clickY := NumGet(pt,4,"int")
        rc := Buffer(16,0)
        DllCall("GetWindowRect","Ptr",puntosGui.g.Hwnd,"Ptr",rc)
        offX := clickX - NumGet(rc,0,"int")
        offY := clickY - NumGet(rc,4,"int")
        cur := Buffer(8,0)
        movido := false
        lp := _HubLPFueLapiz(), t0 := A_TickCount, largo := false
        while _LBtnAbajo() {
            if (!panelBlk.locked) {
                DllCall("GetCursorPos","Ptr",cur)
                mx := NumGet(cur,0,"int")
                my := NumGet(cur,4,"int")
                if (Abs(mx - clickX) > 4 || Abs(my - clickY) > 4) {
                    movido := true
                    DllCall("SetWindowPos","Ptr",puntosGui.g.Hwnd,"Ptr",0,"int",mx - offX,"int",my - offY,"int",0,"int",0,"uint",0x0001 | 0x0004 | 0x0010)
                }
            }
            if (!largo && _HubLPHecha(t0, movido, lp))
                largo := true
            else if (largo && movido)
                largo := false
            Sleep(8)
        }
        if (largo) {
            arrastrando := false
            _HubLPDisparar()
            return
        }
        if !movido {
            try AbrirCalibradorPy()
            catch
                AbrirPanelPuntos()
        }
        else {
            if (IsSet(_PosGuiMutearVigilante))
                _PosGuiMutearVigilante(2000)
            GuardarPosicionGUI("PuntosBtn",puntosGui.g.Hwnd)
        }
        arrastrando := false
    }
}

; ══════════════════════════════════════════════════════════════════
; ⚡ ACCIONES RÁPIDAS: Macro de Capas + Atajos de Lienzo (Req 4 UI, 7)
; ══════════════════════════════════════════════════════════════════
MostrarAccionesRapidasGUI() {
    static gRapidas := 0
    if (IsObject(gRapidas) && DllCall("IsWindow", "Ptr", gRapidas.Hwnd)) {
        try gRapidas.Destroy()
        gRapidas := 0
        return
    }
    mon := ObtenerMonitorCSP()
    g := Gui("+AlwaysOnTop -Caption +ToolWindow","Acciones Rápidas")
    g.BackColor := _Tema("color","surface.off","282828")
    g.MarginX := 8
    g.MarginY := 8

    lblTit := g.Add("Text", "x8 y8 w264 h20 cWhite", "⚡ Acciones Rápidas · Capas y Lienzo")
    GbSetFont(lblTit, 9, 700)

    ; Fila 1: Ciclo de Macros (Buscar -> Color -> Borrar)
    g.Add("GroupBox", "x8 y32 w264 h90 cGray", "Ciclo de Macros (1→2→3)")
    btnM0 := g.Add("Button", "x16 y52 w248 h28", "▶ Ciclo de Macros Completo")
    btnM0.OnEvent("Click", (*) => (IsSet(MacroCapas_Ejecutar) ? MacroCapas_Ejecutar(0) : 0))

    btnM1 := g.Add("Button", "x16 y86 w78 h24", "🔍 1. Buscar")
    btnM1.OnEvent("Click", (*) => (IsSet(MacroCapas_Ejecutar) ? MacroCapas_Ejecutar(1) : 0))

    btnM2 := g.Add("Button", "x101 y86 w78 h24", "🎨 2. Color")
    btnM2.OnEvent("Click", (*) => (IsSet(MacroCapas_Ejecutar) ? MacroCapas_Ejecutar(2) : 0))

    btnM3 := g.Add("Button", "x186 y86 w78 h24", "🗑 3. Borrar")
    btnM3.OnEvent("Click", (*) => (IsSet(MacroCapas_Ejecutar) ? MacroCapas_Ejecutar(3) : 0))

    ; Fila 2: Comandos de Lienzo con Iconos GDI+ (Z, R, Space)
    g.Add("GroupBox", "x8 y128 w264 h72 cGray", "Comandos de Lienzo")
    
    hbmZ := IsSet(GfxIconoLienzo) ? GfxIconoLienzo("z", 24, true) : 0
    hbmR := IsSet(GfxIconoLienzo) ? GfxIconoLienzo("r", 24, true) : 0
    hbmSpc := IsSet(GfxIconoLienzo) ? GfxIconoLienzo("space", 24, true) : 0

    if (hbmZ) {
        picZ := g.Add("Picture", "x24 y148 w24 h24", "HBITMAP:" hbmZ)
        picZ.OnEvent("Click", (*) => SendInput("z"))
    }
    btnZ := g.Add("Button", "x52 y148 w60 h24", "Zoom (Z)")
    btnZ.OnEvent("Click", (*) => SendInput("z"))

    if (hbmR) {
        picR := g.Add("Picture", "x118 y148 w24 h24", "HBITMAP:" hbmR)
        picR.OnEvent("Click", (*) => SendInput("r"))
    }
    btnR := g.Add("Button", "x146 y148 w60 h24", "Rotar (R)")
    btnR.OnEvent("Click", (*) => SendInput("r"))

    btnSpc := g.Add("Button", "x212 y148 w52 h24", "✋ Mover")
    btnSpc.OnEvent("Click", (*) => SendInput("{Space}"))

    ; Fila 3: Utilidades (Shift Anclado y Reset Audio)
    btnSft := g.Add("Button", "x16 y208 w120 h26", "📌 Shift Anclado")
    btnSft.OnEvent("Click", (*) => (IsSet(ShiftAnclado_Toggle) ? ShiftAnclado_Toggle() : 0))

    btnAud := g.Add("Button", "x144 y208 w120 h26", "🔊 Restaurar Audio")
    btnAud.OnEvent("Click", (*) => _CompanionRestaurarAudio())

    btnX := g.Add("Button", "x248 y6 w24 h20", "✕")
    btnX.OnEvent("Click", (*) => (g.Destroy(), gRapidas := 0))

    posX := mon.x + (mon.w - 280) // 2
    posY := mon.y + (mon.h - 245) // 2
    g.Show("x" posX " y" posY " w280 h245 NoActivate")
    if IsSet(GfxMascaraRedondeada)
        GfxMascaraRedondeada(g.Hwnd, 280, 245, 8)
    gRapidas := g
}

; ===== FÁBRICA DE PÍLDORAS DINÁMICAS (inicio) =====
_PillDin() {
    static m := Map()
    return m
}

_PillHwndMapa() {
    static m := Map()
    return m
}

; Eventos que ya tienen píldora rígida (IniciarDsGUI, IniciarCcGUI, IniciarLockGUI, etc.)
_PillIdsRigidos() {
    static m := Map("panel_ds", 1, "panel_cc", 1, "history_lock", 1
                  , "estab_slider", 1, "gui_frente", 1, "reload", 1)
    return m
}

; "Plumilla / Pincel Tinta (Q)" -> "PLUMILLA" ; "Pincel Duro · Hard Brush (...)" -> "PINCEL DURO"
_PillNombreCorto(nombre) {
    t := Trim(RegExReplace(nombre, "\s*\(.*$", ""))
    for sep in [" / ", " · "] {
        i := InStr(t, sep)
        if (i > 1)
            t := SubStr(t, 1, i - 1)
    }
    t := StrUpper(Trim(t))
    if (StrLen(t) > 18)
        t := SubStr(t, 1, 17) "…"
    return (t = "") ? "PILL" : t
}

_PillCrearDinamica(idEv, nombre, atajo := "") {
    pd := _PillDin()
    if pd.Has(idEv) {
        _PillActualizarDinamica(idEv, nombre, atajo)
        return pd[idEv]
    }
    txt := _PillNombreCorto(nombre)
    w := _PillAnchoPara(txt)

    pos := LeerPosicionGUI("Pildora_" idEv)
    if (IsObject(pos) && _PosicionValidaEnPantalla(pos.x, pos.y)) {
        px := pos.x, py := pos.y
    } else {
        base := _AnclaBloquePaneles()
        px := base.x, py := base.y + _E(30) * (pd.Count + 1)
    }
    ClampPrimario(&px, &py, w, _E(25))

    p := {idEv: idEv, nombre: nombre, atajo: atajo}
    p.g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000", "")
    p.g.BackColor := _Tema("color", "surface.off", "424242")
    p.g.MarginX := 0
    p.g.MarginY := 0
    WinSetTransparent(_CompOp("pildora", "op_rep", idEv, _AlphaTema("pill", 235)), p.g)
    p.icono := p.g.Add("Picture", "x" _E(4) " y" _E(2) " w" _E(20) " h" _E(20) " BackgroundTrans", "")
    p.label := p.g.Add("Text", "x" _E(26) " y" _E(3) " w" (w - _E(28)) " h" _E(19) " cWhite", txt)
    GbSetFont(p.label, _FS(9), 700)
    p.barra := p.g.Add("Progress", "x0 y" _E(22) " w" w " h" _E(3))
    p.barra.Visible := _PillFranja()
    p.g.OnEvent("ContextMenu", (*) => _MostrarMenuContextualHub())

    static registrado := false
    if !registrado {
        OnMessage(0x0201, _PillDin_WM_LBUTTONDOWN)
        registrado := true
    }
    p.g.Show("x" px " y" py " w" w " h" _E(25) " NoActivate")
    _PillAjustar(p, txt)
    _PillHwndMapa()[p.g.Hwnd] := idEv
    pd[idEv] := p
    try _CompPildoraAplicar(idEv)                     ; W1: tamaño/color persistidos
    return p
}

_PillActualizarDinamica(idEv, nombre, atajo := "") {
    pd := _PillDin()
    if !pd.Has(idEv)
        return
    p := pd[idEv]
    p.atajo := atajo
    if (p.nombre != nombre) {
        p.nombre := nombre
        txt := _PillNombreCorto(nombre)
        p.label.Text := txt
        _PillAjustar(p, txt)
    }
}

_PillDestruirDinamica(idEv) {
    pd := _PillDin()
    if !pd.Has(idEv)
        return
    p := pd[idEv]
    hm := _PillHwndMapa()
    try {
        if hm.Has(p.g.Hwnd)
            hm.Delete(p.g.Hwnd)
    }
    try p.g.Destroy()
    pd.Delete(idEv)
}

_PillDestruirTodas() {
    ids := []
    for idEv in _PillDin()
        ids.Push(idEv)
    for idEv in ids
        _PillDestruirDinamica(idEv)
}

_PillSincronizarDinamicas() {
    ini := _PosGuiIniPath()
    pd := _PillDin()
    rigidos := _PillIdsRigidos()
    deseados := Map()
    for ev in _PtsEventosDefs() {            ; [id, nombre, grupo]; incluye [EventosCustom]
        idEv := ev[1]
        if rigidos.Has(idEv)
            continue
        if (IniRead(ini, "Particularidades", "pildora_" idEv, "0") = "1") {
            deseados[idEv] := true
            _PillCrearDinamica(idEv, ev[2], IniRead(ini, "Remapeos", "atajo_" idEv, ""))
        }
    }
    viejos := []
    for idEv in pd
        if !deseados.Has(idEv)
            viejos.Push(idEv)
    for idEv in viejos
        _PillDestruirDinamica(idEv)
}

_PillDin_WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    static activo := false
    raiz := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
    hm := _PillHwndMapa()
    if !hm.Has(raiz)
        return                               ; no es dinámica: otros handlers siguen
    pd := _PillDin()
    idEv := hm[raiz]
    if !pd.Has(idEv)
        return
    if activo
        return 0
    activo := true
    try {
        _PillClickOArrastre(hwnd, lParam, pd[idEv])
    } finally {
        activo := false
    }
    return 0
}

_PillClickOArrastre(hwndClick, lParam, p) {
    global panelBlk
    pt := Buffer(8, 0)
    NumPut("int", lParam & 0xFFFF, pt, 0)
    NumPut("int", (lParam >> 16) & 0xFFFF, pt, 4)
    DllCall("ClientToScreen", "Ptr", hwndClick, "Ptr", pt)
    clickX := NumGet(pt, 0, "int"), clickY := NumGet(pt, 4, "int")
    rc := Buffer(16, 0)
    DllCall("GetWindowRect", "Ptr", p.g.Hwnd, "Ptr", rc)
    offX := clickX - NumGet(rc, 0, "int")
    offY := clickY - NumGet(rc, 4, "int")
    bloqueado := panelBlk.locked             ; bloqueado: no se arrastra, solo dispara
    cur := Buffer(8, 0)
    movido := false
    lp := _HubLPFueLapiz(), t0 := A_TickCount, largo := false
    while _LBtnAbajo() {
        DllCall("GetCursorPos", "Ptr", cur)
        mx := NumGet(cur, 0, "int"), my := NumGet(cur, 4, "int")
        if (!bloqueado && (Abs(mx - clickX) > 4 || Abs(my - clickY) > 4)) {
            movido := true
            DllCall("SetWindowPos", "Ptr", p.g.Hwnd, "Ptr", 0, "int", mx - offX, "int", my - offY
                , "int", 0, "int", 0, "uint", 0x0001 | 0x0004 | 0x0010)
        }
        if (!largo && _HubLPHecha(t0, movido, lp))
            largo := true
        else if (largo && movido)
            largo := false
        Sleep(8)
    }
    if (largo) {
        _HubLPDisparar()
        return
    }
    if movido {
        if (IsSet(_PosGuiMutearVigilante))
            _PosGuiMutearVigilante(2000)
        GuardarPosicionGUI("Pildora_" p.idEv, p.g.Hwnd)
    } else
        _PillDisparar(p.idEv)
}

_PillDisparar(idEv) {
    if _PtsEvPausado(idEv)
        return
    pd := _PillDin()
    atajo := IniRead(_PosGuiIniPath(), "Remapeos", "atajo_" idEv, "")
    if (atajo = "" && pd.Has(idEv))
        atajo := pd[idEv].atajo
    if (atajo = "")
        return
    SendInput(atajo)                         ; punto único de envío (sustituible por _ModEnviar)
}
; ===== FÁBRICA DE PÍLDORAS DINÁMICAS (fin) =====


