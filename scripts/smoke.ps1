# Smoke test: run the main scene headless for a few frames and confirm Boot
# finished its self-check and the workshop scene came up.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\smoke.ps1

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_env.ps1')

$result = Invoke-Godot -GodotArgs @(
    '--headless', '--path', $GameDir, '--quit-after', '120'
) -LogName 'godot-smoke.log'

Write-Host ("godot smoke exit={0}  log={1}" -f $result.ExitCode, $result.Log)

$bootOk      = Test-LogMarker -Path $result.Log -Pattern 'BOOT_OK'
$siteOk      = Test-LogMarker -Path $result.Log -Pattern 'SITE_OK'
$playerOk    = Test-LogMarker -Path $result.Log -Pattern 'PLAYERS=1'
$scriptError = Test-LogMarker -Path $result.Log -Pattern 'SCRIPT ERROR'

$labResult = Invoke-Godot -GodotArgs @(
    '--headless', '--path', $GameDir, '--quit-after', '120', '--', 'lab'
) -LogName 'godot-smoke-lab.log'
$labOk = Test-LogMarker -Path $labResult.Log -Pattern 'ASSETLAB_OK'

if ($bootOk -and $siteOk -and $playerOk -and $labOk -and (-not $scriptError) -and $result.ExitCode -eq 0) {
    Get-LogTail -Path $result.Log -Lines 3
    Write-Host 'SMOKE OK'
    exit 0
}

Write-Host 'SMOKE FAILED:'
Get-LogTail -Path $result.Log -Lines 30
exit 1
