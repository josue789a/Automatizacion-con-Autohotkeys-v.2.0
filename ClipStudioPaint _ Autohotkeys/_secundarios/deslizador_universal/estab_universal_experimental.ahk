; ═══════════════════════════════════════════════════════════════════════════════
; [RESPALDO SECUNDARIO / TERCIARIO] estab_universal_experimental.ahk
; Fecha: 2026-11-18
; Estado: Guardado para desarrollo futuro como idea secundaria/terciaria.
; Propósito: Intento de Estabilizador Universal con Auto-Transfer de valores
;            entre herramientas (Q, W, E, S, R...) y batching rápido.
; ═══════════════════════════════════════════════════════════════════════════════

/*
DIAGNÓSTICO TÉCNICO DE LA DIFICULTAD:
1. Clip Studio Paint no dispone de una API de lectura para consultar en qué valor
   numérico se encuentra la estabilización de cada herramienta al activarla.
2. Cada sub-herramienta en CSP (Pluma G, Maru, Aerógrafo suave, etc.) tiene un
   estado interno propio e independiente.
3. Al forzar la alineación inmediata sin conocer la posición real en CSP, se requiere
   bien un reseteo absoluto (j*100 + -*target) o rastreo predictivo de deltas.
   Cualquier desfase previo en CSP produce lecturas erráticas.
*/

; ── 1. Lógica de Despacho en Cambio de Herramienta ──
Stab_ResetUniversal_Experimental(herramienta := "", forzar := false) {
    global stabU, Q, estabGui, STAB_RESET_FISICO, STAB_RESET_DELAY_MS, ESTAB_MAX, ESTAB_MIN, g_ModoUniversal
    if (!forzar && herramienta != "" && herramienta = stabU.tool && !g_ModoUniversal)
        return
    
    stabU.abortar := true
    stabU.tool := herramienta
    clave := _Stab_Clave(herramienta)
    
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
        SetTimer(_Stab_ResetFisico_Experimental, 0)
        return
    }
    if _Stab_NecesitaEmitir(herramienta)
        SetTimer(_Stab_ResetFisico_Experimental, -1)
    else
        SetTimer(_Stab_ResetFisico_Experimental, 0)
}

; ── 2. Reseteo Físico por Lote Instantáneo (Batching Raw) ──
_Stab_ResetFisico_Experimental() {
    global stabU, estabGui, stylus, STAB_RESET_DELAY_MS, g_ModoUniversal
    if stabU.ocupado {
        stabU.rearmar := true
        return
    }
    if !WinActive("ahk_exe CLIPStudioPaint.exe")
        return
    if (estabGui.arrastrando)
        return
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
    tb := _EstabTeclaBajar(), ts := _EstabTeclaSubir()
    try {
        if alt
            SendEvent("{Alt up}")
        BlockInput(true)
        if !stabU.known.Has(clave) {
            ; Salto batch absoluto rápido (0.1 ms)
            if (target > 50)
                envio := "{" ts " 100}" (target < 100 ? "{" tb " " (100 - target) "}" : "")
            else
                envio := "{" tb " 100}" (target > 0 ? "{" ts " " target "}" : "")
            ok := _EstabEnviarRaw(envio)
        } else {
            ; Salto delta instantáneo
            d := target - stabU.known[clave]
            if (d != 0) {
                envio := (d > 0) ? "{" ts " " d "}" : "{" tb " " Abs(d) "}"
                ok := _EstabEnviarRaw(envio)
            } else {
                ok := true
            }
        }
    } finally {
        BlockInput(false)
        _AltRestaurar(alt)
        stabU.ocupado := false
    }
    if ok {
        stabU.known[clave] := target
        estabGui.valor := target
        estabGui.previsto := target
        estabGui.sincronizado := true
        stabU.syncTick := A_TickCount
        _Stab_PostReset()
        OutputDebug("[StabUniv] " tool " -> " target " (" modo ") ms=" (A_TickCount - t0))
    } else if (!stabU.abortar && stabU.tool = tool) {
        SetTimer(_Stab_ResetFisico_Experimental, -60)
    }
    if stabU.rearmar {
        stabU.rearmar := false
        SetTimer(_Stab_ResetFisico_Experimental, -1)
    }
}
