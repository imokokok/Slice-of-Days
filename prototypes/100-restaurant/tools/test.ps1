param(
    [Parameter(Mandatory=$true)][string]$GodotPath,
    [string]$PythonPath = '',
    [string]$OutputDirectory = ''
)
$ErrorActionPreference = 'Stop'
if (-not $PythonPath) {
    $python = Get-Command python3, python, py -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $python) { throw 'Python 3 is required. Install Python 3 or pass -PythonPath.' }
    $PythonPath = $python.Source
}
$runnerArguments = @((Join-Path $PSScriptRoot 'run_checks.py'), '--godot', $GodotPath)
if ($OutputDirectory) { $runnerArguments += @('--output-dir', $OutputDirectory) }
& $PythonPath @runnerArguments
if ($LASTEXITCODE -ne 0) { throw 'Full restaurant checks failed; see the summary and per-step logs.' }
