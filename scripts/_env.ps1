# Shared environment, dot-sourced by the other scripts.
#
# Two hard rules:
#   1) Godot's user:// directory and all temp files stay under .local/ in this
#      workspace - nothing is written to C:.
#   2) Godot is launched through cmd redirection so its raw UTF-8 output lands
#      in a log file; piping through PowerShell would re-encode Chinese text
#      with the console code page and turn the log into mojibake.
#
# Kept ASCII-only on purpose: Windows PowerShell 5.1 misparses UTF-8 files
# without a BOM, and this repo must run under both 5.1 and 7.x.

$ErrorActionPreference = 'Stop'

$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$GameDir       = Join-Path $WorkspaceRoot 'game'
$LocalDir      = Join-Path $WorkspaceRoot '.local'
$TmpDir        = Join-Path $LocalDir 'tmp'
$GodotConsole  = 'D:\Program Files\Godot\Godot_v4.7.2-stable_win64_console.exe'
$GodotGui      = 'D:\Program Files\Godot\Godot_v4.7.2-stable_win64.exe'
$BlenderExe    = 'D:\Program Files\Blender Foundation\Blender 5.2\blender.exe'

function Initialize-WorkspaceLocal {
    foreach ($dir in @(
            $LocalDir,
            $TmpDir,
            (Join-Path $LocalDir 'appdata'),
            (Join-Path $LocalDir 'appdata\Local'))) {
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    }
    $env:APPDATA      = Join-Path $LocalDir 'appdata'
    $env:LOCALAPPDATA = Join-Path $LocalDir 'appdata\Local'
}

# Returns @{ ExitCode = N; Log = 'path' }. Read the log with an editor or the
# read tool; it is UTF-8.
function Invoke-Godot {
    param(
        [Parameter(Mandatory = $true)][string[]]$GodotArgs,
        [Parameter(Mandatory = $true)][string]$LogName
    )
    Initialize-WorkspaceLocal
    $log = Join-Path $TmpDir $LogName
    $quoted = ($GodotArgs | ForEach-Object { '"' + $_ + '"' }) -join ' '
    & cmd /c ('"{0}" {1} > "{2}" 2>&1' -f $GodotConsole, $quoted, $log)
    return @{ ExitCode = $LASTEXITCODE; Log = $log }
}

function Test-LogMarker {
    param([string]$Path, [string]$Pattern)
    if (-not (Test-Path $Path)) { return $false }
    return [bool](Select-String -Path $Path -Pattern $Pattern -SimpleMatch -Quiet)
}

function Get-LogTail {
    param([string]$Path, [int]$Lines = 12)
    if (-not (Test-Path $Path)) { return }
    Get-Content -Path $Path -Tail $Lines
}
