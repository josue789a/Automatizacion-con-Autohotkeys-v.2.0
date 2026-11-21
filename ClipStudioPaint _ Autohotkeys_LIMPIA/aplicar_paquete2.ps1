# aplicar_paquete2.ps1 - Encapsula hotkeys legados con "&& _LegadoActivo()".
# Uso:  .\aplicar_paquete2.ps1 -Familias A,C              (simulacro)
#       .\aplicar_paquete2.ps1 -Familias A,C -Aplicar     (escribe, con respaldo)
# Familias: A, B, C, D1, D2, E.  CERRAR antes el script CSP (CheckReload).
param(
    [string]$Archivo = "C:\Users\jbard\Desktop\AHK-global-main\ClipStudioPaint _ Autohotkeys\lib\hotkeys_csp.ahk",
    [string[]]$Familias = @('A','B','C','D1','E'),
    [switch]$Aplicar,
    [switch]$Forzar
)
$ErrorActionPreference = 'Stop'

# --- TABLA DE OBJETIVOS (del mapa de ANTIGRAVITY): "ini-fin|hotkey[|ctx]" ---
$T = [ordered]@{
 'A' = @{ Ctx = 'CspLibre()'; Filas = @(
   '992-995|!e','996-999|!q','1010-1013|!Home','1014-1014|!-','1166-1175|!j',
   '1285-1300|$!x|CspLibre() && (IsSet(stylus) && stylus.altActive)',
   '1312-1328|!s','1714-1717|!w','1999-2023|!f','2024-2028|!f up') }
 'B' = @{ Ctx = 'CspLibre()'; Filas = @(
   '648-651|Space & RButton','1485-1490|~Space & -',
   '1492-1492|*e|GetKeyState("Space") && CspLibre()',
   '1887-1890|~Space & NumpadAdd','1891-1894|~Space & NumpadSub',
   '1895-1899|~Space & w','1900-1904|~Space & x','1905-1905|~Space & e',
   '1906-1909|~Space & q','1910-1915|~Space & s','1916-1927|~Space & f',
   '1928-1929|~Space & Numpad1','1929-1930|~Space & Numpad2','1930-1931|~Space & Numpad3',
   '1931-1932|~Space & Numpad4','1932-1933|~Space & Numpad5','1933-1938|~Space & Numpad6') }
 'C' = @{ Ctx = 'CspLibre()'; Filas = @(
   '931-936|~RButton & a','980-986|~RButton & e','1476-1481|~RButton & q',
   '1707-1712|~RButton & w','1719-1732|~RButton & -','1733-1739|~RButton & z',
   '1740-1740|~RButton & z up','1741-1746|~RButton & x','1747-1752|~RButton & 1',
   '1753-1758|~RButton & 2','1765-1766|~RButton & 3','1766-1767|~RButton & 4',
   '1767-1768|~RButton & 5','1768-1769|~RButton & 6','1769-1770|~RButton & 7',
   '1770-1771|~RButton & 8','1771-1772|~RButton & 9','1772-1781|~RButton & 0') }
 'D1' = @{ Ctx = 'CspLibre()'; Filas = @(
   '735-754|x','822-826|!z','827-833|!^z','834-834|!^z up','988-991|^e',
   '1162-1165|+q','1465-1468|+r','1472-1473|~f','1807-1810|NumpadDiv',
   '1811-1886|Numpad8','1943-1950|*Backspace','2029-2037|~b & k') }
 'D2' = @{ Ctx = 'CspLibre()'; Filas = @(
   '755-755|$^z','756-761|$^y','821-821|$^z up','915-929|$a','938-978|$e',
   '1015-1056|$w','1057-1088|$z','1090-1092|$z up','1094-1136|$q','1338-1383|$s') }
 'E' = @{ Ctx = 'CspLibre()'; Filas = @(
   '632-636|RButton','637-647|RButton up','1469-1470|Tab','1470-1471|+Escape','1471-1471|F3') }
}
foreach ($f in $Familias) { if (-not $T.Contains($f)) { throw "Familia desconocida: $f" } }

# --- LECTURA CONSERVANDO CODIFICACION ---
$bytes = [IO.File]::ReadAllBytes($Archivo)
$bom = ""; $off = 0
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $bom = "utf8bom"; $off = 3 }
elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { throw "UTF-16 no soportado. Sin cambios." }
$enc = New-Object System.Text.UTF8Encoding($false, $true)
try { $texto = $enc.GetString($bytes, $off, $bytes.Length - $off) } catch { throw "No es UTF-8 valido. Sin cambios." }
$eol = if ($texto.Contains("`r`n")) { "`r`n" } else { "`n" }
$terminaEol = $texto.EndsWith("`n")
$lines = New-Object 'System.Collections.Generic.List[string]'
$lines.AddRange([string[]]($texto -split "`r?`n"))
if ($terminaEol) { $lines.RemoveAt($lines.Count - 1) }

function Limpia([string]$s) {
    $s = [regex]::Replace($s, '"(?:[^"`]|`.)*"', '""')
    $s = [regex]::Replace($s, '''(?:[^''`]|`.)*''', "''")
    $i = $s.IndexOf(';'); if ($i -ge 0) { $s = $s.Substring(0, $i) }
    return $s
}
function Escanea($L) {
    $res = New-Object 'System.Collections.Generic.List[object]'
    $ctx = ""
    for ($i = 0; $i -lt $L.Count; $i++) {
        $t = $L[$i]
        if ($t -match '^#HotIf\b\s*(.*)$') { $ctx = $Matches[1].Trim(); continue }
        if ($t -notmatch '^(?<hk>[^\s;{}()",''][^;"'']*?)::(?<rest>.*)$') { continue }
        $hk = $Matches['hk'].Trim()
        $rest = (Limpia $Matches['rest']).Trim()
        $fin = $i
        if ($rest -eq "" -or $rest.StartsWith("{")) {
            $s = $i; $txt = $rest
            if ($rest -eq "") {
                $s = $i + 1
                while ($s -lt $L.Count -and (Limpia $L[$s]).Trim() -eq "") { $s++ }
                $txt = if ($s -lt $L.Count) { (Limpia $L[$s]).Trim() } else { "" }
            }
            if (-not $txt.StartsWith("{")) { $fin = [Math]::Min($s, $L.Count - 1) }
            else {
                $prof = 0; $k = $s
                while ($k -lt $L.Count) {
                    $x = if ($k -eq $i) { $rest } else { Limpia $L[$k] }
                    $prof += ([regex]::Matches($x, '\{')).Count - ([regex]::Matches($x, '\}')).Count
                    if ($prof -le 0) { break }
                    $k++
                }
                $fin = $k
            }
        }
        $res.Add([pscustomobject]@{ Ini = $i; Fin = $fin; Hk = $hk; Ctx = $ctx })
    }
    return ,$res
}

$ent = Escanea $lines
$graves = New-Object 'System.Collections.Generic.List[string]'
$avisos = New-Object 'System.Collections.Generic.List[string]'
if ($eol -eq "`r`n" -and [regex]::IsMatch($texto, '(?<!\r)\n')) { $avisos.Add("Saltos de linea mezclados (se normalizaran a CRLF)") }

# --- LOCALIZAR OBJETIVOS ---
$targets = New-Object 'System.Collections.Generic.List[object]'
$mapa = @{}; $yaHecho = 0
foreach ($f in $Familias) {
    foreach ($fila in $T[$f].Filas) {
        $p = $fila -split '\|', 3
        $rg = $p[0] -split '-'
        $len = [int]$rg[1] - [int]$rg[0]
        $hkB = $p[1]
        $ctxO = if ($p.Count -ge 3) { $p[2] } else { $T[$f].Ctx }
        $ctxN = "$ctxO && _LegadoActivo()"
        $m = @($ent | Where-Object { $_.Hk -ceq $hkB -and $_.Ctx -ceq $ctxO })
        if ($m.Count -eq 0) {
            $w = @($ent | Where-Object { $_.Hk -ceq $hkB -and $_.Ctx -ceq $ctxN })
            if ($w.Count -ge 1) { $yaHecho++ } else { $graves.Add("[$f] NO ENCONTRADO: '$hkB' con ctx '$ctxO'") }
            continue
        }
        if ($m.Count -gt 1) { $graves.Add("[$f] AMBIGUO ($($m.Count)): '$hkB'"); continue }
        $medida = $m[0].Fin - $m[0].Ini
        if ($medida -ne $len) { $avisos.Add("[$f] LONGITUD '$hkB': esperada $len, medida $medida") }
        $targets.Add([pscustomobject]@{ F = $f; Hk = $hkB; Ini = $m[0].Ini; Fin = $m[0].Fin; Ctx = $ctxO })
        $mapa["$hkB|$ctxO"] = $ctxN
    }
}
foreach ($t in $targets) {
    $k = $t.Fin + 1
    while ($k -lt $lines.Count -and $lines[$k] -match '^\s*(;.*)?$') { $k++ }
    if ($k -lt $lines.Count -and $lines[$k] -match '^\s') { $avisos.Add("FIN SOSPECHOSO tras '$($t.Hk)' (L$($t.Fin + 1)): la siguiente linea util esta indentada") }
}
if ($graves.Count -gt 0) { $graves | ForEach-Object { Write-Host $_ -ForegroundColor Red }; throw "Errores graves: sin cambios." }
if ($avisos.Count -gt 0) {
    $avisos | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
    if (-not $Forzar) { throw "Avisos sin resolver (usa -Forzar solo tras revisarlos). Sin cambios." }
}
if ($targets.Count -eq 0) { Write-Host "Nada que hacer ($yaHecho ya encapsulados)."; return }

# --- AGRUPAR BLOQUES CONTIGUOS DEL MISMO CONTEXTO ---
$grupos = New-Object 'System.Collections.Generic.List[object]'
foreach ($t in ($targets | Sort-Object Ini)) {
    $g = if ($grupos.Count -gt 0) { $grupos[$grupos.Count - 1] } else { $null }
    $unir = $false
    if ($g -and $g.Ctx -ceq $t.Ctx) {
        $unir = $true
        if ($t.Ini -gt $g.Fin + 1) {
            for ($k = $g.Fin + 1; $k -lt $t.Ini; $k++) {
                if ($lines[$k] -notmatch '^\s*(;.*)?$') { $unir = $false; break }
            }
        }
    }
    if ($unir) { if ($t.Fin -gt $g.Fin) { $g.Fin = $t.Fin }; $g.Hks += $t.Hk }
    else { $grupos.Add([pscustomobject]@{ Ini = $t.Ini; Fin = $t.Fin; Ctx = $t.Ctx; Hks = @($t.Hk) }) }
}

# --- APLICAR EN MEMORIA (de abajo hacia arriba) ---
$nuevas = New-Object 'System.Collections.Generic.List[string]'
$nuevas.AddRange($lines)
foreach ($g in ($grupos | Sort-Object Ini -Descending)) {
    $nuevo = "#HotIf " + $g.Ctx + " && _LegadoActivo()"
    $resto = "#HotIf " + $g.Ctx
    $k = $g.Fin + 1
    while ($k -lt $nuevas.Count -and $nuevas[$k].Trim() -eq "") { $k++ }
    $sigDirectiva = ($k -lt $nuevas.Count -and $nuevas[$k] -match '^#HotIf\b')
    if (-not $sigDirectiva) { $nuevas.Insert($g.Fin + 1, $resto) }
    $p = $g.Ini - 1
    while ($p -ge 0 -and $nuevas[$p].Trim() -eq "") { $p-- }
    if ($p -ge 0 -and $nuevas[$p] -match '^#HotIf\b\s*(.*)$' -and $Matches[1].Trim() -ceq $g.Ctx) { $nuevas[$p] = $nuevo }
    else { $nuevas.Insert($g.Ini, $nuevo) }
}

# --- VERIFICACION ESTRUCTURAL: solo deben cambiar los objetivos ---
$ent2 = Escanea $nuevas
$esp = @($ent | ForEach-Object { $k = "$($_.Hk)|$($_.Ctx)"; if ($mapa.ContainsKey($k)) { "$($_.Hk)|$($mapa[$k])" } else { $k } })
$obt = @($ent2 | ForEach-Object { "$($_.Hk)|$($_.Ctx)" })
$dif = @(Compare-Object -ReferenceObject $esp -DifferenceObject $obt -CaseSensitive)
if ($dif.Count -gt 0) {
    $dif | Select-Object -First 10 | ForEach-Object { Write-Host "$($_.SideIndicator) $($_.InputObject)" -ForegroundColor Red }
    throw "Verificacion estructural fallida. Sin cambios."
}

foreach ($g in ($grupos | Sort-Object Ini)) {
    Write-Host ("L{0}-{1}  [{2}]  {3}" -f ($g.Ini + 1), ($g.Fin + 1), $g.Ctx, ($g.Hks -join ' , '))
}
Write-Host ("`n{0} hotkeys en {1} bloques ({2} ya estaban encapsulados). Verificacion estructural OK." -f $targets.Count, $grupos.Count, $yaHecho) -ForegroundColor Green
if (-not $Aplicar) { Write-Host "SIMULACRO: no se escribio nada. Usa -Aplicar."; return }

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
Copy-Item -LiteralPath $Archivo -Destination "$Archivo.bak-paq2-$ts"
$salida = ($nuevas -join $eol); if ($terminaEol) { $salida += $eol }
$cuerpo = (New-Object System.Text.UTF8Encoding($false)).GetBytes($salida)
$pre = if ($bom -eq "utf8bom") { [byte[]](0xEF,0xBB,0xBF) } else { [byte[]]@() }
[IO.File]::WriteAllBytes($Archivo, [byte[]]($pre + $cuerpo))
Write-Host "ESCRITO. Respaldo: $Archivo.bak-paq2-$ts" -ForegroundColor Green
