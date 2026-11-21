# mapa_hotkeys.ps1 - SOLO LECTURA
param([string]$Archivo = "C:\Users\jbard\Desktop\AHK-global-main\ClipStudioPaint _ Autohotkeys\lib\hotkeys_csp.ahk")
$L = Get-Content -LiteralPath $Archivo -Encoding UTF8
function Limpia([string]$s) {
    $s = [regex]::Replace($s, '"(?:[^"`]|`.)*"', '""')
    $s = [regex]::Replace($s, '''(?:[^''`]|`.)*''', "''")
    $i = $s.IndexOf(';'); if ($i -ge 0) { $s = $s.Substring(0, $i) }
    return $s
}
$ctx = ""; $out = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt $L.Count; $i++) {
    $t = $L[$i]
    if ($t -match '^#HotIf\b\s*(.*)$') { $ctx = $Matches[1].Trim(); continue }
    if ($t -notmatch '^(?<hk>[^\s;{}()",''][^;"'']*?)::(?<rest>.*)$') { continue }
    $hk = $Matches['hk'].Trim(); $rest = (Limpia $Matches['rest']).Trim()
    $fin = $i; $nota = ""
    if ($rest -eq "" -or $rest.StartsWith("{")) {
        $s = $i; $txt = $rest
        if ($rest -eq "") {
            $s = $i + 1
            while ($s -lt $L.Count -and (Limpia $L[$s]).Trim() -eq "") { $s++ }
            $txt = (Limpia $L[$s]).Trim()
        }
        if (-not $txt.StartsWith("{")) { $nota = "APILADO/REVISAR"; $fin = $s }
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
    $fam = if ($ctx -match 'altActive' -or $hk -match '^[~*$]*!') { "A?" }
           elseif ($hk -match 'Space' -or $ctx -match 'Space') { "B?" }
           elseif ($hk -match '^~?RButton\s*&') { "C?" }
           elseif ($ctx -match 'CspLibre') { "D/INFRA?" } else { "INFRA?" }
    $out.Add(("{0}-{1} | {2} | {3} | {4} | {5}" -f ($i+1), ($fin+1), $fam, $hk, $ctx, $nota))
}
$dir = Join-Path (Split-Path (Split-Path $Archivo)) "logs"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$dest = Join-Path $dir "mapa_hotkeys.txt"
$out | Set-Content -LiteralPath $dest -Encoding UTF8
"{0} hotkeys mapeados -> {1}" -f $out.Count, $dest
