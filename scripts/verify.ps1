# Environment check: toolchain versions, project assets, export-template gap.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\verify.ps1
#
# The real %APPDATA% is captured before _env.ps1 redirects it, because export
# templates live in the real user profile.

$ErrorActionPreference = 'Stop'
$realAppData = $env:APPDATA
. (Join-Path $PSScriptRoot '_env.ps1')

$problems = 0

Write-Host '=== toolchain ==='
$tools = @(
    @{ Name = 'Godot';   Exe = $GodotConsole; Arg = '--version' },
    @{ Name = 'Blender'; Exe = $BlenderExe;   Arg = '--version' },
    @{ Name = 'git';     Exe = 'git';         Arg = '--version' },
    @{ Name = 'node';    Exe = 'node';        Arg = '--version' }
)
foreach ($tool in $tools) {
    $cmd = Get-Command $tool.Exe -ErrorAction SilentlyContinue
    if ($cmd) {
        $version = (& $tool.Exe $tool.Arg 2>&1 | Select-Object -First 1)
        Write-Host ("  {0,-8} {1}" -f $tool.Name, $version)
    }
    else {
        Write-Host ("  {0,-8} MISSING" -f $tool.Name)
        $problems++
    }
}

Write-Host ''
Write-Host '=== export templates ==='
$templateRoots = @(
    (Join-Path $realAppData 'Godot\export_templates'),
    (Join-Path $LocalDir 'appdata\Godot\export_templates')
)
$foundTemplates = $false
foreach ($root in $templateRoots) {
    if (Test-Path $root) {
        $entries = @(Get-ChildItem $root -ErrorAction SilentlyContinue)
        if ($entries.Count -gt 0) { $foundTemplates = $true }
        Write-Host ("  {0} -> {1} item(s)" -f $root, $entries.Count)
    }
    else {
        Write-Host ("  {0} -> MISSING" -f $root)
    }
}
if (-not $foundTemplates) {
    Write-Host '  WARNING: no export templates installed; --export-* cannot work yet.'
    Write-Host '           When running through these scripts Godot uses the redirected'
    Write-Host '           APPDATA, so templates must live under'
    Write-Host '           .local\appdata\Godot\export_templates\<version>\ to be picked up.'
}

Write-Host ''
Write-Host '=== project assets ==='
$maps = Join-Path $GameDir 'assets\models\maps'
foreach ($name in @('guyao', 'museum', 'imperial', 'taoxichuan')) {
    $glb = Join-Path $maps "$name.glb"
    if (Test-Path $glb) {
        $mb = (Get-Item $glb).Length / 1MB
        Write-Host ("  {0,-12} {1,8:N2} MB" -f $name, $mb)
    }
    else {
        Write-Host ("  {0,-12} MISSING" -f $name)
        $problems++
    }
}
$manifest = Join-Path $maps 'manifest.json'
if (Test-Path $manifest) {
    Write-Host '  manifest.json  ok'
}
else {
    Write-Host '  manifest.json  MISSING'
    $problems++
}

$blends = @(Get-ChildItem (Join-Path $WorkspaceRoot 'art\blender') -Filter '*.blend' -ErrorAction SilentlyContinue)
Write-Host ("  blender sources {0} file(s)" -f $blends.Count)
if ($blends.Count -ne 4) { $problems++ }

Write-Host ''
if ($problems -eq 0) {
    Write-Host 'VERIFY OK'
    exit 0
}
Write-Host ("VERIFY FAILED: {0} problem(s)" -f $problems)
exit 1
