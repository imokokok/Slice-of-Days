param([string]$EnginePath = 'godot')
$ErrorActionPreference = 'Stop'
$resolvedEngine = (Get-Command $EnginePath -ErrorAction Stop).Source
$testWorkspace = Join-Path $env:TEMP ('ObservatoryTests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testWorkspace | Out-Null
Get-ChildItem -LiteralPath $PSScriptRoot -Force | Where-Object { $_.Name -ne '.godot' } | Copy-Item -Destination $testWorkspace -Recurse
Add-Content -LiteralPath (Join-Path $testWorkspace 'project.godot') -Value "`n[application]`nconfig/use_custom_user_dir=true`nconfig/custom_user_dir_name=`"ObservatoryPrototypeTests`""
& $resolvedEngine --headless --path $testWorkspace --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
& $resolvedEngine --headless --path $testWorkspace --script res://tests/integration.gd
if ($LASTEXITCODE -ne 0) { throw 'Integration tests failed.' }
Write-Output ('Tests passed. Isolated test project: ' + $testWorkspace)
