# Build one self-contained artifact for acceptance.
#
#   powershell -File scripts/build.ps1 -Tag step0
#   powershell -File scripts/build.ps1 -Target web -Tag web
#   powershell -File scripts/build.ps1 -Tag step1 -Shot
#
# Windows builds land in dist/windows/KilnDay-<tag>.exe (pck embedded, no extra
# files). Web builds land in dist/web/. Each Windows build is started headless
# and must print BOOT_OK and SITE_OK before the script reports success.
#
# ASCII-only on purpose (Windows PowerShell 5.1).

param(
    [ValidateSet('windows', 'web', 'all')]
    [string]$Target = 'windows',
    [string]$Tag = 'dev',
    [switch]$Shot
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_env.ps1')
Initialize-WorkspaceLocal

$version     = '4.7.2.stable'
$templateDir = Join-Path $env:APPDATA ('Godot\export_templates\' + $version)
$winTemplate = Join-Path $templateDir 'windows_release_x86_64.exe'
$webTemplate = Join-Path $templateDir 'web_nothreads_release.zip'

if (($Target -eq 'windows' -or $Target -eq 'all') -and -not (Test-Path $winTemplate)) {
    throw "Windows export template missing. Run scripts/install-templates.ps1 first."
}
if (($Target -eq 'web' -or $Target -eq 'all') -and -not (Test-Path $webTemplate)) {
    throw "Web export template missing. Run scripts/install-templates.ps1 first."
}

$safeTag = $Tag -replace '[^A-Za-z0-9._-]', '-'
$distDir = Join-Path $WorkspaceRoot 'dist'
$winDir  = Join-Path $distDir 'windows'
$webDir  = Join-Path $distDir 'web'
New-Item -ItemType Directory -Force -Path $winDir | Out-Null
New-Item -ItemType Directory -Force -Path $webDir | Out-Null

function Invoke-ExportedGame {
    param([string]$Exe, [string[]]$GameArgs, [string]$LogName)
    $log = Join-Path $TmpDir $LogName
    $quoted = ($GameArgs | ForEach-Object { '"' + $_ + '"' }) -join ' '
    & cmd /c ('"{0}" {1} > "{2}" 2>&1' -f $Exe, $quoted, $log)
    return @{ ExitCode = $LASTEXITCODE; Log = $log }
}

if ($Target -eq 'windows' -or $Target -eq 'all') {
    $exe = Join-Path $winDir ("KilnDay-{0}.exe" -f $safeTag)
    if (Test-Path $exe) { Remove-Item -Path $exe -Force }

    Write-Host "exporting Windows -> $exe"
    $result = Invoke-Godot -GodotArgs @('--headless', '--path', $GameDir, '--export-release', 'Windows Desktop', $exe) -LogName ("export-win-{0}.log" -f $safeTag)
    if ($result.ExitCode -ne 0) {
        Get-LogTail -Path $result.Log -Lines 30
        throw "Windows export failed (exit $($result.ExitCode))"
    }
    if (-not (Test-Path $exe)) { throw "export reported success but $exe is missing" }
    $size = (Get-Item $exe).Length
    if ($size -lt 20000000) { throw "exe is suspiciously small ($size bytes)" }
    Write-Host ("EXPORT OK {0} ({1:N1} MB)" -f $exe, ($size / 1MB))

    $smoke = Invoke-ExportedGame -Exe $exe -GameArgs @('--headless', '--quit-after', '30') -LogName ("export-smoke-{0}.log" -f $safeTag)
    if (-not (Test-LogMarker -Path $smoke.Log -Pattern 'BOOT_OK')) {
        Get-LogTail -Path $smoke.Log -Lines 30
        throw "exported exe did not reach BOOT_OK"
    }
    if (-not (Test-LogMarker -Path $smoke.Log -Pattern 'SITE_OK')) {
        Get-LogTail -Path $smoke.Log -Lines 30
        throw "exported exe did not reach SITE_OK"
    }
    Write-Host "SMOKE OK"

    if ($Shot) {
        $shotPath = Join-Path $TmpDir ("export-shot-{0}.png" -f $safeTag)
        if (Test-Path $shotPath) { Remove-Item -Path $shotPath -Force }
        $shotResult = Invoke-ExportedGame -Exe $exe -GameArgs @('--resolution', '1600x900', '--', ('shot=' + $shotPath)) -LogName ("export-shot-{0}.log" -f $safeTag)
        if (-not (Test-Path $shotPath)) {
            Get-LogTail -Path $shotResult.Log -Lines 30
            throw "exported exe did not write a screenshot"
        }
        Write-Host ("SHOT OK {0}" -f $shotPath)
    }
}

if ($Target -eq 'web' -or $Target -eq 'all') {
    $index = Join-Path $webDir 'index.html'
    if (Test-Path $index) { Remove-Item -Path $index -Force }

    Write-Host "exporting Web -> $webDir"
    $result = Invoke-Godot -GodotArgs @('--headless', '--path', $GameDir, '--export-release', 'Web', $index) -LogName ("export-web-{0}.log" -f $safeTag)
    if ($result.ExitCode -ne 0) {
        Get-LogTail -Path $result.Log -Lines 30
        throw "Web export failed (exit $($result.ExitCode))"
    }
    foreach ($name in @('index.html', 'index.wasm', 'index.pck')) {
        $file = Join-Path $webDir $name
        if (-not (Test-Path $file)) { throw "web export missing $name" }
    }
    $total = (Get-ChildItem -Path $webDir -Recurse -File | Measure-Object -Property Length -Sum).Sum
    Write-Host ("WEB OK {0} ({1:N1} MB)" -f $webDir, ($total / 1MB))
}

Write-Host ("BUILD OK tag={0} target={1}" -f $safeTag, $Target)
