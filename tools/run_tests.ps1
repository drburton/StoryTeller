# Runs the StoryTeller test suite headless on Windows.
#
# Usage:
#   .\tools\run_tests.ps1 -Godot D:\Godot
#   .\tools\run_tests.ps1 -Godot D:\Godot -Filter crew
#   .\tools\run_tests.ps1 -Godot D:\Godot -UpdateGolden   # rewrite expected parse trees
#
# -Godot accepts the console executable or the folder that contains it.
# When omitted, the GODOT_BIN environment variable is used.
param(
    [string]$Godot = $env:GODOT_BIN,
    [string]$Filter = "",
    [switch]$UpdateGolden
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot

if (-not $Godot) {
    Write-Error "Pass -Godot <path> or set GODOT_BIN, for example: .\tools\run_tests.ps1 -Godot D:\Godot"
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

Write-Host "Using $Godot"
Write-Host "Importing project..."
$importLog = & $Godot --headless --path $root --import 2>&1 | ForEach-Object { "$_" }
$scriptErrors = $importLog | Select-String -Pattern "SCRIPT ERROR|Parse Error"
if ($scriptErrors) {
    $scriptErrors | ForEach-Object { Write-Host $_ }
    Write-Host "Script errors found while importing the project."
    exit 1
}

$testArgs = @("--headless", "--path", $root, "-s", "res://tests/run_tests.gd")
$userArgs = @()
if ($Filter) {
    $userArgs += "--filter=$Filter"
}
if ($UpdateGolden) {
    $userArgs += "--update-golden"
}
if ($userArgs.Count -gt 0) {
    $testArgs += @("--") + $userArgs
}
& $Godot @testArgs 2>&1 | ForEach-Object { "$_" }
exit $LASTEXITCODE
