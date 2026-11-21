# PETICIÓN A CLAUDE — Calibrador multi-monitor + barra de paletas + 10 paletas CSP
Fecha: 2026-11-08 · Paquete autocontenido · Un solo agente (tú) · 3 peticiones atómicas

Lee este documento completo antes de tocar nada. Todo el código que necesitas para producir
los diffs está inline (§4). No necesitas acceso a la máquina del usuario para escribir los
diffs; los archivos del §6 son para verificar anclas y contexto, no para reescribir.

---

## 0. PROTOCOLO OBLIGATORIO (reglas del proyecto, no negociables)

1. **Diffs exactos, zero-rewrite.** Entrega bloques de reemplazo anclados: cita las líneas
   literales actuales (con 3 líneas de contexto antes y después) y el bloque nuevo. Numerados
   por archivo y por petición. Prohibido reescribir archivos completos o reestructurar.
2. **Respaldo antes de aplicar:** `.bak` de cada archivo tocado (el aplicador lo crea; tú
   indícalo en el diff como requisito).
3. **Validación:** `& "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" /validate "<archivo>.ahk"`
   → exit 0. En Git Bash el flag `/validate` se deforma sin `MSYS_NO_PATHCONV=1` y cuelga un
   modal: si validas desde bash, usa `MSYS_NO_PATHCONV=1 "C:/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /validate i"<ruta>"`.
   Exit 2 = error de carga en stderr, no lo ignores.
4. **Pruebas primero en `XPPEN_NO_ADMIN.ahk`** (réplica sin elevación). Solo tras éxito se
   replican las mismas líneas a `XPPEN AHK VERSION ESTABLE.ahk` / `lib/`.
5. **Fail-fast:** máximo 2 intentos autónomos por bug; al 3º sin éxito, detente y reporta
   diagnóstico exacto. Una petición a la vez (orden §1 → §2 → §3).
6. **AHK v2:** nombres de función sin mayúsculas iniciales prohibidas por convención del
   proyecto (respeta el estilo existente: `_PtsXxx`, `_TemaXxx`), out-params con `&v`,
   nada de funciones inexistentes (un call a función inexistente = modal en runtime).
7. **No toques** lo que ya funciona y está verificado: `_PtsTopToggle`, el botón `bPin`
   ("📌 Al frente / 🪟 Normal"), `[Calibrador] alwaysOnTop`, los hotkeys, el estabilizador,
   el HUB. Esta petición NO es sobre eso.
8. **Sin fixes especulativos:** cada cambio debe responder a una causa citada en §2/§3 con
   evidencia (imagen o línea de código). Si algo no está diagnosticado aquí, pregúntalo en
   tu entrega en vez de inventarlo.

---

## 1. CONTEXTO VERIFICADO (estado real del proyecto hoy)

- Script principal: `XPPEN AHK VERSION ESTABLE.ahk` (AutoHotkey v2.0.26), sha256
  `2c7a7cae0711f782a1464543a2c27bd9a5ca92fa1337ef4db962a16721e2360b`. Incluye en orden:
  `lib/core_config.ahk`, `lib/theme_gfx.ahk`, `lib/audio.ahk`, `lib/hud_badges.ahk`,
  `lib/companion.ahk`, `lib/estab_slider.ahk`, `lib/calibrador.ahk`, `lib/hotkeys_csp.ahk`.
- `lib/calibrador.ahk`: 1868 líneas, sha256 `b9eb073c0c5c303c755349c2ed146c759c9dabc391e969e77ac31492e7fd2ddd`.
  Es la "última versión" del usuario (parche de 8 cambios aplicado y verificado por diff).
- `lib/theme_gfx.ahk`: 559 líneas, sha256 `3a6713e25ce4b1ab342b14ed2655455a2d4a4d8e795ab6f9e0e48fea02519ef1`.
- `lib/core_config.ahk`: sha256 `e7d70e85c233f979a86d86db61af3c7ff7a2943acbc70a6cb981410a3d1a27d7`.
- `theme.ini`: sha256 `7c19d26526c72887727f7318c96e31b046b87faa1bf06605df05202b653cf5ca`.
  UTF-8 con BOM y CRLF en todos los .ini: **conserva encoding y saltos de línea** al escribir.
- `posiciones_gui.ini`: sha256 `db1001363a9e6136916024010a882b1bdef06dfadd8e5da99d039964c9ed6be8`.
  El companion en ejecución escribe este ini (flush diferido ~400 ms): si lo editas, espera
  a que el script no esté recargando y verifica el diff contra tu respaldo.
- **Topología de monitores del usuario** (de `[Perfil] ultimaFirma` del ini):
  - Tableta **XP-Pen Artist 16 Pro Gen 2**: rect `(-2560,-220)-(0,1380)` → 2560×1600.
  - Monitor **24" TEROS**: rect `(0,0)-(1920,1080)` → 1920×1080 (primario).
  - CSP corre normalmente sobre la tableta. El usuario quiere el Calibrador **nacido en la
    tableta**, pero libre para arrastrarlo al 24" sin desborde.
- El Calibrador se abre desde el companion; `CheckReload` (lib/companion.ahk:98) recarga el
  script en ~600 ms al cambiar el mtime del .ahk principal: cualquier edición de `lib/`
  requiere recarga para verse (el aplicador la dispara; avisa al usuario antes).
- **Paquete verificado el 2026-11-08:** los 10 bloques de código de §4 coinciden byte a byte
  con el disco en las líneas citadas; `/validate` exit 0 en `XPPEN_NO_ADMIN.ahk` y en
  `XPPEN AHK VERSION ESTABLE.ahk`. Puedes producir los diffs solo con este documento.
- Evidencia visual (copias dentro de este paquete, §6):
  - `img/img1-monitor24-carga-ok.png`: nacido en el 24" → layout correcto.
  - `img/img2-tableta-desborde.png`: en la tableta → los 4 botones "Dibujar con lápiz /
    Dibujar en cadena / Ver zonas / Por defecto" quedan flotando SOBRE las filas del
    ListView (recuadro rojo del usuario) mientras su GroupBox bajó ~250 px. Desborde interno.
  - `img/img3-paletas-vacias.png`: pestaña "🎨 Paleta de temas" con los 25 swatches en
    blanco (solo borde), aunque nombres, descripciones y botones Aplicar/✔ Activo funcionan.
  - `img/img4-csp-interfaz.png`: interfaz real de CSP de la que deben derivarse las 10
    paletas nuevas (colores ya medidos por píxel en §3.3).

---

## 2. PETICIÓN 1 — Nacimiento determinista en la tableta + movimiento entre monitores sin desborde

### 2.1 Síntomas
- A veces nace en el 24", a veces en la tableta (errático).
- Cuando nace/queda en la tableta (ventana más alta que el diseño), los botones con ancla
  horizontal `ps` no bajan con el resto → se superponen al ListView (img2).
- Al arrastrarla a un monitor más pequeño que el de nacimiento, la ventana no cabe.

### 2.2 Causas diagnosticadas (líneas de `lib/calibrador.ahk`, versión del hash §1)
1. **Monitor de nacimiento errático:** `_PtsAjustarVentana` (l.506-525) usa
   `MonitorFromWindow(g.Hwnd, 2)` = el monitor donde Windows dejó la ventana tras
   `g.Show("AutoSize")` (l.369), que suele ser el primario (24"). Nunca consulta ni la
   tableta ni CSP. Además la escala `uiF` (l.99, `_PtsUIEscala` l.567-585) sí usa
   `ObtenerMonitorCSP()`, que cae al primario cuando `colorV.cspHwnd` aún es 0 (loop de
   detección de 80 ms) → escala y monitor de nacimiento pueden discrepar entre aperturas.
2. **Botones que no bajan:** en `_PtsLayRedim` (l.478-505) la rama `if (r.ps)` (l.494-496)
   solo reescala X/ancho e **ignora `r.ay` y `r.ah`**. Los controles marcados `"mitad"` y
   `"fila4"` (l.370-372: bModoN, bModoE, barN, barE, bDib, bCad, bVer, bDef) reciben `ps/pb`
   en `_PtsLayInit` (l.424-429) y también `ay:=1` (l.437-438), pero ese `ay` nunca se aplica.
   Con `dy > 0` (tableta, ventana más alta) el GroupBox y el ListView bajan/crecen y esos 8
   controles se quedan arriba → img2.
3. **Sin re-encaje al cambiar de monitor:** no hay ningún handler de `WM_DISPLAYCHANGE`
   (0x007E) ni de fin de movimiento (`WM_EXITSIZEMOVE` 0x0232 / `WM_MOVING` 0x0216). Y
   `g.Opt("+MinSize")` (l.376) fija como mínimo el tamaño ajustado al monitor de nacimiento:
   en un monitor menor ese mínimo impide encoger la ventana hasta caber.

### 2.3 Requisitos de la corrección
- **Nacimiento siempre en la tableta** en esta topología, de forma determinista entre
  aperturas. Enfoque sugerido (puedes proponer otro si cumple): persistir en
  `posiciones_gui.ini` una firma del monitor de nacimiento (p.ej. `[Calibrador]
  nacRect=x,y,w,h`); al abrir, elegir el monitor cuyo rect coincida con la firma; si no
  existe o la topología cambió (compara con `ultimaFirma`), resolverlo desde la ventana de
  CSP (`ObtenerMonitorCSP()` / `WinExist("ahk_exe CLIPStudioPaint.exe")`) y re-guardar la
  firma. Override manual opcional por clave ini. Prohibido hardcodear `-2560,-220`.
- **Escala coherente:** `uiF` debe calcularse contra el mismo monitor elegido para nacer
  (hoy `_PtsUIEscala` puede mirar otro monitor distinto al de `_PtsAjustarVentana`).
- **Movimiento libre sin desborde:** al terminar de mover la ventana a otro monitor (o al
  cambiar la topología), re-encajar dentro del área útil de ese monitor (clamp de posición
  y tamaño, sin recentrar si el usuario la dejó en un borde) y recalcular `+MinSize` al
  mínimo real de diseño (`ly.cw0` × `ly.ch0 - ly.dyMin`), no al tamaño de nacimiento.
- **Layout interno correcto a cualquier alto:** la rama `r.ps` de `_PtsLayRedim` debe
  aplicar también `ay`/`ah` (o el equivalente que mantenga los 8 controles pegados a su
  GroupBox). Criterio de aceptación: con la ventana en la tableta a tamaño nacido, los 4
  botones de dibujar quedan DENTRO de su GroupBox "✏ Dibujar la zona seleccionada" y los 2
  botones de modo dentro de su franja, sin filas del ListView por debajo de ellos.
- No cambies el diseño de unidades lógicas (TW=736, TH=580, cw=704, x0=28) ni el sistema de
  anclas existente más de lo necesario para estos 3 puntos.

---

## 3. PETICIONES 2 y 3 — Barra de paletas completa + 10 paletas nuevas derivadas de CSP

### 3.1 Síntoma (img3)
Los 25 cuadros de muestra salen blancos con borde. Nombres, descripciones, botones
"Aplicar"/"✔ Activo" y la etiqueta "Tema activo:" sí funcionan; aplicar paletas también.

### 3.2 Causa diagnosticada
`lib/calibrador.ahk` l.283 crea cada swatch como
`g.Add("Text", uiP(sx,yc + 16,44,44) . " +Border Background" hex, "")`:
un control **Text con caption vacío no pinta el fondo** en esta GUI (queda el blanco del
control estático). El patrón que SÍ pinta en este mismo proyecto está en
`lib/theme_gfx.ahk` l.508-510 (selector emergente `_AbrirSelectorTema`, que se ve bien):
`Progress` con `c<hex> Background<hex>` y `Value := 100`.

### 3.3 Requisitos de la barra (petición 2)
- Recrear la barra completa de la pestaña 4 con swatches **pintados** (patrón Progress
  citado, o equivalente verificado), 5 por paleta, con el hex visible (caption pequeña o
  tooltip; elige lo que no rompa el layout).
- Conservar: etiqueta de tema activo (`ptsEd.temaLbl`), nombre + descripción por fila,
  botón Aplicar / ✔ Activo (`_PtsTemaMarcar`, l.589-613), y `_PtsTemaAplicar` (l.614-623).
- Conservar el comportamiento de anclas de la pestaña 4 en `_PtsLayInit` (l.447-453):
  nombre/desc con `aw:=1`, botón con `ax:=1`. Si cambias tipos o posiciones de controles,
  actualiza esa clasificación en el mismo diff (swatches sin ancla horizontal está bien).
- La barra debe seguir cabiendo en el alto de diseño de la pestaña con 5 paletas; con 15
  (5 viejas + 10 nuevas) necesita **scroll o paginación** dentro de la pestaña: resuélvelo
  sin romper `_PtsLayCuenta`/`_PtsLayInit` (cuentan controles por índice; un scroll container
  cambia ese conteo: si lo usas, adapta lyM en el mismo diff y explícalo). Alternativa
  aceptable: lista compacta de 15 filas con swatches de 22-26 px como el selector emergente.
  Elige UNA y justifícala en la entrega.

### 3.4 10 paletas nuevas (petición 3)
Colores **medidos por píxel** de `img/img4-csp-interfaz.png` (2560×1599), moda por región:

| Región de CSP | Hex medido |
|---|---|
| Barra de menú / panel Acceso rápido | `494949` |
| Toolbar superior / cabeceras de panel | `515151` |
| Paneles: rejilla de herramientas, propiedades, capas | `424242` |
| Celda de herramienta activa / fila de capa activa | `636D83` |
| Pestaña de documento activa | `6A748A` |
| Fondo alrededor del lienzo / navegador | `2E2E2E` |
| Barra de estado | `464646` |
| Bordes / separadores oscuros | `232323`, `3A3A3A` |
| Scrollbars / controles medios | `5C5C5C`, `5B5B5B` |
| Texto principal / secundario | `DCDCDC`, `F4F4F4` |

- Añade **10 perfiles nuevos** al array que devuelve `_TemaPerfiles()`
  (`lib/theme_gfx.ahk` l.385-483), numerados `6.` a `15.` en `nombre`, derivados de esa
  interfaz (p.ej. réplica medida exacta, carbón de paneles, pizarra azul de selección,
  nocturno OLED, papel cálido, alto contraste, verde estudio, violeta de acento, ámbar,
  claro gris CSP — decide tú los 10 nombres con criterio de armonía y descríbelos en `desc`).
- **Contrato exacto por perfil** (igual que los 5 existentes): `nombre`, `desc`,
  `swatches` = array de 5 hex RRGGBB sin `#`, `tokens` = Map con EXACTAMENTE estas 12 claves:
  `surface.on`, `surface.off`, `surface.reload`, `accent.estabSoft`, `track.pillOff`,
  `accent.estab`, `text.primary`, `text.idle`, `surface.estabOpen`, `surface.estabLocked`,
  `track.off`, `icon.off`.
- **No modifiques los 5 perfiles existentes** (el #1 es la réplica aproximada actual; el
  nuevo medido puede convivir como #6).
- El motor de aplicación ya existe y no se toca: `_TemaSelAplicarPerfil`
  (`lib/theme_gfx.ahk` l.535-549) escribe los 12 tokens en `theme.ini [color]`, recarga caché
  y repinta paneles; `_PtsTemaAplicar` además escribe `[meta] nombre`.
- Contraste mínimo: `text.primary`/`text.idle` legibles sobre `surface.off` y
  `surface.estabOpen` en las 10 (revísalo a ojo con los hex; no hace falta herramienta).

---

## 4. CÓDIGO INLINE (versión exacta de los hashes del §1; anclas para tus diffs)

### 4.1 `lib/calibrador.ahk` l.99-111 — escala y creación de la GUI
```autohotkey
    uiF := _PtsUIEscala()
    uiS := (n) => Round(n * uiF)
    uiP := (px, py, pw, ph := 0) => Format("x{} y{} w{}{}", uiS(px), uiS(py), uiS(pw), ph ? " h" uiS(ph) : "")
    fs := Round(9 * Min(uiF, 1.35))
    ptsTop := (Trim(IniRead(_PosGuiIniPath(),"Calibrador","alwaysOnTop","1")) != "0")
    g := Gui("+Resize" . (ptsTop ? " +AlwaysOnTop" : ""),"📍 Calibración · rangos, avisos y sistema")
    ptsEd.ly := {top: ptsTop, foco: false, listo: false, items: [], cols: [], dx: 0, dy: 0, cw0: 0, ch0: 0, bTop: 0}
    g.SetFont("s" fs,"Segoe UI")
    TW := 736          ; ancho de la pestaña (unidades lógicas, se escalan con uiF)
    TH := 580          ; alto de la pestaña
    cw := 704          ; ancho útil dentro de la pestaña
    x0 := 28
    tb := g.Add("Tab3",uiP(12,12,TW,TH),["📐 Zonas y rangos","🔔 Eventos / HUD","⚙ Sistema y perfiles","🎨 Paleta de temas"])
```

### 4.2 `lib/calibrador.ahk` l.271-295 — constructor actual de la pestaña 4 (swatches rotos)
```autohotkey
    ; ---------------- Pestaña 4: paleta de temas (integrada, sin ventana emergente) ----------------
    tb.UseTab(4)
    lyM.Push(_PtsLayCuenta(g))
    g.Add("Text",uiP(x0,50,cw,34),"Elige la paleta de colores y estilos para los botones del script, los colores de acento y los avisos en pantalla. Se guarda en theme.ini y se aplica al instante.")
    temaLbl := g.Add("Text",uiP(x0,86,cw,22) . " +0x200","")
    temaLbl.SetFont("s" fs " bold","Segoe UI")
    tUI := []
    yc := 114
    for p in _TemaPerfiles() {
        g.Add("GroupBox",uiP(x0,yc,cw,76),"")
        sx := x0 + 14
        for hex in p.swatches {
            g.Add("Text",uiP(sx,yc + 16,44,44) . " +Border Background" hex,"")
            sx += 50
        }
        nm := g.Add("Text",uiP(x0 + 276,yc + 14,cw - 276 - 132,22) . " +0x200",p.nombre)
        nm.SetFont("s" fs " bold","Segoe UI")
        g.Add("Text",uiP(x0 + 276,yc + 38,cw - 276 - 132,34) . " cGray",p.desc)
        bt := g.Add("Button",uiP(x0 + cw - 12 - 110,yc + 22,110,32),"Aplicar")
        bt.OnEvent("Click",_PtsTemaAplicar.Bind(p))
        tUI.Push({btn: bt})
        yc += 84
    }
    ptsEd.temaLbl := temaLbl
    ptsEd.temaUI := tUI
```

### 4.3 `lib/calibrador.ahk` l.369-378 — show, anclas y ajuste inicial
```autohotkey
    g.Show("AutoSize")
    ov := Map(bModoN.Hwnd,"mitad", bModoE.Hwnd,"mitad", ptsModo.barN.Hwnd,"mitad", ptsModo.barE.Hwnd,"mitad"
        , lv.Hwnd,"lv", lvEv.Hwnd,"lv", bDib.Hwnd,"fila4", bCad.Hwnd,"fila4", bVer.Hwnd,"fila4", bDef.Hwnd,"fila4"
        , bAp.Hwnd,"der", ddGrupo.Hwnd,"der")
    _PtsLayInit(g,lyM,tb,lv,lvEv,ov,{TW:TW,cw:cw,x0:x0,xR:xR,wL:wL,wR:wR})
    g.OnEvent("Size",_PtsLayRedim)
    _PtsAjustarVentana(g)                   ; cabe en el área útil del monitor y queda un poco sobre el centro
    g.Opt("+MinSize")                       ; tamaño ajustado = mínimo
    SetTimer(_PtsAutoMin,250)
    SetTimer(_PtsModoVigilar,500)
```

### 4.4 `lib/calibrador.ahk` l.396-477 — `_PtsLayInit` (completo)
```autohotkey
_PtsLayInit(g,lyM,tb,lv,lvEv,ov,u) {
    global ptsEd
    ly := ptsEd.ly
    tb.GetPos(&tx,&ty,&tw,&th)
    k := tw / u.TW                 ; px reales por unidad de diseño (escala UI × DPI)
    lv.GetPos(&lx,&lyy,&lw,&lh)
    lvEv.GetPos(&ex,&ey,&ew,&eh)
    bot1 := lyy + lh               ; borde inferior del ListView de la pestaña 1
    bot2 := ey + eh                ; borde inferior del ListView de la pestaña 2
    items := []
    idx := 0
    for hwnd, c in g {
        idx += 1
        c.GetPos(&x,&y,&w,&h)
        ux := x / k
        uw := w / k
        typ := c.Type
        modo := ov.Has(hwnd) ? ov[hwnd] : ""
        t := (idx <= lyM[1]) ? 0 : (idx <= lyM[2]) ? 1 : (idx <= lyM[3]) ? 2 : (idx <= lyM[4]) ? 3 : (idx <= lyM[5]) ? 4 : 5
        r := {c: c, x: x, y: y, w: w, h: h, ax: 0, aw: 0, ay: 0, ah: 0, ps: 0, pb: 0}
        if (t = 0) {                                   ; el Tab3: crece en ancho y alto
            r.aw := 1
            r.ah := 1
        } else if (t = 1 || t = 2) {                   ; zonas / eventos: ListView absorbe el alto
            bot := (t = 1) ? bot1 : bot2
            if (modo = "lv") {
                r.aw := 1
                r.ah := 1
            } else if (modo = "mitad") {
                r.ps := u.cw * k
                r.pb := u.x0 * k
            } else if (modo = "fila4") {
                r.ps := (u.cw - 24) * k
                r.pb := (u.x0 + 12) * k
            } else if (modo = "der") {
                r.ax := 1
            } else if ((typ = "GroupBox" || typ = "Text") && uw >= u.cw - 1) {
                r.aw := 1
            } else if (t = 2 && typ = "Text" && y < ey - 1 && ux >= u.x0 + u.cw - 300) {
                r.ax := 1                              ; etiqueta "Grupo:" pegada a su desplegable
            }
            if (modo != "lv" && y >= bot - 1)
                r.ay := 1                              ; todo lo que está bajo la lista baja con la ventana
        } else if (t = 3) {                            ; sistema: dos columnas, se reparten el ancho extra
            if (ux >= u.xR - 1) {
                r.ax := 0.5
                if (uw >= u.wR - 1)
                    r.aw := 0.5
            } else if (uw >= u.wL - 1) {
                r.aw := 0.5
            }
        } else if (t = 4) {                            ; paleta de temas
            if ((typ = "GroupBox" || typ = "Text") && uw >= u.cw - 1)
                r.aw := 1
            else if (typ = "Text" && ux >= u.x0 + 270 && ux <= u.x0 + 282)
                r.aw := 1
            else if (typ = "Button" && ux >= u.x0 + u.cw - 12 - 111)
                r.ax := 1
        } else {                                       ; barra inferior: pegada al borde de abajo
            r.ay := 1
            if (typ = "Text" && uw >= u.TW - 1)
                r.aw := 1
            else if (modo = "der")
                r.ax := 1
        }
        if (r.ax || r.aw || r.ay || r.ah || r.ps)
            items.Push(r)
    }
    ly.items := items
    ly.cols := []
    for l in [lv, lvEv]
        ly.cols.Push({l: l, w0: SendMessage(0x101D,0,0,l)})   ; LVM_GETCOLUMNWIDTH de la col. 1
    need := 0
    for r in items
        need := Max(need, r.y + r.h)                   ; borde inferior real de la barra de botones
    ly.cw0 := tx * 2 + tw                              ; ancho de diseño (margen 12 u a cada lado)
    ly.ch0 := need + Round(12 * k)                     ; alto de diseño = pie de botones + margen
    ly.dyMin := Max(0, Min(lh,eh) - Round(80 * k))     ; los ListView pueden encogerse hasta ~80 u
    ly.dx := 0
    ly.dy := 0
    ly.listo := true
}
```

### 4.5 `lib/calibrador.ahk` l.478-525 — `_PtsLayRedim` y `_PtsAjustarVentana` (completo)
```autohotkey
_PtsLayRedim(gg, minMax, w, h) {
    global ptsEd
    if (minMax = -1 || !IsObject(ptsEd.g) || !HasProp(ptsEd,"ly"))
        return
    ly := ptsEd.ly
    if (!ly.listo)
        return
    dx := Max(0, w - ly.cw0)                           ; nunca por debajo del tamaño AutoSize
    dy := Max(-ly.dyMin, h - ly.ch0)                   ; negativo = ventana más baja que el diseño (los ListView ceden)
    if (dx = ly.dx && dy = ly.dy)
        return
    ly.dx := dx
    ly.dy := dy
    hw := ptsEd.g.Hwnd
    DllCall("SendMessage","Ptr",hw,"UInt",0x000B,"Ptr",0,"Ptr",0)      ; WM_SETREDRAW off
    for r in ly.items {
        if (r.ps) {
            s := (r.ps + dx) / r.ps
            r.c.Move(Round(r.pb + (r.x - r.pb) * s),,Round(r.w * s))
        } else {
            r.c.Move(Round(r.x + r.ax * dx),Round(r.y + r.ay * dy),Round(r.w + r.aw * dx),Round(r.h + r.ah * dy))
        }
    }
    for ci in ly.cols
        try ci.l.ModifyCol(1,ci.w0 + dx)
    DllCall("SendMessage","Ptr",hw,"UInt",0x000B,"Ptr",1,"Ptr",0)      ; WM_SETREDRAW on
    DllCall("RedrawWindow","Ptr",hw,"Ptr",0,"Ptr",0,"UInt",0x185)
}
_PtsAjustarVentana(g) {
    ; Encaja la ventana en el área útil (sin barra de tareas) del monitor donde apareció y la sube un poco del centro.
    hMon := DllCall("MonitorFromWindow","Ptr",g.Hwnd,"UInt",2,"Ptr")
    mi := Buffer(40,0)
    NumPut("UInt",40,mi)
    if (!DllCall("GetMonitorInfoW","Ptr",hMon,"Ptr",mi))
        return
    wl := NumGet(mi,20,"Int")
    wt := NumGet(mi,24,"Int")
    wr := NumGet(mi,28,"Int")
    wb := NumGet(mi,32,"Int")
    g.GetPos(&x,&y,&w,&h)
    nw := Min(w, wr - wl - 16)
    nh := Min(h, wb - wt - 12)
    nx := wl + (wr - wl - nw) // 2
    ny := wt + Round((wb - wt - nh) * 0.30)            ; 0.50 = centro exacto; 0.30 = algo más arriba
    g.Move(nx,ny,nw,nh)
    g.GetClientPos(&cx,&cy,&cw,&ch)
    _PtsLayRedim(g,0,cw,ch)                            ; aplica el layout aunque no haya cambiado el tamaño
}
```

### 4.6 `lib/calibrador.ahk` l.567-585 — `_PtsUIEscala` (completo)
```autohotkey
_PtsUIEscala() {
    ; Factor de escala de la ventana del calibrador: 1.0 = monitor FHD lógico (1080 px de alto).
    ; Tableta 2.5K sube la ventana; monitor de 24" FHD la deja en 1.0. Se limita para que
    ; la ventana (~700 unidades de alto) nunca pase del 92% del monitor CSP.
    ; Override manual: [Calibrador] escalaUI=100..250 (%) en posiciones_gui.ini
    f := 1.0
    try {
        mon := ObtenerMonitorCSP()
        dpi := Max(96, A_ScreenDPI)
        alto := mon.h / (dpi / 96)
        f := Min(alto / 1080, alto * 0.92 / 700)
    }
    try {
        v := Trim(IniRead(_PosGuiIniPath(),"Calibrador","escalaUI",""))
        if (IsInteger(v) && Integer(v) >= 60 && Integer(v) <= 250)
            f := Integer(v) / 100
    }
    return Max(0.8, Min(1.8, f))
}
```

### 4.7 `lib/core_config.ahk` l.5-23 — `ObtenerMonitorCSP` y ruta del ini (completo)
```autohotkey
ObtenerMonitorCSP() {
    global colorV
    if (IsSet(colorV) && IsObject(colorV) && HasProp(colorV, "cspHwnd") && colorV.cspHwnd) {
        try {
            WinGetPos(&wx,&wy,&ww,&wh,"ahk_id " colorV.cspHwnd)
            cx := wx + ww // 2
            cy := wy + wh // 2
            loop MonitorGetCount() {
                MonitorGet(A_Index,&mL,&mT,&mR,&mB)
                if (cx >= mL && cx < mR && cy >= mT && cy < mB)
                    return {x:mL,y:mT,w:mR - mL,h:mB - mT}
            }
        }
    }
    pri := MonitorGetPrimary()
    MonitorGet(pri,&mL,&mT,&mR,&mB)
    return {x:mL,y:mT,w:mR - mL,h:mB - mT}
}
_PosGuiIniPath() => A_ScriptDir "\posiciones_gui.ini"
```

### 4.8 `lib/theme_gfx.ahk` l.385-483 — `_TemaPerfiles` (completo; aquí se insertan las 10)
```autohotkey
_TemaPerfiles() {
    return [
        {
            nombre: "1. CSP Réplica Nativa (Oscuro CSP)",
            desc: "Idéntico a los paneles, barras y botones activos de Clip Studio Paint",
            swatches: ["636C82", "474747", "C8CEDE", "9A7BFF", "363636"],
            tokens: Map(
                "surface.on", "636C82",
                "surface.off", "474747",
                "surface.reload", "3B7A4B",
                "accent.estabSoft", "C8CEDE",
                "track.pillOff", "5A5A5A",
                "accent.estab", "9A7BFF",
                "text.primary", "FFFFFF",
                "text.idle", "B2B2B2",
                "surface.estabOpen", "363636",
                "surface.estabLocked", "282828",
                "track.off", "3A3A3A",
                "icon.off", "B8B8B8"
            )
        },
        {
            nombre: "2. Grafito Carbón (Minimalismo)",
            desc: "Tonos neutros puros sin tintes de color para máxima concentración",
            swatches: ["525252", "333333", "999999", "CCCCCC", "2A2A2A"],
            tokens: Map(
                "surface.on", "525252",
                "surface.off", "333333",
                "surface.reload", "405948",
                "accent.estabSoft", "999999",
                "track.pillOff", "454545",
                "accent.estab", "CCCCCC",
                "text.primary", "F0F0F0",
                "text.idle", "8A8A8A",
                "surface.estabOpen", "2A2A2A",
                "surface.estabLocked", "202020",
                "track.off", "333333",
                "icon.off", "8A8A8A"
            )
        },
        {
            nombre: "3. Slate Blue / Studio Pro (Wacom)",
            desc: "Azul pizarra digital moderno inspirado en herramientas de ilustración",
            swatches: ["4E6982", "343B47", "7AA2F7", "7DCFFF", "2A313D"],
            tokens: Map(
                "surface.on", "4E6982",
                "surface.off", "343B47",
                "surface.reload", "2E6B4F",
                "accent.estabSoft", "7AA2F7",
                "track.pillOff", "465162",
                "accent.estab", "7DCFFF",
                "text.primary", "FFFFFF",
                "text.idle", "A0AEC0",
                "surface.estabOpen", "2A313D",
                "surface.estabLocked", "1E232B",
                "track.off", "3B4452",
                "icon.off", "A0AEC0"
            )
        },
        {
            nombre: "4. OLED Alto Contraste",
            desc: "Negros profundos y barras luminosas para pantallas oscuras o dibujo con luz solar",
            swatches: ["737B8C", "1E1E1E", "E6EDF8", "B388FF", "141414"],
            tokens: Map(
                "surface.on", "737B8C",
                "surface.off", "1E1E1E",
                "surface.reload", "2E7D32",
                "accent.estabSoft", "E6EDF8",
                "track.pillOff", "3A3A3A",
                "accent.estab", "B388FF",
                "text.primary", "FFFFFF",
                "text.idle", "CCCCCC",
                "surface.estabOpen", "141414",
                "surface.estabLocked", "0A0A0A",
                "track.off", "2A2A2A",
                "icon.off", "CCCCCC"
            )
        },
        {
            nombre: "5. Sepia / Warm Paper (Estudio)",
            desc: "Tonos tierra orgánicos que descansan la vista emulando papel tradicional",
            swatches: ["6B5E57", "423B38", "D4B996", "E09F67", "36302D"],
            tokens: Map(
                "surface.on", "6B5E57",
                "surface.off", "423B38",
                "surface.reload", "556B2F",
                "accent.estabSoft", "D4B996",
                "track.pillOff", "524944",
                "accent.estab", "E09F67",
                "text.primary", "FFF8F0",
                "text.idle", "B8ABA0",
                "surface.estabOpen", "36302D",
                "surface.estabLocked", "292422",
                "track.off", "3D3734",
                "icon.off", "B8ABA0"
            )
        }
    ]
}
```

### 4.9 `lib/theme_gfx.ahk` l.506-512 y l.535-549 — patrón de swatch que SÍ pinta + motor de aplicación
```autohotkey
        swX := 330, swY := "yp-16"
        for hex in p.swatches {
            sw := ventana.Add("Progress","x" swX " " swY " w22 h26 +Border c" hex " Background" hex)
            sw.Value := 100
            swX += 25
            swY := "yp"
        }
```
```autohotkey
_TemaSelAplicarPerfil(perfil, *) {
    est := _TemaSelEst()
    iniPath := A_ScriptDir "\theme.ini"
    try {
        for clave, hex in perfil.tokens {
            IniWrite(hex, iniPath, "color", clave)
        }
    } catch {
        try est.st.Value := "⚠ Error al escribir en theme.ini"
        return
    }
    _TemaRecargar()
    _TemaRefrescarPaneles()
    try est.st.Value := "✔ Paleta aplicada: " perfil.nombre
}
```

### 4.10 `posiciones_gui.ini` — claves relevantes hoy
```ini
[Perfil]
actual=2
ultimaFirma=-2560,-220,0,1380;0,0,1920,1080
[Calibrador]
alwaysOnTop=1
```
(`escalaUI` no existe hoy; `_PtsUIEscala` la acepta como override 60..250.)

---

## 5. FORMATO DE ENTREGA ESPERADO DE TI

Un solo documento de respuesta con:
1. **Diff petición 1** (`lib/calibrador.ahk`, y `lib/core_config.ahk` solo si imprescindible):
   bloques anclados con contexto literal, numerados, en orden de aplicación.
2. **Diff petición 2** (`lib/calibrador.ahk` pestaña 4 + clasificación t=4 si cambia).
3. **Diff petición 3** (`lib/theme_gfx.ahk`: inserción de los 10 perfiles antes del `]` de
   cierre del array, sin tocar los 5 existentes).
4. Por diff: archivo, líneas actuales que reemplaza, requisito de `.bak`, y qué prueba
   visual lo acepta (nacido en tableta / arrastre al 24" / botones dentro de su GroupBox /
   swatches pintados / 15 filas aplicables).
5. Lista de lo que NO tocaste y por qué (anclas fuera de alcance).
6. Si necesitas un dato que no está aquí: pídelo como pregunta concreta al final, no lo
   supongas.

Gate de aplicación (lo ejecuta el usuario/otro agente, no tú): copiar el real a una carpeta
temporal, aplicar 1→2→3, `/validate` exit 0, prueba en `XPPEN_NO_ADMIN.ahk`, mirada del
usuario, y solo entonces replicar al real con `.bak-<fecha>`.

---

## 6. ARCHIVOS A SUBIR A CLAUDE (rutas absolutas en la máquina del usuario)

**Subida mínima: PETICION.md + MANIFEST.txt + las 4 imágenes de `img/`.** Todo lo necesario
para escribir los diffs ya está inline en §4 y verificado byte a byte contra el disco
(2026-11-08, ver §1). Los archivos 1-6 de la tabla son OPCIONALES: súbelos solo si quieres
re-verificar anclas, conteos de controles o encoding por tu cuenta:

| # | Ruta absoluta | Para qué |
|---|---|---|
| 1 | `C:\Users\jbard\Desktop\AHK-global-main\ClipStudioPaint _ Autohotkeys\lib\calibrador.ahk` | archivo principal de los diffs 1 y 2 (1868 l) |
| 2 | `C:\Users\jbard\Desktop\AHK-global-main\ClipStudioPaint _ Autohotkeys\lib\theme_gfx.ahk` | diff 3 y motor de paletas (559 l) |
| 3 | `C:\Users\jbard\Desktop\AHK-global-main\ClipStudioPaint _ Autohotkeys\lib\core_config.ahk` | `ObtenerMonitorCSP`, ini helpers |
| 4 | `C:\Users\jbard\Desktop\AHK-global-main\ClipStudioPaint _ Autohotkeys\theme.ini` | tokens actuales y `[meta] nombre` |
| 5 | `C:\Users\jbard\Desktop\AHK-global-main\ClipStudioPaint _ Autohotkeys\posiciones_gui.ini` | topología de monitores y prefs (UTF-8 BOM, CRLF) |
| 6 | `C:\Users\jbard\Desktop\AHK-global-main\ClipStudioPaint _ Autohotkeys\XPPEN_NO_ADMIN.ahk` | driver de pruebas sin elevación (no se edita) |
| 7 | `...\_claude_entrega\peticion-20261108-calibrador-paletas\img\img1-monitor24-carga-ok.png` | evidencia layout OK |
| 8 | `...\_claude_entrega\peticion-20261108-calibrador-paletas\img\img2-tableta-desborde.png` | evidencia desborde interno |
| 9 | `...\_claude_entrega\peticion-20261108-calibrador-paletas\img\img3-paletas-vacias.png` | evidencia swatches blancos |
| 10 | `...\_claude_entrega\peticion-20261108-calibrador-paletas\img\img4-csp-interfaz.png` | fuente de las 10 paletas |

(`...` = `C:\Users\jbard\Desktop\AHK-global-main\ClipStudioPaint _ Autohotkeys`.)
Las 4 imágenes ya están copiadas dentro de este paquete en `img/`; puedes subir esa carpeta
tal cual junto con este PETICION.md y el MANIFEST.txt.