# Re-export the four glTF scenes from their .blend sources.
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\export-art.ps1                       # writes game/assets/models/maps
#   powershell -ExecutionPolicy Bypass -File scripts\export-art.ps1 -Out .local\tmp\check # scratch dir, for verification
#
# This rewrites manifest.json. Run scripts\godot-import.ps1 afterwards.

param([string]$Out)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_env.ps1')

$exporter = Join-Path $WorkspaceRoot 'art\export\export-blender-scenes.py'
if (-not (Test-Path $exporter)) { Write-Host "missing exporter: $exporter"; exit 1 }
if (-not (Test-Path $BlenderExe)) { Write-Host "missing blender: $BlenderExe"; exit 1 }

$blenderArgs = @(
    '--background', '--factory-startup', '--disable-autoexec',
    '--python', $exporter
)

if ($Out) {
    $isRooted = $Out.StartsWith('\\') -or ($Out -match '^[A-Za-z]:')
    $outPath = $Out
    if (-not $isRooted) { $outPath = Join-Path $WorkspaceRoot $Out }
    $blenderArgs += @('--', '--out', $outPath)
    Write-Host "exporting to scratch dir: $outPath"
}
else {
    Write-Host "exporting to $(Join-Path $GameDir 'assets\models\maps')"
}

& $BlenderExe @blenderArgs 2>&1 | ForEach-Object { Write-Host $_ }
$code = $LASTEXITCODE
Write-Host ("blender exit={0}" -f $code)
exit $code
