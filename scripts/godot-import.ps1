# Import assets (creates .godot/ and .godot/imported/). Run after changing any
# .glb / .csv / image.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\godot-import.ps1

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_env.ps1')

$result = Invoke-Godot -GodotArgs @('--headless', '--path', $GameDir, '--import') -LogName 'godot-import.log'

$classes = Join-Path $GameDir '.godot\global_script_class_cache.cfg'
$classCount = 0
if (Test-Path $classes) {
    $classCount = @(Select-String -Path $classes -Pattern '"class":' -SimpleMatch).Count
}

Write-Host ("godot --import exit={0}  classes={1}  log={2}" -f $result.ExitCode, $classCount, $result.Log)

if (Test-LogMarker -Path $result.Log -Pattern 'Parse Error') {
    Write-Host 'PARSE ERRORS FOUND:'
    Get-LogTail -Path $result.Log -Lines 20
    exit 1
}
if ($result.ExitCode -ne 0) { exit $result.ExitCode }

Write-Host 'IMPORT OK'
exit 0
