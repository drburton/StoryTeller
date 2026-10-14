# Exports the demo as a Windows game and checks it the way a player first
# uses it: the exported game starts and quits cleanly, finds its cast, tales,
# and translations (tools/export_check.gd), and plays, saves, and loads
# (tools/export_play_check.gd).
#
# Usage:
#   .\tools\check_windows_export.ps1 -Godot D:\Godot
#   .\tools\check_windows_export.ps1 -Godot D:\Godot -Out build\windows   # keep the game
#
# Needs Godot's Windows export template (windows_release_x86_64.exe) in
# %APPDATA%\Godot\export_templates\<version>. Uses export_presets.cfg when
# it has a "Windows Desktop" preset, and otherwise writes a temporary one.
# Exported games don't run scripts from the command line, so the two checks
# run on the game's .pck with the Godot console executable.
param(
    [string]$Godot = $env:GODOT_BIN,
    [string]$Out = ""
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot

if (-not $Godot) {
    Write-Error "Pass -Godot <path> or set GODOT_BIN."
    exit 2
}
if (Test-Path $Godot -PathType Container) {
    $found = Get-ChildItem -Path $Godot -Filter "Godot*_console.exe" -File |
        Sort-Object Name -Descending | Select-Object -First 1
    if (-not $found) {
        Write-Error "No Godot *_console.exe found in $Godot"
        exit 2
    }
    $Godot = $found.FullName
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("storyteller-windows-" + [guid]::NewGuid())
New-Item -ItemType Directory -Force $work | Out-Null
if (-not $Out) {
    $Out = Join-Path $work "game"
}
New-Item -ItemType Directory -Force $Out | Out-Null
$Out = (Resolve-Path $Out).Path

$presets = Join-Path $root "export_presets.cfg"
$madePresets = $false
if (Test-Path $presets) {
    if (-not (Select-String -Path $presets -Pattern 'name="Windows Desktop"' -Quiet)) {
        Write-Host "export_presets.cfg has no ""Windows Desktop"" preset; add one to run this check."
        exit 1
    }
} else {
    $madePresets = $true
    @'
[preset.0]

name="Windows Desktop"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter="tests/*, tools/*, docs/*, build/*, studio/*, studio_stories/*"
export_path=""

[preset.0.options]

binary_format/embed_pck=false
debug/export_console_wrapper=2
application/modify_resources=false
'@ | Set-Content -Path $presets -Encoding utf8
}

$failed = $false
# Messages from machines with no sound card, not from StoryTeller. Also
# Godot's note about the title music: --quit-after closes the game in the
# middle of it, before the audio mixer lets go (the game's Quit button
# stops the music first).
$noise = "WASAPI|audio driver|AudioDriver|resources still in use at exit"

function Show-Problems([string[]]$log) {
    $problems = $log | Select-String -Pattern "SCRIPT ERROR|^ERROR" | Where-Object { $_ -notmatch $noise }
    $problems | ForEach-Object { Write-Host $_ }
    return [bool]$problems
}

try {
    Write-Host "Using $Godot"
    & $Godot --headless --path $root --import 2>&1 | Out-Null
    Write-Host "Exporting the demo for Windows..."
    $game = Join-Path $Out "storyteller_demo.exe"
    $exportLog = & $Godot --headless --path $root --export-release "Windows Desktop" $game 2>&1 | ForEach-Object { "$_" }
    $console = Join-Path $Out "storyteller_demo.console.exe"
    $pack = Join-Path $Out "storyteller_demo.pck"
    foreach ($file in @($game, $console, $pack)) {
        if (-not (Test-Path $file)) {
            $exportLog | Select-Object -Last 20 | ForEach-Object { Write-Host $_ }
            Write-Host "The export has no $(Split-Path -Leaf $file)."
            exit 1
        }
    }

    Write-Host "Starting the exported game..."
    $startLog = & $console --headless --quit-after 300 2>&1 | ForEach-Object { "$_" }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "The exported game exited with $LASTEXITCODE."
        $failed = $true
    }
    if (Show-Problems $startLog) {
        $failed = $true
    }

    foreach ($check in @("export_check.gd", "export_play_check.gd")) {
        Write-Host "Running $check on the exported game..."
        Copy-Item (Join-Path $root "tools\$check") (Join-Path $work $check)
        $log = & $Godot --headless --main-pack $pack -s (Join-Path $work $check) 2>&1 | ForEach-Object { "$_" }
        $log | Where-Object { $_ -match "^(CHECK|FAIL|Cast:|Tales:|Languages:|Export check|Play check)" } | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) {
            $failed = $true
        }
    }
} finally {
    if ($madePresets) {
        Remove-Item $presets -ErrorAction SilentlyContinue
    }
    Remove-Item -Recurse -Force (Join-Path $work "*.gd") -ErrorAction SilentlyContinue
}

if ($failed) {
    Write-Host "Windows export check failed."
    exit 1
}
Write-Host "Windows export check passed: $game starts, plays, saves, and loads."
exit 0
