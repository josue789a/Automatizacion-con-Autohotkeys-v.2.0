#Requires AutoHotkey v2.0
; [LIB] companion — fuente: XPPEN AHK VERSION ESTABLE.ahk L1251–1282, 1300–1703, 2348–2479, 2485–2635, 2796–3487, 4099–4157, 4297–4600
; [FRANJA-PILL] Interruptor temporal de la franja inferior de los botones companion.
; false = franja oculta (aspecto limpio). true = la recupera tal como estaba.
; El codigo de cada barra (creacion, color y valor) se conserva intacto.
_PillFranja() => false ; false = franja oculta (aspecto limpio). true = la recupera tal como estaba.
class BorderFrame {
    T := 0
    B := 0
    L := 0
    R := 0
    _k := ""                                  ; [FIX-PARPADEO] última geometría aplicada
    __New(color) {
        opts := "-Caption +AlwaysOnTop +ToolWindow +E0x20"
        for side in ["T","B","L","R"] {
            g := Gui(opts)
            g.BackColor := color
            g.Show("w0 h0 NoActivate")
            this.%side% := g
        }
    }
    Show(x,y,w,h,g := 1) {
        ; [FIX-PARPADEO] idempotente: LoopAccesoRapido (80 ms) re-llamaba 4 SetWindowPos + 4 WinSetTransparent aunque nada cambió
        clave := x "," y "," w "," h "," g
        try {
            if (this._k = clave && DllCall("IsWindowVisible", "Ptr", this.T.Hwnd))
                return
        }
        this._k := clave
        flags := 0x10 | 0x40
        DllCall("SetWindowPos","Ptr",this.T.Hwnd,"Ptr",-1,"Int",x,"Int",y,"Int",w,"Int",g,"UInt",flags)
        DllCall("SetWindowPos","Ptr",this.B.Hwnd,"Ptr",-1,"Int",x,"Int",y + h - g,"Int",w,"Int",g,"UInt",flags)
        DllCall("SetWindowPos","Ptr",this.L.Hwnd,"Ptr",-1,"Int",x,"Int",y,"Int",g,"Int",h,"UInt",flags)
        DllCall("SetWindowPos","Ptr",this.R.Hwnd,"Ptr",-1,"Int",x + w - g,"Int",y,"Int",g,"Int",h,"UInt",flags)
        WinSetTransparent(85,"ahk_id " this.T.Hwnd)
        WinSetTransparent(85,"ahk_id " this.B.Hwnd)
        WinSetTransparent(85,"ahk_id " this.L.Hwnd)
        WinSetTransparent(85,"ahk_id " this.R.Hwnd)
    }
    Hide() {
        this._k := ""
        this.T.Hide()
        this.B.Hide()
        this.L.Hide()
        this.R.Hide()
    }
}
IniciarDeteccion() {
    bestHwnd := 0
    bestArea := 0
    for hwnd in WinGetList("ahk_exe CLIPStudioPaint.exe") {
        try {
            WinGetPos(&tx,&ty,&tw,&th,"ahk_id " hwnd)
            if (tw * th > bestArea) {
                bestArea := tw * th
                bestHwnd := hwnd
            }
        }
    }
    colorV.cspHwnd := bestHwnd
    colorV.dsID := BuscarVentanaCSP(0,"eslizador","colores")
    if (colorV.dsID) {
        colorV.bDS := BorderFrame("44AA66")
        colorV.hover := true
        colorV.dsVis := false
        try WinSetTransparent(5,"ahk_id " colorV.dsID)
        try WinSetExStyle("+0x20","ahk_id " colorV.dsID)
    }
    colorCC.id := BuscarVentanaCSP(0,"rculo de colores","olores")
    if (colorCC.id) {
        colorCC.bCC := BorderFrame("AA6622")
        colorCC.hover := false
        colorCC.dsVis := true
        try WinSetTransparent(255,"ahk_id " colorCC.id)
        try WinSetExStyle("-0x20","ahk_id " colorCC.id)
    }
    ar.id := BuscarVentanaCSP(0,"Acceso r","pido")
    if (ar.id) {
        ar.bAR := BorderFrame("AA8844")
        ar.hover := false
        ar.dsVis := true
        try WinSetTransparent(255,"ahk_id " ar.id)
        try WinSetExStyle("-0x20","ahk_id " ar.id)
    }
}
BuscarVentanaCSP(idActual,frag1,frag2) {
    if (idActual) {
        try {
            if WinExist("ahk_id " idActual)
                return idActual
        }
    }
    for hwnd in WinGetList("ahk_exe CLIPStudioPaint.exe") {
        try {
            t := WinGetTitle("ahk_id " hwnd)
            if InStr(t,frag1) && InStr(t,frag2)
                return hwnd
        }
    }
    return 0
}
CheckReload() {
    try newTime := FileGetTime(A_ScriptFullPath,"M")
    catch
        return
    if (sys.lastModTime = "") {
        sys.lastModTime := newTime
        return
    }
    if (newTime != sys.lastModTime) {
        sys.lastModTime := newTime
        mon := ObtenerMonitorCSP()
        x := mon.x + (mon.w // 2) - 120
        y := mon.y + (mon.h // 2) - 20
        ToolTip("💾 Script actualizado y recargado",x,y)
        _SonarUI("reload")
        Sleep(300)
        ToolTip()
        Reload()
    }
}
ChequearZonaHistorial() {
    if !WinActive("ahk_exe CLIPStudioPaint.exe")
        return
    if sys.modoEscritura
        return
    if (hist.modo = 2)
        return
    MouseGetPos(&mx,&my)
    z := ZONAS.hist
    enZona := (mx >= z.x1 && mx <= z.x2 && my >= z.y1 && my <= z.y2)
    if (enZona && !hist.abierto) {
        hist.abierto := true
        Send("{Numpad9}")
    } else if (!enZona && hist.abierto) {
        hist.abierto := false
        Send("{Numpad9}")
    }
}
LimpiarAltPegadoPureRef() {
    if !stylus.altActive
        return
    if !WinActive("ahk_exe PureRef.exe")
        return
    stylus.altActive := false
    Send("{Alt up}")
}
ChequearZonaAltA() {
    if !WinActive("ahk_exe CLIPStudioPaint.exe")
        return
    if sys.modoEscritura
        return
    _ChequearBotones(btn,ZONAS.izq)
}
ChequearZonaDerecha() {
    if !WinActive("ahk_exe CLIPStudioPaint.exe")
        return
    if sys.modoEscritura
        return
    _ChequearBotones(botDer,ZONAS.der)
}
_ChequearBotones(estado,zonas) {
    if !enfoque.activo
        return
    MouseGetPos(&mx,&my)
    Loop 3 {
        z := zonas[A_Index]
        k := "b" A_Index
        enZona := (mx >= z.x1 && mx <= z.x2 && my >= z.y1 && my <= z.y2)
        if (enZona && !estado.%k%) {
            estado.%k% := true
            SendEvent("{Click " mx " " my "}")
        } else if (!enZona && estado.%k%)
            estado.%k% := false
    }
}
LoopColorV() {
    if !WinActive("ahk_exe CLIPStudioPaint.exe") {
        if (colorV.hover) {
            if (colorV.dsVis && colorV.dsID) {
                colorV.dsVis := false
                try WinSetTransparent(5,"ahk_id " colorV.dsID)
                try WinSetExStyle("+0x20","ahk_id " colorV.dsID)
            }
            if IsObject(colorV.bDS)
                colorV.bDS.Hide()
        }
        return
    }
    if (!colorV.dsID) {
        colorV.dsID := BuscarVentanaCSP(0,"eslizador","colores")
        if (colorV.dsID) {
            colorV.bDS := BorderFrame("44AA66")
            colorV.dsVis := false
            try WinSetTransparent(5,"ahk_id " colorV.dsID)
            try WinSetExStyle("+0x20","ahk_id " colorV.dsID)
        }
        return
    }
    try {
        if !WinExist("ahk_id " colorV.dsID) {
            if IsObject(colorV.bDS)
                colorV.bDS.Hide()
            colorV.dsID := 0
            colorV.dsVis := false
            return
        }
        WinGetPos(&wx,&wy,&ww,&wh,"ahk_id " colorV.dsID)
        colorV.dsX := wx
        colorV.dsY := wy
        colorV.dsW := ww
        colorV.dsH := wh
    } catch {
        if IsObject(colorV.bDS)
            colorV.bDS.Hide()
        colorV.dsID := 0
        colorV.dsVis := false
        return
    }
    if (!colorV.hover)
        return
    MouseGetPos(&mx,&my)
    enDS := (mx >= wx && mx <= wx + ww && my >= wy && my <= wy + wh)
    enCirculo := false
    if (colorCC.id && colorCC.ccW > 0) {
        if (colorCC.hover)
            enCirculo := colorCC.dsVis
        else
            enCirculo := (mx >= colorCC.ccX && mx <= colorCC.ccX + colorCC.ccW && my >= colorCC.ccY && my <= colorCC.ccY + colorCC.ccH)
    }
    if (A_TickCount < colorV.supresionHasta) {
        enDS := false
        enCirculo := false
    }
    if (enDS || enCirculo) {
        if (!colorV.dsVis) {
            colorV.dsVis := true
            try WinSetTransparent(255,"ahk_id " colorV.dsID)
            try WinSetExStyle("-0x20","ahk_id " colorV.dsID)
            if IsObject(colorV.bDS)
                colorV.bDS.Hide()
        }
    } else {
        if (colorV.dsVis) {
            colorV.dsVis := false
            try WinSetTransparent(5,"ahk_id " colorV.dsID)
            try WinSetExStyle("+0x20","ahk_id " colorV.dsID)
        }
        if IsObject(colorV.bDS)
            colorV.bDS.Show(wx,wy,ww,wh)
    }
}
LoopColorCC() {
    if !WinActive("ahk_exe CLIPStudioPaint.exe") {
        if (colorCC.hover) {
            if (colorCC.dsVis && colorCC.id) {
                colorCC.dsVis := false
                try WinSetTransparent(5,"ahk_id " colorCC.id)
                try WinSetExStyle("+0x20","ahk_id " colorCC.id)
            }
            if IsObject(colorCC.bCC)
                colorCC.bCC.Hide()
        }
        colorCC.ccW := 0
        return
    }
    if (!colorCC.id) {
        colorCC.id := BuscarVentanaCSP(0,"rculo de colores","olores")
        if (colorCC.id) {
            colorCC.bCC := BorderFrame("AA6622")
            colorCC.dsVis := false
            try WinSetTransparent(5,"ahk_id " colorCC.id)
            try WinSetExStyle("+0x20","ahk_id " colorCC.id)
        }
        return
    }
    try {
        if !WinExist("ahk_id " colorCC.id) {
            if IsObject(colorCC.bCC)
                colorCC.bCC.Hide()
            colorCC.id := 0
            colorCC.dsVis := false
            colorCC.ccW := 0
            return
        }
        WinGetPos(&wx,&wy,&ww,&wh,"ahk_id " colorCC.id)
        colorCC.ccX := wx
        colorCC.ccY := wy
        colorCC.ccW := ww
        colorCC.ccH := wh
    } catch {
        if IsObject(colorCC.bCC)
            colorCC.bCC.Hide()
        colorCC.id := 0
        colorCC.dsVis := false
        colorCC.ccW := 0
        return
    }
    if (!colorCC.hover)
        return
    MouseGetPos(&mx,&my)
    dentro := (mx >= wx && mx <= wx + ww && my >= wy && my <= wy + wh)
    if (!dentro) {
        enDeslizador := false
        if (!colorV.hover && colorV.dsID && colorV.dsW > 0)
            enDeslizador := (mx >= colorV.dsX && mx <= colorV.dsX + colorV.dsW && my >= colorV.dsY && my <= colorV.dsY + colorV.dsH)
        dentro := enDeslizador
    }
    if (A_TickCount < colorCC.supresionHasta)
        dentro := false
    if (dentro) {
        if (!colorCC.dsVis) {
            colorCC.dsVis := true
            try WinSetTransparent(255,"ahk_id " colorCC.id)
            try WinSetExStyle("-0x20","ahk_id " colorCC.id)
            if IsObject(colorCC.bCC)
                colorCC.bCC.Hide()
        }
    } else {
        if (colorCC.dsVis) {
            colorCC.dsVis := false
            try WinSetTransparent(5,"ahk_id " colorCC.id)
            try WinSetExStyle("+0x20","ahk_id " colorCC.id)
        }
        if IsObject(colorCC.bCC)
            colorCC.bCC.Show(wx,wy,ww,wh)
    }
}
LoopAccesoRapido() {
    if (!ar.hover)
        return
    if !WinActive("ahk_exe CLIPStudioPaint.exe") {
        if (ar.dsVis && ar.id) {
            ar.dsVis := false
            try WinSetTransparent(5,"ahk_id " ar.id)
            try WinSetExStyle("+0x20","ahk_id " ar.id)
        }
        if IsObject(ar.bAR)
            ar.bAR.Hide()
        return
    }
    if (!ar.id) {
        ar.id := BuscarVentanaCSP(0,"Acceso r","pido")
        if (ar.id) {
            ar.bAR := BorderFrame("AA8844")
            ar.dsVis := false
            try WinSetTransparent(5,"ahk_id " ar.id)
            try WinSetExStyle("+0x20","ahk_id " ar.id)
        }
        return
    }
    try {
        if !WinExist("ahk_id " ar.id) {
            if IsObject(ar.bAR)
                ar.bAR.Hide()
            ar.id := 0
            ar.dsVis := false
            return
        }
        WinGetPos(&wx,&wy,&ww,&wh,"ahk_id " ar.id)
    } catch {
        if IsObject(ar.bAR)
            ar.bAR.Hide()
        ar.id := 0
        ar.dsVis := false
        return
    }
    MouseGetPos(&mx,&my)
    dentro := (mx >= wx && mx <= wx + ww && my >= wy && my <= wy + wh)
    if (dentro) {
        if (!ar.dsVis) {
            ar.dsVis := true
            try WinSetTransparent(255,"ahk_id " ar.id)
            try WinSetExStyle("-0x20","ahk_id " ar.id)
            if IsObject(ar.bAR)
                ar.bAR.Hide()
        }
    } else {
        if (ar.dsVis) {
            ar.dsVis := false
            try WinSetTransparent(5,"ahk_id " ar.id)
            try WinSetExStyle("+0x20","ahk_id " ar.id)
        }
        if IsObject(ar.bAR)
            ar.bAR.Show(wx,wy,ww,wh)
    }
}
ResetProcesando() => E.procesando := false
__Q_SEND_NORMAL() {
    global colorEstado
    Q.pendiente := false
    SendInput("q")
    _SonarUI("pluma")
    Stab_ResetUniversal("q")
    if (colorEstado = 1)
        MostrarMiniTextoOscuro("🟡 COLOR SECUNDARIO", _Tema("color", "color_secundario", "51D67B"), 800)
    else if (colorEstado = 2)
        MostrarMiniTexto("⚪ ALPHA TRANSPARENTE", _Tema("color", "color_alpha", "1C6EA4"), 800)
    else
        MostrarMiniTexto("🔵 COLOR PRIMARIO", _Tema("color", "color_primario", "00E5FF"), 800)
}
AlternarEstabilizacion() {
    global stabU, Q, estabGui, ESTAB_MAX, ESTAB_MIN
    static ocupado := false
    static lastTick := 0
    static lastPressTime := 0
    static reintentos := 0
    ; Un reset universal en curso NO debe tragarse el toggle: abortarlo y reintentar enseguida
    if stabU.ocupado {
        stabU.abortar := true
        if (reintentos < 6) {
            reintentos += 1
            SetTimer(AlternarEstabilizacion, -25)
        }
        return
    }
    reintentos := 0
    now := A_TickCount
    if (ocupado || (now - lastTick < 30))
        return
    if GetKeyState("LButton","P")
        return
    lastTick := now
    ocupado := true
    esDobleTap := (now - lastPressTime < 350)
    lastPressTime := esDobleTap ? 0 : now
    delta := ESTAB_MAX - ESTAB_MIN
    alta := (Q.estadoEstab = 0)
    destino := alta ? ESTAB_MAX : ESTAB_MIN
    if esDobleTap
        envio := "{j 100}{- " destino "}"
    else
        envio := alta ? "{- " delta "}" : "{j " delta "}"
    try {
        SendInput(envio)                       ; sin BlockInput: SendInput ya es atomico y BlockInput anade latencia
        Q.estadoEstab := alta ? 1 : 0
        if esDobleTap {
            estabGui.valor := destino
            estabGui.previsto := destino
            estabGui.sincronizado := true
        } else if estabGui.sincronizado {
            estabGui.valor := Max(0,Min(100,estabGui.valor + (alta ? delta : -delta)))
            estabGui.previsto := estabGui.valor
        }
        if estabGui.sincronizado
            _Stab_Recordar(estabGui.valor)
        OutputDebug("[StabNormal] envio=" envio " ms=" (A_TickCount - now))
        ; Toda la parte visual/sonora despues del envio y fuera de este hilo
        SetTimer(_Stab_ToggleUI.Bind(alta, esDobleTap), -1)
    } finally {
        ocupado := false
    }
}
_Stab_ToggleUI(alta, esDobleTap) {
    global ESTAB_MAX, ESTAB_MIN, estabGui
    SetTimer(alta ? _BeepEstabAlta : _BeepEstabBaja, -1)
    if esDobleTap
        MostrarMiniTexto("🔄 RE-SINCRONIZADO: " (alta ? "ALTA (" ESTAB_MAX ")" : "BAJA (" ESTAB_MIN ")"), alta ? "1A5C2A" : "1A2E5C", 1000)
    else
        MostrarMiniTexto(alta ? "🟢 ESTABILIZACIÓN ALTA (" ESTAB_MAX ")" : "🔵 ESTABILIZACIÓN BAJA (" ESTAB_MIN ")", alta ? "1A5C2A" : "1A2E5C", 700)
    if estabGui.sincronizado
        ActualizarEstabGUI()
}
_AplicarEstabVisibilidadBase() {
    if !IsObject(estabGui.g) || estabGui.foco
        return
    if (estabGui.visible && enfoque.activo) {
        try estabGui.g.Show("NoActivate")
        _EstabDibujar()
    } else {
        try estabGui.g.Hide()
    }
}
AccionEnfoque() {
    enfoque.activo := !enfoque.activo
    MouseGetPos(&origX,&origY)
    Click(PUNTOS[1][1] " " PUNTOS[1][2])
    Click(PUNTOS[2][1] " " PUNTOS[2][2])
    DllCall("SetCursorPos","int",origX,"int",origY)
    PtsModo_SincronizarCSP()
    _AplicarLayoutPaneles(enfoque.activo ? "Enfoque" : "Normal")
    _NotificarPureRef(enfoque.activo ? 1 : 0)
    if (enfoque.activo) {
        _EstabFocoOcultar()
        _AplicarEstabVisibilidadBase()
        MostrarGUIEnfoque()
        MostrarHUD("🎯 MODO ENFOQUE","00E5FF",900)
        _SonarUI("enfoque_on")
    } else {
        OcultarGUIEnfoque()
        _EstabFocoOcultar()
        _AplicarEstabVisibilidadBase()
        MostrarHUD("🖥 MODO NORMAL","44DD88",900)
        _SonarUI("enfoque_off")
    }
    _ModoSelRefrescar()
}
_NotificarPureRef(modo) {
    prevDHW := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    for hwnd in WinGetList("ahk_class AutoHotkey") {
        try {
            title := WinGetTitle("ahk_id " hwnd)
            if InStr(title,"PureRef_layout.ahk")
                PostMessage(0x5501,modo,0,,"ahk_id " hwnd)
        }
    }
    DetectHiddenWindows(prevDHW)
}
_IdsPaneles() {
    try {
        if (!colorV.dsID || !WinExist("ahk_id " colorV.dsID))
            colorV.dsID := BuscarVentanaCSP(0,"eslizador","colores")
        if (!colorCC.id || !WinExist("ahk_id " colorCC.id))
            colorCC.id := BuscarVentanaCSP(0,"rculo de colores","olores")
        if (!ar.id || !WinExist("ahk_id " ar.id))
            ar.id := BuscarVentanaCSP(0,"Acceso r","pido")
        if (!hist.id || !WinExist("ahk_id " hist.id))
            hist.id := BuscarVentanaCSP(0,"istorial","color")
    }
    ids := Map()
    ids["ds"] := colorV.dsID
    ids["cc"] := colorCC.id
    ids["ar"] := ar.id
    ids["hc"] := hist.id
    return ids
}
_LayoutPanelGuardado(nombre,clave,mon) {
    ini := _PosGuiIniPath()
    sec := "Layout" nombre
    x := IniRead(ini,sec,clave "x","")
    y := IniRead(ini,sec,clave "y","")
    w := IniRead(ini,sec,clave "w","")
    h := IniRead(ini,sec,clave "h","")
    if (x = "" || y = "" || w = "" || h = "")
        return 0
    return {x:mon.x + Integer(x),y:mon.y + Integer(y),w:Integer(w),h:Integer(h)}
}
_AplicarLayoutPaneles(nombre) {
    global dsGui, ccGui, arGui, hcGui
    mon := ObtenerMonitorCSP()
    def := (nombre = "Enfoque") ? LAYOUT_ENFOQUE : LAYOUT_NORMAL
    SWP_FLAGS := 0x0004 | 0x0010
    for clave,id in _IdsPaneles() {
        if (!id || !WinExist("ahk_id " id))
            continue
        r := _LayoutPanelGuardado(nombre,clave,mon)
        if (!r)
            r := def.%clave%
        x := Max(mon.x,Min(r.x,mon.x + mon.w - r.w))
        y := Max(mon.y,Min(r.y,mon.y + mon.h - r.h))
        try {
            DllCall("SetWindowPos","Ptr",id,"Ptr",0,"int",x,"int",y,"int",r.w,"int",r.h,"uint",SWP_FLAGS)
            if (clave = "ds") {
                colorV.dsX := x
                colorV.dsY := y
                colorV.dsW := r.w
                colorV.dsH := r.h
            } else if (clave = "cc") {
                colorCC.ccX := x
                colorCC.ccY := y
                colorCC.ccW := r.w
                colorCC.ccH := r.h
            }
        }
    }

}
_CapturarLayout(nombre) {
    global dsGui, ccGui, arGui, hcGui
    _SonarUI("layout")
    ToolTip("Guardando layout " nombre "...")
    SetTimer(() => ToolTip(),-1500)
    try {
        if (!colorV.dsID)
            colorV.dsID := BuscarVentanaCSP(0,"eslizador","colores")
        if (!colorCC.id)
            colorCC.id := BuscarVentanaCSP(0,"rculo de colores","olores")
        if (!ar.id)
            ar.id := BuscarVentanaCSP(0,"Acceso r","pido")
        if (!hist.id)
            hist.id := BuscarVentanaCSP(0,"istorial","color")
    }
    mon := ObtenerMonitorCSP()
    ini := _PosGuiIniPath()
    sec := "Layout" nombre
    guardados := 0
    for clave,id in _IdsPaneles() {
        if (!id || !WinExist("ahk_id " id))
            continue
        try {
            WinGetPos(&x,&y,&w,&h,"ahk_id " id)
            IniWrite(x - mon.x,ini,sec,clave "x")
            IniWrite(y - mon.y,ini,sec,clave "y")
            IniWrite(w,ini,sec,clave "w")
            IniWrite(h,ini,sec,clave "h")
            guardados++
        }
    }

    MostrarHUD("LAYOUT " StrUpper(nombre) " GUARDADO (" guardados "/4)",guardados = 4 ? "44DD88" : "FF6B00",1600)
}
MostrarGUIEnfoque() {
    mon := ObtenerMonitorCSP()
    opts := "-Caption +AlwaysOnTop +ToolWindow +E0x20"
    flags := 0x0010 | 0x0040
    x := mon.x
    y := mon.y
    w := mon.w
    h := mon.h
    if (!HasProp(floatGui,"enfoqueGuis") || !IsObject(floatGui.enfoqueGuis) || floatGui.enfoqueGuis.Length != 8) {
        floatGui.enfoqueGuis := []
        Loop 4 {
            g := Gui(opts)
            g.BackColor := "0077B6"
            g.Show("w0 h0 NoActivate")
            WinSetTransparent(46,g)
            floatGui.enfoqueGuis.Push(g)
        }
        Loop 4 {
            g := Gui(opts)
            g.BackColor := "00B4D8"
            g.Show("w0 h0 NoActivate")
            WinSetTransparent(76,g)
            floatGui.enfoqueGuis.Push(g)
        }
    }
    DllCall("SetWindowPos","Ptr",floatGui.enfoqueGuis[1].Hwnd,"Ptr",-1,"Int",x,"Int",y,"Int",w,"Int",6,"UInt",flags)
    DllCall("SetWindowPos","Ptr",floatGui.enfoqueGuis[2].Hwnd,"Ptr",-1,"Int",x,"Int",y + h - 6,"Int",w,"Int",6,"UInt",flags)
    DllCall("SetWindowPos","Ptr",floatGui.enfoqueGuis[3].Hwnd,"Ptr",-1,"Int",x,"Int",y,"Int",6,"Int",h,"UInt",flags)
    DllCall("SetWindowPos","Ptr",floatGui.enfoqueGuis[4].Hwnd,"Ptr",-1,"Int",x + w - 6,"Int",y,"Int",6,"Int",h,"UInt",flags)
    DllCall("SetWindowPos","Ptr",floatGui.enfoqueGuis[5].Hwnd,"Ptr",-1,"Int",x,"Int",y,"Int",w,"Int",3,"UInt",flags)
    DllCall("SetWindowPos","Ptr",floatGui.enfoqueGuis[6].Hwnd,"Ptr",-1,"Int",x,"Int",y + h - 3,"Int",w,"Int",3,"UInt",flags)
    DllCall("SetWindowPos","Ptr",floatGui.enfoqueGuis[7].Hwnd,"Ptr",-1,"Int",x,"Int",y,"Int",3,"Int",h,"UInt",flags)
    DllCall("SetWindowPos","Ptr",floatGui.enfoqueGuis[8].Hwnd,"Ptr",-1,"Int",x + w - 3,"Int",y,"Int",3,"Int",h,"UInt",flags)
}
OcultarGUIEnfoque() {
    if (HasProp(floatGui,"enfoqueGuis") && IsObject(floatGui.enfoqueGuis)) {
        for g in floatGui.enfoqueGuis {
            try DllCall("ShowWindow","Ptr",g.Hwnd,"Int",0)
        }
    }
}
ResetEnfoque() {
    if (enfoque.activo) {
        enfoque.activo := false
        OcultarGUIEnfoque()
        _EstabFocoOcultar()
        _AplicarEstabVisibilidadBase()
        try _ModoSelRefrescar()
    }
}
ResetAlphaStates() {
    global colorEstado,panelBlk,floatGui
    if !WinActive("ahk_exe CLIPStudioPaint.exe") {
        if panelBlk.frente {
            _MostrarPaneles()
            _TraerPanelesAlFrente()
            return
        }
        for g in [dial,dsGui,ccGui,arGui,hcGui,nvGui,lockGui,frenteGui,estabBtnGui,reloadGui,estabGui] {
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
    global hubGui, lockGui, frenteGui, puntosGui, estabBtnGui, reloadGui, dsGui, ccGui, arGui, hcGui
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
    return false
}

_TraerPanelesAlFrente() {
    for g in [dsGui,ccGui,arGui,hcGui,nvGui,lockGui,frenteGui,estabBtnGui,reloadGui,puntosGui,estabGui] {
        if !IsObject(g.g) || _EsPanelEmbebido(g)
            continue
        try {
            if DllCall("IsWindowVisible","Ptr",g.g.Hwnd)
                DllCall("SetWindowPos","Ptr",g.g.Hwnd,"Ptr",-1,"int",0,"int",0,"int",0,"int",0,"uint",0x0001 | 0x0002 | 0x0010)
        }
    }
}
_MostrarPaneles() {
    estabHwnd := IsObject(estabGui.g) ? estabGui.g.Hwnd : 0
    for g in [dial,dsGui,ccGui,arGui,hcGui,nvGui,lockGui,frenteGui,estabBtnGui,reloadGui,estabGui] {
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
        while GetKeyState("LButton","P")
            Sleep(5)
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
        Loop {
            if GetKeyState("Escape","P") {   ; Esc = cancelar el gesto sin aplicar nada
                tocados := []
                break
            }
            soltado := !GetKeyState("LButton","P") || (A_TickCount - t0 > 3000)   ; failsafe 3 s: aplica lo barrido
            DllCall("GetCursorPos","Ptr",cur)
            mx := NumGet(cur,0,"int"), my := NumGet(cur,4,"int")
            if (mx != px || my != py) {
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
            if soltado
                break
            Sleep(1)
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
    while GetKeyState("LButton","P") {
        DllCall("GetCursorPos","Ptr",cur)
        mx := NumGet(cur,0,"int"), my := NumGet(cur,4,"int")
        if (Abs(mx - clickX) > 4 || Abs(my - clickY) > 4) {
            movido := true
            DllCall("SetWindowPos","Ptr",guiObj.g.Hwnd,"Ptr",0,"int",mx-offX,"int",my-offY
                ,"int",0,"int",0,"uint",0x0001|0x0004|0x0010)
        }
        Sleep(8)
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
IniciarDsGUI() {
    dsGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow","")
    dsGui.g.BackColor := _Tema("color","surface.off","424242")
    dsGui.g.MarginX := 0
    dsGui.g.MarginY := 0
    WinSetTransparent(_AlphaTema("pill",235),dsGui.g)
    dsGui.icono := dsGui.g.Add("Picture","x" _E(4) " y" _E(2) " w" _E(20) " h" _E(20) " BackgroundTrans","")
    dsGui.label := dsGui.g.Add("Text","x" _E(26) " y" _E(3) " w" _E(76) " h" _E(19) " cWhite","")
    dsGui.label.SetFont("s" _FS(9) " bold","Segoe UI")
    dsGui.barra := dsGui.g.Add("Progress","x0 y" _E(22) " w" _E(104) " h" _E(3))
    dsGui.barra.Visible := _PillFranja()
    OnMessage(0x0201,_DsGUI_WM_LBUTTONDOWN)
    dsGui.g.OnEvent("ContextMenu", (*) => _MostrarMenuContextualHub())
    posDs := LeerPosicionGUI("Slider")
    if !(IsObject(posDs) && _PosicionValidaEnPantalla(posDs.x,posDs.y))
        posDs := _AnclaBloquePaneles()
    dsGui.g.Show("x" posDs.x " y" posDs.y " w" _E(104) " h" _E(25) " NoActivate")
    _DwmRedondear(dsGui.g.Hwnd)
    ActualizarDsGUI()
}
ActualizarDsGUI() {
    if (colorV.hover) {
        _SetIcono(dsGui.icono,"slider_on",true)
        dsGui.label.Value := "SLIDER"
        dsGui.barra.Opt("c" _Tema("color","accent.estabSoft","B4C0DE"))
        dsGui.g.BackColor := _Tema("color","surface.on","636D83")
        dsGui.label.SetFont("s" _FS(9) " bold c" _Tema("color","text.primary","FFFFFF"),"Segoe UI")
    } else {
        _SetIcono(dsGui.icono,"slider_off",false)
        dsGui.label.Value := "SLIDER"
        dsGui.barra.Opt("c" _Tema("color","track.pillOff","6A6A6A"))
        dsGui.g.BackColor := _Tema("color","surface.off","424242")
        dsGui.label.SetFont("s" _FS(9) " bold c" _Tema("color","text.idle","B2B2B2"),"Segoe UI")
    }
    dsGui.barra.Value := 100
}
_DsGUI_WM_LBUTTONDOWN(wParam,lParam,msg,hwnd) => _ArrastrarPanelBloque(hwnd,lParam,dsGui)
IniciarCcGUI() {
    ccGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow","")
    ccGui.g.BackColor := _Tema("color","surface.off","424242")
    ccGui.g.MarginX := 0
    ccGui.g.MarginY := 0
    WinSetTransparent(_AlphaTema("pill",235),ccGui.g)
    ccGui.icono := ccGui.g.Add("Picture","x" _E(4) " y" _E(2) " w" _E(20) " h" _E(20) " BackgroundTrans","")
    ccGui.label := ccGui.g.Add("Text","x" _E(26) " y" _E(3) " w" _E(76) " h" _E(19) " cWhite","")
    ccGui.label.SetFont("s" _FS(9) " bold","Segoe UI")
    ccGui.barra := ccGui.g.Add("Progress","x0 y" _E(22) " w" _E(104) " h" _E(3))
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
            dsW := _E(104)
        }
        ccX := dsX + dsW + PANEL_GAP
        ccY := dsY
    }
    ccGui.g.Show("x" ccX " y" ccY " w" _E(104) " h" _E(25) " NoActivate")
    _DwmRedondear(ccGui.g.Hwnd)
    ActualizarCcGUI()
}
ActualizarCcGUI() {
    if (colorCC.hover) {
        _SetIcono(ccGui.icono,"circle_on",true)
        ccGui.label.Value := "CIRCLE"
        ccGui.barra.Opt("c" _Tema("color","accent.estabSoft","B4C0DE"))
        ccGui.g.BackColor := _Tema("color","surface.on","636D83")
        ccGui.label.SetFont("s" _FS(9) " bold c" _Tema("color","text.primary","FFFFFF"),"Segoe UI")
    } else {
        _SetIcono(ccGui.icono,"circle_off",false)
        ccGui.label.Value := "CIRCLE"
        ccGui.barra.Opt("c" _Tema("color","track.pillOff","6A6A6A"))
        ccGui.g.BackColor := _Tema("color","surface.off","424242")
        ccGui.label.SetFont("s" _FS(9) " bold c" _Tema("color","text.idle","B2B2B2"),"Segoe UI")
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
    arGui.label := arGui.g.Add("Text","x" _E(26) " y" _E(3) " w" _E(76) " h" _E(19) " cWhite","")
    arGui.label.SetFont("s" _FS(9) " bold","Segoe UI")
    arGui.barra := arGui.g.Add("Progress","x0 y" _E(22) " w" _E(104) " h" _E(3))
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
            ccX := ancla.x + _E(104) + PANEL_GAP
            ccY := ancla.y
            ccW := _E(104)
        }
        arX := ccX + ccW + PANEL_GAP
        arY := ccY
    }
    arGui.g.Show("x" arX " y" arY " w" _E(104) " h" _E(25) " NoActivate")
    _DwmRedondear(arGui.g.Hwnd)
    ActualizarArGUI()
}
ActualizarArGUI() {
    if (ar.hover) {
        _SetIcono(arGui.icono,"quick_on",true)
        arGui.label.Value := "QUICK"
        arGui.barra.Opt("c" _Tema("color","accent.estabSoft","B4C0DE"))
        arGui.g.BackColor := _Tema("color","surface.on","636D83")
        arGui.label.SetFont("s" _FS(9) " bold c" _Tema("color","text.primary","FFFFFF"),"Segoe UI")
    } else {
        _SetIcono(arGui.icono,"quick_off",false)
        arGui.label.Value := "QUICK"
        arGui.barra.Opt("c" _Tema("color","track.pillOff","6A6A6A"))
        arGui.g.BackColor := _Tema("color","surface.off","424242")
        arGui.label.SetFont("s" _FS(9) " bold c" _Tema("color","text.idle","B2B2B2"),"Segoe UI")
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
    hcGui.label := hcGui.g.Add("Text","x" _E(26) " y" _E(3) " w" _E(76) " h" _E(19) " cWhite","")
    hcGui.label.SetFont("s" _FS(9) " bold","Segoe UI")
    hcGui.barra := hcGui.g.Add("Progress","x0 y" _E(22) " w" _E(104) " h" _E(3))
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
    hcGui.g.Show("x" x " y" y " w" _E(104) " h" _E(25) " NoActivate")
    _DwmRedondear(hcGui.g.Hwnd)
    ActualizarHCGUI()
}
ActualizarHCGUI() {
    if (hist.modo = 1) {
        _SetIcono(hcGui.icono,"hist_on",true)
        hcGui.label.Value := "HC"
        hcGui.barra.Opt("c" _Tema("color","accent.estabSoft","B4C0DE"))
        hcGui.g.BackColor := _Tema("color","surface.on","636D83")
        hcGui.label.SetFont("s" _FS(9) " bold c" _Tema("color","text.primary","FFFFFF"),"Segoe UI")
    } else {
        _SetIcono(hcGui.icono,"hist_on",false)
        hcGui.label.Value := "HC"
        hcGui.barra.Opt("c" _Tema("color","track.pillOff","6A6A6A"))
        hcGui.g.BackColor := _Tema("color","surface.off","424242")
        hcGui.label.SetFont("s" _FS(9) " bold c" _Tema("color","text.idle","B2B2B2"),"Segoe UI")
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
    nvGui.label.SetFont("s" _FS(9) " bold", "Segoe UI")
    nvGui.btnCrear := nvGui.g.Add("Text", "x" _E(64) " y" _E(1) " w" _E(16) " h" _E(20) " Center cWhite BackgroundTrans", "➕")
    nvGui.btnCrear.SetFont("s" _FS(9) " bold", "Segoe UI")
    nvGui.barra := nvGui.g.Add("Progress", "x0 y" _E(22) " w" _E(88) " h" _E(3))
    nvGui.barra.Visible := _PillFranja()
    nvGui.g.OnEvent("ContextMenu", (*) => _NvMostrarMenu())
    OnMessage(0x0201, _NvGUI_WM_LBUTTONDOWN)
    ActualizarNVGUI()
    x := IniRead(_PosGuiIniPath(), "NV", "x", 20)
    y := IniRead(_PosGuiIniPath(), "NV", "y", 140)
    nvGui.g.Show("x" x " y" y " w" _E(88) " h" _E(25) " NoActivate")
    nvGui.g.Hide()
    SetTimer(ActualizarNVGUI, 500)
}

ActualizarNVGUI() {
    global nvGui
    if !IsObject(nvGui.g)
        return
    e := NvEstado()
    nvGui.label.Text := "WINDOW"
    vis := _NvEstadoVisual(e)
    if (vis = "on") {
        nvGui.barra.Opt("c" _Tema("color", "accent.estabSoft", "B4C0DE"))
        nvGui.g.BackColor := _Tema("color", "surface.on", "636D83")
        nvGui.label.SetFont("s" _FS(9) " bold c" _Tema("color", "text.primary", "FFFFFF"), "Segoe UI")
    } else if (vis = "off") {
        nvGui.barra.Opt("c" _Tema("color", "track.pillOff", "6A6A6A"))
        nvGui.g.BackColor := _Tema("color", "surface.off", "424242")
        nvGui.label.SetFont("s" _FS(9) " bold c" _Tema("color", "text.idle", "B2B2B2"), "Segoe UI")
    } else {                                          ; mixto
        nvGui.barra.Opt("c" _Tema("color", "accent.estabSoft", "B4C0DE"))
        nvGui.g.BackColor := _Tema("color", "surface.off", "424242")
        nvGui.label.SetFont("s" _FS(9) " bold c" _Tema("color", "text.idle", "B2B2B2"), "Segoe UI")
    }
    nvGui.barra.Value := 100
}

_NvGUI_WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global nvGui
    if !IsObject(nvGui.g)
        return
    if (DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr") != nvGui.g.Hwnd)
        return
    ; Clic en el botón ➕ para crear ventana sin necesidad de atajos complejos
    if (HasProp(nvGui, "btnCrear") && IsObject(nvGui.btnCrear) && hwnd = nvGui.btnCrear.Hwnd) {
        _NvBotonCrearVentana()
        return 0
    }
    if KeyWait("LButton", "T0.25") {
        NvAlternarInteractivo()
        return 0
    }
    PostMessage(0xA1, 2, , , nvGui.g)
    SetTimer(_NvGUI_EsperarSoltar, 100)
    return 0
}

_NvGUI_EsperarSoltar() {
    global nvGui
    if GetKeyState("LButton", "P")
        return
    SetTimer(_NvGUI_EsperarSoltar, 0)
    WinGetPos(&x, &y, , , nvGui.g)
    IniWrite(x, _PosGuiIniPath(), "NV", "x")
    IniWrite(y, _PosGuiIniPath(), "NV", "y")
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

_NvMostrarMenu() {
    e := NvEstado()
    m := Menu()
    m.Add("➕ [Global] Crear nueva ventana", _NvBotonCrearVentana)
    m.Add()
    gl := Map("h_on", "[Global] Hover ON (reactivo 5%)"
            , "h_off", "[Global] Hover OFF (100% visible fija)"
            , "desact_25", "[Global] Desactivado 25% (bloqueada)")
    for modo, txt in gl
        m.Add(txt, _NvMenuGlobal.Bind(modo))
    if (e.modoGlobal != "")
        m.Check(gl[e.modoGlobal])
    m.Add()
    if (e.ventanas.Count = 0) {
        m.Add("Sin ventanas detectadas", (*) => 0)
        m.Disable("Sin ventanas detectadas")
    }
    nombres := Map("h_on", "Hover ON (reactivo 5%)"
                 , "h_off", "Hover OFF (100% visible fija)"
                 , "desact_25", "Desactivado 25% (bloqueada)")
    i := 0
    for h, zona in e.ventanas {
        i++
        efectivo := _NvModoEfectivo(e, h)
        sub := Menu()
        for modo, txt in nombres
            sub.Add(txt, _NvMenuIndividual.Bind(h, modo))
        sub.Check(nombres[efectivo])
        m.Add((zona != "" ? zona : ("Window " i)) "  -  " nombres[efectivo], sub)
    }
    m.Show()
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
    lockGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow","")
    lockGui.g.BackColor := _Tema("color","surface.off","424242")
    lockGui.g.MarginX := 0
    lockGui.g.MarginY := 0
    WinSetTransparent(_AlphaTema("pill",235),lockGui.g)
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
            arX := ancla.x + 2 * (_E(104) + PANEL_GAP)
            arY := ancla.y
            arW := _E(104)
        }
        lockX := arX + arW + PANEL_GAP
        lockY := arY
    }
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
    WinSetTransparent(_AlphaTema("pill",235),frenteGui.g)
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
            lX := ancla.x + 3 * (_E(104) + PANEL_GAP)
            lY := ancla.y
            lW := _E(31)
        }
        fX := lX + lW + PANEL_GAP
        fY := lY
    }
    sf := _RectaDentroDeMonitor(fX,fY,_E(31),_E(25)) ? {x:fX,y:fY} : _EsquinaPanelBloque(0)
    frenteGui.g.Show("x" sf.x " y" sf.y " w" _E(31) " h" _E(25) " NoActivate")
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
    panelBlk.frente := !panelBlk.frente
    _EscribirEstadoBloque("frente",panelBlk.frente ? 1 : 0)
    ActualizarFrenteGUI()
    ActualizarHubGUI()
    if panelBlk.frente {
        _MostrarPaneles()
        _TraerPanelesAlFrente()
    }
    MostrarHUD(panelBlk.frente ? "📌 GUI AL FRENTE" : "📌 GUI SOLO EN CSP",panelBlk.frente ? _Tema("color","accent.success","44DD88") : _Tema("color","accent.warn","FF6B00"),1200)
}
IniciarEstabBtnGUI() {
    estabBtnGui.g := Gui("+AlwaysOnTop -Caption +ToolWindow","")
    estabBtnGui.g.BackColor := _Tema("color","surface.off","424242")
    estabBtnGui.g.MarginX := 0
    estabBtnGui.g.MarginY := 0
    WinSetTransparent(_AlphaTema("pill",235),estabBtnGui.g)
    estabBtnGui.icono := estabBtnGui.g.Add("Picture","x" _E(4) " y" _E(2) " w" _E(20) " h" _E(20) " BackgroundTrans","")
    estabBtnGui.label := estabBtnGui.g.Add("Text","x" _E(26) " y" _E(3) " w" _E(76) " h" _E(19) " cWhite","")
    estabBtnGui.label.SetFont("s" _FS(9) " bold","Segoe UI")
    estabBtnGui.barra := estabBtnGui.g.Add("Progress","x0 y" _E(22) " w" _E(104) " h" _E(3))
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
            fX := ancla.x + 3 * (_E(104) + PANEL_GAP) + _E(31) + PANEL_GAP
            fY := ancla.y
            fW := _E(31)
        }
        eX := fX + fW + PANEL_GAP
        eY := fY
    }
    se := _RectaDentroDeMonitor(eX,eY,_E(104),_E(25)) ? {x:eX,y:eY} : _EsquinaPanelBloque(1)
    estabBtnGui.g.Show("x" se.x " y" se.y " w" _E(104) " h" _E(25) " NoActivate")
    _DwmRedondear(estabBtnGui.g.Hwnd)
    ActualizarEstabBtnGUI()
}
ActualizarEstabBtnGUI() {
    if !IsObject(estabBtnGui.g) || !IsObject(estabBtnGui.label)
        return
    v := estabGui.valor
    if estabGui.visible {
        _SetIcono(estabBtnGui.icono,"slider_on",true)
        estabBtnGui.label.Value := "ESTAB " v
        estabBtnGui.barra.Opt("c" _Tema("color","accent.estabSoft","B4C0DE"))
        estabBtnGui.g.BackColor := _Tema("color","surface.on","636D83")
        estabBtnGui.label.SetFont("s" _FS(9) " bold c" _Tema("color","text.primary","FFFFFF"),"Segoe UI")
    } else {
        _SetIcono(estabBtnGui.icono,"slider_on",false)
        estabBtnGui.label.Value := "ESTAB OFF"
        estabBtnGui.barra.Opt("c" _Tema("color","track.pillOff","6A6A6A"))
        estabBtnGui.g.BackColor := _Tema("color","surface.off","424242")
        estabBtnGui.label.SetFont("s" _FS(9) " bold c" _Tema("color","text.idle","B2B2B2"),"Segoe UI")
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
    WinSetTransparent(_AlphaTema("pill",235),reloadGui.g)
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
        while GetKeyState("LButton","P") {
            DllCall("GetCursorPos","Ptr",cur)
            mx := NumGet(cur,0,"int")
            my := NumGet(cur,4,"int")
            if (Abs(mx - clickX) > 4 || Abs(my - clickY) > 4) {
                movido := true
                DllCall("SetWindowPos","Ptr",reloadGui.g.Hwnd,"Ptr",0,"int",mx - offX,"int",my - offY,"int",0,"int",0,"uint",0x0001 | 0x0004 | 0x0010)
            }
            Sleep(8)
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
    for k in ["lock","frente","puntos","estab","reload","ds","cc","ar","hc","flip","enfoque"] {
        hubGui.embebidos[k] := (IniRead(ini,sec,"embeber_" k,"0") = "1")
    }

    ; El boton solitario Hub en la barra superior se retira por peticion del usuario:
    ; se mantiene 'QUICK' (arGui) con su icono y texto, y se accede a todo mediante click derecho en los companion.
    hubGui.g := 0
    hubGui.icono := 0
    hubGui.barra := 0

    OnMessage(0x0205,_Companion_WM_RBUTTON)
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
    global hubGui, lockGui, frenteGui, puntosGui, estabBtnGui, reloadGui, dsGui, ccGui, arGui, hcGui
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
    while GetKeyState("LButton","P") {
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
            AbrirPanelPuntos()
        case "estab":
            _ToggleEstabVisible()
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

    m := Menu()

    cat := [
        ["lock", "🔒 Bloquear Companion", () => panelBlk.locked ? "🔓 Desbloquear Companion" : "🔒 Fijar Companion"],
        ["frente", "📌 Modo Frente (AlwaysOnTop)", () => panelBlk.frente ? "📌 Modo Frente: Desactivar (Solo en CSP)" : "📌 Modo Frente: Activar (AlwaysOnTop)"],
        ["puntos", "📍 Calibrador de Zonas y Rangos", () => "📍 Calibrador de Zonas y Rangos"],
        ["estab", "🎚 Deslizador Estabilización", () => estabGui.visible ? "🎚 Deslizador: Ocultar" : "🎚 Deslizador: Mostrar"],
        ["ds", "🎚 Botón Slider / Pincel (DS)", () => colorV.hover ? "🎚 Slider / Pincel: Ocultar" : "🎚 Slider / Pincel: Mostrar"],
        ["cc", "🎨 Botón Círculo de Color (CC)", () => colorCC.hover ? "🎨 Círculo de Color: Ocultar" : "🎨 Círculo de Color: Mostrar"],
        ["ar", "⚡ Botón Acceso Rápido (AR)", () => ar.hover ? "⚡ Acceso Rápido: Ocultar" : "⚡ Acceso Rápido: Mostrar"],
        ["hc", "🕒 Botón Historial de Color (HC)", () => (hist.modo = 1) ? "🕒 Historial Color: Cambiar a Fijo" : "🕒 Historial Color: Cambiar a Dinámico"],
        ["flip", "🪞 Voltear Lienzo Horizontal", () => "🪞 Voltear Lienzo Horizontal"],
        ["enfoque", "🔍 Modo Enfoque", () => enfoque.activo ? "🔍 Salir de Modo Enfoque" : "🔍 Activar Modo Enfoque"],
        ["reload", "🔄 Recargar Script", () => "🔄 Recargar Script"]
    ]

    ; ── BLOQUE 1 (Superior): Comandos embebidos en el Hub ──
    cantEmbebidos := 0
    for item in cat {
        k := item[1]
        if (hubGui.embebidos.Has(k) && hubGui.embebidos[k]) {
            txtDyn := item[3]()
            m.Add(txtDyn, _EjecutarAccionHub.Bind(k))
            cantEmbebidos++
        }
    }

    if (cantEmbebidos = 0) {
        m.Add("📍 Abrir Calibrador de Zonas", (*) => _EjecutarAccionHub("puntos"))
        m.Add(panelBlk.locked ? "🔓 Desbloquear Companion" : "🔒 Fijar Companion", (*) => _EjecutarAccionHub("lock"))
        m.Add(panelBlk.frente ? "📌 Modo Frente: Desactivar" : "📌 Modo Frente: Activar", (*) => _EjecutarAccionHub("frente"))
        m.Add(estabGui.visible ? "🎚 Deslizador: Ocultar" : "🎚 Deslizador: Mostrar", (*) => _EjecutarAccionHub("estab"))
        m.Add("🔄 Recargar Script", (*) => _EjecutarAccionHub("reload"))
    }

    mLay := Menu()
    itN := "🖥 Modo 1 · Normal"
    itE := "🔍 Modo 2 · Enfoque"
    mLay.Add(itN, (*) => EstablecerModoTrabajo("Normal"))
    mLay.Add(itE, (*) => EstablecerModoTrabajo("Enfoque"))
    mLay.Check(enfoque.activo ? itE : itN)
    mLay.Add()
    mLay.Add("🎛 Selector flotante: Mostrar/Ocultar", (*) => ModoSel_Alternar())
    mLay.Add("💾 Guardar ubicaciones en el modo activo", (*) => _ModoGuardarActivo())
    mLay.Add("💾 Guardar posición actual como Modo 1 (Normal)", (*) => _CapturarLayout("Normal"))
    mLay.Add("💾 Guardar posición actual como Modo 2 (Enfoque)", (*) => _CapturarLayout("Enfoque"))
    m.Add("📐 Layout Paneles CSP (Modo 1 y 2)", mLay)

    m.Add("⚡ Acciones Rápidas (Capas y Lienzo)", (*) => MostrarAccionesRapidasGUI())
    m.Add("🔊 Restaurar Audio (Sin Reiniciar)", (*) => _CompanionRestaurarAudio())

    m.Add("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", (*) => 0)
    m.Disable("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    ; ── BLOQUE 2 (Inferior): Submenú para elegir cuáles embeber ──
    mEmb := Menu()
    for item in cat {
        k := item[1], txt := item[2]
        mEmb.Add(txt, _MenuToggleEmbebido.Bind(k))
        if (hubGui.embebidos.Has(k) && hubGui.embebidos[k])
            mEmb.Check(txt)
    }
    m.Add("☑ Embeber botones en el Hub", mEmb)

    m.Show()
}

_MenuToggleEmbebido(k, *) {
    global hubGui, PERFIL
    if !hubGui.embebidos.Has(k)
        hubGui.embebidos[k] := false
    hubGui.embebidos[k] := !hubGui.embebidos[k]
    IniWrite(hubGui.embebidos[k] ? 1 : 0,_PosGuiIniPath(),"Hub_p" PERFIL,"embeber_" k)
    _AplicarVisibilidadEmbebidos()
    ActualizarHubGUI()
    MostrarAvisoUI("moderno",hubGui.embebidos[k] ? "BOTÓN EMBEBIDO" : "BOTÓN SUELTO",StrUpper(k),2,"00E5FF",1200)
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
        while GetKeyState("LButton","P") {
            if (!panelBlk.locked) {
                DllCall("GetCursorPos","Ptr",cur)
                mx := NumGet(cur,0,"int")
                my := NumGet(cur,4,"int")
                if (Abs(mx - clickX) > 4 || Abs(my - clickY) > 4) {
                    movido := true
                    DllCall("SetWindowPos","Ptr",puntosGui.g.Hwnd,"Ptr",0,"int",mx - offX,"int",my - offY,"int",0,"int",0,"uint",0x0001 | 0x0004 | 0x0010)
                }
            }
            Sleep(8)
        }
        if !movido
            AbrirPanelPuntos()
        else
            GuardarPosicionGUI("PuntosBtn",puntosGui.g.Hwnd)
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
    lblTit.SetFont("s9 bold", "Segoe UI")

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

_CompanionRestaurarAudio() {
    res := 0
    try res := _AudReiniciar()
    if (res)
        MostrarAvisoUI("moderno", "AUDIO RESTAURADO", "SUBSISTEMA REINICIADO", 1, "00E5FF", 1200)
    else
        MostrarAvisoUI("moderno", "AUDIO EN CURSO", "REINICIO YA EN PROCESO", 2, "FF6B00", 1000)
}


; ===================== LIENZO HUD (Z / R / Space) =====================
; Overlay GDI+ vectorial: se dibuja UNA vez por modo a un DIB 32bpp y se muestra con UpdateLayeredWindow.
_TemaHex(clave, def) {
    c := def
    try c := Trim(_Tema("color", clave, def))
    return RegExMatch(c, "^[0-9A-Fa-f]{6}$") ? c : def
}
_LHArgb(hex, a) => (a << 24) | Integer("0x" hex)

_LH() {
    static e := {gui: 0, hwnd: 0, vis: false, modo: "", tecla: "", t0: 0, hasta: 0, paso: 0, pasos: 4
        , x: 0, y: 0, cache: Map(), tok: 0, fallo: false}
    return e
}
_LHGdipIniciar() {
    e := _LH()
    if (e.tok)
        return true
    if (e.fallo)
        return false
    try {
        if !DllCall("GetModuleHandle", "Str", "gdiplus", "Ptr")
            DllCall("LoadLibrary", "Str", "gdiplus")
        si := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
        NumPut("UInt", 1, si, 0)
        tok := 0
        if (DllCall("gdiplus\GdiplusStartup", "Ptr*", &tok, "Ptr", si, "Ptr", 0) = 0 && tok) {
            e.tok := tok
            return true
        }
    }
    e.fallo := true
    return false
}
_LHPen(argb, ancho) {
    pen := 0
    DllCall("gdiplus\GdipCreatePen1", "UInt", argb, "Float", ancho, "Int", 2, "Ptr*", &pen)
    if (pen) {
        DllCall("gdiplus\GdipSetPenLineCap197819", "Ptr", pen, "Int", 2, "Int", 2, "Int", 2)
        DllCall("gdiplus\GdipSetPenLineJoin", "Ptr", pen, "Int", 2)
    }
    return pen
}
_LHTrazo(gfx, argb, ancho, x1, y1, x2, y2) {
    pen := _LHPen(argb, ancho)
    if !pen
        return
    DllCall("gdiplus\GdipDrawLine", "Ptr", gfx, "Ptr", pen, "Float", x1, "Float", y1, "Float", x2, "Float", y2)
    DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
}
_LHArco(gfx, argb, ancho, x, y, w, h, a0, sw) {
    pen := _LHPen(argb, ancho)
    if !pen
        return
    DllCall("gdiplus\GdipDrawArc", "Ptr", gfx, "Ptr", pen, "Float", x, "Float", y, "Float", w, "Float", h, "Float", a0, "Float", sw)
    DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
}
_LHElipse(gfx, argb, ancho, x, y, w, h) {
    pen := _LHPen(argb, ancho)
    if !pen
        return
    DllCall("gdiplus\GdipDrawEllipse", "Ptr", gfx, "Ptr", pen, "Float", x, "Float", y, "Float", w, "Float", h)
    DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
}
_LHRelleno(gfx, argb, x, y, w, h) {
    br := 0
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", argb, "Ptr*", &br)
    if !br
        return
    DllCall("gdiplus\GdipFillEllipse", "Ptr", gfx, "Ptr", br, "Float", x, "Float", y, "Float", w, "Float", h)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
}
_LHFlecha(gfx, argb, ancho, cx, cy, r, angFin) {
    a := angFin * 0.0174532925
    px := cx + r * Cos(a)
    py := cy + r * Sin(a)
    bx := Sin(a)          ; -tangente
    by := -Cos(a)
    for lado in [0.62, -0.62] {
        c := Cos(lado)
        s := Sin(lado)
        vx := bx * c - by * s
        vy := bx * s + by * c
        _LHTrazo(gfx, argb, ancho, px, py, px + vx * 13, py + vy * 13)
    }
}
_LHConstruir(modo) {
    e := _LH()
    if e.cache.Has(modo)
        return e.cache[modo]
    if !_LHGdipIniciar()
        return 0
    w := 112
    h := 142
    try {
        w := _E(112)
        h := _E(142)
    }
    k := w / 112
    switch modo {
        case "z":
            acento := _TemaHex("accent.info", "00E5FF")
            txt := "ZOOM"
        case "r":
            acento := _TemaHex("accent.warn", "FF6B00")
            txt := "ROTAR"
        default:
            acento := _TemaHex("accent.success", "44DD88")
            txt := "MOVER"
    }
    fondo := _TemaHex("surface.base", "12141A")
    blanco := _TemaHex("text.primary", "F0F0F0")
    aCuerpo := 225
    try aCuerpo := Min(255, Integer(_AlphaTema("hud", 215)) + 10)
    familia := "Segoe UI"
    try familia := Trim(_Tema("type", "family", "Segoe UI"))

    hdc := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")
    bi := Buffer(40, 0)
    NumPut("UInt", 40, bi, 0)
    NumPut("Int", w, bi, 4)
    NumPut("Int", -h, bi, 8)
    NumPut("UShort", 1, bi, 12)
    NumPut("UShort", 32, bi, 14)
    bits := 0
    hbm := DllCall("CreateDIBSection", "Ptr", hdc, "Ptr", bi, "UInt", 0, "Ptr*", &bits, "Ptr", 0, "UInt", 0, "Ptr")
    if (!hbm) {
        DllCall("DeleteDC", "Ptr", hdc)
        return 0
    }
    DllCall("SelectObject", "Ptr", hdc, "Ptr", hbm, "Ptr")
    gfx := 0
    DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdc, "Ptr*", &gfx)
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", gfx, "Int", 4)
    DllCall("gdiplus\GdipSetTextRenderingHint", "Ptr", gfx, "Int", 4)
    DllCall("gdiplus\GdipScaleWorldTransform", "Ptr", gfx, "Float", k, "Float", k, "Int", 0)

    ; halo translúcido + cuerpo de vidrio + borde de acento
    Loop 6 {
        r := 56 - (A_Index - 1) * 1.2
        _LHRelleno(gfx, _LHArgb(acento, 16), 56 - r, 56 - r, r * 2, r * 2)
    }
    _LHRelleno(gfx, _LHArgb(fondo, aCuerpo), 10, 10, 92, 92)
    _LHElipse(gfx, _LHArgb(acento, 255), 3, 10, 10, 92, 92)

    ; glifos vectoriales
    cA := _LHArgb(acento, 255)
    cB := _LHArgb(blanco, 255)
    switch modo {
        case "z":      ; lupa con "+"
            _LHElipse(gfx, cA, 5, 35, 35, 30, 30)
            _LHTrazo(gfx, cA, 8, 61, 61, 74, 74)
            _LHTrazo(gfx, cB, 3.5, 44, 50, 56, 50)
            _LHTrazo(gfx, cB, 3.5, 50, 44, 50, 56)
        case "r":      ; dos flechas circulares
            _LHArco(gfx, cA, 5, 32, 32, 48, 48, 200, 120)
            _LHArco(gfx, cA, 5, 32, 32, 48, 48, 20, 120)
            _LHFlecha(gfx, cA, 5, 56, 56, 24, 320)
            _LHFlecha(gfx, cA, 5, 56, 56, 24, 140)
            _LHElipse(gfx, cB, 3, 53, 53, 6, 6)
        default:       ; mano (dedos, palma, pulgar)
            _LHTrazo(gfx, cA, 8, 46, 64, 46, 41)
            _LHTrazo(gfx, cA, 8, 56, 64, 56, 34)
            _LHTrazo(gfx, cA, 8, 66, 64, 66, 36)
            _LHTrazo(gfx, cA, 8, 76, 64, 76, 43)
            _LHTrazo(gfx, cA, 20, 52, 67, 70, 67)
            _LHTrazo(gfx, cA, 16, 54, 76, 68, 76)
            _LHTrazo(gfx, cA, 8, 45, 72, 33, 59)
    }

    ; etiqueta (cápsula + texto)
    _LHTrazo(gfx, cA, 24, 28, 127, 84, 127)
    _LHTrazo(gfx, _LHArgb(fondo, 255), 22, 28, 127, 84, 127)
    fam := 0
    DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", familia, "Ptr", 0, "Ptr*", &fam)
    if (fam) {
        fnt := 0
        fmt := 0
        br := 0
        DllCall("gdiplus\GdipCreateFont", "Ptr", fam, "Float", 12, "Int", 1, "Int", 2, "Ptr*", &fnt)
        DllCall("gdiplus\GdipCreateStringFormat", "Int", 0, "Int", 0, "Ptr*", &fmt)
        DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", fmt, "Int", 1)
        DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", fmt, "Int", 1)
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", cB, "Ptr*", &br)
        rc := Buffer(16, 0)
        NumPut("Float", 0, rc, 0)
        NumPut("Float", 116, rc, 4)
        NumPut("Float", 112, rc, 8)
        NumPut("Float", 22, rc, 12)
        if (fnt && fmt && br)
            DllCall("gdiplus\GdipDrawString", "Ptr", gfx, "WStr", txt, "Int", -1, "Ptr", fnt, "Ptr", rc, "Ptr", fmt, "Ptr", br)
        if (br)
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
        if (fmt)
            DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", fmt)
        if (fnt)
            DllCall("gdiplus\GdipDeleteFont", "Ptr", fnt)
        DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", fam)
    }
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gfx)
    ent := {hdc: hdc, hbm: hbm, w: w, h: h}
    e.cache[modo] := ent
    return ent
}
_LHAsegurarGui() {
    e := _LH()
    if (e.hwnd && DllCall("IsWindow", "Ptr", e.hwnd))
        return
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x80000 +E0x20 +E0x08000000", "LienzoHUD")
    e.gui := g
    e.hwnd := g.Hwnd
}
_LHPintar(ent, alfa) {
    e := _LH()
    pt := Buffer(8, 0)
    NumPut("Int", e.x, pt, 0)
    NumPut("Int", e.y, pt, 4)
    sz := Buffer(8, 0)
    NumPut("Int", ent.w, sz, 0)
    NumPut("Int", ent.h, sz, 4)
    ps := Buffer(8, 0)
    bl := Buffer(4, 0)
    NumPut("UChar", 0, "UChar", 0, "UChar", alfa, "UChar", 1, bl)
    DllCall("UpdateLayeredWindow", "Ptr", e.hwnd, "Ptr", 0, "Ptr", pt, "Ptr", sz, "Ptr", ent.hdc, "Ptr", ps, "UInt", 0, "Ptr", bl, "UInt", 2)
}
LienzoHUD_Mostrar(modo, tecla := "", minMs := 0) {
    e := _LH()
    if (modo != "z" && modo != "r" && modo != "space")
        return false
    ent := _LHConstruir(modo)
    if !ent
        return false
    if (e.vis && e.modo = modo && e.paso = 0) {      ; auto-repeat: solo extiende, sin repintar
        e.tecla := tecla
        e.hasta := Max(e.hasta, A_TickCount + minMs)
        return true
    }
    if (e.paso) {
        SetTimer(_LHFade, 0)
        e.paso := 0
    }
    _LHAsegurarGui()
    if !e.vis {
        pt := Buffer(8, 0)
        DllCall("GetCursorPos", "Ptr", pt)
        px := NumGet(pt, 0, "Int")
        py := NumGet(pt, 4, "Int")
        mon := {x: 0, y: 0, w: A_ScreenWidth, h: A_ScreenHeight}
        try mon := ObtenerMonitorCSP()
        pos := "cursor"
        try pos := Trim(_Tema("lienzo", "pos", "cursor"))
        if (pos = "centro") {
            x := mon.x + (mon.w - ent.w) // 2
            y := mon.y + (mon.h - ent.h) // 2
        } else {
            ; HUD centrado directamente sobre el puntero (el circulo reemplaza el icono/cursor de CSP)
            x := px - ent.w // 2
            y := py - ent.w // 2
        }
        e.x := Max(mon.x, Min(x, mon.x + mon.w - ent.w))
        e.y := Max(mon.y, Min(y, mon.y + mon.h - ent.h))
    }
    e.modo := modo
    e.tecla := tecla
    e.t0 := A_TickCount
    e.hasta := A_TickCount + minMs
    DllCall("ShowWindow", "Ptr", e.hwnd, "Int", 8)
    _LHPintar(ent, 255)
    e.vis := true
    SetTimer(_LHTick, 30)
    return true
}
_LHTick() {
    e := _LH()
    if !e.vis {
        SetTimer(_LHTick, 0)
        return
    }
    ahora := A_TickCount
    if (ahora < e.hasta)
        return
    if (e.tecla != "" && WinActive("ahk_exe CLIPStudioPaint.exe") && GetKeyState(e.tecla, "P") && ahora - e.t0 < 8000)
        return
    SetTimer(_LHTick, 0)
    ms := 120
    try ms := Integer(_Tema("motion", "fast", "60")) * 2
    e.pasos := Max(2, Min(8, ms // 15))
    e.paso := 0
    SetTimer(_LHFade, 15)
}
_LHFade() {
    e := _LH()
    e.paso += 1
    if (!e.vis || e.paso >= e.pasos || !e.cache.Has(e.modo)) {
        _LHOcultar()
        return
    }
    _LHPintar(e.cache[e.modo], Round(255 * (1 - e.paso / e.pasos)))
}
_LHOcultar() {
    e := _LH()
    SetTimer(_LHTick, 0)
    SetTimer(_LHFade, 0)
    e.vis := false
    e.paso := 0
    if (e.hwnd)
        DllCall("ShowWindow", "Ptr", e.hwnd, "Int", 0)
}
LienzoHUD_Invalidar() {   ; llamar tras cambiar colores de theme.ini (opcional)
    e := _LH()
    _LHOcultar()
    for k, ent in e.cache {
        DllCall("DeleteObject", "Ptr", ent.hbm)
        DllCall("DeleteDC", "Ptr", ent.hdc)
    }
    e.cache := Map()
}
LienzoHUD_ChequeoR() {
    if (!WinActive("ahk_exe CLIPStudioPaint.exe") || !GetKeyState("r", "P"))
        return
    LienzoHUD_Mostrar("r", "r", 0)
}
LienzoHUD_ChequeoSpace() {
    if (!WinActive("ahk_exe CLIPStudioPaint.exe") || !GetKeyState("Space", "P") || A_PriorKey != "Space")
        return
    LienzoHUD_Mostrar("space", "Space", 0)
}

; ===================== SELECTOR DE MODO (Normal / Enfoque) =====================
_ModoSel() {
    static s := {g: 0, tN: 0, tE: 0, tS: 0, tI: 0, visible: false, tray: 0, msg: false}
    return s
}
EstablecerModoTrabajo(nombre) {
    global enfoque
    if !IsSet(enfoque)
        return
    quiere := (nombre = "Enfoque") ? 1 : 0
    actual := enfoque.activo ? 1 : 0
    if (quiere = actual) {          ; ya está en ese modo: solo reaplica ubicaciones (sin tocar CSP)
        _AplicarLayoutPaneles(nombre)
        _ModoSelRefrescar()
        MostrarHUD(quiere ? "🔍 MODO ENFOQUE (ya activo)" : "🖥 MODO NORMAL (ya activo)", quiere ? "00E5FF" : "44DD88", 700)
        return
    }
    AccionEnfoque()
}
_ModoContarGuardados(nombre) {
    mon := {x: 0, y: 0, w: 0, h: 0}
    try mon := ObtenerMonitorCSP()
    n := 0
    for clave in ["ds", "cc", "ar", "hc"] {
        if (_LayoutPanelGuardado(nombre, clave, mon))
            n += 1
    }
    return n
}
_ModoSelPosGuardada(nombre) {
    ini := _PosGuiIniPath()
    sec := "Layout" nombre
    gx := IniRead(ini, sec, "gui_modox", "")
    gy := IniRead(ini, sec, "gui_modoy", "")
    if (gx = "" || gy = "")
        return 0
    mon := ObtenerMonitorCSP()
    x := mon.x + Integer(gx)
    y := mon.y + Integer(gy)
    return _PosicionValidaEnPantalla(x, y) ? {x: x, y: y} : 0
}
_ModoSelCrear() {
    global enfoque
    s := _ModoSel()
    if (IsObject(s.g) && DllCall("IsWindow", "Ptr", s.g.Hwnd))
        return
    familia := "Segoe UI"
    try familia := Trim(_Tema("type", "family", "Segoe UI"))
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000", "Selector de Modo")
    g.BackColor := _TemaHex("surface.base", "12141A")
    g.MarginX := 0
    g.MarginY := 0
    g.SetFont("s9 bold", familia)
    s.tN := g.Add("Text", "x" _E(6) " y" _E(6) " w" _E(88) " h" _E(26) " Center +0x200 +0x100", "🖥 NORMAL")
    s.tE := g.Add("Text", "x" _E(96) " y" _E(6) " w" _E(88) " h" _E(26) " Center +0x200 +0x100", "🔍 ENFOQUE")
    s.tS := g.Add("Text", "x" _E(188) " y" _E(6) " w" _E(26) " h" _E(26) " Center +0x200 +0x100", "💾")
    g.SetFont("s8 norm", familia)
    s.tI := g.Add("Text", "x" _E(6) " y" _E(37) " w" _E(208) " h" _E(16) " +0x200 +0x100", "")
    s.tI.SetFont("c" _TemaHex("text.muted", "8E97A8"))
    s.tN.OnEvent("Click", (*) => EstablecerModoTrabajo("Normal"))
    s.tE.OnEvent("Click", (*) => EstablecerModoTrabajo("Enfoque"))
    s.tS.OnEvent("Click", (*) => _ModoGuardarActivo())
    s.g := g
    w := _E(220)
    h := _E(58)
    modo := (IsSet(enfoque) && enfoque.activo) ? "Enfoque" : "Normal"
    pos := 0
    try pos := _ModoSelPosGuardada(modo)
    if (!pos) {
        mon := {x: 0, y: 0, w: A_ScreenWidth, h: A_ScreenHeight}
        try mon := ObtenerMonitorCSP()
        pos := {x: mon.x + (mon.w - w) // 2, y: mon.y + mon.h - h - _E(70)}
    }
    g.Show("Hide NoActivate x" pos.x " y" pos.y " w" w " h" h)
    WinSetTransparent(_AlphaTema("pill", 235), g)
    if IsSet(GfxMascaraRedondeada)
        GfxMascaraRedondeada(g.Hwnd, w, h, 8)
    if !s.msg {
        OnMessage(0x0201, _ModoSel_WM_LBUTTONDOWN)
        s.msg := true
    }
    SetTimer(_ModoSelVigilar, 500)
}
_ModoSelPintarSeg(c, on) {
    bg := on ? _TemaHex("accent.info", "00E5FF") : _TemaHex("surface.off", "333333")
    fg := on ? _TemaHex("knob.text", "23232B") : _TemaHex("text.idle", "8A8A8A")
    c.Opt("+Background" bg)
    c.SetFont("c" fg)
    c.Redraw()
}
_ModoSelRefrescar() {
    global enfoque
    if !IsSet(enfoque)
        return
    act := enfoque.activo ? 1 : 0
    modo := act ? "Enfoque" : "Normal"
    try _ModoTrayMarcar(act)
    s := _ModoSel()
    if !IsObject(s.g)
        return
    try {
        _ModoSelPintarSeg(s.tN, !act)
        _ModoSelPintarSeg(s.tE, act)
        n := _ModoContarGuardados(modo)
        s.tI.Text := "Activo: " StrUpper(modo) "  ·  " (n = 4 ? "✓ ubicaciones 4/4" : "⚠ " n "/4 guardadas, usa 💾")
    }
}
_ModoSelVigilar() {
    global panelBlk
    s := _ModoSel()
    if (!IsObject(s.g) || !DllCall("IsWindow", "Ptr", s.g.Hwnd)) {
        SetTimer(_ModoSelVigilar, 0)
        return
    }
    hwnd := s.g.Hwnd
    debe := s.visible && (WinActive("ahk_exe CLIPStudioPaint.exe") || (IsSet(panelBlk) && panelBlk.frente) || WinActive("ahk_id " hwnd))
    visible := DllCall("IsWindowVisible", "Ptr", hwnd)
    if (debe && !visible)
        s.g.Show("NoActivate")
    else if (!debe && visible)
        s.g.Hide()
}
ModoSel_Alternar() {
    s := _ModoSel()
    s.visible := !s.visible
    IniWrite(s.visible ? 1 : 0, _PosGuiIniPath(), "ModoSel", "visible")
    if (s.visible) {
        _ModoSelCrear()
        _ModoSelRefrescar()
        try s.g.Show("NoActivate")
    } else if IsObject(s.g) {
        try s.g.Hide()
    }
    MostrarHUD(s.visible ? "🎛 SELECTOR DE MODO: VISIBLE" : "🎛 SELECTOR DE MODO: OCULTO", "00E5FF", 800)
}
_ModoGuardarActivo() {
    global enfoque
    if !IsSet(enfoque)
        return
    _CapturarLayout(enfoque.activo ? "Enfoque" : "Normal")
    _ModoSelRefrescar()
}
_ModoTrayConstruir() {
    s := _ModoSel()
    if IsObject(s.tray)
        return s.tray
    mt := Menu()
    mt.Add("🖥 Modo 1 · Normal", (*) => EstablecerModoTrabajo("Normal"))
    mt.Add("🔍 Modo 2 · Enfoque", (*) => EstablecerModoTrabajo("Enfoque"))
    mt.Add()
    mt.Add("🎛 Selector flotante: Mostrar/Ocultar", (*) => ModoSel_Alternar())
    mt.Add("💾 Guardar ubicaciones en el modo activo", (*) => _ModoGuardarActivo())
    A_TrayMenu.Add("Modo de trabajo", mt)
    s.tray := mt
    return mt
}
_ModoTrayMarcar(act) {
    mt := _ModoTrayConstruir()
    try mt.Uncheck("🖥 Modo 1 · Normal")
    try mt.Uncheck("🔍 Modo 2 · Enfoque")
    mt.Check(act ? "🔍 Modo 2 · Enfoque" : "🖥 Modo 1 · Normal")
}
_ModoSelArranque() {
    s := _ModoSel()
    try _ModoTrayConstruir()
    v := IniRead(_PosGuiIniPath(), "ModoSel", "visible", "0")
    s.visible := (v = "1")
    if (s.visible)
        _ModoSelCrear()
    _ModoSelRefrescar()
}
_ModoSel_WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global panelBlk
    s := _ModoSel()
    if !IsObject(s.g)
        return
    if (hwnd != s.g.Hwnd && hwnd != s.tI.Hwnd)
        return
    if (IsSet(panelBlk) && panelBlk.locked)
        return
    PostMessage(0xA1, 2, 0, , "ahk_id " s.g.Hwnd)   ; arrastre por la línea de estado
}

; === NUEVA-VENTANA-RANGO-BEGIN ===
; Cadena optimizada: Nueva ventana -> desacoplar pestaña -> ubicar y verificar en 1 solo lanzamiento ágil.
_NvCfg() {
    static c := Map(
        "claseMarco", "742DEA58-ED6B-4402-BC11-20DFC6D08040",
        "claseDoc",   "742DEA58-ED6B-4402-BC11-20DFC6D08040-E583090D-0E1A-43a2-977A-5266782BDE30",
        "tabX", -2118, "tabY", -88,     ; LEGADO (ya no se usan; deteccion dinamica)
        "tabYRel", 132,                 ; Y de la franja relativa al borde superior del marco (fy=-227, Y=-95 medido con Calibrador/ShareX)
        "colorTab", 0x6A748A,           ; 0xRRGGBB del fondo de la pestana ACTIVA (azul grisáceo Qt verificado en vivo)
        "varColor", 16,                 ; tolerancia por canal (bajar si hay falsos positivos)
        "margenIzq", 110, "margenDer", 700, ; recorte del rango de busqueda (toolbox / paletas flotantes)
        "huecoMax", 40, "anchoMin", 25, ; tolera texto dentro de la pestana; ancho minimo valido
        "agarrePct", 0.30, "agarreMin", 30, "agarreMax", 60,
        "esperaManual", 8000,
        "detectarMax", 3500,            ; ms de polling hasta que aparezca la pestana NUEVA
        "caida", 280,                   ; cuanto se arrastra hacia abajo
        "espera", 150,                  ; ms entre crear la ventana y arrastrar la pestana (150 ms para atajo)
        "metodo", "atajo",              ; Shift+N nativo en CSP (Ventana > Lienzo > Nueva ventana)
        "postAtajo", 150,
        "menuDown", 1,                  ; Down antes de Enter; -1 = legado (tecla n)
        "keyDelay", 20,                 ; SetKeyDelay para el menu
        "abrirMax", 2600,               ; el submenu Lienzo tarda 1.5-2 s en Qt
        "reintentos", 3,                ; reintentos del disparo (solo antes del Enter)
        "menuMs", 300,
        "detectarIntento", 1300,
        "detectarAtajo", 3000,          ; polling único tras Shift+N (no se repite el atajo)
        "pasos", 10, "pasoMs", 18,      ; arrastre (subir si Qt deja de reconocer el drag)
        "asentarMs", 200,               ; la geometria debe mantenerse este tiempo
        "colocarMax", 2500)             ; tope total de colocacion
    return c
}

NuevaVentanaEnZona(rango := "ZonaSegura") {
    static ocupado := false
    if ocupado
        return "ocupado"
    ocupado := true
    try {
        return _NvEjecutar(rango)
    } finally {
        ocupado := false
    }
}

_NvEjecutar(rango) {
    SetWinDelay(-1)
    t0 := A_TickCount
    if !A_IsAdmin
        return _NvLog("no-admin")
    cspPid := ProcessExist("CLIPStudioPaint.exe")
    if !cspPid
        return _NvLog("no-csp")
    static CLS_MAIN := "742DEA58-ED6B-4402-BC11-20DFC6D08040"
    main := WinExist("ahk_pid " cspPid " ahk_class " CLS_MAIN)
    if !main
        return _NvLog("no-main")
    try WinActivate("ahk_id " main)
    Sleep(300)
    if !WinActive("ahk_id " main) {
        _NvLog("main-no-activo")
        return "main-no-activo"
    }
    r := _NvRangoRect(rango)
    if !IsObject(r) {
        _NvLog("no-rango:" rango)
        return "no-rango"
    }
    antes := _NvDocs(cspPid)
    _NvLog("mods-pre ctrl=" GetKeyState("Ctrl") " alt=" GetKeyState("Alt") " shift=" GetKeyState("Shift"))
    _NvSoltarMods()
    nuevo := 0
    e := NvEstado()

    ; Snapshot de TODAS las CLS_DOC existentes (registradas o no): nunca se adoptan ni se tocan.
    ; Siempre se dispara Shift+N; la ventana nueva es la que NO estaba aquí.
    previas := Map()
    for h in antes
        previas[h] := true
    _NvLog("previas=" previas.Count " registradas=" e.ventanas.Count)

    ; 1ª pulsación: creación + desacople automático de pestaña
    if !nuevo {
        c := _NvCfg()
        _NvForzarFocoMarco(main)                  ; foco al marco ANTES de medir y de disparar
        gPrev := 0
        Loop 5 {                                  ; la pestaña activa previa debe leerse bien
            gPrev := _NvTabActivaAgarre(main)
            if IsObject(gPrev)
                break
            Sleep(80)
        }
        xPrev := IsObject(gPrev) ? gPrev["px"] : ""
        _NvLog("xPrev=" xPrev)
        g := 0
        esAtajo := (c["metodo"] = "atajo")
        nIntentos := esAtajo ? 1 : c["reintentos"]            ; atajo: Shift+N JAMÁS se repite
        msDet := esAtajo ? c["detectarAtajo"] : c["detectarIntento"]
        Loop nIntentos {
            _NvDisparar(c["metodo"], cspPid, A_Index)
            Sleep(c["espera"])
            limDet := A_TickCount + msDet
            while (A_TickCount < limDet) {
                g := _NvTabActivaAgarre(main)
                if IsObject(g) && (xPrev = "" || Abs(g["px"] - xPrev) > 8)
                    break
                g := 0
                Sleep(60)
            }
            if IsObject(g)
                break
            _NvLog("disparo-sin-pestana intento=" A_Index)
            _NvLimpiarMenu(main)
        }
        if IsObject(g) {
            _NvLog("agarre x=" g["x"] " y=" g["y"] " ancho=" g["ancho"])
            Sleep(c["asentarMs"])
            _NvArrastrarPestana(g["x"], g["y"], g["x"], g["y"] + c["caida"])
            limite := A_TickCount + 1800
        } else {
            _NvLog("pestana-activa-no-detectada: fallback manual")
            ToolTip("Arrastra la pestaña hacia abajo: yo la coloco")
            SetTimer(() => ToolTip(), -3000)
            limite := A_TickCount + c["esperaManual"]
        }
        while (A_TickCount < limite) {
            for h in _NvDocs(cspPid) {
                if !_NvEnLista(h, antes) {
                    nuevo := h
                    break
                }
            }
            if nuevo
                break
            Sleep(30)
        }
        if !nuevo && IsObject(g) {
            g2 := _NvTabActivaAgarre(main)
            if IsObject(g2) {
                _NvLog("re-arrastre x=" g2["x"] " y=" g2["y"])
                _NvArrastrarPestana(g2["x"], g2["y"], g2["x"], g2["y"] + Round(c["caida"] * 1.6))
                limite := A_TickCount + 1500
                while (A_TickCount < limite && !nuevo) {
                    for h in _NvDocs(cspPid) {
                        if !_NvEnLista(h, antes) {
                            nuevo := h
                            break
                        }
                    }
                    Sleep(30)
                }
            }
        }
    }
    if !nuevo {                                  ; adopción de ventana ya desacoplada
        for h in _NvDocs(cspPid) {
            if !e.ventanas.Has(h) {
                nuevo := h
                _NvLog("adoptada-preexistente-libre hwnd=" nuevo)
                break
            }
        }
    }
    if !nuevo {
        _NvLog("desacople-o-creacion-fallida" (IsObject(g) ? " (timeout 1.8s)" : "-manual"))
        return "sin-ventana-nueva"
    }

    Sleep(900)                                   ; CSP recoloca la ventana justo tras crearla
    final := nuevo
    for h in _NvDocs(cspPid) {
        if !_NvEnLista(h, antes)
            final := h                           ; el último detectado es el definitivo
    }
    ok := false
    try {
        if (WinGetMinMax("ahk_id " final) != 0)
            WinRestore("ahk_id " final)
    }
    ; Guard anti-recaptura: una ventana previa o ya registrada jamás se arrastra ni se recoloca
    if (!final || previas.Has(final) || e.ventanas.Has(final)) {
        _NvLog("ABORTA: final=" final " es previa/registrada; no se toca")
        return
    }

    ; Colocación final:
    Loop 3 {
        try WinMove(r.x, r.y, r.w, r.h, "ahk_id " final)
        Sleep(350)
        try {
            WinGetPos(&gx, &gy, &gw, &gh, "ahk_id " final)
            if (Abs(gx - r.x) <= 16 && Abs(gy - r.y) <= 16 && Abs(gw - r.w) <= 24 && Abs(gh - r.h) <= 24) {
                ok := true
                break
            }
        }
    }
    ; Registro robusto: se registra si la ventana existe y su centro cae dentro de la zona,
    ; aunque DWM haya añadido márgenes y la tolerancia estricta no haya cuadrado.
    if !ok && WinExist("ahk_id " final) {
        try {
            WinGetPos(&gx, &gy, &gw, &gh, "ahk_id " final)
            cx := gx + gw // 2, cy := gy + gh // 2
            if (cx >= r.x && cx <= r.x + r.w && cy >= r.y && cy <= r.y + r.h)
                ok := true
        }
    }
    _NvLog("registro final=" final " ok=" ok " rango=" rango)
    if (ok || WinExist("ahk_id " final))
        NvRegistrarVentana(final, rango)
    _NvLog((ok ? "ok " : "puesto-pero-recolocado ") r.x "," r.y " " r.w "x" r.h " hwnd=" final " ms=" (A_TickCount - t0))
    return ok ? "ok" : "recolocado"
}

_NvSnapshot() {
    s := Map("ids", Map(), "titulo", "")
    for h in WinGetList("ahk_exe CLIPStudioPaint.exe")
        s["ids"][h] := true
    if WinActive("ahk_exe CLIPStudioPaint.exe")
        s["titulo"] := WinGetTitle("A")
    return s
}

_NvEsperarCambio(s, ms := 2500) {
    t0 := A_TickCount
    while (A_TickCount - t0 < ms) {
        for h in WinGetList("ahk_exe CLIPStudioPaint.exe")
            if !s["ids"].Has(h)
                return "hwnd:" h
        if (WinActive("ahk_exe CLIPStudioPaint.exe") && s["titulo"] != "" && WinGetTitle("A") != s["titulo"])
            return "titulo"
        Sleep(50)
    }
    return ""
}

NvEstado() {
    static e := {modoGlobal: _NvIniModoGlobal(), fijas: Map(), ventanas: Map()}
    return e
}

_NvIniModoGlobal() {
    m := IniRead(_PosGuiIniPath(), "NvConfig", "modoGlobal", "")
    if (m = "")   ; migración desde la clave antigua "modo"
        m := (IniRead(_PosGuiIniPath(), "NvConfig", "modo", "hover") = "total") ? "desact_25" : "h_on"
    return (m = "h_off" || m = "desact_25") ? m : "h_on"
}

; Modo efectivo: individual > global > h_on (si el global está roto y la ventana no tiene fija)
_NvModoEfectivo(e, h) {
    if e.fijas.Has(h)
        return e.fijas[h]
    return (e.modoGlobal != "") ? e.modoGlobal : "h_on"
}

; "on" = todas en Hover ON | "off" = todas en Hover OFF/Desact | "mixto"
_NvEstadoVisual(e) {
    if (e.ventanas.Count = 0)
        return (e.modoGlobal = "") ? "mixto" : (e.modoGlobal = "h_on" ? "on" : "off")
    primero := ""
    for h in e.ventanas {
        m := _NvModoEfectivo(e, h)
        if (primero = "")
            primero := m
        else if (m != primero)
            return "mixto"
    }
    return (primero = "h_on") ? "on" : "off"
}

NvSetGlobal(modo) {
    e := NvEstado()
    e.modoGlobal := modo
    e.fijas.Clear()
    try IniWrite(modo, _PosGuiIniPath(), "NvConfig", "modoGlobal")
    _NvRefrescar()
}

NvSetIndividual(h, modo) {
    e := NvEstado()
    e.fijas[h] := modo
    e.modoGlobal := ""          ; ruptura del Global
    _NvRefrescar()
}

; Clic corto: Hover ON -> Hover OFF; Hover OFF / Desact / mixto -> Hover ON (siempre global)
NvAlternarInteractivo() {
    NvSetGlobal(_NvEstadoVisual(NvEstado()) = "on" ? "h_off" : "h_on")
}

_NvRefrescar() {
    LoopNuevasVentanas()
    ActualizarNVGUI()
}

NvSetModo(m) {
    NvSetGlobal(m = "total" ? "desact_25" : "h_on")
}

NvToggleModo() {
    NvAlternarInteractivo()
    vis := _NvEstadoVisual(NvEstado())
    ToolTip("WINDOW: " (vis = "on" ? "HOVER ON (5 %)" : (vis = "off" ? "HOVER OFF / 25 %" : "MIXTO")), , , 18)
    SetTimer(() => ToolTip(, , , 18), -1200)
}

NvRegistrarVentana(hwnd, zona := "") {
    NvEstado().ventanas[hwnd] := zona                 ; hwnd -> nombre de zona
    SetTimer(LoopNuevasVentanas, 80)
}

NvSiguienteZona() {
    e := NvEstado()
    hay := 0
    Loop 8 {
        z := "NvZona" A_Index
        r := 0
        try r := _NvRangoRect(z)
        if (!IsObject(r) || r.w < 1)
            continue
        hay++
        ocupada := false
        for h, zz in e.ventanas
            if (zz = z && WinExist("ahk_id " h))
                ocupada := true
        if !ocupada
            return z
    }
    return hay ? "" : "ZonaSegura"                    ; "" = todas ocupadas; sin zonas Nv: comportamiento anterior
}

LoopNuevasVentanas() {
    e := NvEstado()
    if (e.ventanas.Count = 0) {
        SetTimer(LoopNuevasVentanas, 0)
        return
    }
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    muertos := []
    for h in e.ventanas {
        if !WinExist("ahk_id " h) {
            muertos.Push(h)
            continue
        }
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " h)
        dentro := (mx >= wx && mx <= wx + ww && my >= wy && my <= wy + wh)
        _NvAplicarModo(h, _NvModoEfectivo(e, h), dentro)
    }
    for h in muertos                                  ; no se borra durante el for
        e.ventanas.Delete(h)
}

_NvAplicarModo(hwnd, modo, dentro := false) {
    static ultimo := Map()
    switch modo {
        case "h_off":     fis := "v"                  ; 100% fija
        case "desact_25": fis := "t"                  ; 25% bloqueada
        default:          fis := dentro ? "o" : "r"   ; h_on: hover / reposo
    }
    if (ultimo.Has(hwnd) && ultimo[hwnd] = fis)
        return
    ultimo[hwnd] := fis
    switch fis {
        case "t":                                     ; 25% (64) + click-through
            try WinSetTransparent(64, "ahk_id " hwnd)
            try WinSetExStyle("+0x20", "ahk_id " hwnd)
        case "v", "o":                                ; 100% + interactiva
            try WinSetTransparent(255, "ahk_id " hwnd)
            try WinSetExStyle("-0x20", "ahk_id " hwnd)
        default:                                      ; h_on en reposo: 5% (13) + click-through
            try WinSetTransparent(13, "ahk_id " hwnd)
            try WinSetExStyle("+0x20", "ahk_id " hwnd)
    }
}

; Espera a que aparezca un CLS_DOC que no estaba en "antes"
_NvEsperarNueva(cspPid, antes, timeoutMs := 4000) {
    t0 := A_TickCount
    while (A_TickCount - t0 < timeoutMs) {
        Sleep(100)
        for h in _NvDocs(cspPid) {
            if !_NvEnLista(h, antes)
                return h
        }
    }
    return 0
}

; Menú Ventana(W) > Lienzo(V) > "Nueva ventana" (1ª opción, sin acelerador)
; Tiempos Qt tomados del backup 02:04:30 (ABRIR = 400 ms)
_NvDispararMenu(mainHwnd) {
    static ABRIR := 400
    if !WinActive("ahk_id " mainHwnd) {
        try WinActivate("ahk_id " mainHwnd)
        if !WinWaitActive("ahk_id " mainHwnd, , 1)
            return false
    }
    _NvSoltarMods()
    OutputDebug("[Nv] menu: Alt+W -> v -> Enter")
    SendEvent("{Alt down}w{Alt up}")    ; abre Ventana
    Sleep(ABRIR)
    SendEvent("v")                      ; abre Lienzo
    Sleep(ABRIR)
    SendEvent("{Enter}")                ; Nueva ventana = opción 1
    return true
}

_NvDocs(pid) {
    static CLS_DOC := "742DEA58-ED6B-4402-BC11-20DFC6D08040-E583090D-0E1A-43a2-977A-5266782BDE30"
    out := []
    for h in WinGetList("ahk_pid " pid) {
        try {
            if (WinGetClass("ahk_id " h) = CLS_DOC)
                out.Push(h)
        }
    }
    return out
}

_NvTodas(pid) {
    out := []
    for h in WinGetList("ahk_pid " pid) {
        try {
            if DllCall("IsWindowVisible", "Ptr", h)
                out.Push(h)
        }
    }
    return out
}

_NvEnLista(h, lista) {
    for x in lista
        if (x = h)
            return true
    return false
}

_NvLog(s) {
    try FileAppend(A_Now " " s "`n", EnvGet("TEMP") "\_nv_ultimo.txt")
    return s
}

_NvSoltarMods() {
    static mods := ["LCtrl", "RCtrl", "LAlt", "RAlt", "LShift", "RShift", "LWin", "RWin"]
    t0 := A_TickCount
    while (A_TickCount - t0 < 600) {                   ; un solo plazo; sin espera si nada esta pulsado
        fisico := false
        for k in mods {
            if GetKeyState(k, "P") {
                fisico := true
                break
            }
        }
        if !fisico
            break
        Sleep(10)
    }
    for k in mods
        if GetKeyState(k)                              ; estado logico pegado
            SendEvent("{Blind}{" k " up}")
}

_NvDispararAtajo(mainHwnd) {
    c := _NvCfg()
    if !WinActive("ahk_id " mainHwnd) {
        try WinActivate("ahk_id " mainHwnd)
        if !WinWaitActive("ahk_id " mainHwnd, , 1) {
            _NvLog("atajo-sin-foco")
            return false
        }
    }
    _NvSoltarMods()
    SetKeyDelay(c["keyDelay"], c["keyDelay"])
    SendEvent("{Shift down}n{Shift up}")
    Sleep(c["postAtajo"])
    _NvLog("atajo-enviado")
    return true
}

; Devuelve el foco al marco principal de CSP (puede haber quedado en una ventana desacoplada)
_NvForzarFocoMarco(main) {
    try WinActivate("ahk_id " main)
    if !WinWaitActive("ahk_id " main, , 1) {
        try DllCall("AllowSetForegroundWindow", "UInt", -1)
        try WinActivate("ahk_id " main)
        WinWaitActive("ahk_id " main, , 1)
    }
    Sleep(60)
    ok := WinActive("ahk_id " main) ? true : false
    _NvLog("foco-marco ok=" ok)
    return ok
}

_NvDisparar(modo, pid := 0, intento := 1) {
    c := _NvCfg()
    SetKeyDelay(c["keyDelay"], c["keyDelay"])
    if (modo = "atajo") {
        _NvEsperarSoltarFisico()
        _NvSoltarMods()
        SendEvent("{Shift down}n{Shift up}")
        return
    }
    _NvEsperarSoltarFisico()
    _NvSoltarMods()
    ; Rotación por intento: configurado -> mnemónico "n" -> solo Enter
    variantes := [c["menuDown"], -1, 0]
    vd := variantes[Min(intento, 3)]
    SendEvent("{Alt down}")
    Sleep(40)
    SendEvent("w")                                     ; menu Ventana
    Sleep(40)
    SendEvent("{Alt up}")
    Sleep(c["menuMs"])
    try _NvLog("menu-W cls=" WinGetClass("A") " intento=" intento)
    SendEvent("v")                                     ; submenu Lienzo
    Sleep(c["menuMs"])
    try _NvLog("menu-V cls=" WinGetClass("A") " vd=" vd)
    if (vd >= 0)
        SendEvent((vd > 0 ? "{Down " vd "}" : "") "{Enter}")
    else
        SendEvent("n")
}

_NvEsperarSoltarFisico() {
    for k in ["Ctrl", "Shift", "Alt", "LWin", "RWin"]
        try KeyWait(k, "T1.5")
    k := RegExReplace(A_ThisHotkey, "^[~*$<>^+!#]+")
    if (k != "" && !InStr(k, " & "))
        try KeyWait(k, "T1.5")
}

_NvLimpiarMenu(main) {
    SendEvent("{Escape 3}")
    Sleep(120)
    try WinActivate("ahk_id " main)
    Sleep(150)
}

_NvEsperarPopup(pid, antes, ms) {
    t0 := A_TickCount
    if !pid {
        Sleep(ms)
        return false
    }
    while (A_TickCount - t0 < ms) {
        if (WinGetList("ahk_pid " pid).Length > antes) {
            Sleep(40)                                  ; deja que el menu pinte y seleccione
            return true
        }
        Sleep(15)
    }
    return false
}

_NvEsperarMas(pid, n, ms) {
    t := A_TickCount
    while (A_TickCount - t < ms) {
        if (WinGetList("ahk_pid " pid).Length > n)
            return true
        Sleep(30)
    }
    return false
}

_NvEsperarHasta(pid, n, ms) {
    t := A_TickCount
    while (A_TickCount - t < ms) {
        if (WinGetList("ahk_pid " pid).Length <= n)
            return true
        Sleep(30)
    }
    return false
}

_NvDispararVerificado(pid) {
    c := _NvCfg()
    if (c["metodo"] = "atajo" || !pid) {
        _NvDisparar(c["metodo"], pid)
        return true
    }
    SetKeyDelay(c["keyDelay"], c["keyDelay"])
    Loop c["reintentos"] {
        base := WinGetList("ahk_pid " pid).Length
        SendEvent("{Alt down}w{Alt up}")                  ; menu Ventana
        ok := _NvEsperarMas(pid, base, c["abrirMax"])
        if ok {
            n1 := WinGetList("ahk_pid " pid).Length
            SendEvent("v")                                ; submenu Lienzo
            ok := _NvEsperarMas(pid, n1, c["abrirMax"])
        }
        if ok {
            if (c["menuDown"] >= 0)
                SendEvent((c["menuDown"] > 0 ? "{Down " c["menuDown"] "}" : "") "{Enter}")
            else
                SendEvent("n")
            ; Enter enviado: no se reintenta (evita documentos duplicados)
            ok2 := _NvEsperarHasta(pid, base, c["abrirMax"])
            OutputDebug("[Nv] disparo " A_Index ": enter enviado, menus cerrados=" ok2)
            if !ok2
                Loop 3
                    SendEvent("{Esc}")
            return true
        }
        OutputDebug("[Nv] disparo " A_Index ": el menu no abrio, reintento")
        Loop 3
            SendEvent("{Esc}")
        Sleep(250)
    }
    return false
}

_NvRangoRect(nombre := "zonasegura", usarDefault := true) {
    global PERFIL
    static DEF := [-2437, 819, 315, 535]
    ini := _PosGuiIniPath()                           ; usa la ruta oficial del proyecto
    orden := [IsSet(PERFIL) ? PERFIL : 2, 2, 1]
    for p in orden {
        try
            v := IniRead(ini, "Rangos" p, nombre, "")
        catch
            continue
        n := StrSplit(Trim(v), ",")
        if (n.Length != 4)
            continue                                  ; un punto (2 coords) no es un rect
        ok := true
        for i, t in n {
            n[i] := Trim(t)
            if !IsInteger(n[i])
                ok := false
        }
        if (ok && Integer(n[3]) > 0 && Integer(n[4]) > 0
            && _NvRectVisible(Integer(n[1]), Integer(n[2]), Integer(n[3]), Integer(n[4])))
            return {x: Integer(n[1]), y: Integer(n[2]), w: Integer(n[3]), h: Integer(n[4])}
    }
    if !usarDefault
        return 0
    if _NvRectVisible(DEF[1], DEF[2], DEF[3], DEF[4])
        return {x: DEF[1], y: DEF[2], w: DEF[3], h: DEF[4]}
    MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b)
    return {x: l + (r - l - DEF[3]) // 2, y: t + (b - t - DEF[4]) // 2, w: DEF[3], h: DEF[4]}
}

_NvArrastrarPestana(x1, y1, x2, y2) {
    c := _NvCfg()
    pasos := c["pasos"]
    bloqueado := false
    CoordMode("Mouse", "Screen")
    try {
        BlockInput("MouseMove")
        bloqueado := true
    }
    try {
        MouseMove(x1, y1, 0)
        Sleep(40)
        Click("Down")
        Sleep(40)
        Loop pasos {
            MouseMove(x1 + (x2 - x1) * A_Index // pasos, y1 + (y2 - y1) * A_Index // pasos, 0)
            Sleep(c["pasoMs"])
        }
        MouseMove(x2, y2, 0)
        Sleep(40)
        Click("Up")
    } catch {
        try Click("Up")
    }
    if (bloqueado)
        try BlockInput("MouseMoveOff")
}

; Compara dos colores 0xRRGGBB con tolerancia por canal.
_NvColorCerca(a, b, tol) {
    a := Integer(a), b := Integer(b)
    return Abs(((a >> 16) & 255) - ((b >> 16) & 255)) <= tol
        && Abs(((a >> 8) & 255) - ((b >> 8) & 255)) <= tol
        && Abs((a & 255) - (b & 255)) <= tol
}

; Prueba la fila medida y filas cercanas (tolera borde/gradiente de Qt). Map(x, y, ancho) o 0.
_NvTabActivaAgarre(main) {
    ; Si el usuario calibró NvPestana en el Calibrador visual, usamos ese rectángulo exacto
    rg := 0
    try rg := ObtenerRango("NvPestana")
    fx := fy := fw := fh := 0
    try WinGetPos(&fx, &fy, &fw, &fh, "ahk_id " main)
    ; NvPestana solo vale si se solapa con el marco actual; si no, se usa el respaldo
    if (IsObject(rg) && IsInteger(rg.w) && rg.w > 40 && IsInteger(rg.h) && rg.h > 10
        && rg.x < fx + fw && rg.x + rg.w > fx && rg.y < fy + fh && rg.y + rg.h > fy) {
        yCentro := rg.y + (rg.h // 2)
        xFinR := Min(rg.x + rg.w, fx + fw)      ; no barrer fuera del marco
        for dy in [0, 3, -3, 6, -6] {
            g := _NvTabActivaEnRango(Max(rg.x, fx), yCentro + dy, xFinR)
            if IsObject(g) {
                _NvLog("detectada-en-NvPestana dy=" dy)
                return g
            }
        }
        _NvLog("no-detectada-en-NvPestana")
        return 0
    }

    ; Fallback: cálculo relativo al marco si no estuviera calibrada NvPestana
    for dy in [0, 4, -4, 8, -8] {
        g := _NvTabActivaEnFila(main, dy)
        if IsObject(g) {
            _NvLog("detectada dy=" dy)
            return g
        }
    }
    _NvLog("no-detectada: revisar colorTab/tabYRel/margenes (usar NvDiagBarra)")
    return 0
}

_NvTabActivaEnRango(xIni, y, xFin) {
    c := _NvCfg()
    col := c["colorTab"]
    if (col = "")
        return 0
    CoordMode("Pixel", "Screen")
    tol := c["varColor"]
    paso := 3
    intentos := 0
    while (intentos++ < 8 && xIni < xFin) {
        px := py := 0
        hallado := false
        try hallado := PixelSearch(&px, &py, xIni, y, xFin, y, col, tol)
        if !hallado
            return 0
        xr := px, huecos := 0, x := px + paso
        while (x < xFin && huecos < c["huecoMax"]) {
            if _NvColorCerca(PixelGetColor(x, y), col, tol) {
                xr := x, huecos := 0
            } else
                huecos += paso
            x += paso
        }
        ancho := xr - px
        if (ancho >= c["anchoMin"]) {
            off := Min(c["agarreMax"], Max(c["agarreMin"], Round(ancho * c["agarrePct"])))
            off := Max(12, Min(off, ancho - 40))
            return Map("x", px + off, "y", y, "ancho", ancho, "px", px)
        }
        xIni := xr + paso + 1
    }
    return 0
}

_NvTabActivaEnFila(main, dy) {
    c := _NvCfg()
    fx := fy := fw := fh := 0
    try {
        WinGetPos(&fx, &fy, &fw, &fh, "ahk_id " main)
    } catch
        return 0
    return _NvTabActivaEnRango(fx + c["margenIzq"], fy + c["tabYRel"] + dy, fx + fw - c["margenDer"])
}

; Calibracion: poner el cursor sobre el FONDO de la pestana activa (sin texto) y lanzar.
; Copia el color al portapapeles y muestra tabYRel.
NvMedirColorTab() {
    CoordMode("Mouse", "Screen")
    CoordMode("Pixel", "Screen")
    MouseGetPos(&mx, &my)
    col := PixelGetColor(mx, my)
    fy := 0
    try WinGetPos(, &fy, , , "ahk_class " _NvCfg()["claseMarco"])
    A_Clipboard := col
    ToolTip("colorTab=" col "  tabYRel=" (my - fy) "  (color copiado)")
    SetTimer(() => ToolTip(), -4000)
}

; Copia al portapapeles el color cada 40 px a lo largo de la franja de pestanas.
NvDiagBarra() {
    c := _NvCfg()
    CoordMode("Pixel", "Screen")
    main := WinExist("ahk_class " c["claseMarco"])
    if !main
        return
    fx := fy := fw := 0
    WinGetPos(&fx, &fy, &fw, , "ahk_id " main)
    y := fy + c["tabYRel"]
    s := "y=" y "  fx=" fx "  fw=" fw "`n"
    x := fx + c["margenIzq"]
    while (x < fx + fw - c["margenDer"]) {
        s .= x ": " PixelGetColor(x, y) "`n"
        x += 40
    }
    A_Clipboard := s
    ToolTip("diagnostico copiado al portapapeles")
    SetTimer(() => ToolTip(), -3000)
}

_NvRectVisible(x, y, w, h) {
    cx := x + w // 2, cy := y + h // 2
    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
        if (cx >= l && cx < r && cy >= t && cy < b)
            return true
    }
    return false
}
; === NUEVA-VENTANA-RANGO-END ===
