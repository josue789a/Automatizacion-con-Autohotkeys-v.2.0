#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; SONDA EXPERIMENTAL DE RAW INPUT - DIGITIZADOR / LÁPIZ XP-PEN (Página 0x0D, Uso 0x02)
; ==============================================================================
; Objetivo: Verificar si el hardware/driver de XP-Pen expone eventos de Raw Input HID
; para detectar el contacto de la punta (Tip Switch), presión o botones en background.
; ==============================================================================

g := Gui("+AlwaysOnTop +ToolWindow", "Sonda HID Pen XP-Pen (0x0D / 0x02)")
g.SetFont("s10", "Consolas")
txtInfo := g.Add("Text", "w650 h40", "Estado: Inicializando Raw Input...")
txtLog := g.Add("Edit", "w650 h400 ReadOnly", "")
btnLimpiar := g.Add("Button", "w100 h30", "Limpiar Log")
btnLimpiar.OnEvent("Click", (*) => (txtLog.Value := "", ultHex := ""))
g.OnEvent("Close", (*) => ExitApp())
g.Show("NA")

global ultHex := ""
global totalEventos := 0

; 1. Estructura RAWINPUTDEVICE (x64: 16 bytes)
; usUsagePage (UInt16, 2) | usUsage (UInt16, 2) | dwFlags (UInt32, 4) | hwndTarget (Ptr, 8)
rid := Buffer(16, 0)
NumPut("UShort", 0x000D, rid, 0)       ; Página HID: Digitizers (0x0D)
NumPut("UShort", 0x0002, rid, 2)       ; Uso HID: Pen / Stylus (0x02)
NumPut("UInt", 0x00000100, rid, 4)     ; RIDEV_INPUTSINK (recibe mensajes fuera de foco)
NumPut("Ptr", g.Hwnd, rid, 8)          ; Ventana receptora

if !DllCall("RegisterRawInputDevices", "Ptr", rid, "UInt", 1, "UInt", 16) {
    err := A_LastError
    txtInfo.Text := "❌ Error al registrar RawInput: " err
} else {
    txtInfo.Text := "✅ Registrado (Página 0x0D, Uso 0x02). Mueve el lápiz, toca y pulsa botones."
    OnMessage(0x00FF, OnWM_INPUT)
}

OnWM_INPUT(wParam, lParam, msg, hwnd) {
    global ultHex, totalEventos
    hRaw := lParam
    
    ; Obtener tamaño del búfer
    cbSize := 0
    DllCall("GetRawInputData", "Ptr", hRaw, "UInt", 0x10000003, "Ptr", 0, "UInt*", &cbSize, "UInt", 24)
    if (cbSize <= 0)
        return 0
        
    buf := Buffer(cbSize, 0)
    if (DllCall("GetRawInputData", "Ptr", hRaw, "UInt", 0x10000003, "Ptr", buf, "UInt*", &cbSize, "UInt", 24) <= 0)
        return 0
        
    dwType := NumGet(buf, 0, "UInt")
    if (dwType != 2) ; RIM_TYPEHID = 2
        return 0
        
    dwSizeHid := NumGet(buf, 24, "UInt")
    dwCount := NumGet(buf, 28, "UInt")
    totalBytes := dwSizeHid * dwCount
    
    if (totalBytes <= 0 || totalBytes > 256)
        return 0
        
    ; Extraer bytes brutos en hex
    ptrDatos := buf.Ptr + 32
    hex := ""
    loop totalBytes {
        b := NumGet(ptrDatos, A_Index - 1, "UChar")
        hex .= Format("{:02X} ", b)
    }
    hex := Trim(hex)
    
    ; Solo loguear si cambió el reporte (evitar inundación por hover)
    if (hex != ultHex) {
        ultHex := hex
        totalEventos++
        linea := Format("[{:04d}] Bytes ({:2d}): {}`r`n", totalEventos, totalBytes, hex)
        txtLog.Value := SubStr(linea . txtLog.Value, 1, 4000)
    }
    return 0
}
