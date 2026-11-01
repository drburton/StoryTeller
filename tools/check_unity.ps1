# Opens the Unity sample project in batch mode with Unity 6.7, compiles the
# Visual Novel Teller package, and runs VisualNovelTeller.BatchCheck: each
# tale's import problems, then every path of each tale. Prints the compile
# errors and the check's report, and exits with Unity's exit code.
#
# Usage:
#   .\tools\check_unity.ps1
#   .\tools\check_unity.ps1 -Unity "C:\Program Files\Unity\Hub\Editor\6000.7.0f1\Editor\Unity.exe"
#   .\tools\check_unity.ps1 -Project D:\MyGame       # check another project
#
# Close the project in the Unity editor first: Unity opens a project in one
# place at a time. The full log is written next to the project as
# check_unity.log.
param(
    [string]$Unity = $env:UNITY_BIN,
    [string]$Project = ""
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
if (-not $Project) { $Project = Join-Path $root "unity\SampleProject" }

if (-not $Unity) {
    $hub = Join-Path $env:ProgramFiles "Unity\Hub\Editor"
    $found = Get-ChildItem -Path $hub -Directory -Filter "6000.7*" -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if (-not $found) {
        Write-Error "No Unity 6.7 editor found in $hub. Pass -Unity <path to Unity.exe> or set UNITY_BIN."
        exit 2
    }
    $Unity = Join-Path $found.FullName "Editor\Unity.exe"
}
if (-not (Test-Path $Unity)) {
    Write-Error "Unity not found: $Unity"
    exit 2
}

$log = Join-Path (Split-Path -Parent $Project) "check_unity.log"
Write-Host "Unity:   $Unity"
Write-Host "Project: $Project"
Write-Host "Log:     $log"
Write-Host "Opening the project in batch mode. The first time takes several minutes."

$arguments = @(
    "-batchmode", "-nographics",
    "-projectPath", "`"$Project`"",
    "-executeMethod", "VisualNovelTeller.BatchCheck.Run",
    "-logFile", "`"$log`""
)
$process = Start-Process -FilePath $Unity -ArgumentList $arguments -Wait -PassThru -NoNewWindow
$code = $process.ExitCode

if (Test-Path $log) {
    Write-Host ""
    Write-Host "--- Compile errors and warnings ---"
    $compile = Select-String -Path $log -Pattern "error CS\d+|warning CS\d+" |
        ForEach-Object { $_.Line.Trim() } | Sort-Object -Unique
    if ($compile) { $compile } else { "(none)" }
    Write-Host ""
    Write-Host "--- Visual Novel Teller check ---"
    $report = Select-String -Path $log -Pattern "\[Visual Novel Teller\]" |
        ForEach-Object { $_.Line.Trim() }
    if ($report) { $report } else { "(the check did not run; see the compile errors above and the log)" }
    # Real exceptions only: "SomethingException: message", not file names that
    # contain the word, such as ValidationExceptions.json.
    $other = Select-String -Path $log -Pattern "\b\w*Exception: |executeMethod class|executeMethod method" |
        Where-Object { $_.Line -notmatch "^\s*Importing " } |
        ForEach-Object { $_.Line.Trim() } | Select-Object -First 20
    if ($other) {
        Write-Host ""
        Write-Host "--- Exceptions ---"
        $other
    }
}
Write-Host ""
Write-Host "Unity exit code: $code"
exit $code
