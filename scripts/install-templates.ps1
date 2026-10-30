# Install the Godot 4.7.2 export templates into the workspace.
#
# The repo rule is that Godot's user data stays under .local/, so templates are
# installed to .local/appdata/Godot/export_templates/4.7.2.stable. build.ps1
# runs Godot with the same APPDATA, so it finds them there.
#
# Usage:
#   powershell -File scripts/install-templates.ps1
#   powershell -File scripts/install-templates.ps1 -From D:\downloads\templates.tpz
#
# ASCII-only on purpose (Windows PowerShell 5.1).

param(
    [string]$From = ""
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_env.ps1')
Initialize-WorkspaceLocal

$version    = '4.7.2.stable'
$cacheDir   = Join-Path $LocalDir 'cache'
$tpzPath    = Join-Path $cacheDir 'Godot_v4.7.2-stable_export_templates.tpz'
$url        = 'https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
$templateDir = Join-Path $env:APPDATA ('Godot\export_templates\' + $version)

if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null }

if ($From -ne "") {
    if (-not (Test-Path $From)) { throw "template archive not found: $From" }
    $tpzPath = $From
}

if (-not (Test-Path $tpzPath)) {
    Write-Host "downloading export templates (~1.28 GB)..."
    & curl.exe -L --fail --retry 3 --retry-delay 2 -o $tpzPath $url
    if ($LASTEXITCODE -ne 0) { throw "download failed with exit code $LASTEXITCODE" }
}

$size = (Get-Item $tpzPath).Length
Write-Host ("archive: {0} ({1:N0} bytes)" -f $tpzPath, $size)
if ($size -lt 1200000000) {
    throw "archive looks incomplete ($size bytes); delete it and retry"
}

$stage = Join-Path $cacheDir 'templates-extract'
if (Test-Path $stage) { Remove-Item -Path $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null

# .tpz is a plain zip. Windows' bsdtar (System32\tar.exe) handles it; call it
# by full path so a Git-for-Windows tar earlier on PATH cannot win.
$tar = Join-Path $env:SystemRoot 'System32\tar.exe'
if (-not (Test-Path $tar)) { throw "tar.exe not found at $tar" }
& $tar -xf $tpzPath -C $stage
if ($LASTEXITCODE -ne 0) { throw "extract failed with exit code $LASTEXITCODE" }

$src = Join-Path $stage 'templates'
if (-not (Test-Path $src)) { $src = $stage }

New-Item -ItemType Directory -Force -Path $templateDir | Out-Null
Copy-Item -Path (Join-Path $src '*') -Destination $templateDir -Recurse -Force

$winTemplate = Join-Path $templateDir 'windows_release_x86_64.exe'
$webTemplate = Join-Path $templateDir 'web_nothreads_release.zip'
if (-not (Test-Path $winTemplate)) { throw "windows template missing after install: $winTemplate" }
if (-not (Test-Path $webTemplate)) { Write-Host "WARNING: web template not found ($webTemplate)" }

Write-Host ("TEMPLATES OK {0}" -f $templateDir)
