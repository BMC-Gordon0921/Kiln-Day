# Full check: import -> unit tests -> smoke test.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\check.ps1 [-SkipImport]

param([switch]$SkipImport)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_env.ps1')

$failures = @()

if ($SkipImport) {
    Write-Host 'skipping import'
}
else {
    & (Join-Path $PSScriptRoot 'godot-import.ps1')
    if ($LASTEXITCODE -ne 0) { $failures += 'import' }
}

& (Join-Path $PSScriptRoot 'test.ps1')
if ($LASTEXITCODE -ne 0) { $failures += 'test' }

& (Join-Path $PSScriptRoot 'smoke.ps1')
if ($LASTEXITCODE -ne 0) { $failures += 'smoke' }

Write-Host ''
if ($failures.Count -eq 0) {
    Write-Host 'CHECK OK'
    exit 0
}
Write-Host ("CHECK FAILED: {0}" -f ($failures -join ', '))
exit 1
