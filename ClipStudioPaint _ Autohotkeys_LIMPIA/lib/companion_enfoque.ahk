#Requires AutoHotkey v2.0
; [LIB] companion_enfoque — Modo Enfoque core (extraído de companion.ahk L476-L609)
; Solo funciones. Lee super-globals: enfoque, PUNTOS. No declara estado propio fuera de static.

_EnfDiferirAvisos(act) {
    SetTimer(_EnfAvisos.Bind(act ? 1 : 0), -1)
}

_EnfAvisos(act) {
    if ((enfoque.activo ? 1 : 0) != act)
        return
    if (act) {
        MostrarHUD("🎯 MODO ENFOQUE","00E5FF",900)
        _SonarUI("enfoque_on")
    } else {
        MostrarHUD("🖥 MODO NORMAL","44DD88",900)
        _SonarUI("enfoque_off")
    }
}
; Doble clic de colapso de UI (flechas PUNTOS[1] y PUNTOS[2]) lo más rápido posible.
; modo: 1 = lote SendInput atomico (maximo) | 2 = secuencial sin delays | 3 = legado (Click + SetCursorPos)
_EnfClickDoble(origX, origY) {
    static modo := 1
    x1 := PUNTOS[1][1], y1 := PUNTOS[1][2]
    x2 := PUNTOS[2][1], y2 := PUNTOS[2][2]
    CoordMode("Mouse", "Screen")
    if (modo = 1) {
        SendInput("{Click " x1 " " y1 "}{Click " x2 " " y2 "}{Click " origX " " origY " 0}")
        return
    }
    if (modo = 2) {
        SetMouseDelay(-1)
        MouseClick("Left", x1, y1, 1, 0)
        MouseClick("Left", x2, y2, 1, 0)
        DllCall("SetCursorPos", "int", origX, "int", origY)
        return
    }
    Click(x1 " " y1)
    Click(x2 " " y2)
    DllCall("SetCursorPos", "int", origX, "int", origY)
}
_EnfEstado() {
    static e := {gen: 0, t0: 0, pintado: -1, tp: [], hkMs: 0, hkNom: "", deb: 35, tope: 80}
    return e
}
AccionEnfoque() {
    Critical("On")                                    ; fase A completa sin cola de pulsaciones perdidas
    st := _EnfEstado()
    st.hkMs := A_TimeSinceThisHotkey
    st.hkNom := A_ThisHotkey
    tp := [_EnfMs()]                                  ; t0
    enfoque.activo := !enfoque.activo
    st.gen += 1
    MouseGetPos(&origX,&origY)
    _EnfClickDoble(origX, origY)
    tp.Push(_EnfMs())                                 ; click1 (lote completo)
    tp.Push(tp[-1])                                   ; click2 (compat. _EnfLog)
    tp.Push(tp[-1])                                   ; cursor (compat. _EnfLog)
    PtsModo_SincronizarCSP()                          ; con caché: carga el PUNTOS del modo nuevo para el siguiente click
    SetTimer(NvReposicionarVentanas, -1)
    tp.Push(_EnfMs())                                 ; sync_csp
    st.tp := tp
    Critical("On")                                    ; PtsModo_SincronizarCSP hizo Critical("Off")
    ahora := A_TickCount
    if (st.t0 = 0)
        st.t0 := ahora
    espera := Max(1, Min(st.deb, st.tope - (ahora - st.t0)))
    SetTimer(_EnfReconciliar, -espera)                ; re-armar reinicia el debounce
}
_EnfReconciliar() {
    st := _EnfEstado()
    st.t0 := 0
    gen := st.gen
    act := enfoque.activo ? 1 : 0
    if (st.pintado = act)                             ; ráfaga par: el estado final ya está pintado
        return
    st.pintado := -1                                  ; sucio hasta terminar completo
    tp := st.tp
    off := _EnfMs() - tp[-1]                          ; excluye la espera del debounce de las marcas

    _AplicarLayoutPaneles(act ? "Enfoque" : "Normal")
    tp.Push(_EnfMs() - off)                           ; layout
    if (st.gen != gen)
        return
    _NotificarPureRef(act)
    tp.Push(_EnfMs() - off)                           ; pureref
    if (st.gen != gen)
        return
    if (act) {
        _EstabFocoOcultar()
        _AplicarEstabVisibilidadBase()
        MostrarGUIEnfoque()
        _EnfDiferirAvisos(true)
    } else {
        OcultarGUIEnfoque()
        _EstabFocoOcultar()
        _AplicarEstabVisibilidadBase()
        _EnfDiferirAvisos(false)
    }
    tp.Push(_EnfMs() - off)                           ; visual
    if (st.gen != gen)
        return
    _ModoSelRefrescar()
    tp.Push(_EnfMs() - off)                           ; refresco
    if (st.gen != gen)
        return
    st.pintado := act
    _EnfLog(tp, act ? true : false, st.hkMs, st.hkNom)
}
; ---- MEDICION F1 (Paquete 1): sin efecto funcional; se revierte quitando estas lineas ----
_EnfMs() {
    return IsSet(_DiagMs) ? _DiagMs() : 0
}

_EnfLog(tp, activo, hkMs, hkNom) {
    try {
        if (tp.Length < 9 || !IsSet(DiagLog))   ; ESTABLE no incluye diag.ahk: no-op sin modal
            return
        linea := FormatTime(, "yyyy-MM-dd HH:mm:ss") ";" (activo ? "ON" : "OFF") ";" hkNom ";" hkMs
        Loop 8
            linea .= ";" Round(tp[A_Index + 1] - tp[A_Index], 2)
        linea .= ";" Round(tp[9] - tp[1], 2)
        cab := "ts;modo;hotkey;ms_desde_hotkey;click1;click2;cursor;sync_csp;layout;pureref;visual;refresco;total"
        SetTimer(DiagLog.Bind("enfoque_tiempos.log", linea, cab), -1)
    }
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
    static SWP_ASYNC := true       ; F2: layout p50 174 ms era SetWindowPos bloqueando al hilo de CSP; async postea sin esperar
    static VERIFICAR := true       ; true = log de verificación; poner false tras las pruebas
    mon := ObtenerMonitorCSP()
    def := (nombre = "Enfoque") ? LAYOUT_ENFOQUE : LAYOUT_NORMAL
    ; NOZORDER(0x4) | NOACTIVATE(0x10) [| ASYNCWINDOWPOS(0x4000): no esperar al hilo de CSP por panel]
    SWP_FLAGS := 0x0014 | (SWP_ASYNC ? 0x4000 : 0)
    objetivo := []
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
            objetivo.Push([clave,id,x,y,r.w,r.h])
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
    if (VERIFICAR && objetivo.Length)
        SetTimer(_LayoutVerificar.Bind(objetivo, nombre), -350)

}
_LayoutVerificar(obj, nombre) {
    linea := FormatTime(, "HH:mm:ss") " layout_check " nombre
    for o in obj {
        try {
            WinGetPos(&px, &py, &pw, &ph, "ahk_id " o[2])
            ok := (px = o[3] && py = o[4] && pw = o[5] && ph = o[6])
            linea .= " | " o[1] (ok ? " OK" : " DIF(" px "," py "," pw "," ph " vs " o[3] "," o[4] "," o[5] "," o[6] ")")
        } catch {
            linea .= " | " o[1] " NOEXISTE"
        }
    }
    try {
        FileAppend(linea "`n", A_ScriptDir "\logs\enfoque_layout_check.log", "UTF-8")
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
    _EnfEstado().pintado := -1
    if (enfoque.activo) {
        enfoque.activo := false
        OcultarGUIEnfoque()
        _EstabFocoOcultar()
        _AplicarEstabVisibilidadBase()
        try _ModoSelRefrescar()
    }
}
