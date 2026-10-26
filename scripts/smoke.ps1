# Smoke test: run the main scene headless for a few frames and confirm Boot
# finished its self-check and AssetLab actually loaded glTF geometry.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\smoke.ps1

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_env.ps1')

$result = Invoke-Godot -GodotArgs @(
    '--headless', '--path', $GameDir, '--quit-after', '120'
) -LogName 'godot-smoke.log'

Write-Host ("godot smoke exit={0}  log={1}" -f $result.ExitCode, $result.Log)

$bootOk      = Test-LogMarker -Path $result.Log -Pattern 'BOOT_OK'
$loaded      = Test-LogMarker -Path $result.Log -Pattern 'ASSETLAB_OK'
$scriptError = Test-LogMarker -Path $result.Log -Pattern 'SCRIPT ERROR'

if ($bootOk -and $loaded -and (-not $scriptError) -and $result.ExitCode -eq 0) {
    Get-LogTail -Path $result.Log -Lines 3
    Write-Host 'SMOKE OK'
    exit 0
}

Write-Host 'SMOKE FAILED:'
Get-LogTail -Path $result.Log -Lines 30
exit 1
