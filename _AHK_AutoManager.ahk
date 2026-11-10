; ==============================================================================
;  AUTOHOTKEY WATCHER & AUTO-RELOADER / LAUNCHER (v2)
;  Supervisa la carpeta y subcarpetas para ejecutar y autorecargar scripts .ahk
;  y accesos directos (.lnk).
; ==============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon

; Intentar elevar a Administrador pero continuar si no se acepta o no se puede
if !A_IsAdmin {
    try Run('*RunAs "' A_ScriptFullPath '"')
    catch {
        ; Continúa como usuario normal si no se eleva
    }
    if A_IsAdmin
        ExitApp()
}

SetWorkingDir(A_ScriptDir)

; Configuración
INTERVALO_MS := 1200          ; Frecuencia de escaneo en milisegundos
CARPETAS_IGNORADAS := ["ahk antiguos", "backup", "backups", "old", ".git", "_historico", "spike", "lib", "artifacts", "docs"]

; Mapa en memoria: ruta_archivo => ultima_fecha_modificacion
trackedFiles := Map()
isFirstScan := true

; Iniciar escaneo periódico
SetTimer(EscanearCarpeta, INTERVALO_MS)
EscanearCarpeta() ; Primer escaneo inmediato
MostrarNotificacion("🚀 AHK Watcher Activo", "Vigilando carpeta y subcarpetas...")

EscanearCarpeta() {
    global trackedFiles, isFirstScan, CARPETAS_IGNORADAS

    archivosActuales := Map()

    ; Escanear todos los .ahk recursivamente
    Loop Files, A_ScriptDir "\*.ahk", "R" {
        ruta := A_LoopFilePath

        ; Evitar vigilarse a sí mismo
        if (ruta = A_ScriptFullPath)
            continue

        ; Ignorar carpetas no deseadas
        ignorar := false
        for carpeta in CARPETAS_IGNORADAS {
            if InStr(ruta, "\" carpeta "\") || InStr(ruta, "/" carpeta "/") {
                ignorar := true
                break
            }
        }
        if ignorar
            continue

        archivosActuales[ruta] := A_LoopFileTimeModified
    }

    ; Escanear todos los accesos directos (.lnk) que apunten a .ahk
    Loop Files, A_ScriptDir "\*.lnk", "R" {
        rutaLnk := A_LoopFilePath

        ignorar := false
        for carpeta in CARPETAS_IGNORADAS {
            if InStr(rutaLnk, "\" carpeta "\") || InStr(rutaLnk, "/" carpeta "/") {
                ignorar := true
                break
            }
        }
        if ignorar
            continue

        ; Verificar si el .lnk apunta a un .ahk
        try {
            FileGetShortcut(rutaLnk, &targetPath)
            if (targetPath != "" && RegExMatch(targetPath, "i)\.ahk$")) {
                archivosActuales[rutaLnk] := A_LoopFileTimeModified
            }
        }
    }

    ; 1. Detectar archivos nuevos o modificados
    for ruta, modTime in archivosActuales {
        ; Resolver ruta real si es un acceso directo
        rutaDestino := ruta
        if RegExMatch(ruta, "i)\.lnk$") {
            try {
                FileGetShortcut(ruta, &target)
                if (target != "")
                    rutaDestino := target
            }
        }

        ; Si tanto el script original como su acceso directo están en la lista, no duplicar ejecuciones
        if (ruta != rutaDestino && archivosActuales.Has(rutaDestino))
            continue

        if !trackedFiles.Has(ruta) {
            trackedFiles[ruta] := modTime
            if (isFirstScan) {
                EjecutarSiNoCorre(rutaDestino)
            } else {
                SplitPath(rutaDestino, &nombre)
                MostrarNotificacion("✨ Detectado", nombre)
                SonidoNuevo()
                EjecutarScript(rutaDestino)
            }
        } else if (trackedFiles[ruta] != modTime) {
            trackedFiles[ruta] := modTime
            SplitPath(rutaDestino, &nombre)
            MostrarNotificacion("🔄 Recargando script", nombre)
            SonidoReload()
            EjecutarScript(rutaDestino)
        }
    }

    ; 2. Limpiar del registro archivos que fueron eliminados o movidos
    for ruta in trackedFiles {
        if !archivosActuales.Has(ruta) {
            trackedFiles.Delete(ruta)
        }
    }

    isFirstScan := false
}

EjecutarScript(ruta) {
    SplitPath(ruta, &nombre)
    try {
        ; Si el proceso ya corre, cerrarlo primero para garantizar recarga limpia si fuera necesario
        SetTitleMatchMode(2)
        DetectHiddenWindows(true)
        if WinExist(nombre " - AutoHotkey") {
            WinClose(nombre " - AutoHotkey")
            Sleep(150)
        }
        Run('"' ruta '"')
    } catch as err {
        MostrarNotificacion("❌ Error al ejecutar", nombre "`n" err.Message)
    }
}

EjecutarSiNoCorre(ruta) {
    SplitPath(ruta, &nombre)
    SetTitleMatchMode(2)
    DetectHiddenWindows(true)
    ; Busca si ya existe la ventana del script corriendo
    if !WinExist(nombre " - AutoHotkey") {
        EjecutarScript(ruta)
    }
}

MostrarNotificacion(titulo, texto) {
    ToolTip(titulo "`n" texto, A_ScreenWidth - 350, A_ScreenHeight - 120)
    SetTimer(() => ToolTip(), -2500)
}

SonidoNuevo() {
    try {
        SoundPlay(A_WinDir "\Media\Windows Notify.wav")
    } catch {
        SoundBeep(1200, 100)
    }
}

SonidoReload() {
    try {
        SoundPlay(A_WinDir "\Media\Windows Navigation Start.wav")
    } catch {
        SoundBeep(850, 60)
        Sleep(40)
        SoundBeep(1150, 80)
    }
}
