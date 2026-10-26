# Run the headless unit tests. Pass criterion: exit code 0, the log contains
# "ALL TESTS PASSED", and no "FAIL " line is present.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\test.ps1

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_env.ps1')

$result = Invoke-Godot -GodotArgs @(
    '--headless', '--path', $GameDir, '--script', 'res://tests/run_tests.gd'
) -LogName 'godot-tests.log'

Write-Host ("godot tests exit={0}  log={1}" -f $result.ExitCode, $result.Log)

$passed  = Test-LogMarker -Path $result.Log -Pattern 'ALL TESTS PASSED'
$failMark = Test-LogMarker -Path $result.Log -Pattern 'FAIL '

if ($passed -and -not $failMark -and $result.ExitCode -eq 0) {
    Get-LogTail -Path $result.Log -Lines 3
    Write-Host 'TESTS OK'
    exit 0
}

Write-Host 'TESTS FAILED:'
Get-LogTail -Path $result.Log -Lines 30
exit 1
