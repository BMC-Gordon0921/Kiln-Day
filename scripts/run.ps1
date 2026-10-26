# Open the Godot editor (default) or run the game directly (-Run).
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\run.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\run.ps1 -Run

param([switch]$Run)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_env.ps1')

Initialize-WorkspaceLocal

if ($Run) {
    Write-Host "running game: $GameDir"
    & $GodotConsole --path $GameDir
    exit $LASTEXITCODE
}

Write-Host "opening editor: $GameDir"
& $GodotGui --path $GameDir -e
exit $LASTEXITCODE
