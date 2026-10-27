# Run one scene at 1600x900 with user args (shot=, walkto=, bare, clay, ...)
# and print the tail of its log. Used for the docs/06 parity captures.
param(
    [string]$LogName = 'shot.log',
    [string]$Scene = '',
    [string[]]$Extra = @()
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_env.ps1')
$GodotArgs = @('--path', $GameDir, '--resolution', '1600x900')
if ($Scene -ne '') { $GodotArgs += $Scene }
$GodotArgs += '--'
foreach ($item in $Extra) {
    if ($item -eq '') { continue }
    $GodotArgs += ($item -split ',')
}
$result = Invoke-Godot -GodotArgs $GodotArgs -LogName $LogName
Write-Output ("EXIT=" + $result.ExitCode)
Get-Content -Path $result.Log -Tail 40
