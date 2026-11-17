# actualizar.ps1 - Actualizaciones de Lucas (las corre el agente; Vanina no toca nada).
#
#   -Revisar     Hay una version nueva? Mira en internet como mucho una vez por dia (con -Forzar, siempre).
#   -Instalar    Baja la version nueva, la verifica, la descifra con la llave de esta PC y la instala.
#   -Posponer    Dijo "ahora no": no se vuelve a avisar por unos dias (-Dias, 3 por defecto).
#   -Raiz        Carpeta de Lucas (por defecto, la que contiene .agents\skills\actualizar\scripts).
#
# Datos de esta PC en <Raiz>\actualizacion\ : licencia.json (llave: no mostrar ni copiar), estado.json,
# version.txt e instalado.json. Salida en formato CLAVE=valor.

param(
    [switch]$Revisar,
    [switch]$Instalar,
    [switch]$Posponer,
    [switch]$Forzar,
    [int]$Dias = 3,
    [string]$Raiz = ''
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = 3072
if (-not $Raiz) { $Raiz = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path }
$Raiz = $Raiz.TrimEnd('\')
$DirAct = Join-Path $Raiz 'actualizacion'
$EstadoRuta = Join-Path $DirAct 'estado.json'

function Salir($clave, $valor) { Write-Host "$clave=$valor"; exit 0 }
function LeerJson($ruta) { if (Test-Path -LiteralPath $ruta) { return (Get-Content -LiteralPath $ruta -Raw -Encoding UTF8 | ConvertFrom-Json) } }
function Guardar($obj) { [IO.File]::WriteAllText($EstadoRuta, ($obj | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding($false))) }
function Num($v) { $n = 0; if ([int]::TryParse(([string]$v).Trim(), [ref]$n)) { return $n } return 0 }

function Bajar($url) {
    if ($url -notmatch '^https?://') { return ,[IO.File]::ReadAllBytes($url) }   # solo pruebas locales
    $wc = New-Object Net.WebClient
    $wc.Headers['User-Agent'] = 'AsistenteDocente'
    $wc.Headers['Cache-Control'] = 'no-cache'
    return ,$wc.DownloadData($url + $(if ($url -match '\?') { '&' } else { '?' }) + 't=' + [DateTime]::UtcNow.Ticks)
}
# Un archivo de especiales/<id>/ en el repo. Primero por la API de GitHub (siempre al dia), si no por raw.
function BajarRepo($nombre) {
    if ($env:AGM_BASE_LOCAL) { return ,[IO.File]::ReadAllBytes((Join-Path $env:AGM_BASE_LOCAL $nombre)) }
    try {
        $wc = New-Object Net.WebClient
        $wc.Headers['User-Agent'] = 'AsistenteDocente'
        $wc.Headers['Accept'] = 'application/vnd.github+json'
        $j = [Text.Encoding]::UTF8.GetString($wc.DownloadData("https://api.github.com/repos/$($lic.repo)/contents/especiales/$($lic.id)/$nombre")) | ConvertFrom-Json
        return ,[Convert]::FromBase64String(($j.content -replace '\s', ''))
    } catch {
        $codigo = try { [int]$_.Exception.InnerException.Response.StatusCode } catch { 0 }
        if ($codigo -eq 404) { throw $_ }
    }
    return ,(Bajar "https://raw.githubusercontent.com/$($lic.repo)/main/especiales/$($lic.id)/$nombre")
}
# Formato AGM1 (sal | iv | datos | hmac) con un codigo de 16 letras. $null si no corresponde.
function Descifrar([byte[]]$todo, [string]$codigo) {
    if ($todo.Length -lt 70 -or [Text.Encoding]::ASCII.GetString($todo, 0, 4) -ne 'AGM1') { return $null }
    $fin = $todo.Length - 32
    $kdf = New-Object Security.Cryptography.Rfc2898DeriveBytes($codigo, [byte[]]$todo[4..19], 200000, [Security.Cryptography.HashAlgorithmName]::SHA256)
    $claves = $kdf.GetBytes(64)
    $esperado = (New-Object Security.Cryptography.HMACSHA256(, [byte[]]$claves[32..63])).ComputeHash($todo, 0, $fin)
    $dif = 0
    for ($i = 0; $i -lt 32; $i++) { $dif = $dif -bor ($esperado[$i] -bxor $todo[$fin + $i]) }
    if ($dif -ne 0) { return $null }
    $aes = [Security.Cryptography.Aes]::Create()
    $aes.Key = [byte[]]$claves[0..31]
    $aes.IV = [byte[]]$todo[20..35]
    return ,$aes.CreateDecryptor().TransformFinalBlock($todo, 36, $fin - 36)
}
function CodigoMaestro {
    try { $llave = [Convert]::FromBase64String(([Text.Encoding]::ASCII.GetString((BajarRepo 'clave.txt'))).Trim()) } catch { return $null }
    $m = Descifrar $llave ([string]$lic.secreto).Replace('-', '')
    if (-not $m) { return $null }
    return [Text.Encoding]::ASCII.GetString($m)
}
function Novedades($info, $codigo) {
    if (-not $info.novedades -or -not $codigo) { return @() }
    $b = Descifrar ([Convert]::FromBase64String($info.novedades)) $codigo
    if (-not $b) { return @() }
    $lista = [Text.Encoding]::UTF8.GetString($b) | ConvertFrom-Json
    return @($lista | ForEach-Object { [string]$_ })
}

$lic = LeerJson (Join-Path $DirAct 'licencia.json')
if (-not $lic -or -not $lic.id -or -not $lic.secreto -or -not $lic.repo) { Salir 'ACTUALIZACIONES' 'NO_CONFIGURADAS' }
$verRuta = Join-Path $DirAct 'version.txt'
$actual = if (Test-Path -LiteralPath $verRuta) { Num (Get-Content -LiteralPath $verRuta -Raw) } else { 0 }
$estado = LeerJson $EstadoRuta
if (-not $estado) { $estado = [pscustomobject]@{} }
foreach ($c in 'ultima_revision', 'posponer_hasta', 'version_nueva', 'novedades') {
    if (-not ($estado.PSObject.Properties.Name -contains $c)) { $estado | Add-Member -NotePropertyName $c -NotePropertyValue $null }
}
$hoy = (Get-Date).ToString('yyyy-MM-dd')

if ($Posponer) {
    $estado.posponer_hasta = (Get-Date).AddDays($Dias).ToString('yyyy-MM-dd')
    Guardar $estado
    Salir 'POSPUESTA_HASTA' $estado.posponer_hasta
}

function LeerUltima {
    try { return ([Text.Encoding]::UTF8.GetString((BajarRepo 'ultima.json')) | ConvertFrom-Json) }
    catch {
        $codigo = try { [int]$_.Exception.InnerException.Response.StatusCode } catch { 0 }
        Write-Host 'HAY_ACTUALIZACION=0'
        Write-Host "MOTIVO=$(if ($codigo -eq 404) { 'nada_publicado' } else { 'sin_conexion' })"
        return $null
    }
}

if ($Revisar) {
    if (-not $Forzar -and $estado.posponer_hasta -and $hoy -lt $estado.posponer_hasta) {
        Write-Host 'HAY_ACTUALIZACION=0'; Salir 'MOTIVO' "pospuesta_hasta_$($estado.posponer_hasta)"
    }
    if (-not $Forzar -and $estado.ultima_revision -eq $hoy) {
        if ((Num $estado.version_nueva) -gt $actual) {
            Write-Host 'HAY_ACTUALIZACION=1'; Write-Host "VERSION_ACTUAL=$actual"; Write-Host "VERSION_NUEVA=$($estado.version_nueva)"
            $k = 0; foreach ($n in @($estado.novedades)) { if ($n) { $k++; Write-Host "NOVEDAD_$k=$n" } }
            exit 0
        }
        Salir 'HAY_ACTUALIZACION' '0'
    }
    $info = LeerUltima
    if (-not $info) { exit 0 }
    $estado.ultima_revision = $hoy
    $estado.version_nueva = [string]$info.version
    if ((Num $info.version) -le $actual) { $estado.novedades = @(); Guardar $estado; Write-Host 'HAY_ACTUALIZACION=0'; Salir 'VERSION_ACTUAL' $actual }
    $codigo = CodigoMaestro
    $estado.novedades = @(Novedades $info $codigo)
    Guardar $estado
    Write-Host 'HAY_ACTUALIZACION=1'
    Write-Host "VERSION_ACTUAL=$actual"
    Write-Host "VERSION_NUEVA=$($info.version)"
    if (-not $codigo) { Write-Host 'HABILITADA=0' }
    $k = 0; foreach ($n in @($estado.novedades)) { if ($n) { $k++; Write-Host "NOVEDAD_$k=$n" } }
    exit 0
}

if ($Instalar) {
    $info = LeerUltima
    if (-not $info) { Salir 'RESULTADO' 'ERROR_SIN_CONEXION' }
    if ((Num $info.version) -le $actual) { Write-Host "VERSION_ACTUAL=$actual"; Salir 'RESULTADO' 'YA_ESTABA_ACTUALIZADO' }
    $codigo = CodigoMaestro
    if (-not $codigo) { Salir 'RESULTADO' 'ERROR_NO_HABILITADA' }
    Write-Host "Bajando la version $($info.version)..."
    try { $paquete = Bajar $info.paquete } catch { Salir 'RESULTADO' 'ERROR_DESCARGA' }
    $sha = -join ((New-Object Security.Cryptography.SHA256Managed).ComputeHash($paquete) | ForEach-Object { $_.ToString('x2') })
    if ($info.sha256 -and $sha -ne $info.sha256) { Salir 'RESULTADO' 'ERROR_PAQUETE_ALTERADO' }
    $zipBytes = Descifrar $paquete $codigo
    if (-not $zipBytes) { Salir 'RESULTADO' 'ERROR_PAQUETE_INVALIDO' }

    $tmp = Join-Path $env:TEMP ('Lucas-act-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        $zip = Join-Path $tmp 'p.zip'
        [IO.File]::WriteAllBytes($zip, $zipBytes)
        $pkg = Join-Path $tmp 'p'
        Expand-Archive -LiteralPath $zip -DestinationPath $pkg -Force
        Write-Host '[OK] Version nueva verificada. Instalando...'
        # Corre aparte: puede reemplazar este mismo archivo. AGM_INSTALADOR_EXTRA: solo pruebas (separado por |).
        $extra = if ($env:AGM_INSTALADOR_EXTRA) { @($env:AGM_INSTALADOR_EXTRA -split '\|') } else { @() }
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $pkg 'instalar-paquete.ps1') -Destino $Raiz @extra
        $ok = $LASTEXITCODE -eq 0
    } finally {
        Set-Location $env:TEMP
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($ok) {
        $estado = LeerJson $EstadoRuta
        if (-not $estado) { $estado = [pscustomobject]@{ posponer_hasta = $null } }
        $estado.posponer_hasta = $null
        Guardar $estado
    }
    exit $(if ($ok) { 0 } else { 1 })
}

Write-Host 'Uso: actualizar.ps1 -Revisar | -Instalar | -Posponer'
